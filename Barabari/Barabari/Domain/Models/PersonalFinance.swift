import Foundation

/// Where personal money lives: a cash pouch, a bank account, a mobile wallet.
enum WalletKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case cash
    case bank
    case jazzcash
    case easypaisa
    case card
    case savings

    var id: Self { self }

    var title: String {
        switch self {
        case .cash: "Cash"
        case .bank: "Bank"
        case .jazzcash: "JazzCash"
        case .easypaisa: "Easypaisa"
        case .card: "Card"
        case .savings: "Savings"
        }
    }

    var systemImage: String {
        switch self {
        case .cash: "banknote.fill"
        case .bank: "building.columns.fill"
        case .jazzcash: "iphone.gen3"
        case .easypaisa: "iphone.gen3.radiowaves.left.and.right"
        case .card: "creditcard.fill"
        case .savings: "lock.shield.fill"
        }
    }

    var hex: UInt32 {
        switch self {
        case .cash: 0x10B981
        case .bank: 0x3B82F6
        case .jazzcash: 0xEF4444
        case .easypaisa: 0x22C55E
        case .card: 0x8B5CF6
        case .savings: 0xF59E0B
        }
    }
}

struct Wallet: Equatable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var kind: WalletKind
    var openingMinor: Int64
    let createdAt: Date
    var archivedAt: Date?

    var isArchived: Bool { archivedAt != nil }
}

enum TransactionKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case expense
    case income

    var id: Self { self }

    var title: String {
        switch self {
        case .expense: "Expense"
        case .income: "Income"
        }
    }
}

enum IncomeCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case salary
    case business
    case freelance
    case gift
    case refund
    case other

    var id: Self { self }

    var title: String {
        switch self {
        case .salary: "Salary"
        case .business: "Business"
        case .freelance: "Freelance"
        case .gift: "Gift"
        case .refund: "Refund"
        case .other: "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .salary: "briefcase.fill"
        case .business: "storefront.fill"
        case .freelance: "laptopcomputer"
        case .gift: "gift.fill"
        case .refund: "arrow.uturn.backward.circle.fill"
        case .other: "plus.circle.fill"
        }
    }

    var hex: UInt32 {
        switch self {
        case .salary: 0x10B981
        case .business: 0x0EA5E9
        case .freelance: 0x6366F1
        case .gift: 0xEC4899
        case .refund: 0x14B8A6
        case .other: 0x64748B
        }
    }

    static func detect(from title: String) -> IncomeCategory? {
        let lowered = title.lowercased()
        if ["salary", "tankhwa", "pay"].contains(where: lowered.contains) { return .salary }
        if ["freelance", "fiverr", "upwork", "client"].contains(where: lowered.contains) { return .freelance }
        if ["gift", "eidi", "salami"].contains(where: lowered.contains) { return .gift }
        if ["refund", "cashback", "return"].contains(where: lowered.contains) { return .refund }
        if ["sale", "business", "shop", "profit"].contains(where: lowered.contains) { return .business }
        return nil
    }
}

/// A personal expense or income that belongs only to this person.
struct MoneyTransaction: Equatable, Identifiable, Sendable {
    let id: UUID
    var kind: TransactionKind
    var title: String
    var note: String?
    var amountMinor: Int64
    /// `ExpenseCategory` raw value for expenses, `IncomeCategory` raw value for income.
    var categoryRaw: String
    var walletID: UUID
    var occurredAt: Date
    let createdAt: Date

    var expenseCategory: ExpenseCategory? {
        kind == .expense ? ExpenseCategory(rawValue: categoryRaw) ?? .other : nil
    }

    var incomeCategory: IncomeCategory? {
        kind == .income ? IncomeCategory(rawValue: categoryRaw) ?? .other : nil
    }

    /// Positive for income, negative for spending.
    var signedMinor: Int64 { kind == .income ? amountMinor : -amountMinor }
}

/// A calendar month, the unit budgets and summaries work in.
struct MonthPeriod: Equatable, Hashable, Sendable {
    let start: Date

    init(containing date: Date = .now, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month], from: date)
        start = calendar.date(from: components) ?? date
    }

    static var current: MonthPeriod { MonthPeriod() }

    var end: Date { Calendar.current.date(byAdding: .month, value: 1, to: start) ?? start }
    var previous: MonthPeriod { MonthPeriod(containing: Calendar.current.date(byAdding: .month, value: -1, to: start) ?? start) }
    var next: MonthPeriod { MonthPeriod(containing: end) }
    var isCurrent: Bool { self == .current }

    func contains(_ date: Date) -> Bool { date >= start && date < end }

    var title: String { start.formatted(.dateTime.month(.wide).year()) }
}

/// Spending in one category against its monthly limit.
struct BudgetProgress: Equatable, Identifiable, Sendable {
    let category: ExpenseCategory
    let spentMinor: Int64
    let limitMinor: Int64

    var id: ExpenseCategory { category }
    var fraction: Double { limitMinor > 0 ? Double(spentMinor) / Double(limitMinor) : 0 }
    var remainingMinor: Int64 { limitMinor - spentMinor }

    enum Level: Equatable { case fine, close, over }

    var level: Level {
        if fraction >= 1 { return .over }
        if fraction >= 0.8 { return .close }
        return .fine
    }
}
