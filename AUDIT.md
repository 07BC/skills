# Skills Audit

A running record of audit passes against this skill library. Each dated section captures one audit's findings: which skills changed, what changed, and why. New audits append fresh sections; old sections are not rewritten.

---

## 2026-06-18

Spec-pipeline rebuild. Fixes a silent regression and adds the master-spec layer,
dual review, the traceability spine, and a test-coverage gate. Design and
decisions recorded in [ADR 0014](docs/adr/0014-master-spec-layer-and-in-place-spec-pipeline.md)
and `~/Developer/obsidian/skills/plans/spec-pipeline-rebuild.md`.

### Root-cause regression

Commit `da5fc1c "removing agents"` (2026-05-24) deleted the eight leaf agents
`/spec-pipeline` dispatches by `subagent_type`. The SKILL kept dispatching them,
so since late May every phase ran through a generic fallback agent with no
specialist instructions — the literal cause of "no reviewer" and "weak tests".
All eight were restored verbatim from `da5fc1c^`.

### Changed / new

| Path | Change |
|---|---|
| `agents/{engineer,planner,spec-distiller,test-writer,concurrency-auditor,task-reviewer,swift-spec-review,spec-scope-guardian}.md` | Restored from git. |
| `agents/task-reviewer.md` | Narrowed to the spec-correctness lens (architecture moved out). |
| `agents/quality-reviewer.md` | **New** — architecture/quality lens; runs in parallel with task-reviewer, both must PASS. |
| `agents/test-writer.md` | Emits the `// AC: <id>` mapping convention; every test carries its AC. |
| `agents/drift-auditor.md` | **New** — semantic master↔child drift gate. |
| `agents/spec-scope-guardian.md` | Repurposed: proposes GitHub child specs (`covers`/`depends_on`), not Jira sub-tasks. |
| `agents/spec-distiller.md` | Producer end of the spine: writes `covers:` frontmatter, labels ACs with frozen master IDs, tags each plan task `implements: [...]`. |
| `agents/planner.md` | Validates the spine (every covered AC planned, no creep, test pairing) when the spec carries `covers:`. |
| `skills/engineering/spec-master/SKILL.md` | **New** orchestrator — Jira story → GitHub master issue + native child sub-issues + matrix. |
| `skills/engineering/spec-pipeline/SKILL.md` | In-place (no worktree); `--from-issue`; sequencing gate; drift gate; dual review + test gate; GitHub reconciliation. |
| `skills/engineering/spec-pipeline/scripts/check-traceability.sh` | **New** — child-scope traceability gate. |
| `skills/engineering/spec-pipeline/scripts/coverage-gate.sh` | **New** — changed-line coverage gate (xccov ∩ diff). |
| `skills/engineering/spec-pipeline/scripts/read-pipeline-config.sh` | Added `coverage_floor` default; `github_repo` parses via the generic reader. |
| `SCHEMA.md` | Documented `github_repo`, `coverage_floor`. |
| `docs/adr/0014-*.md` | **New** ADR; partially supersedes ADR 0003 (worktree distinction). |
| `tests/python/test_orchestrator_conformance.py` | Added `/spec-master` to the ORCHESTRATORS list. |
| `README.md` | New `/spec-master` row; updated `/spec-pipeline` and the altitude table. |

### Verification still owed

`coverage-gate.sh` is syntax-clean but unverified against a real `.xcresult` (no
Xcode project in this repo). `check-traceability.sh` smoke-tested green across
pass / scope-creep / exclusion cases. The `gh api graphql addSubIssue` path is
written but not yet exercised against a live repo.

## 2026-05-19

Introduction of `/spec-pipeline` — a top-level orchestrator skill that drives the existing per-domain skills end-to-end (input → spec → plan → per-task implement → whole-diff review → PR). This is the library's first orchestrator-shaped skill. Design rationale, fork-by-fork decisions, and verification plan are recorded in `~/.claude/plans/on-the-plan-before-temporal-starfish.md`.

### New skill

| Path | Purpose |
|---|---|
| `skills/engineering/spec-pipeline/SKILL.md` | Entry point: parses `--from-jira` / `--from-spec` / `--from-prompt`, validates the project's CLAUDE.md `spec_pipeline` YAML block, creates a per-pipeline git worktree, and hands off to the orchestrator agent. `disable-model-invocation: true`. |
| `skills/engineering/spec-pipeline/SCHEMA.md` | Canonical YAML schema reference. Documents required vs optional fields, defaults, vault path resolution, and project .gitignore additions. |
| `skills/engineering/spec-pipeline/scripts/read-pipeline-config.sh` | Parses the fenced `spec_pipeline` YAML block from a project's CLAUDE.md. Emits `SPEC_PIPELINE_*` eval-able variables. Hard-fails on missing required keys. bash 3.2-compatible (macOS default). |
| `skills/engineering/spec-pipeline/scripts/derive-spec-id.sh` | Produces a canonical kebab-case spec ID from `--from-jira KEY <summary>`, `--from-spec PATH`, or `--from-prompt TEXT`. Slugifies, lowercases, truncates to 60 chars. |

