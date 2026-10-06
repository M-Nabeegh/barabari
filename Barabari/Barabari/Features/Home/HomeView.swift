import Charts
import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    @ObservedObject var groupsViewModel: GroupsViewModel
    let revision: Int
    let showGroups: () -> Void
    let addExpense: () -> Void
    let createGroup: () -> Void
    let joinGroup: () -> Void
    var openSettings: () -> Void = {}
    let selectGroup: (Group) -> Void
    @ObservedObject private var metadata = LedgerMetadata.shared
    @Environment(\.syncEngine) private var syncEngine
    @State private var waved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BarabariSpacing.section) {
                switch viewModel.homeState {
                case .loading:
                    BarabariLoadingState(title: "Getting your balance ready")
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
            .padding(.top, 4)
            .barabariScreen()
        }
        .scrollIndicators(.hidden)
        .background(BarabariColors.background)
        .navigationTitle("Barabari")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: joinGroup) {
                    Image(systemName: "qrcode.viewfinder")
                }
                .accessibilityLabel("Join group")
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: openSettings) {
                    if metadata.ownerName.isEmpty {
                        Image(systemName: "person.crop.circle")
                    } else {
                        MemberAvatar(name: metadata.ownerName, seed: AppEnvironment.demoUserID, size: 30)
                    }
                }
                .accessibilityLabel("Settings")
            }
        }
        .task(id: revision) {
            await viewModel.refresh()
            await groupsViewModel.refresh()
        }
        .refreshable {
            await syncEngine?.syncNow()
            await viewModel.refresh()
            await groupsViewModel.refresh()
        }
    }

    private var emptyView: some View {
        BarabariEmptyState(
            systemImage: "equal.circle.fill",
            title: "Split fairly.",
            message: "Create a group for your flat, trip, or weekend plans. Barabari keeps the math calm and clear."
        ) {
            PrimaryActionButton("Create a group", action: createGroup)
                .accessibilityIdentifier("home-see-groups")
            SecondaryActionButton("Join with a link or QR", systemImage: "qrcode", action: joinGroup)
        }
    }

    private func snapshotView(_ snapshot: HomeSnapshot, isOffline: Bool) -> some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.section) {
            if isOffline {
                StatusBadge("Offline. Showing saved balances.", style: .warning)
                    .accessibilityIdentifier("offline-home-status")
            }

            greeting
                .staggeredAppear(0)

            BalanceHeroCard(snapshot: snapshot)
                .staggeredAppear(0)

            quickActions
                .staggeredAppear(1)

            if !groupsViewModel.groups.isEmpty {
                groupsCarousel
                    .staggeredAppear(2)
            }

            if !snapshot.spending.isEmpty {
                SpendingCard(spending: snapshot.spending)
                    .staggeredAppear(3)
            }

            recentActivity(snapshot.recentActivity, expenses: snapshot.expenses)
                .staggeredAppear(4)
        }
    }

    private var greeting: some View {
        let hour = Calendar.current.component(.hour, from: .now)
        let salutation = switch hour {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
        return HStack(spacing: 10) {
            Text("\(Text(LocalizedStringKey(salutation)))\(metadata.ownerFirstName.map { ", \($0)" } ?? "")")
                .font(.headline)
                .foregroundStyle(BarabariColors.textSecondary)
            Text("👋")
                .font(.headline)
                .rotationEffect(.degrees(waved ? 14 : -8), anchor: .bottomTrailing)
                .animation(.spring(response: 0.3, dampingFraction: 0.3).repeatCount(3, autoreverses: true), value: waved)
                .onAppear { waved = true }
        }
        .padding(.horizontal, 4)
    }

    private var quickActions: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 0) {
                QuickActionButton(title: "Add expense", systemImage: "plus", prominent: true, action: addExpense)
                QuickActionButton(title: "Settle up", systemImage: "arrow.left.arrow.right", action: showGroups)
                QuickActionButton(title: "New group", systemImage: "person.2.badge.plus", action: createGroup)
                QuickActionButton(title: "Scan", systemImage: "qrcode.viewfinder", action: joinGroup)
            }
        }
    }

    private var groupsCarousel: some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.row) {
            SectionHeader("Your groups") {
                Button("See all", action: showGroups)
                    .accessibilityIdentifier("home-see-groups")
            }

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(groupsViewModel.groups) { group in
                        Button {
                            BarabariInteraction.trigger(.selection)
                            selectGroup(group)
                        } label: {
                            VStack(alignment: .leading, spacing: 14) {
                                GroupAvatar(name: group.name, seed: group.id, size: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(group.name)
                                        .font(BarabariTypography.headline)
                                        .foregroundStyle(BarabariColors.textPrimary)
                                        .lineLimit(1)
                                    Text(group.description?.isEmpty == false ? group.description! : "Shared ledger")
                                        .font(BarabariTypography.metadata)
                                        .foregroundStyle(BarabariColors.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(16)
                            .frame(width: 168, alignment: .leading)
                            .background(BarabariColors.surface, in: .rect(cornerRadius: 24))
                            .overlay {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .strokeBorder(BarabariColors.hairline, lineWidth: 1)
                            }
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel(group.name)
                        .accessibilityHint("Open group")
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }

    @ViewBuilder
    private func recentActivity(_ activity: [ActivityEvent], expenses: [UUID: Expense]) -> some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.row) {
            SectionHeader("Recent activity")

            BarabariCard(padding: 0) {
                if activity.isEmpty {
                    Text("Your expenses and settlements will appear here.")
                        .font(BarabariTypography.body)
                        .foregroundStyle(BarabariColors.textSecondary)
                        .padding(BarabariSpacing.card)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(activity.enumerated()), id: \.element.id) { index, event in
                            if index > 0 { RowDivider() }
                            let expense = event.kind == .expenseCreated ? expenses[event.subjectID] : nil
                            HStack(spacing: 14) {
                                if let expense {
                                    let category = metadata.category(for: expense)
                                    IconTile(systemImage: category.systemImage, color: category.color, size: 38)
                                } else {
                                    IconTile(systemImage: event.kind.systemImage, color: event.kind.tint, size: 38)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(expense.map { LocalizedStringKey($0.title) } ?? LocalizedStringKey(event.kind.title))
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
    }

    private func errorView(_ message: String) -> some View {
        BarabariEmptyState(
            systemImage: "exclamationmark.triangle.fill",
            title: "We could not load your balance",
            message: message
        ) {
            PrimaryActionButton("Try again") {
                Task { await viewModel.refresh() }
            }
        }
    }
}

// MARK: - Spending

private struct SpendingCard: View {
    let spending: [CategorySpend]

    @State private var selectedAngle: Int64?
    @State private var revealed = false

    private var total: Int64 { spending.reduce(0) { $0 + $1.minorUnits } }

    private var selected: CategorySpend? {
        guard let selectedAngle else { return nil }
        var running: Int64 = 0
        for item in spending {
            running += item.minorUnits
            if selectedAngle <= running { return item }
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.row) {
            SectionHeader("Where your money went")

            BarabariCard {
                HStack(spacing: 18) {
                    Chart(spending) { item in
                        SectorMark(
                            angle: .value("Share", revealed ? item.minorUnits : 0),
                            innerRadius: .ratio(0.64),
                            angularInset: 2.5
                        )
                        .cornerRadius(5)
                        .foregroundStyle(item.category.color.gradient)
                        .opacity(selected == nil || selected == item ? 1 : 0.35)
                    }
                    .chartAngleSelection(value: $selectedAngle)
                    .chartBackground { _ in
                        VStack(spacing: 2) {
                            Image(systemName: (selected?.category ?? spending[0].category).systemImage)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle((selected?.category ?? spending[0].category).color)
                                .contentTransition(.symbolEffect(.replace))
                            Text(AmountFormatter.string(minorUnits: selected?.minorUnits ?? total, currencyCode: "PKR"))
                                .font(.caption.weight(.bold))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .frame(width: 70)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selected)
                    }
                    .frame(width: 138, height: 138)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(spending.prefix(4)) { item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(item.category.color.gradient)
                                    .frame(width: 10, height: 10)
                                Text(LocalizedStringKey(item.category.title))
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text(percent(item))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BarabariColors.textSecondary)
                                    .monospacedDigit()
                            }
                            .opacity(selected == nil || selected == item ? 1 : 0.4)
                        }
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Spending by category")
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.2)) { revealed = true }
        }
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func percent(_ item: CategorySpend) -> String {
        guard total > 0 else { return "0%" }
        return "\(Int((Double(item.minorUnits) / Double(total) * 100).rounded()))%"
    }
}

// MARK: - Balance card

private struct BalanceHeroCard: View {
    let snapshot: HomeSnapshot
    @Environment(\.syncEngine) private var syncEngine

    private var net: Int64 { snapshot.amountOwed.minorUnits - snapshot.amountOwing.minorUnits }

    private var summary: String {
        switch (snapshot.amountOwed.minorUnits, snapshot.amountOwing.minorUnits) {
        case (0, 0): "You are all settled up."
        case let (owed, owing) where owed >= owing: "You are owed more than you owe."
        default: "You owe more than you are owed."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Net balance")
                    .font(BarabariTypography.eyebrow)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                if let syncEngine {
                    SyncStatusPill(engine: syncEngine)
                } else {
                    Label("On this iPhone", systemImage: "lock.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .glassEffect(.clear, in: .capsule)
                }
            }

            HeroAmount(minorUnits: net, size: 48)
                .padding(.top, 18)

            Text(LocalizedStringKey(summary))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.75))
                .padding(.top, 4)

            Spacer(minLength: 22)

            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    metric("You are owed", amount: snapshot.amountOwed, symbol: "arrow.down.left")
                    metric("You owe", amount: snapshot.amountOwing, symbol: "arrow.up.right")
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 236, alignment: .topLeading)
        .background {
            BarabariMeshBackground(tone: net < 0 ? .graphite : .emerald)
                .overlay {
                    LinearGradient(colors: [.white.opacity(0.14), .clear], startPoint: .top, endPoint: .center)
                }
        }
        .clipShape(.rect(cornerRadius: 32))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: BarabariColors.brandEmerald.opacity(0.28), radius: 24, y: 12)
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .combine)
    }

    private func metric(_ title: String, amount: Money, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(.white.opacity(0.16), in: .circle)
            VStack(alignment: .leading, spacing: 1) {
                Text(LocalizedStringKey(title))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                AmountText(minorUnits: amount.minorUnits, currencyCode: amount.currencyCode, style: .compact)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .glassEffect(.clear, in: .rect(cornerRadius: 18))
    }
}
