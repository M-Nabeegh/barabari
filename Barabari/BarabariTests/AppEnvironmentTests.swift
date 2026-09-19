import SwiftData
import XCTest
@testable import Barabari

@MainActor
final class AppEnvironmentTests: XCTestCase {
    func testDemoActivityRecordsUsePKR() throws {
        let environment = AppEnvironment.demo
        let records = try environment.modelContainer.mainContext.fetch(FetchDescriptor<ActivityRecord>())

        XCTAssertFalse(records.isEmpty)
        XCTAssertTrue(records.allSatisfy { $0.currencyCode == "PKR" })
    }
}

