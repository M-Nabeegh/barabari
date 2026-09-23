import SwiftData
import XCTest
@testable import Barabari

final class SwiftDataRepositoryTests: XCTestCase {
    private let ownerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let memberID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    // Catches a join implementation that creates duplicate memberships or duplicate activity on replay.
    func testLocalInviteJoinIsIdempotentAndRecordsMemberActivity() async throws {
        let container = try BarabariModelContainer.make(inMemory: true)
        let repository = LocalGroupRepository(container: container)
        let group = try await repository.createGroup(name: "Flat 404", description: nil, ownerID: ownerID)
        let invite = try await repository.invitePayload(groupID: group.id)

        XCTAssertEqual(
            invite,
            GroupInvitePayload(
                version: GroupInvitePayload.currentVersion,
                groupID: group.id,
                groupName: group.name,
                groupRevision: group.revision
            )
        )

        let first = try await repository.joinGroup(invite: invite, userID: memberID)
        let second = try await repository.joinGroup(invite: invite, userID: memberID)
        let membersAfterJoin = try await repository.members(groupID: group.id)
        let joinActivities = try await repository.activities(groupID: group.id)

        XCTAssertEqual(first, .joined(group))
        XCTAssertEqual(second, .alreadyMember(group))
        XCTAssertEqual(membersAfterJoin.filter(\.isActive).count, 2)
        XCTAssertEqual(membersAfterJoin.filter { $0.userID == memberID && $0.isActive }.count, 1)
        XCTAssertEqual(joinActivities.filter { $0.kind == .memberJoined }.count, 1)
    }

    // Catches a join implementation that creates a phantom group for an invite unknown to this local store.
    func testLocalInviteJoinReturnsUnavailableWithoutPersistingAnything() async throws {
        let container = try BarabariModelContainer.make(inMemory: true)
        let repository = LocalGroupRepository(container: container)
        let missingGroupID = UUID(uuidString: "00000000-0000-0000-0000-000000000999")!
        let invite = GroupInvitePayload(
            version: GroupInvitePayload.currentVersion,
            groupID: missingGroupID,
            groupName: "Shared trip",
            groupRevision: 1
        )

        let outcome = try await repository.joinGroup(invite: invite, userID: memberID)
        let groupsAfterJoin = try await repository.listGroups()
        let membersAfterJoin = try await repository.members(groupID: missingGroupID)
        let activitiesAfterJoin = try await repository.activities(groupID: missingGroupID)

        XCTAssertEqual(outcome, .unavailable(invite))
        XCTAssertTrue(groupsAfterJoin.isEmpty)
        XCTAssertTrue(membersAfterJoin.isEmpty)
        XCTAssertTrue(activitiesAfterJoin.isEmpty)
    }

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

    // Catches offset pagination, which repeats or skips records when another expense is inserted between pages.
    func testExpenseKeysetCursorStaysStableWhenRecordsChangeBetweenPages() async throws {
        let container = try BarabariModelContainer.make(inMemory: true)
        let repository = LocalExpenseRepository(container: container)
        let groupID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!

        for index in 0...50 {
            let expense = makeExpense(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", 1_000 + index))!,
                groupID: groupID,
                occurredAt: Date(timeIntervalSince1970: 2_000 - Double(index))
            )
            _ = try await repository.saveExpense(expense, idempotencyKey: UUID())
        }

        let firstPage = try await repository.listExpenses(groupID: groupID, cursor: nil)
        XCTAssertEqual(firstPage.items.count, 50)
        XCTAssertNotNil(firstPage.nextCursor)

        let insertedBetweenPages = makeExpense(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000009999")!,
            groupID: groupID,
            occurredAt: Date(timeIntervalSince1970: 1_949.5)
        )
        _ = try await repository.saveExpense(insertedBetweenPages, idempotencyKey: UUID())

        let secondPage = try await repository.listExpenses(groupID: groupID, cursor: firstPage.nextCursor)
        XCTAssertTrue(Set(firstPage.items.map(\.id)).isDisjoint(with: Set(secondPage.items.map(\.id))))
        XCTAssertEqual(Set(secondPage.items.map(\.id)), Set([insertedBetweenPages.id, UUID(uuidString: "00000000-0000-0000-0000-000000001050")!]))
    }

