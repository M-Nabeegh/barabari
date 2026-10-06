import Foundation

/// Where this build syncs to. Read from Info.plist so the same code can point at
/// another project; missing values leave the app fully local.
struct SyncConfiguration: Equatable, Sendable {
    let projectURL: URL
    let anonKey: String

    static func fromBundle(_ bundle: Bundle = .main) -> SyncConfiguration? {
        guard let rawURL = bundle.object(forInfoDictionaryKey: "BarabariSupabaseURL") as? String,
              let url = URL(string: rawURL.trimmingCharacters(in: .whitespaces)),
              url.scheme == "https",
              let key = bundle.object(forInfoDictionaryKey: "BarabariSupabaseAnonKey") as? String,
              !key.trimmingCharacters(in: .whitespaces).isEmpty else {
            return nil
        }
        return SyncConfiguration(projectURL: url, anonKey: key)
    }
}
