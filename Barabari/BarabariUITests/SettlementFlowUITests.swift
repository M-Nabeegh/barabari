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

        XCTAssertTrue(app.descendants(matching: .any)["settlement-amount"].waitForExistence(timeout: 2))
        for digit in "500" {
            app.buttons["keypad-\(digit)"].tap()
        }
        app.buttons["settlement-continue"].tap()

        app.buttons["Raast"].tap()
        app.swipeUp()
        let markAsPaid = app.buttons["Mark as paid"]
        markAsPaid.tap()
        if markAsPaid.waitForExistence(timeout: 0.5) {
            markAsPaid.tap()
        }

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

    func testAddedPersonAppearsByNameInGroupAndExpenseSplit() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingDemoState"]
        app.launch()

        app.buttons["Groups"].tap()
        XCTAssertTrue(app.buttons["Barabari Demo"].waitForExistence(timeout: 2))
        app.buttons["Barabari Demo"].tap()

        let addPerson = app.buttons["add-person"]
        XCTAssertTrue(addPerson.waitForExistence(timeout: 2))
        addPerson.tap()

        let name = app.textFields["person-name-field"]
        XCTAssertTrue(name.waitForExistence(timeout: 2))
        name.typeText("Ali")
        app.buttons["person-name-save"].tap()

        XCTAssertTrue(app.staticTexts["Ali"].waitForExistence(timeout: 2))

        app.buttons["Add"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["expense-amount"].waitForExistence(timeout: 2))
        for digit in "900" {
            app.buttons["keypad-\(digit)"].tap()
        }
        app.buttons["expense-continue"].tap()
        XCTAssertTrue(app.buttons["Split with Ali"].waitForExistence(timeout: 2))
    }
}
