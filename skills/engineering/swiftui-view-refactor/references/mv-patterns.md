# MV Patterns Reference

A practical decision aid for whether a SwiftUI feature should stay plain MV or introduce
a view model. MV is the default; a view model is the exception that must earn its place.

Distilled from Thomas Ricouard's "SwiftUI in 2025: Forget MVVM", rewritten as a
refactoring reference and aligned with this repo's MV architecture authority
(`swift-mv-architecture`).

## Default stance

- Views are lightweight state expressions and orchestration points.
- Prefer `@State`, `@Environment`, `@Query`, `.task`, `.task(id:)`, and `onChange` before
  reaching for a view model.
- Keep business logic in `@Observable` services, models, or domain types — never the body.
- Split large screens into smaller view types before inventing a view model layer.
- Test services, models, and transformations; views stay simple and declarative.

## When to AVOID a view model

Do not introduce one when it would mostly:
- mirror local view state,
- wrap values already reachable through `@Environment`,
- duplicate `@Query`, `@State`, or `Binding` data flow,
- exist only because the body is too long (split into subviews instead),
- hold one-off async loading that fits in `.task` plus local view state.

In each case, simplify the view and data flow rather than adding indirection.

## When a view model MAY be justified

Reasonable when at least one holds:
- the request explicitly asks for one,
- the feature's codebase already standardises on the pattern,
- the screen needs a long-lived reference model whose behaviour does not fit a service,
- it bridges a non-SwiftUI API that needs a dedicated adapter object,
- several views share presentation-specific state not better modelled as app-level
  environment data.

Even then keep it small, explicit, and non-optional.

> In MVVM projects the calculus is different — the ViewModel is the sanctioned home for
> view-facing state. This file is MV guidance; see `swift-mvvm-architecture` for MVVM.

## Preferred pattern: local state + environment service

```swift
struct FeedView: View {
    @Environment(FeedService.self) private var service

    enum ViewState {
        case loading
        case error(String)
        case loaded([Post])
    }

    @State private var viewState: ViewState = .loading

    var body: some View {
        List {
            switch viewState {
            case .loading:
                ProgressView("Loading feed…")
            case .error(let message):
                ErrorStateView(message: message) { await loadFeed() }
            case .loaded(let posts):
                ForEach(posts) { PostRowView(post: $0) }
            }
        }
        .task { await loadFeed() }
    }

    private func loadFeed() async {
        do {
            viewState = .loaded(try await service.getFeed())
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }
}
```

State lives next to the UI that renders it; dependencies come from the environment; the
view coordinates UI flow while the service owns the real work.

## Lifecycle modifiers as lightweight orchestration

```swift
.task(id: searchText) {                          // restarts when input changes
    guard !searchText.isEmpty else {
        results = []
        return
    }
    await search(query: searchText)              // auto-cancelled when id changes again
}

.onChange(of: isSearching, initial: false) {
    guard !isSearching else { return }
    Task { await fetchSuggested() }
}
```

`.task(id:)` is the idiomatic debounce/restart primitive — when the id changes it cancels
the running task and starts a fresh one, so input-driven async work needs no manual
cancellation bookkeeping. Do not promote these to a view model until the behaviour clearly
outgrows the view.

## SwiftData note

SwiftData is a strong argument for keeping data flow in the view:

```swift
struct BookListView: View {
    @Query private var books: [Book]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            ForEach(books) { book in
                BookRowView(book: book)
                    .swipeActions {
                        Button("Delete", role: .destructive) { modelContext.delete(book) }
                    }
            }
        }
    }
}
```

Avoid a view model that manually re-fetches and mirrors what `@Query` already provides.

## Testing guidance

Test services, models, state transformations, and async workflows at the service layer;
cover UI behaviour with previews or higher-level UI tests. Do **not** add a view model
purely to make a simple view "testable" — that adds ceremony without improving the design.

## Refactor checklist

- Remove view models that only wrap environment dependencies or local view state.
- Replace optional/delayed-init view models when plain view state suffices.
- Pull business logic out of the body into services/models.
- Keep the view a thin coordinator of UI state, navigation, and user actions.
- Split large bodies into smaller view types before adding new layers.

## Bottom line

The default modern stack: `@State` (local), `@Environment` (shared dependencies),
`@Query` (SwiftData collections), lifecycle modifiers (orchestration), services/models
(business logic). Reach for a view model only when the feature clearly needs one.
