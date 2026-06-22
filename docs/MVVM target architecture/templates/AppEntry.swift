// MVVM TEMPLATE — replace AppName with your app target name.
import SwiftUI

@main
struct AppNameApp: App {

    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootView()
                // One .environment() per repository, matching EnvironmentRepositories.swift.
                .environment(\.authRepository, dependencies.authRepository)
                .environment(\.featureRepository, dependencies.featureRepository)
        }
    }
}
