import SwiftUI

struct GroupDetailView: View {
    private let environment: AppEnvironment
    @StateObject private var viewModel: GroupDetailViewModel
    @State private var selectedTransfer: BalanceTransfer?
    @State private var selectedGroupID: UUID?
    @State private var isPresentingSettlement = false

    init(environment: AppEnvironment, groupID: UUID) {
        self.environment = environment
        _viewModel = StateObject(wrappedValue: GroupDetailViewModel(environment: environment, groupID: groupID))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BarabariSpacing.section) {
                switch viewModel.state {
                case .loading:
                    ProgressView("Loading group")
                        .frame(maxWidth: .infinity, minHeight: 240)
                case let .loaded(snapshot):
                    detail(snapshot, isOffline: false)
                case let .offline(snapshot):
                    detail(snapshot, isOffline: true)
                case let .failed(message):
                    error(message)
                }
            }
            .padding(BarabariSpacing.screen)
        }
        .navigationTitle(groupTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.refresh() }
        .onChange(of: isPresentingSettlement) { _, isPresenting in
            guard !isPresenting else { return }
            Task { await viewModel.refresh() }
        }
        .navigationDestination(isPresented: $isPresentingSettlement) {
            if let transfer = selectedTransfer, let selectedGroupID {
                SettlementView(
                    environment: environment,
                    groupID: selectedGroupID,
                    fromUserID: transfer.fromUserID,
                    toUserID: transfer.toUserID,
                    remainingAmount: transfer.amount,
                    recipient: memberName(for: transfer.toUserID)
                )
            }
        }
    }

    private var groupTitle: String {
        switch viewModel.state {
        case let .loaded(snapshot), let .offline(snapshot): snapshot.group.name
        case .loading, .failed: "Group"
        }
    }

    private func detail(_ snapshot: GroupDetailSnapshot, isOffline: Bool) -> some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.section) {
            if isOffline {
                StatusBadge("Offline. Showing your saved group ledger.", style: .warning)
            }

            BarabariCard {
                VStack(alignment: .leading, spacing: BarabariSpacing.row) {
                    Text(snapshot.group.name)
                        .font(BarabariTypography.screenTitle)
                    if let description = snapshot.group.description, !description.isEmpty {
                        Text(description)
                            .font(BarabariTypography.body)
                            .foregroundStyle(BarabariColors.textSecondary)
                    }
                    Text(balanceHeadline(for: snapshot.balance))
                        .font(BarabariTypography.body)
                        .foregroundStyle(BarabariColors.textSecondary)
                }
            }

            BalanceSummaryView(summary: snapshot.balance, currentUserID: snapshot.currentUserID) { transfer in
                selectedTransfer = transfer
                selectedGroupID = snapshot.group.id
                isPresentingSettlement = true
            }

            VStack(alignment: .leading, spacing: BarabariSpacing.row) {
                Text("People")
                    .font(BarabariTypography.sectionTitle)
                ForEach(snapshot.members) { member in
                    HStack(spacing: BarabariSpacing.row) {
                        Image(systemName: member.role == .owner ? "crown.fill" : "person.fill")
                            .foregroundStyle(member.role == .owner ? BarabariColors.warning : BarabariColors.accent)
                            .frame(width: 22)
                        Text(member.userID == snapshot.currentUserID ? "You" : "Group member")
                            .font(BarabariTypography.body)
                        Spacer()
                        Text(member.role == .owner ? "Owner" : "Member")
                            .font(BarabariTypography.metadata)
                            .foregroundStyle(BarabariColors.textSecondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: BarabariSpacing.row) {
                Text("Latest")
                    .font(BarabariTypography.sectionTitle)
                if snapshot.activity.isEmpty {
                    Text("Add an expense to start this group’s timeline.")
                        .foregroundStyle(BarabariColors.textSecondary)
                } else {
                    ForEach(snapshot.activity.prefix(3)) { event in
                        Text(eventTitle(event.kind))
                            .font(BarabariTypography.body)
                    }
                }
            }
        }
    }

    private func error(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.row) {
            Text("We could not open this group")
                .font(BarabariTypography.sectionTitle)
            Text(message)
                .foregroundStyle(BarabariColors.textSecondary)
            PrimaryActionButton("Try again") {
                Task { await viewModel.refresh() }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 240, alignment: .center)
    }

    private func balanceHeadline(for balance: BalanceSummary) -> String {
        if balance.transfers.isEmpty { return "Everyone is settled up." }
        return "\(balance.transfers.count) settlement\(balance.transfers.count == 1 ? "" : "s") to review."
    }

    private func memberName(for userID: UUID) -> String {
        switch viewModel.state {
        case let .loaded(snapshot), let .offline(snapshot):
            if userID == snapshot.currentUserID { return "You" }
            let index = snapshot.members.firstIndex { $0.userID == userID } ?? 0
            return "Member \(index + 1)"
        case .loading, .failed:
            return "Group member"
        }
    }

    private func eventTitle(_ kind: ActivityEventKind) -> String {
        switch kind {
        case .groupCreated: "Group created"
        case .expenseCreated: "Expense added"
        case .expenseDeleted: "Expense removed"
        case .settlementRecorded: "Settlement recorded"
        case .memberJoined: "Member joined"
        case .memberRemoved: "Member removed"
        }
    }
}
