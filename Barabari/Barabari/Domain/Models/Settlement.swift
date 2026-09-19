import Foundation

enum SettlementMethod: String, Codable, Sendable {
    case cash
    case raast
    case bankTransfer
    case easypaisa
    case jazzcash
    case other
}

struct Settlement: Equatable, Codable, Sendable, Identifiable {
    let id: UUID
    let groupID: UUID
    let fromUserID: UUID
    let toUserID: UUID
    let amount: Money
    let method: SettlementMethod
    let note: String?
    let occurredAt: Date
    let createdByUserID: UUID
    let createdAt: Date
    let updatedAt: Date
    let revision: Int
    let deletedAt: Date?

    init(
        id: UUID = UUID(),
        groupID: UUID,
        fromUserID: UUID,
        toUserID: UUID,
        amount: Money,
        method: SettlementMethod,
        note: String?,
        occurredAt: Date,
        createdByUserID: UUID,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        revision: Int = 1,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.groupID = groupID
        self.fromUserID = fromUserID
        self.toUserID = toUserID
        self.amount = amount
        self.method = method
        self.note = note
        self.occurredAt = occurredAt
        self.createdByUserID = createdByUserID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.revision = revision
        self.deletedAt = deletedAt
    }
}
