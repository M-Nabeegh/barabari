import Foundation
import SwiftData

final actor LocalExpenseRepository: ExpenseRepository {
    private let container: ModelContainer
    private let pageSize = 50

    init(container: ModelContainer) {
        self.container = container
    }

    func listExpenses(groupID: UUID, cursor: String?) throws -> Page<Expense> {
        let context = ModelContext(container)
        let expenses = try context.fetch(FetchDescriptor<StoredExpense>())
            .filter { $0.groupID == groupID && $0.deletedAt == nil }
        let domains = try expenses.map { try domainExpense(from: $0, context: context) }
        let sorted = domains.sorted(by: sortExpenses)
        return page(items: sorted, cursor: cursor)
    }

    func saveExpense(_ expense: Expense, idempotencyKey: UUID) throws -> Expense {
        let context = ModelContext(container)
        let records = try context.fetch(FetchDescriptor<StoredExpense>())
        if let idempotentRecord = records.first(where: { $0.idempotencyKey == idempotencyKey }) {
            return try domainExpense(from: idempotentRecord, context: context)
        }

        let isNew: Bool
        let record: StoredExpense
        if let existing = records.first(where: { $0.id == expense.id }) {
            try existing.apply(expense, idempotencyKey: idempotencyKey)
            record = existing
            isNew = false
        } else {
            record = try StoredExpense(expense: expense, idempotencyKey: idempotencyKey)
            context.insert(record)
            isNew = true
        }
        try replaceSplits(for: expense, context: context)
        if isNew {
            context.insert(StoredActivityEvent(event: ActivityEvent(
                groupID: expense.groupID,
                actorUserID: expense.createdByUserID,
                kind: .expenseCreated,
                subjectID: expense.id,
                occurredAt: expense.occurredAt
            )))
        }
        try context.save()
        return try domainExpense(from: record, context: context)
    }

    func requestExpenseDeletion(id: UUID, idempotencyKey: UUID) throws {
        let context = ModelContext(container)
        guard let record = try context.fetch(FetchDescriptor<StoredExpense>()).first(where: { $0.id == id }) else {
            throw LocalPersistenceError.missingExpense(id)
        }
        guard record.deletedAt == nil else { return }

        let now = Date()
        record.deletedAt = now
        record.updatedAt = now
        record.revision += 1
        record.idempotencyKey = idempotencyKey
        context.insert(StoredActivityEvent(event: ActivityEvent(
            groupID: record.groupID,
            actorUserID: record.createdByUserID,
            kind: .expenseDeleted,
            subjectID: record.id,
            occurredAt: now
        )))
        try context.save()
    }

    /// Sync must see tombstones so the server can reconcile deletions without resurrecting records.
    func expenseForSync(id: UUID) throws -> Expense? {
        let context = ModelContext(container)
        guard let record = try context.fetch(FetchDescriptor<StoredExpense>()).first(where: { $0.id == id }) else {
            return nil
        }
        return try domainExpense(from: record, context: context)
    }

    func expensesForSync(groupID: UUID) throws -> [Expense] {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<StoredExpense>())
            .filter { $0.groupID == groupID }
            .map { try domainExpense(from: $0, context: context) }
            .sorted(by: sortExpenses)
    }

    private func replaceSplits(for expense: Expense, context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<StoredExpenseSplit>())
            .filter { $0.expenseID == expense.id }
        var existingByUserID = Dictionary(uniqueKeysWithValues: existing.map { ($0.userID, $0) })
        for split in expense.splits {
            if let record = existingByUserID.removeValue(forKey: split.userID) {
                record.apply(split)
            } else {
                context.insert(StoredExpenseSplit(expenseID: expense.id, split: split))
            }
        }
        for obsolete in existingByUserID.values {
            context.delete(obsolete)
        }
    }

    private func domainExpense(from record: StoredExpense, context: ModelContext) throws -> Expense {
        let splits = try context.fetch(FetchDescriptor<StoredExpenseSplit>())
            .filter { $0.expenseID == record.id }
            .map(\.asDomain)
            .sorted { uuidBytes($0.userID).lexicographicallyPrecedes(uuidBytes($1.userID)) }
        return try record.asDomain(splits: splits)
    }

    private func page(items: [Expense], cursor: String?) -> Page<Expense> {
        let start = min(max(Int(cursor ?? "0") ?? 0, 0), items.count)
        let end = min(start + pageSize, items.count)
        return Page(items: Array(items[start..<end]), nextCursor: end < items.count ? String(end) : nil)
    }

    private func sortExpenses(_ lhs: Expense, _ rhs: Expense) -> Bool {
        if lhs.occurredAt != rhs.occurredAt { return lhs.occurredAt > rhs.occurredAt }
        return uuidBytes(lhs.id).lexicographicallyPrecedes(uuidBytes(rhs.id))
    }

    private func uuidBytes(_ id: UUID) -> [UInt8] {
        withUnsafeBytes(of: id.uuid) { Array($0) }
    }
}
