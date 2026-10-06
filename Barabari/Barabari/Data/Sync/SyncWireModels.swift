import Foundation

// Rows exactly as they are stored in Supabase (snake_case, paise as bigint).
// The sync engine converts between these and the domain models; nothing else
// in the app sees them.

struct GroupRow: Codable, Equatable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let ownerID: UUID
    let createdAt: Date
    let updatedAt: Date
    let revision: Int
    let deletedAt: Date?
    var serverUpdatedAt: String?

    static let table = "groups"
    static let columns = "id,name,description,owner_id,created_at,updated_at,revision,deleted_at"

    enum CodingKeys: String, CodingKey {
        case id, name, description, revision
        case ownerID = "owner_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case serverUpdatedAt = "server_updated_at"
    }

    init(_ group: Group) {
        id = group.id
        name = group.name
        description = group.description
        ownerID = group.ownerID
        createdAt = group.createdAt
        updatedAt = group.updatedAt
        revision = group.revision
        deletedAt = group.deletedAt
    }

    var domain: Group {
        Group(
            id: id,
            name: name,
            description: description,
            ownerID: ownerID,
            createdAt: createdAt,
            updatedAt: updatedAt,
            revision: revision,
            deletedAt: deletedAt
        )
    }
}

struct GroupMemberRow: Codable, Equatable, Sendable {
    let id: UUID
    let groupID: UUID
    let userID: UUID
    let role: String
    var displayName: String?
    let joinedAt: Date
    let updatedAt: Date
    let revision: Int
    let removedAt: Date?
    var serverUpdatedAt: String?

    static let table = "group_members"
    static let columns = "id,group_id,user_id,role,display_name,joined_at,updated_at,revision,removed_at"

    enum CodingKeys: String, CodingKey {
        case id, role, revision
        case groupID = "group_id"
        case userID = "user_id"
        case displayName = "display_name"
        case joinedAt = "joined_at"
        case updatedAt = "updated_at"
        case removedAt = "removed_at"
        case serverUpdatedAt = "server_updated_at"
    }

    init(_ member: GroupMember, displayName: String?) {
        id = member.id
        groupID = member.groupID
        userID = member.userID
        role = member.role.rawValue
        self.displayName = displayName
        joinedAt = member.joinedAt
        updatedAt = member.updatedAt
        revision = member.revision
        removedAt = member.removedAt
    }

    var domain: GroupMember {
        GroupMember(
            id: id,
            groupID: groupID,
            userID: userID,
            role: GroupMemberRole(rawValue: role) ?? .member,
            joinedAt: joinedAt,
            updatedAt: updatedAt,
            revision: revision,
            removedAt: removedAt
        )
    }
}

struct WireSplit: Codable, Equatable, Sendable {
    let userID: UUID
    let amountMinor: Int64

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case amountMinor = "amount_minor"
    }
}

/// `{"kind": "equal"}` or `{"kind": "exact", "values": [{"user_id": …, "value": …}]}`.
struct WireSplitMethod: Codable, Equatable, Sendable {
    struct Value: Codable, Equatable, Sendable {
        let userID: UUID
        let value: Int64

        enum CodingKeys: String, CodingKey {
            case userID = "user_id"
            case value
        }
    }

    let kind: String
    let values: [Value]?

    init(_ method: SplitMethod) {
        func sorted(_ values: [UUID: Int64]) -> [Value] {
            values.map { Value(userID: $0.key, value: $0.value) }
                .sorted { $0.userID.uuidString < $1.userID.uuidString }
        }
        switch method {
        case .equal:
            kind = "equal"
            values = nil
        case let .exact(map):
            kind = "exact"
            values = sorted(map)
        case let .percentage(map):
            kind = "percentage"
            values = sorted(map)
        case let .shares(map):
            kind = "shares"
            values = sorted(map)
        }
    }

    var domain: SplitMethod {
        let map = Dictionary((values ?? []).map { ($0.userID, $0.value) }, uniquingKeysWith: { first, _ in first })
        switch kind {
        case "exact": return .exact(map)
        case "percentage": return .percentage(map)
        case "shares": return .shares(map)
        default: return .equal
        }
    }
}

