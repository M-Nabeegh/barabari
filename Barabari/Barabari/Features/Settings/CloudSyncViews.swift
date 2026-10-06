import SwiftUI

extension SyncEngine.Status {
    var title: String {
        switch self {
        case .off: "On this iPhone"
        case .idle: "Synced"
        case .syncing: "Syncing"
        case .offline: "Offline"
        case .failed: "Sync paused"
        }
    }

    var systemImage: String {
        switch self {
        case .off: "lock.fill"
        case .idle: "checkmark.icloud.fill"
        case .syncing: "arrow.triangle.2.circlepath.icloud.fill"
        case .offline: "icloud.slash.fill"
        case .failed: "exclamationmark.icloud.fill"
        }
    }
}

/// Small glass pill for the balance card: how fresh the shared ledger is.
struct SyncStatusPill: View {
    @ObservedObject var engine: SyncEngine

    var body: some View {
        Label(engine.status.title, systemImage: engine.status.systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))
            .symbolEffect(.pulse, isActive: engine.status == .syncing)
            .contentTransition(.symbolEffect(.replace))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.clear, in: .capsule)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: engine.status)
            .accessibilityLabel("Cloud sync: \(engine.status.title)")
    }
}

/// Settings row describing Barabari Cloud with a manual “Sync now”.
struct CloudSyncRow: View {
    @ObservedObject var engine: SyncEngine
    @State private var spin = 0

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "icloud.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Color.cyan.gradient, in: .rect(cornerRadius: 8))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Barabari Cloud")
                    .font(BarabariTypography.body)
                Text(detail)
                    .font(BarabariTypography.metadata)
                    .foregroundStyle(detailColor)
                    .lineLimit(2)
                    .contentTransition(.opacity)
            }
            Spacer(minLength: 8)
            Button {
                BarabariInteraction.trigger(.selection)
                spin += 1
                Task { await engine.syncNow(full: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BarabariColors.accent)
                    .symbolEffect(.rotate, value: spin)
                    .frame(width: 38, height: 38)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .disabled(engine.status == .syncing)
            .accessibilityLabel("Sync now")
            .accessibilityIdentifier("sync-now")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 60)
        .animation(.easeOut(duration: 0.2), value: engine.status)
    }

    private var detail: String {
        switch engine.status {
        case .syncing:
            return "Syncing your groups…"
        case .offline:
            return "Offline. Changes are saved and will sync later."
        case let .failed(message):
            return message
        case .idle, .off:
            guard let last = engine.lastSyncedAt else { return "Shared with everyone in your groups" }
            return "Synced \(last.formatted(.relative(presentation: .named)))"
        }
    }

    private var detailColor: Color {
        if case .failed = engine.status { return BarabariColors.warning }
        return BarabariColors.textSecondary
    }
}
