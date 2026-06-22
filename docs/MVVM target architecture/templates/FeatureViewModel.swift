// MVVM TEMPLATE — replace FeatureName / Item / AppError with project types.
import Foundation
import Observation

@MainActor
@Observable
final class FeatureViewModel {

    // MARK: - State

    private(set) var items: [Item] = []
    private(set) var isLoading = false
    private(set) var error: AppError?
    private(set) var hasMore = true

    // MARK: - Private

    private let repository: any FeatureRepositoryProtocol
    private var currentPage = 1
    private var loadTask: Task<Void, Never>?

    // MARK: - Init

    init(repository: any FeatureRepositoryProtocol) {
        self.repository = repository
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
            let response = try await repository.fetch(page: page)
            if reset {
                items = response.data
                currentPage = 1
            } else {
                items.append(contentsOf: response.data)
                currentPage = page
            }
            hasMore = response.hasNextPage
        } catch {
            // repository.fetch throws(AppError) — single catch branch is exhaustive
            self.error = error
            Console.error(error)
        }
    }
}
