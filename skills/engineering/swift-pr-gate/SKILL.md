---
name: swift-pr-gate
description: >
  Runs a structured pre-PR gate before creating a pull request. Verifies build
  is clean, tests pass, scope is tight, branch is correctly named, and the PR
  description is complete and accurate. Use in Phase 8 of ticket-to-pr,
  immediately before running gh pr create. Triggers on "gate the PR", "pre-PR
  check", "ready to raise PR", or at the end of any ticket-to-pr run. Do NOT
  use this skill at the start of a ticket — use pr-preflight for that.
---

# Swift PR Gate Skill

Runs the final gate before a PR is created. This skill is a closing check —
it verifies that the work done in previous phases is correct, complete, and
safe to put in front of a reviewer.

**Nothing gets merged that hasn't passed this gate.**

---

## What this skill does NOT do

- Does not write code or fix issues — it finds them and halts
- Does not run at the start of a ticket (use `pr-preflight` for that)
- Does not review code quality (that happened in Phase 7)
- Does not create the PR — it prepares and validates everything so the
  `gh pr create` call that follows cannot fail for an avoidable reason

---

## Inputs from CLAUDE.md

Read these once at the start; every gate references them:

- `SCHEME`, `DESTINATION` — build configuration
- `TEST_TARGET` — value used in `-only-testing:`
- `BASE_BRANCH` — declared base branch, fall back to `main`
- `BRANCH_PREFIX` — declared branch prefix, fall back to the project's
  Jira key (lowercased) plus `-`
- `PLANS_DIR` — `${HOME}/Developer/obsidian/$(basename $(git rev-parse --show-toplevel))/plans`

If any required value is missing, halt and ask the user before running any gate.

---

## Gate 1 — Build

Run a clean build. Zero errors. Zero warnings. No exceptions.

Prefer MCP Xcode tools when Xcode is open:

```
ToolSearch("select:mcp__xcode__BuildProject,mcp__xcode__GetBuildLog")
```

Fall back to Bash:

```bash
xcodebuild build \
  -scheme [SCHEME] \
  -destination '[DESTINATION]' \
  2>&1 | grep -E "error:|warning:|BUILD SUCCEEDED|BUILD FAILED"
```

**Pass condition:** `BUILD SUCCEEDED` with zero `error:` and zero `warning:` lines.

**Fail action:** halt. Do not proceed to Gate 2. Report the build output.
A PR with a broken build is never raised.

---

## Gate 2 — Tests

Run the full test suite. All tests must pass.

Prefer MCP Xcode tools:

```
ToolSearch("select:mcp__xcode__RunSomeTests,mcp__xcode__RunAllTests")
```

Fall back to Bash:

```bash
xcodebuild test \
  -scheme [SCHEME] \
  -destination '[DESTINATION]' \
  -only-testing:[TEST_TARGET] \
  2>&1 | grep -E "Test.*passed|Test.*failed|error:|BUILD"
```

**Pass condition:** all tests pass, zero failures, zero errors.

**Fail action:** halt. Report which tests failed. A PR with failing tests
is never raised.

---

## Gate 3 — Scope

Verify the diff is clean and scoped to the subtask.

```bash
# Files changed on this branch
git diff --name-only [BASE_BRANCH]...HEAD > /tmp/pr-gate-diff.txt

# Confirm no unintended local changes
git status --short
```

Read the discovery note at `${PLANS_DIR}/[SUBTASK-KEY]-discovery.md` and
build two sets:

- `IN_SCOPE` — every file path referenced under "Types in scope"
- `MUST_NOT_TOUCH` — every file path referenced under "Must NOT touch"

Then verify programmatically:

```bash
# Every changed file must be in IN_SCOPE
comm -23 <(sort /tmp/pr-gate-diff.txt) <(printf '%s\n' "${IN_SCOPE[@]}" | sort) \
  > /tmp/pr-gate-out-of-scope.txt
test ! -s /tmp/pr-gate-out-of-scope.txt   # empty file = pass

# No changed file may appear in MUST_NOT_TOUCH
comm -12 <(sort /tmp/pr-gate-diff.txt) <(printf '%s\n' "${MUST_NOT_TOUCH[@]}" | sort) \
  > /tmp/pr-gate-forbidden.txt
test ! -s /tmp/pr-gate-forbidden.txt      # empty file = pass
```

Additionally:

- [ ] No unrelated files are staged (formatting changes, unrelated fixes,
  leftover debug code)
