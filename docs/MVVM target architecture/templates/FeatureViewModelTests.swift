// MVVM TEMPLATE — replace AppName / FeatureViewModel / Item / AppError with project types.
import Foundation
@testable import AppName
import Testing

@Suite("FeatureViewModel", .tags(.viewModels))
struct FeatureViewModelTests {

    // MARK: - Initial state

    @Test("Items is empty before load")
    func itemsEmptyBeforeLoad() async throws {
        let repo = MockFeatureRepository()
        let sut = await FeatureViewModel(repository: repo)
        let items = await MainActor.run { sut.items }
        let isLoading = await MainActor.run { sut.isLoading }
        let error = await MainActor.run { sut.error }
        #expect(items.isEmpty)
        #expect(isLoading == false)
        #expect(error == nil)
    }

    // MARK: - Loading

    @Test("Load populates items on success")
    func loadPopulatesItems() async throws {
        let repo = MockFeatureRepository()
        await repo.stub(.success(PaginatedResponse(data: [.fixture(), .fixture()], currentPage: 1, hasNextPage: false)))
        let sut = await FeatureViewModel(repository: repo)

        await sut.refresh()

        let items = await MainActor.run { sut.items }
        let error = await MainActor.run { sut.error }
        #expect(items.count == 2)
        #expect(error == nil)
    }

    @Test("Load sets error on failure and keeps items empty")
    func loadSetsErrorOnFailure() async throws {
        let repo = MockFeatureRepository()
        await repo.stub(.failure(.unknown("Network error")))
        let sut = await FeatureViewModel(repository: repo)

        await sut.refresh()

        let error = await MainActor.run { sut.error }
        let items = await MainActor.run { sut.items }
        #expect(error != nil)
        #expect(items.isEmpty)
    }

    // MARK: - Re-load

    @Test("Subsequent refresh replaces items")
    func subsequentRefreshReplacesItems() async throws {
        let repo = MockFeatureRepository()
        await repo.stub(.success(PaginatedResponse(data: [.fixture()], currentPage: 1, hasNextPage: false)))
        let sut = await FeatureViewModel(repository: repo)

        await sut.refresh()
        let firstCount = await MainActor.run { sut.items.count }
        #expect(firstCount == 1)

        await repo.stub(.success(PaginatedResponse(data: [.fixture(), .fixture(), .fixture()], currentPage: 1, hasNextPage: false)))
        await sut.refresh()
        let secondCount = await MainActor.run { sut.items.count }
        #expect(secondCount == 3)
    }

    // MARK: - Pagination

    @Test("loadNextPageIfNeeded appends items")
    func loadNextPageAppendsItems() async throws {
        let repo = MockFeatureRepository()
        await repo.stub(.success(PaginatedResponse(data: [.fixture()], currentPage: 1, hasNextPage: true)))
        let sut = await FeatureViewModel(repository: repo)

        await sut.refresh()
        let firstCount = await MainActor.run { sut.items.count }
        #expect(firstCount == 1)

        await repo.stub(.success(PaginatedResponse(data: [.fixture()], currentPage: 2, hasNextPage: false)))
        await sut.loadNextPageIfNeeded()
        let secondCount = await MainActor.run { sut.items.count }
        let hasMore = await MainActor.run { sut.hasMore }
        #expect(secondCount == 2)
        #expect(hasMore == false)
    }
}
