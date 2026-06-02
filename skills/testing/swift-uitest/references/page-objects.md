# Page Object Catalogue

Page Objects wrap `XCUIElement` queries for a single screen. They prevent
identifier changes from cascading through many test files.

---

## Rules

1. **One Page Object per screen** — if a flow spans multiple screens, chain
   Page Objects: `login.tapSignIn()` returns a `HomeScreen`.
2. **Actions return the resulting screen** — callers should not have to know
   which screen comes next.
3. **No assertions inside Page Objects** — assertions belong in test methods.
4. **Waits inside `waitForScreen()`** — callers should call this before using
   any element.

---

## Template

```swift
// <ScreenName>Screen.swift — in UITest target
struct <ScreenName>Screen {
    let app: XCUIApplication

    // MARK: - Elements

    // var <element>: XCUIElement { app.<type>["<identifier>"] }

    // MARK: - Waits

    @discardableResult
    func waitForScreen(timeout: TimeInterval = 5) -> Bool {
        <rootElement>.waitForExistence(timeout: timeout)
    }

    // MARK: - Actions (return resulting screen)
}
```

---

## Registered Page Objects

### `LoginScreen`

**File:** `LoginScreen.swift`

| Method | Returns | Description |
|--------|---------|-------------|
| `waitForScreen(timeout:)` | `Bool` | Waits for username field |
| `enterUsername(_:)` | `LoginScreen` | Types into username field |
| `enterPassword(_:)` | `LoginScreen` | Types into password field |
| `tapSignIn()` | `HomeScreen` | Taps sign-in, returns home screen |
| `tapForgotPassword()` | `ForgotPasswordScreen` | Navigates to forgot password |

```swift
struct LoginScreen {
    let app: XCUIApplication

    var usernameField: XCUIElement { app.textFields["login.username"] }
    var passwordField: XCUIElement { app.secureTextFields["login.password"] }
    var signInButton: XCUIElement { app.buttons["login.signIn"] }
    var errorMessage: XCUIElement { app.staticTexts["login.errorMessage"] }

    @discardableResult
    func waitForScreen(timeout: TimeInterval = 5) -> Bool {
        usernameField.waitForExistence(timeout: timeout)
    }

    @discardableResult
    func enterUsername(_ value: String) -> LoginScreen {
        usernameField.tap()
        usernameField.typeText(value)
        return self
    }

    @discardableResult
    func enterPassword(_ value: String) -> LoginScreen {
        passwordField.tap()
        passwordField.typeText(value)
        return self
    }

    func tapSignIn() -> HomeScreen {
        signInButton.tap()
        return HomeScreen(app: app)
    }
}
```

---

### `HomeScreen`

**File:** `HomeScreen.swift`

| Method | Returns | Description |
|--------|---------|-------------|
| `waitForScreen(timeout:)` | `Bool` | Waits for home container |
| `tapCompose()` | `ComposeScreen` | Opens Compose/publish screen |
| `tapSearch()` | `SearchScreen` | Opens Search screen |
| `tapArticle(at:)` | `ArticleDetailScreen` | Taps an article cell by identifier, returns detail screen |

```swift
struct HomeScreen {
    let app: XCUIApplication

    var container: XCUIElement { app.otherElements["home.container"] }
    var composeButton: XCUIElement { app.buttons["home.compose"] }
    var searchButton: XCUIElement { app.buttons["home.search"] }

    @discardableResult
    func waitForScreen(timeout: TimeInterval = 10) -> Bool {
        container.waitForExistence(timeout: timeout)
    }

    func tapCompose() -> ComposeScreen {
        composeButton.tap()
        return ComposeScreen(app: app)
    }

    func tapSearch() -> SearchScreen {
        searchButton.tap()
        return SearchScreen(app: app)
    }
}
```

---

### `ComposeScreen`

**File:** `ComposeScreen.swift`

| Method | Returns | Description |
|--------|---------|-------------|
| `waitForScreen(timeout:)` | `Bool` | Waits for compose container |
| `tapPublish()` | `ComposeScreen` | Publishes the item |
| `tapUnpublish()` | `ComposeScreen` | Unpublishes the item |
| `tapToggleCamera()` | `ComposeScreen` | Switches camera |
| `tapToggleMic()` | `ComposeScreen` | Mutes/unmutes mic |
| `publishStatus` | `XCUIElement` | Status label element |

