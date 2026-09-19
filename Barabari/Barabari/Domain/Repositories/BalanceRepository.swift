import Foundation

protocol BalanceRepository {
    func summary(groupID: UUID) async throws -> BalanceSummary
}
