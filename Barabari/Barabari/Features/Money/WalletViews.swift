import SwiftUI

extension WalletKind {
    var color: Color { Color(uiColor: UIColor(hex: hex)) }
}

extension IncomeCategory {
    var color: Color { Color(uiColor: UIColor(hex: hex)) }
}

/// Compact wallet button for pickers.
struct WalletChip: View {
    let wallet: Wallet
    let balanceMinor: Int64
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: wallet.kind.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(wallet.kind.color.gradient, in: .rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 1) {
                Text(wallet.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BarabariColors.textPrimary)
                    .lineLimit(1)
                Text(AmountFormatter.string(minorUnits: balanceMinor, currencyCode: "PKR"))
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(BarabariColors.textSecondary)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 14)
        .padding(.vertical, 8)
        .background(BarabariColors.surface, in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isSelected ? wallet.kind.color : BarabariColors.hairline, lineWidth: isSelected ? 2 : 1)
        }
        .scaleEffect(isSelected ? 1.03 : 1)
    }
}
