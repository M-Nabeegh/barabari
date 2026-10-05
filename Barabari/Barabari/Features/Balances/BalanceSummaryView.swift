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
    var name: (UUID) -> String = { _ in "Group member" }
    var shareTransfer: ((BalanceTransfer) -> Void)?
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
                    BarabariInteraction.trigger(.selection)
                    selectTransfer(onlyTransfer)
                } label: {
                    summaryCard(
                        title: "You owe",
                        subtitle: "Pay \(name(onlyTransfer.toUserID))",
                        amount: total,
                        color: BarabariColors.danger,
                        symbol: "arrow.up.right.circle.fill"
                    )
                }
                .buttonStyle(.pressable)
                .barabariHitTarget()
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
                subtitle: "Waiting on payments",
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
        HStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(BarabariColors.success.gradient)
                .symbolEffect(.bounce, options: .nonRepeating)
            VStack(alignment: .leading, spacing: 2) {
                Text("You are settled")
                    .font(BarabariTypography.headline)
                Text("You are settled up.")
                    .font(BarabariTypography.metadata)
                    .foregroundStyle(BarabariColors.textSecondary)
            }
            Spacer()
        }
        .padding(18)
        .background(BarabariColors.success.opacity(0.12), in: .rect(cornerRadius: BarabariSpacing.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: BarabariSpacing.cardRadius, style: .continuous)
                .strokeBorder(BarabariColors.success.opacity(0.25), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("Settled")
    }

    private func summaryCard(
        title: String,
        subtitle: String,
        amount: Money,
        color: Color,
        symbol: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(color)
                Text(LocalizedStringKey(title))
                    .font(BarabariTypography.headline)
                    .foregroundStyle(BarabariColors.textPrimary)
                Spacer()
                Text(LocalizedStringKey(subtitle))
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(BarabariColors.textSecondary)
            }
            HeroAmount(minorUnits: amount.minorUnits, currencyCode: amount.currencyCode, size: 34, color: color)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.11), in: .rect(cornerRadius: BarabariSpacing.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: BarabariSpacing.cardRadius, style: .continuous)
                .strokeBorder(color.opacity(0.25), lineWidth: 1)
        }
        .contentShape(.rect(cornerRadius: BarabariSpacing.cardRadius))
    }

    private func settlementRow(_ transfer: BalanceTransfer) -> some View {
        Button {
            BarabariInteraction.trigger(.selection)
            selectTransfer(transfer)
        } label: {
            transferRow(label: "Pay \(name(transfer.toUserID))", personID: transfer.toUserID, amount: transfer.amount, transfer: transfer)
        }
        .buttonStyle(.pressable)
        .barabariHitTarget()
        .accessibilityIdentifier(transferAccessibilityIdentifier(transfer, prefix: "settlement-transfer"))
        .accessibilityValue(AmountFormatter.string(minorUnits: transfer.amount.minorUnits, currencyCode: transfer.amount.currencyCode))
        .accessibilityHint("Record a settlement")
    }

    private func incomingTransferRow(_ transfer: BalanceTransfer) -> some View {
        transferRow(label: "\(name(transfer.fromUserID)) owes you", personID: transfer.fromUserID, amount: transfer.amount, transfer: transfer)
            .accessibilityIdentifier(transferAccessibilityIdentifier(transfer, prefix: "incoming-transfer"))
            .accessibilityValue(AmountFormatter.string(minorUnits: transfer.amount.minorUnits, currencyCode: transfer.amount.currencyCode))
    }

    private func transferRow(label: LocalizedStringKey, personID: UUID, amount: Money, transfer: BalanceTransfer) -> some View {
        HStack(spacing: 12) {
            MemberAvatar(name: name(personID), seed: personID, size: 36)
            Text(label)
                .font(BarabariTypography.body.weight(.medium))
                .foregroundStyle(BarabariColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
            Spacer()
            AmountText(minorUnits: amount.minorUnits, currencyCode: amount.currencyCode, style: .compact)
                .foregroundStyle(BarabariColors.textPrimary)
                .lineLimit(1)
                .fixedSize()
            if let shareTransfer {
                Button {
                    BarabariInteraction.trigger(.selection)
                    shareTransfer(transfer)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BarabariColors.accent)
                        .frame(width: 36, height: 36)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share reminder")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 56)
        .background(BarabariColors.surface, in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(BarabariColors.hairline, lineWidth: 1)
        }
        .contentShape(.rect(cornerRadius: 20))
    }

    private func transferAccessibilityIdentifier(_ transfer: BalanceTransfer, prefix: String) -> String {
        "\(prefix)-\(transfer.fromUserID.uuidString)-\(transfer.toUserID.uuidString)"
    }
}

extension BalanceTransfer: Identifiable {
    var id: String { "\(fromUserID.uuidString)-\(toUserID.uuidString)" }
}

private extension Array {
    var only: Element? { count == 1 ? first : nil }
}