    // Catches idempotency scoped only to a repository actor rather than the durable store.
    func testExpenseIdempotencySurvivesNewRepositoryInstances() async throws {
        let container = try BarabariModelContainer.make(inMemory: true)
        let firstRepository = LocalExpenseRepository(container: container)
        let secondRepository = LocalExpenseRepository(container: container)
        let groupID = UUID(uuidString: "00000000-0000-0000-0000-000000000112")!
        let commandID = UUID(uuidString: "00000000-0000-0000-0000-000000000113")!
        let original = makeExpense(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000114")!,
            groupID: groupID,
            occurredAt: Date(timeIntervalSince1970: 1_000)
        )
        let duplicateCommandWithDifferentPayload = makeExpense(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000115")!,
            groupID: groupID,
            occurredAt: Date(timeIntervalSince1970: 999)
        )

        let firstResult = try await firstRepository.saveExpense(original, idempotencyKey: commandID)
        let replayResult = try await secondRepository.saveExpense(duplicateCommandWithDifferentPayload, idempotencyKey: commandID)

        XCTAssertEqual(firstResult, original)
        XCTAssertEqual(replayResult, original)
        let storedExpenseIDs = try await secondRepository.expensesForSync(groupID: groupID).map(\.id)
        XCTAssertEqual(storedExpenseIDs, [original.id])
    }

    // Catches settlement replay behavior that diverges from expense replay behavior after a repository restart.
    func testSettlementIdempotencySurvivesNewRepositoryInstances() async throws {
        let container = try BarabariModelContainer.make(inMemory: true)
        let firstRepository = LocalSettlementRepository(container: container)
        let secondRepository = LocalSettlementRepository(container: container)
        let groupID = UUID(uuidString: "00000000-0000-0000-0000-000000000118")!
        let commandID = UUID(uuidString: "00000000-0000-0000-0000-000000000119")!
        let original = makeSettlement(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000120")!,
            groupID: groupID,
            occurredAt: Date(timeIntervalSince1970: 1_000)
        )
        let replayPayload = makeSettlement(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000121")!,
            groupID: groupID,
            occurredAt: Date(timeIntervalSince1970: 999)
        )

        _ = try await firstRepository.saveSettlement(original, idempotencyKey: commandID)
        let replayResult = try await secondRepository.saveSettlement(replayPayload, idempotencyKey: commandID)

        XCTAssertEqual(replayResult, original)
        let storedIDs = try await secondRepository.settlementsForSync(groupID: groupID).map(\.id)
        XCTAssertEqual(storedIDs, [original.id])
    }

    // Catches a settlement cursor that is an array offset and therefore duplicates entries after a mutation.
    func testSettlementKeysetCursorStaysStableWhenRecordsChangeBetweenPages() async throws {
        let container = try BarabariModelContainer.make(inMemory: true)
        let repository = LocalSettlementRepository(container: container)
        let groupID = UUID(uuidString: "00000000-0000-0000-0000-000000000122")!

        for index in 0...50 {
            let settlement = makeSettlement(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", 2_000 + index))!,
                groupID: groupID,
                occurredAt: Date(timeIntervalSince1970: 3_000 - Double(index))
            )
            _ = try await repository.saveSettlement(settlement, idempotencyKey: UUID())
        }
        let firstPage = try await repository.listSettlements(groupID: groupID, cursor: nil)
        let insertedBetweenPages = makeSettlement(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000008888")!,
            groupID: groupID,
            occurredAt: Date(timeIntervalSince1970: 2_949.5)
        )
        _ = try await repository.saveSettlement(insertedBetweenPages, idempotencyKey: UUID())

        let secondPage = try await repository.listSettlements(groupID: groupID, cursor: firstPage.nextCursor)
        XCTAssertTrue(Set(firstPage.items.map(\.id)).isDisjoint(with: Set(secondPage.items.map(\.id))))
        XCTAssertEqual(Set(secondPage.items.map(\.id)), Set([insertedBetweenPages.id, UUID(uuidString: "00000000-0000-0000-0000-000000002050")!]))
    }

