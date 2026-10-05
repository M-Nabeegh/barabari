import SwiftUI

struct ActivityView: View {
    let revision: Int
    private let currentUserID: UUID

    @StateObject private var viewModel: ActivityViewModel
    @ObservedObject private var metadata = LedgerMetadata.shared

    init(environment: AppEnvironment, revision: Int) {
        self.revision = revision
        self.currentUserID = environment.currentUserID
        _viewModel = StateObject(wrappedValue: ActivityViewModel(environment: environment))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: BarabariSpacing.section) {
                switch viewModel.state {
                case .idle, .loading:
                    BarabariLoadingState(title: "Loading activity")
                case .empty:
                    BarabariEmptyState(
                        systemImage: "list.bullet.rectangle",
                        title: "No activity yet",
                        message: "Expenses and settlements will appear here."
                    )
                case .loaded:
                    ForEach(Array(daySections.enumerated()), id: \.element.day) { sectionIndex, section in
                        VStack(alignment: .leading, spacing: BarabariSpacing.compact) {
                            Text(LocalizedStringKey(dayTitle(section.day)))
                                .font(BarabariTypography.eyebrow)
                                .textCase(.uppercase)
                                .tracking(0.8)
                                .foregroundStyle(BarabariColors.textSecondary)
                                .padding(.horizontal, 4)
                            BarabariCard(padding: 0) {
                                VStack(spacing: 0) {
                                    ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                                        if index > 0 { RowDivider() }
                                        activityRow(row)
                                            .onAppear {
                                                Task { await viewModel.loadNextPageIfNeeded(lastID: row.id) }
                                            }
                                    }
                                }
                            }
                        }
                        .staggeredAppear(sectionIndex)
                    }
                    if viewModel.isLoadingNextPage {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, BarabariSpacing.compact)
                    }
                case let .failed(message):
                    BarabariEmptyState(
                        systemImage: "exclamationmark.triangle.fill",
                        title: "We could not load activity",
                        message: message
                    ) {
                        PrimaryActionButton("Try again") {
                            Task { await viewModel.load() }
                        }
                    }
                }
            }
            .padding(.top, 4)
            .barabariScreen()
        }
        .scrollIndicators(.hidden)
        .background(BarabariColors.background)
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.large)
        .task(id: revision) { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private struct DaySection {
        let day: Date
        let rows: [ActivityRow]
    }

    private var daySections: [DaySection] {
        let calendar = Calendar.current
        var sections: [DaySection] = []
        for row in viewModel.rows {
            let day = calendar.startOfDay(for: row.event.occurredAt)
            if let last = sections.last, last.day == day {
                sections[sections.count - 1] = DaySection(day: day, rows: last.rows + [row])
            } else {
                sections.append(DaySection(day: day, rows: [row]))
            }
        }
        return sections
    }

    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
    }

    @ViewBuilder
    private func activityRow(_ row: ActivityRow) -> some View {
        switch route(for: row) {
        case let .expense(expense):
            NavigationLink {
                ExpenseDetailView(expense: expense, currentUserID: currentUserID)
            } label: {
                activityRowContent(row)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("activity-row-\(row.id.uuidString)")
            .accessibilityHint("Open expense details")
        case let .settlement(settlement):
            NavigationLink {
                SettlementDetailView(settlement: settlement)
            } label: {
                activityRowContent(row)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("activity-row-\(row.id.uuidString)")
            .accessibilityHint("Open settlement details")
        case let .event(event):
            NavigationLink {
                ActivityEventDetailView(event: event)
            } label: {
                activityRowContent(row)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("activity-row-\(row.id.uuidString)")
            .accessibilityHint("Open activity details")
        }
    }

    private func activityRowContent(_ row: ActivityRow) -> some View {
        HStack(spacing: 14) {
            if let expense = row.expense {
                let category = metadata.category(for: expense)
                IconTile(systemImage: category.systemImage, color: category.color, size: 40)
            } else {
                IconTile(systemImage: row.event.kind.systemImage, color: row.event.kind.tint, size: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title(for: row)))
                    .font(BarabariTypography.body.weight(.medium))
                    .foregroundStyle(BarabariColors.textPrimary)
                    .lineLimit(1)
                Text(detail(for: row) ?? row.event.occurredAt.formatted(date: .omitted, time: .shortened))
                    .font(BarabariTypography.metadata)
                    .foregroundStyle(BarabariColors.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let amount = row.settlement?.amount ?? row.expense?.total {
                AmountText(minorUnits: amount.minorUnits, currencyCode: amount.currencyCode, style: .compact)
                    .foregroundStyle(row.settlement != nil ? BarabariColors.success : BarabariColors.textPrimary)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(BarabariColors.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .barabariHitTarget(minHeight: 64)
    }

    private func route(for row: ActivityRow) -> ActivityRoute {
        if let expense = row.expense { return .expense(expense) }
        if let settlement = row.settlement { return .settlement(settlement) }
        return .event(row.event)
    }

    private func title(for row: ActivityRow) -> String {
        if row.event.kind == .expenseCreated, let expense = row.expense {
            return expense.title
        }
        return row.event.kind.title
    }

    private func detail(for row: ActivityRow) -> String? {
        if let settlement = row.settlement {
            let from = metadata.displayName(for: settlement.fromUserID, currentUserID: currentUserID, fallback: "A member")
            let to = metadata.displayName(for: settlement.toUserID, currentUserID: currentUserID, fallback: "a member")
            return "\(from) → \(to) · \(settlement.method.title)"
        }
        if let expense = row.expense {
            let payer = metadata.displayName(for: expense.paidByUserID, currentUserID: currentUserID, fallback: "A member")
            return "\(payer == "You" ? "You paid" : "\(payer) paid") · \(metadata.category(for: expense).title)"
        }
        return nil
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
        ScrollView {
            VStack(spacing: BarabariSpacing.section) {
                ReceiptHeader(
                    systemImage: ActivityEventKind.settlementRecorded.systemImage,
                    tint: ActivityEventKind.settlementRecorded.tint,
                    title: "Settlement recorded",
                    amount: settlement.amount,
                    date: settlement.occurredAt
                )
                BarabariCard(padding: 0) {
                    HStack {
                        Text("Method")
                            .foregroundStyle(BarabariColors.textSecondary)
                        Spacer()
                        Text(settlement.method.title)
                            .font(BarabariTypography.body.weight(.medium))
                    }
                    .padding(16)
                }
                Label("Saved locally on this iPhone.", systemImage: "lock.fill")
                    .font(BarabariTypography.metadata)
                    .foregroundStyle(BarabariColors.textSecondary)
            }
            .barabariScreen()
        }
        .background(BarabariColors.background)
        .navigationTitle("Settlement")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ActivityEventDetailView: View {
    let event: ActivityEvent

    var body: some View {
        ScrollView {
            VStack(spacing: BarabariSpacing.section) {
                ReceiptHeader(
                    systemImage: event.kind.systemImage,
                    tint: event.kind.tint,
                    title: event.kind.title,
                    amount: nil,
                    date: event.occurredAt
                )
                Label("Recorded locally on this iPhone.", systemImage: "lock.fill")
                    .font(BarabariTypography.metadata)
                    .foregroundStyle(BarabariColors.textSecondary)
            }
            .barabariScreen()
        }
        .background(BarabariColors.background)
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
    }
}
