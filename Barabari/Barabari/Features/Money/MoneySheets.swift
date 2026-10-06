import SwiftUI

// MARK: - Wallet editor

struct WalletEditorSheet: View {
    @ObservedObject var finance: PersonalFinanceStore
    let wallet: Wallet?

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kind: WalletKind = .bank
    @State private var opening = ""
    @State private var error: String?
    @State private var confirmRemove = false
    @FocusState private var focusedField: Field?

    private enum Field { case name, balance }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BarabariSpacing.section) {
                    WalletCard(wallet: Wallet(id: wallet?.id ?? UUID(), name: name.isEmpty ? kind.title : name, kind: kind,
                                              openingMinor: 0, createdAt: .now, archivedAt: nil),
                               balanceMinor: previewBalance)
                        .scaleEffect(1.15)
                        .padding(.vertical, 18)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: kind)

                    TextField("Name (e.g. Meezan, HBL)", text: $name)
                        .font(.body.weight(.medium))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .balance }
                        .frame(minHeight: 52)
                        .padding(.horizontal, 18)
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .accessibilityIdentifier("wallet-name")

                    VStack(alignment: .leading, spacing: BarabariSpacing.row) {
                        SectionHeader("Type")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                            ForEach(WalletKind.allCases) { option in
                                let isSelected = kind == option
                                Button {
                                    BarabariInteraction.trigger(.selection)
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        if WalletKind.allCases.map(\.title).contains(name) { name = "" }
                                        kind = option
                                    }
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: option.systemImage)
                                            .font(.system(size: 18, weight: .semibold))
                                        Text(LocalizedStringKey(option.title))
                                            .font(.caption.weight(.semibold))
                                    }
                                    .foregroundStyle(isSelected ? .white : BarabariColors.textPrimary)
                                    .frame(maxWidth: .infinity, minHeight: 68)
                                    .background {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(isSelected ? AnyShapeStyle(option.color.gradient) : AnyShapeStyle(BarabariColors.surface))
                                    }
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .strokeBorder(isSelected ? .clear : BarabariColors.hairline, lineWidth: 1)
                                    }
                                }
                                .buttonStyle(.pressable)
                                .accessibilityAddTraits(isSelected ? .isSelected : [])
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: BarabariSpacing.row) {
                        SectionHeader(wallet == nil ? "Current balance" : "Starting balance")
                        HStack(spacing: 6) {
                            Text("Rs")
                                .foregroundStyle(BarabariColors.textSecondary)
                            TextField("0", text: $opening)
                                .keyboardType(.decimalPad)
                                .font(.system(.title3, design: .rounded, weight: .semibold))
                                .focused($focusedField, equals: .balance)
                                .accessibilityIdentifier("wallet-opening")
                        }
                        .padding(.horizontal, 18)
                        .frame(minHeight: 54)
                        .background(BarabariColors.surface, in: .rect(cornerRadius: 18))
                        Text("What’s in it right now. Logged income and spending adjust it from here.")
                            .font(BarabariTypography.metadata)
                            .foregroundStyle(BarabariColors.textSecondary)
                            .padding(.horizontal, 4)
                    }

                    if let error {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(BarabariTypography.metadata.weight(.medium))
                            .foregroundStyle(BarabariColors.danger)
                    }

                    PrimaryActionButton(wallet == nil ? "Add wallet" : "Save", action: save)
                        .accessibilityIdentifier("wallet-save")

                    if wallet != nil && finance.activeWallets.count > 1 {
                        Button("Remove wallet", role: .destructive) { confirmRemove = true }
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(.horizontal, BarabariSpacing.screen)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(wallet == nil ? "New wallet" : "Edit wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .confirmationDialog("Remove \(wallet?.name ?? "wallet")?", isPresented: $confirmRemove, titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    if let wallet { try? finance.archiveWallet(id: wallet.id) }
                    dismiss()
                }
            } message: {
                Text("It disappears from your wallets. Its past transactions stay in your history.")
            }
        }
        .presentationDetents([.large])
        .onAppear {
            if let wallet {
                name = wallet.name
                kind = wallet.kind
                opening = wallet.openingMinor == 0 ? "" : Self.text(for: wallet.openingMinor)
            }
        }
    }

    private var openingMinor: Int64? {
        let trimmed = opening.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "")
        if trimmed.isEmpty { return 0 }
        guard let value = Decimal(string: trimmed), value >= 0 else { return nil }
        return NSDecimalNumber(decimal: value * 100).int64Value
    }

    private var previewBalance: Int64 {
        let base = openingMinor ?? 0
        guard let wallet else { return base }
        return finance.balance(of: wallet.id) - wallet.openingMinor + base
    }

    private func save() {
        guard let openingMinor else {
            error = "Enter the balance as a number."
            return
        }
        do {
            if var wallet {
                wallet.name = name
                wallet.kind = kind
                wallet.openingMinor = openingMinor
                try finance.updateWallet(wallet)
            } else {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                try finance.addWallet(name: trimmed.isEmpty ? kind.title : trimmed, kind: kind, openingMinor: openingMinor)
            }
            BarabariInteraction.trigger(.success)
            dismiss()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "We couldn’t save this wallet."
            BarabariInteraction.trigger(.error)
        }
    }

    static func text(for minor: Int64) -> String {
        minor % 100 == 0 ? "\(minor / 100)" : String(format: "%lld.%02lld", minor / 100, abs(minor % 100))
    }
}

