import SwiftData
import XCTest
@testable import Barabari

final class LocalSyncStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var store: LocalSyncStore!
    private let me = UUID()
    private let friend = UUID()

    override func setUpWithError() throws {
        container = try BarabariModelContainer.make(inMemory: true)
        store = LocalSyncStore(container: container)
    }

    private func groupRow(_ id: UUID = UUID(), name: String = "Hunza Trip", updatedAt: Date = .now, deletedAt: Date? = nil) -> GroupRow {
        GroupRow(Group(id: id, name: name, description: nil, ownerID: friend, createdAt: updatedAt, updatedAt: updatedAt, deletedAt: deletedAt))
    }

    private func expense(group: UUID, total: Int64 = 1_000, updatedAt: Date = .now) -> Expense {
        Expense(
            groupID: group,
            title: "Karahi",
            note: nil,
            total: Money(minorUnits: total, currencyCode: "PKR"),
            paidByUserID: friend,
            splits: [
                ExpenseSplit(userID: me, amount: Money(minorUnits: total / 2, currencyCode: "PKR")),
                ExpenseSplit(userID: friend, amount: Money(minorUnits: total - total / 2, currencyCode: "PKR"))
            ],
            splitMethod: .equal,
            occurredAt: updatedAt,
            createdByUserID: friend,
            createdAt: updatedAt,
            updatedAt: updatedAt
        )
    }

    func testPulledGroupAndExpenseShowUpInTheLedgerWithCorrectBalances() async throws {
        let group = groupRow()
        let member = GroupMember(groupID: group.id, userID: me, role: .member)
        let friendMember = GroupMember(groupID: group.id, userID: friend, role: .owner)
        let pulled = expense(group: group.id)

        let result1 = try await store.apply(groups: [group])


        XCTAssertTrue(result1)
        let result2 = try await store.apply(members: [GroupMemberRow(member, displayName: nil), GroupMemberRow(friendMember, displayName: "Ali")])

        XCTAssertTrue(result2)
        let result3 = try await store.apply(expenses: [ExpenseRow(pulled, category: .food)])

        XCTAssertTrue(result3)

        let groups = try await LocalGroupRepository(container: container).listGroups()
        XCTAssertEqual(groups.map(\.name), ["Hunza Trip"])
        let summary = try await LocalBalanceRepository(container: container).summary(groupID: group.id)
        XCTAssertEqual(summary.netPosition(for: me)?.amount.minorUnits, -500)
    }

    func testApplyingTheSamePullTwiceChangesNothing() async throws {
        let group = groupRow()
        let result4 = try await store.apply(groups: [group])

        XCTAssertTrue(result4)
        let result5 = try await store.apply(groups: [group])

        XCTAssertFalse(result5)
    }

    func testOlderRemoteRowDoesNotOverwriteANewerLocalEdit() async throws {
        let id = UUID()
        let now = Date()
        _ = try await store.apply(groups: [groupRow(id, name: "New name", updatedAt: now)])
        _ = try await store.apply(groups: [groupRow(id, name: "Old name", updatedAt: now.addingTimeInterval(-60))])
        let name = try await LocalGroupRepository(container: container).listGroups().first?.name
        XCTAssertEqual(name, "New name")
    }

    func testDeletionsAreNeverUndone() async throws {
        let group = UUID()
        let original = expense(group: group)
        _ = try await store.apply(groups: [groupRow(group)])
        _ = try await store.apply(expenses: [ExpenseRow(original, category: nil)])

        let deletedAt = Date().addingTimeInterval(5)
        let tombstone = Expense(
            id: original.id, groupID: group, title: original.title, note: nil, total: original.total,
            paidByUserID: original.paidByUserID, splits: original.splits, splitMethod: .equal,
            occurredAt: original.occurredAt, createdByUserID: original.createdByUserID,
            createdAt: original.createdAt, updatedAt: deletedAt, revision: 2, deletedAt: deletedAt
        )
        let result6 = try await store.apply(expenses: [ExpenseRow(tombstone, category: nil)])

        XCTAssertTrue(result6)
        // A stale copy without the tombstone arrives later.
        _ = try await store.apply(expenses: [ExpenseRow(original, category: nil)])

        let visible = try await LocalExpenseRepository(container: container).listExpenses(groupID: group, cursor: nil).items
        XCTAssertTrue(visible.isEmpty)
    }

    func testClaimedSpotMovesSplitsOntoTheNewIdentity() async throws {
        let group = UUID()
        let placeholder = UUID()
        let original = Expense(
            groupID: group, title: "Petrol", note: nil, total: Money(minorUnits: 900, currencyCode: "PKR"),
            paidByUserID: me,
            splits: [
                ExpenseSplit(userID: me, amount: Money(minorUnits: 450, currencyCode: "PKR")),
                ExpenseSplit(userID: placeholder, amount: Money(minorUnits: 450, currencyCode: "PKR"))
            ],
            splitMethod: .equal, occurredAt: .now, createdByUserID: me
        )
        _ = try await store.apply(groups: [groupRow(group)])
        _ = try await store.apply(expenses: [ExpenseRow(original, category: nil)])

        let claimed = Expense(
            id: original.id, groupID: group, title: "Petrol", note: nil, total: original.total,
            paidByUserID: me,
            splits: [
                ExpenseSplit(userID: me, amount: Money(minorUnits: 450, currencyCode: "PKR")),
                ExpenseSplit(userID: friend, amount: Money(minorUnits: 450, currencyCode: "PKR"))
            ],
            splitMethod: .equal, occurredAt: original.occurredAt, createdByUserID: me,
            createdAt: original.createdAt, updatedAt: Date().addingTimeInterval(10), revision: 2
        )
        _ = try await store.apply(expenses: [ExpenseRow(claimed, category: nil)])

        let stored = try await LocalExpenseRepository(container: container).listExpenses(groupID: group, cursor: nil).items
        XCTAssertEqual(Set(stored.first?.splits.map(\.userID) ?? []), [me, friend])
    }

    func testChangesSinceOnlyReturnsNewerLocalWrites() async throws {
        let cutoff = Date()
        _ = try await store.apply(groups: [groupRow(updatedAt: cutoff.addingTimeInterval(-30))])
        let newer = try await LocalGroupRepository(container: container).createGroup(name: "Flat 4B", description: nil, ownerID: me)

        let changes = try await store.changes(since: cutoff)
        XCTAssertEqual(changes.groups.map(\.id), [newer.id])
        XCTAssertEqual(changes.members.count, 1)
        XCTAssertEqual(changes.events.count, 1)
    }
}
