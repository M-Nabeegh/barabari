import SwiftUI

struct BarabariCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(BarabariSpacing.card)
            .background(BarabariColors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(BarabariColors.raised.opacity(0.8), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
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
