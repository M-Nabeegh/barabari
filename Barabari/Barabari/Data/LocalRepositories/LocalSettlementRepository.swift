import Foundation
import SwiftData

final actor LocalSettlementRepository: SettlementRepository {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func listSettlements(groupID: UUID, cursor: String?) throws -> Page<Settlement> {
        let context = ModelContext(container)
        let settlements = try context.fetch(FetchDescriptor<StoredSettlement>())
            .filter { $0.groupID == groupID && $0.deletedAt == nil }
            .map(\.asDomain)
            .sorted(by: sortSettlements)
        return try LocalLedgerPagination.page(
            items: settlements,
            cursor: cursor,
            occurredAt: \.occurredAt,
            id: \.id
        )
    }

    func saveSettlement(_ settlement: Settlement, idempotencyKey: UUID) throws -> Settlement {
        let context = ModelContext(container)
        if let command = try command(for: idempotencyKey, context: context) {
            return try existingSettlement(for: command, context: context)
        }

        let records = try context.fetch(FetchDescriptor<StoredSettlement>())
        let isNew: Bool
        let record: StoredSettlement
        if let existing = records.first(where: { $0.id == settlement.id }) {
            existing.apply(settlement)
            record = existing
            isNew = false
        } else {
            record = StoredSettlement(settlement: settlement)
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
        context.insert(StoredLedgerCommand(
            idempotencyKey: idempotencyKey,
            kind: .saveSettlement,
            subjectID: settlement.id
        ))
        do {
            try context.save()
        } catch {
            let recoveryContext = ModelContext(container)
            if let command = try? command(for: idempotencyKey, context: recoveryContext) {
                return try existingSettlement(for: command, context: recoveryContext)
            }
            throw error
        }
        return record.asDomain
    }

    func settlementsForSync(groupID: UUID) throws -> [Settlement] {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<StoredSettlement>())
            .filter { $0.groupID == groupID }
            .map(\.asDomain)
            .sorted(by: sortSettlements)
    }

    private func command(for key: UUID, context: ModelContext) throws -> StoredLedgerCommand? {
        try context.fetch(FetchDescriptor<StoredLedgerCommand>()).first { $0.idempotencyKey == key }
    }

    private func existingSettlement(for command: StoredLedgerCommand, context: ModelContext) throws -> Settlement {
        guard command.kind == .saveSettlement else {
            throw LocalPersistenceError.idempotencyKeyConflict(command.idempotencyKey)
        }
        guard let record = try context.fetch(FetchDescriptor<StoredSettlement>()).first(where: { $0.id == command.subjectID }) else {
            throw LocalPersistenceError.missingIdempotencySubject(command.idempotencyKey)
        }
        return record.asDomain
    }

    private func sortSettlements(_ lhs: Settlement, _ rhs: Settlement) -> Bool {
        if lhs.occurredAt != rhs.occurredAt { return lhs.occurredAt > rhs.occurredAt }
        return uuidBytes(lhs.id).lexicographicallyPrecedes(uuidBytes(rhs.id))
    }

    private func uuidBytes(_ id: UUID) -> [UInt8] {
        withUnsafeBytes(of: id.uuid) { Array($0) }
    }
}
