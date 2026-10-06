import Combine
import Foundation
import WidgetKit

struct CategorySpend: Equatable, Identifiable {
    let category: ExpenseCategory
    let minorUnits: Int64

    var id: ExpenseCategory { category }
}

struct HomeSnapshot: Equatable {
    let amountOwed: Money
    let amountOwing: Money
    let recentActivity: [ActivityEvent]
    var spending: [CategorySpend] = []
    /// Expenses behind the recent activity rows, keyed by expense ID.
    var expenses: [UUID: Expense] = [:]
}

enum HomeState: Equatable {
    case loading
    case loaded(HomeSnapshot)
    case empty
    case offline(HomeSnapshot)
    case failed(String)
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var homeState: HomeState = .loading

    private let environment: AppEnvironment
    private let metadata: LedgerMetadata

    init(environment: AppEnvironment, metadata: LedgerMetadata? = nil) {
        self.environment = environment
        self.metadata = metadata ?? .shared
    }

    func load() async {
        homeState = .loading
        await fetchHome()
    }

    func refresh() async {
        await fetchHome()
    }

    private func fetchHome() async {
        do {
            let groups = try await environment.groupRepository.listGroups()
            // Someone who only tracks personal money still gets the full Home.
            guard !groups.isEmpty || !environment.personalFinance.transactions.isEmpty else {
                homeState = .empty
                return
            }

            var owed = Int64.zero
            var owing = Int64.zero
            for group in groups {
                let summary = try await environment.balanceRepository.summary(groupID: group.id)
                guard let position = summary.netPosition(for: environment.currentUserID) else { continue }
                if position.amount.minorUnits >= 0 {
                    let result = owed.addingReportingOverflow(position.amount.minorUnits)
                    guard !result.overflow else { throw HomeLoadingError.balanceOverflow }
                    owed = result.partialValue
                } else {
                    let magnitude = position.amount.minorUnits.multipliedFullWidth(by: -1)
                    guard magnitude.high == 0, magnitude.low <= UInt64(Int64.max) else {
                        throw HomeLoadingError.balanceOverflow
                    }
                    let result = owing.addingReportingOverflow(Int64(magnitude.low))
                    guard !result.overflow else { throw HomeLoadingError.balanceOverflow }
                    owing = result.partialValue
                }
            }

            let expenses = try await allExpenses(groups: groups)
            let snapshot = HomeSnapshot(
                amountOwed: Money(minorUnits: owed, currencyCode: "PKR"),
                amountOwing: Money(minorUnits: owing, currencyCode: "PKR"),
                recentActivity: try await environment.recentActivity(limit: 5),
                spending: spendingByCategory(expenses: expenses),
                expenses: Dictionary(uniqueKeysWithValues: expenses.map { ($0.id, $0) })
            )
            homeState = environment.isOffline ? .offline(snapshot) : .loaded(snapshot)
            publishWidgetSnapshot(snapshot, groups: groups)
        } catch {
            homeState = .failed(error.localizedDescription)
        }
    }
}

extension HomeViewModel {
    func allExpenses(groups: [Group]) async throws -> [Expense] {
        var expenses: [Expense] = []
        for group in groups {
            var cursor: String?
            repeat {
                let page = try await environment.expenseRepository.listExpenses(groupID: group.id, cursor: cursor)
                expenses += page.items.filter { $0.deletedAt == nil }
                cursor = page.nextCursor
            } while cursor != nil
        }
        return expenses
    }

    /// Your personal spending plus your share of every group expense, by category, largest first.
    func spendingByCategory(expenses: [Expense]) -> [CategorySpend] {
        var totals: [ExpenseCategory: Int64] = [:]
        for transaction in environment.personalFinance.transactions {
            guard let category = transaction.expenseCategory else { continue }
            totals[category, default: 0] += transaction.amountMinor
        }
        for expense in expenses {
            guard let share = expense.splits.first(where: { $0.userID == environment.currentUserID }) else { continue }
            totals[metadata.category(for: expense), default: 0] += share.amount.minorUnits
        }
        return totals
            .filter { $0.value > 0 }
            .map { CategorySpend(category: $0.key, minorUnits: $0.value) }
            .sorted { $0.minorUnits == $1.minorUnits ? $0.category.rawValue < $1.category.rawValue : $0.minorUnits > $1.minorUnits }
    }
}

extension HomeViewModel {
    /// Shares the balance with the home screen widget. Demo and test stores never publish.
    fileprivate func publishWidgetSnapshot(_ snapshot: HomeSnapshot, groups: [Group]) {
        guard !environment.isDemo else { return }
        let widget = WidgetSnapshot(
            netMinorUnits: snapshot.amountOwed.minorUnits - snapshot.amountOwing.minorUnits,
            owedMinorUnits: snapshot.amountOwed.minorUnits,
            owingMinorUnits: snapshot.amountOwing.minorUnits,
            groups: groups.prefix(3).map { WidgetSnapshot.GroupLine(id: $0.id, name: $0.name) },
            updatedAt: .now
        )
        guard widget.netMinorUnits != WidgetSnapshot.load()?.netMinorUnits
            || widget.groups != WidgetSnapshot.load()?.groups else { return }
        widget.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

private enum HomeLoadingError: LocalizedError {
    case balanceOverflow

    var errorDescription: String? {
        switch self {
        case .balanceOverflow:
            "Your balances are too large to display safely."
        }
    }
}