- [ ] No working artefacts staged (`${PLANS_DIR}` is outside the repo, but
  verify no copy of a discovery note has been committed)

**Fail action:** halt. List the out-of-scope and/or forbidden files. The
engineer must unstage them before the PR is raised.

---

## Gate 4 — Branch Name

Verify the branch name follows the project convention.

```bash
git branch --show-current
```

**Expected format:** `${BRANCH_PREFIX}[ticket-number]-[short-kebab-title]`

Examples (with `BRANCH_PREFIX=nat-`):
- `nat-1234-add-channel-fetcher` ✅
- `nat-1234-AddChannelFetcher` ❌ — wrong case
- `feature/channel-fetcher` ❌ — missing ticket number / prefix
- `nat-1234` ❌ — missing description

Match against the regex `^${BRANCH_PREFIX}[0-9]+-[a-z0-9-]+$`.

**Fail action:** halt. State the current branch name and the expected format.
Do not raise a PR from a wrongly named branch.

---

## Gate 5 — PR Description

Produce the PR description. Do not use the discovery note verbatim — the
discovery note is internal working context. The PR description is for reviewers.

Use this template exactly:

```markdown
## Summary
[What changed and why — one paragraph. What the subtask required, what was
built, and how it fits into the parent ticket.]

## Root Cause / Motivation
[For bug fixes: name the iOS API, the architectural failure mode, or the
originating commit — not the symptom.
For features: name the requirement from the parent ticket AC.]

## Solution
[What shape was chosen and why. Reference the architecture pattern followed.
e.g. "Implemented as a @MainActor @Observable final class per the target
architecture, injected via AppDependencies."]

## Changes
[File-by-file summary of what changed. One line per file.]
- `Services/FooService.swift` — added `fetchBar()` method
- `Models/BarModel.swift` — new Decodable model for bar response

## Tests
[What is covered by the new Swift Testing tests. One line per test suite.]
- `FooServiceTests` — happy path, network failure, empty response

## Test Plan
[Steps a reviewer can follow to verify the change manually, if applicable.]
1. Launch the app on Apple TV simulator
2. Navigate to [screen]
3. Verify [behaviour]
```

**Rules:**
- Root Cause must name a cause, not a symptom
- Solution must reference the architecture pattern — not just "I added a service"
- Changes list must match the actual diff — verify against `git diff --name-only HEAD`
- Never leave template placeholder text in the description

**Fail action:** if the description cannot be completed accurately, halt and
report what information is missing.

---

## Gate 6 — Jira Status

Before raising the PR, update the Jira subtask status via Atlassian MCP:

1. Transition the subtask to `In Review`
2. Confirm the transition succeeded

**Fail action:** if the MCP call fails, note it but do not halt — the PR
can still be raised. Report the failure to the user after PR creation.

---

## Gate Summary

Produce a gate summary before raising the PR:

```
## PR Gate Summary — [SUBTASK-KEY]

Gate 1 — Build:       PASS / FAIL
Gate 2 — Tests:       PASS / FAIL
Gate 3 — Scope:       PASS / FAIL — [N files changed, all in scope]
Gate 4 — Branch:      PASS / FAIL — [branch name]
Gate 5 — Description: READY
Gate 6 — Jira:        UPDATED / FAILED

Verdict: RAISE PR / BLOCKED — [reason]
```

**Only proceed to `gh pr create` if all gates pass.**

---

## PR Creation

Once all gates pass, write the synthesised PR description (Gate 5) to a
file, then create the PR:

```bash
# Body file lives outside the repo so it never accidentally gets staged
BODY_FILE="${PLANS_DIR}/[SUBTASK-KEY]-pr-body.md"
cat > "$BODY_FILE" <<'EOF'
[PR description from Gate 5]
EOF

gh pr create \
  --title "[SUBTASK-KEY]: [Subtask title]" \
  --body-file "$BODY_FILE" \
  --base "[BASE_BRANCH]" \
  --head "[branch-name]"
```

Never pass the raw discovery note as `--body` — the discovery note is
engineer-facing context, not reviewer-facing content.

After the PR is created:
1. Add the PR URL as a comment on the Jira subtask via Atlassian MCP
2. Report the PR URL to the user

---

## Halt Conditions

Halt immediately (do not proceed to the next gate) if:
- Build fails — Gate 1
- Any test fails — Gate 2
- Out-of-scope files are staged — Gate 3
- Branch name does not match convention — Gate 4

Never raise a PR that has not passed Gates 1–5.
