import XCTest
@testable import Barabari

final class SplitCalculatorTests: XCTestCase {
    private let participantA = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let participantB = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let participantC = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    // Catches a change that gives the indivisible paisa to input order rather than UUID-byte order.
    func testEqualSplitAllocatesRemainderByStableUUIDOrder() throws {
        let splits = try SplitCalculator.calculate(
            total: Money(minorUnits: 10, currencyCode: "PKR"),
            participants: [participantC, participantA, participantB],
            method: .equal
        )

        XCTAssertEqual(splits, [
            ExpenseSplit(userID: participantA, amount: Money(minorUnits: 4, currencyCode: "PKR")),
            ExpenseSplit(userID: participantB, amount: Money(minorUnits: 3, currencyCode: "PKR")),
            ExpenseSplit(userID: participantC, amount: Money(minorUnits: 3, currencyCode: "PKR"))
        ])
        XCTAssertEqual(splits.map(\.amount.minorUnits).reduce(0, +), 10)
    }

    // Catches a change that loses or duplicates a paisa when an equal division is not exact.
    func testEqualSplitAlwaysConservesTheTotal() throws {
        let splits = try SplitCalculator.calculate(
            total: Money(minorUnits: 100, currencyCode: "PKR"),
            participants: [participantA, participantB, participantC],
            method: .equal
        )

        XCTAssertEqual(splits.map(\.amount.minorUnits).reduce(0, +), 100)
    }

    // Catches a change that accepts exact values whose sum differs from the expense total.
    func testExactSplitRejectsMismatchedTotal() {
        XCTAssertThrowsError(
            try SplitCalculator.calculate(
                total: Money(minorUnits: 1_000, currencyCode: "PKR"),
                participants: [participantA, participantB],
                method: .exact([participantA: 400, participantB: 500])
            )
        ) { error in
            XCTAssertEqual(error as? SplitError, .invalidExactTotal)
        }
    }

    // Catches a change that rejects a valid exact split or changes amounts during calculation.
    func testExactSplitPreservesEachSpecifiedAmount() throws {
        let splits = try SplitCalculator.calculate(
            total: Money(minorUnits: 1_000, currencyCode: "PKR"),
            participants: [participantB, participantA],
            method: .exact([participantA: 750, participantB: 250])
        )

        XCTAssertEqual(splits, [
            ExpenseSplit(userID: participantA, amount: Money(minorUnits: 750, currencyCode: "PKR")),
            ExpenseSplit(userID: participantB, amount: Money(minorUnits: 250, currencyCode: "PKR"))
        ])
        XCTAssertEqual(splits.map(\.amount.minorUnits).reduce(0, +), 1_000)
    }

    // Catches a change that accepts a percentage map which does not represent 100 percent.
    func testPercentageSplitRejectsValuesThatDoNotTotalOneHundredPercent() {
        XCTAssertThrowsError(
            try SplitCalculator.calculate(
                total: Money(minorUnits: 1_000, currencyCode: "PKR"),
                participants: [participantA, participantB],
                method: .percentage([participantA: 4_999, participantB: 5_000])
            )
        ) { error in
            XCTAssertEqual(error as? SplitError, .invalidPercentageTotal)
        }
    }

    // Catches a change that loses a rounded paisa in a valid percentage split.
    func testPercentageSplitConservesTotalWithBasisPoints() throws {
        let splits = try SplitCalculator.calculate(
            total: Money(minorUnits: 101, currencyCode: "PKR"),
            participants: [participantB, participantA],
            method: .percentage([participantA: 2_500, participantB: 7_500])
        )

        XCTAssertEqual(splits, [
            ExpenseSplit(userID: participantA, amount: Money(minorUnits: 25, currencyCode: "PKR")),
            ExpenseSplit(userID: participantB, amount: Money(minorUnits: 76, currencyCode: "PKR"))
        ])
        XCTAssertEqual(splits.map(\.amount.minorUnits).reduce(0, +), 101)
    }

    // Catches a change that applies share weights as fixed amounts rather than proportions.
    func testSharesSplitAllocatesProportionallyAndConservesTotal() throws {
        let splits = try SplitCalculator.calculate(
            total: Money(minorUnits: 10, currencyCode: "PKR"),
            participants: [participantA, participantB],
            method: .shares([participantA: 1, participantB: 2])
        )

        XCTAssertEqual(splits, [
            ExpenseSplit(userID: participantA, amount: Money(minorUnits: 3, currencyCode: "PKR")),
            ExpenseSplit(userID: participantB, amount: Money(minorUnits: 7, currencyCode: "PKR"))
        ])
        XCTAssertEqual(splits.map(\.amount.minorUnits).reduce(0, +), 10)
    }

    // Catches a change that permits a zero or negative share, which makes proportional allocation undefined.
    func testSharesSplitRejectsNonPositiveWeights() {
        XCTAssertThrowsError(
            try SplitCalculator.calculate(
                total: Money(minorUnits: 100, currencyCode: "PKR"),
                participants: [participantA, participantB],
                method: .shares([participantA: 0, participantB: 1])
            )
        ) { error in
            XCTAssertEqual(error as? SplitError, .invalidShare)
        }
    }

    // Catches a change that creates a split against someone who is not an expense participant.
    func testSplitRejectsUnknownParticipant() {
        XCTAssertThrowsError(
            try SplitCalculator.calculate(
                total: Money(minorUnits: 100, currencyCode: "PKR"),
                participants: [participantA],
                method: .exact([participantA: 50, participantB: 50])
            )
        ) { error in
            XCTAssertEqual(error as? SplitError, .unknownParticipant)
        }
    }

    // Catches a change that lets an empty participant list produce an invalid expense.
    func testSplitRejectsNoParticipants() {
        XCTAssertThrowsError(
            try SplitCalculator.calculate(
                total: Money(minorUnits: 100, currencyCode: "PKR"),
                participants: [],
                method: .equal
            )
        ) { error in
            XCTAssertEqual(error as? SplitError, .noParticipants)
        }
    }

    // Catches a change that allows zero or negative expenses into the ledger.
    func testSplitRejectsNonPositiveTotal() {
        XCTAssertThrowsError(
            try SplitCalculator.calculate(
                total: Money(minorUnits: -1, currencyCode: "PKR"),
                participants: [participantA],
                method: .equal
            )
        ) { error in
            XCTAssertEqual(error as? SplitError, .nonPositiveTotal)
        }
    }

    // Catches a change that allows a non-PKR expense into the PKR-only V1 ledger.
    func testSplitRejectsMismatchedCurrency() {
        XCTAssertThrowsError(
            try SplitCalculator.calculate(
                total: Money(minorUnits: 100, currencyCode: "USD"),
                participants: [participantA],
                method: .equal
            )
        ) { error in
            XCTAssertEqual(error as? SplitError, .currencyMismatch)
        }
    }
}
