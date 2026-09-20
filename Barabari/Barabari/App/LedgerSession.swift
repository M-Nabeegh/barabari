import Combine

@MainActor
final class LedgerSession: ObservableObject {
    @Published private(set) var revision = 0

    func markChanged() {
        revision &+= 1
    }
}
