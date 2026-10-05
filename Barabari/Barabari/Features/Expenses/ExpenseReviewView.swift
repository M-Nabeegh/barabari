import SwiftUI

struct ExpenseReviewView: View {
    @ObservedObject var viewModel: AddExpenseViewModel

    private var total: Int64 {
        viewModel.previewSplits.reduce(0) { $0 + $1.amount.minorUnits }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.row) {
            SectionHeader("Split preview")

            BarabariCard(padding: 0) {
                if viewModel.previewSplits.isEmpty {
                    HStack(spacing: 12) {
                        IconTile(systemImage: "chart.pie.fill", color: BarabariColors.textSecondary, size: 36)
                        Text("Enter an amount to check everyone’s share before saving.")
                            .font(BarabariTypography.metadata)
                            .foregroundStyle(BarabariColors.textSecondary)
                    }
                    .padding(14)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.previewSplits.enumerated()), id: \.element.userID) { index, split in
                            if index > 0 { RowDivider(leading: 62) }
                            HStack(spacing: 12) {
                                MemberAvatar(name: viewModel.memberName(for: split.userID), seed: split.userID, size: 36)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(viewModel.memberName(for: split.userID))
                                        .font(BarabariTypography.body.weight(.medium))
                                    shareBar(for: split.amount.minorUnits)
                                }
                                Spacer(minLength: 12)
                                AmountText(
                                    minorUnits: split.amount.minorUnits,
                                    currencyCode: split.amount.currencyCode,
                                    style: .body
                                )
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.previewSplits)
                }
            }
        }
    }

    private func shareBar(for amount: Int64) -> some View {
        let fraction = total > 0 ? CGFloat(amount) / CGFloat(total) : 0
        return Capsule()
            .fill(BarabariColors.raised)
            .frame(height: 5)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(BarabariColors.accent.gradient)
                        .frame(width: max(5, proxy.size.width * fraction))
                }
            }
            .frame(maxWidth: 140)
            .accessibilityHidden(true)
    }
}
