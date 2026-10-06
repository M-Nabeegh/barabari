import XCTest
@testable import Barabari

/// A tiny stand-in for Supabase that follows the same rules as the real schema:
/// anonymous sign-up, profile registration, members-only reads, last-writer-wins
/// upserts and invite joins.
final class FakeSupabaseServer: SyncTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var profiles: [String: String] = [:]            // auth id -> app user id
    private var names: [String: String] = [:]               // app user id -> display name
    private var tables: [String: [String: [String: Any]]] = [:]
    private var clock = 0
    var offline = false

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        if lock.withLock({ offline }) { throw SupabaseError.offline }
        let path = request.url!.path
        let body = request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) }
        let auth = request.value(forHTTPHeaderField: "Authorization")?.replacingOccurrences(of: "Bearer tok-", with: "")
        let (status, object): (Int, Any) = lock.withLock {
            if path.hasSuffix("/auth/v1/signup") {
                let user = UUID().uuidString.lowercased()
                return (200, ["access_token": "tok-\(user)", "refresh_token": "r", "expires_in": 3600,
                              "expires_at": Date().timeIntervalSince1970 + 3600, "user": ["id": user]])
            }
            guard let auth else { return (401, [:]) }
            if path.hasSuffix("/rpc/register_profile") {
                let params = body as! [String: Any]
                let app = (params["p_app_user_id"] as! String).lowercased()
                if let existing = profiles[auth], existing != app { return (400, ["message": "identity_mismatch"]) }
                if profiles.contains(where: { $0.key != auth && $0.value == app }) { return (400, ["message": "identity_taken"]) }
                profiles[auth] = app
                if let name = params["p_display_name"] as? String { names[app] = name }
                return (200, app)
            }
            let me = profiles[auth]
            if path.hasSuffix("/rpc/group_preview") {
                let gid = ((body as! [String: Any])["p_group_id"] as! String).lowercased()
                guard let group = tables["groups"]?[gid] else { return (200, []) }
                let members = tables["group_members", default: [:]].values.filter { ($0["group_id"] as! String).lowercased() == gid }
                return (200, [["group_id": gid, "name": group["name"]!, "member_count": members.count, "open_spots": []]])
            }
            if path.hasSuffix("/rpc/join_group") {
                let params = body as! [String: Any]
                let gid = (params["p_group_id"] as! String).lowercased()
                guard let me, tables["groups"]?[gid] != nil else { return (400, ["message": "group_not_found"]) }
                let stamp = SyncJSON.string(from: Date())
                let row: [String: Any] = ["id": UUID().uuidString.lowercased(), "group_id": gid, "user_id": me, "role": "member",
                                          "display_name": params["p_display_name"] ?? NSNull(), "joined_at": stamp,
                                          "updated_at": stamp, "revision": 1, "removed_at": NSNull()]
                write("group_members", row)
                return (200, gid)
            }
            let table = String(path.split(separator: "/").last!)
            if request.httpMethod == "POST" {
                for row in body as! [[String: Any]] {
                    guard let me else { return (403, ["message": "no profile"]) }
                    let gid = ((row["group_id"] as? String) ?? (row["id"] as! String)).lowercased()
                    let isNewGroup = table == "groups" && tables["groups"]?[gid] == nil
                    if isNewGroup ? (row["owner_id"] as! String).lowercased() != me : !canSee(gid, me) && !owns(gid, me) {
                        return (403, ["message": "row level security"])
                    }
                    write(table, row)
                }
                return (201, [])
            }
            guard let me else { return (200, []) }
            // Only the first page carries rows; the engine's keyset pages come back empty.
            if request.url!.query?.contains("or=") == true { return (200, []) }
            let rows = tables[table, default: [:]].values
                .filter { row in
                    let gid = ((row["group_id"] as? String) ?? (row["id"] as! String)).lowercased()
                    return table == "groups" ? (canSee(gid, me) || (row["owner_id"] as! String).lowercased() == me) : canSee(gid, me)
                }
                .sorted { ($0["server_updated_at"] as! String) < ($1["server_updated_at"] as! String) }
            return (200, rows)
        }
        let data = try JSONSerialization.data(withJSONObject: object, options: .fragmentsAllowed)
        return (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }

    private func canSee(_ group: String, _ me: String) -> Bool {
        tables["group_members", default: [:]].values.contains {
            ($0["group_id"] as! String).lowercased() == group && ($0["user_id"] as! String).lowercased() == me
        }
    }

    private func owns(_ group: String, _ me: String) -> Bool {
        (tables["groups"]?[group]?["owner_id"] as? String)?.lowercased() == me
    }

    /// Last writer wins on updated_at; every accepted write advances the server clock.
    private func write(_ table: String, _ incoming: [String: Any]) {
        let id = (incoming["id"] as! String).lowercased()
        var row = incoming
        for key in ["id", "group_id", "user_id", "owner_id", "paid_by", "created_by", "actor_user_id", "subject_id", "from_user", "to_user"] {
            if let value = row[key] as? String { row[key] = value.lowercased() }
        }
        if let existing = tables[table]?[id],
           let old = existing["updated_at"] as? String, let new = row["updated_at"] as? String, new <= old {
            return
        }
        clock += 1
        row["server_updated_at"] = String(format: "2026-10-06T12:00:00.%06d+00:00", clock)
        tables[table, default: [:]][id] = row
    }
}

