import XCTest

final class BarabariLaunchTests: XCTestCase {
    func testLaunchConfigurationHasBarabariDisplayName() throws {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, "Barabari")
    }
}

