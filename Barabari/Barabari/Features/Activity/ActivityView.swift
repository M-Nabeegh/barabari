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
            .padding(.bottom, 92)
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

    private func activityRow(_ row: ActivityRow) -> some View {
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
