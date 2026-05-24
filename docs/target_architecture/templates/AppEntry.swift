// TEMPLATE — replace AppName with your app target name.
import SwiftUI

@main
struct AppNameApp: App {

    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootView()
                // One .environment() per service, matching EnvironmentServices.swift.
                .environment(\.authService, dependencies.authService)
                .environment(\.featureService, dependencies.featureService)
        }
    }
}
