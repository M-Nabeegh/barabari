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
    @Published private(set) var isCreating = false
    @Published private(set) var creationError: String?

    private let environment: AppEnvironment
    private let createGroupOperation: (String, String?, UUID) async throws -> Group

    init(
        environment: AppEnvironment,
        createGroupOperation: ((String, String?, UUID) async throws -> Group)? = nil
    ) {
        self.environment = environment
        self.createGroupOperation = createGroupOperation ?? { name, description, ownerID in
            try await CreateGroup(repository: environment.groupRepository).call(
                name: name,
                description: description,
                ownerID: ownerID
            )
        }
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
        guard !isCreating else { return nil }

        isCreating = true
        creationError = nil
        defer { isCreating = false }

        do {
            let group = try await createGroupOperation(name, description, environment.currentUserID)
            groups.insert(group, at: 0)
            state = environment.isOffline ? .offline : .loaded
            return group
        } catch {
            creationError = error.localizedDescription
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
