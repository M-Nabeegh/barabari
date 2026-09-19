import Foundation

struct User: Equatable, Codable, Sendable, Identifiable {
    let id: UUID
    let displayName: String
    let createdAt: Date
    let updatedAt: Date
    let revision: Int
    let deletedAt: Date?

    init(
        id: UUID = UUID(),
        displayName: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        revision: Int = 1,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.revision = revision
        self.deletedAt = deletedAt
    }
}
