import XCTest

final class NavigationUITests: XCTestCase {
    func testAllPrimaryDestinationsAreReachableInDemoMode() {
        let app = makeApp(arguments: ["-uiTestingDemoState"])
        app.launch()

        XCTAssertTrue(app.staticTexts["Group created"].waitForExistence(timeout: 2))

        for tab in ["Home", "Groups", "Add", "Activity", "Settings"] {
            let button = app.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 2), "Expected \(tab) to be available in main navigation")
            button.tap()
            XCTAssertTrue(button.isSelected || app.navigationBars[tab == "Add" ? "Add expense" : tab].exists)
        }
    }

    func testPrimaryDestinationsStayReachableAfterRepeatedSwitching() {
        let app = makeApp(arguments: ["-uiTestingDemoState"])
        app.launch()

        XCTAssertTrue(app.staticTexts["Group created"].waitForExistence(timeout: 2))

        for _ in 0..<2 {
            for tab in ["Home", "Groups", "Add", "Activity", "Settings"] {
                let button = app.buttons[tab]
                XCTAssertTrue(button.waitForExistence(timeout: 2))
                button.tap()
            }
        }

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
    }

    func testEmptyGroupsOfferCreateAndJoin() {
        let app = makeApp(arguments: ["-uiTestingEmptyState"])
        app.launch()

        app.buttons["Groups"].tap()

        XCTAssertTrue(app.staticTexts["No groups yet"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Create group"].exists)
        XCTAssertTrue(app.buttons["Join group"].exists)
    }

    func testSeededGroupOpensItsDetail() {
        let app = makeApp(arguments: ["-uiTestingDemoState"])
        app.launch()

        app.buttons["Groups"].tap()
        let demoGroup = app.buttons["Barabari Demo"]
        XCTAssertTrue(demoGroup.waitForExistence(timeout: 2))
        demoGroup.tap()

        XCTAssertTrue(app.navigationBars["Barabari Demo"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Everyone is settled up."].exists)
        XCTAssertTrue(app.staticTexts["You"].exists)
    }

    private func makeApp(arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        return app
    }
}
