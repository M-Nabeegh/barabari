import Foundation

enum GroupMemberRole: String, Codable, Sendable {
    case owner
    case member
}

struct GroupMember: Equatable, Codable, Sendable, Identifiable {
    let id: UUID
    let groupID: UUID
    let userID: UUID
    let role: GroupMemberRole
    let joinedAt: Date
    let updatedAt: Date
    let revision: Int
    let removedAt: Date?

    init(
        id: UUID = UUID(),
        groupID: UUID,
        userID: UUID,
        role: GroupMemberRole,
        joinedAt: Date = .now,
        updatedAt: Date = .now,
        revision: Int = 1,
        removedAt: Date? = nil
    ) {
        self.id = id
        self.groupID = groupID
        self.userID = userID
        self.role = role
        self.joinedAt = joinedAt
        self.updatedAt = updatedAt
        self.revision = revision
        self.removedAt = removedAt
    }

    var isActive: Bool {
        removedAt == nil
    }
}
