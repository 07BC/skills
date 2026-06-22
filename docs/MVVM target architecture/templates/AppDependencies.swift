import Foundation

// Composition root. Builds every repository once at app launch.
// Pure wiring — no business logic here. ViewModels are NOT constructed here.
@MainActor
struct AppDependencies {

    let authRepository: any AuthRepositoryProtocol
    let featureRepository: any FeatureRepositoryProtocol
    // Add new repositories here.

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

        self.authRepository = isTestOrPreview
            ? MockAuthRepository()
            : AuthRepository(client: apiClient, storage: storage, tokenProvider: tokenProvider)

        self.featureRepository = isTestOrPreview
            ? MockFeatureRepository()
            : FeatureRepository(client: apiClient)
    }
}
