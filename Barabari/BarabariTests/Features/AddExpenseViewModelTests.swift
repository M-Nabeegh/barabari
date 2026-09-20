import XCTest
@testable import Barabari

@MainActor
final class AddExpenseViewModelTests: XCTestCase {
    func testEqualExpenseSavesToLocalLedgerInDemoMode() async {
        let viewModel = AddExpenseViewModel(environment: .demo)
        await viewModel.load()
        viewModel.amountText = "1250"
        viewModel.title = "Dinner"

        await viewModel.save()

        XCTAssertNil(viewModel.validationMessage)
        XCTAssertEqual(viewModel.savedExpense?.title, "Dinner")
        XCTAssertEqual(viewModel.savedExpense?.total, Money(minorUnits: 125_000, currencyCode: "PKR"))
    }
}
