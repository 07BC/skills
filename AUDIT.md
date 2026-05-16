# Skills Audit

A running record of audit passes against this skill library. Each dated section captures one audit's findings: which skills changed, what changed, and why. New audits append fresh sections; old sections are not rewritten.

---

## 2026-05-16

Three-sweep audit across all 27 shipped skills: visibility flags, deterministic-script extractions, composability/prose fixes. See the `audit/skills-2026-05-16` branch for the change set; this section is the changelog.

### Visibility

Two new YAML frontmatter fields added selectively.

| Skill | Field added | Why |
|---|---|---|
| `git/git-commit` | `disable-model-invocation: true` | Mutates repo state. Must be explicitly user-invoked — no auto-fire from casual mentions of "commit". |
| `git/git-push` | `disable-model-invocation: true` | Pushes to remote. Auto-fire risk includes pushing in-progress work to a shared branch. |
| `git/git-pr` | `disable-model-invocation: true` | Pushes + opens a GitHub PR. Side effect is visible to teammates. |
| `productivity/plan-to-jira` | `disable-model-invocation: true` | Creates Jira issues via the Atlassian MCP. Tickets are visible to the wider team; undo is manual. |
| `engineering/swift-concurrency` | `user-invocable: false` | Pure-reference skill with a `references/` library. Pairs with the action skill `swift-concurrency-expert`. The user has no reason to type `/j:swift-concurrency` — Claude auto-loads it when concurrency questions come up. Hidden from `/menu` to keep that surface focused on action-shaped skills. |

Skills considered but **not** flagged:

- `obsidian-audit`, `daily-notes`, `obsidian-learn`, `obsidian-rollover`, `session-saver` — all mutate the Obsidian vault, but the vault is git-backed, the writes are local-only, and each skill's description already requires explicit user phrasing ("rollover", "run learn", "process my sessions"). Auto-fire risk is annoying-but-recoverable rather than high-risk.
- `swift-engineer`, `swift-testing`, `swift-cidi`, `swift-architect` — knowledge-heavy but action-shaped. Users actually do type these to start work; hiding them from `/menu` would obscure the library.

### Determinism

Nine canonical scripts extracted, plus seven duplicates of two shared
borderlines (locked in the audit grilling as option `(ii) extract everything
including borderlines`). Scripts live **skill-local** at
`skills/<bucket>/<name>/scripts/` — never at repo root — because the plugin
installer (`scripts/link-skills.sh`) only symlinks per-skill directories.
Duplicates carry a `# DUPLICATE — canonical at …` comment pointing to the
authoritative copy.

Every mutating script ships with `--dry-run`. All scripts pass `bash -n` /
`python3 -m py_compile`. Smoke-tested with safe args before commit.

| Script | Skill (canonical) | Duplicates | Replaces |
|---|---|---|---|
| `preflight.sh` | git-commit | — | `git status` + `git diff` + branch-name ticket extraction |
| `find_formatter.sh` | git-push | — | The `.swiftformat`/`.prettierrc`/`rustfmt.toml`/`pyproject.toml` detection table |
| `branch_summary.sh` | git-pr | — | `git log main..HEAD --oneline` + `git diff main...HEAD --stat` |
| `daily_note_path.sh` | obsidian-rollover | obsidian-manage, daily-notes | The `YYYY/MM-MMM/YY-MM-D.md` path-math block (3 copies) |
| `rollover.py` | obsidian-rollover | — | Steps 2–5 of obsidian-rollover (read today, scan 7 days, dedup, insert) |
| `vault_preconditions.sh` | obsidian-audit | obsidian-rollover, daily-notes, obsidian-learn, session-saver | The vault-is-clean-git-repo precondition block (5 copies total). Soft-wired into the 4 writers as an optional preflight; hard-wired into obsidian-audit |
| `kb_append.py` | obsidian-learn | session-saver | KB append-under-date-heading logic. Category→file mapping kept in each SKILL.md prose (the two skills use different maps; the script is map-free) |
| `find_unprocessed_sessions.py` | session-saver | — | Step 1 of session-saver (scan, parse YAML, filter `processed: true`, prefer final saves) |
| `explore.sh` | swiftopher-columbus | — | Phase 1 explore block (top-level shape, package graph, entry point, local packages) |

**SKILL.md edits.** 10 skill bodies updated to reference the new scripts:
git-commit, git-push, git-pr, obsidian-rollover (Steps 1–6 restructured into
Step 0 preflight + Step 1 ensure + Step 2 rollover), obsidian-audit,
daily-notes (2 path-computation blocks + preflight), obsidian-manage (2
path-computation blocks), obsidian-learn (Step 0 preflight + Step 3 KB
write), session-saver (Step 0 preflight + Step 1 finder + Step 3 KB write),
swiftopher-columbus (Phase 1 explore).

**Known pre-existing drift not fixed.** The Obsidian skills disagree on the
vault path: most SKILL.md prose says `$HOME/raw`, `obsidian-learn` says
`~/Developer/obsidian/`, and an existing script in obsidian-audit
hard-codes `/Users/j.lesouef/Developer/obsidian` (note the stale username).
Reality is `$HOME/Developer/obsidian`. New scripts default to `$HOME/raw`
to match the majority SKILL.md prose, but every script accepts a `VAULT` env
override. Fixing the underlying drift is out of scope for this audit.

### Composability + prose

(populated in commit 3)
