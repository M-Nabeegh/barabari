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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var amountMorph
    @State private var step: Step = .amount
    @State private var shakeAmount = 0

    private enum Step {
        case amount
        case details
    }

    init(viewModel: AddExpenseViewModel, session: LedgerSession) {
        self.viewModel = viewModel
        self.session = session
    }

    var body: some View {
        SwiftUI.Group {
            if let expense = viewModel.savedExpense {
                ScrollView {
                    confirmation(expense)
                        .barabariScreen()
                }
                .id(expense.id)
            } else if let personal = viewModel.savedPersonal {
                ScrollView {
                    personalConfirmation(personal)
                        .barabariScreen()
                }
                .id(personal.id)
            } else if viewModel.isLoading {
                BarabariLoadingState(title: "Loading your groups")
            } else if viewModel.groups.isEmpty && !viewModel.isPersonal {
                ScrollView {
                    BarabariEmptyState(
                        systemImage: "person.2.fill",
                        title: "Create a group first",
                        message: "Expenses always belong to a shared group."
                    )
                    .barabariScreen()
                }
            } else if step == .amount {
                amountStep
                    .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
            } else if viewModel.isPersonal {
                personalDetailsStep
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            } else {
                detailsStep
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BarabariColors.background)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if step == .details && viewModel.savedExpense == nil && viewModel.savedPersonal == nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Amount", systemImage: "chevron.backward") {
                        focusedField = nil
                        go(to: .amount)
                    }
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .task { await viewModel.load() }
        .onChange(of: viewModel.savedExpense?.id) { _, id in
            if id == nil { go(to: .amount) }
        }
        .onChange(of: viewModel.savedPersonal?.id) { _, id in
            if id == nil { go(to: .amount) }
        }
    }

    private var navigationTitle: LocalizedStringKey {
        if step == .amount { return "Add expense" }
        if viewModel.isPersonal { return viewModel.personalKind == .income ? "New income" : "Just me" }
        return "New expense"
    }

    private func go(to newStep: Step) {
        if reduceMotion {
            step = newStep
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { step = newStep }
        }
    }

    // MARK: Step 1 — amount

    private var amountStep: some View {
        VStack(spacing: 0) {
            groupPill
                .padding(.top, 8)

            Spacer(minLength: 12)

            AmountEntryField(
                text: $viewModel.amountText,
                accessibilityIdentifier: "expense-amount",
                size: 72,
                shakeTrigger: shakeAmount
            )
            .matchedGeometryEffect(id: "amount", in: amountMorph)

            if let validationMessage = viewModel.validationMessage,
               validationMessage.hasPrefix("Enter an amount") {
                validationLabel(validationMessage)
                    .padding(.top, 8)
            }

            Spacer(minLength: 12)

            AmountKeypad(text: $viewModel.amountText)
                .padding(.horizontal, 8)

            Button {
                guard (Double(viewModel.amountText) ?? 0) > 0 else {
                    shakeAmount += 1
                    BarabariInteraction.trigger(.error)
                    return
                }
                BarabariInteraction.trigger(.selection)
                viewModel.validationMessage = nil
                go(to: .details)
            } label: {
                Text("Continue")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .contentShape(Capsule())
            }
            .buttonStyle(BarabariPrimaryButtonStyle())
            .opacity((Double(viewModel.amountText) ?? 0) > 0 ? 1 : 0.5)
            .animation(.easeOut(duration: 0.2), value: viewModel.amountText.isEmpty)
            .padding(.top, 14)
            .accessibilityIdentifier("expense-continue")
        }
        .padding(.horizontal, BarabariSpacing.screen)
        .padding(.bottom, 12)
    }

    private var groupPill: some View {
        Menu {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { viewModel.choosePersonal() }
            } label: {
                Label("Just me", systemImage: "person.crop.circle")
            }
            if !viewModel.groups.isEmpty {
                Section("Split with a group") {
                    ForEach(viewModel.groups) { group in
                        Button(group.name) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { viewModel.selectGroup(group.id) }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isPersonal {
                    MemberAvatar(name: "You", seed: AppEnvironment.demoUserID, size: 24)
                } else {
                    GroupAvatar(name: selectedGroupName, seed: viewModel.selectedGroupID ?? UUID(), size: 24)
                }
                Text(viewModel.isPersonal ? "Just me" : selectedGroupName)
                    .contentTransition(.interpolate)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BarabariColors.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(BarabariColors.textSecondary)
            }
            .padding(.leading, 6)
            .padding(.trailing, 14)
            .padding(.vertical, 6)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .accessibilityLabel(viewModel.isPersonal ? "Just me" : "Group, \(selectedGroupName)")
        .accessibilityIdentifier("expense-target")
    }

    // MARK: Step 2 — personal details

    private var personalDetailsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BarabariSpacing.section) {
                Button {
                    go(to: .amount)
                } label: {
                    VStack(spacing: 4) {
                        HeroAmount(
                            minorUnits: Int64(((Double(viewModel.amountText) ?? 0) * 100).rounded()),
                            size: 44,
                            color: viewModel.personalKind == .income ? BarabariColors.success : BarabariColors.textPrimary
                        )
                        Label("Tap to edit", systemImage: "pencil")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(BarabariColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.pressable)
                .matchedGeometryEffect(id: "amount", in: amountMorph)
                .accessibilityLabel("Edit amount")

                kindToggle
                    .staggeredAppear(0)

                TextField(viewModel.personalKind == .income ? "Where did it come from?" : "What was it for?", text: $viewModel.title)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .focused($focusedField, equals: .title)
                    .font(.body.weight(.medium))
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 50)
                    .padding(.horizontal, 18)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .accessibilityIdentifier("expense-title")
                    .staggeredAppear(1)

                SwiftUI.Group {
                    if viewModel.personalKind == .expense {
                        categoryPicker
                    } else {
                        incomePicker
                    }
                }
                .staggeredAppear(2)

                walletPicker
                    .staggeredAppear(3)

                BarabariCard(padding: 0) {
                    DatePicker(selection: $viewModel.personalDate, in: ...Date.now.addingTimeInterval(86_400 * 365), displayedComponents: .date) {
                        Label("Date", systemImage: "calendar")
                            .font(BarabariTypography.body)
                    }
                    .tint(BarabariColors.accent)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 56)
                }
                .staggeredAppear(4)

                if let validationMessage = viewModel.validationMessage {
                    validationLabel(validationMessage)
                }

                Button {
                    focusedField = nil
                    Task {
                        let didSave = await viewModel.savePersonal()
                        BarabariInteraction.trigger(didSave ? .success : .error)
                        if didSave { session.markChanged() }
                    }
                } label: {
                    Text(viewModel.personalKind == .income ? "Save income" : "Save expense")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .contentShape(Capsule())
                }
                .buttonStyle(BarabariPrimaryButtonStyle())
                .disabled(viewModel.isSaving)
                .accessibilityIdentifier("save-personal")
            }
            .padding(.top, 8)
            .barabariScreen()
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private var kindToggle: some View {
        HStack(spacing: 4) {
            ForEach(TransactionKind.allCases) { kind in
                let isSelected = viewModel.personalKind == kind
                Button {
                    BarabariInteraction.trigger(.selection)
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { viewModel.personalKind = kind }
                } label: {
                    Label(LocalizedStringKey(kind.title), systemImage: kind == .expense ? "arrow.up.right" : "arrow.down.left")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? BarabariColors.onAccent : BarabariColors.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(kind == .income ? BarabariColors.success.gradient : BarabariColors.accent.gradient)
                                    .matchedGeometryEffect(id: "kind-segment", in: amountMorph)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .glassEffect(.regular, in: .capsule)
    }

    private var incomePicker: some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.row) {
            SectionHeader("Category")
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(IncomeCategory.allCases) { category in
                        let isSelected = viewModel.incomeCategory == category
                        let color = Color(uiColor: UIColor(hex: category.hex))
                        Button {
                            BarabariInteraction.trigger(.selection)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { viewModel.chooseIncomeCategory(category) }
                        } label: {
                            Label(LocalizedStringKey(category.title), systemImage: category.systemImage)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isSelected ? .white : BarabariColors.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background {
                                    Capsule().fill(isSelected ? AnyShapeStyle(color.gradient) : AnyShapeStyle(BarabariColors.surface))
                                }
                                .overlay { Capsule().strokeBorder(isSelected ? .clear : BarabariColors.hairline, lineWidth: 1) }
                        }
                        .buttonStyle(.pressable)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }

    private var walletPicker: some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.row) {
            SectionHeader(viewModel.personalKind == .income ? "Into" : "Paid from")
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(viewModel.wallets) { wallet in
                        let isSelected = viewModel.personalWalletID == wallet.id
                        Button {
                            BarabariInteraction.trigger(.selection)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { viewModel.personalWalletID = wallet.id }
                        } label: {
                            WalletChip(wallet: wallet, balanceMinor: viewModel.walletBalance(wallet.id), isSelected: isSelected)
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel(wallet.name)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }

    // MARK: Step 2 — details

    private var detailsStep: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: BarabariSpacing.section) {
                    Button {
                        go(to: .amount)
                    } label: {
                        VStack(spacing: 4) {
                            HeroAmount(
                                minorUnits: Int64(((Double(viewModel.amountText) ?? 0) * 100).rounded()),
                                size: 44,
                                color: BarabariColors.textPrimary
                            )
                            Label("Tap to edit", systemImage: "pencil")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(BarabariColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.pressable)
                    .matchedGeometryEffect(id: "amount", in: amountMorph)
                    .accessibilityLabel("Edit amount")

                    VStack(alignment: .leading, spacing: BarabariSpacing.compact) {
                        TextField("What was it for?", text: $viewModel.title)
                            .textInputAutocapitalization(.sentences)
                            .submitLabel(.done)
                            .focused($focusedField, equals: .title)
                            .font(.body.weight(.medium))
                            .multilineTextAlignment(.center)
                            .frame(minHeight: 50)
                            .padding(.horizontal, 18)
                            .glassEffect(.regular.interactive(), in: .capsule)
                            .accessibilityIdentifier("expense-title")
                        if let validationMessage = viewModel.validationMessage,
                           validationMessage.hasPrefix("Add a short title") {
                            validationLabel(validationMessage)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .staggeredAppear(0)

                    categoryPicker
                        .staggeredAppear(1)
                    groupAndPayer
                        .staggeredAppear(2)
                    participants
                        .staggeredAppear(3)
                    ExpenseSplitEditorView(viewModel: viewModel, focusedField: $focusedField)
                        .staggeredAppear(4)
                    ExpenseReviewView(viewModel: viewModel)
                        .staggeredAppear(5)

                    if let validationMessage = viewModel.validationMessage,
                       !validationMessage.hasPrefix("Add a short title"),
                       !AddExpenseViewModel.isSplitValidation(validationMessage) {
                        validationLabel(validationMessage)
                    }

                    saveButton
                }
                .padding(.top, 8)
                .barabariScreen()
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.splitSelection) { _, selection in
                guard selection != .equal else { return }
                scroll(to: AddExpenseScrollAnchor.exactShares, using: scrollProxy)
            }
            .onChange(of: focusedField) { _, field in
                guard case let .exact(memberID) = field else { return }
                scroll(to: AddExpenseScrollAnchor.exactShare(memberID), using: scrollProxy)
            }
        }
    }

    private func scroll(to anchor: AddExpenseScrollAnchor, using proxy: ScrollViewProxy) {
        Task { @MainActor in
            await Task.yield()
            if reduceMotion {
                proxy.scrollTo(anchor, anchor: .center)
            } else {
                withAnimation(.snappy) { proxy.scrollTo(anchor, anchor: .center) }
            }
        }
    }

    private var saveButton: some View {
        Button {
            focusedField = nil
            Task {
                let didSave = await viewModel.save()
                BarabariInteraction.trigger(didSave ? .success : .error)
                if didSave {
                    session.markChanged()
                } else if viewModel.validationMessage?.hasPrefix("Enter an amount") == true {
                    go(to: .amount)
                }
            }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isSaving {
                    ProgressView().tint(BarabariColors.onAccent)
                }
                Text(viewModel.isSaving ? "Saving..." : "Save expense")
            }
            .font(.system(.body, design: .rounded, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 54)
            .contentShape(Capsule())
        }
        .buttonStyle(BarabariPrimaryButtonStyle())
        .disabled(viewModel.isSaving)
        .accessibilityLabel("Save expense")
        .accessibilityHint("Saves this expense on this iPhone")
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.row) {
            SectionHeader("Category") {
                if !viewModel.hasChosenCategory, viewModel.detectedCategory != nil {
                    Label("Auto", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(ExpenseCategory.allCases) { category in
                            let isSelected = viewModel.category == category && (viewModel.detectedCategory != nil)
                            Button {
                                BarabariInteraction.trigger(.selection)
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                    viewModel.chooseCategory(category)
                                }
                            } label: {
                                Label(LocalizedStringKey(category.title), systemImage: category.systemImage)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(isSelected ? .white : BarabariColors.textPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background {
                                        Capsule().fill(isSelected ? AnyShapeStyle(category.color.gradient) : AnyShapeStyle(BarabariColors.surface))
                                    }
                                    .overlay {
                                        Capsule().strokeBorder(isSelected ? .clear : BarabariColors.hairline, lineWidth: 1)
                                    }
                                    .scaleEffect(isSelected ? 1.04 : 1)
                            }
                            .buttonStyle(.pressable)
                            .id(category)
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
                .onChange(of: viewModel.detectedCategory) { _, category in
                    guard let category else { return }
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        proxy.scrollTo(category, anchor: .center)
                    }
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: viewModel.detectedCategory)
    }

    private var groupAndPayer: some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.row) {
            SectionHeader("Details")
            BarabariCard(padding: 0) {
                VStack(spacing: 0) {
                    selectionMenu(
                        title: "Group",
                        value: selectedGroupName,
                        accessibilityLabel: selectedGroupName
                    ) {
                        GroupAvatar(name: selectedGroupName, seed: viewModel.selectedGroupID ?? UUID(), size: 36)
                    } menuItems: {
                        ForEach(viewModel.groups) { group in
                            Button(group.name) { viewModel.selectGroup(group.id) }
                        }
                    }
                    RowDivider(leading: 64)
                    selectionMenu(
                        title: "Paid by",
                        value: viewModel.payerID.map(viewModel.memberName) ?? "Choose payer",
                        accessibilityLabel: "Paid by"
                    ) {
                        if let payerID = viewModel.payerID {
                            MemberAvatar(name: viewModel.memberName(for: payerID), seed: payerID, size: 36)
                        } else {
                            IconTile(systemImage: "person.fill", color: BarabariColors.textSecondary, size: 36)
                        }
                    } menuItems: {
                        ForEach(viewModel.members) { member in
                            Button(viewModel.memberName(for: member.userID)) { viewModel.payerID = member.userID }
                        }
                    }
                    RowDivider(leading: 64)
                    selectionMenu(
                        title: "Repeat",
                        value: String(localized: String.LocalizationValue(viewModel.repeatFrequency?.title ?? "Never")),
                        accessibilityLabel: "Repeat"
                    ) {
                        IconTile(
                            systemImage: "repeat",
                            color: viewModel.repeatFrequency == nil ? BarabariColors.textSecondary : BarabariColors.accent,
                            size: 36
                        )
                    } menuItems: {
                        Button("Never") { viewModel.repeatFrequency = nil }
                        ForEach(RecurrenceFrequency.allCases) { frequency in
                            Button(LocalizedStringKey(frequency.title)) { viewModel.repeatFrequency = frequency }
                        }
                    }
                }
            }
        }
    }

    private var participants: some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.row) {
            SectionHeader("Split with") {
                Text("\(viewModel.participantIDs.count) of \(viewModel.members.count)")
                    .foregroundStyle(BarabariColors.textSecondary)
                    .contentTransition(.numericText())
            }
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(viewModel.members) { member in
                        let isSelected = viewModel.participantIDs.contains(member.userID)
                        let name = viewModel.memberName(for: member.userID)
                        Button {
                            BarabariInteraction.trigger(.selection)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                                viewModel.toggleParticipant(member.userID)
                            }
                        } label: {
                            VStack(spacing: 8) {
                                MemberAvatar(name: name, seed: member.userID, size: 58)
                                    .saturation(isSelected ? 1 : 0)
                                    .opacity(isSelected ? 1 : 0.45)
                                    .overlay(alignment: .bottomTrailing) {
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle.fill")
                                            .font(.system(size: 20))
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, isSelected ? BarabariColors.accent : BarabariColors.textTertiary)
                                            .background(BarabariColors.background, in: .circle)
                                            .contentTransition(.symbolEffect(.replace))
                                            .offset(x: 2, y: 2)
                                    }
                                    .scaleEffect(isSelected ? 1 : 0.92)
                                Text(name)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(isSelected ? BarabariColors.textPrimary : BarabariColors.textSecondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 72)
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel("Split with \(name)")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }

    private func selectionMenu<Leading: View, MenuItems: View>(
        title: String,
        value: String,
        accessibilityLabel: String,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder menuItems: () -> MenuItems
    ) -> some View {
        Menu {
            menuItems()
        } label: {
            HStack(spacing: 14) {
                leading()
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(title))
                        .font(BarabariTypography.metadata)
                        .foregroundStyle(BarabariColors.textSecondary)
                    Text(value)
                        .font(BarabariTypography.body.weight(.medium))
                        .foregroundStyle(BarabariColors.textPrimary)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BarabariColors.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var selectedGroupName: String {
        viewModel.groups.first(where: { $0.id == viewModel.selectedGroupID })?.name ?? "Choose group"
    }

    private func validationLabel(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.circle.fill")
            .font(BarabariTypography.metadata.weight(.medium))
            .foregroundStyle(BarabariColors.danger)
            .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func personalConfirmation(_ transaction: MoneyTransaction) -> some View {
        let wallet = viewModel.personalFinanceWalletName(transaction.walletID)
        return ExpenseSavedView(
            headline: transaction.kind == .income ? "Income added" : "Expense saved",
            message: transaction.kind == .income
                ? "\(transaction.title) went into \(wallet)."
                : "\(transaction.title) was paid from \(wallet).",
            amountMinor: transaction.amountMinor,
            budgetAlert: viewModel.budgetAlert,
            actionTitle: transaction.kind == .income ? "Add another" : "Add another expense"
        ) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                viewModel.addAnotherExpense()
            }
        }
    }

    private func confirmation(_ expense: Expense) -> some View {
        ExpenseSavedView(
            headline: "Expense saved locally",
            message: "\(expense.title) is now part of this group’s ledger on this iPhone.",
            amountMinor: expense.total.minorUnits,
            budgetAlert: viewModel.budgetAlert,
            actionTitle: "Add another expense"
        ) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                viewModel.addAnotherExpense()
            }
        }
    }
}

private struct ExpenseSavedView: View {
    let headline: String
    let message: String
    let amountMinor: Int64
    let budgetAlert: BudgetProgress?
    let actionTitle: String
    let addAnother: () -> Void

    @State private var appeared = false
    @State private var ripple = false

    var body: some View {
        VStack(spacing: BarabariSpacing.section) {
            ZStack {
                Circle()
                    .stroke(BarabariColors.accent.opacity(0.25), lineWidth: 2)
                    .frame(width: 150, height: 150)
                    .scaleEffect(ripple ? 1.35 : 0.8)
                    .opacity(ripple ? 0 : 1)
                Circle()
                    .fill(BarabariColors.accent.gradient)
                    .frame(width: 112, height: 112)
                    .shadow(color: BarabariColors.accent.opacity(0.45), radius: 24, y: 10)
                    .scaleEffect(appeared ? 1 : 0.3)
                Image(systemName: "checkmark")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundStyle(BarabariColors.onAccent)
                    .symbolEffect(.drawOn, isActive: !appeared)
            }
            .frame(height: 180)

            VStack(spacing: BarabariSpacing.compact) {
                Text(LocalizedStringKey(headline))
                    .font(.title2.weight(.bold))
                Text(message)
                    .font(BarabariTypography.body)
                    .foregroundStyle(BarabariColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)

            HeroAmount(minorUnits: amountMinor, size: 44, color: BarabariColors.textPrimary)
                .opacity(appeared ? 1 : 0)

            if let budgetAlert {
                BudgetAlertBanner(progress: budgetAlert)
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.9)
            }

            PrimaryActionButton(actionTitle, action: addAnother)
                .opacity(appeared ? 1 : 0)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { appeared = true }
            withAnimation(.easeOut(duration: 1.1).delay(0.15)) { ripple = true }
            if budgetAlert != nil { BarabariInteraction.trigger(.error) }
        }
    }
}

/// "Food budget: 86% used" — shown right after a save that crosses 80%.
struct BudgetAlertBanner: View {
    let progress: BudgetProgress

    private var tint: Color { progress.level == .over ? BarabariColors.danger : BarabariColors.warning }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: progress.level == .over ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(tint)
                .symbolEffect(.wiggle, options: .nonRepeating)
            VStack(alignment: .leading, spacing: 2) {
                Text(progress.level == .over
                     ? "\(progress.category.title) budget is over"
                     : "\(progress.category.title) budget: \(Int((progress.fraction * 100).rounded()))% used")
                    .font(.subheadline.weight(.semibold))
                Text(progress.level == .over
                     ? "\(AmountFormatter.string(minorUnits: -progress.remainingMinor, currencyCode: "PKR")) over this month’s limit"
                     : "\(AmountFormatter.string(minorUnits: progress.remainingMinor, currencyCode: "PKR")) left this month")
                    .font(.caption)
                    .foregroundStyle(BarabariColors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(tint.opacity(0.12), in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(tint.opacity(0.3), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("budget-alert")
    }
}
