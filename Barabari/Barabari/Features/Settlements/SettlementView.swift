import SwiftUI

struct SettlementView: View {
    @StateObject private var viewModel: SettlementViewModel
    private let onSaved: () -> Void
    @FocusState private var isAmountFocused: Bool

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
        ScrollView {
            VStack(alignment: .leading, spacing: BarabariSpacing.section) {
                if let settlement = viewModel.savedSettlement {
                    confirmation(settlement)
                } else {
                    form
                }
            }
            .padding(BarabariSpacing.screen)
            .padding(.bottom, 42)
        }
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
                Button("Done") { isAmountFocused = false }
            }
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.section) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settle with \(viewModel.recipient)")
                    .font(BarabariTypography.screenTitle)
                Text("Record what already happened. Barabari never moves money.")
                    .font(BarabariTypography.body)
                    .foregroundStyle(BarabariColors.textSecondary)
            }

            BarabariCard {
                VStack(alignment: .leading, spacing: BarabariSpacing.row) {
                    Text("Remaining to settle")
                        .font(BarabariTypography.metadata)
                        .foregroundStyle(BarabariColors.textSecondary)
                    AmountText(
                        minorUnits: viewModel.remainingAmount.minorUnits,
                        currencyCode: viewModel.remainingAmount.currencyCode,
                        style: .title
                    )
                }
            }

            VStack(alignment: .leading, spacing: BarabariSpacing.compact) {
                Text("Amount paid")
                    .font(BarabariTypography.sectionTitle)
                HStack(spacing: BarabariSpacing.compact) {
                    Text("PKR")
                        .foregroundStyle(BarabariColors.textSecondary)
                    TextField("0", text: $viewModel.amount)
                        .keyboardType(.decimalPad)
                        .font(BarabariTypography.amount(for: .title))
                        .monospacedDigit()
                        .focused($isAmountFocused)
                        .accessibilityIdentifier("settlement-amount")
                }
                .padding(BarabariSpacing.card)
                .background(BarabariColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            VStack(alignment: .leading, spacing: BarabariSpacing.row) {
                Text("How was it paid?")
                    .font(BarabariTypography.sectionTitle)
                Text("This only records your payment method.")
                    .font(BarabariTypography.metadata)
                    .foregroundStyle(BarabariColors.textSecondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BarabariSpacing.compact) {
                    ForEach(SettlementMethod.allCases, id: \.self) { method in
                        Button(method.title) {
                            BarabariInteraction.trigger(.selection)
                            viewModel.method = method
                        }
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: max(46, BarabariInteraction.minimumHitSize))
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(viewModel.method == method ? Color.white : BarabariColors.textPrimary)
                            .background(
                                viewModel.method == method ? BarabariColors.accent : BarabariColors.surface,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(BarabariColors.raised, lineWidth: viewModel.method == method ? 0 : 1)
                            }
                    }
                }
            }

            VStack(alignment: .leading, spacing: BarabariSpacing.compact) {
                Text("Note (optional)")
                    .font(BarabariTypography.sectionTitle)
                TextField("Reference or reminder", text: $viewModel.note, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(BarabariSpacing.row)
                    .background(BarabariColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if let message = viewModel.validationMessage {
                StatusBadge(message, style: .danger)
            }

            PrimaryActionButton(viewModel.isSaving ? "Recording..." : "Mark as paid") {
                isAmountFocused = false
                Task {
                    let didSave = await viewModel.save()
                    BarabariInteraction.trigger(didSave ? .success : .error)
                }
            }
            .disabled(viewModel.isSaving)
        }
    }

    private func confirmation(_ settlement: Settlement) -> some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.section) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(BarabariColors.success)
            VStack(alignment: .leading, spacing: BarabariSpacing.compact) {
                Text("Settlement recorded locally")
                    .font(BarabariTypography.screenTitle)
                AmountText(
                    minorUnits: settlement.amount.minorUnits,
                    currencyCode: settlement.amount.currencyCode,
                    style: .title
                )
                Text("\(settlement.method.title) payment to \(viewModel.recipient) is now in this group’s ledger on this iPhone.")
                    .font(BarabariTypography.body)
                    .foregroundStyle(BarabariColors.textSecondary)
            }
            StatusBadge("Saved offline-ready", style: .success)
        }
        .frame(maxWidth: .infinity, minHeight: 320, alignment: .center)
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
}
