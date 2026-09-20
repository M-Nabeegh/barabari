import SwiftUI

struct BalanceSummaryView: View {
    let summary: BalanceSummary
    let currentUserID: UUID
    let selectTransfer: (BalanceTransfer) -> Void

    var body: some View {
        if let transfer = summary.transfers.first(where: { $0.fromUserID == currentUserID }) {
            Button {
                selectTransfer(transfer)
            } label: {
                debtCard(
                    title: "You owe",
                    subtitle: "Tap to record a payment",
                    transfer: transfer,
                    color: BarabariColors.danger,
                    symbol: "arrow.up.right.circle.fill"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("You owe")
            .accessibilityHint("Record a settlement")
        } else if let transfer = summary.transfers.first(where: { $0.toUserID == currentUserID }) {
            debtCard(
                title: "You are owed",
                subtitle: "Waiting for a recorded payment",
                transfer: transfer,
                color: BarabariColors.success,
                symbol: "arrow.down.left.circle.fill"
            )
        } else {
            BarabariCard {
                HStack(spacing: BarabariSpacing.row) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(BarabariColors.success)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Settled")
                            .font(BarabariTypography.sectionTitle)
                        Text("Everyone is settled up.")
                            .font(BarabariTypography.body)
                            .foregroundStyle(BarabariColors.textSecondary)
                    }
                    Spacer()
                }
            }
            .accessibilityIdentifier("Settled")
        }
    }

    private func debtCard(
        title: String,
        subtitle: String,
        transfer: BalanceTransfer,
        color: Color,
        symbol: String
    ) -> some View {
        BarabariCard {
            HStack(spacing: BarabariSpacing.row) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(BarabariTypography.sectionTitle)
                    Text(subtitle)
                        .font(BarabariTypography.metadata)
                        .foregroundStyle(BarabariColors.textSecondary)
                }
                Spacer()
                AmountText(
                    minorUnits: transfer.amount.minorUnits,
                    currencyCode: transfer.amount.currencyCode,
                    style: .body
                )
                .foregroundStyle(color)
            }
        }
    }
}
