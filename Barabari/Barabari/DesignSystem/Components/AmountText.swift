import Foundation
import SwiftUI

enum AmountFormatter {
    static func string(minorUnits: Int64, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode.uppercased()
        formatter.currencySymbol = currencyCode.uppercased() == "PKR" ? "PKR" : currencyCode.uppercased()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "en_PK")

        let amount = Decimal(minorUnits) / 100
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(currencyCode.uppercased()) 0"
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
        Text(AmountFormatter.string(minorUnits: minorUnits, currencyCode: currencyCode))
            .font(BarabariTypography.amount(for: style))
            .monospacedDigit()
            .foregroundStyle(BarabariColors.textPrimary)
            .accessibilityLabel("\(AmountFormatter.string(minorUnits: minorUnits, currencyCode: currencyCode))")
    }
}

#Preview {
    AmountText(minorUnits: 565_000, currencyCode: "PKR", style: .hero)
        .padding()
}
