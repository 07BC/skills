# APIClient — canonical rewrite pattern

> **Project scope.** This example uses a neutral domain (articles/catalogue).
> The structural pattern — `struct`, named private helpers, typed errors — applies
> to any app. Substitute your own type, host, and endpoint names.

`APIClient` is the primary example of what clean looks like for a network client.
Use this as the reference pattern for any type that makes network requests. It is a
`struct` — not an `actor` — because it holds only `let` constants and has no shared
mutable state to protect. `async` functions already run off the main thread; an actor
would add unnecessary serialisation with no benefit.

```swift
struct APIClient: APIClientProtocol {

    // MARK: - Constants

    private enum Host {
        static let api = "api.example.com"
        static let config = "config.example.com"
    }

    private static let userAgent = "MyApp/1 CFNetwork/3860 Darwin/25.0.0"

    // MARK: - State

    private let urlSession: URLSession

    // MARK: - Init

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    // MARK: - APIClientProtocol

    /// Fetches the app configuration used for build version gating.
    func fetchAppConfig() async throws -> AppConfig {
        try await fetch(host: Host.config, path: "/config.json")
    }

    /// Fetches global server-driven settings such as feature flags.
    func fetchGlobalSettings() async throws -> GlobalSettings {
        try await fetch(host: Host.api, path: "/api/settings/global")
    }

    /// Fetches a paginated list of articles, optionally filtered.
    ///
    /// - Parameters:
    ///   - page: The page number to fetch (1-indexed).
    ///   - limit: The number of results per page.
    ///   - sort: The sort order. Defaults to `"featured"`.
    ///   - category: An optional top-level category filter.
    func fetchArticles(
        page: Int,
        limit: Int,
        sort: String = "featured",
        category: String? = nil
    ) async throws -> PaginatedResponse<Article> {
        var items = baseQueryItems(page: page, limit: limit, sort: sort)
        if let category { items.append(URLQueryItem(name: "category", value: category)) }
        return try await fetch(host: Host.api, path: "/articles", queryItems: items)
    }

    // MARK: - Private Helpers

    private func fetch<T: Decodable>(
        host: String,
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        let request = try buildRequest(host: host, path: path, queryItems: queryItems)
        let data = try await execute(request)
        return try decode(T.self, from: data)
    }

    private func buildRequest(
        host: String,
        path: String,
        queryItems: [URLQueryItem]
    ) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        if !queryItems.isEmpty { components.queryItems = queryItems }
        guard let url = components.url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func execute(_ request: URLRequest) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch let error as URLError {
            throw APIError.mapURLError(error)
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw APIError.httpError(statusCode: http.statusCode)
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try ModelDecoder.make().decode(type, from: data)
        } catch {
            throw APIError.decodingFailed(context: error.localizedDescription)
        }
    }

    private func baseQueryItems(page: Int, limit: Int, sort: String) -> [URLQueryItem] {
        [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "sort", value: sort),
        ]
    }
}
```

## Why this shape

- `struct` over `actor` when the type holds only immutable state.
- Single named responsibility per private helper (`buildRequest`, `execute`,
  `decode`, `baseQueryItems`) — none over ~20 lines.
- No inline `URLRequest` construction inside protocol methods.
- No inline `JSONDecoder()` — always via the project's shared `ModelDecoder.make()`.
- Errors propagate as typed `APIError` cases — no `try?`, no swallowed catches.
- MARK ordering: `Constants → State → Init → Protocol conformance → Private Helpers`.
