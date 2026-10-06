import Charts
import SwiftUI

/// Personal money in one place: this month's spending, wallets, budgets and history.
struct MoneyView: View {
    let environment: AppEnvironment
    let revision: Int
    let addEntry: () -> Void

    @ObservedObject private var finance: PersonalFinanceStore
    @ObservedObject private var metadata = LedgerMetadata.shared
    @Environment(\.syncEngine) private var syncEngine
    @State private var month = MonthPeriod.current
    @State private var groupShares: [ExpenseCategory: Int64] = [:]
    @State private var isAddingWallet = false
    @State private var editingWallet: Wallet?
    @State private var isEditingBudgets = false
    @State private var selectedTransaction: MoneyTransaction?

    init(environment: AppEnvironment, revision: Int, addEntry: @escaping () -> Void) {
        self.environment = environment
        self.revision = revision
        self.addEntry = addEntry
        _finance = ObservedObject(wrappedValue: environment.personalFinance)
    }

    private var monthTransactions: [MoneyTransaction] { finance.transactions(in: month) }
    private var spent: Int64 { finance.spending(in: month, groupShares: groupShares).values.reduce(0, +) }
    private var income: Int64 { finance.income(in: month) }
    private var groupShareTotal: Int64 { groupShares.values.reduce(0, +) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BarabariSpacing.section) {
                monthSwitcher
                    .staggeredAppear(0)
                MonthSummaryCard(spent: spent, income: income, groupShare: groupShareTotal, month: month)
                    .staggeredAppear(1)
                walletsSection
                    .staggeredAppear(2)
                budgetsSection
                    .staggeredAppear(3)
                historySection
                    .staggeredAppear(4)
            }
            .padding(.top, 4)
            .barabariScreen()
        }
        .scrollIndicators(.hidden)
        .background(BarabariColors.background)
        .navigationTitle("Money")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Log money", systemImage: "plus", action: addEntry)
                    .accessibilityIdentifier("money-add")
            }
        }
        .task(id: TaskKey(revision: revision, financeRevision: finance.revision, month: month)) {
            await loadGroupShares()
        }
        .refreshable {
            await syncEngine?.syncNow()
            await loadGroupShares()
        }
        .sheet(isPresented: $isAddingWallet) {
            WalletEditorSheet(finance: finance, wallet: nil)
        }
        .sheet(item: $editingWallet) { wallet in
            WalletEditorSheet(finance: finance, wallet: wallet)
        }
        .sheet(isPresented: $isEditingBudgets) {
            BudgetsSheet(finance: finance, month: month, groupShares: groupShares)
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailSheet(finance: finance, transaction: transaction)
        }
    }

    private struct TaskKey: Equatable {
        let revision: Int
        let financeRevision: Int
        let month: MonthPeriod
    }

    private func loadGroupShares() async {
        var expenses: [Expense] = []
        let groups = (try? await environment.groupRepository.listGroups()) ?? []
        for group in groups {
            var cursor: String?
            repeat {
                guard let page = try? await environment.expenseRepository.listExpenses(groupID: group.id, cursor: cursor) else { break }
                expenses += page.items
                cursor = page.nextCursor
            } while cursor != nil
        }
        let shares = GroupShareCalculator.shares(expenses: expenses, currentUserID: environment.currentUserID, month: month) {
            metadata.category(for: $0)
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { groupShares = shares }
    }

    // MARK: Month

    private var monthSwitcher: some View {
        HStack {
            Button {
                BarabariInteraction.trigger(.selection)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { month = month.previous }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 40, height: 40)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous month")

            Spacer()
            Text(month.title)
                .font(.headline)
                .contentTransition(.numericText())
                .accessibilityIdentifier("money-month")
            Spacer()

            Button {
                BarabariInteraction.trigger(.selection)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { month = month.next }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 40, height: 40)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .disabled(month.isCurrent)
            .opacity(month.isCurrent ? 0.3 : 1)
            .accessibilityLabel("Next month")
        }
        .foregroundStyle(BarabariColors.textPrimary)
    }

    // MARK: Wallets

    private var walletsSection: some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.row) {
            SectionHeader("Wallets") {
                Text(AmountFormatter.string(minorUnits: finance.totalBalance, currencyCode: "PKR"))
                    .monospacedDigit()
                    .foregroundStyle(BarabariColors.textSecondary)
                    .contentTransition(.numericText(value: Double(finance.totalBalance)))
            }
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(finance.activeWallets) { wallet in
                        Button {
                            BarabariInteraction.trigger(.selection)
                            editingWallet = wallet
                        } label: {
                            WalletCard(wallet: wallet, balanceMinor: finance.balance(of: wallet.id))
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel("\(wallet.name), \(AmountFormatter.string(minorUnits: finance.balance(of: wallet.id), currencyCode: "PKR"))")
                    }
                    Button {
                        BarabariInteraction.trigger(.selection)
                        isAddingWallet = true
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: "plus")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(BarabariColors.accent)
                                .frame(width: 44, height: 44)
                                .background(BarabariColors.accent.opacity(0.14), in: .circle)
                            Text("Add wallet")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BarabariColors.textPrimary)
                        }
                        .frame(width: 130, height: 132)
                        .background {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                                .foregroundStyle(BarabariColors.accent.opacity(0.4))
                        }
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("add-wallet")
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }

    // MARK: Budgets

    private var budgetsSection: some View {
        let progress = finance.budgetProgress(in: month, groupShares: groupShares)
        return VStack(alignment: .leading, spacing: BarabariSpacing.row) {
            SectionHeader("Budgets") {
                Button(progress.isEmpty ? "Set up" : "Edit") { isEditingBudgets = true }
                    .accessibilityIdentifier("edit-budgets")
            }
            if progress.isEmpty {
                Button {
                    isEditingBudgets = true
                } label: {
                    HStack(spacing: 14) {
                        IconTile(systemImage: "target", color: BarabariColors.accent, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Set a monthly budget")
                                .font(BarabariTypography.body.weight(.semibold))
                                .foregroundStyle(BarabariColors.textPrimary)
                            Text("Barabari warns you at 80% — group shares count too.")
                                .font(BarabariTypography.metadata)
                                .foregroundStyle(BarabariColors.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(BarabariColors.surface, in: .rect(cornerRadius: BarabariSpacing.cardRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: BarabariSpacing.cardRadius, style: .continuous)
                            .strokeBorder(BarabariColors.hairline, lineWidth: 1)
                    }
                }
                .buttonStyle(.pressable)
            } else {
                BarabariCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(progress.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { RowDivider(leading: 64) }
                            BudgetRow(progress: item)
                        }
                    }
                }
            }
        }
    }

    // MARK: History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.row) {
            SectionHeader("History")
            if monthTransactions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(BarabariColors.textTertiary)
                    Text("Nothing logged in \(month.title)")
                        .font(BarabariTypography.body.weight(.medium))
                    Text("Tap + and choose “Just me” to log your own spending or income.")
                        .font(BarabariTypography.metadata)
                        .foregroundStyle(BarabariColors.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Log something", action: addEntry)
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.glassProminent)
                        .tint(BarabariColors.accent)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(BarabariColors.surface, in: .rect(cornerRadius: BarabariSpacing.cardRadius))
            } else {
                ForEach(daySections, id: \.day) { section in
                    VStack(alignment: .leading, spacing: BarabariSpacing.compact) {
                        Text(dayTitle(section.day))
                            .font(BarabariTypography.eyebrow)
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .foregroundStyle(BarabariColors.textSecondary)
                            .padding(.horizontal, 4)
                        BarabariCard(padding: 0) {
                            VStack(spacing: 0) {
                                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, transaction in
                                    if index > 0 { RowDivider() }
                                    Button {
                                        selectedTransaction = transaction
                                    } label: {
                                        TransactionRow(transaction: transaction, walletName: finance.wallet(id: transaction.walletID)?.name ?? "Wallet")
                                    }
                                    .buttonStyle(.pressable)
                                    .contextMenu {
                                        Button("Delete", systemImage: "trash", role: .destructive) {
                                            withAnimation { try? finance.deleteTransaction(id: transaction.id) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private struct DaySection {
        let day: Date
        let items: [MoneyTransaction]
    }

    private var daySections: [DaySection] {
        let calendar = Calendar.current
        var sections: [DaySection] = []
        for transaction in monthTransactions {
            let day = calendar.startOfDay(for: transaction.occurredAt)
            if let last = sections.last, last.day == day {
                sections[sections.count - 1] = DaySection(day: day, items: last.items + [transaction])
            } else {
                sections.append(DaySection(day: day, items: [transaction]))
            }
        }
        return sections
    }

    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

// MARK: - Summary card

private struct MonthSummaryCard: View {
    let spent: Int64
    let income: Int64
    let groupShare: Int64
    let month: MonthPeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(month.isCurrent ? "Spent this month" : "Spent in \(month.start.formatted(.dateTime.month(.wide)))")
                    .font(BarabariTypography.eyebrow)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                if groupShare > 0 {
                    Label("incl. groups", systemImage: "person.2.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .glassEffect(.clear, in: .capsule)
                }
            }

            HeroAmount(minorUnits: spent, size: 46)
                .padding(.top, 16)
                .accessibilityIdentifier("money-spent")

            Spacer(minLength: 20)

            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    metric("Income", income, symbol: "arrow.down.left")
                    if income > 0 {
                        metric("Left", income - spent, symbol: "equal")
                    } else {
                        metric("Your group share", groupShare, symbol: "person.2.fill")
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
        .background {
            BarabariMeshBackground(tone: income > 0 && spent > income ? .rose : .graphite)
        }
        .clipShape(.rect(cornerRadius: 32))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
        .environment(\.colorScheme, .dark)
    }

    private func metric(_ title: LocalizedStringKey, _ minor: Int64, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(.white.opacity(0.16), in: .circle)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                Text(AmountFormatter.string(minorUnits: minor, currencyCode: "PKR"))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText(value: Double(minor)))
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .glassEffect(.clear, in: .rect(cornerRadius: 18))
    }
}

// MARK: - Rows and cards

struct WalletCard: View {
    let wallet: Wallet
    let balanceMinor: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: wallet.kind.systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(.white.opacity(0.2), in: .rect(cornerRadius: 12))
            Spacer(minLength: 12)
            Text(wallet.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
            Text(AmountFormatter.string(minorUnits: balanceMinor, currencyCode: "PKR"))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText(value: Double(balanceMinor)))
        }
        .padding(16)
        .frame(width: 160, height: 132, alignment: .leading)
        .background {
            LinearGradient(colors: [wallet.kind.color, wallet.kind.color.mix(with: .black, by: 0.35)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .clipShape(.rect(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        }
        .shadow(color: wallet.kind.color.opacity(0.3), radius: 12, y: 6)
    }
}

struct BudgetRow: View {
    let progress: BudgetProgress
    @State private var appeared = false

    private var tint: Color {
        switch progress.level {
        case .fine: progress.category.color
        case .close: BarabariColors.warning
        case .over: BarabariColors.danger
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemImage: progress.category.systemImage, color: progress.category.color, size: 38)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(LocalizedStringKey(progress.category.title))
                        .font(BarabariTypography.body.weight(.medium))
                    Spacer()
                    Text("\(AmountFormatter.string(minorUnits: progress.spentMinor, currencyCode: "PKR")) / \(AmountFormatter.string(minorUnits: progress.limitMinor, currencyCode: "PKR"))")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(progress.level == .fine ? BarabariColors.textSecondary : tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Capsule()
                    .fill(BarabariColors.raised)
                    .frame(height: 7)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(tint.gradient)
                                .frame(width: max(7, proxy.size.width * min(1, appeared ? progress.fraction : 0)))
                        }
                    }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(Int((progress.fraction * 100).rounded())) percent used")
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.15)) { appeared = true }
        }
    }
}

struct TransactionRow: View {
    let transaction: MoneyTransaction
    let walletName: String

    var body: some View {
        HStack(spacing: 14) {
            if let category = transaction.expenseCategory {
                IconTile(systemImage: category.systemImage, color: category.color, size: 40)
            } else if let category = transaction.incomeCategory {
                IconTile(systemImage: category.systemImage, color: category.color, size: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.title)
                    .font(BarabariTypography.body.weight(.medium))
                    .foregroundStyle(BarabariColors.textPrimary)
                    .lineLimit(1)
                Text(walletName)
                    .font(BarabariTypography.metadata)
                    .foregroundStyle(BarabariColors.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text((transaction.kind == .income ? "+" : "−") + AmountFormatter.string(minorUnits: transaction.amountMinor, currencyCode: "PKR"))
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(transaction.kind == .income ? BarabariColors.success : BarabariColors.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("money-row")
    }
}
