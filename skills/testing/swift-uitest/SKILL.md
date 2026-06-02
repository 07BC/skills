---
name: swift-uitest
description: >
  Creates Xcode UI tests (XCUITest) for iOS apps. Use when the user asks to
  write UI tests, end-to-end tests, integration tests that test the real app
  UI, or mentions XCUIApplication, XCUIElement, or "UI automation". Also
  trigger when the user says "test the login flow", "test this screen", "write
  a UI test for", or wants to verify real user interactions against a running
  simulator. Always use this skill — do not write UI tests from memory.
  UI tests are fundamentally different from unit tests: they run in a separate
  process, cannot import app code, use XCTest (not Swift Testing), and require
  credentials to be injected via environment variables, never hardcoded.
---

# Swift UI Test Skill

You write Xcode UI tests for an iOS app using XCUITest. These tests drive a
real simulator, interact with accessibility elements, and verify end-to-end
user flows. They are **not** unit tests and do not use the Swift Testing framework.

---

## Core Constraints (Non-Negotiable)

1. **XCTest only** — UI test targets run out-of-process. `import Testing` is
   unavailable. Use `XCTestCase`, `XCTAssert*`, `XCTFail`.
2. **No app code imports** — You cannot `@testable import` the app module.
   Tests interact exclusively through `XCUIApplication` accessibility APIs.
3. **Zero hardcoded credentials** — Usernames, passwords, tokens, and any
   secrets must come from environment variables injected at runtime.
4. **Accessibility-first element selection** — Use `accessibilityIdentifier`
   over heuristic queries. Never rely on display text for interactive elements
   unless the identifier is unavailable.
5. **Explicit waits, never `sleep`** — Use `XCTNSPredicateExpectation` or
   `waitForExistence(timeout:)`. `Thread.sleep` is always wrong.

### tvOS hard stops (see detailed section below)

When targeting tvOS, these patterns silently break UI tests:

- `.searchable()` does not produce a `searchField` element. Query the
  underlying `textField` instead.
- `opacity: 0` removes all children from the accessibility tree —
  unreachable from tests. Use `.hidden()` only when tests don't need
  to query those children; never `opacity(0)` on something a test
  must inspect.
- `.accessibilityElement(children: .ignore)` breaks SwiftUI's
  `.focused()` binding — `hasFocus` reports accessibility focus
  correctly but the bound state desyncs. Query the rendered state, not
  the focus signal.
- Count-based remote presses race against focus animations. Use
  wait-driven navigation, not fixed press counts.

