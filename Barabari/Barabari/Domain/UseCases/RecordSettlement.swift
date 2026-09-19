import Foundation

struct SettlementDraft: Sendable {
    let groupID: UUID
    let fromUserID: UUID
    let toUserID: UUID
    let amount: Money
    let method: SettlementMethod
    let note: String?
    let occurredAt: Date
    let createdByUserID: UUID
}

struct RecordSettlement {
    let repository: SettlementRepository
    let groupRepository: GroupRepository

    func call(draft: SettlementDraft, idempotencyKey: UUID) async throws -> Settlement {
        guard draft.amount.currencyCode == "PKR" else {
            throw LedgerValidationError.unsupportedCurrency
        }
        guard draft.amount.minorUnits > 0 else {
            throw LedgerValidationError.nonPositiveAmount
        }
        guard draft.fromUserID != draft.toUserID else {
            throw LedgerValidationError.sameSettlementUser
        }

        let activeMemberIDs = Set(try await groupRepository.members(groupID: draft.groupID).filter(\.isActive).map(\.userID))
        for userID in [draft.fromUserID, draft.toUserID] where !activeMemberIDs.contains(userID) {
            throw LedgerValidationError.settlementUserNotGroupMember(userID)
        }
        guard activeMemberIDs.contains(draft.createdByUserID) else {
            throw LedgerValidationError.creatorNotGroupMember(draft.createdByUserID)
        }

        let settlement = Settlement(
            groupID: draft.groupID,
            fromUserID: draft.fromUserID,
            toUserID: draft.toUserID,
            amount: draft.amount,
            method: draft.method,
            note: draft.note,
            occurredAt: draft.occurredAt,
            createdByUserID: draft.createdByUserID
        )
        return try await repository.saveSettlement(settlement, idempotencyKey: idempotencyKey)
    }
}
