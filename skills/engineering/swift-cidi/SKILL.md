---
name: swift-cidi
description: >
  GitHub Actions CI/CD workflows for iOS and tvOS Xcode projects. Use
  this skill whenever the user is debugging a CI failure, modifying a workflow
  file, investigating a flaky test, updating runner images, wiring up
  xcresult artifacts, or asking about xctestplan setup. Also trigger when
  someone asks "why is CI failing", "how do I get the xcresult bundle", "how
  do I update the runner", or "what's wrong with my test plan". Always use
  this skill — do not diagnose CI failures or write workflow YAML ad hoc
  without it.
---

# CI/CD Skill — iOS & tvOS GitHub Actions

This skill covers GitHub Actions CI for Xcode projects.
It encodes lessons from real PR failures — not just general best practice.

## Variables

Examples below use placeholders. Substitute your own values from
`CLAUDE.md` or the project's Xcode settings:

| Placeholder | Meaning | Example |
| --- | --- | --- |
| `$REPO` | GitHub repo (org/name) | `kick-apple-public` |
| `$SCHEME` | Xcode scheme | `Chagi`, `Chagi-Debug` |
| `$WORKSPACE` | Xcode workspace file | `Chagi.xcworkspace` |
| `$UNIT_TEST_TARGET` | Unit test target | `ChagiTests` |
| `$UI_TEST_TARGET` | UI test target | `ChagiUITests` |

Concrete names that appear in examples below (`kick-apple-public`,
`Chagi`, `ChagiTests`) are illustrative — replace with your own
values.

---

## Project CI Overview

Two workflow files govern CI:

| File | Purpose |
|---|---|
| `.github/workflows/xcode-actions.yml` | Unit tests (run on every PR) |
| `.github/workflows/ui-test.yml` | UI tests (tvOS XCUITest suite) |

Both use `sersoft-gmbh/xcodebuild-action@v3`. Both have a broken artifact
upload step (see Known Bugs below). Check both files before diagnosing a
failure — they share common problems.

---

## Step 1 — Diagnose Before Fixing

**Never push a speculative fix to CI without first understanding the failure.**
A failed CI run that doesn't upload an xcresult bundle teaches nothing and
costs minutes.

### Read the run log first

1. Open the failing GitHub Actions run
2. Find the `xcodebuild` step output
3. Look for `** TEST FAILED **`

