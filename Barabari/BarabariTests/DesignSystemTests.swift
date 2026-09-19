import XCTest
@testable import Barabari

final class DesignSystemTests: XCTestCase {
    func testSpacingScaleIsStable() {
        XCTAssertEqual(BarabariSpacing.screen, 16)
        XCTAssertEqual(BarabariSpacing.section, 26)
    }

    func testAmountFormatterUsesPKR() {
        let value = AmountFormatter.string(minorUnits: 325_000, currencyCode: "PKR")

        XCTAssertTrue(value.contains("PKR") || value.contains("Rs"))
    }

    func testTabBarDefinesAllPrimaryTabs() {
        XCTAssertEqual(AppTab.allCases, [.home, .groups, .addExpense, .activity, .settings])
    }
}
