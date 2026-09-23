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
}
