import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var appearanceStatus = "Follows your iPhone"
    @Published private(set) var notificationsStatus = "Not configured yet"
    @Published private(set) var privacyStatus = "Stored on this iPhone"
    @Published private(set) var exportStatus = "Available after sync"
    @Published private(set) var deletionStatus = "Available after account sync"

    func availabilityMessage(for feature: SettingsFeature) -> String {
        switch feature {
        case .appearance: "Appearance already follows your iPhone’s Light or Dark setting. More choices are coming later."
        case .notifications: "Notifications are not configured in this local demo yet."
        case .privacy: "This demo keeps its ledger on this iPhone. Cloud sync is not active."
        case .export: "Export will be available after account sync is added."
        case .deleteAccount: "Account deletion becomes available once account sync is added."
        }
    }
}

enum SettingsFeature: Identifiable {
    case appearance
    case notifications
    case privacy
    case export
    case deleteAccount

    var id: String { title }

    var title: String {
        switch self {
        case .appearance: "Appearance"
        case .notifications: "Notifications"
        case .privacy: "Privacy"
        case .export: "Export data"
        case .deleteAccount: "Delete account"
        }
    }

    var symbol: String {
        switch self {
        case .appearance: "circle.lefthalf.filled"
        case .notifications: "bell"
        case .privacy: "hand.raised.fill"
        case .export: "square.and.arrow.up"
        case .deleteAccount: "person.crop.circle.badge.minus"
        }
    }
}
