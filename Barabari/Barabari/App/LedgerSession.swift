import Combine

@MainActor
final class LedgerSession: ObservableObject {
    /// Bumps on any change, so screens reload.
    @Published private(set) var revision = 0
    /// Bumps only for writes made on this phone, so they get pushed.
    @Published private(set) var localWrites = 0

    func markChanged() {
        revision &+= 1
        localWrites &+= 1
    }

    /// Another member's change arrived through sync; reload without pushing it back.
    func markRemoteChanged() {
        revision &+= 1
    }
}
