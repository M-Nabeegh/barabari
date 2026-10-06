import Foundation
import SwiftData

private let barabariDefaultUserID = UUID(uuidString: "56D75B9A-0238-45B6-9EF7-A3526D58B2A5")!

/// Composes persistence at the app boundary so SwiftUI features depend on repositories, never SwiftData models.
@MainActor
struct AppEnvironment {
    static let demoUserID = barabariDefaultUserID

    let modelContainer: ModelContainer
    let groupRepository: LocalGroupRepository
    let expenseRepository: LocalExpenseRepository
    let settlementRepository: LocalSettlementRepository
    let balanceRepository: LocalBalanceRepository
    let currentUserID: UUID
    let isOffline: Bool
    let isDemo: Bool
    /// Present only for the on-device ledger of a build configured for Supabase.
    let syncConfiguration: SyncConfiguration?

    static let live = AppEnvironment(inMemory: false, syncConfiguration: SyncConfiguration.fromBundle())
    static let demo = AppEnvironment(inMemory: true, seedDemoData: true)

    init(
        inMemory: Bool,
        seedDemoData: Bool = false,
        seedDemoSecondMember: Bool = false,
        seedDemoDebt: Bool = false,
        currentUserID: UUID? = nil,
        isOffline: Bool = false,
        syncConfiguration: SyncConfiguration? = nil
    ) {
        do {
            let container = try BarabariModelContainer.make(inMemory: inMemory)
            if seedDemoData {
                try BarabariModelContainer.seedDemoData(
                    in: container,
                    includeSecondMember: seedDemoSecondMember,
                    includeDemoDebt: seedDemoDebt
                )
            }
            modelContainer = container
            groupRepository = LocalGroupRepository(container: container)
            expenseRepository = LocalExpenseRepository(container: container)
            settlementRepository = LocalSettlementRepository(container: container)
            balanceRepository = LocalBalanceRepository(container: container)
            if let currentUserID {
                self.currentUserID = currentUserID
            } else if inMemory {
                self.currentUserID = barabariDefaultUserID
            } else {
                self.currentUserID = try LocalIdentity.resolve(container: container)
            }
            self.isOffline = isOffline
            self.isDemo = seedDemoData
            self.syncConfiguration = inMemory ? nil : syncConfiguration
        } catch {
            fatalError("Unable to create Barabari's local ledger store: \(error.localizedDescription)")
        }
    }

    func recentActivity(limit: Int) async throws -> [ActivityEvent] {
        try await groupRepository.recentActivities(limit: limit)
    }

    func activityPage(limit: Int, cursor: String?) async throws -> Page<ActivityEvent> {
        try await groupRepository.listActivities(limit: limit, cursor: cursor)
    }

    func activity(groupID: UUID) async throws -> [ActivityEvent] {
        try await groupRepository.activities(groupID: groupID)
    }
}
