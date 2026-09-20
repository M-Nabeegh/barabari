import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    let showGroups: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BarabariSpacing.section) {
                switch viewModel.homeState {
                case .loading:
                    loadingView
                case .empty:
                    emptyView
                case let .loaded(snapshot):
                    snapshotView(snapshot, isOffline: false)
                case let .offline(snapshot):
                    snapshotView(snapshot, isOffline: true)
                case let .failed(message):
                    errorView(message)
                }
            }
            .padding(BarabariSpacing.screen)
            .padding(.bottom, BarabariSpacing.section)
        }
        .navigationTitle("Barabari")
        .navigationBarTitleDisplayMode(.large)
        .task { await viewModel.load() }
        .refreshable { await viewModel.refresh() }
    }

    private var loadingView: some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.row) {
            ProgressView()
            Text("Getting your balance ready")
                .foregroundStyle(BarabariColors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .center)
        .accessibilityElement(children: .combine)
    }

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.section) {
            VStack(alignment: .leading, spacing: BarabariSpacing.compact) {
                Text("Split fairly.")
                    .font(BarabariTypography.screenTitle)
                Text("Create a group for your flat, trip, or weekend plans. Barabari keeps the math calm and clear.")
                    .font(BarabariTypography.body)
                    .foregroundStyle(BarabariColors.textSecondary)
            }

            PrimaryActionButton("See your groups", action: showGroups)
                .accessibilityIdentifier("home-see-groups")
        }
        .frame(maxWidth: .infinity, minHeight: 340, alignment: .center)
    }

    private func snapshotView(_ snapshot: HomeSnapshot, isOffline: Bool) -> some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.section) {
            if isOffline {
                StatusBadge("Offline. Showing saved balances.", style: .warning)
                    .accessibilityIdentifier("offline-home-status")
            }

            BarabariCard {
                VStack(alignment: .leading, spacing: BarabariSpacing.row) {
                    Text("Your balance")
                        .font(BarabariTypography.metadata)
                        .foregroundStyle(BarabariColors.textSecondary)
                    AmountText(
                        minorUnits: snapshot.amountOwed.minorUnits - snapshot.amountOwing.minorUnits,
                        currencyCode: "PKR",
                        style: .hero
                    )
                    Text(balanceSummary(for: snapshot))
                        .font(BarabariTypography.body)
                        .foregroundStyle(BarabariColors.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: BarabariSpacing.row) {
                Text("At a glance")
                    .font(BarabariTypography.sectionTitle)
                HStack(spacing: BarabariSpacing.row) {
                    balanceMetric("You are owed", amount: snapshot.amountOwed, color: BarabariColors.success)
                    balanceMetric("You owe", amount: snapshot.amountOwing, color: BarabariColors.danger)
                }
            }

            recentActivity(snapshot.recentActivity)
        }
    }

    private func balanceMetric(_ title: String, amount: Money, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(BarabariTypography.metadata)
                .foregroundStyle(BarabariColors.textSecondary)
            AmountText(minorUnits: amount.minorUnits, currencyCode: amount.currencyCode, style: .compact)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BarabariSpacing.row)
        .background(BarabariColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func recentActivity(_ activity: [ActivityEvent]) -> some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.row) {
            Text("Recent activity")
                .font(BarabariTypography.sectionTitle)

            if activity.isEmpty {
                Text("Your expenses and settlements will appear here.")
                    .font(BarabariTypography.body)
                    .foregroundStyle(BarabariColors.textSecondary)
            } else {
                ForEach(activity) { event in
                    HStack(alignment: .top, spacing: BarabariSpacing.row) {
                        Image(systemName: activitySymbol(for: event.kind))
                            .foregroundStyle(BarabariColors.accent)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(activityTitle(for: event.kind))
                                .font(BarabariTypography.body)
                            Text(event.occurredAt, style: .date)
                                .font(BarabariTypography.metadata)
                                .foregroundStyle(BarabariColors.textSecondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.row) {
            Text("We could not load your balance")
                .font(BarabariTypography.sectionTitle)
            Text(message)
                .foregroundStyle(BarabariColors.textSecondary)
            PrimaryActionButton("Try again") {
                Task { await viewModel.refresh() }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .center)
    }

    private func balanceSummary(for snapshot: HomeSnapshot) -> String {
        switch (snapshot.amountOwed.minorUnits, snapshot.amountOwing.minorUnits) {
        case (0, 0): "You are all settled up."
        case let (owed, owing) where owed >= owing: "You are owed more than you owe."
        default: "You owe more than you are owed."
        }
    }

    private func activityTitle(for kind: ActivityEventKind) -> String {
        switch kind {
        case .groupCreated: "Group created"
        case .expenseCreated: "Expense added"
        case .expenseDeleted: "Expense removed"
        case .settlementRecorded: "Settlement recorded"
        case .memberJoined: "Member joined"
        case .memberRemoved: "Member removed"
        }
    }

    private func activitySymbol(for kind: ActivityEventKind) -> String {
        switch kind {
        case .groupCreated, .memberJoined: "person.2.fill"
        case .expenseCreated: "receipt"
        case .expenseDeleted: "trash"
        case .settlementRecorded: "checkmark.circle.fill"
        case .memberRemoved: "person.fill.xmark"
        }
    }
}
