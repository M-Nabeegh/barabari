import XCTest
@testable import Barabari

@MainActor
final class AddExpenseViewModelTests: XCTestCase {
    func testSelectingAnotherGroupIgnoresThePreviousGroupThatFinishesLater() async throws {
        let environment = AppEnvironment(inMemory: true)
        let firstGroup = try await environment.groupRepository.createGroup(
            name: "First group",
            description: nil,
            ownerID: environment.currentUserID
        )
        let secondGroup = try await environment.groupRepository.createGroup(
            name: "Second group",
            description: nil,
            ownerID: environment.currentUserID
        )
        let firstMember = GroupMember(groupID: firstGroup.id, userID: environment.currentUserID, role: .owner)
        let secondMember = GroupMember(groupID: secondGroup.id, userID: environment.currentUserID, role: .owner)

        let viewModel = AddExpenseViewModel(environment: environment) { groupID in
            if groupID == secondGroup.id {
                try await Task.sleep(nanoseconds: 100_000_000)
                return [secondMember]
            }
            return [firstMember]
        }
        await viewModel.load()

        viewModel.selectGroup(secondGroup.id)
        viewModel.selectGroup(firstGroup.id)
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(viewModel.selectedGroupID, firstGroup.id)
        XCTAssertEqual(viewModel.members.map(\.groupID), [firstGroup.id])
    }

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

    func testMalformedExactShareCannotSaveOrPersistAnExpense() async throws {
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
        viewModel.participantIDs = [environment.currentUserID, friendID]
        viewModel.selectSplit(.exact)
        viewModel.updateExactAmount("500", for: environment.currentUserID)
        viewModel.updateExactAmount("1..2", for: friendID)

        let didSave = await viewModel.save()
        let page = try await environment.expenseRepository.listExpenses(groupID: group.id, cursor: nil)

        XCTAssertFalse(didSave)
        XCTAssertNil(viewModel.savedExpense)
        XCTAssertEqual(viewModel.validationMessage, "Enter a valid amount for each person.")
        XCTAssertTrue(page.items.isEmpty)
    }

    /// A demo ledger whose first group has two people in it.
    private func twoPersonViewModel() async throws -> (AddExpenseViewModel, [UUID]) {
        let environment = AppEnvironment(inMemory: true, seedDemoData: true)
        let group = try await environment.groupRepository.listGroups().first!
        let friendID = UUID(uuidString: "A1D2E3F4-5A6B-4C7D-8E9F-001122334455")!
        try await environment.groupRepository.upsertMember(
            GroupMember(groupID: group.id, userID: friendID, role: .member)
        )
        let viewModel = AddExpenseViewModel(environment: environment)
        await viewModel.load()
        viewModel.participantIDs = [environment.currentUserID, friendID]
        return (viewModel, [environment.currentUserID, friendID])
    }

    func testPercentageSplitSavesWeightedShares() async throws {
        let (viewModel, people) = try await twoPersonViewModel()
        viewModel.amountText = "1000"
        viewModel.title = "Hotel"
        viewModel.selectSplit(.percentage)
        viewModel.updatePercentage("70", for: people[0])
        viewModel.updatePercentage("30", for: people[1])

        XCTAssertEqual(viewModel.percentageRemainingBasisPoints, 0)
        XCTAssertEqual(viewModel.previewAmount(for: people[0])?.minorUnits, 70_000)

        let saved = await viewModel.save()

        XCTAssertTrue(saved)
        XCTAssertNil(viewModel.validationMessage)
        let expense = try XCTUnwrap(viewModel.savedExpense)
        XCTAssertEqual(expense.splits.first { $0.userID == people[0] }?.amount.minorUnits, 70_000)
        XCTAssertEqual(expense.splits.first { $0.userID == people[1] }?.amount.minorUnits, 30_000)
        XCTAssertEqual(expense.splits.reduce(0) { $0 + $1.amount.minorUnits }, 100_000)
        guard case .percentage = expense.splitMethod else { return XCTFail("Expected a percentage split") }
    }

    func testPercentagesThatDoNotReachOneHundredAreRefusedWithTheGap() async throws {
        let (viewModel, people) = try await twoPersonViewModel()
        viewModel.amountText = "1000"
        viewModel.title = "Hotel"
        viewModel.selectSplit(.percentage)
        viewModel.updatePercentage("60", for: people[0])
        viewModel.updatePercentage("25.5", for: people[1])

        let saved = await viewModel.save()

        XCTAssertFalse(saved)
        XCTAssertNil(viewModel.savedExpense)
        XCTAssertEqual(viewModel.validationMessage, "Percentages must add up to 100%. There is 14.5% left to assign.")
        XCTAssertTrue(AddExpenseViewModel.isSplitValidation(viewModel.validationMessage ?? ""))
    }

    func testSplitEvenlyHandsOutEveryHundredthOfAPercent() async throws {
        let (viewModel, people) = try await twoPersonViewModel()
        let third = UUID()
        viewModel.participantIDs = people + [third]
        viewModel.selectSplit(.percentage)

        viewModel.splitPercentagesEvenly()

        XCTAssertEqual(viewModel.percentageRemainingBasisPoints, 0)
        let texts = viewModel.participantIDs.map { viewModel.percentageText(for: $0) }
        XCTAssertEqual(texts, ["33.34", "33.33", "33.33"])
    }

