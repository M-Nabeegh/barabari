import Combine
import Foundation
import SwiftData

// Personal money lives in its own SwiftData store, separate from the shared
// ledger, so adding it never migrates or risks the groups already on a phone.

@Model
final class StoredWallet {
    @Attribute(.unique) var id: UUID
    var name: String
    var kindRaw: String
    var openingMinor: Int64
    var createdAt: Date
    var archivedAt: Date?

    init(_ wallet: Wallet) {
        id = wallet.id
        name = wallet.name
        kindRaw = wallet.kind.rawValue
        openingMinor = wallet.openingMinor
        createdAt = wallet.createdAt
        archivedAt = wallet.archivedAt
    }

    var domain: Wallet {
        Wallet(id: id, name: name, kind: WalletKind(rawValue: kindRaw) ?? .cash, openingMinor: openingMinor,
               createdAt: createdAt, archivedAt: archivedAt)
    }
}

@Model
final class StoredMoneyTransaction {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var title: String
    var note: String?
    var amountMinor: Int64
    var categoryRaw: String
    var walletID: UUID
    var occurredAt: Date
    var createdAt: Date

    init(_ transaction: MoneyTransaction) {
        id = transaction.id
        kindRaw = transaction.kind.rawValue
        title = transaction.title
        note = transaction.note
        amountMinor = transaction.amountMinor
        categoryRaw = transaction.categoryRaw
        walletID = transaction.walletID
        occurredAt = transaction.occurredAt
        createdAt = transaction.createdAt
    }

    var domain: MoneyTransaction {
        MoneyTransaction(id: id, kind: TransactionKind(rawValue: kindRaw) ?? .expense, title: title, note: note,
                         amountMinor: amountMinor, categoryRaw: categoryRaw, walletID: walletID,
                         occurredAt: occurredAt, createdAt: createdAt)
    }
}

@Model
final class StoredBudget {
    @Attribute(.unique) var categoryRaw: String
    var limitMinor: Int64
    var updatedAt: Date

    init(categoryRaw: String, limitMinor: Int64) {
        self.categoryRaw = categoryRaw
        self.limitMinor = limitMinor
        updatedAt = .now
    }
}

enum PersonalFinanceError: LocalizedError, Equatable {
    case invalidAmount
    case missingWallet
    case emptyName

    var errorDescription: String? {
        switch self {
        case .invalidAmount: "Enter an amount greater than zero."
        case .missingWallet: "Choose where the money came from."
        case .emptyName: "Give this wallet a name."
        }
    }
}

