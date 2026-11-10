import Combine
import CryptoKit
import Foundation

/// Repeating expenses set up on this phone. They live beside the ledger, like names and
/// categories, and only the phone that created one adds its occurrences, so two members never
/// post the same rent twice.
@MainActor
final class RecurringExpenseStore: ObservableObject {
    /// Replaced with an isolated store for UI tests.
    static var shared = RecurringExpenseStore()

    /// After a long gap, at most this many missed occurrences are added per expense.
    static let catchUpLimit = 12

    @Published private(set) var items: [RecurringExpense]

    private let defaults: UserDefaults
    private var isPosting = false
    private static let key = "barabari.recurringExpenses"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        items = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode([RecurringExpense].self, from: $0) } ?? []
    }

    func items(in groupID: UUID) -> [RecurringExpense] {
        items.filter { $0.groupID == groupID }.sorted { $0.nextDueAt < $1.nextDueAt }
    }

    @discardableResult
    func add(from expense: Expense, category: ExpenseCategory?, frequency: RecurrenceFrequency) -> RecurringExpense {
        let item = RecurringExpense(expense: expense, category: category, frequency: frequency)
        items.append(item)
        persist()
        return item
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        persist()
    }

    /// Adds every occurrence that has come due and returns how many expenses were created.
    @discardableResult
    func postDue(
        environment: AppEnvironment,
        metadata: LedgerMetadata? = nil,
        now: Date = .now,
        calendar: Calendar = RecurrenceSchedule.calendar
    ) async -> Int {
        guard !isPosting else { return 0 }
        isPosting = true
        defer { isPosting = false }

        let metadata = metadata ?? .shared
        let createExpense = CreateExpense(
            repository: environment.expenseRepository,
            groupRepository: environment.groupRepository
        )
        var created = 0

        for id in items.map(\.id) {
            var posted = 0
            while let index = items.firstIndex(where: { $0.id == id }),
                  items[index].nextDueAt <= now, posted < Self.catchUpLimit {
                let item = items[index]
                let draft = ExpenseDraft(
                    groupID: item.groupID,
                    title: item.title,
                    note: nil,
                    total: item.total,
                    paidByUserID: item.paidByUserID,
                    participantIDs: item.participantIDs,
                    splitMethod: item.splitMethod,
                    occurredAt: item.nextDueAt,
                    createdByUserID: environment.currentUserID
                )
                do {
                    let expense = try await createExpense.call(
                        draft: draft,
                        idempotencyKey: Self.occurrenceKey(for: item.id, dueAt: item.nextDueAt)
                    )
                    if let category = item.category {
                        metadata.setCategory(category, for: expense.id)
                    }
                    created += 1
                    posted += 1
                } catch {
                    if let pausedIndex = items.firstIndex(where: { $0.id == id }) {
                        items[pausedIndex].pausedReason = Self.pauseReason(for: error)
                    }
                    break
                }
                guard let advancing = items.firstIndex(where: { $0.id == id }) else { break }
                items[advancing].pausedReason = nil
                items[advancing].nextDueAt = RecurrenceSchedule.next(
                    after: item.nextDueAt, frequency: item.frequency, anchorDay: item.anchorDay, calendar: calendar
                )
            }

            // Still behind after the catch-up limit: skip ahead instead of flooding the group.
            if let index = items.firstIndex(where: { $0.id == id }), items[index].pausedReason == nil {
                while items[index].nextDueAt <= now {
                    items[index].nextDueAt = RecurrenceSchedule.next(
                        after: items[index].nextDueAt,
                        frequency: items[index].frequency,
                        anchorDay: items[index].anchorDay,
                        calendar: calendar
                    )
                }
            }
        }

        persist()
        return created
    }

    /// The same occurrence always maps to the same key, so a retry never adds it twice.
    static func occurrenceKey(for id: UUID, dueAt: Date) -> UUID {
        let seed = "\(id.uuidString)|\(Int64(dueAt.timeIntervalSince1970))"
        let digest = Array(SHA256.hash(data: Data(seed.utf8)).prefix(16))
        return UUID(uuid: (
            digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6], digest[7],
            digest[8], digest[9], digest[10], digest[11], digest[12], digest[13], digest[14], digest[15]
        ))
    }

    private static func pauseReason(for error: Error) -> String {
        switch error {
        case LedgerValidationError.payerNotGroupMember:
            "Paused because the payer left the group."
        case LedgerValidationError.participantNotGroupMember:
            "Paused because someone in the split left the group."
        default:
            "Paused because the last one could not be added."
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
