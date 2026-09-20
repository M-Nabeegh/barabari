import Combine
import Foundation

@MainActor
final class SettlementViewModel: ObservableObject {
    @Published var amount = ""
    @Published private(set) var recipient: String
    @Published var method: SettlementMethod = .cash
    @Published var note = ""
    @Published private(set) var isSaving = false
    @Published private(set) var savedSettlement: Settlement?
    @Published private(set) var validationMessage: String?

    let remainingAmount: Money

    private let environment: AppEnvironment
    private let groupID: UUID
    private let fromUserID: UUID
    private let toUserID: UUID

    init(
        environment: AppEnvironment,
        groupID: UUID,
        fromUserID: UUID,
        toUserID: UUID,
        remainingAmount: Money,
        recipient: String
    ) {
        self.environment = environment
        self.groupID = groupID
        self.fromUserID = fromUserID
        self.toUserID = toUserID
        self.remainingAmount = remainingAmount
        self.recipient = recipient
    }

    func save() async {
        guard !isSaving else { return }
        validationMessage = nil
        isSaving = true
        defer { isSaving = false }

        do {
            let value = try parseAmount(amount)
            guard value.minorUnits <= remainingAmount.minorUnits else {
                throw SettlementFormError.exceedsRemaining
            }
            let draft = SettlementDraft(
                groupID: groupID,
                fromUserID: fromUserID,
                toUserID: toUserID,
                amount: value,
                method: method,
                note: normalizedNote,
                occurredAt: .now,
                createdByUserID: environment.currentUserID
            )
            savedSettlement = try await RecordSettlement(
                repository: environment.settlementRepository,
                groupRepository: environment.groupRepository
            ).call(draft: draft, idempotencyKey: UUID())
        } catch {
            validationMessage = message(for: error)
        }
    }

    private var normalizedNote: String? {
        let value = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func parseAmount(_ text: String) throws -> Money {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count <= 2,
              let wholeText = components.first,
              !wholeText.isEmpty,
              wholeText.allSatisfy(\.isNumber),
              components.dropFirst().allSatisfy({ $0.count <= 2 && $0.allSatisfy(\.isNumber) }),
              let whole = Int64(wholeText) else {
            throw SettlementFormError.invalidAmount
        }
        let fractionText = components.count == 2 ? String(components[1]) : ""
        let fraction = Int64(fractionText.padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0
        let (wholeInPaisa, wholeOverflow) = whole.multipliedReportingOverflow(by: 100)
        let (minorUnits, fractionOverflow) = wholeInPaisa.addingReportingOverflow(fraction)
        guard !wholeOverflow, !fractionOverflow, minorUnits > 0 else {
            throw SettlementFormError.invalidAmount
        }
        return Money(minorUnits: minorUnits, currencyCode: "PKR")
    }

    private func message(for error: Error) -> String {
        switch error {
        case SettlementFormError.invalidAmount, LedgerValidationError.nonPositiveAmount:
            return "Enter an amount greater than PKR 0."
        case SettlementFormError.exceedsRemaining:
            return "This is more than the remaining balance."
        default:
            return "We could not record this settlement. Try again."
        }
    }
}

private enum SettlementFormError: Error {
    case invalidAmount
    case exceedsRemaining
}
