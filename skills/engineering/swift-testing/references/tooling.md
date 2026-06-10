# Swift Testing — use the whole toolkit

Good unit tests are not written from the source file alone. Before and during test authoring, lean on the code-intelligence, coverage, and build tools — guessing is how mock-asserts-mock tests and flaky waits get written.

## Code intelligence — gitnexus / codegraph

When available (`mcp__gitnexus__*`, `mcp__codegraph__*`), use them for three jobs:

1. **Find what *consumes* a symbol** — `mcp__gitnexus__context` / `codegraph_callers`. This is how you obey the "test through the consumer, never the mock's own return" ban: to test a dependency's effect, find the production type that consumes it and assert through *that*. It also reveals the real call path so your test exercises production logic, not a parallel setup.
2. **Grade blast radius for coverage prioritisation** — `mcp__gitnexus__impact` (direction `upstream`). Rank dark files by `uncovered × blast-radius` (see `references/coverage.md`). High-blast untested code is where a test earns the most.
3. **Impact-check before any production change** — if you must add a seam to make code testable (protocol + injection), run `impact` first. LOW/MEDIUM → proceed keeping behaviour identical. HIGH/CRITICAL → surface as a finding and stop; do not bury a risky refactor in a test task.

## Coverage — `xccov`

`xcrun xccov view --report /path/to.xcresult` is the empirical coverage signal. Never infer coverage from reading the suite — measure it, and re-measure after each batch to record the delta. Full workflow in `references/coverage.md`.

## Build/test truth — `xcodebuild`

`xcodebuild` is the authority on whether code compiles and tests pass — **SourceKit is not**.

- SourceKit diagnostics like `No such module 'Testing'` / `No such module 'XCTest'` / cross-module "cannot find type" on a file you just edited are **indexing lag**, not real failures. A clean `xcodebuild` (or the Xcode MCP build) is the truth. Acknowledge with one line and continue; only act on a diagnostic that survives a clean build.
- **Run serially** (`-parallel-testing-enabled NO`) when verifying — parallel scheduling can mask failures as 0.000s "launch flakes" and hides cross-suite races.
- **SPM packages with a platform conflict cannot be tested via `swift test`.** If a local package declares a lower minimum OS than a dependency requires (e.g. a package at macOS 10.13 depending on a product needing 10.15), CLI `swift test` fails to resolve. Test it through `xcodebuild test -scheme {Package} -destination 'platform={platform} Simulator,...'` against the simulator instead.

## API truth — context7

Confirm current Swift Testing API rather than relying on memory:

| Library ID | Use for |
|---|---|
| `/swiftlang/swift` | Swift Testing library source, trait/expectation semantics |
| `/websites/swift` | Swift Testing documentation on swift.org |

Things worth confirming, not guessing: `@Test(arguments:)` with `zip(...)` is **non-combinatorial** (one case per tuple); `.timeLimit` has a **1-minute granularity minimum** (you cannot bound a test to under a minute with it).

## Running tests — Xcode MCP

When Xcode is open, prefer the Xcode MCP tools over a fresh `xcodebuild` for speed:

```
ToolSearch("select:mcp__xcode__RunSomeTests,mcp__xcode__RunAllTests,mcp__xcode__XcodeListNavigatorIssues")
```

Run the specific suite with `mcp__xcode__RunSomeTests`, then `mcp__xcode__XcodeListNavigatorIssues` to confirm no new issues. Fall back to the `swift-test-all` skill / `xcodebuild` when Xcode is not open.

## Gate every commit on a green run

Confirm the run printed `** TEST SUCCEEDED **` (or the MCP equivalent) **before** committing. Never chain a commit unconditionally after the test command — a compile error or failure then lands a red commit you have to amend. Run → read result → commit only if green.