Full tvOS quirks appear later in this skill ("tvOS element type
quirks" and "tvOS SwiftUI layout gotchas that break UI tests"). Treat
the four bullets above as hard stops — never write a tvOS test that
relies on the broken behaviour.

---

## Escalation — when a test is not automatable

Some AC items cannot be driven by `XCUIApplication`:

- System UI with no accessibility surface (in-app purchase sheets,
  permission dialogs on certain OS versions, OS-level keyboard).
- Visual-correctness assertions (colour, exact spacing, animation
  smoothness) that the accessibility tree doesn't expose.
- Behaviour that requires reading app-internal state the UI does not
  surface.

**Do not weaken the assertion to make it automatable.** Do not assert
on the wrong thing to make a test pass. Instead:

1. Stop writing the test.
2. Record the unautomatable AC item in the discovery / plan note with
   one line on *why* (which surface, which API limitation).
3. Surface as a `manual` row in the AC coverage table that the calling
   pipeline produces. The reviewer follows the manual step from the
   PR description.

The same rule applies when `swift-uitest-debug` declares a test
unautomatable after its escalation ladder exhausts: replace the test
with a manual step, do not weaken it.

---

## Step 0 — Understand the App Before Writing

Before writing a single test, explore the target screens:

```bash
# Find the UI test target (usually named *UITests)
find . -name "*.swift" -path "*UITests*" | sort

# Understand what accessibility identifiers already exist in the app
grep -rn "accessibilityIdentifier\|\.accessibilityLabel\|\.accessibilityValue" \
  --include="*.swift" . | grep -v "UITests" | grep -v ".build"

# Find existing UI tests to understand conventions and avoid duplication
find . -name "*.swift" -path "*UITests*" -exec grep -l "XCUIApplication" {} \;

# Check how the app is currently launched in existing UI tests
grep -rn "XCUIApplication()\|launchEnvironment\|launchArguments" \
  --include="*.swift" . | grep -v ".build"
```

Read every existing UI test file. Match their conventions.

---

## Step 1 — Credential Injection Architecture

UI tests must never contain credentials. Use this pattern consistently.

### In the UI test target

```swift
// UITestCredentials.swift  (in UITest target — never committed with real values)
enum UITestCredentials {

    /// Call this before app.launch() to inject credentials from the environment.
    static func inject(into app: XCUIApplication) {
        let env = ProcessInfo.processInfo.environment

        // These env vars must be set in the scheme or passed via xcodebuild -testenv
        let username = env["UI_TEST_USERNAME"] ?? ""
        let password = env["UI_TEST_PASSWORD"] ?? ""

        precondition(!username.isEmpty, "UI_TEST_USERNAME env var must be set")
        precondition(!password.isEmpty, "UI_TEST_PASSWORD env var must be set")

        app.launchEnvironment["UI_TEST_USERNAME"] = username
        app.launchEnvironment["UI_TEST_PASSWORD"] = password
    }
}
```

### In the app target (receiving credentials at launch)

```swift
// AppDelegate.swift or App.swift  — reads creds only during UI testing
#if DEBUG
extension ProcessInfo {
    var isRunningUITests: Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }

    var uitestUsername: String? { environment["UI_TEST_USERNAME"] }
    var uitestPassword: String? { environment["UI_TEST_PASSWORD"] }
}
#endif
```

Then, in your app's login or startup path:

```swift
#if DEBUG
if ProcessInfo.processInfo.isRunningUITests,
   let username = ProcessInfo.processInfo.uitestUsername,
   let password = ProcessInfo.processInfo.uitestPassword {
    // Auto-fill credentials for UI testing
    await authService.loginWith(username: username, password: password)
}
#endif
```

### Setting credentials at runtime

**Xcode Scheme (for local runs):**
1. Product → Scheme → Edit Scheme → Test → Arguments → Environment Variables
2. Add `UI_TEST_USERNAME` and `UI_TEST_PASSWORD` — values are NOT committed to git

**xcodebuild (for CI):**
```bash
xcodebuild test \
  -scheme "MyAppUITests" \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  -testenv "UI_TEST_USERNAME=$(UI_TEST_USERNAME)" \
  -testenv "UI_TEST_PASSWORD=$(UI_TEST_PASSWORD)"
```

CI systems (GitHub Actions, Bitrise, etc.) provide secrets as env vars.
The `-testenv` flag forwards them into the test process, which then forwards
them into `app.launchEnvironment` before `app.launch()`.

**Never** store credentials in:
- Source control (even `*.xcscheme` files are committed)
- `launchArguments` (visible in process lists)
- Test code as string literals
- `.env` files committed to the repo

---

## Step 2 — Accessibility Identifier Contract

UI tests rely on accessibility identifiers set in the app. When writing a new
test, check whether the required identifiers exist in the app code. If they
don't, you must add them alongside the test.

### Adding identifiers in SwiftUI

```swift
// ✅ In the View — use string literals that match the test's expectation
struct LoginView: View {
    var body: some View {
        VStack {
            TextField("Username", text: $username)
                .accessibilityIdentifier("login.username")

            SecureField("Password", text: $password)
                .accessibilityIdentifier("login.password")

            Button("Sign In") { /* ... */ }
                .accessibilityIdentifier("login.signIn")
        }
    }
}
```

### Identifier naming convention

Use dot-namespaced lowercase strings:

```
<screen>.<element>[.<variant>]

login.username
login.password
login.signIn
login.errorMessage
compose.previewButton
compose.camera.toggle
settings.quality.picker
settings.quality.option.hd720
```

Document identifiers in `references/accessibility-ids.md` (see below).

### tvOS element type quirks

These behaviours differ from iOS and cause test failures that are not
obvious from the error message alone:

- **`.searchable()` does not produce a `searchField` element on tvOS.**
  `app.searchFields` returns 0. Query the text field or container by
  accessibility identifier instead.

- **`opacity: 0` removes all children from the accessibility tree on tvOS.**
  Use a proper conditional render (`if visible { ... }`) rather than
  `opacity(0)` for elements that tests need to query.

- **`.accessibilityElement(children: .ignore)` breaks SwiftUI's `.focused()`
  binding on tvOS.** `hasFocus` will report accessibility focus correctly but
  the `@FocusState` variable will never update. Remove the modifier; observe
  the right-panel's rendered state as the focus signal instead.

- **`@FocusState` assigned in `onAppear` is stale** by the time the user
  navigates to a transport bar or overlay panel. Use
  `.prefersDefaultFocus(_:in:)` combined with `@Namespace` focus scope
  instead.

### Finding elements in tests

```swift
// ✅ By identifier (preferred)
let usernameField = app.textFields["login.username"]
let signInButton = app.buttons["login.signIn"]
let errorLabel = app.staticTexts["login.errorMessage"]

// ✅ By type + identifier (when type disambiguation is needed)
let passwordField = app.secureTextFields["login.password"]

// ⚠️ By label — only for read-only display text you control
app.staticTexts["Welcome back"]

// ❌ Never: positional or heuristic queries
app.buttons.element(boundBy: 0)     // breaks when layout changes
app.buttons.firstMatch              // non-deterministic
```

---

## Step 3 — Test File Structure

Every UI test file follows this exact structure:

```swift
import XCTest

// One class per user flow or screen
final class LoginUITests: XCTestCase {

    // MARK: - Properties

    private var app: XCUIApplication!

    // MARK: - Lifecycle

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()

        // Inject credentials from environment — never hardcode
        UITestCredentials.inject(into: app)

        // Optional launch arguments for test-specific app behaviour
        app.launchArguments += ["--uitesting"]

        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tests

    func test_loginWithValidCredentials_showsHomeScreen() throws {
        // Arrange: credentials already in launchEnvironment from setUp

        // Act: the app may auto-login (see Step 1 receiving credentials)
        // or you drive the UI:
        let usernameField = app.textFields["login.username"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 5))
        usernameField.tap()
        usernameField.typeText(app.launchEnvironment["UI_TEST_USERNAME"] ?? "")

        let passwordField = app.secureTextFields["login.password"]
        passwordField.tap()
        passwordField.typeText(app.launchEnvironment["UI_TEST_PASSWORD"] ?? "")

        app.buttons["login.signIn"].tap()

        // Assert
        let homeScreen = app.otherElements["home.container"]
        XCTAssertTrue(homeScreen.waitForExistence(timeout: 10),
                      "Home screen should appear after successful login")
    }

    func test_loginWithEmptyPassword_showsValidationError() throws {
        let usernameField = app.textFields["login.username"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 5))
        usernameField.tap()
        usernameField.typeText("anyone@example.com")

        app.buttons["login.signIn"].tap()

        let errorMessage = app.staticTexts["login.errorMessage"]
        XCTAssertTrue(errorMessage.waitForExistence(timeout: 3))
    }
}
```

### Method naming convention

```
func test_<precondition>_<action>_<expectedOutcome>()

test_loggedOut_tapSignIn_showsHomeScreen()
test_loggedIn_tapCompose_opensPreview()
test_compose_tapMute_muteIconAppears()
test_previewActive_rotateToLandscape_updatesLayout()
```

---

## Step 4 — Page Object Pattern

For flows with multiple screens, use Page Objects to isolate element queries
from test logic. This prevents identifier changes from breaking many tests at once.

```swift
// LoginScreen.swift  (in UITest target)
struct LoginScreen {
    let app: XCUIApplication

    // Elements
    var usernameField: XCUIElement { app.textFields["login.username"] }
    var passwordField: XCUIElement { app.secureTextFields["login.password"] }
    var signInButton: XCUIElement { app.buttons["login.signIn"] }
    var errorMessage: XCUIElement { app.staticTexts["login.errorMessage"] }

    // Waits
    @discardableResult
    func waitForScreen(timeout: TimeInterval = 5) -> Bool {
        usernameField.waitForExistence(timeout: timeout)
    }

    // Actions — return the screen that appears after the action
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

// HomeScreen.swift  (in UITest target)
struct HomeScreen {
    let app: XCUIApplication

    var container: XCUIElement { app.otherElements["home.container"] }
    var composeButton: XCUIElement { app.buttons["home.compose"] }

    @discardableResult
    func waitForScreen(timeout: TimeInterval = 20) -> Bool {
        container.waitForExistence(timeout: timeout)
    }
}
```

**Usage in tests:**

```swift
func test_validLogin_showsHomeScreen() throws {
    let login = LoginScreen(app: app)
    XCTAssertTrue(login.waitForScreen())

    let username = app.launchEnvironment["UI_TEST_USERNAME"] ?? ""
    let password = app.launchEnvironment["UI_TEST_PASSWORD"] ?? ""

    let home = login
        .enterUsername(username)
        .enterPassword(password)
        .tapSignIn()

    XCTAssertTrue(home.waitForScreen(),
                  "Home screen must appear after successful login")
}
```

---

## Step 5 — Waiting Patterns

```swift
// ✅ waitForExistence — the standard wait
let element = app.buttons["compose.publish"]
XCTAssertTrue(element.waitForExistence(timeout: 10))

// ✅ Predicate wait — for element state changes (not just existence)
let publishedState = NSPredicate(format: "label == 'Published'")
let expectation = XCTNSPredicateExpectation(predicate: publishedState,
                                             object: app.staticTexts["compose.status"])
wait(for: [expectation], timeout: 15)

// ✅ Wait for element to disappear
let spinner = app.activityIndicators["loading.spinner"]
let gone = NSPredicate(format: "exists == false")
let disappear = XCTNSPredicateExpectation(predicate: gone, object: spinner)
wait(for: [disappear], timeout: 10)

// ✅ Wait for element to become hittable (exists and not obscured)
let button = app.buttons["login.signIn"]
let hittable = NSPredicate(format: "isHittable == true")
let ready = XCTNSPredicateExpectation(predicate: hittable, object: button)
wait(for: [ready], timeout: 5)

// ✅ Safe element property access — read .count before accessing properties
// Accessing .identifier, .label, or .value on a non-existent element throws.
// Always confirm existence via .count before reading any property.
let fields = app.searchFields
let fieldCount = fields.count          // safe — never throws
if fieldCount > 0 {
    let id = fields.firstMatch.identifier  // safe — element confirmed to exist
}

// ❌ Throws if element doesn't exist
let id = app.searchFields.firstMatch.identifier  // EXC_BAD_INSTRUCTION if count == 0

// ❌ Never
Thread.sleep(forTimeInterval: 2)   // race condition
sleep(2)                            // race condition
```

---

## Step 6 — Common Interaction Patterns

### Text entry

```swift
// Clear before typing (field may have default/placeholder state)
let field = app.textFields["login.username"]
field.tap()
field.clearAndTypeText("newvalue@example.com")  // see extension below

// Extension for clear + type (add to UITest target)
extension XCUIElement {
    func clearAndTypeText(_ text: String) {
        guard let currentValue = value as? String, !currentValue.isEmpty else {
            tap()
            typeText(text)
            return
        }
        // Select all and replace
        tap()
        let selectAll = XCUIApplication().menuItems["Select All"]
        if selectAll.waitForExistence(timeout: 1) {
            selectAll.tap()
        }
        typeText(text)
    }
}
```

### Keyboard activation hides sibling elements

After `typeText()` is called, the software keyboard appears and elements behind
the keyboard overlay are **removed from the accessibility tree**. Any assertion
that compares element counts before and after typing will see a different count
for reasons unrelated to the feature under test.

```swift
// ❌ Fragile — count changes because keyboard hides siblings, not because search filtered
let before = app.descendants(matching: .any).matching(identifier: "result.card").count
searchField.typeText("ab")
let after = app.descendants(matching: .any).matching(identifier: "result.card").count
XCTAssertEqual(before, after, "Short query should not filter")  // fails — keyboard hid cards

// ✅ Assert on something that is never rendered when the condition is met,
//    rather than comparing visible counts
let noResults = app.staticTexts["search.no_results"]
XCTAssertFalse(noResults.exists, "No-results label must not appear for short query")
```

**Rule:** After any `typeText()` call, do not assert on sibling element counts.
Assert on the presence or absence of a sentinel element that only appears when
the app explicitly renders it.

### Navigation

```swift
// Back button (prefer identifier over "Back" label — localisation risk)
app.navigationBars.buttons.firstMatch.tap()   // last resort
app.navigationBars["Settings"].buttons["Back"].tap()  // slightly better
app.buttons["nav.back"].tap()                 // ✅ best — set this identifier
```

### Alerts

```swift
// System alert (permissions)
let alert = app.alerts.firstMatch
if alert.waitForExistence(timeout: 3) {
    alert.buttons["Allow"].tap()
}

// App-defined alert
let alert = app.alerts["Error"]
XCTAssertTrue(alert.waitForExistence(timeout: 5))
alert.buttons["OK"].tap()
```

### Scrolling to element

```swift
let cell = app.cells["settings.quality.hd1080"]
if !cell.isHittable {
    app.swipeUp()
}
XCTAssertTrue(cell.waitForExistence(timeout: 3))
cell.tap()
```

### tvOS SwiftUI layout gotchas that break UI tests

These are app-side bugs that surface as test failures rather than test bugs:

- **`ScrollView` wrapping a layout view (e.g. a row-computing tags view) gives
  the child zero proposed width**, so no rows are produced and no elements
  appear in the tree. Remove the `ScrollView` when it is only being used for
  clipping — use `.clipped()` on the parent instead.

- **`ZStack` centres content rather than anchoring to the top.** For
  top-anchored clipping, use `ScrollView { ZStack { … } }.scrollDisabled(true)`
  not a bare `ZStack` with `.clipped()`.

- **`.focusEffectDisabled()` is the correct fix for the unwanted white
  background focus halo on tvOS** when a custom-styled card or button already
  draws its own focus state. Apply it to the view, not its container.

### Screenshots for failure diagnosis

```swift
// In setUp — attach screenshot on failure
addUIInterruptionMonitor(withDescription: "Permission dialog") { alert in
    alert.buttons["Allow"].tap()
    return true
}

// In a test — manual screenshot
let screenshot = app.screenshot()
let attachment = XCTAttachment(screenshot: screenshot)
attachment.name = "After tapping Compose"
attachment.lifetime = .keepAlways
add(attachment)
```

---

## Step 7 — Running UI Tests

### Via xcodebuildmcp (preferred)

Read the `xcodebuildmcp-cli` skill. Use the `test-sim` tool:

```bash
xcodebuildmcp simulator test-sim \
  --scheme MyAppUITests \
  --project-path ./MyApp.xcodeproj \
  --simulator-name "iPhone 16"
```

Set credentials in the environment before this call:

```bash
export UI_TEST_USERNAME="$(op read 'op://Personal/MyApp Test Account/username')"
export UI_TEST_PASSWORD="$(op read 'op://Personal/MyApp Test Account/password')"

xcodebuildmcp simulator test-sim \
  --scheme MyAppUITests \
  --project-path ./MyApp.xcodeproj \
  --simulator-name "iPhone 16"
```

**3 — Register new test files in `.pbxproj` explicitly.**  
Xcode does not auto-discover Swift files added to a UI test target. A new
`.swift` file that is not listed in the target's `sources` build phase is
silently ignored — the test class compiles nowhere and produces no error.
After adding any new test file, open the `.pbxproj` and confirm the file
appears under the UI test target's `PBXSourcesBuildPhase`.

**4 — Confirm the simulator version exists on the runner before pinning it.**  
Available simulators vary by macOS/Xcode image. A pinned version like
`tvOS 26.0` may not exist on `macos-26`; only `26.1`, `26.2`, and `26.4`
may be available. Always confirm with:

```bash
xcrun simctl list runtimes
```

before committing a pinned version to a workflow file.

**5 — Do not bump the macOS/Xcode runner image and change test code in the
same PR.** Image bumps frequently cause opaque CI failures (`** TEST FAILED **`
with no per-test breakdown) that local builds cannot reproduce. Isolate image
bumps in their own PR so a simple revert gives a decisive answer.

**6 — For persistent CI hangs, try `ONLY_ACTIVE_ARCH=NO CODE_SIGNING_REQUIRED=NO`.**  
A 30+ minute hang with no per-test output is often caused by an LLDB debugger
attach race. The following flags work around it:

```bash
xcodebuild clean test \
  -scheme MyAppUITests \
  -destination '…' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_REQUIRED=NO \
  2>&1 | xcbeautify
```

### Via xcodebuild directly

```bash
xcodebuild test \
  -scheme MyAppUITests \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0' \
  -testenv "UI_TEST_USERNAME=${UI_TEST_USERNAME}" \
  -testenv "UI_TEST_PASSWORD=${UI_TEST_PASSWORD}" \
  -resultBundlePath UITestResults.xcresult \
  2>&1 | tee uitest-output.log
```

### Pre-run checklist

Before running, verify two things that produce misleading errors if skipped:

**1 — Confirm the scheme name with `xcodebuild -list`.**  
Xcode scheme names are not guessable. `-scheme MyApp` fails if the workspace only defines `MyApp-Debug` / `MyApp-Release`. Always check:

```bash
xcodebuild -workspace MyApp.xcworkspace -list
```

**2 — Delete the result bundle path before each run.**  
`xcodebuild` will error with "Existing file at path" if the `.xcresult` directory already exists. Remove it first:

```bash
rm -rf UITestResults.xcresult
xcodebuild test -workspace … -resultBundlePath UITestResults.xcresult …
```

### Scheme configuration (committed to git — no secrets here)

The `*.xcscheme` file for the UI test scheme should have:
- Environment Variables section: **empty** (secrets come from CI, not the scheme)
- `shouldAutocreateTestPlan = "YES"` (default) — do not add a `<TestPlans>` block unless you understand the path fragility below
- A comment in the scheme XML: `<!-- Set UI_TEST_USERNAME and UI_TEST_PASSWORD locally via Edit Scheme -->`

### xctestplan files — path fragility

If you check in a `.xctestplan` file and reference it from the scheme, the path
format matters critically:

```xml
<!-- ❌ Fragile — only resolves when the parent directory is named exactly right -->
<TestPlanReference location = "container:../myapp-apple/MyApp.xctestplan">

<!-- ✅ Robust — relative to the workspace, not its parent -->
<TestPlanReference location = "container:MyApp.xctestplan">
```

The `container:../parentdir/` form is what Xcode writes when a test plan is
created in a location outside the workspace. It resolves correctly on the
machine where it was created, but breaks on any clone where the parent directory
has a different name — including CI runners. Always use workspace-relative paths.

Also check `*.xcworkspace/contents.xcworkspacedata` — Xcode sometimes adds a
matching `<FileRef>` there when a test plan is first checked in. If the test
plan is later removed or its path corrected, this workspace reference must be
cleaned up manually (`git add -f` may be needed if `*.xcworkspace` is in the
global gitignore).

**Do not layer per-target `parallelizable: true` in an xctestplan on top of a
workflow-level `parallel-testing-enabled: true`.** Pick one. Stacking both
produces non-deterministic test ordering and makes timing-sensitive tests fail
intermittently across retries of the same SHA.

### Output formatter — xcbeautify, not xcpretty

`xcpretty` does not parse Xcode 26's test output format correctly. On newer
Xcode versions it silently drops per-test failure detail, leaving only
`** TEST FAILED **` with no actionable information.

Use `xcbeautify` instead:

```bash
xcodebuild test \
  -scheme MyAppUITests \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
  -resultBundlePath TestResults.xcresult \
  2>&1 | xcbeautify

# Install if needed:
brew install xcbeautify
```

If using `sersoft-gmbh/xcodebuild-action@v3` in GitHub Actions, pass
`output-formatter: xcbeautify` if the action version supports it, or call
`xcodebuild` directly and pipe through `xcbeautify`.

**Always wire up xcresult artifact upload before chasing a CI failure on a new
runner image.** A failed CI run that doesn't upload its xcresult bundle teaches
nothing. Verify that artifact upload works on a deliberately-failing run first.

---

## Step 8 — What Makes a Good UI Test

**DO test:**
- Complete user flows (login → compose → publish)
- Error states that require real UI feedback (wrong password, no network)
- Navigation paths (deep links, back navigation, tab switching)
- Permission handling (camera, microphone prompts)
- State that persists across screens (selected quality visible in preview)

**DO NOT test:**
- Business logic (that belongs in unit tests)
- Apple-provided controls (pickers, alerts work — trust them)
- Every edge case (UI tests are slow; test critical paths only)
- Exact pixel layout (use snapshot tests for that)
- Implementation details (don't assert on internal state you can't observe via UI)

**Target coverage:** Critical user journeys, not exhaustive branches.

---

## Step 9 — Diagnosing Failures: A Structured Approach

When a test assertion fails with zero matching elements, follow this sequence
before changing any code.

### ViewInspector traversal — use `.find()` not direct accessors

ViewInspector direct accessor methods (`.scrollView()`, `.vStack()`,
`.anyView()`) are not version-stable across tvOS releases. Tests using them
pass on the simulator image they were written for and fail on newer ones with
no obvious cause.

**Always use `.find()` instead.** It resolves to the correct concrete type
regardless of the tvOS version and survives view refactors that change
intermediate wrapper types.

```swift
// ❌ Breaks across tvOS versions
let stack = try sut.inspect().anyView().vStack()

// ✅ Stable
let button = try sut.inspect().find(button: "Sign In")
```

### Bisection with a minimal diagnostic assertion

When a test failure is hard to reproduce or the cause is unclear, do not
guess and apply multiple fixes. Use a minimal diagnostic loop:

1. Add a single `XCTFail("DIAGNOSTIC: \(element.count)")` assertion
2. Run the test
3. Read the output
4. Remove the diagnostic assertion entirely before applying any fix

Applying accessibility modifier changes and running the test simultaneously
makes it impossible to know which change had which effect — or whether the
failure was a timing race that resolved on its own.

### Capturing diagnostic data on tvOS (and when file writes fail)

On tvOS, the UI test runner executes in a sandboxed process. File writes to
`/tmp/` or `NSHomeDirectory()` go to the runner's sandbox — not the user's
filesystem — and the file never appears. `XCTAttachment` stores data as binary
blobs in the `.xcresult` bundle that are not extractable as text via
`xcresulttool`.

**The only reliable method to surface text diagnostics from a tvOS UI test is
an intentional `XCTFail` with the data embedded in the message string.**

```swift
// ✅ Diagnostic via XCTFail — extractable with xcresulttool
func test_diagnostic_searchTree() throws {
    let screen = SearchScreen(app: app)
    XCTAssertTrue(screen.waitForScreen())

    // Read .count first — never access .identifier on a non-existent element (throws)
    let fieldCount = app.searchFields.count
    let cardCount = app.descendants(matching: .any)
        .matching(identifier: "search.channel.card").count

    XCTFail("DIAGNOSTIC: searchFields=\(fieldCount) channelCards=\(cardCount)")
}
```

Then extract the message from the result bundle:

```bash
xcrun xcresulttool get --legacy --format json --path UITestResults.xcresult 2>/dev/null \
  | python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
def find_kv(obj, key):
    if isinstance(obj, dict):
        if key in obj:
            v = obj[key]
            if isinstance(v, dict) and '_value' in v:
                print(v['_value'])
        for v in obj.values():
            find_kv(v, key)
    elif isinstance(obj, list):
        for i in obj:
            find_kv(i, key)
find_kv(data, 'message')
"
```

**Rules for diagnostic tests:**
- Name them `test_diagnostic_*` so they're easy to identify and delete
- Remove them before committing — they are scaffolding, not tests
- Always read `.count` before accessing `.identifier` or `.label` (see Step 5)
- Run the diagnostic in isolation first; in a full suite run, navigation may
  not have completed when the diagnostic fires

### Reading xcresult failure data — the two-call pattern

`xcresulttool` exposes two separate subtrees. A common mistake is looking only
at the top-level `issues.testFailureSummaries` key — it contains build warnings
and pre-test errors, but **not per-test assertion failures**. Assertion failures
live under the `testsRef` summary, which requires a second call:

```bash
# Step 1 — get the top-level JSON and note the testsRef id
xcrun xcresulttool get --legacy --format json \
  --path UITestResults.xcresult 2>/dev/null > /tmp/result.json

python3 -c "
import json, sys
data = json.load(open('/tmp/result.json'))
ref_id = data['actions']['_values'][0]['actionResult']['testsRef']['id']['_value']
print(ref_id)
"

# Step 2 — fetch the tests subtree by that id
xcrun xcresulttool get --legacy --format json \
  --path UITestResults.xcresult \
  --id <ref_id_from_step1> 2>/dev/null \
  | python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
def find_kv(obj, key):
    if isinstance(obj, dict):
        if key in obj:
            v = obj[key]
            if isinstance(v, dict) and '_value' in v:
                print(v['_value'])
        for v in obj.values():
            find_kv(v, key)
    elif isinstance(obj, list):
        for i in obj:
            find_kv(i, key)
find_kv(data, 'message')
find_kv(data, 'failureMessage')
"
```

The `App UI hierarchy` attachment is stored as a binary blob in the result
bundle. To extract it as text, look for attachments named `App UI hierarchy`
and decode their payload — or add it as a string via `XCTFail` (see above).

### The "wrong screen" signal — navigation failed, not the assertion

When a test times out on `waitForScreen()`, the default assumption is that the
screen never appeared. But the cause could be that the **wrong screen appeared
instead** — a navigated-to card was activated before the nav could be reached.

**Read the `App UI hierarchy` attachment before touching any test code.**

If the hierarchy shows a screen identifier you didn't expect (e.g.
`category_details_screen` when you expected `search_screen`), the assertion
timeout is a symptom, not the root cause. Extending the wait will not help;
the problem is upstream in the navigation path.

