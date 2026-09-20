import SwiftUI

struct ExpenseDetailView: View {
    let expense: Expense

    var body: some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.section) {
            Text(expense.title)
                .font(BarabariTypography.screenTitle)
            AmountText(
                minorUnits: expense.total.minorUnits,
                currencyCode: expense.total.currencyCode,
                style: .hero
            )
            Text("Saved to this iPhone. It will be ready to sync when your group connects.")
                .font(BarabariTypography.body)
                .foregroundStyle(BarabariColors.textSecondary)
        }
        .padding(BarabariSpacing.screen)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(BarabariColors.background)
        .navigationTitle("Expense")
        .navigationBarTitleDisplayMode(.inline)
    }
}
