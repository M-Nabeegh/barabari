import SwiftUI

struct BarabariTabBar: View {
    @Binding private var selection: AppTab

    init(selection: Binding<AppTab>) {
        _selection = selection
    }

    var body: some View {
        SwiftUI.Group {
            if #available(iOS 26, *) {
                GlassEffectContainer(spacing: BarabariSpacing.compact) {
                    tabItems
                        .padding(.horizontal, BarabariSpacing.compact)
                        .padding(.vertical, 6)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
            } else {
                tabItems
                    .padding(.horizontal, BarabariSpacing.compact)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(BarabariColors.raised.opacity(0.8), lineWidth: 1)
                    }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main navigation")
    }

    private var tabItems: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: tab == .addExpense ? 19 : 16, weight: .semibold))
                        Text(tab.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(selection == tab ? BarabariColors.accent : BarabariColors.textSecondary)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    BarabariTabBar(selection: .constant(.home))
        .padding()
        .background(BarabariColors.background)
}