### New agents at `agents/`

The four-stage inner loop plus the top-level orchestrator and the whole-diff reviewer.

| File | Role |
|---|---|
| `agents/engineer.md` | Spec-bound implementer for one task. Builds clean before handoff. Stops on ambiguity. |
| `agents/test-writer.md` | Swift Testing only. Targeted-suite run via `mcp__xcode__RunSomeTests` when Xcode is open. AC-mapped tests. |
| `agents/concurrency-auditor.md` | Self-gated. Scans task diff for triggers (`async`, `actor`, `Sendable`, `@MainActor`, `Task`, `AsyncSequence`, `NSLock`, `Mutex`, `DispatchQueue`, `nonisolated`); short-circuits with `PASS-NO-CONCERN` if none. Otherwise applies the `swift-concurrency-expert` checklist. |
| `agents/task-reviewer.md` | Bounded per-task reviewer. One task's diff against one task's spec slice. `VERDICT: PASS \| BLOCKED`. Does NOT do cross-task coherence. |
| `agents/swift-spec-implement.md` | Per-task orchestrator. Drives `engineer → test-writer → concurrency-auditor → task-reviewer`. Commits via `/git-commit` semantics on all-PASS. Max one inner retry per gate. |
| `agents/swift-spec-review.md` | Whole-diff outer gate. Integrative checks (every AC covered, scope cohesion, architecture uniformity in aggregate). `VERDICT: PASS \| BLOCKED`. Cited file+line on every blocker row. |
| `agents/spec-distiller.md` | Converts `(raw_text, spec_id)` → `docs/specs/`, `docs/plans/`, `master-plan.md`. Idempotent. Marks status `🟡 BLOCKED on Open Questions` rather than guessing. |
| `agents/planner.md` | Read-only validator for the distiller's plan. Returns `PLAN VALID` or `PLAN NEEDS AMENDMENT: <reason>`. Never rewrites. |
| `agents/spec-pipeline-orchestrator.md` | Top-level driver. Stages 1–5, 3-cycle review loop, incremental Obsidian audit log, escalation file. Spawns every other agent via the Task tool. |

### Design forks resolved during the grill

Captured at length in the plan file. Summary of the load-bearing decisions:

- **Generalised, not Jira-bound.** `--from-jira` / `--from-spec` / `--from-prompt` adapters. Atlassian MCP gate is in the Jira adapter only, not the skill's `compatibility.tools`.
- **Fenced YAML block inside CLAUDE.md.** Single read surface (matches `swift-test-all` precedent); structured parsing at 10+ keys. No new `.swift-skills.yml` file.
- **Worktree-per-pipeline isolation.** Orchestrator creates `../<repo>-<spec-id>` at Stage 0.5 on a fresh `<type>/<spec-id>` branch. No file locking — physical isolation. User removes the worktree manually post-merge.
- **All pipeline artefacts gitignored.** `docs/specs/`, `docs/plans/`, `master-plan.md` live only in worktrees. The Obsidian audit log at `$OBSIDIAN_VAULT/AI/plans/<spec-id>.md` is the durable record and contains the full spec + full plan verbatim.
- **Cycle budget = 3.** One BLOCKED + two retries before escalation. Configurable per-project via `cycle_budget`.
- **Concurrency-auditor self-gates** on diff triggers — skips itself when no concurrency surface area is touched.
- **Commits reuse `/git-commit`.** No `Verified by:` template. Short imperative + ticket prefix from branch. No AI attribution. Audit trail lives in Obsidian, not git log.

### Repo housekeeping

| Change | Why |
|---|---|
| New README row under "End-to-end pipelines" | First pipeline-shaped skill warrants its own table section. Slotted between "Git workflow" and "Building" because it composes everything below. |

### Skills NOT changed (and why)

- `/git-pr`, `/git-commit`, `/git-push` — Stage 5 invokes `git-pr` rather than duplicating PR creation. Existing `preflight.sh` is reused for ticket-prefix extraction during per-task commits. No edits needed.
- `/swift-engineer`, `/swift-testing`, `/swift-concurrency-expert`, `/swift-code-review` — read by the new inner-loop agents as authoritative skill bodies. The agents reference them by path; the skills themselves are unchanged.
- `/swift-test-all` — Stage 5's full-suite run delegates to the same `xcodebuild test` invocation pattern. Could optionally call this skill directly in a future audit; left inline for now.

