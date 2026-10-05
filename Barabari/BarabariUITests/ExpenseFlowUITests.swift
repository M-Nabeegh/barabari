import XCTest

final class ExpenseFlowUITests: XCTestCase {
    func testEqualExpenseShowsPreviewAndLocalConfirmation() {
        let app = makeDemoApp()
        app.launch()

        app.buttons["Add"].tap()

        enterAmount("1250", in: app)

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

        let saveButton = app.buttons["Save expense"]
        saveButton.tap()
        if saveButton.waitForExistence(timeout: 0.5) {
            saveButton.tap()
        }

        XCTAssertTrue(app.staticTexts["Expense saved locally"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Add another expense"].exists)
    }

    func testExactSplitExplainsInvalidTotalNextToSplitField() {
        let app = makeDemoApp()
        app.launch()

        app.buttons["Add"].tap()
        enterAmount("1200", in: app)

        let title = app.textFields["expense-title"]
        title.tap()
        title.typeText("Groceries")
        dismissKeyboard(in: app)

        app.buttons["Exact amount"].tap()
        let exactAmount = app.textFields["exact-split-amount-56D75B9A-0238-45B6-9EF7-A3526D58B2A5"]
        XCTAssertTrue(exactAmount.waitForExistence(timeout: 2))
        XCTAssertEqual(exactAmount.label, "Exact share for You")
        exactAmount.tap()
        exactAmount.typeText("1000")
        dismissKeyboard(in: app)

        app.buttons["Save expense"].tap()

        let exactTotalError = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Exact amounts must add up")
        ).firstMatch
        XCTAssertTrue(exactTotalError.waitForExistence(timeout: 2))
    }

    func testExactExpenseChangesPayerAndParticipantsThenSavesDistinctShares() {
        let app = makeDemoApp(withSecondMember: true)
        app.launch()

        app.buttons["Add"].tap()
        enterAmount("1250", in: app)
        enter("Groceries", into: app.textFields["expense-title"], in: app)

        app.buttons["Paid by"].tap()
        app.buttons["Member 2"].tap()

        let friend = app.buttons["Split with Member 2"]
        XCTAssertTrue(friend.waitForExistence(timeout: 2))
        friend.tap()
        XCTAssertFalse(friend.isSelected)
        friend.tap()
        XCTAssertTrue(friend.isSelected)

        app.buttons["Exact amount"].tap()
        let yourShare = app.textFields["exact-split-amount-56D75B9A-0238-45B6-9EF7-A3526D58B2A5"]
        let friendShare = app.textFields["exact-split-amount-A1D2E3F4-5A6B-4C7D-8E9F-001122334455"]
        XCTAssertTrue(yourShare.waitForExistence(timeout: 2))
        XCTAssertTrue(friendShare.waitForExistence(timeout: 2))
        XCTAssertEqual(yourShare.label, "Exact share for You")
        XCTAssertEqual(friendShare.label, "Exact share for Member 2")
        enter("500", into: yourShare, in: app)
        enter("750", into: friendShare, in: app)

        app.buttons["Save expense"].tap()

        XCTAssertTrue(app.staticTexts["Expense saved locally"].waitForExistence(timeout: 2))
    }

    private func makeDemoApp(withSecondMember: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingDemoState"] + (withSecondMember ? ["-uiTestingSecondMember"] : [])
        return app
    }

    /// Types on the custom keypad, then moves on to the details step.
    private func enterAmount(_ digits: String, in app: XCUIApplication) {
        XCTAssertTrue(app.descendants(matching: .any)["expense-amount"].waitForExistence(timeout: 2))
        for digit in digits {
            app.buttons["keypad-\(digit)"].tap()
        }
        app.buttons["expense-continue"].tap()
        XCTAssertTrue(app.textFields["expense-title"].waitForExistence(timeout: 2))
    }

    private func enter(_ text: String, into field: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(field.waitForExistence(timeout: 2))
        field.tap()
        field.typeText(text)
        dismissKeyboard(in: app)
    }

    private func dismissKeyboard(in app: XCUIApplication) {
        let done = app.buttons["Done"].firstMatch
        if done.waitForExistence(timeout: 1) {
            done.tap()
        } else {
            app.keyboards.buttons["return"].tap()
        }
    }
}
