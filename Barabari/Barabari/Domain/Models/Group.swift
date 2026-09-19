import Foundation

struct Group: Equatable, Codable, Sendable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let ownerID: UUID
    let createdAt: Date
    let updatedAt: Date
    let revision: Int
    let deletedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        description: String?,
        ownerID: UUID,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        revision: Int = 1,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.ownerID = ownerID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.revision = revision
        self.deletedAt = deletedAt
    }
}
