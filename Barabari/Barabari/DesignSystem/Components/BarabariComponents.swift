import SwiftUI

// MARK: - Avatars

struct MemberAvatar: View {
    let name: String
    let seed: UUID
    var size: CGFloat = 40

    private var palette: (Color, Color) {
        let index = Int(seed.uuid.0 ^ seed.uuid.15) % BarabariColors.avatarPalettes.count
        return BarabariColors.avatarPalettes[index]
    }

    private var initials: String {
        if name == "You" {
            // Prefer the owner's own initial once they have told us their name.
            if let first = LedgerMetadata.shared.ownerName.first { return String(first).uppercased() }
            return size >= 40 ? "You" : "Y"
        }
        let parts = name.split(separator: " ")
        if let last = parts.last, last.allSatisfy(\.isNumber) {
            return "M\(last)"
        }
        return parts.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }

    var body: some View {
        Circle()
            .fill(LinearGradient(colors: [palette.0, palette.1], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                Text(initials)
                    .font(.system(size: size * (initials.count > 2 ? 0.3 : 0.38), weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
            }
            .overlay {
                Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct GroupAvatar: View {
    let name: String
    let seed: UUID
    var size: CGFloat = 48

    private var palette: (Color, Color) {
        let index = Int(seed.uuid.3 ^ seed.uuid.9) % BarabariColors.avatarPalettes.count
        return BarabariColors.avatarPalettes[index]
    }

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(LinearGradient(colors: [palette.0, palette.1], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                Text(name.first.map { String($0).uppercased() } ?? "B")
                    .font(.system(size: size * 0.44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 0.5)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - Icon tile

struct IconTile: View {
    let systemImage: String
    var color: Color = BarabariColors.accent
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.14), in: .rect(cornerRadius: size * 0.32))
            .accessibilityHidden(true)
    }
}

// MARK: - Section header

struct SectionHeader<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(LocalizedStringKey(title))
                .font(BarabariTypography.sectionTitle)
                .foregroundStyle(BarabariColors.textPrimary)
            Spacer()
            trailing
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BarabariColors.accent)
        }
        .padding(.horizontal, 4)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}

// MARK: - Quick actions

struct QuickActionButton: View {
    let title: String
    let systemImage: String
    var prominent = false
    let action: () -> Void

    @State private var bounce = 0

    var body: some View {
        Button {
            BarabariInteraction.trigger(.selection)
            bounce += 1
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .symbolEffect(.bounce.down, value: bounce)
                    .foregroundStyle(prominent ? BarabariColors.onAccent : BarabariColors.textPrimary)
                    .frame(width: 58, height: 58)
                    .background {
                        if prominent {
                            Circle().fill(BarabariColors.accent.gradient)
                        }
                    }
                    .glassEffect(prominent ? .regular.tint(BarabariColors.accent).interactive() : .regular.interactive(), in: .circle)
                Text(LocalizedStringKey(title))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(BarabariColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(Text(LocalizedStringKey(title)))
    }
}

// MARK: - Hero balance card

/// Slowly drifting emerald mesh, the visual signature of the app.
struct BarabariMeshBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var tone: Tone = .emerald

    enum Tone {
        case emerald
        case rose
        case graphite
    }

    private var colors: [Color] {
        switch tone {
        case .emerald:
            return [
                Color(uiColor: UIColor(hex: 0x022C22)), Color(uiColor: UIColor(hex: 0x065F46)), Color(uiColor: UIColor(hex: 0x0E7C5A)),
                Color(uiColor: UIColor(hex: 0x064E3B)), Color(uiColor: UIColor(hex: 0x10B981)), Color(uiColor: UIColor(hex: 0x34D399)),
                Color(uiColor: UIColor(hex: 0x0B4F3C)), Color(uiColor: UIColor(hex: 0x0D9488)), Color(uiColor: UIColor(hex: 0x99F6E4))
            ]
        case .rose:
            return [
                Color(uiColor: UIColor(hex: 0x3B0A1A)), Color(uiColor: UIColor(hex: 0x7F1D3A)), Color(uiColor: UIColor(hex: 0x9F1239)),
                Color(uiColor: UIColor(hex: 0x4C0519)), Color(uiColor: UIColor(hex: 0xE11D48)), Color(uiColor: UIColor(hex: 0xFB7185)),
                Color(uiColor: UIColor(hex: 0x581C2E)), Color(uiColor: UIColor(hex: 0xBE185D)), Color(uiColor: UIColor(hex: 0xFDA4AF))
            ]
        case .graphite:
            return [
                Color(uiColor: UIColor(hex: 0x0B0F0E)), Color(uiColor: UIColor(hex: 0x1F2937)), Color(uiColor: UIColor(hex: 0x111827)),
                Color(uiColor: UIColor(hex: 0x111827)), Color(uiColor: UIColor(hex: 0x065F46)), Color(uiColor: UIColor(hex: 0x374151)),
                Color(uiColor: UIColor(hex: 0x0B0F0E)), Color(uiColor: UIColor(hex: 0x1F2937)), Color(uiColor: UIColor(hex: 0x34D399))
            ]
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5],
                    [Float(0.5 + 0.18 * sin(t * 0.45)), Float(0.5 + 0.14 * cos(t * 0.38))],
                    [1, Float(0.5 + 0.12 * sin(t * 0.3))],
                    [0, 1], [Float(0.5 + 0.16 * cos(t * 0.33)), 1], [1, 1]
                ],
                colors: colors
            )
        }
    }
}

// MARK: - Hero amount

/// Large balance figure with a small currency prefix, SadaPay style.
struct HeroAmount: View {
    let minorUnits: Int64
    var currencyCode = "PKR"
    var size: CGFloat = 46
    var color: Color = .white

    var body: some View {
        let isNegative = minorUnits < 0
        let magnitude = minorUnits == .min ? Int64.max : abs(minorUnits)
        let whole = magnitude / 100
        let fraction = magnitude % 100
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(isNegative ? "−\(currencySymbol)" : currencySymbol)
                .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                .foregroundStyle(color.opacity(0.75))
            Text(whole.formatted(.number.grouping(.automatic)))
                .font(.system(size: size, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText(value: Double(whole)))
            if fraction != 0 {
                Text(String(format: ".%02d", fraction))
                    .font(.system(size: size * 0.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(color.opacity(0.75))
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AmountFormatter.string(minorUnits: minorUnits, currencyCode: currencyCode))
    }

    private var currencySymbol: String {
        currencyCode.uppercased() == "PKR" ? "Rs" : currencyCode.uppercased()
    }
}

// MARK: - Empty state

struct BarabariEmptyState<Actions: View>: View {
    let systemImage: String
    let title: String
    let message: String
    let actions: Actions

    @State private var appeared = false

    init(systemImage: String, title: String, message: String, @ViewBuilder actions: () -> Actions) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: BarabariSpacing.section) {
            ZStack {
                Circle()
                    .fill(BarabariColors.accent.opacity(0.12))
                    .frame(width: 112, height: 112)
                    .scaleEffect(appeared ? 1 : 0.6)
                Image(systemName: systemImage)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(BarabariColors.accent.gradient)
                    .symbolEffect(.bounce, value: appeared)
            }
            VStack(spacing: BarabariSpacing.compact) {
                Text(LocalizedStringKey(title))
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(LocalizedStringKey(message))
                    .font(BarabariTypography.body)
                    .foregroundStyle(BarabariColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: BarabariSpacing.row) {
                actions
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) { appeared = true }
        }
    }
}

extension BarabariEmptyState where Actions == EmptyView {
    init(systemImage: String, title: String, message: String) {
        self.init(systemImage: systemImage, title: title, message: message) { EmptyView() }
    }
}

// MARK: - Loading

struct BarabariLoadingState: View {
    let title: String

    var body: some View {
        VStack(spacing: BarabariSpacing.row) {
            ProgressView()
                .controlSize(.large)
            Text(LocalizedStringKey(title))
                .font(BarabariTypography.metadata)
                .foregroundStyle(BarabariColors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Entrance animation

private struct StaggeredAppear: ViewModifier {
    let index: Int
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : 18)
            .scaleEffect(isVisible || reduceMotion ? 1 : 0.98, anchor: .top)
            .onAppear {
                guard !isVisible else { return }
                if reduceMotion {
                    isVisible = true
                } else {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(Double(min(index, 8)) * 0.055)) {
                        isVisible = true
                    }
                }
            }
    }
}

extension View {
    /// Fades and lifts content into place, staggered by `index`.
    func staggeredAppear(_ index: Int = 0) -> some View {
        modifier(StaggeredAppear(index: index))
    }

    /// Standard screen chrome: grouped background, comfortable gutters.
    func barabariScreen() -> some View {
        self
            .padding(.horizontal, BarabariSpacing.screen)
            .padding(.bottom, BarabariSpacing.bottomContent)
    }
}

// MARK: - Activity presentation

extension ActivityEventKind {
    var title: String {
        switch self {
        case .groupCreated: "Group created"
        case .expenseCreated: "Expense added"
        case .expenseDeleted: "Expense removed"
        case .settlementRecorded: "Settlement recorded"
        case .memberJoined: "Member joined"
        case .memberRemoved: "Member removed"
        }
    }

    var systemImage: String {
        switch self {
        case .groupCreated: "sparkles"
        case .memberJoined: "person.crop.circle.badge.plus"
        case .expenseCreated: "receipt.fill"
        case .expenseDeleted: "trash.fill"
        case .settlementRecorded: "checkmark.seal.fill"
        case .memberRemoved: "person.crop.circle.badge.xmark"
        }
    }

    var tint: Color {
        switch self {
        case .groupCreated: Color(uiColor: UIColor(hex: 0x8B5CF6))
        case .memberJoined: Color(uiColor: UIColor(hex: 0x3B82F6))
        case .expenseCreated: Color(uiColor: UIColor(hex: 0xF59E0B))
        case .expenseDeleted, .memberRemoved: BarabariColors.danger
        case .settlementRecorded: BarabariColors.success
        }
    }
}

/// Inset divider that aligns with row text, like Settings.
struct RowDivider: View {
    var leading: CGFloat = 64

    var body: some View {
        Rectangle()
            .fill(BarabariColors.hairline)
            .frame(height: 1)
            .padding(.leading, leading)
    }
}

extension ExpenseCategory {
    var color: Color { Color(uiColor: UIColor(hex: hex)) }
}
