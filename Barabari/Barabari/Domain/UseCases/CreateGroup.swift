import Foundation

struct CreateGroup {
    let repository: GroupRepository

    func call(name: String, description: String?, ownerID: UUID) async throws -> Group {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LedgerValidationError.emptyGroupName
        }
        return try await repository.createGroup(name: name, description: description, ownerID: ownerID)
    }
}
