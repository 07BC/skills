---
name: git-pr
description: Commits, pushes, and creates a pull request for the current branch. Runs code review before raising the PR and requires confirmation before creating it. Use when the user says "create a PR", "raise a PR", "open a pull request", or "/git-pr".
disable-model-invocation: true
---

## Rules

- Read **git-push** first and complete all its steps (format → commit → push) before creating the PR.
- PR title **must** follow the same ticket-prefix format as git-commit: `TICKET-123: short description` or a plain description if no ticket exists.
- Present the full PR title and body to the user for confirmation **before** running `gh pr create`.
- Never include AI attribution, "Generated with Claude Code", or similar in the PR body.
- Target branch is `main` unless the project's `CLAUDE.md` specifies otherwise.

## Steps

1. **Read git-push** and complete all steps (format → commit → push).

2. **Run the project's unit tests** if a test suite is present. Skip UI/integration test targets. If any tests fail, stop and report the failures — do not create the PR until they pass.

   Examples:
   - Swift/Xcode: `xcodebuild test -scheme <scheme> -destination 'platform=iOS Simulator,...' -skip-testing:<UITestTarget>`
   - JS/TS: `npm test` or `npx jest --passWithNoTests`
   - Python: `pytest`

   If no test suite exists, skip and continue.

3. **Run a code review** on the diff against the target branch:

   ```bash
   git diff main...HEAD
   ```

   Apply the project's code review skill if available (e.g. `swift-code-review`), otherwise review for: correctness, security issues, obvious bugs, missing error handling at boundaries, and leftover debug code. Report any BLOCKER findings. If blockers exist, stop and ask the user to fix them before continuing.

4. Summarise what is in this branch:

   ```bash
   git log main..HEAD --oneline
   git diff main...HEAD --stat
   ```

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
