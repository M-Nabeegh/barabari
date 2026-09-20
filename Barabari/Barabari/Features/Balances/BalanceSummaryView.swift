import SwiftUI

enum BalanceSummaryPresentation: Equatable {
    case youOwe(total: Money, transfers: [BalanceTransfer])
    case youAreOwed(total: Money, transfers: [BalanceTransfer])
    case settled

    static func make(summary: BalanceSummary, currentUserID: UUID) -> Self {
        guard let position = summary.netPosition(for: currentUserID) else {
            return .settled
        }

        if position.amount.minorUnits < 0 {
            let transfers = summary.transfers.filter { $0.fromUserID == currentUserID }
            return .youOwe(total: magnitude(of: position.amount), transfers: transfers)
        }

        if position.amount.minorUnits > 0 {
            let transfers = summary.transfers.filter { $0.toUserID == currentUserID }
            return .youAreOwed(total: position.amount, transfers: transfers)
        }

        return .settled
    }

    private static func magnitude(of amount: Money) -> Money {
        let minorUnits = amount.minorUnits == Int64.min ? Int64.max : -amount.minorUnits
        return Money(minorUnits: minorUnits, currencyCode: amount.currencyCode)
    }
}

struct BalanceSummaryView: View {
    let summary: BalanceSummary
    let currentUserID: UUID
    let selectTransfer: (BalanceTransfer) -> Void

    private var presentation: BalanceSummaryPresentation {
        BalanceSummaryPresentation.make(summary: summary, currentUserID: currentUserID)
    }

    var body: some View {
        switch presentation {
        case let .youOwe(total, transfers):
            youOwe(total: total, transfers: transfers)
        case let .youAreOwed(total, transfers):
            youAreOwed(total: total, transfers: transfers)
        case .settled:
            settled
        }
    }

    @ViewBuilder
    private func youOwe(total: Money, transfers: [BalanceTransfer]) -> some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.row) {
            if let onlyTransfer = transfers.only {
                Button {
                    selectTransfer(onlyTransfer)
                } label: {
                    summaryCard(
                        title: "You owe",
                        subtitle: "Tap to record a payment",
                        amount: total,
                        color: BarabariColors.danger,
                        symbol: "arrow.up.right.circle.fill"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("You owe")
                .accessibilityValue(AmountFormatter.string(minorUnits: total.minorUnits, currencyCode: total.currencyCode))
                .accessibilityHint("Record a settlement")
            } else {
                summaryCard(
                    title: "You owe",
                    subtitle: "Record each payment below",
                    amount: total,
                    color: BarabariColors.danger,
                    symbol: "arrow.up.right.circle.fill"
                )
                .accessibilityIdentifier("You owe")
                .accessibilityValue(AmountFormatter.string(minorUnits: total.minorUnits, currencyCode: total.currencyCode))

                ForEach(transfers.indices, id: \.self) { index in
                    settlementRow(transfers[index])
                }
            }
        }
    }

    private func youAreOwed(total: Money, transfers: [BalanceTransfer]) -> some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.row) {
            summaryCard(
                title: "You are owed",
                subtitle: "Waiting for recorded payments",
                amount: total,
                color: BarabariColors.success,
                symbol: "arrow.down.left.circle.fill"
            )
            .accessibilityIdentifier("You are owed")
            .accessibilityValue(AmountFormatter.string(minorUnits: total.minorUnits, currencyCode: total.currencyCode))

            ForEach(transfers.indices, id: \.self) { index in
                incomingTransferRow(transfers[index])
            }
        }
    }

    private var settled: some View {
        BarabariCard {
            HStack(spacing: BarabariSpacing.row) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(BarabariColors.success)
                VStack(alignment: .leading, spacing: 4) {
                    Text("You are settled")
                        .font(BarabariTypography.sectionTitle)
                    Text("You are settled up.")
                        .font(BarabariTypography.body)
                        .foregroundStyle(BarabariColors.textSecondary)
                }
                Spacer()
            }
        }
        .accessibilityIdentifier("Settled")
    }

    private func summaryCard(
        title: String,
        subtitle: String,
        amount: Money,
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
                AmountText(minorUnits: amount.minorUnits, currencyCode: amount.currencyCode, style: .body)
                    .foregroundStyle(color)
            }
        }
    }

    private func settlementRow(_ transfer: BalanceTransfer) -> some View {
        Button {
            selectTransfer(transfer)
        } label: {
            transferRow(label: "Record payment", amount: transfer.amount, symbol: "arrow.up.right")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(transferAccessibilityIdentifier(transfer, prefix: "settlement-transfer"))
        .accessibilityValue(AmountFormatter.string(minorUnits: transfer.amount.minorUnits, currencyCode: transfer.amount.currencyCode))
        .accessibilityHint("Record a settlement")
    }

    private func incomingTransferRow(_ transfer: BalanceTransfer) -> some View {
        transferRow(label: "Payment expected", amount: transfer.amount, symbol: "arrow.down.left")
            .accessibilityIdentifier(transferAccessibilityIdentifier(transfer, prefix: "incoming-transfer"))
            .accessibilityValue(AmountFormatter.string(minorUnits: transfer.amount.minorUnits, currencyCode: transfer.amount.currencyCode))
    }

    private func transferRow(label: String, amount: Money, symbol: String) -> some View {
        HStack(spacing: BarabariSpacing.row) {
            Image(systemName: symbol)
                .foregroundStyle(BarabariColors.textSecondary)
            Text(label)
                .font(BarabariTypography.body)
            Spacer()
            AmountText(minorUnits: amount.minorUnits, currencyCode: amount.currencyCode, style: .compact)
        }
        .padding(.horizontal, BarabariSpacing.row)
        .padding(.vertical, BarabariSpacing.compact)
        .background(BarabariColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func transferAccessibilityIdentifier(_ transfer: BalanceTransfer, prefix: String) -> String {
        "\(prefix)-\(transfer.fromUserID.uuidString)-\(transfer.toUserID.uuidString)"
    }
}

private extension Array {
    var only: Element? { count == 1 ? first : nil }
}
