import XCTest
@testable import Barabari

@MainActor
final class AppEnvironmentTests: XCTestCase {
    // Catches an app environment that still uses the retired visual-demo schema.
    func testDemoEnvironmentUsesTheBarabariLedgerStore() async throws {
        let environment = AppEnvironment.demo
        let groups = try await environment.groupRepository.listGroups()
        let events = try await environment.recentActivity(limit: 10)

        XCTAssertFalse(groups.isEmpty)
        XCTAssertFalse(events.isEmpty)
        guard let group = groups.first else {
            return XCTFail("The seeded demo must contain a group.")
        }
        XCTAssertTrue(events.allSatisfy { $0.groupID == group.id })
    }
}
