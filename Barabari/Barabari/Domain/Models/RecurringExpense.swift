import Foundation

enum RecurrenceFrequency: String, Codable, CaseIterable, Sendable, Identifiable {
    case weekly
    case monthly

    var id: Self { self }

    var title: String {
        switch self {
        case .weekly: "Every week"
        case .monthly: "Every month"
        }
    }
}

/// An expense that Barabari adds again on a schedule: rent, a shared subscription, the maid's salary.
struct RecurringExpense: Equatable, Codable, Sendable, Identifiable {
    let id: UUID
    let groupID: UUID
    let title: String
    let total: Money
    let paidByUserID: UUID
    let participantIDs: [UUID]
    let splitMethod: SplitMethod
    let categoryRaw: String?
    let frequency: RecurrenceFrequency
    /// Day of the month the first one fell on. Rent due on the 31st lands on the 28th in February
    /// and goes back to the 31st in March.
    let anchorDay: Int
    var nextDueAt: Date
    /// Set when an occurrence could not be added, for example after the payer left the group.
    var pausedReason: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        expense: Expense,
        category: ExpenseCategory?,
        frequency: RecurrenceFrequency,
        calendar: Calendar = RecurrenceSchedule.calendar
    ) {
        self.id = id
        groupID = expense.groupID
        title = expense.title
        total = expense.total
        paidByUserID = expense.paidByUserID
        participantIDs = expense.splits.map(\.userID)
        splitMethod = expense.splitMethod
        categoryRaw = category?.rawValue
        self.frequency = frequency
        anchorDay = calendar.component(.day, from: expense.occurredAt)
        nextDueAt = RecurrenceSchedule.next(
            after: expense.occurredAt, frequency: frequency, anchorDay: anchorDay, calendar: calendar
        )
        pausedReason = nil
        createdAt = expense.createdAt
    }

    var category: ExpenseCategory? {
        categoryRaw.flatMap(ExpenseCategory.init(rawValue:))
    }
}

enum RecurrenceSchedule {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    /// The occurrence that follows `date`.
    static func next(
        after date: Date,
        frequency: RecurrenceFrequency,
        anchorDay: Int,
        calendar: Calendar = RecurrenceSchedule.calendar
    ) -> Date {
        switch frequency {
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date) ?? date.addingTimeInterval(7 * 86_400)
        case .monthly:
            var parts = calendar.dateComponents([.year, .month, .hour, .minute, .second], from: date)
            parts.month = (parts.month ?? 1) + 1
            parts.day = 1
            guard let firstOfNextMonth = calendar.date(from: parts),
                  let days = calendar.range(of: .day, in: .month, for: firstOfNextMonth)?.count else {
                return date.addingTimeInterval(30 * 86_400)
            }
            parts.day = min(max(anchorDay, 1), days)
            return calendar.date(from: parts) ?? firstOfNextMonth
        }
    }
}
