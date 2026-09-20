import SwiftUI

struct SettingsView: View {
    let isDemo: Bool

    @StateObject private var viewModel: SettingsViewModel
    @State private var isShowingPrivacy = false

    init(environment: AppEnvironment, isDemo: Bool) {
        self.isDemo = isDemo
        _viewModel = StateObject(wrappedValue: SettingsViewModel(environment: environment))
    }

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

                BarabariCard {
                    VStack(spacing: 0) {
                        HStack(spacing: BarabariSpacing.row) {
                            Image(systemName: "circle.lefthalf.filled")
                                .foregroundStyle(BarabariColors.accent)
                                .frame(width: 24)
                            Text("Appearance")
                                .font(BarabariTypography.body)
                            Spacer()
                            Picker("Appearance", selection: $viewModel.appearance) {
                                ForEach(BarabariAppearance.allCases) { appearance in
                                    Text(appearance.title).tag(appearance)
                                }
                            }
                            .pickerStyle(.menu)
                            .accessibilityIdentifier("appearance-picker")
                        }
                        .frame(minHeight: 52)

                        Divider()

                        Toggle(isOn: $viewModel.hapticsEnabled) {
                            Label("Haptics", systemImage: "waveform.path.ecg")
                                .font(BarabariTypography.body)
                        }
                        .frame(minHeight: 52)
                        .accessibilityIdentifier("haptics-toggle")
                    }
                }

                BarabariCard {
                    VStack(spacing: 0) {
                        Button {
                            isShowingPrivacy = true
                        } label: {
                            settingsRowContent(
                                symbol: "hand.raised.fill",
                                title: "Privacy",
                                detail: "Stored on this iPhone"
                            )
                        }
                        .buttonStyle(.plain)
                        .barabariHitTarget(minHeight: 56)
                        .accessibilityHint("Explain local-only storage")

                        Divider()

                        VStack(alignment: .leading, spacing: BarabariSpacing.compact) {
                            settingsRowContent(
                                symbol: "square.and.arrow.up",
                                title: "Export data",
                                detail: viewModel.exportStatus
                            )

                            HStack(spacing: BarabariSpacing.compact) {
                                exportButton(title: "Prepare JSON export", format: .json)
                                exportButton(title: "Prepare CSV export", format: .csv)
                            }

                            if let json = viewModel.preparedJSON {
                                ShareLink(item: json, subject: Text("Barabari JSON export")) {
                                    Label("Share JSON export", systemImage: "square.and.arrow.up")
                                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                }
                                .buttonStyle(.bordered)
                                .tint(BarabariColors.accent)
                                .accessibilityIdentifier("share-json-export")
                            }

                            if let csv = viewModel.preparedCSV {
                                ShareLink(item: csv, subject: Text("Barabari CSV export")) {
                                    Label("Share CSV export", systemImage: "square.and.arrow.up")
                                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                }
                                .buttonStyle(.bordered)
                                .tint(BarabariColors.accent)
                                .accessibilityIdentifier("share-csv-export")
                            }
                        }
                        .padding(.vertical, BarabariSpacing.compact)
                    }
                }

                StatusBadge(
                    isDemo ? "Local demo: data stays on this iPhone." : "Local ledger: data stays on this iPhone.",
                    style: .neutral
                )
                .accessibilityIdentifier("local-demo-status")
            }
            .padding(BarabariSpacing.screen)
            .padding(.bottom, BarabariSpacing.bottomContent)
        }
        .background(BarabariColors.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $isShowingPrivacy) {
            NavigationStack {
                VStack(alignment: .leading, spacing: BarabariSpacing.section) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(BarabariColors.accent)
                    Text("Private by default")
                        .font(BarabariTypography.screenTitle)
                    Text("This demo stores its groups, expenses, settlements, and export data locally on this iPhone. There is no account, cloud sync, notification service, or payment connection in this build.")
                        .font(BarabariTypography.body)
                        .foregroundStyle(BarabariColors.textSecondary)
                    Spacer()
                }
                .padding(BarabariSpacing.screen)
                .background(BarabariColors.background)
                .navigationTitle("Privacy")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
        .preferredColorScheme(viewModel.appearance.colorScheme)
    }

    private func settingsRowContent(symbol: String, title: String, detail: String) -> some View {
        HStack(spacing: BarabariSpacing.row) {
            Image(systemName: symbol)
                .foregroundStyle(BarabariColors.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(BarabariTypography.body)
                    .foregroundStyle(BarabariColors.textPrimary)
                Text(detail)
                    .font(BarabariTypography.metadata)
                    .foregroundStyle(BarabariColors.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(BarabariColors.textSecondary)
        }
        .contentShape(Rectangle())
    }

    private func exportButton(title: String, format: LocalLedgerExportFormat) -> some View {
        Button {
            Task { await viewModel.prepareExport(format: format) }
        } label: {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(BarabariColors.accent)
        .disabled(viewModel.isPreparingExport)
        .accessibilityLabel(title)
    }
}
