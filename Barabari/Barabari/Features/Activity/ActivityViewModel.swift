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
    private var allEvents: [ActivityEvent] = []
    private var nextOffset = 0
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
        allEvents = []
        nextOffset = 0
        hasMore = false
        defer { isLoading = false }

        do {
            let groups = try await environment.groupRepository.listGroups()
            for group in groups {
                try Task.checkCancellation()
                allEvents += try await environment.activity(groupID: group.id)
            }
            allEvents = allEvents
                .filter { $0.deletedAt == nil }
                .sorted(by: Self.sortEvents)
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
        guard !isLoadingNextPage, nextOffset < allEvents.count else {
            hasMore = nextOffset < allEvents.count
            return
        }

        isLoadingNextPage = true
        defer { isLoadingNextPage = false }

        let endOffset = min(nextOffset + pageSize, allEvents.count)
        let pageEvents = Array(allEvents[nextOffset..<endOffset])
        do {
            let related = try await relatedRecords(for: pageEvents)
            guard !Task.isCancelled else { return }
            rows.append(contentsOf: pageEvents.map {
                ActivityRow(
                    event: $0,
                    expense: related.expenses[$0.subjectID],
                    settlement: related.settlements[$0.subjectID]
                )
            })
            nextOffset = endOffset
            hasMore = nextOffset < allEvents.count
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
            var cursor: String?
            repeat {
                try Task.checkCancellation()
                let page = try await environment.expenseRepository.listExpenses(groupID: groupID, cursor: cursor)
                for expense in page.items where ids.contains(expense.id) {
                    expenses[expense.id] = expense
                }
                if Set(expenses.keys).isSuperset(of: ids) { break }
                cursor = page.nextCursor
            } while cursor != nil
        }

        var settlements: [UUID: Settlement] = [:]
        for (groupID, ids) in settlementIDsByGroup where !ids.isEmpty {
            var cursor: String?
            repeat {
                try Task.checkCancellation()
                let page = try await environment.settlementRepository.listSettlements(groupID: groupID, cursor: cursor)
                for settlement in page.items where ids.contains(settlement.id) {
                    settlements[settlement.id] = settlement
                }
                if Set(settlements.keys).isSuperset(of: ids) { break }
                cursor = page.nextCursor
            } while cursor != nil
        }

        return (expenses, settlements)
    }

    private static func sortEvents(_ lhs: ActivityEvent, _ rhs: ActivityEvent) -> Bool {
        if lhs.occurredAt != rhs.occurredAt { return lhs.occurredAt > rhs.occurredAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
