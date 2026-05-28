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
| `tapGoLive()` | `GoLiveScreen` | Opens Go Live preview |

```swift
struct HomeScreen {
    let app: XCUIApplication

    var container: XCUIElement { app.otherElements["home.container"] }
    var goLiveButton: XCUIElement { app.buttons["home.goLive"] }

    @discardableResult
    func waitForScreen(timeout: TimeInterval = 10) -> Bool {
        container.waitForExistence(timeout: timeout)
    }

    func tapGoLive() -> GoLiveScreen {
        goLiveButton.tap()
        return GoLiveScreen(app: app)
    }
}
```

---

### `GoLiveScreen`

**File:** `GoLiveScreen.swift`

| Method | Returns | Description |
|--------|---------|-------------|
| `waitForScreen(timeout:)` | `Bool` | Waits for preview container |
| `tapStartStream()` | `GoLiveScreen` | Starts the stream |
| `tapStopStream()` | `GoLiveScreen` | Stops the stream |
| `tapToggleCamera()` | `GoLiveScreen` | Switches camera |
| `tapToggleMic()` | `GoLiveScreen` | Mutes/unmutes mic |
| `streamStatus` | `XCUIElement` | Status label element |

```swift
struct GoLiveScreen {
    let app: XCUIApplication

    var preview: XCUIElement { app.otherElements["goLive.preview"] }
    var startButton: XCUIElement { app.buttons["goLive.startStream"] }
    var stopButton: XCUIElement { app.buttons["goLive.stopStream"] }
    var cameraToggle: XCUIElement { app.buttons["goLive.camera.toggle"] }
    var micToggle: XCUIElement { app.buttons["goLive.mic.toggle"] }
    var streamStatus: XCUIElement { app.staticTexts["goLive.status"] }

    @discardableResult
    func waitForScreen(timeout: TimeInterval = 5) -> Bool {
        preview.waitForExistence(timeout: timeout)
    }

    @discardableResult
    func tapStartStream() -> GoLiveScreen {
        startButton.tap()
        return self
    }

    @discardableResult
    func tapStopStream() -> GoLiveScreen {
        stopButton.tap()
        return self
    }

    @discardableResult
    func tapToggleCamera() -> GoLiveScreen {
        cameraToggle.tap()
        return self
    }

    @discardableResult
    func tapToggleMic() -> GoLiveScreen {
        micToggle.tap()
        return self
    }
}
```

---

### `LoanInputScreen` (escape)

**File:** `escapeUITests/LoanInputScreen.swift`

| Method | Returns | Description |
|--------|---------|-------------|
| `waitForScreen(timeout:)` | `Bool` | Waits for `loanInput.container` |
| `enterBalance(_:)` | `LoanInputScreen` | Clears + types balance, commits by tapping rate field |
| `enterRate(_:)` | `LoanInputScreen` | Clears + types rate, commits by tapping repayment field |
| `enterRepayment(_:)` | `LoanInputScreen` | Clears + types repayment, commits by tapping a neutral field |
| `selectTermYears(_:)` | `LoanInputScreen` | Opens menu picker, taps row by label ("30 yr") |
| `selectTermMonths(_:)` | `LoanInputScreen` | Opens menu picker, taps row by label ("0 mo") |
| `tapSave()` | `HomeScreen` | Taps Save toolbar action |

### `HomeScreen` (escape)

**File:** `escapeUITests/HomeScreen.swift`

| Method | Returns | Description |
|--------|---------|-------------|
| `waitForScreen(timeout:)` | `Bool` | Waits for `home.container` |
| `tapEnterLoan()` | `LoanInputScreen` | Empty-state CTA |
| `tapEditLoan()` | `LoanInputScreen` | Pre-populated state CTA |
| `tapScenarioA()` | `ScenarioScreen` | Waits for `home.scenario.a`, taps it, returns `ScenarioScreen` |

### `ScenarioScreen` (escape)

**File:** `escapeUITests/ScenarioScreen.swift`

