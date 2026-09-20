import SwiftUI

struct SettingsView: View {
    let isDemo: Bool
    @StateObject private var viewModel = SettingsViewModel()
    @State private var selectedFeature: SettingsFeature?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BarabariSpacing.section) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your space")
                        .font(BarabariTypography.screenTitle)
                    Text("Clear, local-first controls for your shared ledger.")
                        .font(BarabariTypography.body)
                        .foregroundStyle(BarabariColors.textSecondary)
                }

                VStack(spacing: 0) {
                    settingsRow(.appearance, status: viewModel.appearanceStatus)
                    Divider()
                    settingsRow(.notifications, status: viewModel.notificationsStatus)
                    Divider()
                    settingsRow(.privacy, status: viewModel.privacyStatus)
                }
                .background(BarabariColors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(spacing: 0) {
                    settingsRow(.export, status: viewModel.exportStatus)
                    Divider()
                    settingsRow(.deleteAccount, status: viewModel.deletionStatus, isDestructive: true)
                }
                .background(BarabariColors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                StatusBadge(
                    isDemo ? "Demo mode: data stays on this iPhone." : "Your data stays on this iPhone.",
                    style: .neutral
                )
            }
            .padding(BarabariSpacing.screen)
            .padding(.bottom, 92)
        }
        .background(BarabariColors.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert(selectedFeature?.title ?? "Settings", isPresented: Binding(
            get: { selectedFeature != nil },
            set: { if !$0 { selectedFeature = nil } }
        )) {
            Button("OK", role: .cancel) { selectedFeature = nil }
        } message: {
            Text(selectedFeature.map(viewModel.availabilityMessage(for:)) ?? "")
        }
    }

    private func settingsRow(_ feature: SettingsFeature, status: String, isDestructive: Bool = false) -> some View {
        Button {
            selectedFeature = feature
        } label: {
            HStack(spacing: BarabariSpacing.row) {
                Image(systemName: feature.symbol)
                    .foregroundStyle(isDestructive ? BarabariColors.danger : BarabariColors.accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(feature.title)
                        .font(BarabariTypography.body)
                        .foregroundStyle(isDestructive ? BarabariColors.danger : BarabariColors.textPrimary)
                    Text(status)
                        .font(BarabariTypography.metadata)
                        .foregroundStyle(BarabariColors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BarabariColors.textSecondary)
            }
            .padding(BarabariSpacing.row)
            .frame(minHeight: 64)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(feature.title)
        .accessibilityValue(status)
    }
}
