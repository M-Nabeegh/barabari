import XCTest
@testable import Barabari

final class DesignSystemTests: XCTestCase {
    func testSpacingScaleIsStable() {
        XCTAssertEqual(BarabariSpacing.screen, 16)
        XCTAssertEqual(BarabariSpacing.section, 26)
    }

    func testAmountFormatterConvertsPaisaAndGroupsPKR() {
        XCTAssertEqual(
            AmountFormatter.string(minorUnits: 325_050, currencyCode: "PKR"),
            "PKR\u{00A0}3,250.5"
        )
    }

    func testAmountFormatterFormatsZeroAndNegativePKRAmounts() {
        XCTAssertEqual(AmountFormatter.string(minorUnits: 0, currencyCode: "PKR"), "PKR\u{00A0}0")
        XCTAssertEqual(AmountFormatter.string(minorUnits: -12_345, currencyCode: "PKR"), "-PKR\u{00A0}123.45")
    }

    func testAmountFormatterPreservesNonPKRCurrencyCode() {
        XCTAssertEqual(AmountFormatter.string(minorUnits: 123_456, currencyCode: "USD"), "USD\u{00A0}1,234.56")
    }

    func testTabBarDefinesAllPrimaryTabs() {
        XCTAssertEqual(AppTab.allCases, [.home, .groups, .addExpense, .activity, .settings])
    }
}
