---
name: swift-test-all
description: Runs the Swift test suite once for the current project and reports results. Detects the correct workspace, scheme, and simulator from CLAUDE.md. Use when you want to verify tests pass before committing or raising a PR.
---

# Swift Test All

Run the full test suite once for the current project and report results.

**Scheme**: $ARGUMENTS (if not provided, read from CLAUDE.md or ask the user)

## Steps

### 1. Discover project config

Read `CLAUDE.md` in the current working directory to extract:
- Workspace or project file
- Scheme name
- Simulator destination (platform, OS, device)
- Test target flag if any (`-only-testing:`)

If CLAUDE.md does not specify, run:
```bash
ls *.xcworkspace *.xcodeproj 2>/dev/null
xcodebuild -list 2>/dev/null | head -30
xcrun simctl list devices available 2>/dev/null | grep -E "Apple TV|iPhone" | tail -10
```

### 2. Run tests (once, single destination)

**Prefer Xcode MCP tools when Xcode is open** — they provide richer output and integrate with the live Xcode session. These are deferred tools; load their schemas first:

```
ToolSearch("select:mcp__xcode__RunAllTests,mcp__xcode__RunSomeTests,mcp__xcode__GetBuildLog,mcp__xcode__XcodeListNavigatorIssues")
```

Then call `mcp__xcode__RunAllTests` (or `mcp__xcode__RunSomeTests` with `-only-testing:` equivalent) and `mcp__xcode__GetBuildLog` for the full output.

**Fallback when Xcode is not open** — use raw xcodebuild with ONE `-destination` flag. Always skip UI test targets (any target whose name ends in `UITests`):

```bash
xcodebuild test \
  -workspace <workspace> \
  -scheme <scheme> \
  -destination '<destination>' \
  -skip-testing:<SchemeUITests> \
  2>&1 | tee /tmp/test-output.log
```

To discover which targets end in `UITests`, check the `.xctestplan` file or run:

```bash
xcodebuild test -workspace <workspace> -scheme <scheme> -destination '<destination>' -showTestPlans 2>/dev/null | grep UITests
```

### 3. Check live navigator issues

After tests complete, call `mcp__xcode__XcodeListNavigatorIssues` (load schema via ToolSearch if not already loaded) to surface any remaining errors or warnings visible in the Xcode navigator. Include these in the report if any are found.

### 4. Parse and report results

Produce a clean summary:

```
✅ All tests passed (N tests)  ⏱ Xm Ys
```
or
```
❌ N failed out of M total  ⏱ Xm Ys

Failing tests:
- TestSuite/testName
  → failure reason
  → File.swift:42

Navigator issues (if any):
- File.swift:42 — error/warning description
```

### 5. Cleanup (fallback path only)

```bash
rm -f /tmp/test-output.log
```

## Rules

- ONE destination, ONE run — never add multiple `-destination` flags
- Always use the Debug scheme — never trigger Release
- NEVER run UI tests — always add `-skip-testing:<target>UITests` for every target ending in `UITests`
- If the scheme is not found, list available schemes with `xcodebuild -list` and stop
- Do not attempt to fix failures automatically — report and let the developer decide
