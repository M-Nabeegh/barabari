import Foundation

enum SplitError: Error, Equatable {
    case nonPositiveTotal
    case noParticipants
    case invalidExactTotal
    case invalidPercentageTotal
    case invalidShare
    case unknownParticipant
    case currencyMismatch
}

enum SplitCalculator {
    private static let supportedCurrencyCode = "PKR"

    static func calculate(
        total: Money,
        participants: [UUID],
        method: SplitMethod
    ) throws -> [ExpenseSplit] {
        guard total.currencyCode == supportedCurrencyCode else {
            throw SplitError.currencyMismatch
        }

        guard total.minorUnits > 0 else {
            throw SplitError.nonPositiveTotal
        }

        let orderedParticipants = orderedUniqueParticipants(participants)
        guard !orderedParticipants.isEmpty else {
            throw SplitError.noParticipants
        }

        let allocations: [UUID: Int64]
        switch method {
        case .equal:
            allocations = equalAllocations(total: total.minorUnits, participants: orderedParticipants)

        case let .exact(amounts):
            try validateKnownParticipants(amounts.keys, allowed: orderedParticipants)
            guard amounts.values.allSatisfy({ $0 >= 0 }) else {
                throw SplitError.invalidExactTotal
            }
            guard try checkedSum(amounts.values, error: .invalidExactTotal) == total.minorUnits else {
                throw SplitError.invalidExactTotal
            }
            allocations = amounts

        case let .percentage(basisPoints):
            try validateKnownParticipants(basisPoints.keys, allowed: orderedParticipants)
            guard basisPoints.values.allSatisfy({ $0 >= 0 }) else {
                throw SplitError.invalidPercentageTotal
            }
            guard try checkedSum(basisPoints.values, error: .invalidPercentageTotal) == PercentageBasisPoints.oneHundredPercent else {
                throw SplitError.invalidPercentageTotal
            }
            allocations = try weightedAllocations(
                total: total.minorUnits,
                participants: orderedParticipants,
                weights: basisPoints,
                denominator: PercentageBasisPoints.oneHundredPercent,
                error: .invalidPercentageTotal
            )

        case let .shares(shares):
            try validateKnownParticipants(shares.keys, allowed: orderedParticipants)
            guard orderedParticipants.allSatisfy({ (shares[$0] ?? 0) > 0 }) else {
                throw SplitError.invalidShare
            }
            let totalShares = try checkedSum(shares.values, error: .invalidShare)
            guard totalShares > 0 else {
                throw SplitError.invalidShare
            }
            allocations = try weightedAllocations(
                total: total.minorUnits,
                participants: orderedParticipants,
                weights: shares,
                denominator: totalShares,
                error: .invalidShare
            )
        }

        return orderedParticipants.map {
            ExpenseSplit(
                userID: $0,
                amount: Money(minorUnits: allocations[$0] ?? 0, currencyCode: total.currencyCode)
            )
        }
    }

    private static func equalAllocations(total: Int64, participants: [UUID]) -> [UUID: Int64] {
        let count = Int64(participants.count)
        let baseAmount = total / count
        let remainder = total % count

        return Dictionary(uniqueKeysWithValues: participants.enumerated().map { index, participant in
            let amount = baseAmount + (Int64(index) < remainder ? 1 : 0)
            return (participant, amount)
        })
    }

    private static func weightedAllocations(
        total: Int64,
        participants: [UUID],
        weights: [UUID: Int64],
        denominator: Int64,
        error: SplitError
    ) throws -> [UUID: Int64] {
        var floorAllocations: [(userID: UUID, amount: Int64, remainder: Int64)] = []
        floorAllocations.reserveCapacity(participants.count)

        var allocated = Int64.zero
        for participant in participants {
            let weight = weights[participant] ?? 0
            let division = try multiplyAndDivide(total, by: weight, divisor: denominator, error: error)
            let (nextAllocated, overflow) = allocated.addingReportingOverflow(division.quotient)
            guard !overflow else {
                throw error
            }
            allocated = nextAllocated
            floorAllocations.append((participant, division.quotient, division.remainder))
        }

        let remainingUnits = total - allocated
        let remainderOrder = floorAllocations.indices.sorted { lhs, rhs in
            let left = floorAllocations[lhs]
            let right = floorAllocations[rhs]
            if left.remainder != right.remainder {
                return left.remainder > right.remainder
            }
            return uuidBytes(left.userID).lexicographicallyPrecedes(uuidBytes(right.userID))
        }

        var adjustedAmounts = Dictionary(uniqueKeysWithValues: floorAllocations.map { ($0.userID, $0.amount) })
        for index in remainderOrder.prefix(Int(remainingUnits)) {
            let participant = floorAllocations[index].userID
            adjustedAmounts[participant, default: 0] += 1
        }
        return adjustedAmounts
    }

    private static func multiplyAndDivide(
        _ value: Int64,
        by multiplier: Int64,
        divisor: Int64,
        error: SplitError
    ) throws -> (quotient: Int64, remainder: Int64) {
        guard value >= 0, multiplier >= 0, divisor > 0 else {
            throw error
        }

        let product = value.multipliedFullWidth(by: multiplier)
        let result = divisor.dividingFullWidth(product)
        return (result.quotient, result.remainder)
    }

    private static func validateKnownParticipants<C: Collection>(
        _ splitParticipantIDs: C,
        allowed participants: [UUID]
    ) throws where C.Element == UUID {
        let allowedIDs = Set(participants)
        guard splitParticipantIDs.allSatisfy(allowedIDs.contains) else {
            throw SplitError.unknownParticipant
        }
    }

    private static func checkedSum<S: Sequence>(
        _ values: S,
        error: SplitError
    ) throws -> Int64 where S.Element == Int64 {
        var sum = Int64.zero
        for value in values {
            let (nextSum, overflow) = sum.addingReportingOverflow(value)
            guard !overflow else {
                throw error
            }
            sum = nextSum
        }
        return sum
    }

    private static func orderedUniqueParticipants(_ participants: [UUID]) -> [UUID] {
        Set(participants).sorted {
            uuidBytes($0).lexicographicallyPrecedes(uuidBytes($1))
        }
    }

    private static func uuidBytes(_ id: UUID) -> [UInt8] {
        withUnsafeBytes(of: id.uuid) { Array($0) }
    }
}
