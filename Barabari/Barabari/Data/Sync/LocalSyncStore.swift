import Foundation
import SwiftData

/// Everything written on this phone since the last successful push.
struct LocalChangeSet: Sendable {
    var groups: [Group] = []
    var members: [GroupMember] = []
    var expenses: [Expense] = []
    var settlements: [Settlement] = []
    var events: [ActivityEvent] = []

    var isEmpty: Bool {
        groups.isEmpty && members.isEmpty && expenses.isEmpty && settlements.isEmpty && events.isEmpty
    }
}

/// Reads local changes for the push and merges pulled rows into SwiftData.
///
/// Merging follows the same rules as the server: the newest `updatedAt` wins and
/// a tombstone is never undone. Rows are matched by id, so applying the same
/// pull twice is harmless.
final actor LocalSyncStore {
    private let container: ModelContainer
    /// Timestamps lose sub-millisecond precision on the round trip through Postgres.
    private let tolerance: TimeInterval = 0.001

    init(container: ModelContainer) {
        self.container = container
    }

    // MARK: Push side

    func changes(since: Date?) throws -> LocalChangeSet {
        let context = ModelContext(container)
        func isNew(_ date: Date) -> Bool { since.map { date > $0 } ?? true }

        var set = LocalChangeSet()
        set.groups = try context.fetch(FetchDescriptor<StoredGroup>())
            .filter { isNew($0.updatedAt) }
            .map(\.asDomain)
        set.members = try context.fetch(FetchDescriptor<StoredGroupMember>())
            .filter { isNew($0.updatedAt) }
            .map(\.asDomain)

        let changedExpenses = try context.fetch(FetchDescriptor<StoredExpense>()).filter { isNew($0.updatedAt) }
        if !changedExpenses.isEmpty {
            let splits = Dictionary(grouping: try context.fetch(FetchDescriptor<StoredExpenseSplit>()), by: \.expenseID)
            set.expenses = changedExpenses.compactMap { record in
                try? record.asDomain(splits: (splits[record.id] ?? []).map(\.asDomain))
            }
        }
        set.settlements = try context.fetch(FetchDescriptor<StoredSettlement>())
            .filter { isNew($0.updatedAt) }
            .map(\.asDomain)
        set.events = try context.fetch(FetchDescriptor<StoredActivityEvent>())
            .filter { isNew($0.createdAt) || ($0.deletedAt.map(isNew) ?? false) }
            .map(\.asDomain)
        return set
    }

    /// Member rows for people whose display name changed and must be re-sent.
    func members(forUsers userIDs: Set<UUID>) throws -> [GroupMember] {
        guard !userIDs.isEmpty else { return [] }
        return try ModelContext(container).fetch(FetchDescriptor<StoredGroupMember>())
            .filter { userIDs.contains($0.userID) }
            .map(\.asDomain)
    }

    func groupIDs() throws -> Set<UUID> {
        Set(try ModelContext(container).fetch(FetchDescriptor<StoredGroup>()).map(\.id))
    }

    // MARK: Pull side

    /// Each `apply` returns true when something the user can see changed.
    func apply(groups rows: [GroupRow]) throws -> Bool {
        guard !rows.isEmpty else { return false }
        let context = ModelContext(container)
        var existing = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<StoredGroup>()).map { ($0.id, $0) })
        var changed = false
        for row in rows {
            if let local = existing[row.id] {
                let tombstone = local.deletedAt ?? row.deletedAt
                guard isNewer(row.updatedAt, than: local.updatedAt) || tombstone != local.deletedAt else { continue }
                if local.name != row.name || local.groupDescription != row.description || tombstone != local.deletedAt {
                    changed = true
                }
                local.name = row.name
                local.groupDescription = row.description
                local.ownerID = row.ownerID
                local.updatedAt = max(local.updatedAt, row.updatedAt)
                local.revision = max(local.revision, row.revision)
                local.deletedAt = tombstone
            } else {
                let record = StoredGroup(group: row.domain)
                context.insert(record)
                existing[row.id] = record
                changed = true
            }
        }
        try saveIfNeeded(context)
        return changed
    }

    func apply(members rows: [GroupMemberRow]) throws -> Bool {
        guard !rows.isEmpty else { return false }
        let context = ModelContext(container)
        var existing = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<StoredGroupMember>()).map { ($0.id, $0) })
        var changed = false
        for row in rows {
            if let local = existing[row.id] {
                let tombstone = local.removedAt ?? row.removedAt
                guard isNewer(row.updatedAt, than: local.updatedAt) || tombstone != local.removedAt else { continue }
                if local.userID != row.userID || local.roleRawValue != row.role || tombstone != local.removedAt {
                    changed = true
                }
                let remote = row.domain
                local.apply(GroupMember(
                    id: remote.id,
                    groupID: remote.groupID,
                    userID: remote.userID,
                    role: remote.role,
                    joinedAt: remote.joinedAt,
                    updatedAt: max(local.updatedAt, remote.updatedAt),
                    revision: max(local.revision, remote.revision),
                    removedAt: tombstone
                ))
            } else {
                let record = StoredGroupMember(member: row.domain)
                context.insert(record)
                existing[row.id] = record
                changed = true
            }
        }
        try saveIfNeeded(context)
        return changed
    }

    func apply(expenses rows: [ExpenseRow]) throws -> Bool {
        guard !rows.isEmpty else { return false }
        let context = ModelContext(container)
        var existing = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<StoredExpense>()).map { ($0.id, $0) })
        var splitsByExpense = Dictionary(grouping: try context.fetch(FetchDescriptor<StoredExpenseSplit>()), by: \.expenseID)
        var changed = false
        for row in rows {
            let remote = row.domain
            if let local = existing[row.id] {
                let tombstone = local.deletedAt ?? row.deletedAt
                guard isNewer(row.updatedAt, than: local.updatedAt) || tombstone != local.deletedAt else { continue }
                let merged = Expense(
                    id: remote.id,
                    groupID: remote.groupID,
                    title: remote.title,
                    note: remote.note,
                    total: remote.total,
                    paidByUserID: remote.paidByUserID,
                    splits: remote.splits,
                    splitMethod: remote.splitMethod,
                    occurredAt: remote.occurredAt,
                    createdByUserID: remote.createdByUserID,
                    createdAt: remote.createdAt,
                    updatedAt: max(local.updatedAt, remote.updatedAt),
                    revision: max(local.revision, remote.revision),
                    deletedAt: tombstone
                )
                try local.apply(merged)
                replaceSplits(merged, existing: splitsByExpense[merged.id] ?? [], context: context)
                changed = true
            } else {
                let record = try StoredExpense(expense: remote)
                context.insert(record)
                existing[row.id] = record
                replaceSplits(remote, existing: splitsByExpense[remote.id] ?? [], context: context)
                splitsByExpense[remote.id] = nil
                changed = true
            }
        }
        try saveIfNeeded(context)
        return changed
    }

    func apply(settlements rows: [SettlementRow]) throws -> Bool {
        guard !rows.isEmpty else { return false }
        let context = ModelContext(container)
        var existing = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<StoredSettlement>()).map { ($0.id, $0) })
        var changed = false
        for row in rows {
            let remote = row.domain
            if let local = existing[row.id] {
                let tombstone = local.deletedAt ?? row.deletedAt
                guard isNewer(row.updatedAt, than: local.updatedAt) || tombstone != local.deletedAt else { continue }
                local.apply(Settlement(
                    id: remote.id,
                    groupID: remote.groupID,
                    fromUserID: remote.fromUserID,
                    toUserID: remote.toUserID,
                    amount: remote.amount,
                    method: remote.method,
                    note: remote.note,
                    occurredAt: remote.occurredAt,
                    createdByUserID: remote.createdByUserID,
                    createdAt: remote.createdAt,
                    updatedAt: max(local.updatedAt, remote.updatedAt),
                    revision: max(local.revision, remote.revision),
                    deletedAt: tombstone
                ))
                changed = true
            } else {
                let record = StoredSettlement(settlement: remote)
                context.insert(record)
                existing[row.id] = record
                changed = true
            }
        }
        try saveIfNeeded(context)
        return changed
    }

    func apply(events rows: [ActivityEventRow]) throws -> Bool {
        guard !rows.isEmpty else { return false }
        let context = ModelContext(container)
        var existing = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<StoredActivityEvent>()).map { ($0.id, $0) })
        var changed = false
        for row in rows {
            guard let remote = row.domain else { continue }
            if let local = existing[row.id] {
                if local.actorUserID != remote.actorUserID {
                    // A claimed spot moved this event onto the person who joined.
                    local.actorUserID = remote.actorUserID
                    changed = true
                }
                if local.deletedAt == nil, let deletedAt = remote.deletedAt {
                    local.deletedAt = deletedAt
                    changed = true
                }
            } else {
                let record = StoredActivityEvent(event: remote)
                context.insert(record)
                existing[row.id] = record
                changed = true
            }
        }
        try saveIfNeeded(context)
        return changed
    }

    // MARK: Helpers

    private func isNewer(_ remote: Date, than local: Date) -> Bool {
        remote > local.addingTimeInterval(tolerance)
    }

    private func replaceSplits(_ expense: Expense, existing: [StoredExpenseSplit], context: ModelContext) {
        var byUser = Dictionary(existing.map { ($0.userID, $0) }, uniquingKeysWith: { first, _ in first })
        for split in expense.splits {
            if let record = byUser.removeValue(forKey: split.userID) {
                record.apply(split)
            } else {
                context.insert(StoredExpenseSplit(expenseID: expense.id, split: split))
            }
        }
        for obsolete in byUser.values {
            context.delete(obsolete)
        }
    }

    private func saveIfNeeded(_ context: ModelContext) throws {
        if context.hasChanges {
            try context.save()
        }
    }
}
