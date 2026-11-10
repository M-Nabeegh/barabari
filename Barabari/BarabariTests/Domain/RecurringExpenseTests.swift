import XCTest
@testable import Barabari

@MainActor
final class RecurringExpenseTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Karachi")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func isolatedDefaults() -> UserDefaults {
        let name = "barabari.tests.recurring.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func savedExpense(
        in environment: AppEnvironment,
        title: String = "Rent",
        on occurredAt: Date
    ) async throws -> Expense {
        let group = try await environment.groupRepository.listGroups().first!
        let draft = ExpenseDraft(
            groupID: group.id,
            title: title,
            note: nil,
            total: Money(minorUnits: 4_500_000, currencyCode: "PKR"),
            paidByUserID: environment.currentUserID,
            participantIDs: [environment.currentUserID],
            splitMethod: .equal,
            occurredAt: occurredAt,
            createdByUserID: environment.currentUserID
        )
        return try await CreateExpense(
            repository: environment.expenseRepository,
            groupRepository: environment.groupRepository
        ).call(draft: draft, idempotencyKey: UUID())
    }

    private func expenses(in environment: AppEnvironment) async throws -> [Expense] {
        let group = try await environment.groupRepository.listGroups().first!
        return try await environment.expenseRepository.listExpenses(groupID: group.id, cursor: nil).items
    }

    func testWeeklyMovesSevenDays() {
        let next = RecurrenceSchedule.next(after: date(2026, 11, 10), frequency: .weekly, anchorDay: 10, calendar: calendar)
        XCTAssertEqual(next, date(2026, 11, 17))
    }

    func testMonthlyKeepsTheDayAndClampsToShortMonths() {
        let february = RecurrenceSchedule.next(after: date(2027, 1, 31), frequency: .monthly, anchorDay: 31, calendar: calendar)
        XCTAssertEqual(february, date(2027, 2, 28))
        let march = RecurrenceSchedule.next(after: february, frequency: .monthly, anchorDay: 31, calendar: calendar)
        XCTAssertEqual(march, date(2027, 3, 31))
        let january = RecurrenceSchedule.next(after: date(2026, 12, 5), frequency: .monthly, anchorDay: 5, calendar: calendar)
        XCTAssertEqual(january, date(2027, 1, 5))
    }

    func testOccurrenceKeysAreStablePerDate() {
        let id = UUID()
        XCTAssertEqual(
            RecurringExpenseStore.occurrenceKey(for: id, dueAt: date(2026, 12, 1)),
            RecurringExpenseStore.occurrenceKey(for: id, dueAt: date(2026, 12, 1))
        )
        XCTAssertNotEqual(
            RecurringExpenseStore.occurrenceKey(for: id, dueAt: date(2026, 12, 1)),
            RecurringExpenseStore.occurrenceKey(for: id, dueAt: date(2027, 1, 1))
        )
    }

    func testDueOccurrencesAreAddedOnceWithTheirCategory() async throws {
        let environment = AppEnvironment(inMemory: true, seedDemoData: true)
        let metadata = LedgerMetadata(defaults: isolatedDefaults())
        let store = RecurringExpenseStore(defaults: isolatedDefaults())
        let before = try await expenses(in: environment).count
        let first = try await savedExpense(in: environment, on: date(2026, 9, 1))
        store.add(from: first, category: .rent, frequency: .monthly)

        // Nothing is due on the day it was set up.
        let none = await store.postDue(environment: environment, metadata: metadata, now: date(2026, 9, 1), calendar: calendar)
        XCTAssertEqual(none, 0)

        // October and November have come due by 10 November.
        let added = await store.postDue(environment: environment, metadata: metadata, now: date(2026, 11, 10), calendar: calendar)
        XCTAssertEqual(added, 2)
        let again = await store.postDue(environment: environment, metadata: metadata, now: date(2026, 11, 10), calendar: calendar)
        XCTAssertEqual(again, 0)

        let all = try await expenses(in: environment)
        XCTAssertEqual(all.count, before + 3)
        let repeats = all.filter { $0.title == "Rent" && $0.id != first.id }
        XCTAssertEqual(Set(repeats.map(\.occurredAt)), [date(2026, 10, 1), date(2026, 11, 1)])
        XCTAssertTrue(repeats.allSatisfy { $0.total == first.total && metadata.category(for: $0) == .rent })
        XCTAssertEqual(store.items.first?.nextDueAt, date(2026, 12, 1))
    }

    func testALongGapAddsAtMostTheCatchUpLimitThenSkipsAhead() async throws {
        let environment = AppEnvironment(inMemory: true, seedDemoData: true)
        let store = RecurringExpenseStore(defaults: isolatedDefaults())
        let first = try await savedExpense(in: environment, title: "Milk", on: date(2026, 1, 5))
        store.add(from: first, category: nil, frequency: .weekly)

        let added = await store.postDue(
            environment: environment, metadata: LedgerMetadata(defaults: isolatedDefaults()),
            now: date(2026, 11, 10), calendar: calendar
        )

        XCTAssertEqual(added, RecurringExpenseStore.catchUpLimit)
        let next = try XCTUnwrap(store.items.first?.nextDueAt)
        XCTAssertGreaterThan(next, date(2026, 11, 10))
        XCTAssertLessThanOrEqual(next, date(2026, 11, 17))
    }

    func testAnExpenseWhosePayerLeftIsPausedInsteadOfAdded() async throws {
        let environment = AppEnvironment(inMemory: true, seedDemoData: true)
        let store = RecurringExpenseStore(defaults: isolatedDefaults())
        let real = try await savedExpense(in: environment, on: date(2026, 9, 1))
        let stranger = UUID()
        let orphaned = Expense(
            groupID: real.groupID, title: "Internet", note: nil, total: real.total,
            paidByUserID: stranger, splits: real.splits, splitMethod: .equal,
            occurredAt: date(2026, 9, 1), createdByUserID: real.createdByUserID
        )
        store.add(from: orphaned, category: .utilities, frequency: .monthly)

        let added = await store.postDue(
            environment: environment, metadata: LedgerMetadata(defaults: isolatedDefaults()),
            now: date(2026, 11, 10), calendar: calendar
        )

        XCTAssertEqual(added, 0)
        XCTAssertEqual(store.items.first?.pausedReason, "Paused because the payer left the group.")
        XCTAssertEqual(store.items.first?.nextDueAt, date(2026, 10, 1))
    }

    func testStoppingRemovesItAndSurvivesARelaunch() async throws {
        let environment = AppEnvironment(inMemory: true, seedDemoData: true)
        let defaults = isolatedDefaults()
        let store = RecurringExpenseStore(defaults: defaults)
        let first = try await savedExpense(in: environment, on: date(2026, 9, 1))
        let item = store.add(from: first, category: .rent, frequency: .monthly)

        XCTAssertEqual(RecurringExpenseStore(defaults: defaults).items, [item])
        XCTAssertEqual(store.items(in: first.groupID).map(\.id), [item.id])

        store.remove(item.id)
        XCTAssertTrue(RecurringExpenseStore(defaults: defaults).items.isEmpty)
    }

    func testSavingWithRepeatSetsUpTheSchedule() async throws {
        let store = RecurringExpenseStore(defaults: isolatedDefaults())
        let viewModel = AddExpenseViewModel(
            environment: AppEnvironment(inMemory: true, seedDemoData: true),
            metadata: LedgerMetadata(defaults: isolatedDefaults()),
            recurring: store
        )
        await viewModel.load()
        viewModel.amountText = "45000"
        viewModel.title = "Flat rent"
        viewModel.repeatFrequency = .monthly

        let saved = await viewModel.save()

        XCTAssertTrue(saved)
        let item = try XCTUnwrap(store.items.first)
        XCTAssertEqual(item.title, "Flat rent")
        XCTAssertEqual(item.frequency, .monthly)
        XCTAssertEqual(item.total.minorUnits, 4_500_000)
        XCTAssertGreaterThan(item.nextDueAt, .now)

        viewModel.addAnotherExpense()
        XCTAssertNil(viewModel.repeatFrequency)
    }
}
