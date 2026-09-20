import SwiftUI

struct GroupsView: View {
    @ObservedObject var viewModel: GroupsViewModel
    let revision: Int
    let onChanged: () -> Void
    let selectGroup: (Group) -> Void

    @State private var isPresentingCreateGroup = false
    @State private var isPresentingJoinMessage = false

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
            .padding(.bottom, BarabariSpacing.section)
        }
        .navigationTitle("Groups")
        .navigationBarTitleDisplayMode(.large)
        .task(id: revision) { await viewModel.refresh() }
        .refreshable { await viewModel.refresh() }
        .sheet(isPresented: $isPresentingCreateGroup) {
            CreateGroupSheet { name, description in
                Task {
                    if let group = await viewModel.createGroup(name: name, description: description) {
                        BarabariInteraction.trigger(.success)
                        onChanged()
                        isPresentingCreateGroup = false
                        selectGroup(group)
                    }
                }
            }
        }
        .alert("Join a group", isPresented: $isPresentingJoinMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Join links and QR codes are coming in the next offline-ready milestone.")
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

            PrimaryActionButton("Create group") {
                isPresentingCreateGroup = true
            }

            Button("Join group") {
                isPresentingJoinMessage = true
            }
            .font(.system(.body, design: .rounded, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(BarabariColors.accent)
            .background(BarabariColors.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                    BarabariInteraction.trigger(.selection)
                    isPresentingCreateGroup = true
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .frame(width: BarabariInteraction.minimumHitSize, height: BarabariInteraction.minimumHitSize)
                        .contentShape(Circle())
                }
                .accessibilityLabel("Create group")
                .foregroundStyle(.white)
                .background(BarabariColors.accent, in: Circle())
            }

            ForEach(viewModel.groups) { group in
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
                .buttonStyle(.plain)
                .barabariHitTarget()
                .accessibilityLabel(group.name)
                .accessibilityHint("Open group")
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

    let save: (String, String?) -> Void

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
            }
            .navigationTitle("New group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
                        save(trimmedName, trimmedDescription.isEmpty ? nil : trimmedDescription)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
