import SwiftUI

struct BarabariCard<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    init(padding: CGFloat = BarabariSpacing.card, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BarabariColors.surface, in: .rect(cornerRadius: BarabariSpacing.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: BarabariSpacing.cardRadius, style: .continuous)
                    .strokeBorder(BarabariColors.hairline, lineWidth: 1)
            }
    }
}

/// Springy press feedback used for every tappable card and tile.
struct BarabariCardButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.97
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? pressedScale : 1)
            .brightness(configuration.isPressed ? -0.02 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == BarabariCardButtonStyle {
    static var pressable: BarabariCardButtonStyle { BarabariCardButtonStyle() }
}

#Preview {
    BarabariCard {
        VStack(alignment: .leading, spacing: BarabariSpacing.compact) {
            Text("Weekend in Lahore")
                .font(BarabariTypography.sectionTitle)
            Text("You are owed Rs 5,650")
                .foregroundStyle(BarabariColors.textSecondary)
        }
    }
    .padding()
    .background(BarabariColors.background)
}
