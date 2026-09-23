import SwiftUI

struct RootView: View {
    let environment: AppEnvironment

    @StateObject private var router: AppRouter
    @StateObject private var session: LedgerSession
    @StateObject private var homeViewModel: HomeViewModel
    @StateObject private var groupsViewModel: GroupsViewModel
    @StateObject private var addExpenseViewModel: AddExpenseViewModel
    @AppStorage("barabari.appearance") private var appearanceRawValue = "dark"

    init(environment: AppEnvironment) {
        self.environment = environment
        _router = StateObject(wrappedValue: AppRouter())
        _session = StateObject(wrappedValue: LedgerSession())
        _homeViewModel = StateObject(wrappedValue: HomeViewModel(environment: environment))
        _groupsViewModel = StateObject(wrappedValue: GroupsViewModel(environment: environment))
        _addExpenseViewModel = StateObject(wrappedValue: AddExpenseViewModel(environment: environment))
    }

    var body: some View {
        TabView(selection: $router.selectedTab) {
            NavigationStack {
                HomeView(viewModel: homeViewModel, revision: session.revision) {
                    router.selectedTab = .groups
                }
            }
            .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.systemImage) }
            .tag(AppTab.home)

            NavigationStack(path: $router.groupPath) {
                GroupsView(
                    viewModel: groupsViewModel,
                    revision: session.revision,
                    onChanged: session.markChanged,
                    selectGroup: { group in
                        router.showGroup(group)
                    },
                    onJoin: { router.presentJoin() }
                )
                .navigationDestination(for: GroupRoute.self) { route in
                    switch route {
                    case let .detail(groupID):
                        GroupDetailView(
                            environment: environment,
                            groupID: groupID,
                            revision: session.revision,
                            onChanged: session.markChanged,
                            onInvite: { router.presentInvite(groupID: groupID) }
                        )
                    }
                }
            }
            .tabItem { Label(AppTab.groups.title, systemImage: AppTab.groups.systemImage) }
            .tag(AppTab.groups)

            NavigationStack {
                AddExpenseView(viewModel: addExpenseViewModel, session: session)
            }
            .tabItem { Label(AppTab.addExpense.title, systemImage: AppTab.addExpense.systemImage) }
            .tag(AppTab.addExpense)

            NavigationStack {
                ActivityView(environment: environment, revision: session.revision)
            }
            .tabItem { Label(AppTab.activity.title, systemImage: AppTab.activity.systemImage) }
            .tag(AppTab.activity)

            NavigationStack {
                SettingsView(environment: environment, isDemo: environment.isDemo)
            }
            .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage) }
            .tag(AppTab.settings)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BarabariTabBar(selection: $router.selectedTab)
                .padding(.horizontal, 12)
                .padding(.top, 5)
                .padding(.bottom, 2)
                .background(BarabariColors.background.opacity(0.94))
        }
        .tint(BarabariColors.accent)
        .background(BarabariColors.background)
        .sheet(item: $router.invitePresentation) { presentation in
            switch presentation {
            case let .invite(groupID):
                GroupInviteView(environment: environment, groupID: groupID)
            case let .join(url):
                JoinGroupView(environment: environment, initialURL: url) { group in
                    session.markChanged()
                    router.dismissInvitePresentation()
                    router.showGroup(group)
                }
            }
        }
        .onOpenURL { url in
            router.presentJoin(url: url)
        }
        .preferredColorScheme(BarabariAppearance(rawValue: appearanceRawValue)?.colorScheme)
    }
}
