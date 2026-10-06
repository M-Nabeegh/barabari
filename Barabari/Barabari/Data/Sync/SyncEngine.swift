import Combine
import SwiftUI
import Foundation

/// What survives between launches: push watermark, pull cursors and identity bookkeeping.
struct SyncState: Codable, Equatable {
    struct Cursor: Codable, Equatable {
        var stamp: String
        var id: UUID
    }

    var lastPushedAt: Date?
    var lastSyncedAt: Date?
    var cursors: [String: Cursor] = [:]
    var registeredAuthUserID: UUID?
    var registeredName: String?
    var pushedNames: [UUID: String] = [:]
    /// Rows the server refused outright (for example a group this phone may no longer
    /// write to). They are skipped so one bad row never blocks everything else.
    var rejectedIDs: Set<UUID> = []

    static let storageKey = "barabari.syncState"

    static func load(from defaults: UserDefaults) -> SyncState {
        guard let data = defaults.data(forKey: storageKey),
              let state = try? JSONDecoder().decode(SyncState.self, from: data) else {
            return SyncState()
        }
        return state
    }

    func save(to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}

/// Keeps the on-device ledger and Supabase in step.
///
/// The phone stays the source of truth for the UI: writes land locally first and
/// the engine pushes them in the background, then pulls whatever other members
/// changed. Runs are serialised and coalesced, so rapid edits never overlap.
@MainActor
final class SyncEngine: ObservableObject {
    enum Status: Equatable {
        case off
        case idle
        case syncing
        case offline
        case failed(String)
    }

    @Published private(set) var status: Status
    @Published private(set) var lastSyncedAt: Date?
    /// Bumps whenever a pull changed what the user sees.
    @Published private(set) var remoteChangeCount = 0

    var isEnabled: Bool { client != nil }

    private let client: SupabaseClient?
    private let store: LocalSyncStore
    private let metadata: LedgerMetadata
    private let currentUserID: UUID
    private let defaults: UserDefaults
    private var state: SyncState

    private var running: Task<Void, Never>?
    private var queued = false
    private var queuedFull = false
    private var needsFullPull = true
    private var debounce: Task<Void, Never>?
    private var heartbeat: Task<Void, Never>?

    static let heartbeatInterval: Duration = .seconds(15)
    private static let chunkSize = 200
    private static let pullOverlap: TimeInterval = 10

    init(
        environment: AppEnvironment,
        metadata: LedgerMetadata? = nil,
        transport: SyncTransport = URLSessionTransport(),
        sessionStore: AuthSessionStore = KeychainSessionStore(),
        defaults: UserDefaults = .standard
    ) {
        self.metadata = metadata ?? .shared
        self.store = LocalSyncStore(container: environment.modelContainer)
        self.currentUserID = environment.currentUserID
        self.defaults = defaults
        self.client = environment.syncConfiguration.map {
            SupabaseClient(configuration: $0, transport: transport, sessionStore: sessionStore)
        }
        let state = SyncState.load(from: defaults)
        self.state = state
        self.lastSyncedAt = state.lastSyncedAt
        self.status = environment.syncConfiguration == nil ? .off : .idle
    }

    // MARK: Triggers

