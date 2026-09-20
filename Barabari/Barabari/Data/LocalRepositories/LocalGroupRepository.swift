import Foundation
import SwiftData

final actor LocalGroupRepository: GroupRepository {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func listGroups() throws -> [Group] {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<StoredGroup>())
            .filter { $0.deletedAt == nil }
            .map(\.asDomain)
            .sorted(by: sortGroups)
    }

    func createGroup(name: String, description: String?, ownerID: UUID) throws -> Group {
        let group = Group(name: name, description: description, ownerID: ownerID)
        let owner = GroupMember(groupID: group.id, userID: ownerID, role: .owner)
        let event = ActivityEvent(
            groupID: group.id,
            actorUserID: ownerID,
            kind: .groupCreated,
            subjectID: group.id
        )
        let context = ModelContext(container)
        context.insert(StoredGroup(group: group))
        context.insert(StoredGroupMember(member: owner))
        context.insert(StoredActivityEvent(event: event))
        try context.save()
        return group
    }

    func members(groupID: UUID) throws -> [GroupMember] {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<StoredGroupMember>())
            .filter { $0.groupID == groupID }
            .map(\.asDomain)
            .sorted { uuidBytes($0.userID).lexicographicallyPrecedes(uuidBytes($1.userID)) }
    }

    func upsertMember(_ member: GroupMember) throws {
        let context = ModelContext(container)
        if let existing = try context.fetch(FetchDescriptor<StoredGroupMember>()).first(where: { $0.id == member.id }) {
            existing.apply(member)
        } else {
            context.insert(StoredGroupMember(member: member))
        }
        try context.save()
    }

    func activities(groupID: UUID, includingDeleted: Bool = false) throws -> [ActivityEvent] {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<StoredActivityEvent>())
            .filter { $0.groupID == groupID && (includingDeleted || $0.deletedAt == nil) }
            .map(\.asDomain)
            .sorted { lhs, rhs in
                if lhs.occurredAt != rhs.occurredAt { return lhs.occurredAt > rhs.occurredAt }
                return uuidBytes(lhs.id).lexicographicallyPrecedes(uuidBytes(rhs.id))
            }
    }

    func recentActivities(limit: Int) throws -> [ActivityEvent] {
        let context = ModelContext(container)
        let events = try context.fetch(FetchDescriptor<StoredActivityEvent>())
            .filter { $0.deletedAt == nil }
            .map(\.asDomain)
            .sorted { lhs, rhs in
                if lhs.occurredAt != rhs.occurredAt { return lhs.occurredAt > rhs.occurredAt }
                return uuidBytes(lhs.id).lexicographicallyPrecedes(uuidBytes(rhs.id))
            }
        return Array(events.prefix(max(limit, 0)))
    }

    private func sortGroups(_ lhs: Group, _ rhs: Group) -> Bool {
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        return uuidBytes(lhs.id).lexicographicallyPrecedes(uuidBytes(rhs.id))
    }

    private func uuidBytes(_ id: UUID) -> [UInt8] {
        withUnsafeBytes(of: id.uuid) { Array($0) }
    }
}
