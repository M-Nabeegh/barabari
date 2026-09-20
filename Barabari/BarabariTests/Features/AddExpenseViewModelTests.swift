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

    func testMalformedCommaAmountsAreRejectedInsteadOfBeingReinterpreted() async {
        for malformedAmount in ["1,2", "1.2,3", "12,34", "1,23,456"] {
            let viewModel = AddExpenseViewModel(environment: .demo)
            await viewModel.load()
            viewModel.amountText = malformedAmount
            viewModel.title = "Dinner"

            await viewModel.save()

            XCTAssertNil(viewModel.savedExpense, "\(malformedAmount) must not be silently reinterpreted")
            XCTAssertEqual(viewModel.validationMessage, "Enter an amount greater than PKR 0.")
        }
    }

    func testGroupedThousandsAmountSavesAsExpected() async {
        let viewModel = AddExpenseViewModel(environment: .demo)
        await viewModel.load()
        viewModel.amountText = "1,250"
        viewModel.title = "Dinner"

        await viewModel.save()

        XCTAssertEqual(viewModel.savedExpense?.total, Money(minorUnits: 125_000, currencyCode: "PKR"))
    }

    func testExactMultiParticipantExpenseSavesDistinctSharesAndPayer() async throws {
        let environment = AppEnvironment(inMemory: true, seedDemoData: true)
        let group = try await environment.groupRepository.listGroups().first!
        let friendID = UUID(uuidString: "A1D2E3F4-5A6B-4C7D-8E9F-001122334455")!
        try await environment.groupRepository.upsertMember(
            GroupMember(groupID: group.id, userID: friendID, role: .member)
        )

        let viewModel = AddExpenseViewModel(environment: environment)
        await viewModel.load()
        viewModel.amountText = "1250"
        viewModel.title = "Groceries"
        viewModel.payerID = friendID
        viewModel.participantIDs = [environment.currentUserID, friendID]
        viewModel.selectSplit(.exact)
        viewModel.updateExactAmount("500", for: environment.currentUserID)
        viewModel.updateExactAmount("750", for: friendID)

        await viewModel.save()

        XCTAssertNil(viewModel.validationMessage)
        XCTAssertEqual(viewModel.savedExpense?.paidByUserID, friendID)
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: (viewModel.savedExpense?.splits ?? []).map { ($0.userID, $0.amount.minorUnits) }),
            [environment.currentUserID: 50_000, friendID: 75_000]
        )
    }
}
