import Combine
import Foundation

/// Local presentation metadata that sits beside the ledger: people's names and
/// expense categories. It lives outside SwiftData so the ledger schema stays
/// untouched until a sync backend owns these fields.
@MainActor
final class LedgerMetadata: ObservableObject {
    /// Replaced with an isolated store for UI tests so runs never see each other's names.
    static var shared = LedgerMetadata()

    @Published private(set) var names: [UUID: String]
    @Published private(set) var categories: [UUID: ExpenseCategory]
    @Published var ownerName: String {
        didSet { defaults.set(ownerName, forKey: Keys.ownerName) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let names = "barabari.metadata.names"
        static let categories = "barabari.metadata.categories"
        static let ownerName = "barabari.metadata.ownerName"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        names = Self.decode([UUID: String].self, from: defaults.data(forKey: Keys.names)) ?? [:]
        categories = Self.decode([UUID: ExpenseCategory].self, from: defaults.data(forKey: Keys.categories)) ?? [:]
        ownerName = defaults.string(forKey: Keys.ownerName) ?? ""
    }

    // MARK: People

    func setName(_ name: String, for userID: UUID) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        names[userID] = trimmed.isEmpty ? nil : trimmed
        persist(names, forKey: Keys.names)
    }

    /// "You" for the current user, a saved name when there is one, otherwise a stable fallback.
    func displayName(for userID: UUID, currentUserID: UUID, fallback: @autoclosure () -> String) -> String {
        if userID == currentUserID { return "You" }
        return names[userID] ?? fallback()
    }

    /// Name for a member of a group, falling back to their position in that group.
    func displayName(for userID: UUID, in members: [GroupMember], currentUserID: UUID) -> String {
        displayName(for: userID, currentUserID: currentUserID, fallback: {
            guard let index = members.firstIndex(where: { $0.userID == userID }) else { return "Group member" }
            return "Member \(index + 1)"
        }())
    }

    /// The current user's own name, for greetings and share cards.
    var ownerFirstName: String? {
        ownerName.split(separator: " ").first.map(String.init)
    }

    // MARK: Categories

    func setCategory(_ category: ExpenseCategory, for expenseID: UUID) {
        categories[expenseID] = category
        persist(categories, forKey: Keys.categories)
    }

    func category(for expense: Expense) -> ExpenseCategory {
        categories[expense.id] ?? ExpenseCategory.detect(from: expense.title) ?? .other
    }

    // MARK: Persistence

    private func persist<Value: Encodable>(_ value: Value, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, from data: Data?) -> Value? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
