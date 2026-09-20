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

    func testGroupsViewModelIgnoresRepeatedCreateRequestsWhileFirstSaveIsInFlight() async throws {
        let environment = AppEnvironment(inMemory: true)
        let saveStarted = AsyncTestLatch()
        let viewModel = GroupsViewModel(environment: environment) { name, description, ownerID in
            await saveStarted.signal()
            try await Task.sleep(nanoseconds: 100_000_000)
            return try await environment.groupRepository.createGroup(
                name: name,
                description: description,
                ownerID: ownerID
            )
        }

        let firstRequest = Task { await viewModel.createGroup(name: "Trip", description: nil) }
        await saveStarted.wait()
        let repeatedRequest = await viewModel.createGroup(name: "Duplicate", description: nil)
        let firstResult = await firstRequest.value

        XCTAssertNotNil(firstResult)
        XCTAssertNil(repeatedRequest)
        XCTAssertFalse(viewModel.isCreating)
        let storedGroups = try await environment.groupRepository.listGroups()
        XCTAssertEqual(storedGroups.count, 1)
    }
}

private actor AsyncTestLatch {
    private var signaled = false
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        guard !signaled else { return }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func signal() {
        signaled = true
        continuation?.resume()
        continuation = nil
    }
}
