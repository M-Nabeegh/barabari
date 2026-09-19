import Foundation

struct Money: Equatable, Codable, Sendable {
    let minorUnits: Int64
    let currencyCode: String

    init(minorUnits: Int64, currencyCode: String) {
        self.minorUnits = minorUnits
        self.currencyCode = currencyCode
    }
}
