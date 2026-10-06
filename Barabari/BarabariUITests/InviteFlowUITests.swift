import XCTest

final class InviteFlowUITests: XCTestCase {
    func testEmptyStateJoinShowsPasteAndScanControls() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingEmptyState"]
        app.launch()

        app.buttons["Groups"].tap()
        let joinButton = app.buttons["Join group"]
        XCTAssertTrue(joinButton.waitForExistence(timeout: 10))
        joinButton.tap()

        XCTAssertTrue(app.navigationBars["Join a group"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["Paste invite link"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["scan-qr"].exists)

        let field = app.textFields["Paste invite link"]
        field.tap()
        field.typeText("https://example.com")
        app.buttons["Check link"].tap()

        XCTAssertTrue(
            app.staticTexts["Use a Barabari invite link that starts with barabari://join."]
                .waitForExistence(timeout: 10)
        )
    }
}
