import SwiftUI

enum BarabariTypography {
    static let screenTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let sectionTitle = Font.system(.title3, design: .rounded, weight: .semibold)
    static let body = Font.system(.body, design: .default, weight: .regular)
    static let metadata = Font.system(.footnote, design: .default, weight: .regular)

    static func amount(for style: AmountText.Style) -> Font {
        switch style {
        case .hero:
            return .system(.largeTitle, design: .rounded, weight: .bold)
        case .title:
            return .system(.title2, design: .rounded, weight: .bold)
        case .body:
            return .system(.body, design: .rounded, weight: .semibold)
        case .compact:
            return .system(.footnote, design: .rounded, weight: .semibold)
        }
    }
}
