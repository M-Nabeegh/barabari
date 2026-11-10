import Combine
import Foundation

enum ExpenseSplitSelection: String, CaseIterable, Identifiable {
    case equal
    case exact
    case percentage
    case shares

    var id: Self { self }

    var title: String {
        switch self {
        case .equal: "Equal split"
        case .exact: "Exact amount"
        case .percentage: "Percentages"
        case .shares: "Shares"
        }
    }

    /// Fits four across on the smallest iPhone.
    var shortTitle: String {
        switch self {
        case .equal: "Equal"
        case .exact: "Exact"
        case .percentage: "Percent"
        case .shares: "Shares"
        }
    }
}

@MainActor
final class AddExpenseViewModel: ObservableObject {
    @Published var amountText = "" {
        didSet { refreshPreview() }
    }
    @Published var title = "" {
        didSet {
            clearValidationIfNeeded()
            if !hasChosenCategory { detectedCategory = ExpenseCategory.detect(from: title) }
            if !hasChosenIncomeCategory { incomeCategory = IncomeCategory.detect(from: title) ?? .other }
        }
    }
    /// Auto-detected from the title until the person picks one themselves.
    @Published private(set) var detectedCategory: ExpenseCategory?
    @Published private(set) var hasChosenCategory = false
    @Published var payerID: UUID? {
        didSet { clearValidationIfNeeded() }
    }
    @Published var participantIDs: [UUID] = [] {
        didSet { refreshPreview() }
    }
    @Published var splitMethod: SplitMethod = .equal
    @Published var splitSelection: ExpenseSplitSelection = .equal {
        didSet { refreshPreview() }
    }
    /// Add this expense again every week or month. Nil means it happens once.
    @Published var repeatFrequency: RecurrenceFrequency?
    @Published var validationMessage: String?
    @Published var previewSplits: [ExpenseSplit] = []
    @Published private(set) var groups: [Group] = []
    @Published private(set) var members: [GroupMember] = []
    @Published private(set) var selectedGroupID: UUID?
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var savedExpense: Expense?

    // MARK: Personal ("Just me") entries
    @Published private(set) var isPersonal = false
    @Published var personalKind: TransactionKind = .expense
    @Published var personalWalletID: UUID?
    @Published var personalDate = Date()
    @Published private(set) var incomeCategory: IncomeCategory = .other
    @Published private(set) var hasChosenIncomeCategory = false
    @Published private(set) var savedPersonal: MoneyTransaction?
    /// Set after a save that pushed a budget to 80% or past its limit.
    @Published private(set) var budgetAlert: BudgetProgress?

    private let environment: AppEnvironment
    private let metadata: LedgerMetadata
    private let memberLoader: (UUID) async throws -> [GroupMember]
    private let recurring: RecurringExpenseStore
    private var exactAmountTexts: [UUID: String] = [:]
    private var percentageTexts: [UUID: String] = [:]
    private var shareCounts: [UUID: Int] = [:]
    private var memberLoadTask: Task<Void, Never>?
    private var memberLoadGeneration = 0

    init(
        environment: AppEnvironment,
        metadata: LedgerMetadata? = nil,
        memberLoader: ((UUID) async throws -> [GroupMember])? = nil,
        recurring: RecurringExpenseStore? = nil
    ) {
        self.environment = environment
        self.metadata = metadata ?? .shared
        self.recurring = recurring ?? .shared
        self.memberLoader = memberLoader ?? { groupID in
            try await environment.groupRepository.members(groupID: groupID)
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            groups = try await environment.groupRepository.listGroups()
            if groups.isEmpty { isPersonal = true }
            let wallets = environment.personalFinance.activeWallets
            if personalWalletID == nil || !wallets.contains(where: { $0.id == personalWalletID }) {
                personalWalletID = wallets.first?.id
            }
            if selectedGroupID == nil || !groups.contains(where: { $0.id == selectedGroupID }) {
                selectedGroupID = groups.first?.id
            }
            beginMemberLoad(for: selectedGroupID)
            await memberLoadTask?.value
        } catch {
            validationMessage = "We could not load your groups. Try again."
        }
    }