**Isolation run as triage split:**

Run the failing test in isolation immediately after seeing the failure:

```bash
xcodebuild test -workspace … -only-testing:MyAppUITests/SearchUITests/test_search_inputAvailable
```

- **Passes in isolation** → the failure is order- or state-dependent (previous
  test left the simulator under load, parallelisation, or a proxy). Do not
  change test code yet; fix the environment first.
- **Fails in isolation** → the failure is reproducible and code changes are
  warranted.

### Count-based remote presses are a race on tvOS

Page objects that navigate by firing a fixed count of `XCUIRemote` presses
(e.g. 10× LEFT, then UP, then SELECT) are inherently racy when the target
animation has a settle delay. A typical side-nav with `.delay(0.1)` and
`.easeInOut(duration: 0.25)` needs ~350 ms to settle after focus crosses the
boundary. With presses arriving every ~217 ms, subsequent presses can miss
the boundary and move focus inside the wrong container.

The race only manifests under load (slow simulator, long preceding test
session, active proxy). It is latent on a clean/cool sim.

**Detection:** the wrong screen appears in the UI hierarchy attachment;
test duration matches `waitForScreen` timeout rather than normal flow duration.

**Fix (when permitted to modify the page object):** replace count-based presses
with a wait-for-element loop keyed off the target nav element's
`accessibilityIdentifier`:

