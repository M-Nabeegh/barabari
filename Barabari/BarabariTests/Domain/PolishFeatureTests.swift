import XCTest
@testable import Barabari

final class ExpenseCategoryTests: XCTestCase {
    func testDetectsCommonPakistaniExpenses() {
        XCTAssertEqual(ExpenseCategory.detect(from: "Biryani at Haveli"), .food)
        XCTAssertEqual(ExpenseCategory.detect(from: "Careem to airport"), .transport)
        XCTAssertEqual(ExpenseCategory.detect(from: "Petrol"), .transport)
        XCTAssertEqual(ExpenseCategory.detect(from: "K-Electric bill"), .utilities)
        XCTAssertEqual(ExpenseCategory.detect(from: "Hunza hotel"), .travel)
        XCTAssertEqual(ExpenseCategory.detect(from: "Monthly rent"), .rent)
    }

    func testIgnoresPartialWordMatches() {
        // "gas" must not match inside "gasket", "tea" not inside "steak".
        XCTAssertNil(ExpenseCategory.detect(from: "Gasket"))
        XCTAssertNil(ExpenseCategory.detect(from: "steak"))
    }

    func testEmptyTitleHasNoCategory() {
        XCTAssertNil(ExpenseCategory.detect(from: "   "))
    }
}

final class AmountInputTests: XCTestCase {
    private func type(_ keys: [AmountInput.Key], from start: String = "") -> String {
        keys.reduce(start) { AmountInput.apply($1, to: $0) }
    }

    func testDigitsAppendAndLeadingZeroIsReplaced() {
        XCTAssertEqual(type([.digit(0), .digit(5)]), "5")
        XCTAssertEqual(type([.digit(1), .digit(2), .digit(5), .digit(0)]), "1250")
    }

    func testDecimalAllowsAtMostTwoPlaces() {
        XCTAssertEqual(type([.decimal]), "0.")
        XCTAssertEqual(type([.digit(9), .decimal, .digit(9), .digit(9), .digit(9)]), "9.99")
        XCTAssertEqual(type([.digit(1), .decimal, .decimal]), "1.")
    }

    func testBackspaceAndDigitLimit() {
        XCTAssertEqual(type([.digit(4), .digit(2), .backspace]), "4")
        XCTAssertEqual(type([.backspace]), "")
        let long = type(Array(repeating: .digit(9), count: 12))
        XCTAssertEqual(long.count, AmountInput.maxWholeDigits)
    }

    func testDisplayGroupsThousandsAndKeepsTypedDecimals() {
        XCTAssertEqual(AmountInput.display(""), "0")
        XCTAssertEqual(AmountInput.display("2450"), "2,450")
        XCTAssertEqual(AmountInput.display("1250000.5"), "1,250,000.5")
        XCTAssertEqual(AmountInput.display("12."), "12.")
    }
}

@MainActor
final class LedgerMetadataTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "LedgerMetadataTests")
        defaults.removePersistentDomain(forName: "LedgerMetadataTests")
    }

    func testNamesPersistAndCurrentUserIsAlwaysYou() {
        let me = UUID()
        let friend = UUID()
        let metadata = LedgerMetadata(defaults: defaults)
        metadata.setName("  Ali  ", for: friend)
        metadata.setName("Not me", for: me)

        let reloaded = LedgerMetadata(defaults: defaults)
        XCTAssertEqual(reloaded.displayName(for: friend, currentUserID: me, fallback: "x"), "Ali")
        XCTAssertEqual(reloaded.displayName(for: me, currentUserID: me, fallback: "x"), "You")
    }

    func testFallsBackToMemberPosition() {
        let me = UUID()
        let members = [
            GroupMember(groupID: UUID(), userID: me, role: .owner),
            GroupMember(groupID: UUID(), userID: UUID(), role: .member)
        ]
        let metadata = LedgerMetadata(defaults: defaults)
        XCTAssertEqual(metadata.displayName(for: members[1].userID, in: members, currentUserID: me), "Member 2")
    }

    func testBlankNameClearsSavedName() {
        let friend = UUID()
        let metadata = LedgerMetadata(defaults: defaults)
        metadata.setName("Sara", for: friend)
        metadata.setName("   ", for: friend)
        XCTAssertNil(metadata.names[friend])
    }

    func testChosenCategoryWinsOverDetection() {
        let metadata = LedgerMetadata(defaults: defaults)
        let expense = Expense(
            groupID: UUID(),
            title: "Pizza night",
            note: nil,
            total: Money(minorUnits: 1_000, currencyCode: "PKR"),
            paidByUserID: UUID(),
            splits: [],
            splitMethod: .equal,
            occurredAt: .now,
            createdByUserID: UUID()
        )
        XCTAssertEqual(metadata.category(for: expense), .food)
        metadata.setCategory(.fun, for: expense.id)
        XCTAssertEqual(LedgerMetadata(defaults: defaults).category(for: expense), .fun)
    }

    func testOwnerFirstName() {
        let metadata = LedgerMetadata(defaults: defaults)
        XCTAssertNil(metadata.ownerFirstName)
        metadata.ownerName = "Nabeegh Javed"
        XCTAssertEqual(metadata.ownerFirstName, "Nabeegh")
    }
}
