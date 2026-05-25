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

## Gate 1 — Build

Run a clean build. Zero errors. Zero warnings. No exceptions.

```bash
xcodebuild build \
  -scheme [SCHEME] \
  -destination '[DESTINATION]' \
  2>&1 | grep -E "error:|warning:|BUILD SUCCEEDED|BUILD FAILED"
```

> Read `CLAUDE.md` for the correct `[SCHEME]` and `[DESTINATION]` values for this project.

**Pass condition:** `BUILD SUCCEEDED` with zero `error:` and zero `warning:` lines.

**Fail action:** halt. Do not proceed to Gate 2. Report the build output.
A PR with a broken build is never raised.

---

## Gate 2 — Tests

Run the full test suite. All tests must pass.

```bash
xcodebuild test \
  -scheme [SCHEME] \
  -destination '[DESTINATION]' \
  2>&1 | grep -E "Test.*passed|Test.*failed|error:|BUILD"
```

**Pass condition:** all tests pass, zero failures, zero errors.

**Fail action:** halt. Report which tests failed. A PR with failing tests
is never raised.

---

## Gate 3 — Scope

Verify the diff is clean and scoped to the subtask.

```bash
# Files staged for commit
git diff --name-only HEAD

# Confirm no unintended files
git status
```

Check each changed file against the discovery note at
`docs/working/[SUBTASK-KEY]-discovery.md`:

- [ ] Every changed file appears in the discovery note's "Types in scope"
- [ ] No file in "Must NOT touch" has been modified
- [ ] No unrelated files are staged (formatting changes, unrelated fixes,
  leftover debug code)
- [ ] No `docs/working/` files are staged — these are working artefacts,
  not PR content

**Fail action:** halt. List the out-of-scope files. The engineer must
unstage them before the PR is raised.

---

## Gate 4 — Branch Name

Verify the branch name follows the project convention.

```bash
git branch --show-current
```

**Expected format:** `nat-[ticket-number]-[short-kebab-title]`

Examples:
- `nat-1234-add-channel-fetcher` ✅
- `nat-1234-AddChannelFetcher` ❌ — wrong case
- `feature/channel-fetcher` ❌ — missing ticket number
- `nat-1234` ❌ — missing description

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

Once all gates pass, create the PR:

```bash
gh pr create \
  --title "[SUBTASK-KEY]: [Subtask title]" \
  --body "[PR description from Gate 5]" \
  --base 2.0 \
  --head [branch-name]
```

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