```swift
struct ComposeScreen {
    let app: XCUIApplication

    var preview: XCUIElement { app.otherElements["compose.preview"] }
    var publishButton: XCUIElement { app.buttons["compose.publish"] }
    var unpublishButton: XCUIElement { app.buttons["compose.unpublish"] }
    var cameraToggle: XCUIElement { app.buttons["compose.camera.toggle"] }
    var micToggle: XCUIElement { app.buttons["compose.mic.toggle"] }
    var publishStatus: XCUIElement { app.staticTexts["compose.status"] }

    @discardableResult
    func waitForScreen(timeout: TimeInterval = 5) -> Bool {
        preview.waitForExistence(timeout: timeout)
    }

    @discardableResult
    func tapPublish() -> ComposeScreen {
        publishButton.tap()
        return self
    }

    @discardableResult
    func tapUnpublish() -> ComposeScreen {
        unpublishButton.tap()
        return self
    }

    @discardableResult
    func tapToggleCamera() -> ComposeScreen {
        cameraToggle.tap()
        return self
    }

    @discardableResult
    func tapToggleMic() -> ComposeScreen {
        micToggle.tap()
        return self
    }
}
```

---

### `SearchScreen`

**File:** `MyAppUITests/SearchScreen.swift`

| Method | Returns | Description |
|--------|---------|-------------|
| `waitForScreen(timeout:)` | `Bool` | Waits for `search.container` |
| `enterQuery(_:)` | `SearchScreen` | Clears + types query text, commits by tapping search button |
| `tapResult(at:)` | `ArticleDetailScreen` | Taps a result cell by index, returns `ArticleDetailScreen` |
| `tapClear()` | `SearchScreen` | Clears the search field |

### `ArticleDetailScreen`

**File:** `MyAppUITests/ArticleDetailScreen.swift`

| Property | Element | Notes |
|----------|---------|-------|
| `container` | `descendants(matching: .any)["articleDetail.container"]` | Anchor for `waitForScreen()` |
| `titleLabel` | `staticTexts["articleDetail.title"]` | Article title text |
| `bodyText` | `staticTexts["articleDetail.body"]` | Article body content |
| `publishDateLabel` | `staticTexts["articleDetail.publishDate"]` | Publication date label |
| `categoryPicker` | `otherElements["articleDetail.category"]` | `Picker("Category", …)` with `.pickerStyle(.segmented)` — group-level identifier for diagnostics only |
| `categoryAll` | `buttons["All"]` | All categories segment in the Category Picker |
| `categoryTechnology` | `buttons["Technology"]` | Technology segment |
| `categoryScience` | `buttons["Science"]` | Science segment |
| `bookmarkToggle` | `switches["articleDetail.bookmark.toggle"]` | Toggle that bookmarks the article |
| `relatedArticlesList` | `otherElements["articleDetail.related"]` | Related articles section |
| `errorBanner` | `staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Unable to load")).firstMatch` | Error banner overlay text; `otherElements[id]` does not resolve on iOS 26 — queried by label |
| `sortOrderField` | `buttons["articleDetail.sortOrder"]` | Sort order picker (.menu) |

> Chart-related properties intentionally absent: `Chart` inside a `Form Section` does not expose identifiers, legend entries, or axis labels to XCUITest queries. ACs covering visual chart elements are documented in the PR's manual test plan rather than automated.

> Category filter queries use visible labels, not identifiers — segmented Pickers absorb per-child `.accessibilityIdentifier` modifiers. See `accessibility-ids.md` under `ArticleDetailView` for the full explanation.

| Method | Returns | Description |
|--------|---------|-------------|
| `waitForScreen(timeout:)` | `Bool` | Waits for `articleDetail.container` |
| `waitForContent(timeout:)` | `Bool` | Waits for `titleLabel` to exist; content is gated on async fetch |
| `waitForCategoryComputed(timeout:)` | `Bool` | Waits until `categoryAll.label` is not the loading placeholder |
| `waitForPublishDate(notEqualTo:timeout:)` | `Bool` | Waits until `publishDateLabel.label` differs from a captured previous value; use after a category or sort change to gate on the 300 ms debounced reload |
| `waitForRelatedArticles(timeout:)` | `Bool` | Waits for `relatedArticlesList` to appear after content loads |
| `waitForErrorBanner(timeout:)` | `Bool` | Waits for the error banner to appear |
| `selectCategoryAll()` | `ArticleDetailScreen` | Waits for segment, taps All, returns self |
| `selectCategoryTechnology()` | `ArticleDetailScreen` | Waits for segment, taps Technology, returns self |
| `selectCategoryScience()` | `ArticleDetailScreen` | Waits for segment, taps Science, returns self |
| `enterQuery(_:)` | `ArticleDetailScreen` | Taps field, types text, dismisses keyboard via nav bar |
| `toggleBookmark()` | `ArticleDetailScreen` | Scrolls until toggle is hittable (loop, max 5 swipes), taps, waits for binding to flip to "1"; falls back to coordinate-tap on the switch handle if needed |
| `selectSortOrder(_:)` | `ArticleDetailScreen` | Opens sort order menu, taps row by label |
| `waitForSortErrorBanner(timeout:)` | `Bool` | Waits for the sort error banner |
| `ensureHittable(_:)` | `Bool` | Returns true if hittable; scrolls up once if not |
