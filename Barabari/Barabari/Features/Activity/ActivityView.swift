import SwiftUI

struct ActivityView: View {
    let revision: Int

    @StateObject private var viewModel: ActivityViewModel

    init(environment: AppEnvironment, revision: Int) {
        self.revision = revision
        _viewModel = StateObject(wrappedValue: ActivityViewModel(environment: environment))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: BarabariSpacing.section) {
                switch viewModel.state {
                case .idle, .loading:
                    ProgressView("Loading activity")
                        .frame(maxWidth: .infinity, minHeight: 240)
                case .empty:
                    ContentUnavailableView(
                        "No activity yet",
                        systemImage: "clock",
                        description: Text("Expenses and settlements will appear here.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 300)
                case .loaded:
                    header
                    ForEach(viewModel.rows) { row in
                        activityRow(row)
                            .onAppear {
                                Task { await viewModel.loadNextPageIfNeeded(lastID: row.id) }
                            }
                    }
                    if viewModel.isLoadingNextPage {
                        ProgressView("Loading more")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, BarabariSpacing.compact)
                    }
                case let .failed(message):
                    VStack(alignment: .leading, spacing: BarabariSpacing.row) {
                        Text("We could not load activity")
                            .font(BarabariTypography.sectionTitle)
                        Text(message)
                            .foregroundStyle(BarabariColors.textSecondary)
                        PrimaryActionButton("Try again") {
                            Task { await viewModel.load() }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 260, alignment: .center)
                }
            }
            .padding(BarabariSpacing.screen)
            .padding(.bottom, BarabariSpacing.bottomContent)
        }
        .background(BarabariColors.background)
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.large)
        .task(id: revision) { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your shared ledger")
                .font(BarabariTypography.sectionTitle)
            Text("A simple record of expenses and payments you have already made.")
                .font(BarabariTypography.body)
                .foregroundStyle(BarabariColors.textSecondary)
        }
    }

    @ViewBuilder
    private func activityRow(_ row: ActivityRow) -> some View {
        switch route(for: row) {
        case let .expense(expense):
            NavigationLink {
                ExpenseDetailView(expense: expense)
            } label: {
                activityRowContent(row)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("activity-row-\(row.id.uuidString)")
            .accessibilityHint("Open expense details")
        case let .settlement(settlement):
            NavigationLink {
                SettlementDetailView(settlement: settlement)
            } label: {
                activityRowContent(row)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("activity-row-\(row.id.uuidString)")
            .accessibilityHint("Open settlement details")
        case let .event(event):
            NavigationLink {
                ActivityEventDetailView(event: event)
            } label: {
                activityRowContent(row)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("activity-row-\(row.id.uuidString)")
            .accessibilityHint("Open activity details")
        }
    }

    private func activityRowContent(_ row: ActivityRow) -> some View {
        BarabariCard {
            HStack(alignment: .top, spacing: BarabariSpacing.row) {
                Image(systemName: symbol(for: row.event.kind))
                    .font(.headline)
                    .foregroundStyle(row.event.kind == .settlementRecorded ? BarabariColors.success : BarabariColors.accent)
                    .frame(width: 28, height: 28)
                    .background(BarabariColors.raised, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(title(for: row))
                        .font(BarabariTypography.body)
                    if let detail = detail(for: row) {
                        Text(detail)
                            .font(BarabariTypography.metadata)
                            .foregroundStyle(BarabariColors.textSecondary)
                    }
                    Text(row.event.occurredAt, style: .date)
                        .font(BarabariTypography.metadata)
                        .foregroundStyle(BarabariColors.textSecondary)
                }
                Spacer(minLength: 0)
                if let amount = row.settlement?.amount ?? row.expense?.total {
                    AmountText(minorUnits: amount.minorUnits, currencyCode: amount.currencyCode, style: .compact)
                }
            }
        }
        .barabariHitTarget(minHeight: 64)
    }

    private func route(for row: ActivityRow) -> ActivityRoute {
        if let expense = row.expense { return .expense(expense) }
        if let settlement = row.settlement { return .settlement(settlement) }
        return .event(row.event)
    }

    private func title(for row: ActivityRow) -> String {
        switch row.event.kind {
        case .groupCreated: "Group created"
        case .expenseCreated: row.expense.map { "\($0.title) added" } ?? "Expense added"
        case .expenseDeleted: "Expense removed"
        case .settlementRecorded: "Settlement recorded"
        case .memberJoined: "Member joined"
        case .memberRemoved: "Member removed"
        }
    }

    private func detail(for row: ActivityRow) -> String? {
        if let settlement = row.settlement {
            return "\(settlement.method.title) · local confirmation"
        }
        if let expense = row.expense {
            return expense.note
        }
        return nil
    }

    private func symbol(for kind: ActivityEventKind) -> String {
        switch kind {
        case .groupCreated, .memberJoined: "person.2.fill"
        case .expenseCreated: "receipt"
        case .expenseDeleted: "trash"
        case .settlementRecorded: "checkmark.circle.fill"
        case .memberRemoved: "person.fill.xmark"
        }
    }
}

private enum ActivityRoute {
    case expense(Expense)
    case settlement(Settlement)
    case event(ActivityEvent)
}

private struct SettlementDetailView: View {
    let settlement: Settlement

    var body: some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.section) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(BarabariColors.success)
            Text("Settlement recorded")
                .font(BarabariTypography.screenTitle)
            AmountText(minorUnits: settlement.amount.minorUnits, currencyCode: settlement.amount.currencyCode, style: .hero)
            Text("Method: \(settlement.method.title)")
                .font(BarabariTypography.body)
            Text("Saved locally on this iPhone.")
                .font(BarabariTypography.body)
                .foregroundStyle(BarabariColors.textSecondary)
        }
        .padding(BarabariSpacing.screen)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(BarabariColors.background)
        .navigationTitle("Settlement")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ActivityEventDetailView: View {
    let event: ActivityEvent

    var body: some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.section) {
            Image(systemName: "clock.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(BarabariColors.accent)
            Text(title)
                .font(BarabariTypography.screenTitle)
            HStack(spacing: 4) {
                Text("Recorded locally on")
                Text(event.occurredAt, style: .date)
            }
            .font(BarabariTypography.body)
            .foregroundStyle(BarabariColors.textSecondary)
        }
        .padding(BarabariSpacing.screen)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(BarabariColors.background)
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var title: String {
        switch event.kind {
        case .groupCreated: "Group created"
        case .expenseCreated: "Expense added"
        case .expenseDeleted: "Expense removed"
        case .settlementRecorded: "Settlement recorded"
        case .memberJoined: "Member joined"
        case .memberRemoved: "Member removed"
        }
    }
}
