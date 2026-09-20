import XCTest

final class ExpenseFlowUITests: XCTestCase {
    func testEqualExpenseShowsPreviewAndLocalConfirmation() {
        let app = makeDemoApp()
        app.launch()

        app.buttons["Add"].tap()

        let amount = app.textFields["expense-amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 2))
        amount.tap()
        amount.typeText("1250")
        dismissKeyboard(in: app)

        let title = app.textFields["expense-title"]
        XCTAssertTrue(title.exists)
        title.tap()
        title.typeText("Dinner")
        dismissKeyboard(in: app)

        XCTAssertTrue(app.buttons["Barabari Demo"].exists)
        XCTAssertTrue(app.staticTexts["Paid by"].exists)
        XCTAssertTrue(app.staticTexts["Split with"].exists)

        app.buttons["Equal split"].tap()
        XCTAssertTrue(app.staticTexts["Split preview"].exists)
        XCTAssertTrue(app.staticTexts["You"].exists)

        app.buttons["Save expense"].tap()

        XCTAssertTrue(app.staticTexts["Expense saved locally"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Add another expense"].exists)
    }

    func testExactSplitExplainsInvalidTotalNextToSplitField() {
        let app = makeDemoApp()
        app.launch()

        app.buttons["Add"].tap()
        let amount = app.textFields["expense-amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 2))
        amount.tap()
        amount.typeText("1200")
        dismissKeyboard(in: app)

        let title = app.textFields["expense-title"]
        title.tap()
        title.typeText("Groceries")
        dismissKeyboard(in: app)

        app.buttons["Exact amount"].tap()
        let exactAmount = app.textFields["exact-split-amount"]
        XCTAssertTrue(exactAmount.waitForExistence(timeout: 2))
        exactAmount.tap()
        exactAmount.typeText("1000")
        dismissKeyboard(in: app)

        app.buttons["Save expense"].tap()

        let exactTotalError = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Exact amounts must add up")
        ).firstMatch
        XCTAssertTrue(exactTotalError.waitForExistence(timeout: 2))
    }

    private func makeDemoApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingDemoState"]
        return app
    }

    private func dismissKeyboard(in app: XCUIApplication) {
        let done = app.buttons["Done"]
        if done.waitForExistence(timeout: 1) {
            done.tap()
        } else {
            app.keyboards.buttons["return"].tap()
        }
    }
}
