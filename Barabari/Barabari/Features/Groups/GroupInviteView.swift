import SwiftUI
import UIKit

struct GroupInviteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel: GroupInviteViewModel
    @State private var didCopy = false
    @Environment(\.syncEngine) private var syncEngine

    init(environment: AppEnvironment, groupID: UUID) {
        _viewModel = StateObject(wrappedValue: GroupInviteViewModel(environment: environment, groupID: groupID))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BarabariSpacing.section) {
                    switch viewModel.state {
                    case .loading:
                        BarabariLoadingState(title: "Preparing invite")
                    case let .loaded(payload, link):
                        inviteContent(payload: payload, link: link)
                    case let .failed(message):
                        failure(message)
                    }
                }
                .padding(.top, 8)
                .barabariScreen()
            }
            .background(BarabariColors.background.ignoresSafeArea())
            .navigationTitle("Invite people")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .task { await viewModel.load() }
        .animation(
            reduceMotion ? nil : .snappy(duration: 0.35, extraBounce: 0.02),
            value: viewModel.state
        )
    }

    @ViewBuilder
    private func inviteContent(payload: GroupInvitePayload, link: URL) -> some View {
        VStack(spacing: 6) {
            Text("Invite to \(payload.groupName)")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
            Text(syncEngine == nil
                 ? "Share this link or let someone scan the code to join this local ledger."
                 : "Share this link or let someone scan the code to join from their own phone.")
                .font(BarabariTypography.metadata)
                .foregroundStyle(BarabariColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)

        InviteQRCodeImage(url: link)
            .frame(maxWidth: 260)
            .overlay {
                GroupAvatar(name: payload.groupName, seed: payload.groupID, size: 52)
                    .padding(5)
                    .background(.white, in: .rect(cornerRadius: 20))
            }
            .shadow(color: .black.opacity(0.18), radius: 30, y: 16)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .accessibilityIdentifier("invite-qr")
            .staggeredAppear(0)

        VStack(spacing: BarabariSpacing.row) {
            Text(link.absoluteString)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(BarabariColors.textSecondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(BarabariColors.raised.opacity(0.6), in: .rect(cornerRadius: 16))

            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = link.absoluteString
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { didCopy = true }
                        BarabariInteraction.trigger(.success)
                    } label: {
                        Label(didCopy ? "Copied" : "Copy link", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                            .contentTransition(.symbolEffect(.replace))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BarabariColors.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.pressable)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .accessibilityIdentifier("copy-invite-link")

                    ShareLink(item: link.absoluteString) {
                        Label("Share link", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BarabariColors.onAccent)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(BarabariColors.accent.gradient, in: .capsule)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("share-invite-link")
                }
            }
        }
        .staggeredAppear(1)

        Label(
            syncEngine == nil
                ? "Local demo: this invite works when the group is already in Barabari on this iPhone."
                : "Anyone with this link can join from their own phone and see the same balances.",
            systemImage: syncEngine == nil ? "iphone" : "icloud.fill"
        )
            .font(BarabariTypography.metadata)
            .foregroundStyle(BarabariColors.textSecondary)
            .staggeredAppear(2)
    }

    private func failure(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.row) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(BarabariColors.danger)
            Text("Invite unavailable")
                .font(BarabariTypography.sectionTitle)
            Text(LocalizedStringKey(message))
                .foregroundStyle(BarabariColors.textSecondary)
            PrimaryActionButton("Try again") {
                Task { await viewModel.load() }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 280, alignment: .center)
    }
}
