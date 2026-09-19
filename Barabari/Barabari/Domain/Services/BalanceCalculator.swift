import Foundation

enum BalanceCalculationError: Error, Equatable, Sendable {
    case noActiveMembers
    case inconsistentGroup
    case unknownMember(UUID)
    case invalidExpense(UUID)
    case invalidSettlement(UUID)
    case arithmeticOverflow
}

enum BalanceCalculator {
    static func calculate(
        expenses: [Expense],
        settlements: [Settlement],
        members: [GroupMember]
    ) throws -> BalanceSummary {
        guard !members.isEmpty else {
            throw BalanceCalculationError.noActiveMembers
        }
        let groupIDs = Set(members.map(\.groupID))
        guard groupIDs.count == 1, let groupID = groupIDs.first else {
            throw BalanceCalculationError.inconsistentGroup
        }

        // A departed member can still have an unresolved historical position. New writes are
        // restricted to active members by their use cases, but balance reconstruction accepts
        // every membership record known to this group.
        let memberIDs = Set(members.map(\.userID))
        var positions = Dictionary(uniqueKeysWithValues: memberIDs.map { ($0, Int64.zero) })

        for expense in expenses where expense.deletedAt == nil {
            guard expense.groupID == groupID else {
                throw BalanceCalculationError.inconsistentGroup
            }
            try validateExpense(expense, memberIDs: memberIDs)
            try add(expense.total.minorUnits, to: expense.paidByUserID, positions: &positions)
            for split in expense.splits {
                try add(-split.amount.minorUnits, to: split.userID, positions: &positions)
            }
        }

        for settlement in settlements where settlement.deletedAt == nil {
            guard settlement.groupID == groupID else {
                throw BalanceCalculationError.inconsistentGroup
            }
            guard memberIDs.contains(settlement.fromUserID) else {
                throw BalanceCalculationError.unknownMember(settlement.fromUserID)
            }
            guard memberIDs.contains(settlement.toUserID) else {
                throw BalanceCalculationError.unknownMember(settlement.toUserID)
            }
            guard memberIDs.contains(settlement.createdByUserID) else {
                throw BalanceCalculationError.unknownMember(settlement.createdByUserID)
            }
            guard settlement.fromUserID != settlement.toUserID,
                  settlement.amount.currencyCode == "PKR",
                  settlement.amount.minorUnits > 0 else {
                throw BalanceCalculationError.invalidSettlement(settlement.id)
            }
            try add(settlement.amount.minorUnits, to: settlement.fromUserID, positions: &positions)
            try add(-settlement.amount.minorUnits, to: settlement.toUserID, positions: &positions)
        }

        let orderedPositions = positions.keys.sorted(by: isBefore).map {
            BalancePosition(userID: $0, amount: Money(minorUnits: positions[$0] ?? 0, currencyCode: "PKR"))
        }
        return BalanceSummary(
            groupID: groupID,
            netPositions: orderedPositions,
            transfers: try makeTransfers(from: positions)
        )
    }

    private static func validateExpense(_ expense: Expense, memberIDs: Set<UUID>) throws {
        guard expense.total.currencyCode == "PKR", expense.total.minorUnits > 0 else {
            throw BalanceCalculationError.invalidExpense(expense.id)
        }
        guard memberIDs.contains(expense.paidByUserID) else {
            throw BalanceCalculationError.unknownMember(expense.paidByUserID)
        }
        guard memberIDs.contains(expense.createdByUserID) else {
            throw BalanceCalculationError.unknownMember(expense.createdByUserID)
        }
        var total = Int64.zero
        var splitUserIDs = Set<UUID>()
        for split in expense.splits {
            guard memberIDs.contains(split.userID),
                  splitUserIDs.insert(split.userID).inserted,
                  split.amount.currencyCode == "PKR",
                  split.amount.minorUnits >= 0 else {
                throw BalanceCalculationError.invalidExpense(expense.id)
            }
            let (updated, overflow) = total.addingReportingOverflow(split.amount.minorUnits)
            guard !overflow else {
                throw BalanceCalculationError.arithmeticOverflow
            }
            total = updated
        }
        guard total == expense.total.minorUnits else {
            throw BalanceCalculationError.invalidExpense(expense.id)
        }
    }

    private static func add(_ amount: Int64, to userID: UUID, positions: inout [UUID: Int64]) throws {
        guard let current = positions[userID] else {
            throw BalanceCalculationError.unknownMember(userID)
        }
        let (updated, overflow) = current.addingReportingOverflow(amount)
        guard !overflow else {
            throw BalanceCalculationError.arithmeticOverflow
        }
        positions[userID] = updated
    }

    private static func makeTransfers(from positions: [UUID: Int64]) throws -> [BalanceTransfer] {
        var debtors: [(userID: UUID, amount: Int64)] = []
        for (userID, position) in positions where position < 0 {
            debtors.append((userID: userID, amount: try positiveMagnitude(of: position)))
        }
        debtors.sort { isBefore($0.userID, $1.userID) }
        var creditors = positions
            .filter { $0.value > 0 }
            .map { (userID: $0.key, amount: $0.value) }
            .sorted { isBefore($0.userID, $1.userID) }
        var transfers: [BalanceTransfer] = []
        var debtorIndex = 0
        var creditorIndex = 0

        while debtorIndex < debtors.count, creditorIndex < creditors.count {
            let amount = min(debtors[debtorIndex].amount, creditors[creditorIndex].amount)
            guard amount > 0 else {
                throw BalanceCalculationError.inconsistentGroup
            }
            transfers.append(BalanceTransfer(
                fromUserID: debtors[debtorIndex].userID,
                toUserID: creditors[creditorIndex].userID,
                amount: Money(minorUnits: amount, currencyCode: "PKR")
            ))
            debtors[debtorIndex].amount -= amount
            creditors[creditorIndex].amount -= amount
            if debtors[debtorIndex].amount == 0 { debtorIndex += 1 }
            if creditors[creditorIndex].amount == 0 { creditorIndex += 1 }
        }
        guard debtorIndex == debtors.count, creditorIndex == creditors.count else {
            throw BalanceCalculationError.inconsistentGroup
        }
        return transfers
    }

    private static func positiveMagnitude(of negativeAmount: Int64) throws -> Int64 {
        let (magnitude, overflow) = negativeAmount.multipliedReportingOverflow(by: -1)
        guard !overflow else {
            throw BalanceCalculationError.arithmeticOverflow
        }
        return magnitude
    }

    private static func isBefore(_ lhs: UUID, _ rhs: UUID) -> Bool {
        withUnsafeBytes(of: lhs.uuid) { Array($0) }.lexicographicallyPrecedes(withUnsafeBytes(of: rhs.uuid) { Array($0) })
    }
}
