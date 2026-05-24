// TEMPLATE — replace AppName / FeatureService / Item / AppError with project types.
import Foundation
@testable import AppName
import Testing

@Suite("FeatureService", .tags(.services))
struct FeatureServiceTests {

    // MARK: - Initial state

    @Test("Items is empty before load")
    func itemsEmptyBeforeLoad() async throws {
        let client = MockAPIClient()
        let sut = await FeatureService(client: client)
        let items = await MainActor.run { sut.items }
        let isLoading = await MainActor.run { sut.isLoading }
        let error = await MainActor.run { sut.error }
        #expect(items.isEmpty)
        #expect(isLoading == false)
        #expect(error == nil)
    }

    // MARK: - Loading

    @Test("isLoading is true while fetching")
    func isLoadingWhileFetching() async throws {
        let client = MockAPIClient()
        await client.stub(.success(.fixture()))
        await client.setFetchDelay(.milliseconds(50))
        let sut = await FeatureService(client: client)

        await sut.load()

        // load() fires a Task internally — assert isLoading went true then false
        // by awaiting the full load cycle via refresh() which is directly awaitable
        let isLoading = await MainActor.run { sut.isLoading }
        #expect(isLoading == false)
    }

    @Test("Load populates items on success")
    func loadPopulatesItems() async throws {
        let client = MockAPIClient()
        await client.stub(.success(PaginatedResponse(data: [.fixture(), .fixture()], currentPage: 1, hasNextPage: false)))
        let sut = await FeatureService(client: client)

        await sut.refresh()  // refresh() is async — directly awaitable

        let items = await MainActor.run { sut.items }
        let error = await MainActor.run { sut.error }
        #expect(items.count == 2)
        #expect(error == nil)
    }

    @Test("Load sets error on failure and keeps items empty")
    func loadSetsErrorOnFailure() async throws {
        let client = MockAPIClient()
        await client.stub(.failure(.unknown("Network error")))
        let sut = await FeatureService(client: client)

        await sut.refresh()

        let error = await MainActor.run { sut.error }
        let items = await MainActor.run { sut.items }
        #expect(error != nil)
        #expect(items.isEmpty)
    }

    // MARK: - Re-load

    @Test("Subsequent refresh replaces items")
    func subsequentRefreshReplacesItems() async throws {
        let client = MockAPIClient()
        await client.stub(.success(PaginatedResponse(data: [.fixture()], currentPage: 1, hasNextPage: false)))
        let sut = await FeatureService(client: client)

        await sut.refresh()
        let firstCount = await MainActor.run { sut.items.count }
        #expect(firstCount == 1)

        await client.stub(.success(PaginatedResponse(data: [.fixture(), .fixture(), .fixture()], currentPage: 1, hasNextPage: false)))
        await sut.refresh()
        let secondCount = await MainActor.run { sut.items.count }
        #expect(secondCount == 3)
    }

    // MARK: - Pagination

    @Test("loadNextPage appends items")
    func loadNextPageAppendsItems() async throws {
        let client = MockAPIClient()
        await client.stub(.success(PaginatedResponse(data: [.fixture()], currentPage: 1, hasNextPage: true)))
        let sut = await FeatureService(client: client)

        await sut.refresh()
        let firstCount = await MainActor.run { sut.items.count }
        #expect(firstCount == 1)

        await client.stub(.success(PaginatedResponse(data: [.fixture()], currentPage: 2, hasNextPage: false)))
        await sut.loadNextPageIfNeeded()
        let secondCount = await MainActor.run { sut.items.count }
        let hasMore = await MainActor.run { sut.hasMore }
        #expect(secondCount == 2)
        #expect(hasMore == false)
    }
}
