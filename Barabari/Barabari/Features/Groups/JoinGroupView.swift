import SwiftUI
import UIKit

struct JoinGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel: JoinGroupViewModel
    @State private var isPresentingScanner = false
    @FocusState private var isLinkFieldFocused: Bool

    let joined: (Group) -> Void

    init(environment: AppEnvironment, initialURL: URL? = nil, joined: @escaping (Group) -> Void) {
        _viewModel = StateObject(wrappedValue: JoinGroupViewModel(environment: environment, initialURL: initialURL))
        self.joined = joined
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BarabariSpacing.section) {
                    header
                    linkEntry
                    stateContent
                }
                .padding(.top, 8)
                .barabariScreen()
            }
            .background(BarabariColors.background.ignoresSafeArea())
            .navigationTitle("Join a group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .task { await viewModel.parseAndLoad() }
        .animation(
            reduceMotion ? nil : .snappy(duration: 0.35, extraBounce: 0.02),
            value: viewModel.state
        )
        .sheet(isPresented: $isPresentingScanner) {
            NavigationStack {
                QRCodeScannerView(
                    onCode: { value in
                        isPresentingScanner = false
                        viewModel.parse(value)
                    },
                    onUnavailable: {
                        isPresentingScanner = false
                        isLinkFieldFocused = true
                    }
                )
                .ignoresSafeArea()
                .navigationTitle("Scan invite QR")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isPresentingScanner = false }
                    }
                }
            }
            .presentationDetents([.large])
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(BarabariColors.accent.gradient)
                .frame(width: 80, height: 80)
                .background(BarabariColors.accent.opacity(0.12), in: .circle)
                .symbolEffect(.breathe, options: .repeat(2))
            Text("Join with an invite")
                .font(.title2.weight(.bold))
            Text("Paste a Barabari link or scan a QR code. We will check whether the group is available in this local demo.")
                .font(BarabariTypography.metadata)
                .foregroundStyle(BarabariColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var linkEntry: some View {
        BarabariCard {
            VStack(alignment: .leading, spacing: BarabariSpacing.row) {
                Text("Invite link")
                    .font(BarabariTypography.metadata)
                    .foregroundStyle(BarabariColors.textSecondary)
                HStack(spacing: 8) {
                    TextField("barabari://join…", text: $viewModel.linkText, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .focused($isLinkFieldFocused)
                        .accessibilityIdentifier("Paste invite link")
                    Button {
                        guard let value = UIPasteboard.general.string else { return }
                        viewModel.parse(value)
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                            .frame(width: BarabariInteraction.minimumHitSize, height: BarabariInteraction.minimumHitSize)
                    }
                    .accessibilityLabel("Paste invite link")
                    .barabariHitTarget()
                }
                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        Button {
                            BarabariInteraction.trigger(.selection)
                            Task { await viewModel.parseAndLoad() }
                        } label: {
                            Text("Check link")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BarabariColors.onAccent)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(BarabariColors.accent.gradient, in: .capsule)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.pressable)

                        Button {
                            isLinkFieldFocused = false
                            isPresentingScanner = true
                        } label: {
                            Label("Scan QR", systemImage: "qrcode.viewfinder")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BarabariColors.textPrimary)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.pressable)
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .accessibilityIdentifier("scan-qr")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        switch viewModel.state {
        case .idle:
            EmptyView()
        case let .preview(payload, localGroup):
            preview(payload: payload, localGroup: localGroup)
        case .joining:
            ProgressView("Joining group")
                .frame(maxWidth: .infinity, minHeight: 120)
        case let .joined(outcome):
            joinedContent(outcome)
        case let .failed(message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(BarabariTypography.body)
                .foregroundStyle(BarabariColors.danger)
                .accessibilityIdentifier("join-group-error")
        }
    }

    private func preview(payload: GroupInvitePayload, localGroup: Group?) -> some View {
        VStack(alignment: .leading, spacing: BarabariSpacing.row) {
            BarabariCard {
                VStack(alignment: .leading, spacing: BarabariSpacing.compact) {
                    HStack(spacing: 12) {
                        GroupAvatar(name: payload.groupName, seed: payload.groupID, size: 44)
                        Text(payload.groupName)
                            .font(BarabariTypography.sectionTitle)
                    }
                    if localGroup == nil {
                        Label("This group is not available on this iPhone", systemImage: "iphone.slash")
                            .font(BarabariTypography.metadata)
                            .foregroundStyle(BarabariColors.warning)
                    } else {
                        Label("Available on this iPhone", systemImage: "checkmark.circle.fill")
                            .font(BarabariTypography.metadata)
                            .foregroundStyle(BarabariColors.success)
                    }
                }
            }

            Label("Local demo: joining only updates this iPhone. It does not create cloud sync.", systemImage: "lock.shield")
                .font(BarabariTypography.metadata)
                .foregroundStyle(BarabariColors.textSecondary)

            if localGroup != nil {
                PrimaryActionButton("Join group") {
                    isLinkFieldFocused = false
                    Task {
                        if let group = await viewModel.join() { joined(group) }
                    }
                }
                .accessibilityIdentifier("join-group-confirm")
            }
        }
    }

    @ViewBuilder
    private func joinedContent(_ outcome: GroupJoinOutcome) -> some View {
        switch outcome {
        case let .joined(group):
            Label("Joined \(group.name)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(BarabariColors.success)
        case let .alreadyMember(group):
            Label("You are already in \(group.name)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(BarabariColors.success)
        case .unavailable:
            EmptyView()
        }
    }
}
