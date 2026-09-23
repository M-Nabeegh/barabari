import SwiftUI
import UIKit

struct GroupInviteView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: GroupInviteViewModel
    @State private var didCopy = false

    init(environment: AppEnvironment, groupID: UUID) {
        _viewModel = StateObject(wrappedValue: GroupInviteViewModel(environment: environment, groupID: groupID))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BarabariSpacing.section) {
                    switch viewModel.state {
                    case .loading:
                        ProgressView("Preparing invite")
                            .frame(maxWidth: .infinity, minHeight: 280)
                    case let .loaded(payload, link):
                        inviteContent(payload: payload, link: link)
                    case let .failed(message):
                        failure(message)
                    }
                }
                .padding(BarabariSpacing.screen)
                .padding(.bottom, BarabariSpacing.bottomContent)
            }
            .background(BarabariColors.background.ignoresSafeArea())
            .navigationTitle("Invite people")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .barabariHitTarget()
                }
            }
        }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private func inviteContent(payload: GroupInvitePayload, link: URL) -> some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.compact) {
            Text("Invite to (payload.groupName)")
                .font(BarabariTypography.screenTitle)
            Text("Share this link or let someone scan the code to join this local ledger.")
                .font(BarabariTypography.body)
                .foregroundStyle(BarabariColors.textSecondary)
        }

        InviteQRCodeImage(url: link)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("invite-qr")

        BarabariCard {
            VStack(alignment: .leading, spacing: BarabariSpacing.row) {
                Text("Invite link")
                    .font(BarabariTypography.metadata)
                    .foregroundStyle(BarabariColors.textSecondary)
                Text(link.absoluteString)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: BarabariSpacing.row) {
                    Button {
                        UIPasteboard.general.string = link.absoluteString
                        didCopy = true
                        BarabariInteraction.trigger(.success)
                    } label: {
                        Label(didCopy ? "Copied" : "Copy link", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                    }
                    .accessibilityIdentifier("copy-invite-link")
                    .barabariHitTarget()

                    ShareLink(item: link.absoluteString) {
                        Label("Share link", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("share-invite-link")
                    .barabariHitTarget()
                }
                .buttonStyle(.bordered)
            }
        }

        Label("Local demo: this invite works when the group is already in Barabari on this iPhone. Cloud sync comes later.", systemImage: "iphone")
            .font(BarabariTypography.metadata)
            .foregroundStyle(BarabariColors.textSecondary)
    }

    private func failure(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.row) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(BarabariColors.danger)
            Text("Invite unavailable")
                .font(BarabariTypography.sectionTitle)
            Text(message)
                .foregroundStyle(BarabariColors.textSecondary)
            PrimaryActionButton("Try again") {
                Task { await viewModel.load() }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 280, alignment: .center)
    }
}
