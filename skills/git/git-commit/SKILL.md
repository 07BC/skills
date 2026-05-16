---
name: git-commit
description: Stages specific files and commits with a short imperative message. Extracts a ticket number from the branch name if one is present and prepends it to the message. Use when the user says "commit", "commit my changes", or "stage and commit". Builds on git-push and git-pr — do not invoke manually if those are running.
disable-model-invocation: true
---

## Rules

- **Never** use `git add -A` or `git add .` — stage specific files by name only, unless the user explicitly asks for all.
- **Never** use `--no-verify`. If a pre-commit hook fails, fix the underlying issue and create a new commit.
- **Never** amend a previous commit unless the user explicitly asks.
- **Never** add `Co-Authored-By`, AI attribution, or tooling signatures to commit messages.
- **Never** commit `.env`, secrets, tokens, credentials, or large binaries.
- Always pass the commit message via HEREDOC — never inline with `-m "..."`.
- Commit messages are **short, lowercase, imperative** — no full stops, no emojis.

## Steps

1. Run `git status` and `git diff` in parallel to show what has changed.

2. Extract a ticket number from the current branch name. Match any `WORD-NUMBER` pattern (e.g. `PROJ-123`, `NAT-456`, `TICKET-789`):

   ```bash
   git rev-parse --abbrev-ref HEAD | grep -oE '[A-Z]+-[0-9]+' | head -1
   ```

   If a ticket number is found, prefix the commit message: `PROJ-123: short description`.
   If no ticket is found, use a plain message: `short description`.

3. If the user has not provided a commit message, ask for one. Keep it short and imperative (e.g. `fix logout bug`, `add stream health indicator`).

4. Show the user which files will be staged and confirm before staging.

5. Stage the relevant files by name:

   ```bash
   git add path/to/file1 path/to/file2
   ```

6. Commit using HEREDOC:

   ```bash
   git commit -m "$(cat <<'EOF'
   PROJ-123: short description
   EOF
   )"
   ```

7. Run `git status` to confirm a clean working tree.

## If the pre-commit hook fails

Fix the underlying issue, re-stage the affected files, and create a **new** commit. Do not use `--no-verify` to bypass the hook.

## Commit message format

```
TICKET-123: short lowercase description
```

Without a ticket:

```
short lowercase description
```

### Good examples

```
fix logout on background transition
add error state to stream health view
remove deprecated MediaPicker import
update snapshot tests after layout change
```
