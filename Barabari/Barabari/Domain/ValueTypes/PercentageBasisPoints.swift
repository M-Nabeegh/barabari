import Foundation

struct PercentageBasisPoints: Equatable, Codable, Sendable {
    static let oneHundredPercent: Int64 = 10_000

    let value: Int64

    init(_ value: Int64) {
        self.value = value
    }
}
