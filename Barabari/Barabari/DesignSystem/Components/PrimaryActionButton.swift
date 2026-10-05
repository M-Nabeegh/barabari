import SwiftUI

struct PrimaryActionButton<Label: View>: View {
    private let action: () -> Void
    private let label: Label

    init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.action = action
        self.label = label()
    }

    var body: some View {
        Button {
            BarabariInteraction.trigger(.selection)
            action()
        } label: {
            label
                .font(.system(.body, design: .rounded, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 54)
                .contentShape(Capsule())
        }
        .buttonStyle(BarabariPrimaryButtonStyle())
    }
}

struct BarabariPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(BarabariColors.onAccent)
            .background {
                Capsule()
                    .fill(BarabariColors.accent.gradient)
                    .overlay {
                        Capsule()
                            .strokeBorder(.white.opacity(0.22), lineWidth: 0.5)
                            .blendMode(.plusLighter)
                    }
                    .shadow(color: BarabariColors.accent.opacity(isEnabled ? 0.35 : 0), radius: 14, y: 6)
            }
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Quiet glass capsule for secondary actions.
struct SecondaryActionButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button {
            BarabariInteraction.trigger(.selection)
            action()
        } label: {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(LocalizedStringKey(title))
            }
            .font(.system(.body, design: .rounded, weight: .semibold))
            .foregroundStyle(BarabariColors.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 54)
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

extension PrimaryActionButton where Label == Text {
    init(_ title: String, action: @escaping () -> Void) {
        self.init(action: action) {
            Text(LocalizedStringKey(title))
        }
    }
}
