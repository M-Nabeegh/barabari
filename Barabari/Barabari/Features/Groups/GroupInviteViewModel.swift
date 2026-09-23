import Combine
import Foundation

enum GroupInviteState: Equatable {
    case loading
    case loaded(payload: GroupInvitePayload, link: URL)
    case failed(String)
}

@MainActor
final class GroupInviteViewModel: ObservableObject {
    @Published private(set) var state: GroupInviteState = .loading

    private let environment: AppEnvironment
    private let groupID: UUID

    init(environment: AppEnvironment, groupID: UUID) {
        self.environment = environment
        self.groupID = groupID
    }

    func load() async {
        state = .loading
        do {
            let payload = try await environment.groupRepository.invitePayload(groupID: groupID)
            let link = try GroupInviteCodec.makeURL(for: payload)
            state = .loaded(payload: payload, link: link)
        } catch {
            state = .failed(Self.message(for: error))
        }
    }

    private static func message(for error: Error) -> String {
        if let persistenceError = error as? LocalPersistenceError,
           case .missingGroup = persistenceError {
            return "This group is no longer available on this iPhone."
        }
        return "We could not create an invite link. Try again."
    }
}
