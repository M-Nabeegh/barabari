import Foundation
import SwiftData

enum LocalPersistenceError: Error, Equatable, Sendable {
    case invalidSplitMethod(UUID)
    case missingExpense(UUID)
    case invalidCursor
    case idempotencyKeyConflict(UUID)
    case missingIdempotencySubject(UUID)
}

enum StoredLedgerCommandKind: String, Codable, Sendable {
    case saveExpense
    case deleteExpense
    case saveSettlement
}

@Model
final class StoredLedgerCommand {
    @Attribute(.unique) var idempotencyKey: UUID
    var kindRawValue: String
    var subjectID: UUID
    var createdAt: Date

    init(idempotencyKey: UUID, kind: StoredLedgerCommandKind, subjectID: UUID, createdAt: Date = .now) {
        self.idempotencyKey = idempotencyKey
        kindRawValue = kind.rawValue
        self.subjectID = subjectID
        self.createdAt = createdAt
    }

    var kind: StoredLedgerCommandKind? {
        StoredLedgerCommandKind(rawValue: kindRawValue)
    }
}

@Model
final class StoredGroup {
    @Attribute(.unique) var id: UUID
    var name: String
    var groupDescription: String?
    var ownerID: UUID
    var createdAt: Date
    var updatedAt: Date
    var revision: Int
    var deletedAt: Date?

    init(group: Group) {
        id = group.id
        name = group.name
        groupDescription = group.description
        ownerID = group.ownerID
        createdAt = group.createdAt
        updatedAt = group.updatedAt
        revision = group.revision
        deletedAt = group.deletedAt
    }

    var asDomain: Group {
        Group(
            id: id,
            name: name,
            description: groupDescription,
            ownerID: ownerID,
            createdAt: createdAt,
            updatedAt: updatedAt,
            revision: revision,
            deletedAt: deletedAt
        )
    }
}

@Model
final class StoredGroupMember {
    @Attribute(.unique) var id: UUID
    var groupID: UUID
    var userID: UUID
    var roleRawValue: String
    var joinedAt: Date
    var updatedAt: Date
    var revision: Int
    var removedAt: Date?

    init(member: GroupMember) {
        id = member.id
        groupID = member.groupID
        userID = member.userID
        roleRawValue = member.role.rawValue
        joinedAt = member.joinedAt
        updatedAt = member.updatedAt
        revision = member.revision
        removedAt = member.removedAt
    }

    var asDomain: GroupMember {
        GroupMember(
            id: id,
            groupID: groupID,
            userID: userID,
            role: GroupMemberRole(rawValue: roleRawValue) ?? .member,
            joinedAt: joinedAt,
            updatedAt: updatedAt,
            revision: revision,
            removedAt: removedAt
        )
    }

    func apply(_ member: GroupMember) {
        groupID = member.groupID
        userID = member.userID
        roleRawValue = member.role.rawValue
        joinedAt = member.joinedAt
        updatedAt = member.updatedAt
        revision = member.revision
        removedAt = member.removedAt
    }
}

@Model
final class StoredExpense {
    @Attribute(.unique) var id: UUID
    var groupID: UUID
    var title: String
    var note: String?
    var totalMinorUnits: Int64
    var currencyCode: String
    var paidByUserID: UUID
    var splitMethodData: Data
    var occurredAt: Date
    var createdByUserID: UUID
    var createdAt: Date
    var updatedAt: Date
    var revision: Int
    var deletedAt: Date?
    init(expense: Expense) throws {
        id = expense.id
        groupID = expense.groupID
        title = expense.title
        note = expense.note
        totalMinorUnits = expense.total.minorUnits
        currencyCode = expense.total.currencyCode
        paidByUserID = expense.paidByUserID
        splitMethodData = try JSONEncoder().encode(expense.splitMethod)
        occurredAt = expense.occurredAt
        createdByUserID = expense.createdByUserID
        createdAt = expense.createdAt
        updatedAt = expense.updatedAt
        revision = expense.revision
        deletedAt = expense.deletedAt
    }

    func apply(_ expense: Expense) throws {
        groupID = expense.groupID
        title = expense.title
        note = expense.note
        totalMinorUnits = expense.total.minorUnits
        currencyCode = expense.total.currencyCode
        paidByUserID = expense.paidByUserID
        splitMethodData = try JSONEncoder().encode(expense.splitMethod)
        occurredAt = expense.occurredAt
        createdByUserID = expense.createdByUserID
        createdAt = expense.createdAt
        updatedAt = expense.updatedAt
        revision = expense.revision
        deletedAt = expense.deletedAt
    }

    func asDomain(splits: [ExpenseSplit]) throws -> Expense {
        guard let splitMethod = try? JSONDecoder().decode(SplitMethod.self, from: splitMethodData) else {
            throw LocalPersistenceError.invalidSplitMethod(id)
        }
        return Expense(
            id: id,
            groupID: groupID,
            title: title,
            note: note,
            total: Money(minorUnits: totalMinorUnits, currencyCode: currencyCode),
            paidByUserID: paidByUserID,
            splits: splits,
            splitMethod: splitMethod,
            occurredAt: occurredAt,
            createdByUserID: createdByUserID,
            createdAt: createdAt,
            updatedAt: updatedAt,
            revision: revision,
            deletedAt: deletedAt
        )
    }
}

@Model
final class StoredExpenseSplit {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var stableKey: String
    var expenseID: UUID
    var userID: UUID
    var amountMinorUnits: Int64
    var currencyCode: String