@MainActor
final class SyncEngineTests: XCTestCase {
    private struct Phone {
        let environment: AppEnvironment
        let engine: SyncEngine
        let metadata: LedgerMetadata
    }

    private let configuration = SyncConfiguration(projectURL: URL(string: "https://fake.supabase.co")!, anonKey: "anon")

    private func makePhone(_ name: String, server: FakeSupabaseServer) -> Phone {
        let suite = "SyncEngineTests.\(name).\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        let metadata = LedgerMetadata(defaults: defaults)
        metadata.ownerName = name
        let environment = AppEnvironment(inMemory: true, currentUserID: UUID(), syncConfiguration: configuration)
        let engine = SyncEngine(environment: environment, metadata: metadata, transport: server,
                                sessionStore: InMemorySessionStore(), defaults: defaults)
        return Phone(environment: environment, engine: engine, metadata: metadata)
    }

    private func addExpense(on phone: Phone, group: UUID, title: String, total: Int64, payer: UUID, people: [UUID]) async throws {
        let each = total / Int64(people.count)
        var splits = people.map { ExpenseSplit(userID: $0, amount: Money(minorUnits: each, currencyCode: "PKR")) }
        let remainder = total - each * Int64(people.count)
        splits[0] = ExpenseSplit(userID: people[0], amount: Money(minorUnits: each + remainder, currencyCode: "PKR"))
        let expense = Expense(groupID: group, title: title, note: nil, total: Money(minorUnits: total, currencyCode: "PKR"),
                              paidByUserID: payer, splits: splits, splitMethod: .equal, occurredAt: .now,
                              createdByUserID: phone.environment.currentUserID)
        _ = try await phone.environment.expenseRepository.saveExpense(expense, idempotencyKey: UUID())
    }