**If there is no per-test output below `** TEST FAILED **`** — just a bare
failure line — the output formatter is the problem, not the tests. See
[xcpretty → xcbeautify](#output-formatter--xcbeautify-not-xcpretty).

**If different tests fail across consecutive attempts of the same SHA**, with
wildly different session durations, suspect environment — not test code:
- Parallelisation stacking (see [xctestplan rules](#xctestplan-rules))
- Wallclock-bound `wait(for:timeout:)` on a slow CI simulator
- A stray test plan reference changing test ordering

Do not change test code in response to this pattern. Stabilise the environment
first, then observe.

### Bisect with reverts

If a branch has multiple recent commits and CI fails opaquely, revert the most
recent suspect commit and push. One CI cycle gives a decisive answer. Pushing
speculative fixes on the same branch without understanding the failure wastes
cycles and obscures the root cause.

---

## Step 2 — Wire Up xcresult Artifacts

Before chasing any failure on a new runner image, verify that CI uploads its
xcresult bundle on failure. Without this, every failed run is a black box.

### The bug in the current workflow

Both workflow files have a `Package DerivedData` step that does:

```yaml
- name: Package DerivedData
  run: zip -r DerivedData.zip DerivedData
```

`sersoft-gmbh/xcodebuild-action@v3` writes to `~/Library/Developer/Xcode/DerivedData/`
by default — not `./DerivedData` in the workspace root. So this step always
logs `zip warning: name not matched: DerivedData` and the artifact upload finds
nothing.

### Fix — result bundle path

Pass `result-bundle-path` to the action so the xcresult lands in a known
workspace-relative location:

```yaml
- name: Run tests
  uses: sersoft-gmbh/xcodebuild-action@v3
  with:
    scheme: [YOUR-SCHEME]   # e.g. Chagi-Debug
    destination: platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=latest
    action: test
    result-bundle-path: TestResults.xcresult   # ← add this
    output-formatter: xcbeautify               # ← and this (see below)

- name: Upload xcresult
  if: failure()
  uses: actions/upload-artifact@v4
  with:
    name: test-results
    path: TestResults.xcresult
```

**Always verify artifact upload works on a deliberately-failing run before
doing anything else on a new runner image.**

### Extracting failure detail from the xcresult bundle

```bash
# Download the artifact from the GitHub Actions run, then:
xcrun xcresulttool get --legacy --format json --path TestResults.xcresult 2>/dev/null \
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

# Or with jq if available:
xcrun xcresulttool get --legacy --format json --path TestResults.xcresult \
  | jq '.issues'
```

---

## Step 3 — Output Formatter: xcbeautify, not xcpretty

`xcpretty` does not parse Xcode 26's test output format. On Xcode 26+, it
silently drops per-test failure detail, leaving only `** TEST FAILED **` with
no actionable output. This is end-of-life behaviour — xcpretty is unmaintained.

**Use xcbeautify:**

```yaml
# In the xcodebuild-action step:
output-formatter: xcbeautify
```

Or if calling xcodebuild directly:

```bash
xcodebuild test [...] 2>&1 | xcbeautify
```

Install locally:

```bash
brew install xcbeautify
```

**Symptom of xcpretty being the problem:** CI fails with `** TEST FAILED **`
and zero per-test lines. No assertion messages, no test names. This is always
xcpretty failing to parse the output, never a genuine silent test failure.

---

## Step 4 — xctestplan Rules

### Path fragility

Xcode writes `container:../parentdir/MyApp.xctestplan` when a test plan is
created outside the workspace. This path only resolves correctly when the
parent directory has the exact right name — true on the machine where it was
created, broken on CI runners and other local clones.

```xml
<!-- ❌ Fragile — breaks when parent directory name differs -->
<!-- Example from kick-apple-public — substitute your own project name -->
<TestPlanReference location = "container:../your-project/YourScheme.xctestplan">

<!-- ✅ Robust — relative to the workspace -->
<TestPlanReference location = "container:YourScheme.xctestplan">
```

**Symptom:** Non-deterministic test execution; the session takes wildly
different durations across consecutive attempts of the same SHA; different
tests fail each time.

### Prefer `shouldAutocreateTestPlan`

Unless you have a specific reason for a checked-in test plan, leave the scheme
at its default:

```xml
shouldAutocreateTestPlan = "YES"
```

This matches the behaviour of `main` and avoids the path fragility entirely.

### Don't stack parallelisation

If the workflow already has `parallel-testing-enabled: true` at the workflow
level, do **not** also set `parallelizable: true` per-target in the xctestplan.
Pick one. Stacking both produces non-deterministic ordering that makes
timing-sensitive tests flake.

### Clean up the workspace reference too

When removing a test plan from the scheme, also check
`Chagi.xcworkspace/contents.xcworkspacedata` — Xcode adds a matching
`<FileRef>` there when the plan was first checked in. Removing the scheme
reference and the plan file does not remove the workspace reference.

```xml
<!-- Remove this if present after deleting the xctestplan -->
<FileRef location = "group:../your-project/YourScheme.xctestplan">
```

Note: `*.xcworkspace` may be in the global gitignore (`~/.gitignore_global`).
If it's already tracked, modifications need `git add -f`.

---

## Step 5 — Runner Image Upgrades

### Always isolate on a fresh branch

Never piggyback a runner image bump on a feature PR. The failure modes are
unrelated to the feature, the revert history pollutes the PR, and it forces
reviewers to read CI archaeology alongside feature code.

Create a dedicated branch:
```bash
git checkout main
git pull
git checkout -b ci/bump-runner-macos26
```

### Upgrade checklist

When bumping to a new runner image (e.g. macos-26 / Xcode 26 / tvOS 26):

1. **Wire up xcresult artifact upload first** — if CI fails, you need the bundle
2. **Update output formatter to xcbeautify** — xcpretty breaks on Xcode 26
3. **Bump simulator name** — confirm Apple TV 4K generation name for new OS
4. **Push and let CI run** — do not make multiple changes simultaneously
5. **If it fails**, download the xcresult bundle and run `xcresulttool` before doing anything else

### Known failure mode: opaque failure on macos-26 with xcpretty

Symptom: `** TEST FAILED **`, 160–190s session, zero per-test output.
Cause: xcpretty silently drops Xcode 26 output.
Fix: Switch to xcbeautify before retrying.

---

## Step 6 — Flaky Unit Tests on CI Simulators

The examples below are from the Kick codebase. The patterns apply generally —
substitute your own test names and file paths.

### Example: Timeout-bound async test
**Pattern seen in:** `LoginViewModelTests.testLogin()` (`ChagiTests/LoginViewTests/LoginViewModelTests.swift:75`)
**Symptom:** `wait(for: [expect], timeout: N)` expires on slow CI simulator
**Current band-aid:** timeout bumped from 5s → 15s in `7b53badc`
**Real fix needed:** Rewrite as `async throws` test — drive `startLoginProcess()` with `await` so completion is structural, not time-bounded. Inject a deterministic scheduler rather than relying on wallclock.

### Example: AVPlayer state assertion
**Pattern seen in:** `StreamplayerViewModelTests.testSuccesfullChannelPlay()` (`ChagiTests/StreamplayerViewModelTests/StreamplayerViewModelTests.swift:58`)
**Symptom:** `wait(for: [expectPlay], timeout: 1)` — 1 second for AVPlayer to reach `.playing` status is too tight on a loaded CI simulator
**Current band-aid:** none yet; increase to at least 5s
**Real fix needed:** Assert on observable ViewModel state rather than a real AVPlayer's runtime status.

### General rule

Any test using `wait(for:timeout:)` with a wallclock budget is a latent flake
on CI. The fix is always structural: make completion observable without a timer.
Bumping the timeout is a band-aid that defers the problem to the next slow run.

---

## Known Bugs (tracked, not yet fixed)

| Bug | Location | Impact | Fix |
|---|---|---|---|
| DerivedData artifact always empty | Both workflow files, `Package DerivedData` step | No usable artifact on failure | Pass `result-bundle-path` to xcodebuild-action, zip that path |
| xcpretty drops Xcode 26 output | Both workflows, `output-formatter` | Silent failures on new runner | Switch to xcbeautify |
| `*.xcworkspace` in global gitignore | `~/.gitignore_global` | Workspace edits need `git add -f` | Add `![YourApp].xcworkspace/` to project `.gitignore` (low priority) |

---

## References

- **`swift-uitest` skill** — xctestplan rules, xcbeautify, and diagnostic patterns also appear there in the context of authoring UI tests.
- **`kick-commit` skill** — for committing CI/workflow changes under the correct project ticket.