struct ExpenseRow: Codable, Equatable, Sendable {
    let id: UUID
    let groupID: UUID
    let title: String
    let note: String?
    let totalMinor: Int64
    let currencyCode: String
    let paidBy: UUID
    let splitMethod: WireSplitMethod
    let splits: [WireSplit]
    let category: String?
    let occurredAt: Date
    let createdBy: UUID
    let createdAt: Date
    let updatedAt: Date
    let revision: Int
    let deletedAt: Date?
    var serverUpdatedAt: String?

    static let table = "expenses"
    static let columns = "id,group_id,title,note,total_minor,currency_code,paid_by,split_method,splits,category,occurred_at,created_by,created_at,updated_at,revision,deleted_at"

    enum CodingKeys: String, CodingKey {
        case id, title, note, splits, category, revision
        case groupID = "group_id"
        case totalMinor = "total_minor"
        case currencyCode = "currency_code"
        case paidBy = "paid_by"
        case splitMethod = "split_method"
        case occurredAt = "occurred_at"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case serverUpdatedAt = "server_updated_at"
    }

    init(_ expense: Expense, category: ExpenseCategory?) {
        id = expense.id
        groupID = expense.groupID
        title = expense.title
        note = expense.note
        totalMinor = expense.total.minorUnits
        currencyCode = expense.total.currencyCode
        paidBy = expense.paidByUserID
        splitMethod = WireSplitMethod(expense.splitMethod)
        splits = expense.splits.map { WireSplit(userID: $0.userID, amountMinor: $0.amount.minorUnits) }
        self.category = category?.rawValue
        occurredAt = expense.occurredAt
        createdBy = expense.createdByUserID
        createdAt = expense.createdAt
        updatedAt = expense.updatedAt
        revision = expense.revision
        deletedAt = expense.deletedAt
    }

    var domain: Expense {
        Expense(
            id: id,
            groupID: groupID,
            title: title,
            note: note,
            total: Money(minorUnits: totalMinor, currencyCode: currencyCode),
            paidByUserID: paidBy,
            splits: splits.map { ExpenseSplit(userID: $0.userID, amount: Money(minorUnits: $0.amountMinor, currencyCode: currencyCode)) },
            splitMethod: splitMethod.domain,
            occurredAt: occurredAt,
            createdByUserID: createdBy,
            createdAt: createdAt,
            updatedAt: updatedAt,
            revision: revision,
            deletedAt: deletedAt
        )
    }
}

struct SettlementRow: Codable, Equatable, Sendable {
    let id: UUID
    let groupID: UUID
    let fromUser: UUID
    let toUser: UUID
    let amountMinor: Int64
    let currencyCode: String
    let method: String
    let note: String?
    let occurredAt: Date
    let createdBy: UUID
    let createdAt: Date
    let updatedAt: Date
    let revision: Int
    let deletedAt: Date?
    var serverUpdatedAt: String?

    static let table = "settlements"
    static let columns = "id,group_id,from_user,to_user,amount_minor,currency_code,method,note,occurred_at,created_by,created_at,updated_at,revision,deleted_at"

    enum CodingKeys: String, CodingKey {
        case id, method, note, revision
        case groupID = "group_id"
        case fromUser = "from_user"
        case toUser = "to_user"
        case amountMinor = "amount_minor"
        case currencyCode = "currency_code"
        case occurredAt = "occurred_at"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case serverUpdatedAt = "server_updated_at"
    }

    init(_ settlement: Settlement) {
        id = settlement.id
        groupID = settlement.groupID
        fromUser = settlement.fromUserID
        toUser = settlement.toUserID
        amountMinor = settlement.amount.minorUnits
        currencyCode = settlement.amount.currencyCode
        method = settlement.method.rawValue
        note = settlement.note
        occurredAt = settlement.occurredAt
        createdBy = settlement.createdByUserID
        createdAt = settlement.createdAt
        updatedAt = settlement.updatedAt
        revision = settlement.revision
        deletedAt = settlement.deletedAt
    }

