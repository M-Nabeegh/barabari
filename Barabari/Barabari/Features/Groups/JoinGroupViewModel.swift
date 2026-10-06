import Combine
import Foundation

enum JoinGroupState: Equatable {
    case idle
    case preview(payload: GroupInvitePayload, localGroup: Group?)
    /// The group lives in the cloud and this phone can join it.
    case cloudPreview(payload: GroupInvitePayload, preview: CloudGroupPreview)
    case joining
    case joined(GroupJoinOutcome)
    case failed(String)
}

@MainActor
final class JoinGroupViewModel: ObservableObject {
    @Published var linkText: String
    @Published private(set) var state: JoinGroupState = .idle
    /// The person added by name that this phone is joining as, if any.
    @Published var claimedSpot: UUID?

    private let environment: AppEnvironment
    private let sync: SyncEngine?
    private let initialURL: URL?
    private var isJoining = false

    init(environment: AppEnvironment, sync: SyncEngine? = nil, initialURL: URL? = nil) {
        self.environment = environment
        self.sync = sync
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
            let localGroup: Group?
            do {
                localGroup = try await environment.groupRepository.listGroups().first { $0.id == payload.groupID }
            } catch {
                state = .failed("We could not check your local groups. Try again.")
                return
            }
            guard localGroup == nil, let sync else {
                state = .preview(payload: payload, localGroup: localGroup)
                return
            }
            do {
                if let preview = try await sync.preview(groupID: payload.groupID) {
                    claimedSpot = nil
                    state = .cloudPreview(payload: payload, preview: preview)
                } else {
                    state = .failed("This group isn’t available any more. Ask for a fresh invite.")
                }
            } catch SupabaseError.offline {
                state = .failed("You’re offline. Connect to the internet to join this group.")
            } catch {
                state = .failed("We couldn’t reach Barabari Cloud. Try again in a moment.")
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

    /// Joins through the cloud, then returns the group once it is on this phone.
    @discardableResult
    func joinCloud() async -> Group? {
        guard !isJoining, let sync else { return nil }
        guard case let .cloudPreview(payload, _) = state else { return nil }

        isJoining = true
        state = .joining
        defer { isJoining = false }

        do {
            try await sync.join(groupID: payload.groupID, claiming: claimedSpot)
            if let group = try await environment.groupRepository.listGroups().first(where: { $0.id == payload.groupID }) {
                state = .joined(.joined(group))
                return group
            }
            state = .failed("You joined, but the group is still downloading. Pull to refresh in a moment.")
        } catch SupabaseError.offline {
            state = .failed("You’re offline. Connect to the internet to join this group.")
        } catch {
            state = .failed("We could not join this group. Try again.")
        }
        return nil
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
