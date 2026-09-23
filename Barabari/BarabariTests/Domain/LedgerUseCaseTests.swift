import Foundation
import XCTest
@testable import Barabari

final class LedgerUseCaseTests: XCTestCase {
    private let groupID = UUID(uuidString: "00000000-0000-0000-0000-000000000100")!
    private let ownerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let memberID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let outsiderID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    // Catches a change that lets a new group omit its owner from the repository request.
    func testCreateGroupDelegatesOwnerAndMetadataToRepository() async throws {
        let repository = InMemoryGroupRepository(membersByGroup: [:])
        let useCase = CreateGroup(repository: repository)

        let group = try await useCase.call(
            name: "Apartment",
            description: "September bills",
            ownerID: ownerID
        )

        XCTAssertEqual(group.name, "Apartment")
        XCTAssertEqual(group.description, "September bills")
        XCTAssertEqual(group.ownerID, ownerID)
    }

    // Catches a change that lets an expense split include a user who does not belong to its group.
    func testCreateExpenseRejectsParticipantOutsideGroup() async {
        let groups = InMemoryGroupRepository(membersByGroup: [
            groupID: members(in: groupID, users: [ownerID, memberID])
        ])
        let expenses = InMemoryExpenseRepository()
        let useCase = CreateExpense(repository: expenses, groupRepository: groups)

        let draft = expenseDraft(participantIDs: [ownerID, outsiderID])

        await XCTAssertThrowsErrorAsync(try await useCase.call(draft: draft, idempotencyKey: UUID())) { error in
            XCTAssertEqual(error as? LedgerValidationError, .participantNotGroupMember(outsiderID))
        }
        XCTAssertTrue(expenses.savedExpenses.isEmpty)
    }

    // Catches a change that lets a non-member claim they paid a group expense.
    func testCreateExpenseRejectsPayerOutsideGroup() async {
        let groups = InMemoryGroupRepository(membersByGroup: [
            groupID: members(in: groupID, users: [ownerID, memberID])
        ])
        let expenses = InMemoryExpenseRepository()
        let useCase = CreateExpense(repository: expenses, groupRepository: groups)

        let draft = expenseDraft(paidByUserID: outsiderID, participantIDs: [ownerID, memberID])

        await XCTAssertThrowsErrorAsync(try await useCase.call(draft: draft, idempotencyKey: UUID())) { error in
            XCTAssertEqual(error as? LedgerValidationError, .payerNotGroupMember(outsiderID))
        }
        XCTAssertTrue(expenses.savedExpenses.isEmpty)
    }

    // Catches a change that creates splits which do not preserve the original PKR expense amount.
    func testCreateExpensePersistsConservedDeterministicSplits() async throws {
        let groups = InMemoryGroupRepository(membersByGroup: [
            groupID: members(in: groupID, users: [ownerID, memberID])
        ])
        let expenses = InMemoryExpenseRepository()
        let useCase = CreateExpense(repository: expenses, groupRepository: groups)

        let expense = try await useCase.call(
            draft: expenseDraft(total: Money(minorUnits: 101, currencyCode: "PKR")),
            idempotencyKey: UUID()
        )

        XCTAssertEqual(expense.splits.map(\.amount.minorUnits).reduce(0, +), 101)
        XCTAssertEqual(expense.splits.map(\.userID), [ownerID, memberID])
        XCTAssertEqual(expenses.savedExpenses, [expense])
    }

    // Catches a change that makes ledger positions create or destroy money.
    func testBalanceCalculatorConservesNetPositions() throws {
        let expense = Expense(
            id: UUID(),
            groupID: groupID,
            title: "Dinner",
            note: nil,
            total: Money(minorUnits: 1_000, currencyCode: "PKR"),
            paidByUserID: ownerID,
            splits: [
                ExpenseSplit(userID: ownerID, amount: Money(minorUnits: 500, currencyCode: "PKR")),
                ExpenseSplit(userID: memberID, amount: Money(minorUnits: 500, currencyCode: "PKR"))
            ],
            splitMethod: .equal,
            occurredAt: Date(timeIntervalSince1970: 1),
            createdByUserID: ownerID
        )

        let summary = try BalanceCalculator.calculate(
            expenses: [expense],
            settlements: [],
            members: members(in: groupID, users: [ownerID, memberID])
        )

        XCTAssertEqual(summary.netPositions.map(\.amount.minorUnits).reduce(0, +), 0)
        XCTAssertEqual(summary.netPosition(for: ownerID)?.amount, Money(minorUnits: 500, currencyCode: "PKR"))
        XCTAssertEqual(summary.netPosition(for: memberID)?.amount, Money(minorUnits: -500, currencyCode: "PKR"))
    }

