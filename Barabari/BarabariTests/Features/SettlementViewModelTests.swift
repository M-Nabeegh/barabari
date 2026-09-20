import XCTest
@testable import Barabari

@MainActor
final class SettlementViewModelTests: XCTestCase {
    func testPartialSettlementLeavesRemainingBalanceInLocalLedger() async throws {
        let environment = AppEnvironment(
            inMemory: true,
            seedDemoData: true,
            seedDemoSecondMember: true,
            seedDemoDebt: true
        )
        let groups = try await environment.groupRepository.listGroups()
        let group = try XCTUnwrap(groups.first)
        let initialBalance = try await environment.balanceRepository.summary(groupID: group.id)
        let transfer = try XCTUnwrap(initialBalance.transfers.first { $0.fromUserID == environment.currentUserID })
        let viewModel = SettlementViewModel(
            environment: environment,
            groupID: group.id,
            fromUserID: transfer.fromUserID,
            toUserID: transfer.toUserID,
            remainingAmount: transfer.amount,
            recipient: "Member 2"
        )
        viewModel.amount = "500"

        await viewModel.save()

        XCTAssertEqual(viewModel.savedSettlement?.amount, Money(minorUnits: 50_000, currencyCode: "PKR"))
        let refreshedBalance = try await environment.balanceRepository.summary(groupID: group.id)
        let remaining = try XCTUnwrap(refreshedBalance.transfers.first { $0.fromUserID == environment.currentUserID })
        XCTAssertEqual(remaining.amount, Money(minorUnits: 50_000, currencyCode: "PKR"))
    }

    func testOverpaymentIsRejectedBeforeWritingToLocalLedger() async throws {
        let environment = AppEnvironment(
            inMemory: true,
            seedDemoData: true,
            seedDemoSecondMember: true,
            seedDemoDebt: true
        )
        let groups = try await environment.groupRepository.listGroups()
        let group = try XCTUnwrap(groups.first)
        let initialBalance = try await environment.balanceRepository.summary(groupID: group.id)
        let transfer = try XCTUnwrap(initialBalance.transfers.first { $0.fromUserID == environment.currentUserID })
        let viewModel = SettlementViewModel(
            environment: environment,
            groupID: group.id,
            fromUserID: transfer.fromUserID,
            toUserID: transfer.toUserID,
            remainingAmount: transfer.amount,
            recipient: "Member 2"
        )
        viewModel.amount = "1001"

        await viewModel.save()

        XCTAssertNil(viewModel.savedSettlement)
        XCTAssertEqual(viewModel.validationMessage, "This is more than the remaining balance.")
        let settlements = try await environment.settlementRepository.listSettlements(groupID: group.id, cursor: nil)
        XCTAssertEqual(settlements.items.count, 0)
    }
}
