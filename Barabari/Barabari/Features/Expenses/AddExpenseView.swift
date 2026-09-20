import SwiftUI

enum AddExpenseFocusedField: Hashable {
    case amount
    case title
    case exact(UUID)
}

enum AddExpenseScrollAnchor: Hashable {
    case exactShares
    case exactShare(UUID)
}

struct AddExpenseView: View {

    @ObservedObject private var viewModel: AddExpenseViewModel
    private let session: LedgerSession
    @FocusState private var focusedField: AddExpenseFocusedField?

    init(viewModel: AddExpenseViewModel, session: LedgerSession) {
        self.viewModel = viewModel
        self.session = session
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: BarabariSpacing.section) {
                    if let expense = viewModel.savedExpense {
                        confirmation(expense)
                    } else if viewModel.isLoading {
                        ProgressView("Loading your groups")
                            .frame(maxWidth: .infinity, minHeight: 240)
                    } else if viewModel.groups.isEmpty {
                        ContentUnavailableView(
                            "Create a group first",
                            systemImage: "person.2.fill",
                            description: Text("Expenses always belong to a shared group.")
                        )
                    } else {
                        form
                    }
                }
                .padding(BarabariSpacing.screen)
                .padding(.bottom, 92)
                .id(viewModel.savedExpense?.id)
            }
            .onChange(of: viewModel.splitSelection) { _, selection in
                guard selection == .exact else { return }
                scrollToExactShares(using: scrollProxy)
            }
            .onChange(of: focusedField) { _, field in
                guard case let .exact(memberID) = field else { return }
                scrollToExactShare(memberID, using: scrollProxy)
            }
        }
        .background(BarabariColors.background)
        .navigationTitle("Add expense")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .task { await viewModel.load() }
    }

    private func scrollToExactShares(using proxy: ScrollViewProxy) {
        Task { @MainActor in
            await Task.yield()
            withAnimation(.snappy) {
                proxy.scrollTo(AddExpenseScrollAnchor.exactShares, anchor: .center)
            }
        }
    }

    private func scrollToExactShare(_ memberID: UUID, using proxy: ScrollViewProxy) {
        Task { @MainActor in
            await Task.yield()
            withAnimation(.snappy) {
                proxy.scrollTo(AddExpenseScrollAnchor.exactShare(memberID), anchor: .center)
            }
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.section) {
            VStack(alignment: .leading, spacing: BarabariSpacing.compact) {
                Text("How much did you spend?")
                    .font(BarabariTypography.screenTitle)
                HStack(alignment: .firstTextBaseline, spacing: BarabariSpacing.compact) {
                    Text("PKR")
                        .font(BarabariTypography.sectionTitle)
                        .foregroundStyle(BarabariColors.textSecondary)
                    TextField("0", text: $viewModel.amountText)
                        .keyboardType(.decimalPad)
                        .font(BarabariTypography.amount(for: .hero))
                        .monospacedDigit()
                        .focused($focusedField, equals: .amount)
                        .accessibilityIdentifier("expense-amount")
                }
                .padding(BarabariSpacing.card)
                .background(BarabariColors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(BarabariColors.raised, lineWidth: 1)
                }
                if let validationMessage = viewModel.validationMessage,
                   validationMessage.hasPrefix("Enter an amount") {
                    validationLabel(validationMessage)
                }
            }

            VStack(alignment: .leading, spacing: BarabariSpacing.compact) {
                Text("What was it for?")
                    .font(BarabariTypography.sectionTitle)
                TextField("Dinner, groceries, petrol...", text: $viewModel.title)
                    .textInputAutocapitalization(.sentences)
                    .focused($focusedField, equals: .title)
                    .frame(minHeight: 52)
                    .padding(.horizontal, BarabariSpacing.row)
                    .background(BarabariColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityIdentifier("expense-title")
                if let validationMessage = viewModel.validationMessage,
                   validationMessage.hasPrefix("Add a short title") {
                    validationLabel(validationMessage)
                }
            }

            groupAndPayer
            participants
            ExpenseSplitEditorView(viewModel: viewModel, focusedField: $focusedField)
            ExpenseReviewView(viewModel: viewModel)

            if let validationMessage = viewModel.validationMessage,
               !validationMessage.hasPrefix("Enter an amount"),
               !validationMessage.hasPrefix("Add a short title"),
               !validationMessage.hasPrefix("Exact amounts") {
                validationLabel(validationMessage)
            }

            Button {
                focusedField = nil
                Task {
                    let didSave = await viewModel.save()
                    BarabariInteraction.trigger(didSave ? .success : .error)
                    if didSave {
                        session.markChanged()
                    }
                }
            } label: {
                Text(viewModel.isSaving ? "Saving..." : "Save expense")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(BarabariColors.onAccent)
            .background(BarabariColors.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .disabled(viewModel.isSaving)
            .accessibilityLabel("Save expense")
            .accessibilityHint("Saves this expense on this iPhone")
        }
    }

    private var groupAndPayer: some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.row) {
            Text("Expense details")
                .font(BarabariTypography.sectionTitle)
            selectionMenu(
                title: "Group",
                value: selectedGroupName,
                accessibilityLabel: selectedGroupName
            ) {
                ForEach(viewModel.groups) { group in
                    Button(group.name) { viewModel.selectGroup(group.id) }
                }
            }
            selectionMenu(
                title: "Paid by",
                value: viewModel.payerID.map(viewModel.memberName) ?? "Choose payer",
                accessibilityLabel: "Paid by"
            ) {
                ForEach(viewModel.members) { member in
                    Button(viewModel.memberName(for: member.userID)) { viewModel.payerID = member.userID }
                }
            }
        }
    }

    private var participants: some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.row) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Split with")
                    .font(BarabariTypography.sectionTitle)
                Text("Everyone selected gets a share.")
                    .font(BarabariTypography.metadata)
                    .foregroundStyle(BarabariColors.textSecondary)
            }
            ForEach(viewModel.members) { member in
                Button {
                    BarabariInteraction.trigger(.selection)
                    viewModel.toggleParticipant(member.userID)
                } label: {
                    HStack(spacing: BarabariSpacing.row) {
                        Image(systemName: viewModel.participantIDs.contains(member.userID) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(viewModel.participantIDs.contains(member.userID) ? BarabariColors.accent : BarabariColors.textSecondary)
                        Text(viewModel.memberName(for: member.userID))
                            .foregroundStyle(BarabariColors.textPrimary)
                        Spacer()
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Split with \(viewModel.memberName(for: member.userID))")
            }
        }
    }

    private func selectionMenu<MenuItems: View>(
        title: String,
        value: String,
        accessibilityLabel: String,
        @ViewBuilder menuItems: () -> MenuItems
    ) -> some View {
        Menu {
            menuItems()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(BarabariTypography.metadata)
                        .foregroundStyle(BarabariColors.textSecondary)
                    Text(value)
                        .font(BarabariTypography.body)
                        .foregroundStyle(BarabariColors.textPrimary)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BarabariColors.textSecondary)
            }
            .padding(BarabariSpacing.row)
            .frame(minHeight: 56)
            .background(BarabariColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var selectedGroupName: String {
        viewModel.groups.first(where: { $0.id == viewModel.selectedGroupID })?.name ?? "Choose group"
    }

    private func validationLabel(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.circle.fill")
            .font(BarabariTypography.metadata)
            .foregroundStyle(BarabariColors.danger)
    }

    private func confirmation(_ expense: Expense) -> some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.section) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(BarabariColors.success)
            VStack(alignment: .leading, spacing: BarabariSpacing.compact) {
                Text("Expense saved locally")
                    .font(BarabariTypography.screenTitle)
                Text("\(expense.title) is now part of this group’s ledger on this iPhone.")
                    .font(BarabariTypography.body)
                    .foregroundStyle(BarabariColors.textSecondary)
            }
            AmountText(
                minorUnits: expense.total.minorUnits,
                currencyCode: expense.total.currencyCode,
                style: .hero
            )
            PrimaryActionButton("Add another expense") {
                viewModel.addAnotherExpense()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 380, alignment: .center)
    }
}
