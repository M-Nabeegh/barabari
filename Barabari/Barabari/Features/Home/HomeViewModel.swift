import Combine
import Foundation

struct HomeSnapshot: Equatable {
    let amountOwed: Money
    let amountOwing: Money
    let recentActivity: [ActivityEvent]
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

    init(environment: AppEnvironment) {
        self.environment = environment
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
            guard !groups.isEmpty else {
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

            let snapshot = HomeSnapshot(
                amountOwed: Money(minorUnits: owed, currencyCode: "PKR"),
                amountOwing: Money(minorUnits: owing, currencyCode: "PKR"),
                recentActivity: try await environment.recentActivity(limit: 5)
            )
            homeState = environment.isOffline ? .offline(snapshot) : .loaded(snapshot)
        } catch {
            homeState = .failed(error.localizedDescription)
        }
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