    var wallets: [Wallet] { environment.personalFinance.activeWallets }

    func walletBalance(_ id: UUID) -> Int64 { environment.personalFinance.balance(of: id) }

    func personalFinanceWalletName(_ id: UUID) -> String {
        environment.personalFinance.wallet(id: id)?.name ?? "your wallet"
    }

    func choosePersonal() {
        isPersonal = true
        validationMessage = nil
    }

    func chooseIncomeCategory(_ category: IncomeCategory) {
        hasChosenIncomeCategory = true
        incomeCategory = category
    }

    func selectGroup(_ id: UUID) {
        isPersonal = false
        guard selectedGroupID != id else { return }
        selectedGroupID = id
        beginMemberLoad(for: id)
    }

    func selectSplit(_ selection: ExpenseSplitSelection) {
        splitSelection = selection
        splitMethod = splitMethodForCurrentInputs()
    }

    func toggleParticipant(_ id: UUID) {
        if participantIDs.contains(id) {
            guard participantIDs.count > 1 else { return }
            participantIDs.removeAll { $0 == id }
        } else {
            participantIDs.append(id)
        }
        splitMethod = splitMethodForCurrentInputs()
    }

    func exactAmountText(for id: UUID) -> String {
        exactAmountTexts[id] ?? ""
    }

    func updateExactAmount(_ text: String, for id: UUID) {
        exactAmountTexts[id] = text
        splitMethod = splitMethodForCurrentInputs()
        refreshPreview()
    }

    func percentageText(for id: UUID) -> String {
        percentageTexts[id] ?? ""
    }

    func updatePercentage(_ text: String, for id: UUID) {
        percentageTexts[id] = text
        clearValidationIfNeeded()
        splitMethod = splitMethodForCurrentInputs()
        refreshPreview()
    }

    /// Percent still to hand out, in basis points. Negative when the split is over 100%.
    var percentageRemainingBasisPoints: Int64 {
        PercentageBasisPoints.oneHundredPercent - participantIDs.reduce(Int64.zero) {
            $0 + (Self.parseBasisPoints(percentageTexts[$1] ?? "") ?? 0)
        }
    }

    /// Gives everyone the same percentage, with any leftover hundredths going to the first people.
    func splitPercentagesEvenly() {
        guard !participantIDs.isEmpty else { return }
        let count = Int64(participantIDs.count)
        let base = PercentageBasisPoints.oneHundredPercent / count
        let extra = PercentageBasisPoints.oneHundredPercent % count
        for (index, id) in participantIDs.enumerated() {
            percentageTexts[id] = Self.percentText(basisPoints: base + (Int64(index) < extra ? 1 : 0))
        }
        clearValidationIfNeeded()
        splitMethod = splitMethodForCurrentInputs()
        refreshPreview()
    }

    static let maximumShares = 99

    func shareCount(for id: UUID) -> Int {
        shareCounts[id] ?? 1
    }

    func setShareCount(_ count: Int, for id: UUID) {
        shareCounts[id] = min(max(count, 1), Self.maximumShares)
        clearValidationIfNeeded()
        splitMethod = splitMethodForCurrentInputs()
        refreshPreview()
    }

    /// The amount this person would owe with the inputs as they are now.
    func previewAmount(for id: UUID) -> Money? {
        previewSplits.first { $0.userID == id }?.amount
    }

    /// True for messages the split editor shows next to its own fields.
    static func isSplitValidation(_ message: String) -> Bool {
        message.hasPrefix("Exact amounts") || message.hasPrefix("Percentages") || message.hasPrefix("Enter a percentage")
    }

    var category: ExpenseCategory { detectedCategory ?? .other }

    func chooseCategory(_ category: ExpenseCategory) {
        hasChosenCategory = true
        detectedCategory = category
    }

    func memberName(for id: UUID) -> String {
        metadata.displayName(for: id, in: members, currentUserID: environment.currentUserID)
    }

