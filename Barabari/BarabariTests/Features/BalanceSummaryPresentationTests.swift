import XCTest
@testable import Barabari

final class BalanceSummaryPresentationTests: XCTestCase {
    private let groupID = UUID()
    private let currentUserID = UUID()
    private let firstFriendID = UUID()
    private let secondFriendID = UUID()

    func testNegativeCurrentUserPositionShowsEveryOutgoingTransfer() {
        let summary = BalanceSummary(
            groupID: groupID,
            netPositions: [
                BalancePosition(userID: currentUserID, amount: Money(minorUnits: -1_500, currencyCode: "PKR")),
                BalancePosition(userID: firstFriendID, amount: Money(minorUnits: 1_000, currencyCode: "PKR")),
                BalancePosition(userID: secondFriendID, amount: Money(minorUnits: 500, currencyCode: "PKR"))
            ],
            transfers: [
                BalanceTransfer(fromUserID: currentUserID, toUserID: firstFriendID, amount: Money(minorUnits: 1_000, currencyCode: "PKR")),
                BalanceTransfer(fromUserID: currentUserID, toUserID: secondFriendID, amount: Money(minorUnits: 500, currencyCode: "PKR"))
            ]
        )

        XCTAssertEqual(
            BalanceSummaryPresentation.make(summary: summary, currentUserID: currentUserID),
            .youOwe(
                total: Money(minorUnits: 1_500, currencyCode: "PKR"),
                transfers: summary.transfers
            )
        )
    }

    func testPositiveCurrentUserPositionShowsEveryIncomingTransfer() {
        let incomingTransfers = [
            BalanceTransfer(fromUserID: firstFriendID, toUserID: currentUserID, amount: Money(minorUnits: 1_000, currencyCode: "PKR")),
            BalanceTransfer(fromUserID: secondFriendID, toUserID: currentUserID, amount: Money(minorUnits: 500, currencyCode: "PKR"))
        ]
        let summary = BalanceSummary(
            groupID: groupID,
            netPositions: [
                BalancePosition(userID: currentUserID, amount: Money(minorUnits: 1_500, currencyCode: "PKR"))
            ],
            transfers: incomingTransfers
        )

        XCTAssertEqual(
            BalanceSummaryPresentation.make(summary: summary, currentUserID: currentUserID),
            .youAreOwed(total: Money(minorUnits: 1_500, currencyCode: "PKR"), transfers: incomingTransfers)
        )
    }

    func testSettledCurrentUserDoesNotClaimOtherMembersAreSettled() {
        let summary = BalanceSummary(
            groupID: groupID,
            netPositions: [
                BalancePosition(userID: currentUserID, amount: Money(minorUnits: 0, currencyCode: "PKR")),
                BalancePosition(userID: firstFriendID, amount: Money(minorUnits: -900, currencyCode: "PKR")),
                BalancePosition(userID: secondFriendID, amount: Money(minorUnits: 900, currencyCode: "PKR"))
            ],
            transfers: [
                BalanceTransfer(fromUserID: firstFriendID, toUserID: secondFriendID, amount: Money(minorUnits: 900, currencyCode: "PKR"))
            ]
        )

        XCTAssertEqual(BalanceSummaryPresentation.make(summary: summary, currentUserID: currentUserID), .settled)
    }
}
