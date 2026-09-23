import Foundation
import XCTest
@testable import Barabari

final class GroupInviteTests: XCTestCase {
    private let groupID = UUID(uuidString: "00000000-0000-0000-0000-000000000123")!

    func testInviteURLRoundTripsAndPercentEncodesDisplayName() throws {
        let payload = GroupInvitePayload(
            version: 1,
            groupID: groupID,
            groupName: "Lahore 🥘 & Flat 404",
            groupRevision: 3
        )

        let url = try GroupInviteCodec.makeURL(for: payload)

        XCTAssertEqual(url.scheme, "barabari")
        XCTAssertEqual(url.host, "join")
        XCTAssertFalse(url.absoluteString.contains("Lahore 🥘"))
        XCTAssertEqual(try GroupInviteCodec.payload(from: url), payload)
    }

    func testUnsupportedInviteInputFailsClosed() {
        assertInviteError(
            URL(string: "https://example.com")!,
            equals: .invalidScheme
        )
        assertInviteError(
            URL(string: "barabari://other?v=1&group=00000000-0000-0000-0000-000000000123&name=Trip&revision=1")!,
            equals: .invalidHost
        )
        assertInviteError(
            URL(string: "barabari://join?group=00000000-0000-0000-0000-000000000123&name=Trip&revision=1")!,
            equals: .missingVersion
        )
        assertInviteError(
            URL(string: "barabari://join?v=99&group=00000000-0000-0000-0000-000000000123&name=Trip&revision=1")!,
            equals: .unsupportedVersion(99)
        )
        assertInviteError(
            URL(string: "barabari://join?v=1&group=not-a-uuid&name=Trip&revision=1")!,
            equals: .invalidUUID
        )
        assertInviteError(
            URL(string: "barabari://join?v=1&group=00000000-0000-0000-0000-000000000123&name=&revision=1")!,
            equals: .emptyName
        )
        assertInviteError(
            URL(string: "barabari://join?v=1&group=00000000-0000-0000-0000-000000000123&name=Trip&revision=0")!,
            equals: .invalidRevision
        )
    }

    func testInviteNameLengthAndPayloadValidation() throws {
        let tooLong = GroupInvitePayload(
            version: 1,
            groupID: groupID,
            groupName: String(repeating: "a", count: 81),
            groupRevision: 1
        )
        XCTAssertThrowsError(try GroupInviteCodec.makeURL(for: tooLong)) { error in
            XCTAssertEqual(error as? GroupInviteError, .nameTooLong)
        }

        let unsupported = GroupInvitePayload(
            version: 2,
            groupID: groupID,
            groupName: "Trip",
            groupRevision: 1
        )
        XCTAssertThrowsError(try GroupInviteCodec.makeURL(for: unsupported)) { error in
            XCTAssertEqual(error as? GroupInviteError, .unsupportedVersion(2))
        }

        let invalidRevision = GroupInvitePayload(
            version: 1,
            groupID: groupID,
            groupName: "Trip",
            groupRevision: 0
        )
        XCTAssertThrowsError(try GroupInviteCodec.makeURL(for: invalidRevision)) { error in
            XCTAssertEqual(error as? GroupInviteError, .invalidRevision)
        }
    }

    func testHostileInviteAuthorityAndControlCharactersFailClosed() {
        let query = "v=1&group=00000000-0000-0000-0000-000000000123&name=Trip&revision=1"
        assertInviteError(
            URL(string: "barabari://user:password@join?\(query)")!,
            equals: .invalidAuthority
        )
        assertInviteError(
            URL(string: "barabari://join:443?\(query)")!,
            equals: .invalidAuthority
        )
        assertInviteError(
            URL(string: "barabari://join/path?\(query)")!,
            equals: .invalidAuthority
        )
        assertInviteError(
            URL(string: "barabari://join?\(query)#fragment")!,
            equals: .invalidAuthority
        )
        assertInviteError(
            URL(string: "barabari://jo%69n?\(query)")!,
            equals: .invalidAuthority
        )
        assertInviteError(
            URL(string: "barabari://join?v=1&group=00000000-0000-0000-0000-000000000123&name=Trip%0A&revision=1")!,
            equals: .invalidControlCharacter
        )
    }

    func testGroupJoinOutcomeCarriesTheExpectedDomainValue() {
        let group = Group(name: "Trip", description: nil, ownerID: groupID)
        let payload = GroupInvitePayload(version: 1, groupID: group.id, groupName: group.name, groupRevision: group.revision)

        XCTAssertEqual(GroupJoinOutcome.joined(group), .joined(group))
        XCTAssertEqual(GroupJoinOutcome.alreadyMember(group), .alreadyMember(group))
        XCTAssertEqual(GroupJoinOutcome.unavailable(payload), .unavailable(payload))
    }

    private func assertInviteError(
        _ url: URL,
        equals expected: GroupInviteError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try GroupInviteCodec.payload(from: url), file: file, line: line) { error in
            XCTAssertEqual(error as? GroupInviteError, expected, file: file, line: line)
        }
    }
}
