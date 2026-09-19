import Foundation

struct Page<Item: Equatable & Sendable>: Equatable, Sendable {
    let items: [Item]
    let nextCursor: String?
}

protocol ExpenseRepository {
    func listExpenses(groupID: UUID, cursor: String?) async throws -> Page<Expense>
    func saveExpense(_ expense: Expense, idempotencyKey: UUID) async throws -> Expense
    func requestExpenseDeletion(id: UUID, idempotencyKey: UUID) async throws
}