    // Catches a change that applies a settlement in the wrong direction or does not reduce the outstanding debt.
    func testSettlementReducesCorrectDebtDirection() throws {
        let expense = Expense(
            id: UUID(),
            groupID: groupID,
            title: "Dinner",
            note: nil,
            total: Money(minorUnits: 1_000, currencyCode: "PKR"),
            paidByUserID: ownerID,
            splits: [
                ExpenseSplit(userID: ownerID, amount: Money(minorUnits: 500, currencyCode: "PKR")),
                ExpenseSplit(userID: memberID, amount: Money(minorUnits: 500, currencyCode: "PKR"))
            ],
            splitMethod: .equal,
            occurredAt: Date(timeIntervalSince1970: 1),
            createdByUserID: ownerID
        )
        let settlement = Settlement(
            id: UUID(),
            groupID: groupID,
            fromUserID: memberID,
            toUserID: ownerID,
            amount: Money(minorUnits: 200, currencyCode: "PKR"),
            method: .raast,
            note: nil,
            occurredAt: Date(timeIntervalSince1970: 2),
            createdByUserID: memberID
        )

        let summary = try BalanceCalculator.calculate(
            expenses: [expense],
            settlements: [settlement],
            members: members(in: groupID, users: [ownerID, memberID])
        )

        XCTAssertEqual(summary.netPosition(for: ownerID)?.amount, Money(minorUnits: 300, currencyCode: "PKR"))
        XCTAssertEqual(summary.netPosition(for: memberID)?.amount, Money(minorUnits: -300, currencyCode: "PKR"))
        XCTAssertEqual(summary.transfers, [
            BalanceTransfer(fromUserID: memberID, toUserID: ownerID, amount: Money(minorUnits: 300, currencyCode: "PKR"))
        ])
    }

    // Catches a change that stores an invalid settlement without preserving its explicit draft details.
    func testRecordSettlementPersistsDraft() async throws {
        let groups = InMemoryGroupRepository(membersByGroup: [
            groupID: members(in: groupID, users: [ownerID, memberID])
        ])
        let settlements = InMemorySettlementRepository()
        let useCase = RecordSettlement(repository: settlements, groupRepository: groups)
        let draft = SettlementDraft(
            groupID: groupID,
            fromUserID: memberID,
            toUserID: ownerID,
            amount: Money(minorUnits: 500, currencyCode: "PKR"),
            method: .easypaisa,
            note: "Sent",
            occurredAt: Date(timeIntervalSince1970: 3),
            createdByUserID: memberID
        )

        let settlement = try await useCase.call(draft: draft, idempotencyKey: UUID())

        XCTAssertEqual(settlement.groupID, groupID)
        XCTAssertEqual(settlement.fromUserID, memberID)
        XCTAssertEqual(settlement.toUserID, ownerID)
        XCTAssertEqual(settlement.amount, draft.amount)
        XCTAssertEqual(settlement.method, .easypaisa)
        XCTAssertEqual(settlements.savedSettlements, [settlement])
    }

    // Catches a change that converts an Int64.min balance to a positive magnitude by trapping instead of reporting overflow.
    func testBalanceCalculatorReportsOverflowForUnrepresentableDebtorMagnitude() {
        let secondCreditorID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
        let firstExpense = Expense(
            groupID: groupID,
            title: "Large bill",
            note: nil,
            total: Money(minorUnits: Int64.max, currencyCode: "PKR"),
            paidByUserID: ownerID,
            splits: [ExpenseSplit(userID: memberID, amount: Money(minorUnits: Int64.max, currencyCode: "PKR"))],
            splitMethod: .exact([memberID: Int64.max]),
            occurredAt: Date(timeIntervalSince1970: 1),
            createdByUserID: ownerID
        )
        let secondExpense = Expense(
            groupID: groupID,
            title: "One paisa",
            note: nil,
            total: Money(minorUnits: 1, currencyCode: "PKR"),
            paidByUserID: secondCreditorID,
            splits: [ExpenseSplit(userID: memberID, amount: Money(minorUnits: 1, currencyCode: "PKR"))],
            splitMethod: .exact([memberID: 1]),
            occurredAt: Date(timeIntervalSince1970: 2),
            createdByUserID: secondCreditorID
        )

        XCTAssertThrowsError(
            try BalanceCalculator.calculate(
                expenses: [firstExpense, secondExpense],
                settlements: [],
                members: members(in: groupID, users: [ownerID, memberID, secondCreditorID])
            )
        ) { error in
            XCTAssertEqual(error as? BalanceCalculationError, .arithmeticOverflow)
        }
    }

