import SwiftUI
import SwiftData

@main
struct BarabariApp: App {
    private let environment = AppEnvironment.live

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