    func testTwoPhonesShareAGroupThroughAnInvite() async throws {
        let server = FakeSupabaseServer()
        let nabeegh = makePhone("Nabeegh", server: server)
        let ali = makePhone("Ali", server: server)

        // Nabeegh creates the trip offline-first and adds Sara by name.
        let trip = try await nabeegh.environment.groupRepository.createGroup(name: "Hunza Trip", description: nil, ownerID: nabeegh.environment.currentUserID)
        let sara = UUID()
        let invite = try await nabeegh.environment.groupRepository.invitePayload(groupID: trip.id)
        _ = try await nabeegh.environment.groupRepository.joinGroup(invite: invite, userID: sara)
        nabeegh.metadata.setName("Sara Khan", for: sara)
        try await addExpense(on: nabeegh, group: trip.id, title: "Hotel in Karimabad", total: 1_800_000,
                             payer: nabeegh.environment.currentUserID, people: [nabeegh.environment.currentUserID, sara])
        await nabeegh.engine.syncNow()
        XCTAssertEqual(nabeegh.engine.status, .idle)

        // Ali opens the invite on his own phone.
        await ali.engine.syncNow()
        let preview = try await ali.engine.preview(groupID: trip.id)
        XCTAssertEqual(preview?.name, "Hunza Trip")
        try await ali.engine.join(groupID: trip.id, claiming: nil)

        let aliGroups = try await ali.environment.groupRepository.listGroups()
        XCTAssertEqual(aliGroups.map(\.name), ["Hunza Trip"])
        let aliExpenses = try await ali.environment.expenseRepository.listExpenses(groupID: trip.id, cursor: nil).items
        XCTAssertEqual(aliExpenses.map(\.title), ["Hotel in Karimabad"])
        XCTAssertEqual(ali.metadata.names[sara], "Sara Khan")
        XCTAssertEqual(ali.metadata.names[nabeegh.environment.currentUserID], "Nabeegh")
        XCTAssertEqual(ali.metadata.categories[aliExpenses[0].id], .travel)

        // Ali adds petrol; Nabeegh sees it on the next sync with matching balances.
        try await addExpense(on: ali, group: trip.id, title: "Petrol to Naran", total: 900_000,
                             payer: ali.environment.currentUserID,
                             people: [nabeegh.environment.currentUserID, sara, ali.environment.currentUserID])
        await ali.engine.syncNow()
        await nabeegh.engine.syncNow()

        let nabeeghTitles = try await nabeegh.environment.expenseRepository.listExpenses(groupID: trip.id, cursor: nil).items.map(\.title)
        XCTAssertEqual(Set(nabeeghTitles), ["Hotel in Karimabad", "Petrol to Naran"])
        XCTAssertEqual(nabeegh.metadata.names[ali.environment.currentUserID], "Ali")

        let nabeeghSummary = try await nabeegh.environment.balanceRepository.summary(groupID: trip.id)
        let aliSummary = try await ali.environment.balanceRepository.summary(groupID: trip.id)
        XCTAssertEqual(nabeeghSummary, aliSummary)
        XCTAssertGreaterThan(nabeegh.engine.remoteChangeCount, 0)
    }

    func testOfflineWritesAreKeptAndPushedLater() async throws {
        let server = FakeSupabaseServer()
        let phone = makePhone("Nabeegh", server: server)
        await phone.engine.syncNow()

        server.offline = true
        let group = try await phone.environment.groupRepository.createGroup(name: "Flat 4B", description: nil, ownerID: phone.environment.currentUserID)
        await phone.engine.syncNow()
        XCTAssertEqual(phone.engine.status, .offline)
        let localGroups = try await phone.environment.groupRepository.listGroups()
        XCTAssertEqual(localGroups.map(\.id), [group.id])

        server.offline = false
        await phone.engine.syncNow()
        XCTAssertEqual(phone.engine.status, .idle)

        // A second phone joining proves the group reached the server.
        let other = makePhone("Ali", server: server)
        await other.engine.syncNow()
        try await other.engine.join(groupID: group.id, claiming: nil)
        let otherGroups = try await other.environment.groupRepository.listGroups()
        XCTAssertEqual(otherGroups.map(\.name), ["Flat 4B"])
    }

    func testLocalOnlyBuildsNeverTouchTheNetwork() async {
        let environment = AppEnvironment(inMemory: true)
        let engine = SyncEngine(environment: environment, transport: FakeSupabaseServer(), sessionStore: InMemorySessionStore())
        XCTAssertFalse(engine.isEnabled)
        await engine.syncNow()
        XCTAssertEqual(engine.status, .off)
    }
}
