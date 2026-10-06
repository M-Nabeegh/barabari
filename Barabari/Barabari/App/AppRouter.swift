import Combine
import Foundation

enum AppTab: String, CaseIterable, Hashable, Identifiable {
    case home
    case groups
    case money
    case addExpense
    case activity

    var id: Self { self }

    var title: String {
        switch self {
        case .home: "Home"
        case .groups: "Groups"
        case .money: "Money"
        case .addExpense: "Add"
        case .activity: "Activity"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .groups: "person.2.fill"
        case .money: "wallet.bifold.fill"
        case .addExpense: "plus"
        case .activity: "list.bullet.rectangle.fill"
        }
    }
}

enum GroupRoute: Hashable {
    case detail(UUID)
}

enum InvitePresentation: Identifiable, Equatable {
    case invite(groupID: UUID)
    case join(URL?)

    var id: String {
        switch self {
        case let .invite(groupID):
            return "invite-\(groupID.uuidString)"
        case let .join(url):
            return "join-\(url?.absoluteString ?? "empty")"
        }
    }
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var groupPath: [GroupRoute] = []
    @Published var invitePresentation: InvitePresentation?
    @Published var isPresentingCreateGroup = false
    @Published var isShowingSettings = false

    func showGroup(_ group: Group) {
        selectedTab = .groups
        groupPath.append(.detail(group.id))
    }

    func presentInvite(groupID: UUID) {
        invitePresentation = .invite(groupID: groupID)
    }

    func presentJoin(url: URL? = nil) {
        invitePresentation = .join(url)
    }

    func dismissInvitePresentation() {
        invitePresentation = nil
    }
}
