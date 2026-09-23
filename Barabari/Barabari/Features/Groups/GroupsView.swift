import SwiftUI

struct GroupsView: View {
    @ObservedObject var viewModel: GroupsViewModel
    let revision: Int
    let onChanged: () -> Void
    let selectGroup: (Group) -> Void
    let onJoin: () -> Void

    @State private var isPresentingCreateGroup = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasRevealedGroups = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BarabariSpacing.section) {
                switch viewModel.state {
                case .loading:
                    loadingView
                case .empty:
                    emptyView
                case .loaded, .offline:
                    loadedView
                case let .failed(message):
                    errorView(message)
                }
            }
            .padding(BarabariSpacing.screen)
            .padding(.bottom, BarabariSpacing.bottomContent)
        }
        .navigationTitle("Groups")
        .navigationBarTitleDisplayMode(.large)
        .task(id: revision) { await viewModel.refresh() }
        .refreshable { await viewModel.refresh() }
        .onAppear { revealGroupsIfReady() }
        .onChange(of: viewModel.state) { _, _ in revealGroupsIfReady() }
        .sheet(isPresented: $isPresentingCreateGroup) {
            CreateGroupSheet { name, description in
                guard let group = await viewModel.createGroup(name: name, description: description) else {
                    return viewModel.creationError ?? "We could not create this group. Try again."
                }

                BarabariInteraction.trigger(.success)
                onChanged()
                isPresentingCreateGroup = false
                selectGroup(group)
                return nil
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: BarabariSpacing.row) {
            ProgressView()
            Text("Loading your groups")
                .foregroundStyle(BarabariColors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
    }

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.section) {
            VStack(alignment: .leading, spacing: BarabariSpacing.compact) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(BarabariColors.accent)
                Text("No groups yet")
                    .font(BarabariTypography.screenTitle)
                Text("Start a shared ledger for the people and plans that matter.")
                    .font(BarabariTypography.body)
                    .foregroundStyle(BarabariColors.textSecondary)
            }

            VStack(spacing: BarabariSpacing.row) {
                PrimaryActionButton("Create group") {
                    isPresentingCreateGroup = true
                }

                Button {
                    onJoin()
                } label: {
                    Label("Join group", systemImage: "person.2.badge.plus")
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.bordered)
                .tint(BarabariColors.accent)
                .accessibilityIdentifier("join-group")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 340, alignment: .center)
    }

    private var loadedView: some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.section) {
            if viewModel.state == .offline {
                StatusBadge("Offline. Your groups are saved on this iPhone.", style: .warning)
            }

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your groups")
                        .font(BarabariTypography.sectionTitle)
                    Text("Pick up where you left off.")
                        .font(BarabariTypography.body)
                        .foregroundStyle(BarabariColors.textSecondary)
                }
                Spacer()
                Button {
                    onJoin()
                } label: {
                    Image(systemName: "person.2.badge.plus")
                        .font(.headline)
                        .frame(width: BarabariInteraction.minimumHitSize, height: BarabariInteraction.minimumHitSize)
                        .contentShape(Circle())
                }
                .accessibilityLabel("Join group")
                .accessibilityIdentifier("join-group")
                .foregroundStyle(BarabariColors.accent)
                Button {
                    BarabariInteraction.trigger(.selection)
                    isPresentingCreateGroup = true
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .frame(width: BarabariInteraction.minimumHitSize, height: BarabariInteraction.minimumHitSize)
                        .contentShape(Circle())
                }
                .accessibilityLabel("Create group")
                .foregroundStyle(BarabariColors.onAccent)
                .background(BarabariColors.accent, in: Circle())
            }

            BarabariCard {
                HStack(spacing: BarabariSpacing.row) {
                    Image(systemName: "link.circle.fill")
                        .font(.title2)
                        .foregroundStyle(BarabariColors.brandMint)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Joining a shared group?")
                            .font(BarabariTypography.body)
                        Text("Paste an invite link or scan a QR code.")
                            .font(BarabariTypography.metadata)
                            .foregroundStyle(BarabariColors.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Button("Join") { onJoin() }
                        .buttonStyle(.bordered)
                        .tint(BarabariColors.accent)
                        .accessibilityIdentifier("join-group-card")
                }
            }

            ForEach(Array(viewModel.groups.enumerated()), id: \.element.id) { entry in
                let group = entry.element
                Button {
                    selectGroup(group)
                } label: {
                    BarabariCard {
                        HStack(spacing: BarabariSpacing.row) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(BarabariColors.accent)
                                .frame(width: 36, height: 36)
                                .background(BarabariColors.raised, in: Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.name)
                                    .font(BarabariTypography.sectionTitle)
                                    .foregroundStyle(BarabariColors.textPrimary)
                                if let description = group.description, !description.isEmpty {
                                    Text(description)
                                        .font(BarabariTypography.metadata)
                                        .foregroundStyle(BarabariColors.textSecondary)
                                } else {
                                    Text("Shared ledger")
                                        .font(BarabariTypography.metadata)
                                        .foregroundStyle(BarabariColors.textSecondary)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(BarabariColors.textSecondary)
                        }
                        .contentShape(Rectangle())
                    }
                }
                .buttonStyle(BarabariCardButtonStyle())
                .barabariHitTarget()
                .accessibilityLabel(group.name)
                .accessibilityHint("Open group")
                .opacity(hasRevealedGroups ? 1 : 0)
                .offset(y: hasRevealedGroups ? 0 : 8)
                .animation(
                    reduceMotion ? nil : .easeOut(duration: 0.34).delay(Double(entry.offset) * 0.045),
                    value: hasRevealedGroups
                )
            }
        }
    }

    private func revealGroupsIfReady() {
        guard viewModel.state == .loaded || viewModel.state == .offline else { return }
        guard !hasRevealedGroups else { return }

        if reduceMotion {
            hasRevealedGroups = true
        } else {
            withAnimation(.easeOut(duration: 0.38)) {
                hasRevealedGroups = true
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.row) {
            Text("We could not load your groups")
                .font(BarabariTypography.sectionTitle)
            Text(message)
                .foregroundStyle(BarabariColors.textSecondary)
            PrimaryActionButton("Try again") {
                Task { await viewModel.refresh() }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .center)
    }
}

private struct CreateGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    let save: (String, String?) async -> String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Group details") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("group-name-field")
                    TextField("Optional description", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(BarabariTypography.metadata)
                            .foregroundStyle(BarabariColors.danger)
                            .accessibilityIdentifier("create-group-error")
                    }
                }
            }
            .navigationTitle("New group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        guard !isSaving else { return }
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
                        isSaving = true
                        errorMessage = nil
                        Task { @MainActor in
                            if let failure = await save(trimmedName, trimmedDescription.isEmpty ? nil : trimmedDescription) {
                                isSaving = false
                                errorMessage = failure
                            } else {
                                dismiss()
                            }
                        }
                    }
                    .accessibilityIdentifier("create-group-button")
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
