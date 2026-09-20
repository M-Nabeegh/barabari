import XCTest

final class SettlementFlowUITests: XCTestCase {
    func testDebtCardRecordsPartialRaastSettlementAndShowsItInActivity() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingDemoState", "-uiTestingSecondMember", "-uiTestingDebtState"]
        app.launch()

        app.buttons["Groups"].tap()
        XCTAssertTrue(app.buttons["Barabari Demo"].waitForExistence(timeout: 2))
        app.buttons["Barabari Demo"].tap()

        let debtCard = app.buttons["You owe"]
        XCTAssertTrue(debtCard.waitForExistence(timeout: 2))
        debtCard.tap()

        let amount = app.textFields["settlement-amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 2))
        amount.tap()
        amount.typeText("500")
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 2))
        done.tap()

        app.buttons["Raast"].tap()
        app.swipeUp()
        app.buttons["Mark as paid"].tap()

        XCTAssertTrue(app.staticTexts["Settlement recorded locally"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Raast payment to Member 2 is now in this group’s ledger on this iPhone."].exists)

        app.navigationBars["Settle up"].buttons["Barabari Demo"].tap()
        let remainingDebt = app.buttons["You owe"]
        XCTAssertTrue(remainingDebt.waitForExistence(timeout: 2))
        XCTAssertTrue((remainingDebt.value as? String ?? "").contains("500"))
        app.navigationBars["Barabari Demo"].buttons["Groups"].tap()
        app.buttons["Activity"].tap()
        XCTAssertTrue(app.staticTexts["Settlement recorded"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Raast")).firstMatch.exists)
    }
}
