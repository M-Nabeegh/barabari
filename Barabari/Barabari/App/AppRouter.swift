import Combine
import Foundation

enum AppTab: String, CaseIterable, Hashable, Identifiable {
    case home
    case groups
    case addExpense
    case activity
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .home: "Home"
        case .groups: "Groups"
        case .addExpense: "Add"
        case .activity: "Activity"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .groups: "person.2.fill"
        case .addExpense: "plus"
        case .activity: "clock.fill"
        case .settings: "gearshape.fill"
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
