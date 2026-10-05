import SwiftUI

struct ExpenseDetailView: View {
    let expense: Expense
    var currentUserID: UUID?
    @ObservedObject private var metadata = LedgerMetadata.shared

    var body: some View {
        ScrollView {
            VStack(spacing: BarabariSpacing.section) {
                ReceiptHeader(
                    systemImage: metadata.category(for: expense).systemImage,
                    tint: metadata.category(for: expense).color,
                    title: expense.title,
                    amount: expense.total,
                    date: expense.occurredAt
                )

                Label(LocalizedStringKey(metadata.category(for: expense).title), systemImage: metadata.category(for: expense).systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(metadata.category(for: expense).color)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(metadata.category(for: expense).color.opacity(0.14), in: .capsule)

                BarabariCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(expense.splits.enumerated()), id: \.element.userID) { index, split in
                            if index > 0 { RowDivider(leading: 62) }
                            HStack(spacing: 12) {
                                MemberAvatar(name: name(for: split.userID, index: index), seed: split.userID, size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(name(for: split.userID, index: index))
                                        .font(BarabariTypography.body.weight(.medium))
                                    if split.userID == expense.paidByUserID {
                                        Text("Paid the bill")
                                            .font(.caption)
                                            .foregroundStyle(BarabariColors.accent)
                                    }
                                }
                                Spacer()
                                AmountText(minorUnits: split.amount.minorUnits, currencyCode: split.amount.currencyCode, style: .body)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                    }
                }

                if let note = expense.note, !note.isEmpty {
                    BarabariCard {
                        Label(note, systemImage: "text.quote")
                            .font(BarabariTypography.body)
                            .foregroundStyle(BarabariColors.textSecondary)
                    }
                }

                Label("Saved locally on this iPhone. This demo does not sync to a server.", systemImage: "lock.fill")
                    .font(BarabariTypography.metadata)
                    .foregroundStyle(BarabariColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .barabariScreen()
        }
        .background(BarabariColors.background)
        .navigationTitle("Expense")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func name(for userID: UUID, index: Int) -> String {
        metadata.displayName(for: userID, currentUserID: currentUserID ?? UUID(), fallback: "Member \(index + 1)")
    }
}

/// Centered receipt-style header shared by expense, settlement and event details.
struct ReceiptHeader: View {
    let systemImage: String
    let tint: Color
    let title: String
    let amount: Money?
    let date: Date

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 76, height: 76)
                .background(tint.opacity(0.14), in: .circle)
                .scaleEffect(appeared ? 1 : 0.5)
                .symbolEffect(.bounce, value: appeared)
            Text(LocalizedStringKey(title))
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
            if let amount {
                HeroAmount(minorUnits: amount.minorUnits, currencyCode: amount.currencyCode, size: 44, color: BarabariColors.textPrimary)
            }
            Text(date.formatted(date: .complete, time: .omitted))
                .font(BarabariTypography.metadata)
                .foregroundStyle(BarabariColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appeared = true }
        }
    }
}