    init(id: UUID = UUID(), expenseID: UUID, split: ExpenseSplit) {
        self.id = id
        stableKey = "\(expenseID.uuidString):\(split.userID.uuidString)"
        self.expenseID = expenseID
        userID = split.userID
        amountMinorUnits = split.amount.minorUnits
        currencyCode = split.amount.currencyCode
    }

    var asDomain: ExpenseSplit {
        ExpenseSplit(userID: userID, amount: Money(minorUnits: amountMinorUnits, currencyCode: currencyCode))
    }

    func apply(_ split: ExpenseSplit) {
        userID = split.userID
        amountMinorUnits = split.amount.minorUnits
        currencyCode = split.amount.currencyCode
    }
}

@Model
final class StoredSettlement {
    @Attribute(.unique) var id: UUID
    var groupID: UUID
    var fromUserID: UUID
    var toUserID: UUID
    var amountMinorUnits: Int64
    var currencyCode: String
    var methodRawValue: String
    var note: String?
    var occurredAt: Date
    var createdByUserID: UUID
    var createdAt: Date
    var updatedAt: Date
    var revision: Int
    var deletedAt: Date?
    init(settlement: Settlement) {
        id = settlement.id
        groupID = settlement.groupID
        fromUserID = settlement.fromUserID
        toUserID = settlement.toUserID
        amountMinorUnits = settlement.amount.minorUnits
        currencyCode = settlement.amount.currencyCode
        methodRawValue = settlement.method.rawValue
        note = settlement.note
        occurredAt = settlement.occurredAt
        createdByUserID = settlement.createdByUserID
        createdAt = settlement.createdAt
        updatedAt = settlement.updatedAt
        revision = settlement.revision
        deletedAt = settlement.deletedAt
    }

    func apply(_ settlement: Settlement) {
        groupID = settlement.groupID
        fromUserID = settlement.fromUserID
        toUserID = settlement.toUserID
        amountMinorUnits = settlement.amount.minorUnits
        currencyCode = settlement.amount.currencyCode
        methodRawValue = settlement.method.rawValue
        note = settlement.note
        occurredAt = settlement.occurredAt
        createdByUserID = settlement.createdByUserID
        createdAt = settlement.createdAt
        updatedAt = settlement.updatedAt
        revision = settlement.revision
        deletedAt = settlement.deletedAt
    }

    var asDomain: Settlement {
        Settlement(
            id: id,
            groupID: groupID,
            fromUserID: fromUserID,
            toUserID: toUserID,
            amount: Money(minorUnits: amountMinorUnits, currencyCode: currencyCode),
            method: SettlementMethod(rawValue: methodRawValue) ?? .other,
            note: note,
            occurredAt: occurredAt,
            createdByUserID: createdByUserID,
            createdAt: createdAt,
            updatedAt: updatedAt,
            revision: revision,
            deletedAt: deletedAt
        )
    }
}

@Model
final class StoredActivityEvent {
    @Attribute(.unique) var id: UUID
    var groupID: UUID
    var actorUserID: UUID
    var kindRawValue: String
    var subjectID: UUID
    var occurredAt: Date
    var createdAt: Date
    var revision: Int
    var deletedAt: Date?

    init(event: ActivityEvent) {
        id = event.id
        groupID = event.groupID
        actorUserID = event.actorUserID
        kindRawValue = event.kind.rawValue
        subjectID = event.subjectID
        occurredAt = event.occurredAt
        createdAt = event.createdAt
        revision = event.revision
        deletedAt = event.deletedAt
    }

    var asDomain: ActivityEvent {
        ActivityEvent(
            id: id,
            groupID: groupID,
            actorUserID: actorUserID,
            kind: ActivityEventKind(rawValue: kindRawValue) ?? .expenseCreated,
            subjectID: subjectID,
            occurredAt: occurredAt,
            createdAt: createdAt,
            revision: revision,
            deletedAt: deletedAt
        )
    }
}

struct LocalLedgerCursor: Codable, Equatable, Sendable {
    let occurredAt: Date
    let id: UUID
}

enum LocalLedgerPagination {
    private static let pageSize = 50

    static func page<Item: Equatable & Sendable>(
        items: [Item],
        cursor: String?,
        occurredAt: (Item) -> Date,
        id: (Item) -> UUID
    ) throws -> Page<Item> {
        let cursor = try cursor.map(decode)
        let remaining = cursor.map { boundary in
            items.filter { item in
                let itemDate = occurredAt(item)
                return itemDate < boundary.occurredAt || (
                    itemDate == boundary.occurredAt && uuidBytes(boundary.id).lexicographicallyPrecedes(uuidBytes(id(item)))
                )
            }
        } ?? items
        let pageItems = Array(remaining.prefix(pageSize))
        let nextCursor = remaining.count > pageItems.count ? pageItems.last.map {
            encode(LocalLedgerCursor(occurredAt: occurredAt($0), id: id($0)))
        } : nil
        return Page(items: pageItems, nextCursor: nextCursor)
    }

    private static func encode(_ cursor: LocalLedgerCursor) -> String {
        guard let data = try? JSONEncoder().encode(cursor) else {
            preconditionFailure("A keyset cursor made only of a Date and UUID must be encodable.")
        }
        return data.base64EncodedString()
    }

    private static func decode(_ value: String) throws -> LocalLedgerCursor {
        guard let data = Data(base64Encoded: value),
              let cursor = try? JSONDecoder().decode(LocalLedgerCursor.self, from: data) else {
            throw LocalPersistenceError.invalidCursor
        }
        return cursor
    }

    private static func uuidBytes(_ id: UUID) -> [UInt8] {
        withUnsafeBytes(of: id.uuid) { Array($0) }
    }
}
