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
                .frame(maxWidth: .infinity, minHeight: max(52, BarabariInteraction.minimumHitSize))
                .contentShape(Rectangle())
        }
        .buttonStyle(BarabariPrimaryButtonStyle())
        .accessibilityAddTraits(.isButton)
    }
}

private struct BarabariPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(BarabariColors.onAccent)
            .background(BarabariColors.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

extension PrimaryActionButton where Label == Text {
    init(_ title: String, action: @escaping () -> Void) {
        self.init(action: action) {
            Text(title)
        }
    }
}
