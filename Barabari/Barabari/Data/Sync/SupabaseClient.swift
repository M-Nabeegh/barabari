import Foundation
import Security

enum SupabaseError: Error, Equatable {
    case offline
    case unauthorized
    case anonymousSignInsDisabled
    case server(status: Int, code: String?, message: String)
    case unreadableResponse

    var userMessage: String {
        switch self {
        case .offline:
            return "You’re offline. Changes are saved on this iPhone."
        case .unauthorized:
            return "Cloud sign-in expired. Trying again."
        case .anonymousSignInsDisabled:
            return "Cloud sync isn’t switched on for this project yet."
        case let .server(_, _, message):
            return message
        case .unreadableResponse:
            return "The cloud sent something unexpected."
        }
    }
}

struct AuthSession: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let userID: UUID
}

// MARK: - Transport

protocol SyncTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionTransport: SyncTransport {
    let session: URLSession

    init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.session = session
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw SupabaseError.unreadableResponse }
            return (data, http)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost,
                 .cannotConnectToHost, .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff,
                 .secureConnectionFailed:
                throw SupabaseError.offline
            default:
                throw error
            }
        }
    }
}

// MARK: - Session storage

protocol AuthSessionStore: Sendable {
    func load() -> AuthSession?
    func save(_ session: AuthSession)
}

/// Keeps the anonymous session in the Keychain, which survives app updates and
/// reinstalls, so a phone keeps its cloud identity.
struct KeychainSessionStore: AuthSessionStore {
    var service = "com.nabeegh.Barabari.cloud"
    var account = "supabase-session"

