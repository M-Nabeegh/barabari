import UIKit
import XCTest
@testable import Barabari

final class DesignSystemTests: XCTestCase {
    func testAccentUsesInkInLightModeAndPearlInDarkMode() {
        let light = UIColor(BarabariColors.accent).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let dark = UIColor(BarabariColors.accent).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))

        var lightRed: CGFloat = 0
        var lightGreen: CGFloat = 0
        var lightBlue: CGFloat = 0
        var darkRed: CGFloat = 0
        var darkGreen: CGFloat = 0
        var darkBlue: CGFloat = 0
        XCTAssertTrue(light.getRed(&lightRed, green: &lightGreen, blue: &lightBlue, alpha: nil))
        XCTAssertTrue(dark.getRed(&darkRed, green: &darkGreen, blue: &darkBlue, alpha: nil))

        XCTAssertLessThan(lightRed, 0.15)
        XCTAssertLessThan(lightGreen, 0.16)
        XCTAssertLessThan(lightBlue, 0.17)
        XCTAssertGreaterThan(darkRed, 0.80)
        XCTAssertGreaterThan(darkGreen, 0.80)
        XCTAssertGreaterThan(darkBlue, 0.80)
    }

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

    func testInteractiveControlsUseAppleMinimumHitSize() {
        XCTAssertEqual(BarabariInteraction.minimumHitSize, 44)
    }
}
