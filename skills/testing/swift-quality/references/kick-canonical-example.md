# KickAPIClient — canonical rewrite pattern (Kick tvOS project)

> **Project scope.** This example is drawn from the `kick-apple-public` /
> Kick tvOS codebase. Apply it as a reference shape when working in that
> project. For other projects, treat it as illustrative of the structural
> pattern, not the naming or type identifiers.

`KickAPIClient` is the primary example of what clean looks like for the Kick
tvOS codebase. Use this as the reference pattern for any type that makes
network requests. It is a `struct` — not an `actor` — because it holds only
`let` constants and has no shared mutable state to protect. `async` functions
already run off the main thread; an actor would add unnecessary serialisation
with no benefit.

```swift
struct KickAPIClient: KickAPIClientProtocol {

    // MARK: - Constants

    private enum Host {
        static let kick = "kick.com"
        static let appConfig = "kick-app-config.kick.com"
    }

    private static let userAgent = "KickAppleTV/2000 CFNetwork/3860.500.112 Darwin/25.4.0"

    // MARK: - State

    private let urlSession: URLSession

    // MARK: - Init

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    // MARK: - KickAPIClientProtocol

    /// Fetches the app configuration used for build version gating.
    func fetchAppConfig() async throws -> AppConfig {
        try await fetch(host: Host.appConfig, path: "/apple-public.json")
    }

    /// Fetches global server-driven settings such as event tracking intervals.
    func fetchGlobalSettings() async throws -> GlobalSettings {
        try await fetch(host: Host.kick, path: "/api/internal/settings/global")
    }

    /// Fetches a paginated list of live streams, optionally filtered.
    ///
    /// - Parameters:
    ///   - page: The page number to fetch (1-indexed).
    ///   - limit: The number of results per page.
    ///   - sort: The sort order. Defaults to `"featured"`.
    ///   - category: An optional top-level category filter.
    ///   - subcategory: An optional subcategory slug filter.
    func fetchLivestreams(
        page: Int,
        limit: Int,
        sort: String = "featured",
        category: String? = nil,
        subcategory: String? = nil
    ) async throws -> PaginatedResponse<Stream> {
        var items = baseQueryItems(page: page, limit: limit, sort: sort)
        if let category { items.append(URLQueryItem(name: "category", value: category)) }
        if let subcategory { items.append(URLQueryItem(name: "subcategory", value: subcategory)) }
        return try await fetch(host: Host.kick, path: "/stream/livestreams/en", queryItems: items)
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
        guard let url = components.url else { throw KickError.invalidURL }
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
            throw KickError.mapURLError(error)
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw KickError.httpError(statusCode: http.statusCode)
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try ModelDecoder.make().decode(type, from: data)
        } catch {
            throw KickError.decodingFailed(context: error.localizedDescription)
        }
    }

    private func baseQueryItems(page: Int, limit: Int, sort: String) -> [URLQueryItem] {
        [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "strict", value: "false"),
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
- Errors propagate as typed `KickError` cases — no `try?`, no swallowed catches.
- MARK ordering: `Constants → State → Init → Protocol conformance → Private Helpers`.
