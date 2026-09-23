import Foundation
import SwiftData

private enum LocalActivityCursorCodec {
    static func decode(_ value: String?) throws -> LocalLedgerCursor? {
        guard let value else { return nil }
        guard let data = Data(base64Encoded: value),
              let cursor = try? JSONDecoder().decode(LocalLedgerCursor.self, from: data) else {
            throw LocalPersistenceError.invalidCursor
        }
        return cursor
    }

    static func encode(_ cursor: LocalLedgerCursor) -> String {
        guard let data = try? JSONEncoder().encode(cursor) else {
            preconditionFailure("A keyset cursor made only of a Date and UUID must be encodable.")
        }
        return data.base64EncodedString()
    }
}

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

    func listActivities(limit: Int, cursor: String?) throws -> Page<ActivityEvent> {
        let requestedLimit = max(limit, 1)
        let boundary = try LocalActivityCursorCodec.decode(cursor)
        let predicate: Predicate<StoredActivityEvent>

        if let boundary {
            let boundaryDate = boundary.occurredAt
            let boundaryID = boundary.id
            predicate = #Predicate<StoredActivityEvent> { event in
                event.deletedAt == nil && (
                    event.occurredAt < boundaryDate ||
                    (event.occurredAt == boundaryDate && event.id > boundaryID)
                )
            }
        } else {
            predicate = #Predicate<StoredActivityEvent> { event in
                event.deletedAt == nil
            }
        }

        let context = ModelContext(container)
        var descriptor = FetchDescriptor<StoredActivityEvent>(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\.occurredAt, order: .reverse),
                SortDescriptor(\.id, order: .forward)
            ]
        )
        descriptor.fetchLimit = requestedLimit == Int.max ? Int.max : requestedLimit + 1

        let events = try context.fetch(descriptor).map(\.asDomain)
        let pageItems = Array(events.prefix(requestedLimit))
        let nextCursor: String?
        if events.count > pageItems.count, let last = pageItems.last {
            nextCursor = LocalActivityCursorCodec.encode(
                LocalLedgerCursor(occurredAt: last.occurredAt, id: last.id)
            )
        } else {
            nextCursor = nil
        }
        return Page(items: pageItems, nextCursor: nextCursor)
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

    func invitePayload(groupID: UUID) throws -> GroupInvitePayload {
        let context = ModelContext(container)
        guard let storedGroup = try context.fetch(FetchDescriptor<StoredGroup>())
            .first(where: { $0.id == groupID && $0.deletedAt == nil }) else {
            throw LocalPersistenceError.missingGroup(groupID)
        }
        return GroupInvitePayload(
            version: GroupInvitePayload.currentVersion,
            groupID: storedGroup.id,
            groupName: storedGroup.name,
            groupRevision: storedGroup.revision
        )
    }

    func joinGroup(invite: GroupInvitePayload, userID: UUID) throws -> GroupJoinOutcome {
        let context = ModelContext(container)
        guard let storedGroup = try context.fetch(FetchDescriptor<StoredGroup>())
            .first(where: { $0.id == invite.groupID && $0.deletedAt == nil }) else {
            return .unavailable(invite)
        }

        let group = storedGroup.asDomain
        let storedMembers = try context.fetch(FetchDescriptor<StoredGroupMember>())
        if storedMembers.contains(where: {
            $0.groupID == invite.groupID && $0.userID == userID && $0.removedAt == nil
        }) {
            return .alreadyMember(group)
        }

        let member = GroupMember(groupID: invite.groupID, userID: userID, role: .member)
        let event = ActivityEvent(
            groupID: invite.groupID,
            actorUserID: userID,
            kind: .memberJoined,
            subjectID: member.id
        )
        context.insert(StoredGroupMember(member: member))
        context.insert(StoredActivityEvent(event: event))
        try context.save()
        return .joined(group)
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
