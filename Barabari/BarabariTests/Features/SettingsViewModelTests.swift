import XCTest
@testable import Barabari

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testJSONExportUsesDomainValuesWithoutPersistenceInternals() throws {
        let group = Group(name: "Trip", description: "Shared costs", ownerID: UUID())
        let export = try LocalLedgerExport.json(groups: [group], expenses: [], settlements: [])

        XCTAssertTrue(export.contains("Trip"))
        XCTAssertTrue(export.contains("Shared costs"))
        XCTAssertFalse(export.contains("StoredGroup"))
        XCTAssertFalse(export.contains("modelContainer"))
    }

    func testHapticsPreferencePersistsThroughSettingsViewModel() {
        defer { UserDefaults.standard.removeObject(forKey: BarabariInteraction.hapticsUserDefaultsKey) }

        let viewModel = SettingsViewModel(environment: .demo)
        viewModel.hapticsEnabled = false

        XCTAssertFalse(UserDefaults.standard.bool(forKey: BarabariInteraction.hapticsUserDefaultsKey))
        XCTAssertFalse(viewModel.hapticsEnabled)
    }
}
