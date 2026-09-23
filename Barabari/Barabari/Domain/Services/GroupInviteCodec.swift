import Foundation

enum GroupInviteCodec {
    static let scheme = "barabari"
    static let host = "join"

    static func makeURL(for payload: GroupInvitePayload) throws -> URL {
        try validate(payload)

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [
            URLQueryItem(name: "v", value: String(payload.version)),
            URLQueryItem(name: "group", value: payload.groupID.uuidString.lowercased()),
            URLQueryItem(name: "name", value: payload.groupName),
            URLQueryItem(name: "revision", value: String(payload.groupRevision))
        ]

        guard let url = components.url else {
            throw GroupInviteError.invalidURL
        }
        return url
    }

    static func payload(from url: URL) throws -> GroupInvitePayload {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw GroupInviteError.invalidURL
        }
        try validateControlCharacters(in: components)
        guard components.scheme == scheme else {
            throw GroupInviteError.invalidScheme
        }
        guard components.host == host else {
            throw GroupInviteError.invalidHost
        }
        guard components.percentEncodedHost == host,
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.path.isEmpty,
              components.fragment == nil,
              authorityPrefix(of: url) == "\(scheme)://\(host)" else {
            throw GroupInviteError.invalidAuthority
        }

        var values: [String: String] = [:]
        for item in components.queryItems ?? [] {
            if containsControlCharacters(item.name) || item.value.map(containsControlCharacters) == true {
                throw GroupInviteError.invalidControlCharacter
            }
            guard isSupportedQueryKey(item.name) else {
                throw GroupInviteError.unexpectedQueryItem(item.name)
            }
            guard values[item.name] == nil else {
                throw GroupInviteError.duplicateQueryItem(item.name)
            }
            guard let value = item.value else {
                throw GroupInviteError.missingQueryValue(item.name)
            }
            values[item.name] = value
        }

        guard let versionValue = values["v"] else {
            throw GroupInviteError.missingVersion
        }
        guard let version = Int(versionValue) else {
            throw GroupInviteError.invalidVersion
        }
        guard version == GroupInvitePayload.currentVersion else {
            throw GroupInviteError.unsupportedVersion(version)
        }

        guard let groupValue = values["group"] else {
            throw GroupInviteError.missingGroupID
        }
        guard let groupID = UUID(uuidString: groupValue) else {
            throw GroupInviteError.invalidUUID
        }

        guard let groupName = values["name"] else {
            throw GroupInviteError.missingName
        }
        try validateName(groupName)

        guard let revisionValue = values["revision"], !revisionValue.isEmpty else {
            throw GroupInviteError.missingRevision
        }
        guard let groupRevision = Int(revisionValue), groupRevision > 0 else {
            throw GroupInviteError.invalidRevision
        }

        return GroupInvitePayload(
            version: version,
            groupID: groupID,
            groupName: groupName,
            groupRevision: groupRevision
        )
    }

    private static func validate(_ payload: GroupInvitePayload) throws {
        guard payload.version == GroupInvitePayload.currentVersion else {
            throw GroupInviteError.unsupportedVersion(payload.version)
        }
        try validateName(payload.groupName)
        guard payload.groupRevision > 0 else {
            throw GroupInviteError.invalidRevision
        }
    }

    private static func validateName(_ name: String) throws {
        guard !containsControlCharacters(name) else {
            throw GroupInviteError.invalidControlCharacter
        }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GroupInviteError.emptyName
        }
        guard name.unicodeScalars.count <= 80 else {
            throw GroupInviteError.nameTooLong
        }
    }

    private static func isSupportedQueryKey(_ key: String) -> Bool {
        key == "v" || key == "group" || key == "name" || key == "revision"
    }

    private static func validateControlCharacters(in components: URLComponents) throws {
        let authorityAndPath = [
            components.scheme,
            components.host,
            components.percentEncodedHost,
            components.user,
            components.password,
            components.path,
            components.fragment
        ]
        guard !authorityAndPath.compactMap({ $0 }).contains(where: containsControlCharacters) else {
            throw GroupInviteError.invalidControlCharacter
        }
    }

    private static func containsControlCharacters(_ value: String) -> Bool {
        value.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }

    private static func authorityPrefix(of url: URL) -> String {
        String(url.absoluteString.prefix { $0 != "?" && $0 != "#" })
    }
}
