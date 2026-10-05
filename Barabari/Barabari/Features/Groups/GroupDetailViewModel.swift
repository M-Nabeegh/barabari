import Combine
import Foundation

struct GroupDetailSnapshot: Equatable {
    let group: Group
    let members: [GroupMember]
    let balance: BalanceSummary
    let activity: [ActivityEvent]
    let currentUserID: UUID
    var expenses: [UUID: Expense] = [:]
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

    /// Adds a named person to this local group so expenses can be split with them.
    @discardableResult
    func addPerson(named name: String, metadata: LedgerMetadata) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        do {
            let invite = try await environment.groupRepository.invitePayload(groupID: groupID)
            let personID = UUID()
            _ = try await environment.groupRepository.joinGroup(invite: invite, userID: personID)
            metadata.setName(trimmed, for: personID)
            await fetchGroup()
            return true
        } catch {
            return false
        }
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
                activity: try await environment.activity(groupID: groupID),
                currentUserID: environment.currentUserID,
                expenses: Dictionary(
                    uniqueKeysWithValues: try await environment.expenseRepository
                        .listExpenses(groupID: groupID, cursor: nil).items.map { ($0.id, $0) }
                )
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
