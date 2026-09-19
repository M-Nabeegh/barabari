import Foundation

struct Expense: Equatable, Codable, Sendable, Identifiable {
    let id: UUID
    let groupID: UUID
    let title: String
    let note: String?
    let total: Money
    let paidByUserID: UUID
    let splits: [ExpenseSplit]
    let splitMethod: SplitMethod
    let occurredAt: Date
    let createdByUserID: UUID
    let createdAt: Date
    let updatedAt: Date
    let revision: Int
    let deletedAt: Date?

    init(
        id: UUID = UUID(),
        groupID: UUID,
        title: String,
        note: String?,
        total: Money,
        paidByUserID: UUID,
        splits: [ExpenseSplit],
        splitMethod: SplitMethod,
        occurredAt: Date,
        createdByUserID: UUID,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        revision: Int = 1,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.groupID = groupID
        self.title = title
        self.note = note
        self.total = total
        self.paidByUserID = paidByUserID
        self.splits = splits
        self.splitMethod = splitMethod
        self.occurredAt = occurredAt
        self.createdByUserID = createdByUserID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.revision = revision
        self.deletedAt = deletedAt
    }
}
