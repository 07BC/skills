// MVVM TEMPLATE — replace AppName / FeatureRepository / Item / AppError with project types.
import Foundation
@testable import AppName
import Testing

@Suite("FeatureRepository", .tags(.repositories))
struct FeatureRepositoryTests {

    // MARK: - Helpers

    private func makeRepository(data: Data, statusCode: Int = 200) -> FeatureRepository {
        FeatureRepository(
            client: APIClient(
                urlSession: .mock { request in
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: statusCode,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                    return (response, data)
                },
                tokenProvider: MockAuthTokenProvider()
            )
        )
    }

    // MARK: - fetch(page:)

    @Test("fetch returns decoded items from API response")
    func fetchReturnsDecodedItems() async throws {
        let sut = makeRepository(data: ResponseFixtures.items())
        let response = try await sut.fetch(page: 1)
        #expect(response.data.count == 1)
    }

    @Test("fetch throws AppError on non-200 response")
    func fetchThrowsOnNon200() async throws {
        let sut = makeRepository(data: Data(), statusCode: 500)
        #expect(throws: AppError.self) {
            _ = try await sut.fetch(page: 1)
        }
    }

    @Test("fetch passes correct page parameter")
    func fetchPassesPageParameter() async throws {
        let client = MockAPIClient()
        let sut = FeatureRepository(client: client)

        _ = try? await sut.fetch(page: 3)

        let callCount = await client.fetchItemsCallCount
        let lastPage = await client.lastFetchedPage
        #expect(callCount == 1)
        #expect(lastPage == 3)
    }
}
