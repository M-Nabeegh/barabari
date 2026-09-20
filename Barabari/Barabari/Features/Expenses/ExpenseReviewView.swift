import SwiftUI

struct ExpenseReviewView: View {
    @ObservedObject var viewModel: AddExpenseViewModel

    var body: some View {
        BarabariCard {
            VStack(alignment: .leading, spacing: BarabariSpacing.row) {
                Text("Split preview")
                    .font(BarabariTypography.sectionTitle)

                if viewModel.previewSplits.isEmpty {
                    Text("Enter an amount to check everyone’s share before saving.")
                        .font(BarabariTypography.body)
                        .foregroundStyle(BarabariColors.textSecondary)
                } else {
                    ForEach(viewModel.previewSplits, id: \.userID) { split in
                        HStack {
                            Text(viewModel.memberName(for: split.userID))
                                .font(BarabariTypography.body)
                            Spacer()
                            AmountText(
                                minorUnits: split.amount.minorUnits,
                                currencyCode: split.amount.currencyCode,
                                style: .body
                            )
                        }
                    }
                }
            }
        }
    }
}