    // Catches a replacement that leaves stale split rows behind after an expense edit.
    func testExpenseReplacementUpdatesTheStoredSplitSet() async throws {
        let container = try BarabariModelContainer.make(inMemory: true)
        let repository = LocalExpenseRepository(container: container)
        let groupID = UUID(uuidString: "00000000-0000-0000-0000-000000000116")!
        let expenseID = UUID(uuidString: "00000000-0000-0000-0000-000000000117")!
        let initial = Expense(
            id: expenseID,
            groupID: groupID,
            title: "Groceries",
            note: nil,
            total: Money(minorUnits: 1_000_00, currencyCode: "PKR"),
            paidByUserID: ownerID,
            splits: [
                ExpenseSplit(userID: ownerID, amount: Money(minorUnits: 500_00, currencyCode: "PKR")),
                ExpenseSplit(userID: memberID, amount: Money(minorUnits: 500_00, currencyCode: "PKR"))
            ],
            splitMethod: .equal,
            occurredAt: Date(timeIntervalSince1970: 1_000),
            createdByUserID: ownerID,
            revision: 1
        )
        let updated = Expense(
            id: expenseID,
            groupID: groupID,
            title: "Groceries",
            note: "Corrected",
            total: Money(minorUnits: 1_000_00, currencyCode: "PKR"),
            paidByUserID: ownerID,
            splits: [ExpenseSplit(userID: ownerID, amount: Money(minorUnits: 1_000_00, currencyCode: "PKR"))],
            splitMethod: .equal,
            occurredAt: Date(timeIntervalSince1970: 1_000),
            createdByUserID: ownerID,
            revision: 2
        )

        _ = try await repository.saveExpense(initial, idempotencyKey: UUID())
        _ = try await repository.saveExpense(updated, idempotencyKey: UUID())

        let storedExpense = try await repository.expenseForSync(id: expenseID)
        XCTAssertEqual(storedExpense, updated)
    }

    // Catches future schema changes that remove the V1 migration path without updating the plan.
    func testVersionOneSchemaIsRegisteredWithMigrationPlan() {
        XCTAssertEqual(BarabariSchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
        XCTAssertEqual(BarabariMigrationPlan.schemas.count, 1)
    }

    // Catches a local balance adapter that ignores persisted split or settlement rows during reconstruction.
    func testLocalBalanceRepositoryReconstructsPersistedLedger() async throws {
        let container = try BarabariModelContainer.make(inMemory: true)
        let groups = LocalGroupRepository(container: container)
        let expenses = LocalExpenseRepository(container: container)
        let settlements = LocalSettlementRepository(container: container)
        let balances = LocalBalanceRepository(container: container)
        let group = try await groups.createGroup(name: "Flat", description: nil, ownerID: ownerID)
        try await groups.upsertMember(GroupMember(groupID: group.id, userID: memberID, role: .member))
        let expense = Expense(
            groupID: group.id,
            title: "Dinner",
            note: nil,
            total: Money(minorUnits: 1_000_00, currencyCode: "PKR"),
            paidByUserID: ownerID,
            splits: [
                ExpenseSplit(userID: ownerID, amount: Money(minorUnits: 500_00, currencyCode: "PKR")),
                ExpenseSplit(userID: memberID, amount: Money(minorUnits: 500_00, currencyCode: "PKR"))
            ],
            splitMethod: .equal,
            occurredAt: Date(timeIntervalSince1970: 1_000),
            createdByUserID: ownerID
        )
        _ = try await expenses.saveExpense(expense, idempotencyKey: UUID())
        _ = try await settlements.saveSettlement(
            makeSettlement(id: UUID(), groupID: group.id, occurredAt: Date(timeIntervalSince1970: 1_001), amount: 200_00),
            idempotencyKey: UUID()
        )

        let summary = try await balances.summary(groupID: group.id)
        XCTAssertEqual(summary.netPosition(for: ownerID)?.amount, Money(minorUnits: 300_00, currencyCode: "PKR"))
        XCTAssertEqual(summary.netPosition(for: memberID)?.amount, Money(minorUnits: -300_00, currencyCode: "PKR"))
    }

    private func makeExpense(id: UUID, groupID: UUID, occurredAt: Date) -> Expense {
        Expense(
            id: id,
            groupID: groupID,
            title: "Test expense",
            note: nil,
            total: Money(minorUnits: 100_00, currencyCode: "PKR"),
            paidByUserID: ownerID,
            splits: [ExpenseSplit(userID: ownerID, amount: Money(minorUnits: 100_00, currencyCode: "PKR"))],
            splitMethod: .equal,
            occurredAt: occurredAt,
            createdByUserID: ownerID
        )
    }

    private func makeSettlement(id: UUID, groupID: UUID, occurredAt: Date, amount: Int64 = 100_00) -> Settlement {
        Settlement(
            id: id,
            groupID: groupID,
            fromUserID: memberID,
            toUserID: ownerID,
            amount: Money(minorUnits: amount, currencyCode: "PKR"),
            method: .raast,
            note: nil,
            occurredAt: occurredAt,
            createdByUserID: memberID
        )
    }
}
