import SwiftData
import XCTest
@testable import Barabari

final class LocalIdentityTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "LocalIdentityTests")
        defaults.removePersistentDomain(forName: "LocalIdentityTests")
    }

    func testFirstLaunchMovesLegacyDataOntoAFreshIdentity() async throws {
        let container = try BarabariModelContainer.make(inMemory: true)
        try BarabariModelContainer.seedDemoData(in: container, includeSecondMember: true, includeDemoDebt: true)

        let identity = try LocalIdentity.resolve(container: container, defaults: defaults)
        XCTAssertNotEqual(identity, LocalIdentity.legacySharedUserID)

        let groups = LocalGroupRepository(container: container)
        let group = try await XCTUnwrapAsync(try await groups.listGroups().first)
        XCTAssertEqual(group.ownerID, identity)
        let memberIDs = try await groups.members(groupID: group.id).map(\.userID)
        XCTAssertTrue(memberIDs.contains(identity))
        XCTAssertFalse(memberIDs.contains(LocalIdentity.legacySharedUserID))

        let expenses = try await LocalExpenseRepository(container: container).listExpenses(groupID: group.id, cursor: nil).items
        let splitUsers = expenses.flatMap(\.splits).map(\.userID)
        XCTAssertTrue(splitUsers.contains(identity))
        XCTAssertFalse(splitUsers.contains(LocalIdentity.legacySharedUserID))

        // Balances still add up after the move.
        let summary = try await LocalBalanceRepository(container: container).summary(groupID: group.id)
        XCTAssertEqual(summary.netPosition(for: identity)?.amount.minorUnits, -100_000)
    }

    func testIdentityIsStableAcrossLaunches() throws {
        let container = try BarabariModelContainer.make(inMemory: true)
        let first = try LocalIdentity.resolve(container: container, defaults: defaults)
        let second = try LocalIdentity.resolve(container: container, defaults: defaults)
        XCTAssertEqual(first, second)
    }

    func testExactSplitKeysAreRemapped() throws {
        let container = try BarabariModelContainer.make(inMemory: true)
        let old = LocalIdentity.legacySharedUserID
        let friend = UUID()
        let expense = Expense(
            groupID: UUID(),
            title: "Rent",
            note: nil,
            total: Money(minorUnits: 300, currencyCode: "PKR"),
            paidByUserID: old,
            splits: [
                ExpenseSplit(userID: old, amount: Money(minorUnits: 100, currencyCode: "PKR")),
                ExpenseSplit(userID: friend, amount: Money(minorUnits: 200, currencyCode: "PKR"))
            ],
            splitMethod: .exact([old: 100, friend: 200]),
            occurredAt: .now,
            createdByUserID: old
        )
        let context = ModelContext(container)
        context.insert(try StoredExpense(expense: expense))
        try context.save()

        let fresh = UUID()
        try LocalIdentity.remapUser(from: old, to: fresh, in: container)

        let stored = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<StoredExpense>()).first)
        let method = try JSONDecoder().decode(SplitMethod.self, from: stored.splitMethodData)
        XCTAssertEqual(method, .exact([fresh: 100, friend: 200]))
        XCTAssertEqual(stored.paidByUserID, fresh)
    }
}

final class SyncWireModelTests: XCTestCase {
    func testExpenseRoundTripsThroughTheWireFormat() throws {
        let me = UUID()
        let friend = UUID()
        let expense = Expense(
            groupID: UUID(),
            title: "Hotel in Karimabad",
            note: nil,
            total: Money(minorUnits: 1_800_000, currencyCode: "PKR"),
            paidByUserID: me,
            splits: [
                ExpenseSplit(userID: me, amount: Money(minorUnits: 900_000, currencyCode: "PKR")),
                ExpenseSplit(userID: friend, amount: Money(minorUnits: 900_000, currencyCode: "PKR"))
            ],
            splitMethod: .exact([me: 900_000, friend: 900_000]),
            occurredAt: Date(timeIntervalSince1970: 1_790_000_000.25),
            createdByUserID: me,
            createdAt: Date(timeIntervalSince1970: 1_790_000_000.5),
            updatedAt: Date(timeIntervalSince1970: 1_790_000_001.125)
        )
        let data = try SyncJSON.encoder().encode(ExpenseRow(expense, category: .travel))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["total_minor"] as? Int, 1_800_000)
        XCTAssertEqual((json["split_method"] as? [String: Any])?["kind"] as? String, "exact")
        XCTAssertEqual(json["category"] as? String, "travel")

        let decoded = try SyncJSON.decoder().decode(ExpenseRow.self, from: data)
        XCTAssertEqual(decoded.domain, expense)
    }

    func testParsesPostgresMicrosecondTimestamps() throws {
        let date = try XCTUnwrap(SyncJSON.date(from: "2026-10-06T12:44:49.123456+00:00"))
        XCTAssertEqual(date.timeIntervalSince1970, 1_791_290_689.123, accuracy: 0.0005)
        XCTAssertNotNil(SyncJSON.date(from: "2026-10-06T12:44:49+00:00"))
        XCTAssertNotNil(SyncJSON.date(from: "2026-10-06 12:44:49.5+00"))
    }

    func testUnknownActivityKindsAreSkipped() throws {
        let raw = """
        {"id":"\(UUID())","group_id":"\(UUID())","actor_user_id":"\(UUID())","kind":"somethingNew",
         "subject_id":"\(UUID())","occurred_at":"2026-10-06T12:00:00+00:00","created_at":"2026-10-06T12:00:00+00:00",
         "revision":1,"deleted_at":null,"server_updated_at":"2026-10-06T12:00:00.1+00:00"}
        """
        let row = try SyncJSON.decoder().decode(ActivityEventRow.self, from: Data(raw.utf8))
        XCTAssertNil(row.domain)
    }
}

private func XCTUnwrapAsync<T>(_ expression: @autoclosure () async throws -> T?, file: StaticString = #filePath, line: UInt = #line) async throws -> T {
    let value = try await expression()
    return try XCTUnwrap(value, file: file, line: line)
}
