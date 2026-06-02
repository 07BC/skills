# Accessibility Identifier Registry

This file is the source of truth for all `accessibilityIdentifier` values used
in UI tests. Update it whenever you add, rename, or remove an identifier.

---

## Naming Convention

```
<screen>.<element>[.<variant>]
```

- All lowercase, dot-separated
- Screen prefix matches the SwiftUI View filename without the `View` suffix
  (e.g. `LoginView` → `login.*`)
- Variants used for repeated elements (e.g. quality options)

---

## Template: Adding a New Screen

When a new screen requires UI tests, add a section here:

```markdown
## <ScreenName>

| Identifier | Element type | Description |
|------------|--------------|-------------|
| `<screen>.container` | `View` / `otherElements` | Root container of the screen |
| `<screen>.<element>` | `Button` / `TextField` / etc. | Short description |
```

---

## Registered Identifiers

<!-- Add new screens below this line, alphabetically -->

### Login

| Identifier | Element type | SwiftUI usage |
|------------|--------------|---------------|
| `login.username` | `textFields` | `TextField` for username |
| `login.password` | `secureTextFields` | `SecureField` for password |
| `login.signIn` | `buttons` | Primary sign-in button |
| `login.errorMessage` | `staticTexts` | Validation / auth error label |
| `login.forgotPassword` | `buttons` | Forgot password link |

### Home / Dashboard

| Identifier | Element type | SwiftUI usage |
|------------|--------------|---------------|
| `home.container` | `otherElements` | Root `VStack` / container |
| `home.compose` | `buttons` | Compose CTA button |
| `home.search` | `buttons` | Search CTA button |

### Compose / Publish

| Identifier | Element type | SwiftUI usage |
|------------|--------------|---------------|
| `compose.preview` | `otherElements` | Content preview container |
| `compose.publish` | `buttons` | Publish button |
| `compose.unpublish` | `buttons` | Unpublish button |
| `compose.camera.toggle` | `buttons` | Switch camera button |
| `compose.mic.toggle` | `buttons` | Mute/unmute mic button |
| `compose.status` | `staticTexts` | Status label (e.g. "Published") |

### Settings

| Identifier | Element type | SwiftUI usage |
|------------|--------------|---------------|
| `settings.container` | `otherElements` | Root container |
| `settings.quality.picker` | `otherElements` | Quality picker/segmented control |
| `settings.quality.option.hd720` | `buttons` | 720p option |
| `settings.quality.option.hd1080` | `buttons` | 1080p option |

---

## MyApp (catalogue)

### SearchView

| Identifier | Element type | SwiftUI usage |
|------------|--------------|---------------|
| `search.container` | `otherElements` | Root in `SearchView` |
| `search.queryField` | `textFields` | Query input `TextField` |
| `search.queryField.error` | `staticTexts` | Inline error `Text` below query field |
| `search.category` | `buttons` | Category `Picker` (.menu) |
| `search.sortOrder` | `buttons` | Sort order `Picker` (.menu) |
| `search.sortOrder.error` | `staticTexts` | Inline sort error |
| `search.results` | `otherElements` | Results list container |
| `search.noResults` | `staticTexts` | "No results" empty-state label |
| `search.submit` | `buttons` | Submit / search toolbar action |

### HomeView (article list)

| Identifier | Element type | SwiftUI usage |
|------------|--------------|---------------|
| `home.container` | `otherElements` | Root `VStack` in `HomeView` |
| `home.compose` | `buttons` | "New article" `NavigationLink` (empty state) |
| `home.search` | `buttons` | "Search articles" `NavigationLink` |
| `home.article.featured` | `buttons` | Featured article `NavigationLink` (pre-populated state) |
| `home.summary.title` | `staticTexts` | `LabeledContent` value for article title |
| `home.summary.category` | `staticTexts` | `LabeledContent` value for Category |
| `home.summary.publishDate` | `staticTexts` | `LabeledContent` value for Publish Date |
| `home.summary.wordCount` | `staticTexts` | `LabeledContent` value for Word Count |

### ArticleDetailView

| Identifier | Element type | SwiftUI usage |
|------------|--------------|---------------|
| `articleDetail.container` | `otherElements` | Root `Form` in `ArticleDetailView` |
| `articleDetail.title` | `staticTexts` | Article title `Text` |
| `articleDetail.body` | `staticTexts` | Article body content `Text` |
| `articleDetail.publishDate` | `staticTexts` | Publication date value `Text` |
| `articleDetail.category` | `otherElements` | `Picker("Category", …)` with `.pickerStyle(.segmented)` — group-level identifier for diagnostics only |
| `articleDetail.sortOrder` | `buttons` | Sort order `Picker` (.menu) |
| `articleDetail.bookmark.toggle` | `switches` | `Toggle("Bookmark", …)` |
| `articleDetail.related` | `otherElements` | Related articles section container |

> **Error banner query.** `ErrorBannerView` uses
> `.accessibilityElement(children: .combine)`. The combined element does
> not surface as `otherElements[id]` on iOS 26 even with an
> `.accessibilityIdentifier` modifier applied — SwiftUI rebuilds the
> element identity at combine time and drops the modifier. The visible
> error text remains queryable as a `staticTexts` element whose `label`
> contains the error message copy (set in `ErrorBannerView.message(for:)`).
> The page object queries it as `staticTexts.matching("label CONTAINS
> <message-prefix>").firstMatch`. Do not add an `articleDetail.error.banner`
> identifier to `ErrorBannerView` — it is dead code.

**Segmented Picker segment queries.** SwiftUI `Picker(.segmented)` renders each `Text("…").tag(…)` child as an `XCUIElement` of type `.button`. Applying `.accessibilityIdentifier(_:)` on the inner `Text` children is unreliable — the Picker absorbs child modifiers. Use visible labels instead: `app.buttons["All"]`, `app.buttons["Technology"]`, `app.buttons["Science"]`. The `articleDetail.category` group identifier is for diagnostics only and should not be relied on in assertions.

> **Chart accessibility note.** SwiftUI `Chart` inside a `Form` `Section` cell publishes an audio-graph representation and does not expose `.accessibilityIdentifier(_:)` on the chart container, legend entries, or axis labels. `ArticleChartView` keeps `.accessibilityLabel("Article activity chart")` for the audio-graph fallback, but no identifier-based queries on the chart are possible from XCUITest. Visual chart ACs are documented in the manual test plan in each PR description.

---

## Adding Identifiers to SwiftUI Views

```swift
// Button
Button("Publish") { ... }
    .accessibilityIdentifier("compose.publish")

// TextField
TextField("Username", text: $username)
    .accessibilityIdentifier("login.username")

// SecureField
SecureField("Password", text: $password)
    .accessibilityIdentifier("login.password")

// Container view
VStack { ... }
    .accessibilityIdentifier("home.container")

// Picker
Picker("Quality", selection: $quality) { ... }
    .accessibilityIdentifier("settings.quality.picker")

// Dynamic list item
ForEach(options) { option in
    Text(option.label)
        .accessibilityIdentifier("settings.quality.option.\(option.id)")
}
```
