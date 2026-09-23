import SwiftUI

struct BarabariCard<Content: View>: View {
    private let content: Content
    @Environment(\.colorScheme) private var colorScheme

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(BarabariSpacing.card)
            .background(BarabariColors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                BarabariColors.raised.opacity(colorScheme == .dark ? 0.92 : 0.72),
                                BarabariColors.raised.opacity(colorScheme == .dark ? 0.48 : 0.46)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.30 : 0.08),
                radius: colorScheme == .dark ? 20 : 16,
                y: colorScheme == .dark ? 8 : 6
            )
    }
}

struct BarabariCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.86 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.18),
                value: configuration.isPressed
            )
    }
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
