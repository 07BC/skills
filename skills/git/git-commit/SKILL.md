---
name: git-commit
description: Stages specific files and commits with a short imperative message. Extracts a ticket number from the branch name if one is present and prepends it to the message. Use when the user says "commit", "commit my changes", or "stage and commit". Builds on git-push and git-pr — do not invoke manually if those are running.
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

1. Run `scripts/preflight.sh` (bundled with this skill) to get the
   status, diff, and ticket extraction in one call. The script emits
   three labelled blocks (`=== status ===`, `=== diff ===`,
   `=== ticket ===`); the ticket block is either a `WORD-NUMBER` match
   from the branch name (e.g. `PROJ-123`) or empty.

   If the script is missing from the skill directory (rare — it ships
   alongside SKILL.md), fall back to running these three commands by
   hand: `git status --short`, `git diff`, and
   `git branch --show-current | grep -oE '[A-Z]+-[0-9]+'`.

2. If the ticket block is non-empty, prefix the commit message:
   `PROJ-123: short description`. Otherwise use a plain message:
   `short description`.

3. If the user has not provided a commit message, ask for one. Keep it short and imperative (e.g. `fix logout bug`, `add article cache`).

4. Show the user which files will be staged and confirm before staging.

5. Stage the relevant files by name:

   ```bash
   git add path/to/file1 path/to/file2
   ```

6. Commit using HEREDOC with the skill sentinel so the pre-tool hook allows it:

   ```bash
   CLAUDE_SKILL_COMMIT=1 git commit -m "$(cat <<'EOF'
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
add error state to article list view
remove deprecated MediaPicker import
update snapshot tests after layout change
```
