import SwiftUI

struct SettingsView: View {
    let isDemo: Bool

    @StateObject private var viewModel: SettingsViewModel
    @State private var isShowingPrivacy = false
    @State private var isEditingName = false
    @ObservedObject private var metadata = LedgerMetadata.shared
    @ObservedObject private var lock = AppLock.shared
    @Environment(\.syncEngine) private var syncEngine
    @AppStorage("barabari.hasOnboarded") private var hasOnboarded = true

    init(environment: AppEnvironment, isDemo: Bool) {
        self.isDemo = isDemo
        _viewModel = StateObject(wrappedValue: SettingsViewModel(environment: environment))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BarabariSpacing.section) {
                profileCard
                    .staggeredAppear(0)

                if let syncEngine {
                    VStack(alignment: .leading, spacing: BarabariSpacing.compact) {
                        sectionLabel("Cloud")
                        BarabariCard(padding: 0) {
                            CloudSyncRow(engine: syncEngine)
                        }
                    }
                    .staggeredAppear(1)
                }

                VStack(alignment: .leading, spacing: BarabariSpacing.compact) {
                    sectionLabel("Appearance")
                    appearancePicker
                }
                .staggeredAppear(1)

                VStack(alignment: .leading, spacing: BarabariSpacing.compact) {
                    sectionLabel("Feel")
                    BarabariCard(padding: 0) {
                        Toggle(isOn: $viewModel.hapticsEnabled) {
                            HStack(spacing: 14) {
                                SettingsIcon(systemImage: "iphone.radiowaves.left.and.right", color: .pink)
                                Text("Haptics")
                                    .font(BarabariTypography.body)
                            }
                        }
                        .tint(BarabariColors.accent)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 56)
                        .accessibilityIdentifier("haptics-toggle")
                    }
                }
                .staggeredAppear(2)

