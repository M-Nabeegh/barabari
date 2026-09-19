import Foundation

enum ActivityEventKind: String, Codable, Sendable {
    case groupCreated
    case expenseCreated
    case expenseDeleted
    case settlementRecorded
    case memberJoined
    case memberRemoved
}

struct ActivityEvent: Equatable, Codable, Sendable, Identifiable {
    let id: UUID
    let groupID: UUID
    let actorUserID: UUID
    let kind: ActivityEventKind
    let subjectID: UUID
    let occurredAt: Date
    let createdAt: Date
    let revision: Int
    let deletedAt: Date?

    init(
        id: UUID = UUID(),
        groupID: UUID,
        actorUserID: UUID,
        kind: ActivityEventKind,
        subjectID: UUID,
        occurredAt: Date = .now,
        createdAt: Date = .now,
        revision: Int = 1,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.groupID = groupID
        self.actorUserID = actorUserID
        self.kind = kind
        self.subjectID = subjectID
        self.occurredAt = occurredAt
        self.createdAt = createdAt
        self.revision = revision
        self.deletedAt = deletedAt
    }
}
