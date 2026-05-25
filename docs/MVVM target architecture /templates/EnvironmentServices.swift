import SwiftUI

// Register one @Entry per repository.
// Default values are always mocks so previews work without wiring.
// ViewModels are NOT registered here — they are owned by their Views via @State.
extension EnvironmentValues {
    @Entry var authRepository: any AuthRepositoryProtocol = MockAuthRepository()
    @Entry var featureRepository: any FeatureRepositoryProtocol = MockFeatureRepository()
    // Add new repositories here as the app grows.
}
