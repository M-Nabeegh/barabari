import SwiftUI

struct ContentView: View {
    let environment: AppEnvironment
    @State private var activity: [ActivityEvent] = []
    @State private var selection = Tab.home

    var body: some View {
        TabView(selection: $selection) {
            home
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(Tab.home)

            placeholder("Groups", symbol: "person.2.fill")
                .tabItem { Label("Groups", systemImage: "person.2.fill") }
                .tag(Tab.groups)

            placeholder("Add expense", symbol: "plus.circle.fill")
                .tabItem { Label("Add", systemImage: "plus.circle.fill") }
                .tag(Tab.add)

            placeholder("Activity", symbol: "clock.fill")
                .tabItem { Label("Activity", systemImage: "clock.fill") }
                .tag(Tab.activity)

            placeholder("Settings", symbol: "gearshape.fill")
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .tint(.teal)
        .task {
            activity = (try? await environment.recentActivity(limit: 10)) ?? []
        }
    }

    private var home: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your net balance")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Rs 5,650")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .monospacedDigit()
                        Text("You are owed more than you owe")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Section("Recent activity") {
                    if activity.isEmpty {
                        ContentUnavailableView("No activity yet", systemImage: "receipt")
                    } else {
                        ForEach(activity) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(activityTitle(for: item))
                                Text(item.kind.rawValue.replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression).capitalized)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Barabari")
        }
    }

    private func placeholder(_ title: String, symbol: String) -> some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: symbol, description: Text("Coming in the next Barabari milestone."))
                .navigationTitle(title)
        }
    }

    private func activityTitle(for event: ActivityEvent) -> String {
        switch event.kind {
        case .groupCreated:
            "Group created"
        case .expenseCreated:
            "Expense added"
        case .expenseDeleted:
            "Expense deleted"
        case .settlementRecorded:
            "Settlement recorded"
        case .memberJoined:
            "Member joined"
        case .memberRemoved:
            "Member removed"
        }
    }

    private enum Tab: Hashable {
        case home, groups, add, activity, settings
    }
}
