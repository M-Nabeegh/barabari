import SwiftUI

struct ExpenseSplitEditorView: View {
    @ObservedObject var viewModel: AddExpenseViewModel
    var focusedField: FocusState<AddExpenseFocusedField?>.Binding
    @Namespace private var segment

    var body: some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.row) {
            SectionHeader("How should it be split?")

            HStack(spacing: 4) {
                ForEach(ExpenseSplitSelection.allCases) { selection in
                    let isSelected = viewModel.splitSelection == selection
                    Button {
                        BarabariInteraction.trigger(.selection)
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                            viewModel.selectSplit(selection)
                        }
                    } label: {
                        Text(LocalizedStringKey(selection.shortTitle))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isSelected ? BarabariColors.onAccent : BarabariColors.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background {
                                if isSelected {
                                    Capsule()
                                        .fill(BarabariColors.accent.gradient)
                                        .matchedGeometryEffect(id: "split-segment", in: segment)
                                }
                            }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(selection.title)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(4)
            .glassEffect(.regular, in: .capsule)

            if viewModel.splitSelection != .equal {
                BarabariCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.participantIDs.enumerated()), id: \.element) { index, memberID in
                            if index > 0 { RowDivider(leading: 62) }
                            HStack(spacing: 12) {
                                MemberAvatar(name: viewModel.memberName(for: memberID), seed: memberID, size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(viewModel.memberName(for: memberID))
                                        .font(BarabariTypography.body.weight(.medium))
                                    if viewModel.splitSelection != .exact,
                                       let amount = viewModel.previewAmount(for: memberID) {
                                        Text(AmountFormatter.string(minorUnits: amount.minorUnits, currencyCode: amount.currencyCode))
                                            .font(BarabariTypography.metadata)
                                            .foregroundStyle(BarabariColors.textSecondary)
                                            .contentTransition(.numericText())
                                            .accessibilityIdentifier("split-preview-\(memberID.uuidString)")
                                    }
                                }
                                Spacer()
                                input(for: memberID)
                                    .id(AddExpenseScrollAnchor.exactShare(memberID))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                        }
                    }
                }
                .id(AddExpenseScrollAnchor.exactShares)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }

            if viewModel.splitSelection == .percentage {
                percentageFooter
            }

            if viewModel.splitSelection != .equal,
               let validationMessage = viewModel.validationMessage,
               AddExpenseViewModel.isSplitValidation(validationMessage) {
                Label(validationMessage, systemImage: "exclamationmark.circle.fill")
                    .font(BarabariTypography.metadata.weight(.medium))
                    .foregroundStyle(BarabariColors.danger)
            }
        }
    }

    @ViewBuilder
    private func input(for memberID: UUID) -> some View {
        switch viewModel.splitSelection {
        case .equal:
            EmptyView()
        case .exact:
            HStack(spacing: 4) {
                Text("Rs")
                    .font(BarabariTypography.metadata)
                    .foregroundStyle(BarabariColors.textSecondary)
                TextField(
                    "0",
                    text: Binding(
                        get: { viewModel.exactAmountText(for: memberID) },
                        set: { viewModel.updateExactAmount($0, for: memberID) }
                    )
                )
                .keyboardType(.decimalPad)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .multilineTextAlignment(.trailing)
                .focused(focusedField, equals: .exact(memberID))
                .frame(width: 96)
                .accessibilityLabel("Exact share for \(viewModel.memberName(for: memberID))")
                .accessibilityIdentifier("exact-split-amount-\(memberID.uuidString)")
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(BarabariColors.raised, in: .capsule)
        case .percentage:
            HStack(spacing: 4) {
                TextField(
                    "0",
                    text: Binding(
                        get: { viewModel.percentageText(for: memberID) },
                        set: { viewModel.updatePercentage($0, for: memberID) }
                    )
                )
                .keyboardType(.decimalPad)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .multilineTextAlignment(.trailing)
                .focused(focusedField, equals: .exact(memberID))
                .frame(width: 64)
                .accessibilityLabel("Percentage for \(viewModel.memberName(for: memberID))")
                .accessibilityIdentifier("percentage-split-\(memberID.uuidString)")
                Text("%")
                    .font(BarabariTypography.metadata)
                    .foregroundStyle(BarabariColors.textSecondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(BarabariColors.raised, in: .capsule)
        case .shares:
            let count = viewModel.shareCount(for: memberID)
            HStack(spacing: 2) {
                shareButton("minus", label: "Fewer shares for \(viewModel.memberName(for: memberID))", isEnabled: count > 1) {
                    viewModel.setShareCount(count - 1, for: memberID)
                }
                Text("\(count)")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .frame(minWidth: 28)
                    .accessibilityLabel("\(count) shares for \(viewModel.memberName(for: memberID))")
                    .accessibilityIdentifier("share-count-\(memberID.uuidString)")
                shareButton("plus", label: "More shares for \(viewModel.memberName(for: memberID))", isEnabled: count < AddExpenseViewModel.maximumShares) {
                    viewModel.setShareCount(count + 1, for: memberID)
                }
            }
            .padding(.horizontal, 4)
            .frame(height: 44)
            .background(BarabariColors.raised, in: .capsule)
        }
    }

    private func shareButton(_ symbol: String, label: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            BarabariInteraction.trigger(.selection)
            withAnimation(.snappy) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isEnabled ? BarabariColors.accent : BarabariColors.textSecondary.opacity(0.5))
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }

    private var percentageFooter: some View {
        let remaining = viewModel.percentageRemainingBasisPoints
        return HStack {
            SwiftUI.Group {
                if remaining == 0 {
                    Label("Adds up to 100%", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(BarabariColors.accent)
                } else if remaining > 0 {
                    Text("\(AddExpenseViewModel.percentText(basisPoints: remaining))% left to assign")
                        .foregroundStyle(BarabariColors.textSecondary)
                } else {
                    Text("\(AddExpenseViewModel.percentText(basisPoints: -remaining))% over")
                        .foregroundStyle(BarabariColors.danger)
                }
            }
            .font(BarabariTypography.metadata.weight(.medium))
            .accessibilityIdentifier("percentage-remaining")
            Spacer()
            Button("Split evenly") {
                BarabariInteraction.trigger(.selection)
                withAnimation(.snappy) { viewModel.splitPercentagesEvenly() }
            }
            .font(BarabariTypography.metadata.weight(.semibold))
            .tint(BarabariColors.accent)
        }
        .padding(.horizontal, 4)
    }
}
