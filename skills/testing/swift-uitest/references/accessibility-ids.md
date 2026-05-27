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
| `home.goLive` | `buttons` | Go Live CTA button |

### Go Live / Preview

| Identifier | Element type | SwiftUI usage |
|------------|--------------|---------------|
| `goLive.preview` | `otherElements` | Camera preview container |
| `goLive.startStream` | `buttons` | Start streaming button |
| `goLive.stopStream` | `buttons` | Stop streaming button |
| `goLive.camera.toggle` | `buttons` | Switch camera button |
| `goLive.mic.toggle` | `buttons` | Mute/unmute mic button |
| `goLive.status` | `staticTexts` | Stream status label (e.g. "Live") |

### Settings

| Identifier | Element type | SwiftUI usage |
|------------|--------------|---------------|
| `settings.container` | `otherElements` | Root container |
| `settings.quality.picker` | `otherElements` | Quality picker/segmented control |
| `settings.quality.option.hd720` | `buttons` | 720p option |
| `settings.quality.option.hd1080` | `buttons` | 1080p option |

---

## Escape (payback)

### LoanInputView

| Identifier | Element type | SwiftUI usage |
|------------|--------------|---------------|
| `loanInput.container` | `otherElements` | `Form` root in `LoanInputView` |
| `loanInput.balance` | `textFields` | `CurrencyField` inner `TextField` |
| `loanInput.balance.error` | `staticTexts` | Inline error `Text` below balance |
| `loanInput.termYears` | `buttons` | `TermPicker` years `Picker` (.menu) |
| `loanInput.termMonths` | `buttons` | `TermPicker` months `Picker` (.menu) |
| `loanInput.term.error` | `staticTexts` | Inline term error (unreachable from UI, registered for symmetry) |
| `loanInput.rate` | `textFields` | `PercentageField` inner `TextField` |
| `loanInput.rate.error` | `staticTexts` | Inline rate error |
| `loanInput.rate.fixedNote` | `staticTexts` | Footer copy: "fixed, used for modelling" |
| `loanInput.repayment` | `textFields` | Repayment `CurrencyField` inner `TextField` |
| `loanInput.repayment.error` | `staticTexts` | Inline repayment error |
| `loanInput.save` | `buttons` | Save toolbar action |

### HomeView (escape)

| Identifier | Element type | SwiftUI usage |
|------------|--------------|---------------|
| `home.container` | `otherElements` | `Form` root in `HomeView` |
| `home.enterLoan` | `buttons` | "Enter your loan" `NavigationLink` (empty state) |
| `home.editLoan` | `buttons` | "Edit loan" `NavigationLink` (pre-populated state) |
| `home.scenario.a` | `buttons` | "Scenario A — extra repayment" `NavigationLink` (pre-populated state) |
| `home.summary.balance` | `staticTexts` | `LabeledContent` value for Balance |
| `home.summary.rate` | `staticTexts` | `LabeledContent` value for Rate |
| `home.summary.term` | `staticTexts` | `LabeledContent` value for Term |
| `home.summary.repayment` | `staticTexts` | `LabeledContent` value for Repayment |

### ScenarioView (escape)

| Identifier | Element type | SwiftUI usage |
|------------|--------------|---------------|
| `scenario.container` | `otherElements` | Root `Form` in `ScenarioView` |
| `scenario.extraRepayment` | `textFields` | `CurrencyField(identifier:)` for Extra per period |
| `scenario.summary.payoffDate` | `staticTexts` | Value `Text` in `ResultsSummaryView` payoff date row (when `idPrefix: "scenario"`) |
| `scenario.summary.timeSaved` | `staticTexts` | Value `Text` in `ResultsSummaryView` time saved row (when `idPrefix: "scenario"`) |
| `scenario.summary.interestSaved` | `staticTexts` | Value `Text` in `ResultsSummaryView` interest saved row (when `idPrefix: "scenario"`) |

> **Chart accessibility note.** SwiftUI `Chart` inside a `Form` `Section` cell publishes an audio-graph representation and does not expose `.accessibilityIdentifier(_:)` on the chart container, legend entries, or axis labels. `ScenarioChartView` keeps `.accessibilityLabel("Balance over time chart")` for the audio-graph fallback, but no identifier-based queries on the chart are possible from XCUITest. AC 4 (axes), AC 5 (legend), and AC 6 (summary-above-chart) are documented in the manual test plan in each PR description.

---

## Adding Identifiers to SwiftUI Views

```swift
// Button
Button("Go Live") { ... }
    .accessibilityIdentifier("goLive.startStream")

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
