import XCTest

final class BarabariUITests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["Barabari"].exists)
    }
}

