import Foundation

struct ExpenseSplit: Equatable, Codable, Sendable {
    let userID: UUID
    let amount: Money

    init(userID: UUID, amount: Money) {
        self.userID = userID
        self.amount = amount
    }
}
