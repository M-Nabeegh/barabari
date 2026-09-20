import SwiftUI
import SwiftData

@main
struct BarabariApp: App {
    private let environment: AppEnvironment

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestingDemoState") {
            environment = AppEnvironment(inMemory: true, seedDemoData: true)
        } else if arguments.contains("-uiTestingEmptyState") {
            environment = AppEnvironment(inMemory: true)
        } else {
            environment = .live
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(environment: environment)
        }
        .modelContainer(environment.modelContainer)
    }
}

#Preview("Demo") {
    ContentView(environment: AppEnvironment.demo)
}
