---
name: obsidian:audit
description: Audits the Obsidian vault at ~/raw and auto-applies tag + property fixes with a per-run changelog. Use when the user asks to audit notes, clean up frontmatter, fix or normalise tags, add/update YAML properties, lift inline bullet fields into frontmatter, or run a vault hygiene sweep. Triggers on "audit my vault", "audit notes", "clean up frontmatter", "fix tags", "tag audit", "property audit", "/obsidian:audit". Changes are git-backed and fully revertible.
---

# Obsidian Vault Audit

Audit notes in the vault at `$HOME/raw`. For each candidate note, evaluate tags + properties against the rules in this skill, apply fixes, and write a changelog. Auto-apply only — vault is git-backed; revert via `git`.

## Preconditions (check first, halt if any fail)

```bash
VAULT="$HOME/raw"

# 1. Vault is a git repo
git -C "$VAULT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Vault is not a git repo. Aborting."; exit 1; }

# 2. Vault has no uncommitted changes (otherwise the audit's diff is muddied)
[ -z "$(git -C "$VAULT" status --porcelain)" ] || { echo "Vault has uncommitted changes. Commit or stash first."; exit 1; }
```

If any precondition fails, stop and report. Do not edit anything.

The Obsidian CLI is **not** used by this skill — it is flaky and silently
fails on path resolution. All edits are direct file operations on `$VAULT`.

## Workflow

### Step 1 — Determine scope

Default scope priority:
1. If user passed a path arg (folder or file), audit that.
2. Else: audit files where any of these is true:
   - File has no frontmatter at all.
   - File has frontmatter but no `tags:` key.
   - File `mtime` is newer than the last-audit timestamp in `~/raw/.audit/state.json`.
3. Always exclude: `templates/`, `assets/`, `.audit/`, `.obsidian/`, anything under `.git/`.

Run `scripts/audit_candidates.sh [optional-path]` to get the candidate list. Output is one absolute path per line.

If the candidate count exceeds 50, summarise the count to the user and ask whether to proceed (auto mode: proceed but log the count).

### Step 2 — Pass 1: classify (read-only)

For each candidate file:
1. Read the note (frontmatter + body).
2. Determine the **proposed change set** (do NOT write yet):
   - Apply [tag rules](references/tag-rules.md) → list of tags to keep, drop, and propose-new.
   - Apply [property schema](references/property-schema.md) → properties to set/update.
   - Detect [inline-field bullets](references/property-schema.md#inline-field-lifting) to lift into frontmatter.
3. Add each **proposed-new tag** to a vault-wide `new_tag_candidates` map: `{ tag: [file_paths] }`.
4. Persist the per-file change set in memory (or to a temp JSON file if running over many files).

### Step 3 — Tag commit threshold

After Pass 1 finishes, before Pass 2:
- For each entry in `new_tag_candidates`, count occurrences. Any tag with count `< 2` is **rejected** — strip it from every per-file change set.
- Tags with count `>= 2` are accepted as new vault tags.

This is the only place the 2+ rule is enforced. Existing-tag pruning happens per-file in Pass 1.

### Step 4 — Pass 2: apply

For each candidate file, apply its (now-filtered) change set:
1. **Tag changes** — rewrite the `tags:` array in YAML frontmatter directly via `scripts/apply_changes.sh`.
2. **Property changes** — direct file edit on the YAML frontmatter for scalar properties (do not use the Obsidian CLI; it is flaky on path resolution).
3. **Inline-field lifting** — direct file edit: remove the bullet line(s), add the corresponding property to frontmatter.
4. After each file, append a per-file diff entry to the run changelog.

If any file edit fails, log the error in the changelog under a `## Errors` section and continue with the next file.

### Step 5 — Write changelog and update state

- Changelog path: `~/raw/.audit/YYYY-MM-DD-HHMM-audit.md` (format defined in [references/changelog-format.md](references/changelog-format.md)).
- Update `~/raw/.audit/state.json` with:
  ```json
  { "last_audit_iso": "2026-04-29T15:42:00+10:00", "last_audit_changelog": ".audit/2026-04-29-1542-audit.md" }
  ```
- Print to the user: file count, tags created, tags pruned, properties added, errors.

### Step 6 — Tell the user how to revert

Print exactly:

```
Audit applied. To revert everything:
  git -C ~/raw reset --hard HEAD
To revert one file:
  git -C ~/raw checkout HEAD -- <relative-path>
Changelog: <changelog-path>
```

Do NOT auto-commit the audit changes — leave them in the working tree so the user can review and commit themselves.

## Reference files

- [references/tag-rules.md](references/tag-rules.md) — closed-taxonomy default, 2+ rule for new tags, per-file pruning of irrelevant single-occurrence tags.
- [references/property-schema.md](references/property-schema.md) — `type`/`status`/`created`/`updated` inference, inline-field lifting map.
- [references/changelog-format.md](references/changelog-format.md) — exact markdown structure for the run changelog.

## Scripts

- `scripts/audit_candidates.sh [path]` — emit candidate file list (one absolute path per line).
- `scripts/apply_changes.sh <file> <changes-json>` — apply a JSON change set to one file's frontmatter + body. Idempotent.

## Conventions

- Australian spelling in all log/changelog text (organise, behaviour, colour).
- Never touch `templates/`, `assets/`, `.audit/`, or `.obsidian/`.
- Never invent tags that fail the 2+ threshold.
- Never edit a file the user didn't include in scope.
- Always leave changes uncommitted so the user controls the commit.
