import Foundation
import SwiftData

final actor LocalBalanceRepository: BalanceRepository {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func summary(groupID: UUID) throws -> BalanceSummary {
        let context = ModelContext(container)
        let members = try context.fetch(FetchDescriptor<StoredGroupMember>())
            .filter { $0.groupID == groupID }
            .map(\.asDomain)
        let expenses = try context.fetch(FetchDescriptor<StoredExpense>())
            .filter { $0.groupID == groupID }
            .map { try domainExpense(from: $0, context: context) }
        let settlements = try context.fetch(FetchDescriptor<StoredSettlement>())
            .filter { $0.groupID == groupID }
            .map(\.asDomain)
        return try BalanceCalculator.calculate(expenses: expenses, settlements: settlements, members: members)
    }

    private func domainExpense(from record: StoredExpense, context: ModelContext) throws -> Expense {
        let splits = try context.fetch(FetchDescriptor<StoredExpenseSplit>())
            .filter { $0.expenseID == record.id }
            .map(\.asDomain)
            .sorted { uuidBytes($0.userID).lexicographicallyPrecedes(uuidBytes($1.userID)) }
        return try record.asDomain(splits: splits)
    }

    private func uuidBytes(_ id: UUID) -> [UInt8] {
        withUnsafeBytes(of: id.uuid) { Array($0) }
    }
}
