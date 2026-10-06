import XCTest

final class NavigationUITests: XCTestCase {
    func testAllPrimaryDestinationsAreReachableInDemoMode() {
        let app = makeApp(arguments: ["-uiTestingDemoState"])
        app.launch()

        XCTAssertTrue(app.staticTexts["Group created"].waitForExistence(timeout: 10))

        for tab in ["Home", "Groups", "Add", "Activity", "Settings"] {
            let button = app.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 10), "Expected \(tab) to be available in main navigation")
            button.tap()
            XCTAssertTrue(button.isSelected || app.navigationBars[tab == "Add" ? "Add expense" : tab].exists)
        }
    }

    func testPrimaryDestinationsStayReachableAfterRepeatedSwitching() {
        let app = makeApp(arguments: ["-uiTestingDemoState"])
        app.launch()

        XCTAssertTrue(app.staticTexts["Group created"].waitForExistence(timeout: 10))

        for _ in 0..<2 {
            for tab in ["Home", "Groups", "Add", "Activity", "Settings"] {
                let button = app.buttons[tab]
                XCTAssertTrue(button.waitForExistence(timeout: 10))
                button.tap()
            }
        }

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
    }

    func testSwitchingTabsFromAmountEntryTakesOneTap() {
        let app = makeApp(arguments: ["-uiTestingDemoState"])
        app.launch()

        app.buttons["Add"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["expense-amount"].waitForExistence(timeout: 10))
        app.buttons["keypad-4"].tap()

        // The custom keypad never raises the system keyboard, so the tab bar stays reachable.
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        app.buttons["Settings"].tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
    }

    func testEmptyGroupsOfferCreateAndJoin() {
        let app = makeApp(arguments: ["-uiTestingEmptyState"])
        app.launch()

        app.buttons["Groups"].tap()

        XCTAssertTrue(app.staticTexts["No groups yet"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Create group"].exists)
        XCTAssertTrue(app.buttons["Join group"].exists)
    }

    func testActivityRowsOpenDetailAndSettingsShowsWorkingLocalActions() {
        let app = makeApp(arguments: ["-uiTestingDemoState", "-uiTestingDebtState"])
        app.launch()

        app.buttons["Activity"].tap()
        let activityRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'activity-row-'" )).firstMatch
        XCTAssertTrue(activityRow.waitForExistence(timeout: 10))
        activityRow.tap()
        XCTAssertTrue(app.navigationBars["Expense"].waitForExistence(timeout: 10))

        app.buttons["BackButton"].tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Local demo: data stays on this iPhone."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Prepare JSON export"].exists)
        XCTAssertTrue(app.buttons["Prepare CSV export"].exists)
        XCTAssertFalse(app.buttons["Notifications"].exists)
        XCTAssertFalse(app.buttons["Delete account"].exists)

        app.buttons["Prepare JSON export"].tap()
        XCTAssertTrue(app.buttons["Share JSON export"].waitForExistence(timeout: 10))
    }

    func testSeededGroupOpensItsDetail() {
        let app = makeApp(arguments: ["-uiTestingDemoState"])
        app.launch()

        app.buttons["Groups"].tap()
        let demoGroup = app.buttons["Barabari Demo"]
        XCTAssertTrue(demoGroup.waitForExistence(timeout: 10))
        demoGroup.tap()

        XCTAssertTrue(app.navigationBars["Barabari Demo"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Everyone is settled up."].exists)
        XCTAssertTrue(app.staticTexts["You"].exists)
    }

    private func makeApp(arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        return app
    }
}
