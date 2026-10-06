import SwiftUI

struct GroupsView: View {
    @ObservedObject var viewModel: GroupsViewModel
    @Environment(\.syncEngine) private var syncEngine
    let revision: Int
    let transitionNamespace: Namespace.ID
    @Binding var isPresentingCreateGroup: Bool
    let onChanged: () -> Void
    let selectGroup: (Group) -> Void
    let onJoin: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BarabariSpacing.section) {
                switch viewModel.state {
                case .loading:
                    BarabariLoadingState(title: "Loading your groups")
                case .empty:
                    emptyView
                case .loaded, .offline:
                    loadedView
                case let .failed(message):
                    errorView(message)
                }
            }
            .padding(.top, 4)
            .barabariScreen()
        }
        .scrollIndicators(.hidden)
        .background(BarabariColors.background)
        .navigationTitle("Groups")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if viewModel.state == .loaded || viewModel.state == .offline {
                    Button(action: onJoin) {
                        Image(systemName: "qrcode.viewfinder")
                    }
                    .accessibilityLabel("Join group")
                    .accessibilityIdentifier("join-group")

                    Button {
                        BarabariInteraction.trigger(.selection)
                        isPresentingCreateGroup = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create group")
                }
            }
        }
        .task(id: revision) { await viewModel.refresh() }
        .refreshable {
            await syncEngine?.syncNow()
            await viewModel.refresh()
        }
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

    private var emptyView: some View {
        BarabariEmptyState(
            systemImage: "person.2.fill",
            title: "No groups yet",
            message: "Start a shared ledger for the people and plans that matter."
        ) {
            PrimaryActionButton("Create group") {
                isPresentingCreateGroup = true
            }
            SecondaryActionButton("Join group", systemImage: "qrcode.viewfinder", action: onJoin)
                .accessibilityIdentifier("join-group")
        }
    }

    private var loadedView: some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.section) {
            if viewModel.state == .offline {
                StatusBadge("Offline. Your groups are saved on this iPhone.", style: .warning)
            }

            VStack(spacing: 12) {
                ForEach(Array(viewModel.groups.enumerated()), id: \.element.id) { index, group in
                    Button {
                        BarabariInteraction.trigger(.selection)
                        selectGroup(group)
                    } label: {
                        groupRow(group)
                    }
                    .buttonStyle(.pressable)
                    .matchedTransitionSource(id: group.id, in: transitionNamespace) { source in
                        source.clipShape(.rect(cornerRadius: BarabariSpacing.cardRadius))
                    }
                    .accessibilityLabel(group.name)
                    .accessibilityHint("Open group")
                    .staggeredAppear(index)
                }
            }

            joinBanner
                .staggeredAppear(viewModel.groups.count)
        }
    }

    private func groupRow(_ group: Group) -> some View {
        HStack(spacing: 14) {
            GroupAvatar(name: group.name, seed: group.id, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(group.name)
                    .font(BarabariTypography.headline)
                    .foregroundStyle(BarabariColors.textPrimary)
                    .lineLimit(1)
                Text(group.description?.isEmpty == false ? group.description! : "Shared ledger")
                    .font(BarabariTypography.metadata)
                    .foregroundStyle(BarabariColors.textSecondary)
                    .lineLimit(2)
                Text("Created \(group.createdAt.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(BarabariColors.textTertiary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(BarabariColors.textTertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BarabariColors.surface, in: .rect(cornerRadius: BarabariSpacing.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: BarabariSpacing.cardRadius, style: .continuous)
                .strokeBorder(BarabariColors.hairline, lineWidth: 1)
        }
        .contentShape(.rect(cornerRadius: BarabariSpacing.cardRadius))
    }

    private var joinBanner: some View {
        Button(action: onJoin) {
            HStack(spacing: 14) {
                IconTile(systemImage: "qrcode", color: BarabariColors.accent, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Joining a group?")
                        .font(BarabariTypography.body.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(BarabariColors.textPrimary)
                    Text("Paste a link or scan a QR code.")
                        .font(BarabariTypography.metadata)
                        .foregroundStyle(BarabariColors.textSecondary)
                }
                Spacer(minLength: 0)
                Text("Join")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BarabariColors.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: BarabariSpacing.cardRadius, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    .foregroundStyle(BarabariColors.accent.opacity(0.35))
            }
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("join-group-card")
    }

    private func errorView(_ message: String) -> some View {
        BarabariEmptyState(
            systemImage: "exclamationmark.triangle.fill",
            title: "We could not load your groups",
            message: message
        ) {
            PrimaryActionButton("Try again") {
                Task { await viewModel.refresh() }
            }
        }
    }
}

private struct CreateGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var previewSeed = UUID()

    let save: (String, String?) async -> String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        GroupAvatar(name: name.isEmpty ? "B" : name, seed: previewSeed, size: 84)
                            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: name.first)
                        Text(name.isEmpty ? "New group" : name)
                            .font(.title3.weight(.bold))
                            .lineLimit(1)
                            .contentTransition(.interpolate)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

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
        .presentationDetents([.medium, .large])
    }
}
