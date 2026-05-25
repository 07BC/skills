// MVVM TEMPLATE — replace AppName / Item / AppError with project types.
// Lives in Infrastructure/Mocks/. Compiled only in DEBUG.
#if DEBUG
import Foundation

actor MockAPIClient: APIClientProtocol {

    // MARK: - Configuration (set before calling methods)

    var fetchItemsResult: Result<PaginatedResponse<Item>, AppError> = .success(.fixture())
    var fetchDelay: Duration?

    // MARK: - Recorded calls

    private(set) var fetchItemsCallCount = 0
    private(set) var lastFetchedPage: Int?

    // MARK: - APIClientProtocol

    func fetchItems(page: Int) async throws(AppError) -> PaginatedResponse<Item> {
        fetchItemsCallCount += 1
        lastFetchedPage = page
        if let delay = fetchDelay {
            try? await Task.sleep(for: delay)
        }
        return try fetchItemsResult.get()
    }

    // MARK: - Test helpers

    func stub(_ result: Result<PaginatedResponse<Item>, AppError>) {
        fetchItemsResult = result
    }
}

// MARK: - Fixtures

extension PaginatedResponse where T == Item {
    static func fixture(
        data: [Item] = [.fixture()],
        currentPage: Int = 1,
        hasNextPage: Bool = false
    ) -> PaginatedResponse<Item> {
        PaginatedResponse(data: data, currentPage: currentPage, hasNextPage: hasNextPage)
    }
}
#endif
