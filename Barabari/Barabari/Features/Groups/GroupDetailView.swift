import SwiftUI

struct GroupDetailView: View {
    private let environment: AppEnvironment
    private let revision: Int
    private let onChanged: () -> Void
    private let onInvite: () -> Void
    private let onAddExpense: () -> Void
    @StateObject private var viewModel: GroupDetailViewModel
    @Environment(\.syncEngine) private var syncEngine
    @State private var selectedTransfer: BalanceTransfer?
    @State private var selectedGroupID: UUID?
    @State private var isPresentingSettlement = false
    @State private var isAddingPerson = false
    @State private var renamingMember: GroupMember?
    @State private var shareTransfer: BalanceTransfer?
    @ObservedObject private var metadata = LedgerMetadata.shared
    @State private var toast: String?

    init(
        environment: AppEnvironment,
        groupID: UUID,
        revision: Int,
        onChanged: @escaping () -> Void,
        onInvite: @escaping () -> Void = {},
        onAddExpense: @escaping () -> Void = {}
    ) {
        self.environment = environment
        self.revision = revision
        self.onChanged = onChanged
        self.onInvite = onInvite
        self.onAddExpense = onAddExpense
        _viewModel = StateObject(wrappedValue: GroupDetailViewModel(environment: environment, groupID: groupID))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BarabariSpacing.section) {
                switch viewModel.state {
                case .loading:
                    BarabariLoadingState(title: "Loading group")
                case let .loaded(snapshot):
                    detail(snapshot, isOffline: false)
                case let .offline(snapshot):
                    detail(snapshot, isOffline: true)
                case let .failed(message):
                    error(message)
                }
            }
            .barabariScreen()
        }
        .scrollIndicators(.hidden)
        .background(BarabariColors.background)
        .navigationTitle(groupTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onInvite()
                } label: {
                    Image(systemName: "person.badge.plus")
                }
                .accessibilityLabel("Invite")
                .accessibilityIdentifier("invite-group")
            }
        }
        .overlay(alignment: .top) {
            if let toast {
                Text(toast)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
                    .accessibilityIdentifier("group-toast")
            }
        }
        .task(id: revision) { await viewModel.refresh() }
        .refreshable {
            await syncEngine?.syncNow()
            await viewModel.refresh()
        }
        .onChange(of: isPresentingSettlement) { _, isPresenting in
            guard !isPresenting else { return }
            Task { await viewModel.refresh() }
        }
        .sheet(isPresented: $isAddingPerson) {
            PersonNameSheet(title: "Add person", initialName: "", actionTitle: "Add") { name in
                let added = await viewModel.addPerson(named: name, metadata: metadata)
                if added {
                    BarabariInteraction.trigger(.success)
                    onChanged()
                }
                return added
            }
        }
        .sheet(item: $renamingMember) { member in
            PersonNameSheet(
                title: "Rename",
                initialName: metadata.names[member.userID] ?? "",
                actionTitle: "Save"
            ) { name in
                metadata.setName(name, for: member.userID)
                onChanged()
                return true
            }
        }
        .sheet(item: $shareTransfer) { transfer in
            ShareBalanceSheet(
                transfer: transfer,
                groupName: groupTitle,
                fromName: memberName(for: transfer.fromUserID),
                toName: memberName(for: transfer.toUserID)
            )
        }
        .navigationDestination(isPresented: $isPresentingSettlement) {
            if let transfer = selectedTransfer, let selectedGroupID {
                SettlementView(
                    environment: environment,
                    groupID: selectedGroupID,
                    fromUserID: transfer.fromUserID,
                    toUserID: transfer.toUserID,
                    remainingAmount: transfer.amount,
                    recipient: memberName(for: transfer.toUserID),
                    onSaved: onChanged
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

            header(snapshot)
                .staggeredAppear(0)

            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 0) {
                    QuickActionButton(title: "Add expense", systemImage: "plus", prominent: true, action: onAddExpense)
                    QuickActionButton(title: "Invite", systemImage: "person.badge.plus", action: onInvite)
                    QuickActionButton(title: "Settle up", systemImage: "arrow.left.arrow.right") {
                        guard let transfer = snapshot.balance.transfers.first(where: { $0.fromUserID == snapshot.currentUserID }) else {
                            BarabariInteraction.trigger(.success)
                            showToast("You’re all settled 🎉")
                            return
                        }
                        selectedTransfer = transfer
                        selectedGroupID = snapshot.group.id
                        isPresentingSettlement = true
                    }
                }
            }
            .staggeredAppear(1)

            VStack(alignment: .leading, spacing: BarabariSpacing.row) {
                SectionHeader("Balance")
                BalanceSummaryView(
                    summary: snapshot.balance,
                    currentUserID: snapshot.currentUserID,
                    name: { memberName(for: $0) },
                    shareTransfer: { shareTransfer = $0 }
                ) { transfer in
                    selectedTransfer = transfer
                    selectedGroupID = snapshot.group.id
                    isPresentingSettlement = true
                }
            }
            .staggeredAppear(2)

            VStack(alignment: .leading, spacing: BarabariSpacing.row) {
                SectionHeader("People") {
                    Button {
                        BarabariInteraction.trigger(.selection)
                        isAddingPerson = true
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                    }
                    .accessibilityLabel("Add person")
                    .accessibilityIdentifier("add-person")
                }
                BarabariCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(snapshot.members.enumerated()), id: \.element.id) { index, member in
                            if index > 0 { RowDivider(leading: 70) }
                            HStack(spacing: 14) {
                                MemberAvatar(name: memberName(for: member.userID), seed: member.userID, size: 42)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(memberName(for: member.userID))
                                        .font(BarabariTypography.body.weight(.medium))
                                    if member.userID == snapshot.currentUserID, let ownerName = metadata.ownerFirstName {
                                        Text(ownerName)
                                            .font(.caption)
                                            .foregroundStyle(BarabariColors.textSecondary)
                                    }
                                }
                                Spacer()
                                if member.role == .owner {
                                    Label("Owner", systemImage: "crown.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(BarabariColors.warning)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(BarabariColors.warning.opacity(0.14), in: .capsule)
                                } else {
                                    Text("Member")
                                        .font(BarabariTypography.metadata)
                                        .foregroundStyle(BarabariColors.textSecondary)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard member.userID != snapshot.currentUserID else { return }
                                BarabariInteraction.trigger(.selection)
                                renamingMember = member
                            }
                            .contextMenu {
                                if member.userID != snapshot.currentUserID {
                                    Button("Rename", systemImage: "pencil") { renamingMember = member }
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityHint(member.userID == snapshot.currentUserID ? "" : "Rename")
                        }
                    }
                }
            }
            .staggeredAppear(3)

            VStack(alignment: .leading, spacing: BarabariSpacing.row) {
                SectionHeader("Latest")
                BarabariCard(padding: 0) {
                    if snapshot.activity.isEmpty {
                        Text("Add an expense to start this group’s timeline.")
                            .font(BarabariTypography.body)
                            .foregroundStyle(BarabariColors.textSecondary)
                            .padding(BarabariSpacing.card)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(snapshot.activity.prefix(4).enumerated()), id: \.element.id) { index, event in
                                if index > 0 { RowDivider() }
                                let expense = event.kind == .expenseCreated ? snapshot.expenses[event.subjectID] : nil
                                HStack(spacing: 14) {
                                    if let expense {
                                        let category = metadata.category(for: expense)
                                        IconTile(systemImage: category.systemImage, color: category.color, size: 38)
                                    } else {
                                        IconTile(systemImage: event.kind.systemImage, color: event.kind.tint, size: 38)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(LocalizedStringKey(latestTitle(for: event, expense: expense, snapshot: snapshot)))
                                            .font(BarabariTypography.body.weight(.medium))
                                            .lineLimit(1)
                                        Text(event.occurredAt, format: .relative(presentation: .named))
                                            .font(BarabariTypography.metadata)
                                            .foregroundStyle(BarabariColors.textSecondary)
                                    }
                                    Spacer(minLength: 0)
                                    if let expense {
                                        AmountText(minorUnits: expense.total.minorUnits, currencyCode: expense.total.currencyCode, style: .compact)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }
            }
            .staggeredAppear(4)
        }
    }

    private func header(_ snapshot: GroupDetailSnapshot) -> some View {
        VStack(spacing: 14) {
            GroupAvatar(name: snapshot.group.name, seed: snapshot.group.id, size: 88)
                .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
            VStack(spacing: 4) {
                Text(snapshot.group.name)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                if let description = snapshot.group.description, !description.isEmpty {
                    Text(description)
                        .font(BarabariTypography.body)
                        .foregroundStyle(BarabariColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            HStack(spacing: 10) {
                HStack(spacing: -10) {
                    ForEach(snapshot.members.prefix(4)) { member in
                        MemberAvatar(name: memberName(for: member.userID), seed: member.userID, size: 28)
                            .overlay { Circle().strokeBorder(BarabariColors.background, lineWidth: 2) }
                    }
                }
                Text(balanceHeadline(for: snapshot.balance))
                    .font(BarabariTypography.metadata.weight(.medium))
                    .foregroundStyle(BarabariColors.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .capsule)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func error(_ message: String) -> some View {
        BarabariEmptyState(
            systemImage: "exclamationmark.triangle.fill",
            title: "We could not open this group",
            message: message
        ) {
            PrimaryActionButton("Try again") {
                Task { await viewModel.refresh() }
            }
        }
    }

    private func latestTitle(for event: ActivityEvent, expense: Expense?, snapshot: GroupDetailSnapshot) -> String {
        if let expense { return expense.title }
        if event.kind == .memberJoined, event.actorUserID != snapshot.currentUserID, let name = metadata.names[event.actorUserID] {
            return "\(name) joined"
        }
        return event.kind.title
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut(duration: 0.3)) { toast = nil }
        }
    }

    private func balanceHeadline(for balance: BalanceSummary) -> String {
        if balance.transfers.isEmpty { return "Everyone is settled up." }
        return "\(balance.transfers.count) settlement\(balance.transfers.count == 1 ? "" : "s") to review."
    }

    private func memberName(for userID: UUID) -> String {
        switch viewModel.state {
        case let .loaded(snapshot), let .offline(snapshot):
            return metadata.displayName(for: userID, in: snapshot.members, currentUserID: snapshot.currentUserID)
        case .loading, .failed:
            return "Group member"
        }
    }
}
