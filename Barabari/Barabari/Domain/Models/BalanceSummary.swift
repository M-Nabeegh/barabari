import Foundation

struct BalancePosition: Equatable, Codable, Sendable {
    let userID: UUID
    let amount: Money
}

struct BalanceTransfer: Equatable, Codable, Sendable {
    let fromUserID: UUID
    let toUserID: UUID
    let amount: Money
}

struct BalanceSummary: Equatable, Codable, Sendable {
    let groupID: UUID
    let netPositions: [BalancePosition]
    let transfers: [BalanceTransfer]

    func netPosition(for userID: UUID) -> BalancePosition? {
        netPositions.first { $0.userID == userID }
    }
}