@MainActor
final class PersonalFinanceStore: ObservableObject {
    @Published private(set) var wallets: [Wallet] = []
    /// Newest first.
    @Published private(set) var transactions: [MoneyTransaction] = []
    @Published private(set) var budgets: [ExpenseCategory: Int64] = [:]
    /// Bumps on every write so dependent screens reload.
    @Published private(set) var revision = 0

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init(inMemory: Bool) throws {
        let schema = Schema([StoredWallet.self, StoredMoneyTransaction.self, StoredBudget.self])
        let configuration = ModelConfiguration("BarabariPersonal", schema: schema, isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(for: schema, configurations: [configuration])
        reload()
        if wallets.isEmpty {
            _ = try? addWallet(name: "Cash", kind: .cash, openingMinor: 0)
        }
    }

    func reload() {
        wallets = ((try? context.fetch(FetchDescriptor<StoredWallet>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []).map(\.domain)
        transactions = ((try? context.fetch(FetchDescriptor<StoredMoneyTransaction>(
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
        ))) ?? []).map(\.domain)
        let stored = (try? context.fetch(FetchDescriptor<StoredBudget>())) ?? []
        budgets = Dictionary(stored.compactMap { budget in
            ExpenseCategory(rawValue: budget.categoryRaw).map { ($0, budget.limitMinor) }
        }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: Wallets

    var activeWallets: [Wallet] { wallets.filter { !$0.isArchived } }

    func wallet(id: UUID) -> Wallet? { wallets.first { $0.id == id } }

    func balance(of walletID: UUID) -> Int64 {
        let opening = wallet(id: walletID)?.openingMinor ?? 0
        return transactions.filter { $0.walletID == walletID }.reduce(opening) { $0 + $1.signedMinor }
    }

    var totalBalance: Int64 {
        activeWallets.reduce(0) { $0 + balance(of: $1.id) }
    }

    @discardableResult
    func addWallet(name: String, kind: WalletKind, openingMinor: Int64) throws -> Wallet {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PersonalFinanceError.emptyName }
        let wallet = Wallet(id: UUID(), name: trimmed, kind: kind, openingMinor: openingMinor, createdAt: .now, archivedAt: nil)
        context.insert(StoredWallet(wallet))
        try save()
        return wallet
    }

    func updateWallet(_ wallet: Wallet) throws {
        guard let stored = try storedWallet(wallet.id) else { throw PersonalFinanceError.missingWallet }
        let trimmed = wallet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PersonalFinanceError.emptyName }
        stored.name = trimmed
        stored.kindRaw = wallet.kind.rawValue
        stored.openingMinor = wallet.openingMinor
        try save()
    }

    /// Hides a wallet. Its past transactions stay in history; the last wallet can't be removed.
    func archiveWallet(id: UUID) throws {
        guard activeWallets.count > 1, let stored = try storedWallet(id) else { return }
        stored.archivedAt = .now
        try save()
    }

    // MARK: Transactions

    @discardableResult
    func addTransaction(
        kind: TransactionKind,
        title: String,
        amountMinor: Int64,
        categoryRaw: String,
        walletID: UUID,
        occurredAt: Date = .now,
        note: String? = nil
    ) throws -> MoneyTransaction {
        guard amountMinor > 0 else { throw PersonalFinanceError.invalidAmount }
        guard wallet(id: walletID) != nil else { throw PersonalFinanceError.missingWallet }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let transaction = MoneyTransaction(
            id: UUID(),
            kind: kind,
            title: trimmed.isEmpty ? defaultTitle(kind: kind, categoryRaw: categoryRaw) : trimmed,
            note: note,
            amountMinor: amountMinor,
            categoryRaw: categoryRaw,
            walletID: walletID,
            occurredAt: occurredAt,
            createdAt: .now
        )
        context.insert(StoredMoneyTransaction(transaction))
        try save()
        return transaction
    }

    func deleteTransaction(id: UUID) throws {
        let stored = try context.fetch(FetchDescriptor<StoredMoneyTransaction>(predicate: #Predicate { $0.id == id }))
        stored.forEach(context.delete)
        try save()
    }

    func transactions(in month: MonthPeriod) -> [MoneyTransaction] {
        transactions.filter { month.contains($0.occurredAt) }
    }

    // MARK: Budgets

    func setBudget(_ limitMinor: Int64?, for category: ExpenseCategory) throws {
        let raw = category.rawValue
        let existing = try context.fetch(FetchDescriptor<StoredBudget>(predicate: #Predicate { $0.categoryRaw == raw })).first
        if let limitMinor, limitMinor > 0 {
            if let existing {
                existing.limitMinor = limitMinor
                existing.updatedAt = .now
            } else {
                context.insert(StoredBudget(categoryRaw: raw, limitMinor: limitMinor))
            }
        } else if let existing {
            context.delete(existing)
        }
        try save()
    }

    // MARK: Summaries

    /// Personal spending plus your share of group expenses, by category, for a month.
    func spending(in month: MonthPeriod, groupShares: [ExpenseCategory: Int64] = [:]) -> [ExpenseCategory: Int64] {
        var totals = groupShares
        for transaction in transactions(in: month) {
            guard let category = transaction.expenseCategory else { continue }
            totals[category, default: 0] += transaction.amountMinor
        }
        return totals.filter { $0.value > 0 }
    }

    func income(in month: MonthPeriod) -> Int64 {
        transactions(in: month).filter { $0.kind == .income }.reduce(0) { $0 + $1.amountMinor }
    }

    func budgetProgress(in month: MonthPeriod, groupShares: [ExpenseCategory: Int64] = [:]) -> [BudgetProgress] {
        let spent = spending(in: month, groupShares: groupShares)
        return budgets
            .map { BudgetProgress(category: $0.key, spentMinor: spent[$0.key] ?? 0, limitMinor: $0.value) }
            .sorted { $0.fraction == $1.fraction ? $0.category.rawValue < $1.category.rawValue : $0.fraction > $1.fraction }
    }

    // MARK: Private

    private func storedWallet(_ id: UUID) throws -> StoredWallet? {
        try context.fetch(FetchDescriptor<StoredWallet>(predicate: #Predicate { $0.id == id })).first
    }

    private func defaultTitle(kind: TransactionKind, categoryRaw: String) -> String {
        switch kind {
        case .expense: (ExpenseCategory(rawValue: categoryRaw) ?? .other).title
        case .income: (IncomeCategory(rawValue: categoryRaw) ?? .other).title
        }
    }

    private func save() throws {
        try context.save()
        reload()
        revision &+= 1
    }
}

/// Your own share of group expenses in a month, by category.
enum GroupShareCalculator {
    static func shares(
        expenses: [Expense],
        currentUserID: UUID,
        month: MonthPeriod,
        category: (Expense) -> ExpenseCategory
    ) -> [ExpenseCategory: Int64] {
        var totals: [ExpenseCategory: Int64] = [:]
        for expense in expenses where expense.deletedAt == nil && month.contains(expense.occurredAt) {
            guard let share = expense.splits.first(where: { $0.userID == currentUserID }) else { continue }
            totals[category(expense), default: 0] += share.amount.minorUnits
        }
        return totals
    }
}