| Property | Element | Notes |
|----------|---------|-------|
| `container` | `descendants(matching: .any)["scenario.container"]` | Anchor for `waitForScreen()` |
| `extraRepaymentField` | `textFields["scenario.extraRepayment"]` | Cents-accumulator semantics |
| `payoffDateValue` | `staticTexts["scenario.summary.payoffDate"]` | |
| `timeSavedValue` | `staticTexts["scenario.summary.timeSaved"]` | Default label "No time saved yet" when scenario == baseline |
| `interestSavedValue` | `staticTexts["scenario.summary.interestSaved"]` | Default label "—" when no savings |
| `frequencyMonthly` | `buttons["Monthly"]` | Monthly segment in the Repayment frequency Picker |
| `frequencyFortnightly` | `buttons["Fortnightly"]` | Fortnightly segment |
| `frequencyWeekly` | `buttons["Weekly"]` | Weekly segment |
| `lumpSumToggle` | `switches["scenario.lumpSum.toggle"]` | Toggle that reveals the lump sum section |
| `lumpSumAmountField` | `textFields["scenario.lumpSum.amount"]` | Cents-accumulator; visible only when toggle is on |
| `lumpSumDatePicker` | `datePickers["scenario.lumpSum.date"]` | Compact-style date picker; visible only when toggle is on |
| `errorBanner` | `staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Lump sum is larger")).firstMatch` | Error banner overlay text; `otherElements[id]` does not resolve on iOS 26 — queried by label (Unknown 2 fallback, plan story 06) |
| `offsetBalanceField` | `textFields["scenario.offsetBalance"]` | Cents-accumulator semantics |
| `offsetErrorBanner` | `staticTexts.matching("label CONTAINS[c] 'Offset balance'").firstMatch` | Banner queried by label-prefix (same pattern as lumpSum error) |

> Chart-related properties intentionally absent: `Chart` inside a `Form Section` does not expose identifiers, legend entries, or axis labels to XCUITest queries. ACs covering chart visuals (axes, legend, summary-above-chart) are documented in the PR's manual test plan rather than automated.

> Frequency segment queries use visible labels, not identifiers — segmented Pickers absorb per-child `.accessibilityIdentifier` modifiers. See `accessibility-ids.md` under `ScenarioView (escape)` for the full explanation.

| Method | Returns | Description |
|--------|---------|-------------|
| `waitForScreen(timeout:)` | `Bool` | Waits for `scenario.container` |
| `waitForResults(timeout:)` | `Bool` | Waits for `payoffDateValue` to exist; results are gated on async baseline compute |
| `waitForScenarioComputed(timeout:)` | `Bool` | Waits until `timeSavedValue.label != "No time saved yet"` |
| `waitForPayoffDate(notEqualTo:timeout:)` | `Bool` | Waits until `payoffDateValue.label` differs from a captured previous value; use after a frequency switch or lump sum change to gate on the 300 ms debounced recompute |
| `waitForLumpSumFields(timeout:)` | `Bool` | Waits for `lumpSumAmountField` to appear after the toggle is enabled |
| `waitForErrorBanner(timeout:)` | `Bool` | Waits for the error banner to appear |
| `selectMonthly()` | `ScenarioScreen` | Waits for segment, taps Monthly, returns self |
| `selectFortnightly()` | `ScenarioScreen` | Waits for segment, taps Fortnightly, returns self |
| `selectWeekly()` | `ScenarioScreen` | Waits for segment, taps Weekly, returns self |
| `enterExtraRepayment(_:)` | `ScenarioScreen` | Taps field, types digits, dismisses keyboard via nav bar |
| `enableLumpSum()` | `ScenarioScreen` | Scrolls until toggle is hittable (loop, max 5 swipes), taps, waits for binding to flip to "1"; if not flipped after 2 s, falls back to coordinate-tap on the switch handle (O1 fix, story 06 diagnosis) |
| `enterLumpSumAmount(_:)` | `ScenarioScreen` | Waits for field, taps, types digits, dismisses keyboard via nav bar |
| `enterOffsetBalance(_:)` | `ScenarioScreen` | Scrolls into view, taps, types digits, dismisses keyboard via nav bar |
| `waitForOffsetErrorBanner(timeout:)` | `Bool` | Waits for the offset error banner |
| `ensureHittable(_:)` | `Bool` | Returns true if hittable; scrolls up once if not |
