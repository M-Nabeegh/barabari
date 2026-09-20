import Combine
import Foundation

enum ExpenseSplitSelection: String, CaseIterable, Identifiable {
    case equal
    case exact

    var id: Self { self }

    var title: String {
        switch self {
        case .equal: "Equal split"
        case .exact: "Exact amount"
        }
    }
}

@MainActor
final class AddExpenseViewModel: ObservableObject {
    @Published var amountText = "" {
        didSet { refreshPreview() }
    }
    @Published var title = "" {
        didSet { clearValidationIfNeeded() }
    }
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
    @Published var validationMessage: String?
    @Published var previewSplits: [ExpenseSplit] = []
    @Published private(set) var groups: [Group] = []
    @Published private(set) var members: [GroupMember] = []
    @Published private(set) var selectedGroupID: UUID?
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var savedExpense: Expense?

    private let environment: AppEnvironment
    private let memberLoader: (UUID) async throws -> [GroupMember]
    private var exactAmountTexts: [UUID: String] = [:]
    private var memberLoadTask: Task<Void, Never>?
    private var memberLoadGeneration = 0

    init(environment: AppEnvironment, memberLoader: ((UUID) async throws -> [GroupMember])? = nil) {
        self.environment = environment
        self.memberLoader = memberLoader ?? { groupID in
            try await environment.groupRepository.members(groupID: groupID)
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            groups = try await environment.groupRepository.listGroups()
            if selectedGroupID == nil || !groups.contains(where: { $0.id == selectedGroupID }) {
                selectedGroupID = groups.first?.id
            }
            beginMemberLoad(for: selectedGroupID)
            await memberLoadTask?.value
        } catch {
            validationMessage = "We could not load your groups. Try again."
        }
    }

    func selectGroup(_ id: UUID) {
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

    func memberName(for id: UUID) -> String {
        if id == environment.currentUserID { return "You" }
        guard let index = members.firstIndex(where: { $0.userID == id }) else { return "Group member" }
        return "Member \(index + 1)"
    }

    func addAnotherExpense() {
        amountText = ""
        title = ""
        splitSelection = .equal
        splitMethod = .equal
        exactAmountTexts = [:]
        previewSplits = []
        validationMessage = nil
        savedExpense = nil
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
        }
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
    case noGroup
    case noPayer
}
