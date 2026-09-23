import XCTest
@testable import Barabari

@MainActor
final class GroupInviteViewModelTests: XCTestCase {
    func testLoadsLocalInvitePayloadAndLink() async throws {
        let environment = AppEnvironment(inMemory: true)
        let group = try await environment.groupRepository.createGroup(
            name: "Weekend plan",
            description: nil,
            ownerID: environment.currentUserID
        )
        let viewModel = GroupInviteViewModel(environment: environment, groupID: group.id)

        await viewModel.load()

        guard case let .loaded(payload, link) = viewModel.state else {
            return XCTFail("Expected a loaded invite")
        }
        XCTAssertEqual(payload.groupID, group.id)
        XCTAssertEqual(payload.groupName, group.name)
        XCTAssertEqual(try GroupInviteCodec.payload(from: link), payload)
    }

    func testMissingLocalGroupShowsUserFacingFailure() async {
        let environment = AppEnvironment(inMemory: true)
        let viewModel = GroupInviteViewModel(environment: environment, groupID: UUID())

        await viewModel.load()

        guard case let .failed(message) = viewModel.state else {
            return XCTFail("Expected a failed invite")
        }
        XCTAssertTrue(message.contains("no longer available"))
    }

    func testQRCodeRendererReturnsImageForInviteLink() throws {
        let payload = GroupInvitePayload(
            version: 1,
            groupID: UUID(),
            groupName: "Weekend plan",
            groupRevision: 1
        )
        let url = try GroupInviteCodec.makeURL(for: payload)

        XCTAssertNotNil(InviteQRCodeImage.render(url: url))
    }

    func testJoinPreviewShowsAvailableLocalGroup() async throws {
        let environment = AppEnvironment(inMemory: true)
        let group = try await environment.groupRepository.createGroup(
            name: "Shared trip",
            description: nil,
            ownerID: environment.currentUserID
        )
        let payload = try await environment.groupRepository.invitePayload(groupID: group.id)
        let url = try GroupInviteCodec.makeURL(for: payload)
        let viewModel = JoinGroupViewModel(environment: environment, initialURL: url)

        await viewModel.parseAndLoad()

        XCTAssertEqual(viewModel.state, .preview(payload: payload, localGroup: group))
    }

    func testJoinPreviewKeepsMissingLocalGroupUnavailable() async throws {
        let environment = AppEnvironment(inMemory: true)
        let payload = GroupInvitePayload(version: 1, groupID: UUID(), groupName: "Shared trip", groupRevision: 1)
        let url = try GroupInviteCodec.makeURL(for: payload)
        let viewModel = JoinGroupViewModel(environment: environment, initialURL: url)

        await viewModel.parseAndLoad()

        XCTAssertEqual(viewModel.state, .preview(payload: payload, localGroup: nil))
    }

    func testMalformedJoinLinkShowsActionableFailure() async {
        let environment = AppEnvironment(inMemory: true)
        let viewModel = JoinGroupViewModel(environment: environment)

        viewModel.parse("https://example.com/not-a-barabari-invite")
        try? await Task.sleep(for: .milliseconds(10))

        guard case let .failed(message) = viewModel.state else {
            return XCTFail("Expected malformed-link failure")
        }
        XCTAssertTrue(message.contains("Barabari invite"))
    }

    func testJoinIsIdempotentAndReturnsTheLocalGroup() async throws {
        let memberID = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!
        let ownerID = UUID(uuidString: "00000000-0000-0000-0000-000000000043")!
        let environment = AppEnvironment(inMemory: true, currentUserID: memberID)
        let group = try await environment.groupRepository.createGroup(
            name: "Shared trip",
            description: nil,
            ownerID: ownerID
        )
        let payload = try await environment.groupRepository.invitePayload(groupID: group.id)
        let url = try GroupInviteCodec.makeURL(for: payload)
        let viewModel = JoinGroupViewModel(environment: environment, initialURL: url)
        await viewModel.parseAndLoad()
        let joinedGroup = await viewModel.join()

        XCTAssertEqual(joinedGroup?.id, group.id)
        let activeMembers = try await environment.groupRepository.members(groupID: group.id).filter(\.isActive)
        XCTAssertEqual(activeMembers.count, 2)
    }
}
