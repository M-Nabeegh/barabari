import Foundation

/// The small slice of the ledger the home screen widget shows, shared through the app group.
struct WidgetSnapshot: Codable, Equatable {
    struct GroupLine: Codable, Equatable, Identifiable {
        let id: UUID
        let name: String
    }

    var netMinorUnits: Int64
    var owedMinorUnits: Int64
    var owingMinorUnits: Int64
    var groups: [GroupLine]
    var updatedAt: Date

    static let appGroup = "group.com.nabeegh.Barabari"
    static let storageKey = "barabari.widgetSnapshot"

    static let placeholder = WidgetSnapshot(
        netMinorUnits: 565_000,
        owedMinorUnits: 765_000,
        owingMinorUnits: 200_000,
        groups: [GroupLine(id: UUID(), name: "Hunza trip"), GroupLine(id: UUID(), name: "Flat 4B")],
        updatedAt: .now
    )

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.appGroup)?.set(data, forKey: Self.storageKey)
    }
}
