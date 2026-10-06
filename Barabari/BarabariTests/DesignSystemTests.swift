import UIKit
import XCTest
@testable import Barabari

final class DesignSystemTests: XCTestCase {
    func testAccentIsEmeraldAndBrightensInDarkMode() {
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

        // Green leads in both appearances so the brand reads as emerald.
        XCTAssertGreaterThan(lightGreen, lightRed)
        XCTAssertGreaterThan(lightGreen, lightBlue)
        XCTAssertGreaterThan(darkGreen, darkRed)
        XCTAssertGreaterThan(darkGreen, darkBlue)
        // Dark mode uses a lighter emerald to keep contrast on black.
        XCTAssertGreaterThan(darkGreen, lightGreen)
    }

    func testSpacingScaleIsStable() {
        XCTAssertEqual(BarabariSpacing.screen, 20)
        XCTAssertEqual(BarabariSpacing.section, 28)
    }

    func testAmountFormatterConvertsPaisaAndGroupsPKR() {
        XCTAssertEqual(
            AmountFormatter.string(minorUnits: 325_050, currencyCode: "PKR"),
            "Rs\u{00A0}3,250.5"
        )
    }

    func testAmountFormatterFormatsZeroAndNegativePKRAmounts() {
        XCTAssertEqual(AmountFormatter.string(minorUnits: 0, currencyCode: "PKR"), "Rs\u{00A0}0")
        XCTAssertEqual(AmountFormatter.string(minorUnits: -12_345, currencyCode: "PKR"), "-Rs\u{00A0}123.45")
    }

    func testAmountFormatterPreservesNonPKRCurrencyCode() {
        XCTAssertEqual(AmountFormatter.string(minorUnits: 123_456, currencyCode: "USD"), "USD\u{00A0}1,234.56")
    }

    func testTabBarDefinesAllPrimaryTabs() {
        XCTAssertEqual(AppTab.allCases, [.home, .groups, .money, .addExpense, .activity])
    }

    func testInteractiveControlsUseAppleMinimumHitSize() {
        XCTAssertEqual(BarabariInteraction.minimumHitSize, 44)
    }
}
