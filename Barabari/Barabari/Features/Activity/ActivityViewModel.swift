import Combine
import Foundation

enum ActivityLoadingState: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case failed(String)
}

struct ActivityRow: Identifiable, Equatable {
    let event: ActivityEvent
    let expense: Expense?
    let settlement: Settlement?

    var id: UUID { event.id }
}

@MainActor
final class ActivityViewModel: ObservableObject {
    @Published private(set) var state: ActivityLoadingState = .idle
    @Published private(set) var rows: [ActivityRow] = []
    @Published private(set) var isLoadingNextPage = false
    private(set) var hasMore = false

    private let environment: AppEnvironment
    private let pageSize: Int
    private var nextCursor: String?
    private var expenseCacheByGroup: [UUID: [UUID: Expense]] = [:]
    private var settlementCacheByGroup: [UUID: [UUID: Settlement]] = [:]
    private var expenseCursorByGroup: [UUID: String?] = [:]
    private var settlementCursorByGroup: [UUID: String?] = [:]
    private var exhaustedExpenseGroups = Set<UUID>()
    private var exhaustedSettlementGroups = Set<UUID>()
    private var isLoading = false

    init(environment: AppEnvironment, pageSize: Int = 20) {
        self.environment = environment
        self.pageSize = max(pageSize, 1)
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        state = .loading
        rows = []
        nextCursor = nil
        expenseCacheByGroup = [:]
        settlementCacheByGroup = [:]
        expenseCursorByGroup = [:]
        settlementCursorByGroup = [:]
        exhaustedExpenseGroups = []
        exhaustedSettlementGroups = []
        hasMore = false
        defer { isLoading = false }

        do {
            await appendNextPage()
            if !Task.isCancelled, rows.isEmpty {
                state = .empty
            }
        } catch is CancellationError {
            return
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func loadNextPageIfNeeded(lastID: UUID) async {
        guard state == .loaded,
              hasMore,
              rows.last?.id == lastID,
              !isLoadingNextPage else { return }
        await appendNextPage()
    }

    private func appendNextPage() async {
        guard !isLoadingNextPage else { return }

        isLoadingNextPage = true
        defer { isLoadingNextPage = false }

        do {
            let page = try await environment.activityPage(limit: pageSize, cursor: nextCursor)
            let related = try await relatedRecords(for: page.items)
            guard !Task.isCancelled else { return }
            rows.append(contentsOf: page.items.map {
                ActivityRow(
                    event: $0,
                    expense: related.expenses[$0.subjectID],
                    settlement: related.settlements[$0.subjectID]
                )
            })
            nextCursor = page.nextCursor
            hasMore = page.nextCursor != nil
            state = rows.isEmpty ? .empty : .loaded
        } catch is CancellationError {
            return
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func relatedRecords(for events: [ActivityEvent]) async throws -> (expenses: [UUID: Expense], settlements: [UUID: Settlement]) {
        let expenseIDsByGroup = Dictionary(grouping: events.filter { $0.kind == .expenseCreated || $0.kind == .expenseDeleted }) {
            $0.groupID
        }.mapValues { Set($0.map(\.subjectID)) }
        let settlementIDsByGroup = Dictionary(grouping: events.filter { $0.kind == .settlementRecorded }) {
            $0.groupID
        }.mapValues { Set($0.map(\.subjectID)) }

        var expenses: [UUID: Expense] = [:]
        for (groupID, ids) in expenseIDsByGroup where !ids.isEmpty {
            let records = try await loadExpenses(ids: ids, groupID: groupID)
            expenses.merge(records) { _, latest in latest }
        }

        var settlements: [UUID: Settlement] = [:]
        for (groupID, ids) in settlementIDsByGroup where !ids.isEmpty {
            let records = try await loadSettlements(ids: ids, groupID: groupID)
            settlements.merge(records) { _, latest in latest }
        }

        return (expenses, settlements)
    }

    private func loadExpenses(ids: Set<UUID>, groupID: UUID) async throws -> [UUID: Expense] {
        var cache = expenseCacheByGroup[groupID, default: [:]]
        guard !ids.allSatisfy({ cache[$0] != nil }), !exhaustedExpenseGroups.contains(groupID) else {
            return cache.filter { ids.contains($0.key) }
        }

        var cursor = expenseCursorByGroup[groupID] ?? nil
        repeat {
            try Task.checkCancellation()
            let page = try await environment.expenseRepository.listExpenses(groupID: groupID, cursor: cursor)
            for expense in page.items {
                cache[expense.id] = expense
            }
            cursor = page.nextCursor
            if ids.allSatisfy({ cache[$0] != nil }) {
                break
            }
            if cursor == nil {
                exhaustedExpenseGroups.insert(groupID)
                break
            }
        } while true

        expenseCacheByGroup[groupID] = cache
        expenseCursorByGroup[groupID] = cursor
        return cache.filter { ids.contains($0.key) }
    }

    private func loadSettlements(ids: Set<UUID>, groupID: UUID) async throws -> [UUID: Settlement] {
        var cache = settlementCacheByGroup[groupID, default: [:]]
        guard !ids.allSatisfy({ cache[$0] != nil }), !exhaustedSettlementGroups.contains(groupID) else {
            return cache.filter { ids.contains($0.key) }
        }

        var cursor = settlementCursorByGroup[groupID] ?? nil
        repeat {
            try Task.checkCancellation()
            let page = try await environment.settlementRepository.listSettlements(groupID: groupID, cursor: cursor)
            for settlement in page.items {
                cache[settlement.id] = settlement
            }
            cursor = page.nextCursor
            if ids.allSatisfy({ cache[$0] != nil }) {
                break
            }
            if cursor == nil {
                exhaustedSettlementGroups.insert(groupID)
                break
            }
        } while true

        settlementCacheByGroup[groupID] = cache
        settlementCursorByGroup[groupID] = cursor
        return cache.filter { ids.contains($0.key) }
    }
}
