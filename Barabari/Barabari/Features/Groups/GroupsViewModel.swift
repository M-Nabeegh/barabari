import Combine
import Foundation

enum GroupsState: Equatable {
    case loading
    case loaded
    case empty
    case offline
    case failed(String)
}

@MainActor
final class GroupsViewModel: ObservableObject {
    @Published private(set) var groups: [Group] = []
    @Published private(set) var state: GroupsState = .loading

    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func load() async {
        state = .loading
        await fetchGroups()
    }

    func refresh() async {
        await fetchGroups()
    }

    @discardableResult
    func createGroup(name: String, description: String?) async -> Group? {
        do {
            let group = try await CreateGroup(repository: environment.groupRepository).call(
                name: name,
                description: description,
                ownerID: environment.currentUserID
            )
            groups.insert(group, at: 0)
            state = environment.isOffline ? .offline : .loaded
            return group
        } catch {
            state = .failed(error.localizedDescription)
            return nil
        }
    }

    private func fetchGroups() async {
        do {
            groups = try await environment.groupRepository.listGroups()
            if groups.isEmpty {
                state = .empty
            } else {
                state = environment.isOffline ? .offline : .loaded
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