    func testPercentageInputAcceptsTwoDecimalsAndNothingAboveOneHundred() {
        XCTAssertEqual(AddExpenseViewModel.parseBasisPoints("33.33"), 3_333)
        XCTAssertEqual(AddExpenseViewModel.parseBasisPoints("50"), 5_000)
        XCTAssertEqual(AddExpenseViewModel.parseBasisPoints("12.5"), 1_250)
        XCTAssertEqual(AddExpenseViewModel.parseBasisPoints("100"), 10_000)
        XCTAssertNil(AddExpenseViewModel.parseBasisPoints("100.01"))
        XCTAssertNil(AddExpenseViewModel.parseBasisPoints("1.234"))
        XCTAssertNil(AddExpenseViewModel.parseBasisPoints("-5"))
        XCTAssertNil(AddExpenseViewModel.parseBasisPoints("abc"))
        XCTAssertNil(AddExpenseViewModel.parseBasisPoints(""))
        XCTAssertEqual(AddExpenseViewModel.percentText(basisPoints: 3_333), "33.33")
        XCTAssertEqual(AddExpenseViewModel.percentText(basisPoints: 1_250), "12.5")
        XCTAssertEqual(AddExpenseViewModel.percentText(basisPoints: 5_000), "50")
    }

    func testSharesSplitInProportionAndAddUpToTheTotal() async throws {
        let (viewModel, people) = try await twoPersonViewModel()
        viewModel.amountText = "900"
        viewModel.title = "Petrol"
        viewModel.selectSplit(.shares)
        viewModel.setShareCount(2, for: people[0])

        XCTAssertEqual(viewModel.shareCount(for: people[1]), 1)
        XCTAssertEqual(viewModel.previewAmount(for: people[0])?.minorUnits, 60_000)

        let saved = await viewModel.save()

        XCTAssertTrue(saved)
        let expense = try XCTUnwrap(viewModel.savedExpense)
        XCTAssertEqual(expense.splits.first { $0.userID == people[0] }?.amount.minorUnits, 60_000)
        XCTAssertEqual(expense.splits.first { $0.userID == people[1] }?.amount.minorUnits, 30_000)
        guard case .shares = expense.splitMethod else { return XCTFail("Expected a shares split") }
    }

    func testShareCountsStayBetweenOneAndTheMaximum() async throws {
        let (viewModel, people) = try await twoPersonViewModel()
        let person = people[0]
        viewModel.selectSplit(.shares)

        viewModel.setShareCount(0, for: person)
        XCTAssertEqual(viewModel.shareCount(for: person), 1)

        viewModel.setShareCount(500, for: person)
        XCTAssertEqual(viewModel.shareCount(for: person), AddExpenseViewModel.maximumShares)
    }
}

@MainActor
final class PersonalEntryTests: XCTestCase {
    func testJustMeSavesToTheChosenWalletAndWarnsNearTheBudget() async throws {
        let environment = AppEnvironment(inMemory: true)
        let finance = environment.personalFinance
        let bank = try finance.addWallet(name: "Meezan", kind: .bank, openingMinor: 1_000_000)
        try finance.setBudget(100_000, for: .food)

        let viewModel = AddExpenseViewModel(environment: environment)
        await viewModel.load()
        XCTAssertTrue(viewModel.isPersonal, "with no groups, Add starts in Just me")

        viewModel.personalWalletID = bank.id
        viewModel.amountText = "900"
        viewModel.title = "Biryani"
        XCTAssertEqual(viewModel.category, .food)

        let saved = await viewModel.savePersonal()
        XCTAssertTrue(saved)
        XCTAssertEqual(viewModel.savedPersonal?.expenseCategory, .food)
        XCTAssertEqual(finance.balance(of: bank.id), 910_000)
        XCTAssertEqual(viewModel.budgetAlert?.level, .close)
    }

    func testIncomeUsesIncomeCategories() async throws {
        let environment = AppEnvironment(inMemory: true)
        let viewModel = AddExpenseViewModel(environment: environment)
        await viewModel.load()
        viewModel.personalKind = .income
        viewModel.amountText = "150000"
        viewModel.title = "October salary"
        XCTAssertEqual(viewModel.incomeCategory, .salary)

        let saved = await viewModel.savePersonal()
        XCTAssertTrue(saved)
        XCTAssertEqual(environment.personalFinance.income(in: .current), 15_000_000)
        XCTAssertNil(viewModel.budgetAlert)
    }

    func testInvalidAmountShowsAMessage() async {
        let environment = AppEnvironment(inMemory: true)
        let viewModel = AddExpenseViewModel(environment: environment)
        await viewModel.load()
        viewModel.amountText = "0"
        let saved = await viewModel.savePersonal()
        XCTAssertFalse(saved)
        XCTAssertNotNil(viewModel.validationMessage)
    }
}
