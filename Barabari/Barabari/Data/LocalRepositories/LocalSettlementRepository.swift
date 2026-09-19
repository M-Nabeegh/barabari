import Foundation
import SwiftData

final actor LocalSettlementRepository: SettlementRepository {
    private let container: ModelContainer
    private let pageSize = 50

    init(container: ModelContainer) {
        self.container = container
    }

    func listSettlements(groupID: UUID, cursor: String?) throws -> Page<Settlement> {
        let context = ModelContext(container)
        let settlements = try context.fetch(FetchDescriptor<StoredSettlement>())
            .filter { $0.groupID == groupID && $0.deletedAt == nil }
            .map(\.asDomain)
            .sorted(by: sortSettlements)
        return page(items: settlements, cursor: cursor)
    }

    func saveSettlement(_ settlement: Settlement, idempotencyKey: UUID) throws -> Settlement {
        let context = ModelContext(container)
        let records = try context.fetch(FetchDescriptor<StoredSettlement>())
        if let idempotentRecord = records.first(where: { $0.idempotencyKey == idempotencyKey }) {
            return idempotentRecord.asDomain
        }

        let isNew: Bool
        let record: StoredSettlement
        if let existing = records.first(where: { $0.id == settlement.id }) {
            existing.apply(settlement, idempotencyKey: idempotencyKey)
            record = existing
            isNew = false
        } else {
            record = StoredSettlement(settlement: settlement, idempotencyKey: idempotencyKey)
            context.insert(record)
            isNew = true
        }
        if isNew {
            context.insert(StoredActivityEvent(event: ActivityEvent(
                groupID: settlement.groupID,
                actorUserID: settlement.createdByUserID,
                kind: .settlementRecorded,
                subjectID: settlement.id,
                occurredAt: settlement.occurredAt
            )))
        }
        try context.save()
        return record.asDomain
    }

    func settlementsForSync(groupID: UUID) throws -> [Settlement] {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<StoredSettlement>())
            .filter { $0.groupID == groupID }
            .map(\.asDomain)
            .sorted(by: sortSettlements)
    }

    private func page(items: [Settlement], cursor: String?) -> Page<Settlement> {
        let start = min(max(Int(cursor ?? "0") ?? 0, 0), items.count)
        let end = min(start + pageSize, items.count)
        return Page(items: Array(items[start..<end]), nextCursor: end < items.count ? String(end) : nil)
    }

    private func sortSettlements(_ lhs: Settlement, _ rhs: Settlement) -> Bool {
        if lhs.occurredAt != rhs.occurredAt { return lhs.occurredAt > rhs.occurredAt }
        return uuidBytes(lhs.id).lexicographicallyPrecedes(uuidBytes(rhs.id))
    }

    private func uuidBytes(_ id: UUID) -> [UInt8] {
        withUnsafeBytes(of: id.uuid) { Array($0) }
    }
}
