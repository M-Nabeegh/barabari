import Foundation

struct GroupInvitePayload: Codable, Equatable, Hashable, Sendable {
    static let currentVersion = 1

    let version: Int
    let groupID: UUID
    let groupName: String
    let groupRevision: Int

    init(version: Int, groupID: UUID, groupName: String, groupRevision: Int) {
        self.version = version
        self.groupID = groupID
        self.groupName = groupName
        self.groupRevision = groupRevision
    }
}

enum GroupJoinOutcome: Equatable, Sendable {
    case joined(Group)
    case alreadyMember(Group)
    case unavailable(GroupInvitePayload)
}

enum GroupInviteError: Error, Equatable, Sendable {
    case invalidScheme
    case invalidHost
    case invalidURL
    case missingVersion
    case invalidVersion
    case unsupportedVersion(Int)
    case missingGroupID
    case invalidUUID
    case missingName
    case emptyName
    case nameTooLong
    case missingRevision
    case invalidRevision
    case duplicateQueryItem(String)
    case unexpectedQueryItem(String)
    case missingQueryValue(String)
}
