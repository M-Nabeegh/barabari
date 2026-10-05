import SwiftUI
import WidgetKit

@main
struct BarabariWidgetBundle: WidgetBundle {
    var body: some Widget {
        BalanceWidget()
    }
}

struct BalanceEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let isPlaceholder: Bool
}

struct BalanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> BalanceEntry {
        BalanceEntry(date: .now, snapshot: .placeholder, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (BalanceEntry) -> Void) {
        let snapshot = WidgetSnapshot.load()
        completion(BalanceEntry(date: .now, snapshot: snapshot ?? .placeholder, isPlaceholder: snapshot == nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BalanceEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load()
        let entry = BalanceEntry(date: .now, snapshot: snapshot ?? .placeholder, isPlaceholder: snapshot == nil)
        // The app reloads timelines whenever the ledger changes; this is only a safety refresh.
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60 * 60))))
    }
}

struct BalanceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BarabariBalance", provider: BalanceProvider()) { entry in
            BalanceWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(red: 0.01, green: 0.17, blue: 0.13), Color(red: 0.02, green: 0.37, blue: 0.27), Color(red: 0.06, green: 0.73, blue: 0.51)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .widgetURL(URL(string: "barabari://home"))
        }
        .configurationDisplayName("Balance")
        .description("Your net Barabari balance at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct BalanceWidgetView: View {
    let entry: BalanceEntry
    @Environment(\.widgetFamily) private var family

    private var snapshot: WidgetSnapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("Barabari \(signed(snapshot.netMinorUnits))")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("Barabari", systemImage: "equal.circle.fill")
                    .font(.caption2.weight(.semibold))
                Text(signed(snapshot.netMinorUnits))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .widgetAccentable()
                Text(summary)
                    .font(.caption2)
            }
        case .systemMedium:
            HStack(spacing: 16) {
                balance
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 10) {
                    metric("You are owed", snapshot.owedMinorUnits, symbol: "arrow.down.left")
                    metric("You owe", snapshot.owingMinorUnits, symbol: "arrow.up.right")
                }
                .frame(maxWidth: 150, alignment: .leading)
            }
            .foregroundStyle(.white)
        default:
            balance
                .foregroundStyle(.white)
        }
    }

    private var balance: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "equal.circle.fill")
                Text("Net balance")
                    .textCase(.uppercase)
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white.opacity(0.8))

            Spacer(minLength: 0)

            Text(signed(snapshot.netMinorUnits))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText(value: Double(snapshot.netMinorUnits)))
                .redacted(reason: entry.isPlaceholder ? .placeholder : [])

            Text(summary)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(2)
        }
    }

    private func metric(_ title: String, _ minorUnits: Int64, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.caption2.weight(.bold))
                .frame(width: 22, height: 22)
                .background(.white.opacity(0.18), in: .circle)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
                Text(format(minorUnits))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private var summary: String {
        switch snapshot.netMinorUnits {
        case 0: "All settled up"
        case let net where net > 0: "You are owed"
        default: "You owe overall"
        }
    }

    private func signed(_ minorUnits: Int64) -> String {
        minorUnits < 0 ? "−" + format(-minorUnits) : format(minorUnits)
    }

    private func format(_ minorUnits: Int64) -> String {
        let whole = (minorUnits / 100).formatted(.number.grouping(.automatic))
        return "Rs \(whole)"
    }
}

#Preview(as: .systemSmall) {
    BalanceWidget()
} timeline: {
    BalanceEntry(date: .now, snapshot: .placeholder, isPlaceholder: false)
}