    func appBecameActive() {
        guard isEnabled else { return }
        Task { await syncNow(full: needsFullPull) }
        heartbeat?.cancel()
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.heartbeatInterval)
                guard !Task.isCancelled else { return }
                await self?.syncNow()
            }
        }
    }

    func appWentToBackground() {
        heartbeat?.cancel()
        heartbeat = nil
        // Next time the app opens, re-read everything as a safety net.
        needsFullPull = true
    }

    /// Call after any local write; quick edits are batched into one push.
    func localDataChanged() {
        guard isEnabled else { return }
        debounce?.cancel()
        debounce = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    func syncNow(full: Bool = false) async {
        guard isEnabled else { return }
        if let running {
            queued = true
            queuedFull = queuedFull || full
            await running.value
            return
        }
        let task = Task { await self.run(full: full) }
        running = task
        await task.value
        running = nil
        if queued {
            let full = queuedFull
            queued = false
            queuedFull = false
            await syncNow(full: full)
        }
    }

    // MARK: Invites

    func preview(groupID: UUID) async throws -> CloudGroupPreview? {
        guard let client else { return nil }
        let data = try await client.rpc("group_preview", parameters: ["p_group_id": groupID.uuidString.lowercased()])
        return try SyncJSON.decoder().decode([CloudGroupPreview].self, from: data).first
    }

    /// Joins on the server, then pulls the whole group onto this phone.
    func join(groupID: UUID, claiming placeholder: UUID?) async throws {
        guard let client else { return }
        let session = try await client.ensureSession()
        try await registerIfNeeded(session: session, client: client)
        _ = try await client.rpc("join_group", parameters: [
            "p_group_id": groupID.uuidString.lowercased(),
            "p_display_name": ownerName,
            "p_claim_user_id": placeholder?.uuidString.lowercased()
        ])
        await syncNow(full: true)
        if case let .failed(message) = status {
            throw SupabaseError.server(status: 0, code: nil, message: message)
        }
    }

    // MARK: Run

    private func run(full: Bool) async {
        guard let client else { return }
        if status != .idle || lastSyncedAt == nil { status = .syncing }
        do {
            let session = try await client.ensureSession()
            try await registerIfNeeded(session: session, client: client)
            try await push(client: client)
            let pulledChanges = try await pull(client: client, full: full || needsFullPull)
            needsFullPull = false
            let now = Date()
            state.lastSyncedAt = now
            state.save(to: defaults)
            lastSyncedAt = now
            status = .idle
            if pulledChanges { remoteChangeCount &+= 1 }
        } catch let error as SupabaseError {
            status = error == .offline ? .offline : .failed(error.userMessage)
        } catch is CancellationError {
            status = .idle
        } catch {
            status = .failed("Sync paused: \(error.localizedDescription)")
        }
    }

    private var ownerName: String? {
        let trimmed = metadata.ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func registerIfNeeded(session: AuthSession, client: SupabaseClient) async throws {
        guard state.registeredAuthUserID != session.userID || state.registeredName != ownerName else { return }
        do {
            _ = try await client.rpc("register_profile", parameters: [
                "p_app_user_id": currentUserID.uuidString.lowercased(),
                "p_display_name": ownerName
            ])
        } catch let SupabaseError.server(_, _, message) where message.contains("identity_") {
            throw SupabaseError.server(status: 409, code: "identity", message: "This phone’s cloud identity is linked elsewhere. Your data is safe on this iPhone.")
        }
        state.registeredAuthUserID = session.userID
        state.registeredName = ownerName
        state.save(to: defaults)
    }

    // MARK: Push

    private func push(client: SupabaseClient) async throws {
        let pushStartedAt = Date()
        var changes = try await store.changes(since: state.lastPushedAt)

        // Renaming someone does not touch their member row, so resend it explicitly.
        let names = metadata.names
        let renamed = Set(names.filter { state.pushedNames[$0.key] != $0.value }.keys)
        let knownMemberIDs = Set(changes.members.map(\.id))
        changes.members += try await store.members(forUsers: renamed).filter { !knownMemberIDs.contains($0.id) }

        let rejected = state.rejectedIDs
        try await upsert(changes.groups.filter { !rejected.contains($0.id) }.map(GroupRow.init),
                         table: GroupRow.table, columns: GroupRow.columns, id: \.id, client: client)
        try await upsert(changes.members.filter { !rejected.contains($0.id) }.map { member in
            GroupMemberRow(member, displayName: member.userID == currentUserID ? ownerName : names[member.userID])
        }, table: GroupMemberRow.table, columns: GroupMemberRow.columns, id: \.id, client: client)
        try await upsert(changes.expenses.filter { !rejected.contains($0.id) }.map { expense in
            ExpenseRow(expense, category: metadata.categories[expense.id] ?? ExpenseCategory.detect(from: expense.title))
        }, table: ExpenseRow.table, columns: ExpenseRow.columns, id: \.id, client: client)
        try await upsert(changes.settlements.filter { !rejected.contains($0.id) }.map(SettlementRow.init),
                         table: SettlementRow.table, columns: SettlementRow.columns, id: \.id, client: client)
        try await upsert(changes.events.filter { !rejected.contains($0.id) }.map(ActivityEventRow.init),
                         table: ActivityEventRow.table, columns: ActivityEventRow.columns, id: \.id, client: client)

        state.lastPushedAt = pushStartedAt
        state.pushedNames.merge(names) { _, new in new }
        state.save(to: defaults)
    }

    private func upsert<Row: Encodable>(_ rows: [Row], table: String, columns: String, id: (Row) -> UUID, client: SupabaseClient) async throws {
        guard !rows.isEmpty else { return }
        let encoder = SyncJSON.encoder()
        for start in stride(from: 0, to: rows.count, by: Self.chunkSize) {
            let chunk = Array(rows[start..<min(start + Self.chunkSize, rows.count)])
            do {
                try await client.upsert(table: table, columns: columns, body: encoder.encode(chunk))
            } catch let SupabaseError.server(status, _, _) where (400..<500).contains(status) && status != 401 {
                // Find the offending row(s) instead of failing the whole batch forever.
                for row in chunk {
                    do {
                        try await client.upsert(table: table, columns: columns, body: encoder.encode([row]))
                    } catch let SupabaseError.server(status, _, _) where (400..<500).contains(status) && status != 401 {
                        state.rejectedIDs.insert(id(row))
                    }
                }
            }
        }
    }

    // MARK: Pull

    private func pull(client: SupabaseClient, full: Bool) async throws -> Bool {
        var changed = false
        changed = try await pullTable(GroupRow.self, table: GroupRow.table, full: full, client: client) { rows in
            try await self.store.apply(groups: rows)
        } || changed

        let knownGroups = try await store.groupIDs()
        var discoveredGroup = false
        changed = try await pullTable(GroupMemberRow.self, table: GroupMemberRow.table, full: full, client: client) { rows in
            for row in rows where !knownGroups.contains(row.groupID) && row.userID == self.currentUserID {
                discoveredGroup = true
            }
            self.adoptNames(from: rows)
            return try await self.store.apply(members: rows)
        } || changed

        changed = try await pullTable(ExpenseRow.self, table: ExpenseRow.table, full: full, client: client) { rows in
            self.adoptCategories(from: rows)
            return try await self.store.apply(expenses: rows)
        } || changed
        changed = try await pullTable(SettlementRow.self, table: SettlementRow.table, full: full, client: client) { rows in
            try await self.store.apply(settlements: rows)
        } || changed
        changed = try await pullTable(ActivityEventRow.self, table: ActivityEventRow.table, full: full, client: client) { rows in
            try await self.store.apply(events: rows)
        } || changed

        // Membership in a group this phone has never seen: fetch its full history.
        if discoveredGroup && !full {
            changed = try await pull(client: client, full: true) || changed
        }
        return changed
    }

    private func pullTable<Row: Decodable & ServerStamped>(
        _ type: Row.Type,
        table: String,
        full: Bool,
        client: SupabaseClient,
        apply: ([Row]) async throws -> Bool
    ) async throws -> Bool {
        let decoder = SyncJSON.decoder()
        // Re-read a short overlap so rows committed slightly out of order are never missed.
        let floor = full ? nil : state.cursors[table].flatMap { SyncJSON.date(from: $0.stamp) }
            .map { SyncJSON.string(from: $0.addingTimeInterval(-Self.pullOverlap)) }
        var after: (stamp: String, id: UUID)?
        var changed = false
        var newest = state.cursors[table]
        while true {
            let data = try await client.select(table: table, query: SyncQuery.page(after: after, floor: floor))
            let rows = try decoder.decode([Row].self, from: data)
            if try await apply(rows) { changed = true }
            if let last = rows.last, let stamp = last.serverUpdatedAt {
                after = (stamp, last.id)
                if newest == nil || stamp > newest!.stamp {
                    newest = SyncState.Cursor(stamp: stamp, id: last.id)
                }
            }
            if rows.count < SyncQuery.pageSize { break }
        }
        state.cursors[table] = newest
        return changed
    }

    private func adoptNames(from rows: [GroupMemberRow]) {
        for row in rows where row.userID != currentUserID {
            guard let name = row.displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { continue }
            if metadata.names[row.userID] != name {
                metadata.setName(name, for: row.userID)
            }
            state.pushedNames[row.userID] = name
        }
    }

    private func adoptCategories(from rows: [ExpenseRow]) {
        for row in rows {
            guard let raw = row.category, let category = ExpenseCategory(rawValue: raw) else { continue }
            if metadata.categories[row.id] != category {
                metadata.setCategory(category, for: row.id)
            }
        }
    }
}

/// Rows that carry the server's write clock and an id, for keyset pagination.
protocol ServerStamped {
    var id: UUID { get }
    var serverUpdatedAt: String? { get }
}

extension GroupRow: ServerStamped {}
extension GroupMemberRow: ServerStamped {}
extension ExpenseRow: ServerStamped {}
extension SettlementRow: ServerStamped {}
extension ActivityEventRow: ServerStamped {}

// MARK: - SwiftUI

private struct SyncEngineKey: EnvironmentKey {
    static let defaultValue: SyncEngine? = nil
}

extension EnvironmentValues {
    /// The running sync engine, or nil when this build or ledger is local-only.
    var syncEngine: SyncEngine? {
        get { self[SyncEngineKey.self] }
        set { self[SyncEngineKey.self] = newValue }
    }
}
