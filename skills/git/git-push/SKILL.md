---
name: git-push
description: Runs the project formatter (if configured), commits, then pushes to the remote branch. Use when the user says "commit and push", "push my changes", or "/git-push". Builds on git-commit. Does not create a PR — use git-pr for that.
disable-model-invocation: true
---

## Rules

- Read **git-commit** first and complete all its steps before pushing.
- **Never** force-push to `main` or `master`.
- If the push is rejected due to divergence, stop and report — do not rebase or reset without asking.
- If no upstream is set, push with `-u origin HEAD` to establish tracking.

## Steps

1. **Run the project formatter** if one is configured. Check in this order:

   | Config file present | Command |
   |---|---|
   | `.swiftformat` | `swiftformat .` |
   | `.prettierrc` / `prettier.config.*` | `npx prettier --write .` |
   | `rustfmt.toml` | `cargo fmt` |
   | `pyproject.toml` / `.flake8` | `ruff format .` or `black .` |

   If no formatter config is found, skip this step. If the formatter is not installed, note it and continue.
   Include any files changed by the formatter when staging in the next step.

2. **Read git-commit** and complete all commit steps (status → stage → commit).

3. Check whether the current branch already tracks a remote:

   ```bash
   git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null
   ```

4. Push:
   - No upstream set: `git push -u origin HEAD`
   - Upstream exists: `git push`

5. Confirm the push succeeded by reporting the remote URL and branch name.