    // Catches a change that drops a former member's unresolved debt from historical records.
    func testBalanceCalculatorIncludesFormerMembersInHistoricalLedger() throws {
        let formerMember = GroupMember(
            groupID: groupID,
            userID: memberID,
            role: .member,
            joinedAt: Date(timeIntervalSince1970: 0),
            removedAt: Date(timeIntervalSince1970: 4)
        )
        let expense = Expense(
            groupID: groupID,
            title: "Old dinner",
            note: nil,
            total: Money(minorUnits: 1_000, currencyCode: "PKR"),
            paidByUserID: ownerID,
            splits: [ExpenseSplit(userID: memberID, amount: Money(minorUnits: 1_000, currencyCode: "PKR"))],
            splitMethod: .exact([memberID: 1_000]),
            occurredAt: Date(timeIntervalSince1970: 1),
            createdByUserID: ownerID
        )

        let summary = try BalanceCalculator.calculate(
            expenses: [expense],
            settlements: [],
            members: [
                GroupMember(groupID: groupID, userID: ownerID, role: .owner, joinedAt: Date(timeIntervalSince1970: 0)),
                formerMember
            ]
        )

        XCTAssertEqual(summary.netPosition(for: ownerID)?.amount, Money(minorUnits: 1_000, currencyCode: "PKR"))
        XCTAssertEqual(summary.netPosition(for: memberID)?.amount, Money(minorUnits: -1_000, currencyCode: "PKR"))
    }

    // Catches a change that accepts a persisted expense whose actor never belonged to the group.
    func testBalanceCalculatorRejectsExpenseWithUnknownCreator() {
        let expense = Expense(
            groupID: groupID,
            title: "Dinner",
            note: nil,
            total: Money(minorUnits: 100, currencyCode: "PKR"),
            paidByUserID: ownerID,
            splits: [ExpenseSplit(userID: memberID, amount: Money(minorUnits: 100, currencyCode: "PKR"))],
            splitMethod: .exact([memberID: 100]),
            occurredAt: Date(timeIntervalSince1970: 1),
            createdByUserID: outsiderID
        )

        XCTAssertThrowsError(
            try BalanceCalculator.calculate(
                expenses: [expense],
                settlements: [],
                members: members(in: groupID, users: [ownerID, memberID])
            )
        ) { error in
            XCTAssertEqual(error as? BalanceCalculationError, .unknownMember(self.outsiderID))
        }
    }

    // Catches a change that accepts a persisted settlement whose actor never belonged to the group.
    func testBalanceCalculatorRejectsSettlementWithUnknownCreator() {
        let settlement = Settlement(
            groupID: groupID,
            fromUserID: memberID,
            toUserID: ownerID,
            amount: Money(minorUnits: 100, currencyCode: "PKR"),
            method: .cash,
            note: nil,
            occurredAt: Date(timeIntervalSince1970: 1),
            createdByUserID: outsiderID
        )

        XCTAssertThrowsError(
            try BalanceCalculator.calculate(
                expenses: [],
                settlements: [settlement],
                members: members(in: groupID, users: [ownerID, memberID])
            )
        ) { error in
            XCTAssertEqual(error as? BalanceCalculationError, .unknownMember(self.outsiderID))
        }
    }

    // Catches a change that includes a soft-deleted expense or settlement in the current balance.
    func testBalanceCalculatorIgnoresTombstonedLedgerRecords() throws {
        let tombstoneDate = Date(timeIntervalSince1970: 5)
        let deletedExpense = Expense(
            groupID: groupID,
            title: "Deleted expense",
            note: nil,
            total: Money(minorUnits: 100, currencyCode: "PKR"),
            paidByUserID: ownerID,
            splits: [ExpenseSplit(userID: memberID, amount: Money(minorUnits: 100, currencyCode: "PKR"))],
            splitMethod: .exact([memberID: 100]),
            occurredAt: Date(timeIntervalSince1970: 1),
            createdByUserID: outsiderID,
            deletedAt: tombstoneDate
        )
        let deletedSettlement = Settlement(
            groupID: groupID,
            fromUserID: memberID,
            toUserID: ownerID,
            amount: Money(minorUnits: 100, currencyCode: "PKR"),
            method: .cash,
            note: nil,
            occurredAt: Date(timeIntervalSince1970: 2),
            createdByUserID: outsiderID,
            deletedAt: tombstoneDate
        )

        let summary = try BalanceCalculator.calculate(
            expenses: [deletedExpense],
            settlements: [deletedSettlement],
            members: members(in: groupID, users: [ownerID, memberID])
        )

        XCTAssertEqual(summary.netPosition(for: ownerID)?.amount, Money(minorUnits: 0, currencyCode: "PKR"))
        XCTAssertEqual(summary.netPosition(for: memberID)?.amount, Money(minorUnits: 0, currencyCode: "PKR"))
        XCTAssertTrue(summary.transfers.isEmpty)
    }

