import Combine
import Foundation

enum JoinGroupState: Equatable {
    case idle
    case preview(payload: GroupInvitePayload, localGroup: Group?)
    case joining
    case joined(GroupJoinOutcome)
    case failed(String)
}

@MainActor
final class JoinGroupViewModel: ObservableObject {
    @Published var linkText: String
    @Published private(set) var state: JoinGroupState = .idle

    private let environment: AppEnvironment
    private let initialURL: URL?
    private var isJoining = false

    init(environment: AppEnvironment, initialURL: URL? = nil) {
        self.environment = environment
        self.initialURL = initialURL
        linkText = initialURL?.absoluteString ?? ""
    }

    func parseAndLoad() async {
        let value = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            if initialURL == nil { state = .idle }
            return
        }

        guard let url = URL(string: value) else {
            state = .failed("That invite link is not valid.")
            return
        }
        await parseURL(url)
    }

    func parse(_ url: URL) {
        Task { await parseURL(url) }
    }

    private func parseURL(_ url: URL) async {
        do {
            let payload = try GroupInviteCodec.payload(from: url)
            do {
                let groups = try await environment.groupRepository.listGroups()
                let localGroup = groups.first { $0.id == payload.groupID }
                state = .preview(payload: payload, localGroup: localGroup)
            } catch {
                state = .failed("We could not check your local groups. Try again.")
            }
        } catch {
            state = .failed(Self.message(for: error))
        }
    }

    func parse(_ rawValue: String) {
        linkText = rawValue
        Task { await parseAndLoad() }
    }

    @discardableResult
    func join() async -> Group? {
        guard !isJoining else { return nil }
        guard case let .preview(payload, localGroup: localGroup?) = state else { return nil }

        isJoining = true
        state = .joining
        defer { isJoining = false }

        do {
            let outcome = try await environment.groupRepository.joinGroup(
                invite: payload,
                userID: environment.currentUserID
            )
            state = .joined(outcome)
            switch outcome {
            case let .joined(group), let .alreadyMember(group):
                return group
            case .unavailable:
                return localGroup
            }
        } catch {
            state = .failed("We could not join this group. Try again.")
            return nil
        }
    }

    private static func message(for error: Error) -> String {
        if let inviteError = error as? GroupInviteError {
            switch inviteError {
            case .invalidScheme, .invalidHost, .invalidAuthority, .invalidURL:
                return "Use a Barabari invite link that starts with barabari://join."
            case .unsupportedVersion:
                return "This invite was made by a newer version of Barabari."
            default:
                return "That invite link is incomplete or invalid."
            }
        }
        return "That invite link is not valid."
    }
}