    var domain: Settlement {
        Settlement(
            id: id,
            groupID: groupID,
            fromUserID: fromUser,
            toUserID: toUser,
            amount: Money(minorUnits: amountMinor, currencyCode: currencyCode),
            method: SettlementMethod(rawValue: method) ?? .other,
            note: note,
            occurredAt: occurredAt,
            createdByUserID: createdBy,
            createdAt: createdAt,
            updatedAt: updatedAt,
            revision: revision,
            deletedAt: deletedAt
        )
    }
}

struct ActivityEventRow: Codable, Equatable, Sendable {
    let id: UUID
    let groupID: UUID
    let actorUserID: UUID
    let kind: String
    let subjectID: UUID
    let occurredAt: Date
    let createdAt: Date
    let revision: Int
    let deletedAt: Date?
    var serverUpdatedAt: String?

    static let table = "activity_events"
    static let columns = "id,group_id,actor_user_id,kind,subject_id,occurred_at,created_at,revision,deleted_at"

    enum CodingKeys: String, CodingKey {
        case id, kind, revision
        case groupID = "group_id"
        case actorUserID = "actor_user_id"
        case subjectID = "subject_id"
        case occurredAt = "occurred_at"
        case createdAt = "created_at"
        case deletedAt = "deleted_at"
        case serverUpdatedAt = "server_updated_at"
    }

    init(_ event: ActivityEvent) {
        id = event.id
        groupID = event.groupID
        actorUserID = event.actorUserID
        kind = event.kind.rawValue
        subjectID = event.subjectID
        occurredAt = event.occurredAt
        createdAt = event.createdAt
        revision = event.revision
        deletedAt = event.deletedAt
    }

    /// Unknown kinds from a newer app version are skipped rather than mislabelled.
    var domain: ActivityEvent? {
        guard let kind = ActivityEventKind(rawValue: kind) else { return nil }
        return ActivityEvent(
            id: id,
            groupID: groupID,
            actorUserID: actorUserID,
            kind: kind,
            subjectID: subjectID,
            occurredAt: occurredAt,
            createdAt: createdAt,
            revision: revision,
            deletedAt: deletedAt
        )
    }
}

/// What `group_preview` returns for an invite link.
struct CloudGroupPreview: Codable, Equatable, Sendable {
    struct OpenSpot: Codable, Equatable, Sendable, Identifiable {
        let userID: UUID
        let displayName: String

        var id: UUID { userID }

        enum CodingKeys: String, CodingKey {
            case userID = "user_id"
            case displayName = "display_name"
        }
    }

    let groupID: UUID
    let name: String
    let memberCount: Int
    let openSpots: [OpenSpot]

    enum CodingKeys: String, CodingKey {
        case name
        case groupID = "group_id"
        case memberCount = "member_count"
        case openSpots = "open_spots"
    }
}

// MARK: - JSON

enum SyncJSON {
    /// Postgres returns microseconds with an offset (`2026-10-06T12:44:49.123456+00:00`);
    /// Foundation's ISO 8601 parser only takes milliseconds, so trim before parsing.
    static func date(from raw: String) -> Date? {
        var value = raw.replacingOccurrences(of: " ", with: "T")
        if let dot = value.firstIndex(of: ".") {
            let fractionStart = value.index(after: dot)
            let zoneStart = value[fractionStart...].firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) ?? value.endIndex
            let digits = value[fractionStart..<zoneStart]
            let millis = String(digits.prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0)
            value = String(value[..<fractionStart]) + millis + String(value[zoneStart...])
        }
        if value.hasSuffix("+00") { value += ":00" }
        if let parsed = withFraction.date(from: value) { return parsed }
        return withoutFraction.date(from: value)
    }

    static func string(from date: Date) -> String {
        withFraction.string(from: date)
    }

    nonisolated(unsafe) private static let withFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) private static let withoutFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(string(from: date))
        }
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let date = date(from: raw) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unreadable timestamp \(raw)")
            }
            return date
        }
        return decoder
    }
}
