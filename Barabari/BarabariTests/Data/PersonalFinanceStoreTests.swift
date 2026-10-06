import XCTest
@testable import Barabari

@MainActor
final class PersonalFinanceStoreTests: XCTestCase {
    private var store: PersonalFinanceStore!

    override func setUpWithError() throws {
        store = try PersonalFinanceStore(inMemory: true)
    }

    private var cash: Wallet { store.activeWallets[0] }

    func testStartsWithACashWallet() {
        XCTAssertEqual(store.activeWallets.map(\.name), ["Cash"])
        XCTAssertEqual(store.totalBalance, 0)
    }

    func testBalancesFollowIncomeAndSpendingPerWallet() throws {
        let bank = try store.addWallet(name: "Meezan", kind: .bank, openingMinor: 5_000_000)
        try store.addTransaction(kind: .income, title: "Salary", amountMinor: 15_000_000, categoryRaw: IncomeCategory.salary.rawValue, walletID: bank.id)
        try store.addTransaction(kind: .expense, title: "Groceries", amountMinor: 1_250_000, categoryRaw: ExpenseCategory.groceries.rawValue, walletID: bank.id)
        try store.addTransaction(kind: .expense, title: "Chai", amountMinor: 20_000, categoryRaw: ExpenseCategory.food.rawValue, walletID: cash.id)

        XCTAssertEqual(store.balance(of: bank.id), 18_750_000)
        XCTAssertEqual(store.balance(of: cash.id), -20_000)
        XCTAssertEqual(store.totalBalance, 18_730_000)
    }

    func testRejectsZeroAmountsAndBlankWalletNames() {
        XCTAssertThrowsError(try store.addTransaction(kind: .expense, title: "x", amountMinor: 0, categoryRaw: "food", walletID: cash.id))
        XCTAssertThrowsError(try store.addWallet(name: "   ", kind: .bank, openingMinor: 0))
    }

    func testBlankTitleFallsBackToTheCategoryName() throws {
        let saved = try store.addTransaction(kind: .expense, title: " ", amountMinor: 500, categoryRaw: ExpenseCategory.transport.rawValue, walletID: cash.id)
        XCTAssertEqual(saved.title, "Transport")
    }

    func testMonthlySpendingIncludesYourShareOfGroupExpenses() throws {
        try store.addTransaction(kind: .expense, title: "Pizza", amountMinor: 300_000, categoryRaw: ExpenseCategory.food.rawValue, walletID: cash.id)
        let lastMonth = MonthPeriod.current.previous.start.addingTimeInterval(3600)
        try store.addTransaction(kind: .expense, title: "Old", amountMinor: 999_900, categoryRaw: ExpenseCategory.food.rawValue, walletID: cash.id, occurredAt: lastMonth)

        let me = UUID()
        let groupDinner = Expense(groupID: UUID(), title: "Karahi", note: nil, total: Money(minorUnits: 600_000, currencyCode: "PKR"),
                                  paidByUserID: UUID(),
                                  splits: [ExpenseSplit(userID: me, amount: Money(minorUnits: 200_000, currencyCode: "PKR")),
                                           ExpenseSplit(userID: UUID(), amount: Money(minorUnits: 400_000, currencyCode: "PKR"))],
                                  splitMethod: .exact([:]), occurredAt: .now, createdByUserID: me)
        let shares = GroupShareCalculator.shares(expenses: [groupDinner], currentUserID: me, month: .current) { _ in .food }

        XCTAssertEqual(store.spending(in: .current, groupShares: shares)[.food], 500_000)
    }

    func testBudgetProgressLevels() throws {
        try store.setBudget(1_000_000, for: .food)
        try store.setBudget(1_000_000, for: .transport)
        try store.addTransaction(kind: .expense, title: "Dinner", amountMinor: 850_000, categoryRaw: "food", walletID: cash.id)
        try store.addTransaction(kind: .expense, title: "Petrol", amountMinor: 1_200_000, categoryRaw: "transport", walletID: cash.id)

        let progress = store.budgetProgress(in: .current)
        XCTAssertEqual(progress.map(\.category), [.transport, .food])
        XCTAssertEqual(progress.map(\.level), [.over, .close])

        try store.setBudget(nil, for: .transport)
        XCTAssertEqual(store.budgetProgress(in: .current).map(\.category), [.food])
    }

    func testArchivingKeepsHistoryAndNeverRemovesTheLastWallet() throws {
        try store.archiveWallet(id: cash.id)
        XCTAssertEqual(store.activeWallets.count, 1, "the only wallet stays")

        let bank = try store.addWallet(name: "HBL", kind: .bank, openingMinor: 0)
        try store.addTransaction(kind: .expense, title: "Bill", amountMinor: 100, categoryRaw: "utilities", walletID: bank.id)
        try store.archiveWallet(id: bank.id)
        XCTAssertEqual(store.activeWallets.map(\.name), ["Cash"])
        XCTAssertEqual(store.transactions.count, 1)
    }

    func testDeleteTransaction() throws {
        let saved = try store.addTransaction(kind: .expense, title: "Oops", amountMinor: 100, categoryRaw: "other", walletID: cash.id)
        try store.deleteTransaction(id: saved.id)
        XCTAssertTrue(store.transactions.isEmpty)
    }

    func testMonthPeriodNavigation() {
        let month = MonthPeriod(containing: Date(timeIntervalSince1970: 1_791_290_689))
        XCTAssertTrue(month.contains(Date(timeIntervalSince1970: 1_791_290_689)))
        XCTAssertEqual(month.next.previous, month)
        XCTAssertFalse(month.next.contains(Date(timeIntervalSince1970: 1_791_290_689)))
    }
}
