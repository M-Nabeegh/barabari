import SwiftUI

struct SettlementView: View {
    @StateObject private var viewModel: SettlementViewModel
    private let onSaved: () -> Void
    @FocusState private var isNoteFocused: Bool
    @State private var step: Step = .amount
    @State private var shakeAmount = 0

    init(
        environment: AppEnvironment,
        groupID: UUID,
        fromUserID: UUID,
        toUserID: UUID,
        remainingAmount: Money,
        recipient: String,
        onSaved: @escaping () -> Void = {}
    ) {
        self.onSaved = onSaved
        _viewModel = StateObject(wrappedValue: SettlementViewModel(
            environment: environment,
            groupID: groupID,
            fromUserID: fromUserID,
            toUserID: toUserID,
            remainingAmount: remainingAmount,
            recipient: recipient
        ))
    }

    var body: some View {
        SwiftUI.Group {
            if let settlement = viewModel.savedSettlement {
                ScrollView {
                    confirmation(settlement)
                        .padding(.top, 8)
                        .barabariScreen()
                }
            } else if step == .amount {
                amountStep
                    .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
            } else {
                ScrollView {
                    detailsStep
                        .padding(.top, 8)
                        .barabariScreen()
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BarabariColors.background)
        .navigationTitle("Settle up")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.savedSettlement?.id) { _, savedID in
            guard savedID != nil else { return }
            onSaved()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isNoteFocused = false }
            }
        }
    }

    private enum Step {
        case amount
        case details
    }

    private func go(to newStep: Step) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { step = newStep }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: -12) {
                MemberAvatar(name: "You", seed: viewModel.fromUserID, size: 52)
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BarabariColors.textSecondary)
                    .frame(width: 28, height: 28)
                    .glassEffect(.regular, in: .circle)
                    .zIndex(1)
                MemberAvatar(name: viewModel.recipient, seed: viewModel.toUserID, size: 52)
            }
            Text("Settle with \(viewModel.recipient)")
                .font(.title3.weight(.bold))
        }
    }

    private var amountStep: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 8)

            Spacer(minLength: 8)

            AmountEntryField(
                text: $viewModel.amount,
                prompt: "How much did you pay?",
                accessibilityIdentifier: "settlement-amount",
                size: 64,
                shakeTrigger: shakeAmount
            )

            HStack(spacing: 8) {
                quickAmountChip("Full", minorUnits: viewModel.remainingAmount.minorUnits)
                quickAmountChip("Half", minorUnits: viewModel.remainingAmount.minorUnits / 2)
            }
            .padding(.top, 12)

            Spacer(minLength: 8)

            AmountKeypad(text: $viewModel.amount, identifierPrefix: "keypad")
                .padding(.horizontal, 8)

            Button {
                guard (Double(viewModel.amount) ?? 0) > 0 else {
                    shakeAmount += 1
                    BarabariInteraction.trigger(.error)
                    return
                }
                BarabariInteraction.trigger(.selection)
                go(to: .details)
            } label: {
                Text("Continue")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .contentShape(Capsule())
            }
            .buttonStyle(BarabariPrimaryButtonStyle())
            .opacity((Double(viewModel.amount) ?? 0) > 0 ? 1 : 0.5)
            .padding(.top, 14)
            .accessibilityIdentifier("settlement-continue")
        }
        .padding(.horizontal, BarabariSpacing.screen)
        .padding(.bottom, 12)
    }

    private func quickAmountChip(_ title: String, minorUnits: Int64) -> some View {
        Button {
            BarabariInteraction.trigger(.selection)
            let whole = minorUnits / 100
            let fraction = minorUnits % 100
            viewModel.amount = fraction == 0 ? "\(whole)" : String(format: "%lld.%02lld", whole, fraction)
        } label: {
            HStack(spacing: 4) {
                Text(LocalizedStringKey(title))
                    .foregroundStyle(BarabariColors.textSecondary)
                AmountText(minorUnits: minorUnits, currencyCode: viewModel.remainingAmount.currencyCode, style: .compact)
                    .foregroundStyle(BarabariColors.textPrimary)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(title) amount")
    }

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.section) {
            Button {
                go(to: .amount)
            } label: {
                VStack(spacing: 6) {
                    header
                    HeroAmount(
                        minorUnits: Int64(((Double(viewModel.amount) ?? 0) * 100).rounded()),
                        size: 44,
                        color: BarabariColors.textPrimary
                    )
                    Label("Tap to edit", systemImage: "pencil")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(BarabariColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Edit amount")

            VStack(alignment: .leading, spacing: BarabariSpacing.row) {
                SectionHeader("How was it paid?")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(SettlementMethod.allCases, id: \.self) { method in
                        let isSelected = viewModel.method == method
                        Button {
                            BarabariInteraction.trigger(.selection)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                                viewModel.method = method
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: method.systemImage)
                                    .font(.system(size: 20, weight: .semibold))
                                    .symbolEffect(.bounce, value: isSelected)
                                Text(LocalizedStringKey(method.title))
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .foregroundStyle(isSelected ? BarabariColors.onAccent : BarabariColors.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 74)
                            .background {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(isSelected ? AnyShapeStyle(BarabariColors.accent.gradient) : AnyShapeStyle(BarabariColors.surface))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(isSelected ? .clear : BarabariColors.hairline, lineWidth: 1)
                            }
                            .scaleEffect(isSelected ? 1.03 : 1)
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel(Text(LocalizedStringKey(method.title)))
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                Text("This only records your payment method. Barabari never moves money.")
                    .font(BarabariTypography.metadata)
                    .foregroundStyle(BarabariColors.textSecondary)
                    .padding(.horizontal, 4)
            }
            .staggeredAppear(0)

            TextField("Add a note (optional)", text: $viewModel.note, axis: .vertical)
                .lineLimit(1...4)
                .focused($isNoteFocused)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
                .staggeredAppear(1)

            if let message = viewModel.validationMessage {
                StatusBadge(message, style: .danger)
            }

            PrimaryActionButton(viewModel.isSaving ? "Recording..." : "Mark as paid") {
                isNoteFocused = false
                Task {
                    let didSave = await viewModel.save()
                    BarabariInteraction.trigger(didSave ? .success : .error)
                }
            }
            .disabled(viewModel.isSaving)
            .staggeredAppear(2)
        }
    }

    private func confirmation(_ settlement: Settlement) -> some View {
        VStack(spacing: BarabariSpacing.section) {
            ReceiptHeader(
                systemImage: "checkmark.seal.fill",
                tint: BarabariColors.success,
                title: "Settlement recorded locally",
                amount: settlement.amount,
                date: settlement.occurredAt
            )
            Text("\(settlement.method.title) payment to \(viewModel.recipient) is now in this group’s ledger on this iPhone.")
                .font(BarabariTypography.body)
                .foregroundStyle(BarabariColors.textSecondary)
                .multilineTextAlignment(.center)
            StatusBadge("Saved offline-ready", style: .success)
        }
        .frame(maxWidth: .infinity)
    }
}

extension SettlementMethod {
    static var allCases: [SettlementMethod] {
        [.cash, .raast, .bankTransfer, .easypaisa, .jazzcash, .other]
    }

    var title: String {
        switch self {
        case .cash: "Cash"
        case .raast: "Raast"
        case .bankTransfer: "Bank transfer"
        case .easypaisa: "Easypaisa"
        case .jazzcash: "JazzCash"
        case .other: "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .cash: "banknote.fill"
        case .raast: "bolt.fill"
        case .bankTransfer: "building.columns.fill"
        case .easypaisa: "iphone.gen3"
        case .jazzcash: "creditcard.fill"
        case .other: "ellipsis.circle.fill"
        }
    }
}
