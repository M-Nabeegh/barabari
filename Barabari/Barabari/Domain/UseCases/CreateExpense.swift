import Foundation

struct ExpenseDraft: Sendable {
    let groupID: UUID
    let title: String
    let note: String?
    let total: Money
    let paidByUserID: UUID
    let participantIDs: [UUID]
    let splitMethod: SplitMethod
    let occurredAt: Date
    let createdByUserID: UUID
}

enum LedgerValidationError: Error, Equatable, Sendable {
    case emptyGroupName
    case emptyExpenseTitle
    case noParticipants
    case unsupportedCurrency
    case nonPositiveAmount
    case payerNotGroupMember(UUID)
    case participantNotGroupMember(UUID)
    case creatorNotGroupMember(UUID)
    case settlementUserNotGroupMember(UUID)
    case sameSettlementUser
}

struct CreateExpense {
    let repository: ExpenseRepository
    let groupRepository: GroupRepository

    func call(draft: ExpenseDraft, idempotencyKey: UUID) async throws -> Expense {
        guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LedgerValidationError.emptyExpenseTitle
        }
        try validateMoney(draft.total)

        let activeMemberIDs = try await activeMemberIDs(in: draft.groupID)
        guard activeMemberIDs.contains(draft.paidByUserID) else {
            throw LedgerValidationError.payerNotGroupMember(draft.paidByUserID)
        }
        guard activeMemberIDs.contains(draft.createdByUserID) else {
            throw LedgerValidationError.creatorNotGroupMember(draft.createdByUserID)
        }
        guard !draft.participantIDs.isEmpty else {
            throw LedgerValidationError.noParticipants
        }
        for participantID in draft.participantIDs where !activeMemberIDs.contains(participantID) {
            throw LedgerValidationError.participantNotGroupMember(participantID)
        }

        let splits = try SplitCalculator.calculate(
            total: draft.total,
            participants: draft.participantIDs,
            method: draft.splitMethod
        )
        let expense = Expense(
            groupID: draft.groupID,
            title: draft.title,
            note: draft.note,
            total: draft.total,
            paidByUserID: draft.paidByUserID,
            splits: splits,
            splitMethod: draft.splitMethod,
            occurredAt: draft.occurredAt,
            createdByUserID: draft.createdByUserID
        )
        return try await repository.saveExpense(expense, idempotencyKey: idempotencyKey)
    }

    private func activeMemberIDs(in groupID: UUID) async throws -> Set<UUID> {
        Set(try await groupRepository.members(groupID: groupID).filter(\.isActive).map(\.userID))
    }

    private func validateMoney(_ money: Money) throws {
        guard money.currencyCode == "PKR" else {
            throw LedgerValidationError.unsupportedCurrency
        }
        guard money.minorUnits > 0 else {
            throw LedgerValidationError.nonPositiveAmount
        }
    }
}
