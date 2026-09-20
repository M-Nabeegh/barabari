import SwiftUI

private struct ActivityRow: Identifiable {
    let event: ActivityEvent
    let expense: Expense?
    let settlement: Settlement?

    var id: UUID { event.id }
}

private enum ActivityLoadingState {
    case loading
    case loaded([ActivityRow])
    case empty
    case failed(String)
}

struct ActivityView: View {
    let environment: AppEnvironment

    @State private var state: ActivityLoadingState = .loading

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BarabariSpacing.section) {
                switch state {
                case .loading:
                    ProgressView("Loading activity")
                        .frame(maxWidth: .infinity, minHeight: 240)
                case .empty:
                    ContentUnavailableView(
                        "No activity yet",
                        systemImage: "clock",
                        description: Text("Expenses and settlements will appear here.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 300)
                case let .loaded(rows):
                    header
                    ForEach(rows) { row in
                        activityRow(row)
                    }
                case let .failed(message):
                    VStack(alignment: .leading, spacing: BarabariSpacing.row) {
                        Text("We could not load activity")
                            .font(BarabariTypography.sectionTitle)
                        Text(message)
                            .foregroundStyle(BarabariColors.textSecondary)
                        PrimaryActionButton("Try again") {
                            Task { await load() }
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
        .task { await load() }
        .refreshable { await load() }
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

    private func load() async {
        state = .loading
        do {
            let groups = try await environment.groupRepository.listGroups()
            var activity: [ActivityEvent] = []
            var expenses: [UUID: Expense] = [:]
            var settlements: [UUID: Settlement] = [:]
            for group in groups {
                activity += try await environment.activity(groupID: group.id)
                for expense in try await environment.expenseRepository.listExpenses(groupID: group.id, cursor: nil).items {
                    expenses[expense.id] = expense
                }
                for settlement in try await environment.settlementRepository.listSettlements(groupID: group.id, cursor: nil).items {
                    settlements[settlement.id] = settlement
                }
            }
            let rows = activity
                .filter { $0.deletedAt == nil }
                .sorted { lhs, rhs in
                    lhs.occurredAt == rhs.occurredAt
                        ? lhs.id.uuidString < rhs.id.uuidString
                        : lhs.occurredAt > rhs.occurredAt
                }
                .map { ActivityRow(event: $0, expense: expenses[$0.subjectID], settlement: settlements[$0.subjectID]) }
            state = rows.isEmpty ? .empty : .loaded(rows)
        } catch {
            state = .failed(error.localizedDescription)
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
