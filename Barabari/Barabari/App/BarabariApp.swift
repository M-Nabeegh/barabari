import SwiftUI

@main
struct BarabariApp: App {
    private let environment = AppEnvironment.live

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(environment.modelContainer)
    }
}

#Preview("Demo") {
    ContentView()
        .modelContainer(AppEnvironment.demo.modelContainer)
}

