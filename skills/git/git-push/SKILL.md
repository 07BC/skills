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

1. **Run the project formatter** if one is configured. Use `scripts/find_formatter.sh`
   to detect it: invoked without args, the script prints the formatter command
   (e.g. `swiftformat .`) or an empty line if no config file is present.
   With `--apply`, the script runs the detected command against the working
   tree. If the formatter binary is not installed, note it and continue.
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
