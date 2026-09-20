import SwiftUI

struct RootView: View {
    let environment: AppEnvironment

    @StateObject private var router: AppRouter
    @StateObject private var homeViewModel: HomeViewModel
    @StateObject private var groupsViewModel: GroupsViewModel

    init(environment: AppEnvironment) {
        self.environment = environment
        _router = StateObject(wrappedValue: AppRouter())
        _homeViewModel = StateObject(wrappedValue: HomeViewModel(environment: environment))
        _groupsViewModel = StateObject(wrappedValue: GroupsViewModel(environment: environment))
    }

    var body: some View {
        NavigationStack(path: $router.groupPath) {
            ZStack(alignment: .bottom) {
                BarabariColors.background
                    .ignoresSafeArea()

                selectedContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, 78)

                BarabariTabBar(selection: $router.selectedTab)
                    .padding(.horizontal, BarabariSpacing.screen)
                    .padding(.bottom, BarabariSpacing.compact)
            }
            .navigationDestination(for: GroupRoute.self) { route in
                switch route {
                case let .detail(groupID):
                    GroupDetailView(environment: environment, groupID: groupID)
                }
            }
        }
        .tint(BarabariColors.accent)
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch router.selectedTab {
        case .home:
            HomeView(viewModel: homeViewModel) {
                router.selectedTab = .groups
            }
        case .groups:
            GroupsView(viewModel: groupsViewModel) { group in
                router.showGroup(group)
            }
        case .addExpense:
            AddExpenseView(environment: environment)
        case .activity:
            ActivityView(environment: environment)
        case .settings:
            SettingsView()
        }
    }
}
