---
name: git-pr
description: Commits, pushes, and creates a pull request for the current branch. Runs code review before raising the PR and requires confirmation before creating it. Use when the user says "create a PR", "raise a PR", "open a pull request", or "/git-pr".
---

## Rules

- Read **git-push** first and complete all its steps (format → commit → push) before creating the PR.
- PR title **must** follow the same ticket-prefix format as git-commit: `TICKET-123: short description` or a plain description if no ticket exists.
- Present the full PR title and body to the user for confirmation **before** running `gh pr create`.
- Never include AI attribution, "Generated with Claude Code", or similar in the PR body.
- Target branch is `main` unless the project's `CLAUDE.md` specifies otherwise.

## Steps

1. **Read git-push** and complete all steps (format → commit → push).

2. **Run the project's unit tests** if a test suite is present. Skip
   UI/integration test targets. If any tests fail, stop and report
   the failures — do not create the PR until they pass.

   Read `SCHEME`, `DESTINATION`, `TEST_TARGET`, and `UI_TEST_TARGET`
   from the project's `CLAUDE.md`. If those values aren't declared,
   fall back to the project's documented test command.

   Examples:
   - Swift/Xcode (Xcode open): `mcp__xcode__RunSomeTests` with
     `$TEST_TARGET` only — skips UI tests by virtue of selecting just
     the unit target.
   - Swift/Xcode (Xcode closed): `xcodebuild test -scheme $SCHEME
     -destination '$DESTINATION' -only-testing:$TEST_TARGET`.
   - JS/TS: `npm test` or `npx jest --passWithNoTests`.
   - Python: `pytest`.

   **Timeout: 5 minutes.** If tests don't complete in that window,
   terminate, report the timeout, and halt PR creation. Do not raise
   a PR over a hung test suite.

   If no test suite exists, skip and continue.

3. **Run a code review** on the diff against the target branch:

   ```bash
   git diff main...HEAD
   ```

   Apply the project's code review skill if available (prefer
   `swift-code-review` for Swift projects). Use its severity mapping
   end-to-end: `BLOCKER` / `WARNING` / `SUGGESTION`. If no skill is
   available, review for correctness, security issues, obvious bugs,
   missing error handling at boundaries, and leftover debug code.

   **What blocks the PR:**

   - **BLOCKER findings** halt PR creation. Fix or reroute (e.g.
     spawn a fix subagent) before continuing.
   - **WARNING findings** do not halt. Include them in the PR
     description's "Review notes" section so reviewers know which
     items the author chose to ship anyway.
   - **SUGGESTION findings** do not halt and do not need to appear in
     the PR description.

4. Summarise what is in this branch by running `scripts/branch_summary.sh`
   (defaults to `main` as the base; pass another branch name to override).
   The script emits two labelled blocks: `=== commits (BASE..HEAD) ===` and
   `=== diffstat (BASE...HEAD) ===`.

5. Draft the PR title and body (see format below). Show the user the full draft and ask for confirmation before creating the PR.

6. On confirmation, create the PR:

   ```bash
   gh pr create --title "TICKET-123: short description" --body "$(cat <<'EOF'
   ## Summary

   - <bullet>

   ## Test Plan

   - [ ] <step>
   EOF
   )"
   ```

7. Output the PR URL.

## PR body format

```markdown
## Summary

- <What changed — one bullet per logical change>
- <Why it was needed or what problem it solves>

## Test Plan

- [ ] <User-facing action — navigate, tap, toggle, submit>
- [ ] <Verify what the user sees or experiences>
- [ ] <Repeat for each changed behaviour>
```

### Test Plan rules

- Every item is a `- [ ]` checkbox.
- Each item is a **single short step** — no multi-action sentences.
- Written from the user's perspective — what they do and what they observe.
- No mention of Xcode, logs, build flags, mocks, analytics events, or internal tooling.
- Cover the happy path first, then any changed edge cases.

## PR title format

With ticket:
```
TICKET-123: short lowercase description
```

Without ticket:
```
short lowercase description
```
