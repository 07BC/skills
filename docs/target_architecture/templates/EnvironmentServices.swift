import SwiftUI

// Register one @Entry per service.
// Default values are always mocks so previews work without wiring.
extension EnvironmentValues {
    @Entry var authService: any AuthServiceProtocol = MockAuthService()
    @Entry var featureService: any FeatureServiceProtocol = MockFeatureService()
    // Add new services here as the app grows.
}
