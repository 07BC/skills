---
name: swift-lint
description: >
  Runs SwiftLint with the correct config for the current project. Use when the
  user says "lint this", "run swiftlint", "check style", "swiftlint errors",
  or "/j:swift-lint". Walks up from the current directory to find the nearest
  .swiftlint.yml, then runs from that directory so included/excluded paths
  resolve correctly.
---

# swift-lint

Finds the correct `.swiftlint.yml` and runs `swiftlint lint` from the right
working directory.

---

## Step 1 — Find config

Run `scripts/run-lint.sh [path]` where `path` is the directory or file the
user wants to lint (defaults to cwd).

The script walks up from `path` to find the nearest `.swiftlint.yml`, changes
to that directory, and runs:

```
swiftlint lint --config <found-config> [path]
```

---

## Step 2 — Report results

The script emits a banner summary. Relay violations to the user, grouped by
severity:

- **Serious** (error) — must fix before merging
- **Warning** — should fix, but not blocking

If zero violations: confirm clean with a one-line message.

---

## Rules

- Do **not** hardcode a config path — always discover via the script.
- If no `.swiftlint.yml` is found anywhere in the tree, tell the user and
  suggest adding one at the project root.
- Do **not** run `swiftlint autocorrect` without explicit user permission.
- Pass `--strict` only if the user explicitly requests it.
