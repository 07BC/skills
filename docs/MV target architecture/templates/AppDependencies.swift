import Foundation

// Composition root. Builds every service once at app launch.
// Pure wiring — no business logic here.
@MainActor
struct AppDependencies {

    let authService: AuthService
    let featureService: FeatureService
    // Add new services here.

    init() {
        let isTestOrPreview = ProcessInfo.processInfo.isRunningTests
            || ProcessInfo.processInfo.isRunningInPreview

        let tokenProvider: any AuthTokenProviding = isTestOrPreview
            ? MockAuthTokenProvider()
            : AuthTokenProvider()

        let storage: any StorageServiceProtocol = isTestOrPreview
            ? MockStorageService()
            : StorageService()

        let apiClient: any APIClientProtocol = isTestOrPreview
            ? MockAPIClient()
            : APIClient(tokenProvider: tokenProvider)

        self.authService = AuthService(
            client: apiClient,
            storage: storage,
            tokenProvider: tokenProvider
        )

        self.featureService = FeatureService(client: apiClient)
    }
}