    func addAnotherExpense() {
        amountText = ""
        title = ""
        hasChosenCategory = false
        detectedCategory = nil
        splitSelection = .equal
        splitMethod = .equal
        exactAmountTexts = [:]
        percentageTexts = [:]
        shareCounts = [:]
        repeatFrequency = nil
        previewSplits = []
        validationMessage = nil
        savedExpense = nil
        savedPersonal = nil
        budgetAlert = nil
        hasChosenIncomeCategory = false
        incomeCategory = .other
        personalDate = Date()
    }

    /// Saves a personal expense or income to the chosen wallet.
    @discardableResult
    func savePersonal() async -> Bool {
        guard !isSaving else { return false }
        validationMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            let money = try parseMoney(amountText)
            guard let walletID = personalWalletID else { throw PersonalFinanceError.missingWallet }
            let saved = try environment.personalFinance.addTransaction(
                kind: personalKind,
                title: title,
                amountMinor: money.minorUnits,
                categoryRaw: personalKind == .expense ? category.rawValue : incomeCategory.rawValue,
                walletID: walletID,
                occurredAt: personalDate
            )
            savedPersonal = saved
            if let category = saved.expenseCategory {
                budgetAlert = await budgetWarning(for: category, in: MonthPeriod(containing: saved.occurredAt))
            }
            return true
        } catch let error as PersonalFinanceError {
            validationMessage = error.errorDescription
            return false
        } catch {
            validationMessage = message(for: error)
            return false
        }
    }

    /// A budget that is at 80% or more for the month, including your share of group expenses.
    private func budgetWarning(for category: ExpenseCategory, in month: MonthPeriod) async -> BudgetProgress? {
        let finance = environment.personalFinance
        guard finance.budgets[category] != nil else { return nil }
        var expenses: [Expense] = []
        for group in groups {
            expenses += (try? await environment.expenseRepository.listExpenses(groupID: group.id, cursor: nil).items) ?? []
        }
        let shares = GroupShareCalculator.shares(expenses: expenses, currentUserID: environment.currentUserID, month: month) {
            metadata.category(for: $0)
        }
        let progress = finance.budgetProgress(in: month, groupShares: shares).first { $0.category == category }
        guard let progress, progress.level != .fine else { return nil }
        return progress
    }

    @discardableResult
    func save() async -> Bool {
        guard !isSaving else { return false }
        validationMessage = nil
        savedExpense = nil
        isSaving = true
        defer { isSaving = false }

        do {
            let draft = try makeDraft()
            let expense = try await CreateExpense(
                repository: environment.expenseRepository,
                groupRepository: environment.groupRepository
            ).call(draft: draft, idempotencyKey: UUID())
            metadata.setCategory(category, for: expense.id)
            if let repeatFrequency {
                recurring.add(from: expense, category: category, frequency: repeatFrequency)
            }
            budgetAlert = await budgetWarning(for: category, in: MonthPeriod(containing: expense.occurredAt))
            savedExpense = expense
            previewSplits = expense.splits
            return true
        } catch {
            validationMessage = message(for: error)
            return false
        }
    }

    private func beginMemberLoad(for groupID: UUID?) {
        memberLoadTask?.cancel()
        memberLoadGeneration &+= 1
        let generation = memberLoadGeneration
        memberLoadTask = Task { [weak self] in
            guard let self else { return }
            await self.loadMembers(for: groupID, generation: generation)
        }
    }

    private func loadMembers(for groupID: UUID?, generation: Int) async {
        guard let groupID else {
            guard generation == memberLoadGeneration else { return }
            members = []
            participantIDs = []
            payerID = nil
            return
        }

        do {
            let loadedMembers = try await memberLoader(groupID).filter(\.isActive)
            guard !Task.isCancelled, generation == memberLoadGeneration, selectedGroupID == groupID else { return }
            members = loadedMembers
            let memberIDs = members.map(\.userID)
            participantIDs = participantIDs.filter(memberIDs.contains)
            if participantIDs.isEmpty { participantIDs = memberIDs }
            if payerID == nil || !memberIDs.contains(payerID ?? UUID()) {
                payerID = memberIDs.contains(environment.currentUserID) ? environment.currentUserID : memberIDs.first
            }
            exactAmountTexts = exactAmountTexts.filter { memberIDs.contains($0.key) }
            percentageTexts = percentageTexts.filter { memberIDs.contains($0.key) }
            shareCounts = shareCounts.filter { memberIDs.contains($0.key) }
            splitMethod = splitMethodForCurrentInputs()
            refreshPreview()
        } catch {
            guard !Task.isCancelled, generation == memberLoadGeneration, selectedGroupID == groupID else { return }
            members = []
            participantIDs = []
            payerID = nil
            validationMessage = "We could not load this group’s members. Try again."
        }
    }

    private func makeDraft() throws -> ExpenseDraft {
        guard let groupID = selectedGroupID else { throw AddExpenseValidationError.noGroup }
        guard let payerID else { throw AddExpenseValidationError.noPayer }
        let money = try parseMoney(amountText)
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else { throw LedgerValidationError.emptyExpenseTitle }
        let method: SplitMethod
        switch splitSelection {
        case .equal:
            method = .equal
        case .exact:
            method = .exact(try exactAmountsForCurrentInputs())
        case .percentage:
            method = .percentage(try percentagesForCurrentInputs())
        case .shares:
            method = .shares(sharesForCurrentInputs())
        }
        splitMethod = method
        return ExpenseDraft(
            groupID: groupID,
            title: normalizedTitle,
            note: nil,
            total: money,
            paidByUserID: payerID,
            participantIDs: participantIDs,
            splitMethod: method,
            occurredAt: .now,
            createdByUserID: environment.currentUserID
        )
    }

    private func splitMethodForCurrentInputs() -> SplitMethod {
        switch splitSelection {
        case .equal:
            return .equal
        case .exact:
            let values = Dictionary(uniqueKeysWithValues: participantIDs.map {
                ($0, (try? parseMoney(exactAmountTexts[$0] ?? "").minorUnits) ?? 0)
            })
            return .exact(values)
        case .percentage:
            let values = Dictionary(uniqueKeysWithValues: participantIDs.map {
                ($0, Self.parseBasisPoints(percentageTexts[$0] ?? "") ?? 0)
            })
            return .percentage(values)
        case .shares:
            return .shares(sharesForCurrentInputs())
        }
    }

    private func sharesForCurrentInputs() -> [UUID: Int64] {
        Dictionary(uniqueKeysWithValues: participantIDs.map { ($0, Int64(shareCount(for: $0))) })
    }

    private func percentagesForCurrentInputs() throws -> [UUID: Int64] {
        try Dictionary(uniqueKeysWithValues: participantIDs.map { participantID in
            let text = percentageTexts[participantID] ?? ""
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let basisPoints = trimmed.isEmpty ? 0 : Self.parseBasisPoints(trimmed) else {
                throw AddExpenseValidationError.invalidPercentage
            }
            return (participantID, basisPoints)
        })
    }

    /// "33.33" becomes 3333. Up to two decimal places, never above 100.
    static func parseBasisPoints(_ input: String) -> Int64? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count),
              let wholeText = parts.first, !wholeText.isEmpty, wholeText.count <= 3,
              wholeText.allSatisfy({ $0.isASCII && $0.isNumber }),
              let whole = Int64(wholeText) else { return nil }
        var fraction = Int64.zero
        if parts.count == 2 {
            let fractionText = parts[1]
            guard fractionText.count <= 2, fractionText.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
            fraction = Int64(String(fractionText).padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0
        }
        let basisPoints = whole * 100 + fraction
        return basisPoints <= PercentageBasisPoints.oneHundredPercent ? basisPoints : nil
    }

    /// 3333 becomes "33.33", 5000 becomes "50".
    static func percentText(basisPoints: Int64) -> String {
        let whole = basisPoints / 100
        let fraction = basisPoints % 100
        if fraction == 0 { return "\(whole)" }
        return fraction % 10 == 0 ? "\(whole).\(fraction / 10)" : String(format: "%lld.%02lld", whole, fraction)
    }

    private func exactAmountsForCurrentInputs() throws -> [UUID: Int64] {
        do {
            return try Dictionary(uniqueKeysWithValues: participantIDs.map { participantID in
                let amount = try parseMoney(exactAmountTexts[participantID] ?? "", allowsZero: true)
                return (participantID, amount.minorUnits)
            })
        } catch {
            throw AddExpenseValidationError.invalidExactAmount
        }
    }

    private func refreshPreview() {
        splitMethod = splitMethodForCurrentInputs()
        guard let money = try? parseMoney(amountText), !participantIDs.isEmpty,
              let splits = try? SplitCalculator.calculate(total: money, participants: participantIDs, method: splitMethod) else {
            previewSplits = []
            return
        }
        previewSplits = splits
    }

    private func parseMoney(_ input: String, allowsZero: Bool = false) throws -> Money {
        let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count <= 2,
              let enteredWholePart = components.first,
              let wholePart = normalizedWholePart(enteredWholePart),
              components.dropFirst().allSatisfy({ $0.count <= 2 && $0.allSatisfy(\.isNumber) }) else {
            throw AddExpenseValidationError.invalidAmount
        }
        guard let whole = Int64(wholePart) else { throw AddExpenseValidationError.invalidAmount }
        let fractionText = components.count == 2 ? String(components[1]) : ""
        let fraction = Int64(fractionText.padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0
        let (wholeInPaisa, overflow) = whole.multipliedReportingOverflow(by: 100)
        guard !overflow else { throw AddExpenseValidationError.invalidAmount }
        let (minorUnits, additionOverflow) = wholeInPaisa.addingReportingOverflow(fraction)
        guard !additionOverflow, allowsZero ? minorUnits >= 0 : minorUnits > 0 else {
            throw AddExpenseValidationError.invalidAmount
        }
        return Money(minorUnits: minorUnits, currencyCode: "PKR")
    }

    private func normalizedWholePart(_ input: Substring) -> Substring? {
        guard !input.isEmpty else { return nil }
        guard input.contains(",") else {
            return input.allSatisfy(\.isNumber) ? input : nil
        }

        let groups = input.split(separator: ",", omittingEmptySubsequences: false)
        guard groups.count > 1,
              let firstGroup = groups.first,
              (1...3).contains(firstGroup.count),
              firstGroup.allSatisfy(\.isNumber),
              groups.dropFirst().allSatisfy({ $0.count == 3 && $0.allSatisfy(\.isNumber) }) else {
            return nil
        }

        return Substring(groups.map(String.init).joined())
    }

    private func message(for error: Error) -> String {
        switch error {
        case AddExpenseValidationError.invalidAmount, LedgerValidationError.nonPositiveAmount:
            return "Enter an amount greater than PKR 0."
        case AddExpenseValidationError.invalidExactAmount:
            return "Enter a valid amount for each person."
        case LedgerValidationError.emptyExpenseTitle:
            return "Add a short title for this expense."
        case AddExpenseValidationError.noGroup:
            return "Choose a group before saving this expense."
        case AddExpenseValidationError.noPayer:
            return "Choose who paid for this expense."
        case LedgerValidationError.noParticipants:
            return "Choose at least one person to split with."
        case SplitError.invalidExactTotal:
            let amount = (try? parseMoney(amountText)).map { AmountFormatter.string(minorUnits: $0.minorUnits, currencyCode: $0.currencyCode) } ?? "the total"
            return "Exact amounts must add up to \(amount)."
        case AddExpenseValidationError.invalidPercentage:
            return "Enter a percentage from 0 to 100 for each person."
        case SplitError.invalidPercentageTotal:
            let remaining = percentageRemainingBasisPoints
            let gap = Self.percentText(basisPoints: abs(remaining))
            return remaining > 0
                ? "Percentages must add up to 100%. There is \(gap)% left to assign."
                : "Percentages must add up to 100%. They are \(gap)% over."
        case SplitError.nonPositiveTotal:
            return "Enter an amount greater than PKR 0."
        default:
            return "We could not save this expense. Try again."
        }
    }

    private func clearValidationIfNeeded() {
        if validationMessage != nil { validationMessage = nil }
    }
}

private enum AddExpenseValidationError: Error {
    case invalidAmount
    case invalidExactAmount
    case invalidPercentage
    case noGroup
    case noPayer
}
