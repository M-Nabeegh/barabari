import SwiftUI

struct StatusBadge<Label: View>: View {
    enum Style {
        case success
        case warning
        case danger
        case neutral

        var color: Color {
            switch self {
            case .success: BarabariColors.success
            case .warning: BarabariColors.warning
            case .danger: BarabariColors.danger
            case .neutral: BarabariColors.textSecondary
            }
        }
    }

    private let style: Style
    private let label: Label

    init(style: Style, @ViewBuilder label: () -> Label) {
        self.style = style
        self.label = label()
    }

    var body: some View {
        label
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(style.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(style.color.opacity(0.13), in: Capsule())
    }
}

extension StatusBadge where Label == Text {
    init(_ title: String, style: Style) {
        self.init(style: style) {
            Text(LocalizedStringKey(title))
        }
    }
}
