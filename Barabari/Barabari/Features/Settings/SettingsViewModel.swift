import Combine
import Foundation
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var appearance: BarabariAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Self.appearanceUserDefaultsKey) }
    }
    @Published var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: BarabariInteraction.hapticsUserDefaultsKey) }
    }
    @Published private(set) var exportStatus = "Ready to share a local copy"
    @Published private(set) var preparedJSON: String?
    @Published private(set) var preparedCSV: String?
    @Published private(set) var isPreparingExport = false

    private static let appearanceUserDefaultsKey = "barabari.appearance"
    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        appearance = BarabariAppearance(rawValue: UserDefaults.standard.string(forKey: Self.appearanceUserDefaultsKey) ?? "system") ?? .system
        hapticsEnabled = UserDefaults.standard.object(forKey: BarabariInteraction.hapticsUserDefaultsKey) as? Bool ?? true
    }

    func prepareExport(format: LocalLedgerExportFormat) async {
        guard !isPreparingExport else { return }
        isPreparingExport = true
        exportStatus = "Preparing local export..."
        defer { isPreparingExport = false }

        do {
            let groups = try await environment.groupRepository.listGroups()
            var expenses: [Expense] = []
            var settlements: [Settlement] = []
            for group in groups {
                expenses += try await allExpenses(groupID: group.id)
                settlements += try await allSettlements(groupID: group.id)
            }
            switch format {
            case .json:
                preparedJSON = try LocalLedgerExport.json(groups: groups, expenses: expenses, settlements: settlements)
                exportStatus = "JSON export ready to share"
            case .csv:
                preparedCSV = LocalLedgerExport.csv(groups: groups, expenses: expenses, settlements: settlements)
                exportStatus = "CSV export ready to share"
            }
        } catch {
            exportStatus = "Could not prepare export. Try again."
        }
    }

    private func allExpenses(groupID: UUID) async throws -> [Expense] {
        var cursor: String?
        var expenses: [Expense] = []
        repeat {
            let page = try await environment.expenseRepository.listExpenses(groupID: groupID, cursor: cursor)
            expenses += page.items
            cursor = page.nextCursor
        } while cursor != nil
        return expenses
    }

    private func allSettlements(groupID: UUID) async throws -> [Settlement] {
        var cursor: String?
        var settlements: [Settlement] = []
        repeat {
            let page = try await environment.settlementRepository.listSettlements(groupID: groupID, cursor: cursor)
            settlements += page.items
            cursor = page.nextCursor
        } while cursor != nil
        return settlements
    }
}

enum LocalLedgerExportFormat {
    case json
    case csv
}

enum BarabariAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
