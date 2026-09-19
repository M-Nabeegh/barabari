import SwiftData
import XCTest
@testable import Barabari

final class SwiftDataRepositoryTests: XCTestCase {
    private let ownerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let memberID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    // Catches a persistence layer that drops ledger records or changes their stable IDs.
    func testInMemoryRepositoriesPersistGroupExpenseSettlementAndActivity() async throws {
        let container = try BarabariModelContainer.make(inMemory: true)
        let groups = LocalGroupRepository(container: container)
        let expenses = LocalExpenseRepository(container: container)
        let settlements = LocalSettlementRepository(container: container)

        let group = try await groups.createGroup(
            name: "Flat 404",
            description: "September bills",
            ownerID: ownerID
        )
        let savedGroups = try await groups.listGroups()
        XCTAssertEqual(savedGroups, [group])

        let expense = Expense(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000100")!,
            groupID: group.id,
            title: "Dinner",
            note: "Friday",
            total: Money(minorUnits: 4_800_00, currencyCode: "PKR"),
            paidByUserID: ownerID,
            splits: [
                ExpenseSplit(userID: ownerID, amount: Money(minorUnits: 2_400_00, currencyCode: "PKR")),
                ExpenseSplit(userID: memberID, amount: Money(minorUnits: 2_400_00, currencyCode: "PKR"))
            ],
            splitMethod: .equal,
            occurredAt: Date(timeIntervalSince1970: 1_700_000_000),
            createdByUserID: ownerID,
            createdAt: Date(timeIntervalSince1970: 1_700_000_001),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_002),
            revision: 3
        )
        let savedExpense = try await expenses.saveExpense(expense, idempotencyKey: UUID())
        XCTAssertEqual(savedExpense, expense)
        let fetchedExpenses = try await expenses.listExpenses(groupID: group.id, cursor: nil)
        XCTAssertEqual(fetchedExpenses.items, [expense])

        let settlement = Settlement(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000200")!,
            groupID: group.id,
            fromUserID: memberID,
            toUserID: ownerID,
            amount: Money(minorUnits: 1_000_00, currencyCode: "PKR"),
            method: .raast,
            note: "Paid",
            occurredAt: Date(timeIntervalSince1970: 1_700_000_003),
            createdByUserID: memberID,
            createdAt: Date(timeIntervalSince1970: 1_700_000_004),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_005),
            revision: 2
        )
        let savedSettlement = try await settlements.saveSettlement(settlement, idempotencyKey: UUID())
        XCTAssertEqual(savedSettlement, settlement)
        let fetchedSettlements = try await settlements.listSettlements(groupID: group.id, cursor: nil)
        XCTAssertEqual(fetchedSettlements.items, [settlement])

        let event = ActivityEvent(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000300")!,
            groupID: group.id,
            actorUserID: ownerID,
            kind: .expenseCreated,
            subjectID: expense.id,
            occurredAt: Date(timeIntervalSince1970: 1_700_000_006),
            createdAt: Date(timeIntervalSince1970: 1_700_000_007),
            revision: 4
        )
        let context = ModelContext(container)
        context.insert(StoredActivityEvent(event: event))
        try context.save()
        let savedEvents = try context.fetch(FetchDescriptor<StoredActivityEvent>())
        XCTAssertEqual(savedEvents.first { $0.id == event.id }?.asDomain, event)
    }

    // Catches an implementation that hard-deletes a locally changed expense before sync can reconcile it.
    func testSoftDeletedExpenseIsHiddenFromNormalQueriesButAvailableForSync() async throws {
        let container = try BarabariModelContainer.make(inMemory: true)
        let expenses = LocalExpenseRepository(container: container)
        let groupID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let expenseID = UUID(uuidString: "00000000-0000-0000-0000-000000000020")!
        let expense = Expense(
            id: expenseID,
            groupID: groupID,
            title: "Internet",
            note: nil,
            total: Money(minorUnits: 3_000_00, currencyCode: "PKR"),
            paidByUserID: ownerID,
            splits: [ExpenseSplit(userID: ownerID, amount: Money(minorUnits: 3_000_00, currencyCode: "PKR"))],
            splitMethod: .equal,
            occurredAt: Date(timeIntervalSince1970: 1_700_000_000),
            createdByUserID: ownerID
        )
        _ = try await expenses.saveExpense(expense, idempotencyKey: UUID())

        try await expenses.requestExpenseDeletion(id: expenseID, idempotencyKey: UUID())

        let visibleExpenses = try await expenses.listExpenses(groupID: groupID, cursor: nil)
        XCTAssertTrue(visibleExpenses.items.isEmpty)
        let tombstone = try await expenses.expenseForSync(id: expenseID)
        XCTAssertEqual(tombstone?.id, expenseID)
        XCTAssertNotNil(tombstone?.deletedAt)
        XCTAssertEqual(tombstone?.revision, expense.revision + 1)
    }
}