                VStack(alignment: .leading, spacing: BarabariSpacing.compact) {
                    sectionLabel("Security")
                    BarabariCard(padding: 0) {
                        VStack(spacing: 0) {
                            Toggle(isOn: Binding(
                                get: { lock.isEnabled },
                                set: { newValue in Task { await lock.setEnabled(newValue) } }
                            )) {
                                HStack(spacing: 14) {
                                    SettingsIcon(systemImage: lock.biometrySymbol, color: .green)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Lock with \(lock.biometryName)")
                                            .font(BarabariTypography.body)
                                        Text("Ask every time you open Barabari")
                                            .font(BarabariTypography.metadata)
                                            .foregroundStyle(BarabariColors.textSecondary)
                                    }
                                }
                            }
                            .tint(BarabariColors.accent)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 60)
                            .accessibilityIdentifier("app-lock-toggle")

                            RowDivider(leading: 58)

                            Button {
                                BarabariInteraction.trigger(.selection)
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.9)) { hasOnboarded = false }
                            } label: {
                                settingsRowContent(
                                    symbol: "sparkles",
                                    color: .purple,
                                    title: "Replay intro",
                                    detail: "See the welcome tour again"
                                )
                            }
                            .buttonStyle(.pressable)
                            .barabariHitTarget(minHeight: 56)
                        }
                    }
                }
                .staggeredAppear(3)

                VStack(alignment: .leading, spacing: BarabariSpacing.compact) {
                    sectionLabel("Your data")
                    BarabariCard(padding: 0) {
                        VStack(spacing: 0) {
                            Button {
                                isShowingPrivacy = true
                            } label: {
                                settingsRowContent(
                                    symbol: "hand.raised.fill",
                                    color: .blue,
                                    title: "Privacy",
                                    detail: "Stored on this iPhone"
                                )
                            }
                            .buttonStyle(.pressable)
                            .barabariHitTarget(minHeight: 56)
                            .accessibilityHint("Explain local-only storage")

                            RowDivider(leading: 58)

                            VStack(alignment: .leading, spacing: BarabariSpacing.row) {
                                HStack(spacing: 14) {
                                    SettingsIcon(systemImage: "square.and.arrow.up.fill", color: .orange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Export data")
                                            .font(BarabariTypography.body)
                                        Text(viewModel.exportStatus)
                                            .font(BarabariTypography.metadata)
                                            .foregroundStyle(BarabariColors.textSecondary)
                                            .contentTransition(.opacity)
                                    }
                                }

                                GlassEffectContainer(spacing: 8) {
                                    HStack(spacing: BarabariSpacing.compact) {
                                        exportButton(title: "Prepare JSON export", short: "JSON", format: .json)
                                        exportButton(title: "Prepare CSV export", short: "CSV", format: .csv)
                                    }
                                }

                                if let json = viewModel.preparedJSON {
                                    shareLink(item: json, subject: "Barabari JSON export", title: "Share JSON export")
                                        .accessibilityIdentifier("share-json-export")
                                }

                                if let csv = viewModel.preparedCSV {
                                    shareLink(item: csv, subject: "Barabari CSV export", title: "Share CSV export")
                                        .accessibilityIdentifier("share-csv-export")
                                }
                            }
                            .padding(14)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.preparedJSON)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.preparedCSV)
                        }
                    }
                }
                .staggeredAppear(4)

                VStack(spacing: 6) {
                    Image(systemName: "equal.circle.fill")
                        .font(.title2)
                        .foregroundStyle(BarabariColors.accent.gradient)
                    Text(isDemo ? "Local demo: data stays on this iPhone."
                         : syncEngine == nil ? "Local ledger: data stays on this iPhone."
                         : "Shared through Barabari Cloud. Barabari never moves money.")
                        .font(BarabariTypography.metadata)
                        .foregroundStyle(BarabariColors.textSecondary)
                        .accessibilityIdentifier("local-demo-status")
                    Text("Barabari · Split fairly. Settle simply.")
                        .font(.caption2)
                        .foregroundStyle(BarabariColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .staggeredAppear(5)
            }
            .padding(.top, 4)
            .barabariScreen()
        }
        .scrollIndicators(.hidden)
        .background(BarabariColors.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $isEditingName) {
            PersonNameSheet(title: "Your name", initialName: metadata.ownerName, actionTitle: "Save") { name in
                metadata.ownerName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                BarabariInteraction.trigger(.success)
                return true
            }
        }
        .sheet(isPresented: $isShowingPrivacy) {
            NavigationStack {
                VStack(spacing: BarabariSpacing.section) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundStyle(BarabariColors.accent.gradient)
                        .symbolEffect(.bounce, options: .nonRepeating)
                        .padding(.top, 12)
                    Text("Private by default")
                        .font(.title.weight(.bold))
                    Text("This demo stores its groups, expenses, settlements, and export data locally on this iPhone. There is no account, cloud sync, notification service, or payment connection in this build.")
                        .font(BarabariTypography.body)
                        .foregroundStyle(BarabariColors.textSecondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(BarabariSpacing.screen)
                .navigationTitle("Privacy")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
        .preferredColorScheme(viewModel.appearance.colorScheme)
    }

    private var profileCard: some View {
        Button {
            BarabariInteraction.trigger(.selection)
            isEditingName = true
        } label: {
            profileCardContent
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("edit-profile-name")
    }

    private var profileCardContent: some View {
        HStack(spacing: 16) {
            if metadata.ownerName.isEmpty {
                Circle()
                    .fill(BarabariColors.accent.gradient)
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(BarabariColors.onAccent)
                    }
            } else {
                MemberAvatar(name: metadata.ownerName, seed: AppEnvironment.demoUserID, size: 60)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(metadata.ownerName.isEmpty ? "Your space" : metadata.ownerName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(BarabariColors.textPrimary)
                Text(metadata.ownerName.isEmpty ? "Tap to add your name" : "Shown on reminders you share")
                    .font(BarabariTypography.metadata)
                    .foregroundStyle(BarabariColors.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "pencil.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(BarabariColors.accent)
        }
        .padding(16)
        .background(BarabariColors.surface, in: .rect(cornerRadius: BarabariSpacing.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: BarabariSpacing.cardRadius, style: .continuous)
                .strokeBorder(BarabariColors.hairline, lineWidth: 1)
        }
    }

    private var appearancePicker: some View {
        HStack(spacing: 12) {
            ForEach(BarabariAppearance.allCases) { appearance in
                let isSelected = viewModel.appearance == appearance
                Button {
                    BarabariInteraction.trigger(.selection)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        viewModel.appearance = appearance
                    }
                } label: {
                    VStack(spacing: 10) {
                        AppearanceSwatch(appearance: appearance)
                            .frame(height: 92)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(isSelected ? BarabariColors.accent : BarabariColors.hairline, lineWidth: isSelected ? 2.5 : 1)
                            }
                        HStack(spacing: 5) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected ? BarabariColors.accent : BarabariColors.textTertiary)
                                .contentTransition(.symbolEffect(.replace))
                            Text(LocalizedStringKey(appearance.title))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(BarabariColors.textPrimary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(appearance.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(14)
        .background(BarabariColors.surface, in: .rect(cornerRadius: BarabariSpacing.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: BarabariSpacing.cardRadius, style: .continuous)
                .strokeBorder(BarabariColors.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appearance-picker")
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(LocalizedStringKey(title))
            .font(BarabariTypography.eyebrow)
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(BarabariColors.textSecondary)
            .padding(.horizontal, 4)
    }

    private func shareLink(item: String, subject: String, title: String) -> some View {
        ShareLink(item: item, subject: Text(subject)) {
            Label(title, systemImage: "square.and.arrow.up")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.glassProminent)
        .tint(BarabariColors.accent)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func settingsRowContent(symbol: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            SettingsIcon(systemImage: symbol, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title))
                    .font(BarabariTypography.body)
                    .foregroundStyle(BarabariColors.textPrimary)
                Text(LocalizedStringKey(detail))
                    .font(BarabariTypography.metadata)
                    .foregroundStyle(BarabariColors.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(BarabariColors.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func exportButton(title: String, short: String, format: LocalLedgerExportFormat) -> some View {
        Button {
            BarabariInteraction.trigger(.selection)
            Task { await viewModel.prepareExport(format: format) }
        } label: {
            Label(short, systemImage: format == .json ? "curlybraces" : "tablecells")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BarabariColors.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .glassEffect(.regular.interactive(), in: .capsule)
        .disabled(viewModel.isPreparingExport)
        .accessibilityLabel(title)
    }
}

/// iOS Settings–style rounded icon.
private struct SettingsIcon: View {
    let systemImage: String
    let color: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(color.gradient, in: .rect(cornerRadius: 8))
            .accessibilityHidden(true)
    }
}

/// Miniature preview of the app chrome in each appearance.
private struct AppearanceSwatch: View {
    let appearance: BarabariAppearance

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                switch appearance {
                case .light:
                    swatch(background: Color(white: 0.95), card: .white, line: Color(white: 0.85))
                case .dark:
                    swatch(background: .black, card: Color(white: 0.12), line: Color(white: 0.25))
                case .system:
                    HStack(spacing: 0) {
                        swatch(background: Color(white: 0.95), card: .white, line: Color(white: 0.85))
                            .frame(width: proxy.size.width / 2)
                            .clipped()
                        swatch(background: .black, card: Color(white: 0.12), line: Color(white: 0.25))
                            .frame(width: proxy.size.width / 2)
                            .clipped()
                    }
                }
            }
        }
        .clipShape(.rect(cornerRadius: 16))
    }

    private func swatch(background: Color, card: Color, line: Color) -> some View {
        ZStack(alignment: .topLeading) {
            background
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LinearGradient(colors: [BarabariColors.brandForest, BarabariColors.brandEmerald], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 30)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(card)
                    .frame(height: 14)
                    .overlay(alignment: .leading) {
                        Capsule().fill(line).frame(width: 28, height: 4).padding(.leading, 6)
                    }
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(card)
                    .frame(height: 14)
            }
            .padding(10)
        }
    }
}
