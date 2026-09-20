import SwiftData

/// Composes persistence at the app boundary so SwiftUI features depend on repositories, never SwiftData models.
@MainActor
struct AppEnvironment {
    let modelContainer: ModelContainer
    let groupRepository: LocalGroupRepository
    let expenseRepository: LocalExpenseRepository
    let settlementRepository: LocalSettlementRepository
    let balanceRepository: LocalBalanceRepository

    static let live = AppEnvironment(inMemory: false)
    static let demo = AppEnvironment(inMemory: true, seedDemoData: true)

    init(inMemory: Bool, seedDemoData: Bool = false) {
        do {
            let container = try BarabariModelContainer.make(inMemory: inMemory)
            if seedDemoData {
                try BarabariModelContainer.seedDemoData(in: container)
            }
            modelContainer = container
            groupRepository = LocalGroupRepository(container: container)
            expenseRepository = LocalExpenseRepository(container: container)
            settlementRepository = LocalSettlementRepository(container: container)
            balanceRepository = LocalBalanceRepository(container: container)
        } catch {
            fatalError("Unable to create Barabari's local ledger store: \(error.localizedDescription)")
        }
    }

    func recentActivity(limit: Int) async throws -> [ActivityEvent] {
        try await groupRepository.recentActivities(limit: limit)
    }
}
