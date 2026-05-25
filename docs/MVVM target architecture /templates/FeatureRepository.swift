// MVVM TEMPLATE — replace FeatureName / Item / AppError with project types.
// Repositories are stateless — no @Observable, no @MainActor.
// All state lives in ViewModels.
import Foundation

final class FeatureRepository: FeatureRepositoryProtocol, Sendable {

    // MARK: - Init

    private let client: any APIClientProtocol

    init(client: any APIClientProtocol) {
        self.client = client
    }

    // MARK: - FeatureRepositoryProtocol

    func fetch(page: Int) async throws(AppError) -> PaginatedResponse<Item> {
        let response = try await client.fetchItems(page: page)
        return response
    }
}