### Known follow-ups

- **Deprecation of the legacy orphan agents** (`agents/junior-developer.md`, `senior-developer.md`, `tester.md`) — these live on the `new/regression-skill` branch and are superseded by the new inner-loop agents. They need to move to `skills/deprecated/legacy-agents/` once that branch lands on `main`, with a README mapping old → new. Out of scope for this PR.
- **Wiki page 05 (Skills vs. Agents)** — design-rationale prose for skill-vs-agent decisions, derived from the grill in the plan file. Written locally in the `skills.wiki` repo alongside sidebar/Home.md updates; not pushed yet because GitHub wiki has no PR mechanism — pushing goes live immediately. Will be pushed when this PR merges.
- **Verification** (Phase 8 of the plan) — end-to-end dry-run against a real NAT ticket has not been done yet. Phase 8 items 3–10 require a real Swift project. The verification plan is in `~/.claude/plans/on-the-plan-before-temporal-starfish.md`.

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

**README link mismatch.** `README.md` links four obsidian skills with hyphens
(`/j:obsidian-audit`, `/j:obsidian-learn`, `/j:obsidian-manage`,
`/j:obsidian-rollover`) but each skill's `name:` frontmatter field uses a
colon (`obsidian:audit`, etc.). The actual invocation is `/j:obsidian:audit`.
Pre-existing inconsistency, surfaced by this audit's verification sweep but
not changed. Fix is either (a) rename four README links to use colons, or
(b) rename four skill `name:` fields to use hyphens — each has follow-on
consequences (user muscle memory; cross-skill references) and warrants its
own grilling pass.

### Composability + prose

Three small prose edits to remove cross-skill overlap and a read-only health
check on the one skill that lives outside the README.

| Skill | Change | Rationale |
|---|---|---|
| `engineering/swift-quality` | Added a "Scope boundary" line: this skill **rewrites**, doesn't flag issues; for diagnosis with BLOCKER/WARNING/SUGGESTION severities use `swift-code-review`; for an exhaustive multi-section report use `swift-audit`. | The three skills' descriptions all "look at Swift code and apply rules", so the verb (rewrite vs. flag vs. audit) needs to be explicit in the body. Without this, casual triggers can land on the wrong skill. |
| `engineering/swiftopher-columbus` | Changed the H1 from `# Swift Architect` to `# Swiftopher Columbus`. Added a "Scope boundary" line: this skill **documents** an existing codebase; for scaffolding/MVVM-drift auditing use `swift-architect`. | The previous H1 collided with the actual `swift-architect` skill — silent reader trap when grepping or scanning files. Now the name on the tin matches the name in the frontmatter. |
| `personal/prompt:writer` | Read-only audit. Frontmatter parses; body is 320 lines and well-structured. No edit needed. Directory name carries a colon (`prompt:writer/`) — unusual on macOS but matches the convention already in use for other namespaced skills (`obsidian:audit`, `obsidian:learn`). | Listed in CLAUDE.md as intentionally hidden from `README.md`; sanity-check only. |

### Skills NOT changed (and why)

The audit walked every shipped skill; these were considered and skipped:

- `engineering/swift-engineer` — no high-risk side effect (writes local Swift, easy git revert); no script-eligible deterministic blocks; no shared logic with another skill.
- `engineering/swift-architect` — scaffolds + audits MV adherence. Judgment-heavy throughout; no fixed step that pays for extraction.
- `engineering/swift-audit` — large skill with audit-report scaffolding. The file-discovery block (~5 lines of `find`) was a candidate for extraction in Q4 but the user picked option (ii) "all 9 from the table"; this one wasn't in the table. Left inline.
- `engineering/swift-code-review` — pure judgment work; nothing to extract.
- `engineering/swift-concurrency-expert` — action-shaped concurrency work; no deterministic block.
- `engineering/swift-document` — DocC comment authoring; no fixed step.
- `engineering/swift-test-all` — runs the test suite. Tiny and already deterministic-shaped (one command). No script needed.
- `engineering/swift-testing` — test authoring; nothing to extract.
- `engineering/swift-tvos` — focus-engine diagnosis; judgment work.
- `engineering/swift-uitest` — XCUITest authoring; judgment work.
- `engineering/swiftui-liquid-glass` — Liquid Glass API guidance; judgment work.
- `engineering/swift-cidi` — CI/CD debugging; the deterministic parts (xcresult retrieval) vary too much between project shapes to extract usefully.
- `engineering/xcodebuildmcp-cli` — wrapper for the XcodeBuildMCP CLI; nothing to extract that the CLI itself doesn't already do.
