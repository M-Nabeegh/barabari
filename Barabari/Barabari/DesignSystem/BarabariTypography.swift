import SwiftUI

enum BarabariTypography {
    static let screenTitle = Font.system(.largeTitle, design: .default, weight: .bold)
    static let sectionTitle = Font.system(.title3, design: .default, weight: .semibold)
    static let headline = Font.system(.headline, design: .default, weight: .semibold)
    static let body = Font.system(.body, design: .default, weight: .regular)
    static let metadata = Font.system(.footnote, design: .default, weight: .regular)
    static let eyebrow = Font.system(.caption, design: .default, weight: .semibold)

    static func amount(for style: AmountText.Style) -> Font {
        switch style {
        case .hero:
            return .system(size: 44, weight: .bold, design: .rounded)
        case .title:
            return .system(.title, design: .rounded, weight: .bold)
        case .body:
            return .system(.body, design: .rounded, weight: .semibold)
        case .compact:
            return .system(.subheadline, design: .rounded, weight: .semibold)
        }
    }
}
