import Foundation

protocol SettlementRepository {
    func listSettlements(groupID: UUID, cursor: String?) async throws -> Page<Settlement>
    func saveSettlement(_ settlement: Settlement, idempotencyKey: UUID) async throws -> Settlement
}