    private func expenseDraft(
        total: Money = Money(minorUnits: 1_000, currencyCode: "PKR"),
        paidByUserID: UUID? = nil,
        participantIDs: [UUID]? = nil
    ) -> ExpenseDraft {
        ExpenseDraft(
            groupID: groupID,
            title: "Dinner",
            note: nil,
            total: total,
            paidByUserID: paidByUserID ?? ownerID,
            participantIDs: participantIDs ?? [ownerID, memberID],
            splitMethod: .equal,
            occurredAt: Date(timeIntervalSince1970: 1),
            createdByUserID: ownerID
        )
    }

    private func members(in groupID: UUID, users: [UUID]) -> [GroupMember] {
        users.enumerated().map { index, userID in
            GroupMember(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!,
                groupID: groupID,
                userID: userID,
                role: index == 0 ? .owner : .member,
                joinedAt: Date(timeIntervalSince1970: 0)
            )
        }
    }
}

private final class InMemoryGroupRepository: GroupRepository, @unchecked Sendable {
    private var storedGroups: [Group] = []
    private var membersByGroup: [UUID: [GroupMember]]

    init(membersByGroup: [UUID: [GroupMember]]) {
        self.membersByGroup = membersByGroup
    }

    func listGroups() async throws -> [Group] {
        storedGroups
    }

    func createGroup(name: String, description: String?, ownerID: UUID) async throws -> Group {
        let group = Group(
            id: UUID(),
            name: name,
            description: description,
            ownerID: ownerID,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            revision: 1,
            deletedAt: nil
        )
        storedGroups.append(group)
        membersByGroup[group.id] = [GroupMember(groupID: group.id, userID: ownerID, role: .owner)]
        return group
    }

    func members(groupID: UUID) async throws -> [GroupMember] {
        membersByGroup[groupID] ?? []
    }

    func invitePayload(groupID: UUID) async throws -> GroupInvitePayload {
        guard let group = storedGroups.first(where: { $0.id == groupID }) else {
            throw InMemoryGroupRepositoryError.missingGroup(groupID)
        }
        return GroupInvitePayload(
            version: GroupInvitePayload.currentVersion,
            groupID: group.id,
            groupName: group.name,
            groupRevision: group.revision
        )
    }

    func joinGroup(invite: GroupInvitePayload, userID: UUID) async throws -> GroupJoinOutcome {
        guard let group = storedGroups.first(where: { $0.id == invite.groupID }) else {
            return .unavailable(invite)
        }
        if membersByGroup[invite.groupID, default: []].contains(where: {
            $0.userID == userID && $0.isActive
        }) {
            return .alreadyMember(group)
        }
        membersByGroup[invite.groupID, default: []].append(
            GroupMember(groupID: invite.groupID, userID: userID, role: .member)
        )
        return .joined(group)
    }
}

private enum InMemoryGroupRepositoryError: Error, Equatable {
    case missingGroup(UUID)
}

private final class InMemoryExpenseRepository: ExpenseRepository, @unchecked Sendable {
    private(set) var savedExpenses: [Expense] = []

    func listExpenses(groupID: UUID, cursor: String?) async throws -> Page<Expense> {
        Page(items: savedExpenses.filter { $0.groupID == groupID }, nextCursor: nil)
    }

    func saveExpense(_ expense: Expense, idempotencyKey: UUID) async throws -> Expense {
        savedExpenses.append(expense)
        return expense
    }

    func requestExpenseDeletion(id: UUID, idempotencyKey: UUID) async throws {
        savedExpenses.removeAll { $0.id == id }
    }
}

private final class InMemorySettlementRepository: SettlementRepository, @unchecked Sendable {
    private(set) var savedSettlements: [Settlement] = []

    func listSettlements(groupID: UUID, cursor: String?) async throws -> Page<Settlement> {
        Page(items: savedSettlements.filter { $0.groupID == groupID }, nextCursor: nil)
    }

    func saveSettlement(_ settlement: Settlement, idempotencyKey: UUID) async throws -> Settlement {
        savedSettlements.append(settlement)
        return settlement
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void = { _ in },
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected an error", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
