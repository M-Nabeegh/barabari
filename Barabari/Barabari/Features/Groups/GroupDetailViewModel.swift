import Combine
import Foundation

struct GroupDetailSnapshot: Equatable {
    let group: Group
    let members: [GroupMember]
    let balance: BalanceSummary
    let activity: [ActivityEvent]
}

enum GroupDetailState: Equatable {
    case loading
    case loaded(GroupDetailSnapshot)
    case offline(GroupDetailSnapshot)
    case failed(String)
}

@MainActor
final class GroupDetailViewModel: ObservableObject {
    @Published private(set) var state: GroupDetailState = .loading

    private let environment: AppEnvironment
    private let groupID: UUID

    init(environment: AppEnvironment, groupID: UUID) {
        self.environment = environment
        self.groupID = groupID
    }

    func load() async {
        state = .loading
        await fetchGroup()
    }

    func refresh() async {
        await fetchGroup()
    }

    private func fetchGroup() async {
        do {
            guard let group = try await environment.groupRepository.listGroups().first(where: { $0.id == groupID }) else {
                throw GroupDetailLoadingError.groupNotFound
            }
            let snapshot = GroupDetailSnapshot(
                group: group,
                members: try await environment.groupRepository.members(groupID: groupID),
                balance: try await environment.balanceRepository.summary(groupID: groupID),
                activity: try await environment.activity(groupID: groupID)
            )
            state = environment.isOffline ? .offline(snapshot) : .loaded(snapshot)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

private enum GroupDetailLoadingError: LocalizedError {
    case groupNotFound

    var errorDescription: String? {
        "This group is no longer available on this iPhone."
    }
}
