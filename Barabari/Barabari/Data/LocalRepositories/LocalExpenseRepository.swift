import Foundation
import SwiftData

final actor LocalExpenseRepository: ExpenseRepository {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func listExpenses(groupID: UUID, cursor: String?) throws -> Page<Expense> {
        let context = ModelContext(container)
        let expenses = try context.fetch(FetchDescriptor<StoredExpense>())
            .filter { $0.groupID == groupID && $0.deletedAt == nil }
        let domains = try expenses.map { try domainExpense(from: $0, context: context) }
        let sorted = domains.sorted(by: sortExpenses)
        return try LocalLedgerPagination.page(
            items: sorted,
            cursor: cursor,
            occurredAt: \.occurredAt,
            id: \.id
        )
    }

    func saveExpense(_ expense: Expense, idempotencyKey: UUID) throws -> Expense {
        let context = ModelContext(container)
        if let command = try command(for: idempotencyKey, context: context) {
            return try existingExpense(for: command, context: context)
        }

        let records = try context.fetch(FetchDescriptor<StoredExpense>())
        let isNew: Bool
        let record: StoredExpense
        if let existing = records.first(where: { $0.id == expense.id }) {
            try existing.apply(expense)
            record = existing
            isNew = false
        } else {
            record = try StoredExpense(expense: expense)
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
        context.insert(StoredLedgerCommand(
            idempotencyKey: idempotencyKey,
            kind: .saveExpense,
            subjectID: expense.id
        ))
        do {
            try context.save()
        } catch {
            let recoveryContext = ModelContext(container)
            if let command = try? command(for: idempotencyKey, context: recoveryContext) {
                return try existingExpense(for: command, context: recoveryContext)
            }
            throw error
        }
        return try domainExpense(from: record, context: context)
    }

    func requestExpenseDeletion(id: UUID, idempotencyKey: UUID) throws {
        let context = ModelContext(container)
        if let command = try command(for: idempotencyKey, context: context) {
            guard command.kind == .deleteExpense, command.subjectID == id else {
                throw LocalPersistenceError.idempotencyKeyConflict(idempotencyKey)
            }
            return
        }
        guard let record = try context.fetch(FetchDescriptor<StoredExpense>()).first(where: { $0.id == id }) else {
            throw LocalPersistenceError.missingExpense(id)
        }
        guard record.deletedAt == nil else { return }

        let now = Date()
        record.deletedAt = now
        record.updatedAt = now
        record.revision += 1
        context.insert(StoredActivityEvent(event: ActivityEvent(
            groupID: record.groupID,
            actorUserID: record.createdByUserID,
            kind: .expenseDeleted,
            subjectID: record.id,
            occurredAt: now
        )))
        context.insert(StoredLedgerCommand(
            idempotencyKey: idempotencyKey,
            kind: .deleteExpense,
            subjectID: id
        ))
        do {
            try context.save()
        } catch {
            let recoveryContext = ModelContext(container)
            if let command = try? command(for: idempotencyKey, context: recoveryContext),
               command.kind == .deleteExpense,
               command.subjectID == id {
                return
            }
            throw error
        }
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

    private func command(for key: UUID, context: ModelContext) throws -> StoredLedgerCommand? {
        try context.fetch(FetchDescriptor<StoredLedgerCommand>()).first { $0.idempotencyKey == key }
    }

    private func existingExpense(for command: StoredLedgerCommand, context: ModelContext) throws -> Expense {
        guard command.kind == .saveExpense else {
            throw LocalPersistenceError.idempotencyKeyConflict(command.idempotencyKey)
        }
        guard let record = try context.fetch(FetchDescriptor<StoredExpense>()).first(where: { $0.id == command.subjectID }) else {
            throw LocalPersistenceError.missingIdempotencySubject(command.idempotencyKey)
        }
        return try domainExpense(from: record, context: context)
    }

    private func sortExpenses(_ lhs: Expense, _ rhs: Expense) -> Bool {
        if lhs.occurredAt != rhs.occurredAt { return lhs.occurredAt > rhs.occurredAt }
        return uuidBytes(lhs.id).lexicographicallyPrecedes(uuidBytes(rhs.id))
    }

    private func uuidBytes(_ id: UUID) -> [UInt8] {
        withUnsafeBytes(of: id.uuid) { Array($0) }
    }
}