```swift
// ❌ Count-based — races against animation settle
for _ in 0..<10 { remote.press(.left) }
remote.press(.select)

// ✅ Wait-driven — fires SELECT only after the nav element is focused/visible
let navTab = app.buttons["nav.tab.search"]
var attempts = 0
while !navTab.isHittable && attempts < 15 {
    remote.press(.left)
    _ = navTab.waitForExistence(timeout: 0.4)
    attempts += 1
}
XCTAssertTrue(navTab.isHittable, "Search nav tab must be reachable")
remote.press(.select)
```

If modifying the page object is out of scope, note the latent race in a comment
and add a tracking ticket — don't mask it with a longer timeout on the
destination screen.

### Confirm the view renders

Add `.onAppear` file writes to the suspected view. Run the test. Check if the
file exists. This separates data/render failures from accessibility failures.

### Dump the specific subtree

Dump the accessibility subtree of the nearest known-good parent, not the whole
app. The full `app.debugDescription` is often truncated. Note: on tvOS, use the
`XCTFail` method above instead of file writes.

```swift
// In the Page Object waitForScreen(), after the parent element exists:
let parent = app.otherElements["known.parent"].firstMatch
try? parent.debugDescription.write(toFile: "/tmp/subtree.txt",
                                    atomically: true, encoding: .utf8)
```

