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
                        Text(LocalizedStringKey(selection.title))
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

            if viewModel.splitSelection == .exact {
                BarabariCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.participantIDs.enumerated()), id: \.element) { index, memberID in
                            if index > 0 { RowDivider(leading: 62) }
                            HStack(spacing: 12) {
                                MemberAvatar(name: viewModel.memberName(for: memberID), seed: memberID, size: 36)
                                Text(viewModel.memberName(for: memberID))
                                    .font(BarabariTypography.body.weight(.medium))
                                Spacer()
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

            if viewModel.splitSelection == .exact,
               let validationMessage = viewModel.validationMessage,
               validationMessage.hasPrefix("Exact amounts") {
                Label(validationMessage, systemImage: "exclamationmark.circle.fill")
                    .font(BarabariTypography.metadata.weight(.medium))
                    .foregroundStyle(BarabariColors.danger)
            }
        }
    }
}
