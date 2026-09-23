import Foundation

protocol GroupRepository {
    func listGroups() async throws -> [Group]
    func createGroup(name: String, description: String?, ownerID: UUID) async throws -> Group
    func members(groupID: UUID) async throws -> [GroupMember]
    func invitePayload(groupID: UUID) async throws -> GroupInvitePayload
    func joinGroup(invite: GroupInvitePayload, userID: UUID) async throws -> GroupJoinOutcome
}