### Different tests failing across retries of the same SHA = environment, not test code

When the same commit produces *different* failing tests across consecutive CI
attempts — especially when the test session takes wildly different durations —
the cause is almost always environment, not a bug in the test or app code.

Common environment causes:
- Per-target `parallelizable: true` layered on top of workflow-level parallel execution (non-deterministic ordering)
- Slow CI simulator resource pressure causing wallclock-bound `wait(for:timeout:)` to expire
- A stray xctestplan reference changing which tests run or in what order
- **A running proxy interceptor (Proxyman, Charles, etc.)** — even after quitting, stale CLOSED sockets in the simulator's process can cause network calls to complete slowly, starving the simulator of resources and triggering timing races. Run `lsof -nP -iTCP:9090 | grep LISTEN` to confirm no listener is active. If the port was recently active, reboot the simulator before re-running.

**Do not change test code in response to this pattern.** First stabilise the
environment (remove parallelisation layering, clean test plan references), then
observe whether the flake disappears. Bisect with reverts rather than
speculative fixes pushed on the same branch — a revert is one CI cycle and gives
a decisive answer.

### Extend the wait before concluding a timing race

Before attributing zero results to a missing modifier, rule out timing with a
15-second predicate wait:

```swift
let query = app.descendants(matching: .any).matching(identifier: "my.id")
let predicate = NSPredicate(format: "count > 0")
let expectation = XCTNSPredicateExpectation(predicate: predicate, object: query)
let result = XCTWaiter.wait(for: [expectation], timeout: 15)
// result == .timedOut → not a timing race, the element genuinely isn't in the tree
// result == .completed → timing race; fix is a longer wait in waitForScreen()
```

