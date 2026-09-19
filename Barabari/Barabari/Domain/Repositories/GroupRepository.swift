import Foundation

protocol GroupRepository {
    func listGroups() async throws -> [Group]
    func createGroup(name: String, description: String?, ownerID: UUID) async throws -> Group
    func members(groupID: UUID) async throws -> [GroupMember]
}
