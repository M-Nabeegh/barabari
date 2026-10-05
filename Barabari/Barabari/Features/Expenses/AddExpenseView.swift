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
            } else if viewModel.isLoading {
                BarabariLoadingState(title: "Loading your groups")
            } else if viewModel.groups.isEmpty {
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
            } else {
                detailsStep
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BarabariColors.background)
        .navigationTitle(step == .amount ? "Add expense" : "New expense")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if step == .details && viewModel.savedExpense == nil {
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
            ForEach(viewModel.groups) { group in
                Button(group.name) { viewModel.selectGroup(group.id) }
            }
        } label: {
            HStack(spacing: 8) {
                GroupAvatar(name: selectedGroupName, seed: viewModel.selectedGroupID ?? UUID(), size: 24)
                Text(selectedGroupName)
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
        .accessibilityLabel("Group, \(selectedGroupName)")
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
                       !validationMessage.hasPrefix("Exact amounts") {
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
                guard selection == .exact else { return }
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

    private func confirmation(_ expense: Expense) -> some View {
        ExpenseSavedView(expense: expense) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                viewModel.addAnotherExpense()
            }
        }
    }
}

private struct ExpenseSavedView: View {
    let expense: Expense
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
                Text("Expense saved locally")
                    .font(.title2.weight(.bold))
                Text("\(expense.title) is now part of this group’s ledger on this iPhone.")
                    .font(BarabariTypography.body)
                    .foregroundStyle(BarabariColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)

            HeroAmount(minorUnits: expense.total.minorUnits, currencyCode: expense.total.currencyCode, size: 44, color: BarabariColors.textPrimary)
                .opacity(appeared ? 1 : 0)

            PrimaryActionButton("Add another expense", action: addAnother)
                .opacity(appeared ? 1 : 0)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { appeared = true }
            withAnimation(.easeOut(duration: 1.1).delay(0.15)) { ripple = true }
        }
    }
}
