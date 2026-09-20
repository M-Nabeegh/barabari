import XCTest
@testable import Barabari

@MainActor
final class ActivityViewModelTests: XCTestCase {
    func testInitialActivityPageIsBoundedAndLaterPagesAppendInOrder() async throws {
        let environment = AppEnvironment(inMemory: true, seedDemoData: true, seedDemoSecondMember: true, seedDemoDebt: true)
        let viewModel = ActivityViewModel(environment: environment, pageSize: 1)

        await viewModel.load()

        XCTAssertEqual(viewModel.rows.count, 1)
        XCTAssertTrue(viewModel.hasMore)
        let firstID = try XCTUnwrap(viewModel.rows.first?.id)

        await viewModel.loadNextPageIfNeeded(lastID: firstID)

        XCTAssertEqual(viewModel.rows.count, 2)
        XCTAssertNotEqual(viewModel.rows[0].id, viewModel.rows[1].id)
        XCTAssertGreaterThanOrEqual(viewModel.rows[0].event.occurredAt, viewModel.rows[1].event.occurredAt)
    }

    func testRepeatedRequestsForAnOlderRowDoNotDuplicateActivity() async throws {
        let environment = AppEnvironment(inMemory: true, seedDemoData: true, seedDemoSecondMember: true, seedDemoDebt: true)
        let viewModel = ActivityViewModel(environment: environment, pageSize: 1)

        await viewModel.load()

        let firstID = try XCTUnwrap(viewModel.rows.first?.id)
        await viewModel.loadNextPageIfNeeded(lastID: firstID)
        let countAfterSecondPage = viewModel.rows.count

        await viewModel.loadNextPageIfNeeded(lastID: firstID)

        XCTAssertEqual(viewModel.rows.count, countAfterSecondPage)
    }
}
