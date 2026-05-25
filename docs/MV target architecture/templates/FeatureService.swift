// TEMPLATE — replace FeatureName / Item / AppError with project types.
import Foundation
import Observation

@MainActor
@Observable
final class FeatureService {

    // MARK: - State

    private(set) var items: [Item] = []
    private(set) var isLoading = false
    private(set) var error: AppError?
    private(set) var hasMore = true

    // MARK: - Private

    private let fetcher: ItemFetcher
    private var currentPage = 1
    private var loadTask: Task<Void, Never>?

    // MARK: - Init

    init(client: any APIClientProtocol) {
        self.fetcher = ItemFetcher(client: client)
    }

    // MARK: - Intent

    func load() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            await performLoad(page: 1, reset: true)
        }
    }

    func loadNextPage() {
        guard hasMore, !isLoading else { return }
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            await performLoad(page: currentPage + 1, reset: false)
        }
    }

    /// Awaitable variant for use in tests and pagination triggers.
    func loadNextPageIfNeeded() async {
        guard hasMore, !isLoading else { return }
        loadTask?.cancel()
        await performLoad(page: currentPage + 1, reset: false)
    }

    func refresh() async {
        loadTask?.cancel()
        await performLoad(page: 1, reset: true)
    }

    // MARK: - Private

    private func performLoad(page: Int, reset: Bool) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let fetched = try await fetcher.fetch(page: page)
            if reset {
                items = fetched
                currentPage = 1
            } else {
                items.append(contentsOf: fetched)
                currentPage = page
            }
            hasMore = !fetched.isEmpty
        } catch {
            // fetcher.fetch throws(AppError) — single catch branch is exhaustive
            self.error = error
            Console.error(error)
        }
    }
}

// MARK: - Fetcher (off-main, stateless)

struct ItemFetcher {
    private let client: any APIClientProtocol

    init(client: any APIClientProtocol) {
        self.client = client
    }

    func fetch(page: Int) async throws(AppError) -> [Item] {
        let response = try await client.fetchItems(page: page)
        return response.data
    }
}
