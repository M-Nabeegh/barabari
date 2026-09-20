import Foundation
import SwiftData

/// Composes persistence at the app boundary so SwiftUI features depend on repositories, never SwiftData models.
@MainActor
struct AppEnvironment {
    static let demoUserID = UUID(uuidString: "56D75B9A-0238-45B6-9EF7-A3526D58B2A5")!

    let modelContainer: ModelContainer
    let groupRepository: LocalGroupRepository
    let expenseRepository: LocalExpenseRepository
    let settlementRepository: LocalSettlementRepository
    let balanceRepository: LocalBalanceRepository
    let currentUserID: UUID
    let isOffline: Bool

    static let live = AppEnvironment(inMemory: false)
    static let demo = AppEnvironment(inMemory: true, seedDemoData: true)

    init(
        inMemory: Bool,
        seedDemoData: Bool = false,
        currentUserID: UUID = AppEnvironment.demoUserID,
        isOffline: Bool = false
    ) {
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
            self.currentUserID = currentUserID
            self.isOffline = isOffline
        } catch {
            fatalError("Unable to create Barabari's local ledger store: \(error.localizedDescription)")
        }
    }

    func recentActivity(limit: Int) async throws -> [ActivityEvent] {
        try await groupRepository.recentActivities(limit: limit)
    }

    func activity(groupID: UUID) async throws -> [ActivityEvent] {
        try await groupRepository.activities(groupID: groupID)
    }
}
