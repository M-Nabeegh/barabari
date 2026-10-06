import Foundation
import SwiftData

/// The ledger user id for this install.
///
/// Before cloud sync every install used the same fixed id, which is fine on one
/// phone but collides as soon as two phones share a group. The first launch of a
/// sync-capable build mints a per-install id and moves everything saved under the
/// old shared id onto it, so existing groups and balances are kept.
enum LocalIdentity {
    static let legacySharedUserID = UUID(uuidString: "56D75B9A-0238-45B6-9EF7-A3526D58B2A5")!
    static let storageKey = "barabari.localUserID"

    static func resolve(container: ModelContainer, defaults: UserDefaults = .standard) throws -> UUID {
        if let raw = defaults.string(forKey: storageKey), let stored = UUID(uuidString: raw) {
            return stored
        }
        let fresh = UUID()
        try remapUser(from: legacySharedUserID, to: fresh, in: container)
        defaults.set(fresh.uuidString, forKey: storageKey)
        return fresh
    }

    /// Rewrites every reference to `old` in the local ledger. Runs in one save, so a
    /// failure leaves the store untouched and the next launch simply tries again.
    static func remapUser(from old: UUID, to new: UUID, in container: ModelContainer) throws {
        let context = ModelContext(container)

        for group in try context.fetch(FetchDescriptor<StoredGroup>()) where group.ownerID == old {
            group.ownerID = new
        }
        for member in try context.fetch(FetchDescriptor<StoredGroupMember>()) where member.userID == old {
            member.userID = new
        }
        for expense in try context.fetch(FetchDescriptor<StoredExpense>()) {
            if expense.paidByUserID == old { expense.paidByUserID = new }
            if expense.createdByUserID == old { expense.createdByUserID = new }
            if let method = try? JSONDecoder().decode(SplitMethod.self, from: expense.splitMethodData) {
                let remapped = remap(method, from: old, to: new)
                if remapped != method {
                    expense.splitMethodData = try JSONEncoder().encode(remapped)
                }
            }
        }
        for split in try context.fetch(FetchDescriptor<StoredExpenseSplit>()) where split.userID == old {
            split.userID = new
            split.stableKey = "\(split.expenseID.uuidString):\(new.uuidString)"
        }
        for settlement in try context.fetch(FetchDescriptor<StoredSettlement>()) {
            if settlement.fromUserID == old { settlement.fromUserID = new }
            if settlement.toUserID == old { settlement.toUserID = new }
            if settlement.createdByUserID == old { settlement.createdByUserID = new }
        }
        for event in try context.fetch(FetchDescriptor<StoredActivityEvent>()) where event.actorUserID == old {
            event.actorUserID = new
        }
        if context.hasChanges {
            try context.save()
        }
    }

    private static func remap(_ method: SplitMethod, from old: UUID, to new: UUID) -> SplitMethod {
        func swap(_ values: [UUID: Int64]) -> [UUID: Int64] {
            Dictionary(values.map { ($0.key == old ? new : $0.key, $0.value) }, uniquingKeysWith: +)
        }
        switch method {
        case .equal: return .equal
        case let .exact(values): return .exact(swap(values))
        case let .percentage(values): return .percentage(swap(values))
        case let .shares(values): return .shares(swap(values))
        }
    }
}
