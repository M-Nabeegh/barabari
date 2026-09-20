import Foundation
import SwiftUI

enum AmountFormatter {
    private static let formatterCache = NSCache<NSString, NumberFormatter>()
    private static let formatterLock = NSLock()

    static func string(minorUnits: Int64, currencyCode: String) -> String {
        let normalizedCurrency = currencyCode.uppercased()
        let cacheKey = "\(normalizedCurrency)|en_PK" as NSString
        formatterLock.lock()
        defer { formatterLock.unlock() }

        let formatter: NumberFormatter
        if let cached = formatterCache.object(forKey: cacheKey) {
            formatter = cached
        } else {
            let created = NumberFormatter()
            created.numberStyle = .currency
            created.currencyCode = normalizedCurrency
            created.currencySymbol = normalizedCurrency == "PKR" ? "PKR" : normalizedCurrency
            created.minimumFractionDigits = 0
            created.maximumFractionDigits = 2
            created.locale = Locale(identifier: "en_PK")
            formatterCache.setObject(created, forKey: cacheKey)
            formatter = created
        }

        let amount = Decimal(minorUnits) / 100
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(normalizedCurrency) 0"
    }
}

struct AmountText: View {
    enum Style {
        case hero
        case title
        case body
        case compact
    }

    let minorUnits: Int64
    let currencyCode: String
    let style: Style

    init(minorUnits: Int64, currencyCode: String, style: Style) {
        self.minorUnits = minorUnits
        self.currencyCode = currencyCode
        self.style = style
    }

    var body: some View {
        let displayValue = AmountFormatter.string(minorUnits: minorUnits, currencyCode: currencyCode)
        return Text(displayValue)
            .font(BarabariTypography.amount(for: style))
            .monospacedDigit()
            .foregroundStyle(BarabariColors.textPrimary)
            .accessibilityLabel(displayValue)
    }
}

#Preview {
    AmountText(minorUnits: 565_000, currencyCode: "PKR", style: .hero)
        .padding()
}