// MARK: - Budgets

struct BudgetsSheet: View {
    @ObservedObject var finance: PersonalFinanceStore
    let month: MonthPeriod
    let groupShares: [ExpenseCategory: Int64]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BarabariSpacing.row) {
                    Text("Set a monthly limit for any category. Your share of group expenses counts toward it.")
                        .font(BarabariTypography.metadata)
                        .foregroundStyle(BarabariColors.textSecondary)
                        .padding(.horizontal, 4)
                    BarabariCard(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(ExpenseCategory.allCases.enumerated()), id: \.element) { index, category in
                                if index > 0 { RowDivider(leading: 64) }
                                NavigationLink(value: category) {
                                    row(category)
                                }
                                .buttonStyle(.pressable)
                                .accessibilityIdentifier("budget-\(category.rawValue)")
                            }
                        }
                    }
                }
                .padding(.horizontal, BarabariSpacing.screen)
                .padding(.bottom, 30)
            }
            .background(BarabariColors.background)
            .navigationTitle("Budgets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
            .navigationDestination(for: ExpenseCategory.self) { category in
                BudgetEditor(finance: finance, category: category)
            }
        }
        .presentationDetents([.large])
    }

    private func row(_ category: ExpenseCategory) -> some View {
        let spent = finance.spending(in: month, groupShares: groupShares)[category] ?? 0
        let limit = finance.budgets[category]
        return HStack(spacing: 14) {
            IconTile(systemImage: category.systemImage, color: category.color, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(category.title))
                    .font(BarabariTypography.body.weight(.medium))
                    .foregroundStyle(BarabariColors.textPrimary)
                Text("Spent \(AmountFormatter.string(minorUnits: spent, currencyCode: "PKR")) this month")
                    .font(.caption)
                    .foregroundStyle(BarabariColors.textSecondary)
            }
            Spacer()
            Text(limit.map { AmountFormatter.string(minorUnits: $0, currencyCode: "PKR") } ?? "No limit")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(limit == nil ? BarabariColors.textTertiary : BarabariColors.accent)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(BarabariColors.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private struct BudgetEditor: View {
    @ObservedObject var finance: PersonalFinanceStore
    let category: ExpenseCategory

    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var shake = 0

    var body: some View {
        VStack(spacing: 0) {
            IconTile(systemImage: category.systemImage, color: category.color, size: 56)
                .padding(.top, 12)
            Spacer(minLength: 8)
            AmountEntryField(text: $amount, prompt: "Monthly limit for \(category.title)",
                             accessibilityIdentifier: "budget-amount", size: 60, shakeTrigger: shake)
            Spacer(minLength: 8)
            AmountKeypad(text: $amount, identifierPrefix: "keypad")
                .padding(.horizontal, 8)
            PrimaryActionButton("Save budget") {
                guard let value = Decimal(string: amount), value > 0 else {
                    shake += 1
                    BarabariInteraction.trigger(.error)
                    return
                }
                try? finance.setBudget(NSDecimalNumber(decimal: value * 100).int64Value, for: category)
                BarabariInteraction.trigger(.success)
                dismiss()
            }
            .padding(.top, 14)
            .accessibilityIdentifier("budget-save")
            if finance.budgets[category] != nil {
                Button("Remove budget", role: .destructive) {
                    try? finance.setBudget(nil, for: category)
                    dismiss()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.top, 10)
            }
        }
        .padding(.horizontal, BarabariSpacing.screen)
        .padding(.bottom, 12)
        .navigationTitle(LocalizedStringKey(category.title))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let limit = finance.budgets[category] { amount = WalletEditorSheet.text(for: limit) }
        }
    }
}

// MARK: - Transaction detail

struct TransactionDetailSheet: View {
    @ObservedObject var finance: PersonalFinanceStore
    let transaction: MoneyTransaction

    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    private var icon: (String, Color, String) {
        if let category = transaction.expenseCategory { return (category.systemImage, category.color, category.title) }
        let income = transaction.incomeCategory ?? .other
        return (income.systemImage, income.color, income.title)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BarabariSpacing.section) {
                    ReceiptHeader(systemImage: icon.0, tint: icon.1, title: transaction.title,
                                  amount: Money(minorUnits: transaction.amountMinor, currencyCode: "PKR"),
                                  date: transaction.occurredAt)
                    BarabariCard(padding: 0) {
                        VStack(spacing: 0) {
                            detailRow("Type", transaction.kind == .income ? "Income" : "Expense")
                            RowDivider(leading: 16)
                            detailRow("Category", icon.2)
                            RowDivider(leading: 16)
                            detailRow(transaction.kind == .income ? "Into" : "Paid from",
                                      finance.wallet(id: transaction.walletID)?.name ?? "Removed wallet")
                        }
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("delete-transaction")
                }
                .padding(.horizontal, BarabariSpacing.screen)
                .padding(.bottom, 30)
            }
            .navigationTitle(transaction.kind == .income ? "Income" : "Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", systemImage: "xmark") { dismiss() }
                }
            }
            .confirmationDialog("Delete this \(transaction.kind == .income ? "income" : "expense")?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    try? finance.deleteTransaction(id: transaction.id)
                    BarabariInteraction.trigger(.success)
                    dismiss()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func detailRow(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(BarabariColors.textSecondary)
            Spacer()
            Text(value).font(BarabariTypography.body.weight(.medium))
        }
        .padding(16)
    }
}
