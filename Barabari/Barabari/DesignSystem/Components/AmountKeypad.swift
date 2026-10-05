import SwiftUI

/// Pure editing rules for keypad amount entry, kept separate so they are unit-testable.
enum AmountInput {
    static let maxWholeDigits = 9

    enum Key: Hashable {
        case digit(Int)
        case decimal
        case backspace
    }

    static func apply(_ key: Key, to text: String) -> String {
        switch key {
        case let .digit(value):
            let parts = text.split(separator: ".", omittingEmptySubsequences: false)
            if parts.count == 2 {
                return parts[1].count >= 2 ? text : text + String(value)
            }
            if text == "0" { return value == 0 ? text : String(value) }
            return text.count >= maxWholeDigits ? text : text + String(value)
        case .decimal:
            if text.contains(".") { return text }
            return text.isEmpty ? "0." : text + "."
        case .backspace:
            return String(text.dropLast())
        }
    }

    /// Groups the whole part for display while preserving what the user typed after the dot.
    static func display(_ text: String) -> String {
        guard !text.isEmpty else { return "0" }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        let whole = Int64(parts[0]) ?? 0
        let grouped = whole.formatted(.number.grouping(.automatic).locale(Locale(identifier: "en_PK")))
        return parts.count == 2 ? grouped + "." + parts[1] : grouped
    }
}

/// SadaPay-style amount entry: a huge live-formatted figure above a custom keypad.
struct AmountEntryField: View {
    @Binding var text: String
    var prompt = "How much did you spend?"
    var accessibilityIdentifier: String
    var size: CGFloat = 64
    /// Increment to shake the figure, e.g. when validation fails.
    var shakeTrigger = 0

    var body: some View {
        VStack(spacing: 10) {
            Text(LocalizedStringKey(prompt))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(BarabariColors.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Rs")
                    .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                    .foregroundStyle(BarabariColors.textSecondary)
                Text(AmountInput.display(text))
                    .font(.system(size: size, weight: .bold, design: .rounded))
                    .foregroundStyle(text.isEmpty ? BarabariColors.textTertiary : BarabariColors.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(text) ?? 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
            }
            .frame(maxWidth: .infinity)
            .modifier(ShakeEffect(animatableData: CGFloat(shakeTrigger)))
            .animation(.linear(duration: 0.4), value: shakeTrigger)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Amount")
            .accessibilityValue(text.isEmpty ? "0" : text)
            .accessibilityIdentifier(accessibilityIdentifier)
        }
    }
}

struct AmountKeypad: View {
    @Binding var text: String
    var identifierPrefix = "keypad"

    private let rows: [[AmountInput.Key]] = [
        [.digit(1), .digit(2), .digit(3)],
        [.digit(4), .digit(5), .digit(6)],
        [.digit(7), .digit(8), .digit(9)],
        [.decimal, .digit(0), .backspace]
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { key in
                        KeypadKey(key: key) {
                            let updated = AmountInput.apply(key, to: text)
                            if updated == text {
                                BarabariInteraction.trigger(.error)
                            } else {
                                BarabariInteraction.trigger(.selection)
                                text = updated
                            }
                        }
                        .accessibilityIdentifier("\(identifierPrefix)-\(label(for: key))")
                    }
                }
            }
        }
    }

    private func label(for key: AmountInput.Key) -> String {
        switch key {
        case let .digit(value): "\(value)"
        case .decimal: "decimal"
        case .backspace: "delete"
        }
    }
}

private struct KeypadKey: View {
    let key: AmountInput.Key
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SwiftUI.Group {
                switch key {
                case let .digit(value):
                    Text("\(value)")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                case .decimal:
                    Text(".")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                case .backspace:
                    Image(systemName: "delete.backward")
                        .font(.system(size: 22, weight: .medium))
                }
            }
            .foregroundStyle(BarabariColors.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 56)
            .contentShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(KeypadButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        switch key {
        case let .digit(value): "\(value)"
        case .decimal: "Decimal point"
        case .backspace: "Delete"
        }
    }
}

private struct KeypadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(configuration.isPressed ? BarabariColors.accent.opacity(0.18) : Color.clear)
            }
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(animatableData * .pi * 4), y: 0))
    }
}