    func load() -> AuthSession? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    func save(_ session: AuthSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        if SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            var insert = baseQuery
            insert.merge(attributes) { _, new in new }
            SecItemAdd(insert as CFDictionary, nil)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

final class InMemorySessionStore: AuthSessionStore, @unchecked Sendable {
    private let lock = NSLock()
    private var session: AuthSession?

    init(session: AuthSession? = nil) {
        self.session = session
    }

    func load() -> AuthSession? {
        lock.withLock { session }
    }

    func save(_ session: AuthSession) {
        lock.withLock { self.session = session }
    }
}

// MARK: - Client

/// A small Supabase client: anonymous auth plus PostgREST tables and RPCs.
actor SupabaseClient {
    private let configuration: SyncConfiguration
    private let transport: SyncTransport
    private let sessionStore: AuthSessionStore
    private var session: AuthSession?
    private var authTask: Task<AuthSession, Error>?

    init(
        configuration: SyncConfiguration,
        transport: SyncTransport = URLSessionTransport(),
        sessionStore: AuthSessionStore = KeychainSessionStore()
    ) {
        self.configuration = configuration
        self.transport = transport
        self.sessionStore = sessionStore
        self.session = sessionStore.load()
    }

    /// A valid session, refreshing or signing in anonymously as needed. Concurrent
    /// callers share one in-flight sign-in so a phone never creates two identities.
    func ensureSession(forceRefresh: Bool = false) async throws -> AuthSession {
        if let authTask {
            return try await authTask.value
        }
        if !forceRefresh, let session, session.expiresAt > Date().addingTimeInterval(60) {
            return session
        }
        let existing = session
        let task = Task { [configuration, transport] () throws -> AuthSession in
            if let existing {
                do {
                    return try await Self.refresh(existing, configuration: configuration, transport: transport)
                } catch SupabaseError.unauthorized {
                    // The refresh token is gone (revoked or expired): start a new identity.
                }
            }
            return try await Self.signUpAnonymously(configuration: configuration, transport: transport)
        }
        authTask = task
        defer { authTask = nil }
        let fresh = try await task.value
        session = fresh
        sessionStore.save(fresh)
        return fresh
    }

    func rpc(_ function: String, parameters: [String: Any?]) async throws -> Data {
        let body = try JSONSerialization.data(withJSONObject: parameters.mapValues { $0 ?? NSNull() })
        return try await authorized(method: "POST", path: "rest/v1/rpc/\(function)", query: nil, body: body, prefer: nil)
    }

    func upsert(table: String, columns: String, body: Data) async throws {
        _ = try await authorized(
            method: "POST",
            path: "rest/v1/\(table)",
            query: "on_conflict=id&columns=\(columns)",
            body: body,
            prefer: "resolution=merge-duplicates,return=minimal"
        )
    }

    func select(table: String, query: String) async throws -> Data {
        try await authorized(method: "GET", path: "rest/v1/\(table)", query: query, body: nil, prefer: nil)
    }

    // MARK: Private

    private func authorized(method: String, path: String, query: String?, body: Data?, prefer: String?) async throws -> Data {
        var token = try await ensureSession().accessToken
        for attempt in 0..<2 {
            var request = Self.request(configuration, method: method, path: path, query: query, body: body)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if let prefer { request.setValue(prefer, forHTTPHeaderField: "Prefer") }
            let (data, response) = try await transport.send(request)
            if response.statusCode == 401, attempt == 0 {
                token = try await ensureSession(forceRefresh: true).accessToken
                continue
            }
            try Self.check(response, data: data)
            return data
        }
        throw SupabaseError.unauthorized
    }

    private static func signUpAnonymously(configuration: SyncConfiguration, transport: SyncTransport) async throws -> AuthSession {
        let body = try JSONSerialization.data(withJSONObject: ["data": [String: String]()])
        let request = request(configuration, method: "POST", path: "auth/v1/signup", query: nil, body: body)
        let (data, response) = try await transport.send(request)
        if response.statusCode == 422 || response.statusCode == 400,
           String(data: data, encoding: .utf8)?.contains("anonymous") == true {
            throw SupabaseError.anonymousSignInsDisabled
        }
        try check(response, data: data)
        return try decodeSession(data)
    }

    private static func refresh(_ session: AuthSession, configuration: SyncConfiguration, transport: SyncTransport) async throws -> AuthSession {
        let body = try JSONSerialization.data(withJSONObject: ["refresh_token": session.refreshToken])
        let request = request(configuration, method: "POST", path: "auth/v1/token", query: "grant_type=refresh_token", body: body)
        let (data, response) = try await transport.send(request)
        if (400...403).contains(response.statusCode) {
            throw SupabaseError.unauthorized
        }
        try check(response, data: data)
        return try decodeSession(data)
    }

    private static func decodeSession(_ data: Data) throws -> AuthSession {
        struct Payload: Decodable {
            struct User: Decodable { let id: UUID }
            let access_token: String
            let refresh_token: String
            let expires_in: Double?
            let expires_at: Double?
            let user: User
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            throw SupabaseError.unreadableResponse
        }
        let expiry = payload.expires_at.map { Date(timeIntervalSince1970: $0) }
            ?? Date().addingTimeInterval(payload.expires_in ?? 3600)
        return AuthSession(
            accessToken: payload.access_token,
            refreshToken: payload.refresh_token,
            expiresAt: expiry,
            userID: payload.user.id
        )
    }

    private static func request(_ configuration: SyncConfiguration, method: String, path: String, query: String?, body: Data?) -> URLRequest {
        var components = URLComponents(url: configuration.projectURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.percentEncodedQuery = query
        var request = URLRequest(url: components.url!, timeoutInterval: 20)
        request.httpMethod = method
        request.httpBody = body
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(configuration.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private static func check(_ response: HTTPURLResponse, data: Data) throws {
        guard !(200..<300).contains(response.statusCode) else { return }
        if response.statusCode == 401 { throw SupabaseError.unauthorized }
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let code = (object?["code"] as? String) ?? (object?["error_code"] as? String)
        let message = (object?["message"] as? String) ?? (object?["msg"] as? String)
            ?? HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
        throw SupabaseError.server(status: response.statusCode, code: code, message: message)
    }
}

// MARK: - Pull queries

/// Builds keyset-paginated pull queries ordered by the server's write clock, so
/// rows that share a timestamp are never skipped between pages.
enum SyncQuery {
    static let pageSize = 500

    static func page(after cursor: (stamp: String, id: UUID)?, floor: String?) -> String {
        var parts = ["select=*", "order=server_updated_at.asc,id.asc", "limit=\(pageSize)"]
        if let cursor {
            let quoted = "\"\(cursor.stamp)\""
            let tree = "(server_updated_at.gt.\(quoted),and(server_updated_at.eq.\(quoted),id.gt.\(cursor.id.uuidString.lowercased())))"
            parts.append("or=\(encode(tree))")
        } else if let floor {
            parts.append("server_updated_at=gte.\(encode(floor))")
        }
        return parts.joined(separator: "&")
    }

    private static func encode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~:(),")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
