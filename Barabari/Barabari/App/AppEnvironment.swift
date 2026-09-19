import SwiftData

/// Keeps storage and external-provider details out of SwiftUI features.
/// V1 runs fully locally until a remote repository adapter is introduced.
@MainActor
struct AppEnvironment {
    let modelContainer: ModelContainer

    static let live = AppEnvironment(inMemory: false)
    static let demo = AppEnvironment(inMemory: true, seedDemoData: true)

    init(inMemory: Bool, seedDemoData: Bool = false) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)

        do {
            modelContainer = try ModelContainer(
                for: GroupRecord.self,
                ActivityRecord.self,
                configurations: configuration
            )
        } catch {
            fatalError("Unable to create Barabari's local store: \(error.localizedDescription)")
        }

        if seedDemoData {
            seedIfNeeded()
        }
    }

    private func seedIfNeeded() {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<GroupRecord>()
        guard (try? context.fetchCount(descriptor)) == 0 else { return }

        context.insert(GroupRecord(name: "Apartment 7B", detail: "4 members"))
        context.insert(GroupRecord(name: "Hunza Trip", detail: "6 members"))
        context.insert(ActivityRecord(
            title: "Dinner added",
            subtitle: "You paid for Apartment 7B",
            amountInPaisa: 4_800_00
        ))
        context.insert(ActivityRecord(
            title: "Ali settled up",
            subtitle: "Raast payment recorded",
            amountInPaisa: 3_250_00
        ))

        try? context.save()
    }
}

