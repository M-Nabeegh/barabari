import XCTest
@testable import Barabari

/// Scripted network: each request is answered by the first matching handler.
final class FakeTransport: SyncTransport, @unchecked Sendable {
    typealias Handler = (URLRequest) -> (Int, Data)?
    private let lock = NSLock()
    private var handlers: [Handler] = []
    private(set) var requests: [URLRequest] = []

    func on(_ handler: @escaping Handler) {
        lock.withLock { handlers.append(handler) }
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let handlers = lock.withLock {
            requests.append(request)
            return self.handlers
        }
        for handler in handlers {
            if let (status, data) = handler(request) {
                return (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
            }
        }
        return (Data("{\"message\":\"unhandled\"}".utf8), HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!)
    }

    func count(path: String) -> Int {
        lock.withLock { requests.filter { $0.url?.path.hasSuffix(path) == true }.count }
    }

    static func session(user: UUID = UUID(), token: String = "token", expiresIn: Double = 3600) -> Data {
        Data("""
        {"access_token":"\(token)","refresh_token":"refresh-\(token)","expires_in":\(expiresIn),
         "expires_at":\(Date().timeIntervalSince1970 + expiresIn),"user":{"id":"\(user)"}}
        """.utf8)
    }
}

final class SupabaseClientTests: XCTestCase {
    private let configuration = SyncConfiguration(projectURL: URL(string: "https://example.supabase.co")!, anonKey: "anon")

    func testSignsInAnonymouslyOnceAndReusesTheSession() async throws {
        let transport = FakeTransport()
        let user = UUID()
        transport.on { $0.url!.path.hasSuffix("/auth/v1/signup") ? (200, FakeTransport.session(user: user)) : nil }
        let store = InMemorySessionStore()
        let client = SupabaseClient(configuration: configuration, transport: transport, sessionStore: store)

        async let first = client.ensureSession()
        async let second = client.ensureSession()
        let sessions = try await [first, second]

        XCTAssertEqual(sessions.map(\.userID), [user, user])
        XCTAssertEqual(transport.count(path: "/auth/v1/signup"), 1)
        XCTAssertEqual(store.load()?.userID, user)
    }

    func testRefreshesAnExpiredSessionInsteadOfCreatingANewIdentity() async throws {
        let transport = FakeTransport()
        let user = UUID()
        transport.on { $0.url!.path.hasSuffix("/auth/v1/token") ? (200, FakeTransport.session(user: user, token: "fresh")) : nil }
        let expired = AuthSession(accessToken: "old", refreshToken: "r", expiresAt: .distantPast, userID: user)
        let client = SupabaseClient(configuration: configuration, transport: transport, sessionStore: InMemorySessionStore(session: expired))

        let session = try await client.ensureSession()

        XCTAssertEqual(session.accessToken, "fresh")
        XCTAssertEqual(session.userID, user)
        XCTAssertEqual(transport.count(path: "/auth/v1/signup"), 0)
    }

    func testRetriesOnceWithAFreshTokenAfter401() async throws {
        let transport = FakeTransport()
        let user = UUID()
        transport.on { request in
            guard request.url!.path.hasSuffix("/rest/v1/groups") else { return nil }
            let auth = request.value(forHTTPHeaderField: "Authorization")
            return auth == "Bearer fresh" ? (200, Data("[]".utf8)) : (401, Data())
        }
        transport.on { $0.url!.path.hasSuffix("/auth/v1/token") ? (200, FakeTransport.session(user: user, token: "fresh")) : nil }
        let stale = AuthSession(accessToken: "stale", refreshToken: "r", expiresAt: .distantFuture, userID: user)
        let client = SupabaseClient(configuration: configuration, transport: transport, sessionStore: InMemorySessionStore(session: stale))

        let data = try await client.select(table: "groups", query: "select=*")
        XCTAssertEqual(String(data: data, encoding: .utf8), "[]")
    }

    func testReportsWhenAnonymousSignInsAreOff() async {
        let transport = FakeTransport()
        transport.on { _ in (422, Data("{\"error_code\":\"anonymous_provider_disabled\",\"msg\":\"Anonymous sign-ins are disabled\"}".utf8)) }
        let client = SupabaseClient(configuration: configuration, transport: transport, sessionStore: InMemorySessionStore())
        do {
            _ = try await client.ensureSession()
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? SupabaseError, .anonymousSignInsDisabled)
        }
    }

    func testTimestampsWithPlusSignsSurviveTheQueryString() async throws {
        let transport = FakeTransport()
        transport.on { $0.url!.path.hasSuffix("/rest/v1/expenses") ? (200, Data("[]".utf8)) : nil }
        let session = AuthSession(accessToken: "t", refreshToken: "r", expiresAt: .distantFuture, userID: UUID())
        let client = SupabaseClient(configuration: configuration, transport: transport, sessionStore: InMemorySessionStore(session: session))

        _ = try await client.select(table: "expenses", query: SyncQuery.page(after: nil, floor: "2026-10-06T12:00:00.000+00:00"))
        let query = try XCTUnwrap(transport.requests.last?.url?.query(percentEncoded: true))
        XCTAssertTrue(query.contains("%2B00:00"), query)
    }
}
