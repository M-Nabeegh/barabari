import XCTest
@testable import Barabari

@MainActor
final class LedgerSessionTests: XCTestCase {
    func testMarkChangedAdvancesRevision() {
        let session = LedgerSession()
        let initialRevision = session.revision

        session.markChanged()

        XCTAssertEqual(session.revision, initialRevision + 1)
    }

    func testAddExpenseViewModelIsNotResetBySessionChanges() {
        let environment = AppEnvironment.demo
        let viewModel = AddExpenseViewModel(environment: environment)
        viewModel.title = "Dinner"
        let session = LedgerSession()

        session.markChanged()

        XCTAssertEqual(viewModel.title, "Dinner")
    }
}