### Separate the diagnostic from the fix

Do not apply accessibility modifier fixes and run the test in the same pass.
Instrument first, confirm findings, then apply exactly one fix. Applying
multiple speculative fixes simultaneously makes it impossible to know which
one worked — or whether any did.

---

## Step 10 — Post-Creation Checklist

After writing UI tests, verify:

- [ ] `UITestCredentials.swift` exists and reads from `ProcessInfo.processInfo.environment`
- [ ] No string literal credentials anywhere in the test target
- [ ] Every `XCUIElement` access is preceded by `waitForExistence(timeout:)` before interaction
- [ ] `continueAfterFailure = false` is set in `setUpWithError`
- [ ] All required accessibility identifiers are added to the app target
- [ ] No `ScrollView.scrollDisabled(true)` wrapping elements that need to be queryable
- [ ] Container views have explicit `.accessibilityElement(children:)` where queried by identifier
- [ ] Leaf views (ZStack-based chips, cards) own their own `.accessibilityElement(children: .ignore)` and `.accessibilityLabel`
- [ ] No element `.identifier` or `.label` accessed without a `.count > 0` guard first
- [ ] `references/accessibility-ids.md` is updated with new identifiers
- [ ] Scheme XML does not contain hardcoded env var values
- [ ] Tests pass on three consecutive runs before declaring done

---

## References

- **`references/accessibility-ids.md`** — Master list of all accessibility identifiers in the app. Read and update this file whenever adding new tests or identifiers.
- **`references/page-objects.md`** — Catalogue of existing Page Object types. Read before creating new ones to avoid duplication.
- **`xcodebuildmcp-cli` skill** — Use for running tests and inspecting simulator UI.
- **`swift-test-all` skill** — For running the full unit test suite alongside UI tests before committing.
- **`git-commit` skill** — For committing new UI test files under the correct PROJ ticket.