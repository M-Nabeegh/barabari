import Foundation

enum LocalLedgerExport {
    private struct Payload: Codable {
        let formatVersion: Int
        let exportedAt: Date
        let groups: [Group]
        let expenses: [Expense]
        let settlements: [Settlement]
    }

    static func json(groups: [Group], expenses: [Expense], settlements: [Settlement], exportedAt: Date = .now) throws -> String {
        let payload = Payload(
            formatVersion: 1,
            exportedAt: exportedAt,
            groups: groups,
            expenses: expenses,
            settlements: settlements
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return String(decoding: try encoder.encode(payload), as: UTF8.self)
    }

    static func csv(groups: [Group], expenses: [Expense], settlements: [Settlement], exportedAt: Date = .now) -> String {
        let dateFormatter = ISO8601DateFormatter()
        var lines = [
            "record_type,id,group_id,title,description,amount_minor_units,currency_code,occurred_at,exported_at"
        ]
        let exportedDate = dateFormatter.string(from: exportedAt)
        lines += groups.map {
            row([
                "group", $0.id.uuidString, $0.id.uuidString, $0.name,
                $0.description ?? "", "", "", dateFormatter.string(from: $0.createdAt), exportedDate
            ])
        }
        lines += expenses.map {
            row([
                "expense", $0.id.uuidString, $0.groupID.uuidString, $0.title,
                $0.note ?? "", String($0.total.minorUnits), $0.total.currencyCode,
                dateFormatter.string(from: $0.occurredAt), exportedDate
            ])
        }
        lines += settlements.map {
            row([
                "settlement", $0.id.uuidString, $0.groupID.uuidString, $0.method.title,
                $0.note ?? "", String($0.amount.minorUnits), $0.amount.currencyCode,
                dateFormatter.string(from: $0.occurredAt), exportedDate
            ])
        }
        return lines.joined(separator: "\n")
    }

    private static func row(_ values: [String]) -> String {
        values.map(escape).joined(separator: ",")
    }

    private static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
