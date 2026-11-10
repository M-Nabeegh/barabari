import SwiftUI

struct RootView: View {
    let environment: AppEnvironment

    @StateObject private var router: AppRouter
    @StateObject private var session: LedgerSession
    @StateObject private var homeViewModel: HomeViewModel
    @StateObject private var groupsViewModel: GroupsViewModel
    @StateObject private var addExpenseViewModel: AddExpenseViewModel
    @StateObject private var sync: SyncEngine
    @ObservedObject private var metadata = LedgerMetadata.shared
    @AppStorage("barabari.appearance") private var appearanceRawValue = "dark"
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var groupTransition

    init(environment: AppEnvironment) {
        self.environment = environment
        _router = StateObject(wrappedValue: AppRouter())
        _session = StateObject(wrappedValue: LedgerSession())
        _homeViewModel = StateObject(wrappedValue: HomeViewModel(environment: environment))
        _groupsViewModel = StateObject(wrappedValue: GroupsViewModel(environment: environment))
        _addExpenseViewModel = StateObject(wrappedValue: AddExpenseViewModel(environment: environment))
        _sync = StateObject(wrappedValue: SyncEngine(environment: environment))
    }

    var body: some View {
        TabView(selection: tabSelection) {
            Tab(LocalizedStringKey(AppTab.home.title), systemImage: AppTab.home.systemImage, value: AppTab.home) {
                NavigationStack {
                    HomeView(
                        viewModel: homeViewModel,
                        groupsViewModel: groupsViewModel,
                        revision: session.revision,
                        showGroups: { router.selectedTab = .groups },
                        addExpense: { router.selectedTab = .addExpense },
                        createGroup: {
                            router.selectedTab = .groups
                            router.isPresentingCreateGroup = true
                        },
                        joinGroup: { router.presentJoin() },
                        openSettings: { router.isShowingSettings = true },
                        selectGroup: { router.showGroup($0) }
                    )
                }
            }

            Tab(LocalizedStringKey(AppTab.groups.title), systemImage: AppTab.groups.systemImage, value: AppTab.groups) {
                NavigationStack(path: $router.groupPath) {
                    GroupsView(
                        viewModel: groupsViewModel,
                        revision: session.revision,
                        transitionNamespace: groupTransition,
                        isPresentingCreateGroup: $router.isPresentingCreateGroup,
                        onChanged: session.markChanged,
                        selectGroup: { router.showGroup($0) },
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
                                onInvite: { router.presentInvite(groupID: groupID) },
                                onAddExpense: {
                                    addExpenseViewModel.selectGroup(groupID)
                                    router.selectedTab = .addExpense
                                }
                            )
                            .navigationTransition(.zoom(sourceID: groupID, in: groupTransition))
                        }
                    }
                }
            }

            Tab(LocalizedStringKey(AppTab.money.title), systemImage: AppTab.money.systemImage, value: AppTab.money) {
                NavigationStack {
                    MoneyView(environment: environment, revision: session.revision) {
                        addExpenseViewModel.choosePersonal()
                        router.selectedTab = .addExpense
                    }
                }
            }

            Tab(LocalizedStringKey(AppTab.activity.title), systemImage: AppTab.activity.systemImage, value: AppTab.activity) {
                NavigationStack {
                    ActivityView(environment: environment, revision: session.revision)
                }
            }


            // The trailing, detached glass button: always one tap from a new expense.
            Tab(LocalizedStringKey(AppTab.addExpense.title), systemImage: AppTab.addExpense.systemImage, value: AppTab.addExpense, role: .search) {
                NavigationStack {
                    AddExpenseView(viewModel: addExpenseViewModel, session: session)
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(BarabariColors.accent)
        .sensoryFeedback(.selection, trigger: router.selectedTab)
        .onChange(of: router.selectedTab) { previous, _ in
            // Leaving Add after a save: start fresh next time instead of showing the old receipt.
            if previous == .addExpense,
               addExpenseViewModel.savedExpense != nil || addExpenseViewModel.savedPersonal != nil {
                addExpenseViewModel.addAnotherExpense()
            }
        }
        .onChange(of: session.localWrites) { _, _ in sync.localDataChanged() }
        .onChange(of: metadata.ownerName) { _, _ in sync.localDataChanged() }
        .onChange(of: sync.remoteChangeCount) { _, _ in session.markRemoteChanged() }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active:
                sync.appBecameActive()
                Task {
                    let added = await RecurringExpenseStore.shared.postDue(environment: environment)
                    if added > 0 { session.markChanged() }
                }
            case .background: sync.appWentToBackground()
            default: break
            }
        }
        .sheet(item: $router.invitePresentation) { presentation in
            switch presentation {
            case let .invite(groupID):
                GroupInviteView(environment: environment, groupID: groupID)
            case let .join(url):
                JoinGroupView(environment: environment, sync: sync.isEnabled ? sync : nil, initialURL: url) { group in
                    session.markChanged()
                    router.dismissInvitePresentation()
                    router.showGroup(group)
                }
            }
        }
        .sheet(isPresented: $router.isShowingSettings) {
            NavigationStack {
                SettingsView(environment: environment, isDemo: environment.isDemo)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done", systemImage: "checkmark") { router.isShowingSettings = false }
                                .accessibilityIdentifier("settings-done")
                        }
                    }
            }
        }
        .onOpenURL { url in
            if url.host() == "home" {
                router.selectedTab = .home
            } else {
                router.presentJoin(url: url)
            }
        }
        .preferredColorScheme(BarabariAppearance(rawValue: appearanceRawValue)?.colorScheme)
        // Outermost, so sheets (invites, joins) see the sync engine too.
        .environment(\.syncEngine, sync.isEnabled ? sync : nil)
    }

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { router.selectedTab },
            set: { router.selectedTab = $0 }
        )
    }
}
