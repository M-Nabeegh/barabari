import SwiftUI

struct ExpenseSplitEditorView: View {
    @ObservedObject var viewModel: AddExpenseViewModel
    var focusedField: FocusState<AddExpenseFocusedField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.row) {
            Text("How should it be split?")
                .font(BarabariTypography.sectionTitle)

            HStack(spacing: BarabariSpacing.compact) {
                ForEach(ExpenseSplitSelection.allCases) { selection in
                    Button(selection.title) {
                        viewModel.selectSplit(selection)
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(viewModel.splitSelection == selection ? .white : BarabariColors.accent)
                    .background(
                        viewModel.splitSelection == selection ? BarabariColors.accent : BarabariColors.raised,
                        in: Capsule()
                    )
                    .accessibilityAddTraits(viewModel.splitSelection == selection ? .isSelected : [])
                }
            }

            if viewModel.splitSelection == .exact {
                VStack(alignment: .leading, spacing: BarabariSpacing.compact) {
                    Text("Enter each person’s share")
                        .font(BarabariTypography.metadata)
                        .foregroundStyle(BarabariColors.textSecondary)
                    ForEach(viewModel.participantIDs, id: \.self) { memberID in
                        HStack(spacing: BarabariSpacing.row) {
                            Text(viewModel.memberName(for: memberID))
                                .font(BarabariTypography.body)
                            Spacer()
                            Text("PKR")
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
                            .multilineTextAlignment(.trailing)
                            .focused(focusedField, equals: .exact(memberID))
                            .frame(width: 112, height: 44)
                            .padding(.horizontal, BarabariSpacing.compact)
                            .background(BarabariColors.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .accessibilityIdentifier("exact-split-amount")
                        }
                    }
                }
            }

            if viewModel.splitSelection == .exact,
               let validationMessage = viewModel.validationMessage,
               validationMessage.hasPrefix("Exact amounts") {
                Label(validationMessage, systemImage: "exclamationmark.circle.fill")
                    .font(BarabariTypography.metadata)
                    .foregroundStyle(BarabariColors.danger)
            }
        }
    }
}
