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

@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var groupPath: [GroupRoute] = []

    func showGroup(_ group: Group) {
        selectedTab = .groups
        groupPath.append(.detail(group.id))
    }
}
