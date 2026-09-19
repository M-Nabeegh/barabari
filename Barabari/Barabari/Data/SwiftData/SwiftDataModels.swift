import Foundation
import SwiftData

enum LocalPersistenceError: Error, Equatable, Sendable {
    case invalidSplitMethod(UUID)
    case missingExpense(UUID)
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
    var idempotencyKey: UUID?

    init(expense: Expense, idempotencyKey: UUID?) throws {
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
        self.idempotencyKey = idempotencyKey
    }

    func apply(_ expense: Expense, idempotencyKey: UUID?) throws {
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
        self.idempotencyKey = idempotencyKey
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
    var idempotencyKey: UUID?

    init(settlement: Settlement, idempotencyKey: UUID?) {
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
        self.idempotencyKey = idempotencyKey
    }

    func apply(_ settlement: Settlement, idempotencyKey: UUID?) {
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
        self.idempotencyKey = idempotencyKey
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
