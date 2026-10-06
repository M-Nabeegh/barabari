import XCTest

final class MoneyFlowUITests: XCTestCase {
    func testJustMeExpenseShowsUpInMoney() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingDemoState"]
        app.launch()

        app.buttons["Money"].tap()
        XCTAssertTrue(app.staticTexts["Wallets"].waitForExistence(timeout: 10))
        app.buttons["money-add"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["expense-amount"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Just me"].exists)
        for digit in "750" {
            app.buttons["keypad-\(digit)"].tap()
        }
        app.buttons["expense-continue"].tap()

        let title = app.textFields["expense-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        title.tap()
        title.typeText("Chai and samosa\n")
        app.buttons["save-personal"].tap()

        XCTAssertTrue(app.staticTexts["Expense saved"].waitForExistence(timeout: 10))

        app.buttons["Money"].tap()
        XCTAssertTrue(app.staticTexts["Chai and samosa"].waitForExistence(timeout: 10))
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "Chai and samosa", "750")).firstMatch
        XCTAssertTrue(row.exists, "the history row shows the amount")
    }
}
