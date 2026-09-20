import SwiftData
import XCTest
@testable import Barabari

@MainActor
final class ActivityViewModelTests: XCTestCase {
    func testActivityRepositoryReturnsBoundedKeysetPages() async throws {
        let environment = AppEnvironment(inMemory: true, seedDemoData: true)
        let groups = try await environment.groupRepository.listGroups()
        let group = try XCTUnwrap(groups.first)
        let context = ModelContext(environment.modelContainer)

        for index in 0..<75 {
            let event = ActivityEvent(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", 1_000 + index))!,
                groupID: group.id,
                actorUserID: group.ownerID,
                kind: .memberJoined,
                subjectID: group.id,
                occurredAt: Date(timeIntervalSince1970: 2_000 + Double(index)),
                createdAt: Date(timeIntervalSince1970: 2_000 + Double(index))
            )
            context.insert(StoredActivityEvent(event: event))
        }
        try context.save()

        let firstPage = try await environment.activityPage(limit: 7, cursor: nil)
        XCTAssertEqual(firstPage.items.count, 7)
        XCTAssertNotNil(firstPage.nextCursor)

        let secondPage = try await environment.activityPage(limit: 7, cursor: firstPage.nextCursor)
        XCTAssertEqual(secondPage.items.count, 7)
        XCTAssertTrue(Set(firstPage.items.map(\.id)).isDisjoint(with: Set(secondPage.items.map(\.id))))
        XCTAssertGreaterThan(firstPage.items[0].occurredAt, secondPage.items[0].occurredAt)
    }

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
