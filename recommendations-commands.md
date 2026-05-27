# Recommendations — audit-codebase + uitest-pipeline

> **Status: applied** (with one carve-out). Every BLOCKER, IMPROVEMENT,
> and POLISH below was fixed in a follow-up pass:
>
> - `commands/Mr Will/audit-codebase.md` — full rewrite. Variables
>   block, `PLANS_DIR`-routed outputs, named `Apply skill X`
>   references, `pipeline-preflight` as Phase 0, per-layer Sonnet
>   subagents in Phase 3, `swift-discovery` template for batches in
>   Phase 4, unified BLOCKER/WARNING/SUGGESTION severity end-to-end,
>   `workflow` handoff replacing the dead `ticket-to-pr` reference,
>   two scope modes DRY'd into one parameterised flow.
> - `commands/Mr Will/uitest-pipeline.md` — full rewrite. Emoji
>   removed, shell globs fixed (`*UITests*.swift`, `*.swift`),
>   `pr-preflight` replaced with `swift-pr-gate`, `prompt:review`
>   referenced as a named skill, Atlassian cloud ID sourced from
>   `CLAUDE.md`, MCP Xcode tools preferred over raw `xcodebuild`,
>   `present_files` removed (just save to `PLANS_DIR`), HTML-comment
>   model hints replaced with explicit spawn blocks, PR description
>   delegated to `swift-pr-gate` Gate 5 plus a UI-specific addendum,
>   `pipeline-preflight` as Phase −1.
> - `skills/testing/swift-uitest/SKILL.md` — new "tvOS hard stops"
>   callout in Core Constraints; new "Escalation — when a test is not
>   automatable" section.
> - `skills/testing/swift-uitest-debug/SKILL.md` — new "Escalation
>   ceiling — declare unautomatable" section codifying what happens
>   after Phase 4 (Sonnet fix from Opus diagnosis) fails.
>
> **Carve-out:** `prompt:review` lives at `~/.claude/skills/prompt:review/`
> as a real directory (not a symlink into this repo). Per global
> CLAUDE.md, unmigrated skills must be flagged rather than edited in
> place. The BLOCKER about its sandbox output path
> (`/mnt/user-data/outputs/...`) and the IMPROVEMENT about delegating
> to `swift-code-review` remain open — flag to migrate the skill into
> `skills/engineering/prompt-review/` (or similar) before editing.

Review of two sibling orchestrator commands and their dependent skills:

- `commands/Mr Will/audit-codebase.md`
- `commands/Mr Will/uitest-pipeline.md`

Same severity ladder as the original `recommendations.md`:

- **BLOCKER** — the command does the wrong thing today; ship a fix before
  next run.
- **IMPROVEMENT** — measurable speed, accuracy, or robustness win.
- **POLISH** — coherence / readability; safe to defer.

Each entry: **Where → Problem → Fix → Why it matters.**

---

## 1. Cross-cutting findings

### [BLOCKER] Both commands write outputs inside the repo

- **Where:** `audit-codebase.md` Phase 1, 2, 3, 4, 5, 6 (every artefact
  goes to `docs/audit/[TICKET-KEY]/…` or `docs/audit/full-[YYYY-MM-DD]/…`);
  `uitest-pipeline.md` Phase 1 (`docs/uitest-plan-[slug].md`), Phase 4b
  (`pr-review-[slug].md`), Phase 4c (`pr-description-[slug].md`).
- **Problem:** Global plan-storage rule (`~/.claude/CLAUDE.md`) mandates
  that ALL plans, prompts, post-mortems, and architecture documents live
  in `${HOME}/Developer/obsidian/${PROJECT_NAME}/plans/`, not inside the
  project repo. Both commands violate this rule.
- **Fix:** Define `PLANS_DIR=${HOME}/Developer/obsidian/${PROJECT_NAME}/plans`
  at the top of each command and route every artefact through it.
  `audit-codebase.md` → `${PLANS_DIR}/audit/[TICKET-KEY]/…`;
  `uitest-pipeline.md` → `${PLANS_DIR}/uitest-plan-[slug].md` etc.
- **Why it matters:** Audit outputs and PR-prep docs sitting in the repo
  get accidentally committed (the `docs/working/` ban from `swift-pr-gate`
  exists for exactly this reason). Centralising them in obsidian also
  makes cross-project review possible.

### [BLOCKER] Severity vocabularies don't line up

- **Where:** `audit-codebase.md` Phase 3 uses `blocking|major|minor`;
  `swift-code-review` outputs `BLOCKER|WARNING|SUGGESTION`; Jira priority
  mapping in Phase 5 uses `Critical|High|Medium`.
- **Problem:** Three different vocabularies for the same axis. Findings
  recorded as `major` in the audit doc can't be cross-referenced with
  `swift-code-review` output or a Jira priority filter.
- **Fix:** Use `BLOCKER|WARNING|SUGGESTION` end-to-end (matches the new
  severity mapping in `swift-code-review`). In Phase 5, map
  BLOCKER→Critical, WARNING→High, SUGGESTION→Medium.
- **Why it matters:** Today an auditor records a finding as "major",
  the engineer's PR review flags the same code as "WARNING", and the
  Jira ticket goes in as "High". A simple grep across artefacts won't
  link them.

### [IMPROVEMENT] Neither command runs `pipeline-preflight`

- **Where:** `audit-codebase.md` Phase 1; `uitest-pipeline.md` Phase 0.
- **Problem:** Both can start on a dirty tree, a wrong base branch, or
  with merged-PR drift in the progress doc. `workflow.md` already cites
  `pipeline-preflight` as the canonical first step for any
  orchestrator; these two skipped it.
- **Fix:** Add a "Phase −1: Preflight" to both commands that applies
  `pipeline-preflight` and uses the same Reconcile / Proceed / Abort
  resolution semantics that `workflow.md` now documents.
- **Why it matters:** Audits run on a dirty tree mix the auditor's own
  half-finished work into findings. UI test runs on the wrong base
  branch can't be cleanly PR'd.

### [POLISH] Both commands embed skill paths instead of named skills

- **Where:** `audit-codebase.md` uses `[SKILL:
  ~/.claude/skills/user/swift-architect/SKILL.md]`;
  `uitest-pipeline.md` uses `~/.claude/skills/swift-uitest/SKILL.md`.
- **Problem:** `workflow.md` was migrated to the named pattern
  (`Apply skill swift-engineer`) — these two still use absolute paths,
  which is more fragile and harder for skill renames.
- **Fix:** Replace every `[SKILL: <path>]` with `Apply skill <name>` and
  let the Skill tool resolve.

---

## 2. `audit-codebase.md` findings

### [BLOCKER] All skill paths include a non-existent `user/` segment

- **Where:** `audit-codebase.md:43`, `:74`, `:200`, `:231` —
  `~/.claude/skills/user/swift-architect/SKILL.md` and
  `~/.claude/skills/user/swift-code-review/SKILL.md`.
- **Problem:** `~/.claude/skills/` is a flat directory of symlinks; the
  `user/` segment doesn't exist. Every reference 404s.
- **Fix:** Remove `user/` from every skill path, or migrate to the named
  `Apply skill swift-architect` / `Apply skill swift-code-review` form.
- **Why it matters:** First read fails on every run today. Either the
  orchestrator skips the skill silently (worst case — runs without the
  context the skill provides) or halts.

### [BLOCKER] Handoff points at a command that no longer exists

- **Where:** `audit-codebase.md` lines 9-10 ("companion to `ticket-to-pr`")
  and 315-321 ("Run `ticket-to-pr` for [NAT-XXXX]").
- **Problem:** `ticket-to-pr` was renamed / replaced by `workflow`
  (commands/Mr Will/workflow.md). The audit doc still hands tickets to
  the old name.
- **Fix:** Replace every `ticket-to-pr` reference with `workflow`. Update
  Phase 6 / Handoff sections accordingly.
- **Why it matters:** Anyone following the audit's instructions runs a
  non-existent command and the remediation pipeline halts at handoff.

### [BLOCKER] Phase 3 checklist is hand-rolled, not the canonical `swift-code-review` set

- **Where:** `audit-codebase.md` Phase 3 lines 78-109 (Architecture
  conformance / Swift 6 concurrency / Swift quality / Test coverage /
  Scope creep indicators bullets).
- **Problem:** Duplicates `swift-code-review`'s checklist with subtly
  different wording. Drift between the two will turn audits and PR
  reviews into different verdicts on the same code.
- **Fix:** Phase 3 should `Apply skill swift-code-review` per file and
  consolidate the structured findings. Remove the inline bullet list.
- **Why it matters:** The audit doc and the PR-review skill should agree
  on what "good" looks like. Today they don't.

### [IMPROVEMENT] Phase 3 is pure Opus — no subagents

- **Where:** `audit-codebase.md` Phase 3 (both modes).
- **Problem:** Auditing every Swift file in the codebase pulls every
  file's contents into the orchestrator's context. On a large project
  this is unsustainable — and `swift-code-review` was specifically
  designed to be run by a subagent (see the spawn pattern in the new
  `workflow.md` Phase 7).
- **Fix:** In Phase 3 spawn one Sonnet subagent per layer (Domain
  models → Actors/services → Views → Tests), each applying
  `swift-code-review` and reporting structured findings. Opus
  consolidates the four reports.
- **Why it matters:** Today the audit either succeeds on small projects
  and burns out the context window on large ones, or skips files
  silently. Per-layer subagents protect orchestrator context and parallelise
  the work.

### [IMPROVEMENT] Phase 4 batch definition could reference the discovery-note shape

- **Where:** `audit-codebase.md` Phase 4 batch template lines 141-148.
- **Problem:** The batch block is bespoke (Severity / Depends on / Files
  in scope / Findings addressed / Definition of done). `swift-discovery`
  already defines a discovery-note shape that subsumes most of this; if
  Phase 4 produced one discovery note per batch, the audit would feed
  `workflow.md` directly without translation.
- **Fix:** Phase 4 batches should be written in `swift-discovery`'s
  template (Types in scope / Must NOT touch / Definition of done / etc.)
  so handoff to `workflow.md` is zero-translation.
- **Why it matters:** Right now `workflow.md` would have to re-run
  `swift-discovery` over the same code the auditor already understands.
  Cuts double work.

### [IMPROVEMENT] Phase 5 priority mapping doesn't cover SUGGESTION

- **Where:** `audit-codebase.md` Phase 5 lines 158-161.
- **Problem:** Maps `blocking → Critical`, `major → High`, `minor →
  Medium`. After unifying severities (cross-cutting BLOCKER above),
  SUGGESTION has no mapping.
- **Fix:** Add `SUGGESTION → Low` (or `Lowest` if the project uses
  five-tier Jira priority).
- **Why it matters:** Without this, suggestions either get dropped or
  get over-prioritised as Medium.

### [IMPROVEMENT] Two scope modes duplicate Phase 3-6

- **Where:** `audit-codebase.md` `--scope=ticket` (Phases 1-6) vs
  `--scope=all` (Phases 1-5). The checklist, batch format, and report
  template are identical; the only real difference is the input scope
  and whether Jira subtasks are created.
- **Fix:** Collapse to one phase sequence parameterised by `SCOPE`
  (ticket or all) and `JIRA_INTERACTION` (yes/no). Use one set of phase
  bodies that branch on those two variables.
- **Why it matters:** Today the two modes drift independently. A fix to
  Phase 3 in one mode silently does not propagate to the other.

### [IMPROVEMENT] No `swift-discovery` referenced anywhere

- **Where:** Throughout `audit-codebase.md`.
- **Problem:** Audit findings naturally produce discovery notes (one
  per batch, defining what `workflow.md` should do next). The skill
  `swift-discovery` exists exactly for that, but the audit doc never
  invokes it.
- **Fix:** Phase 4 applies `swift-discovery` once per batch instead of
  inventing a batch template.
- **Why it matters:** See the previous IMPROVEMENT — kills translation
  work at the handoff boundary.

### [POLISH] Phase headings double-mark the model

- **Where:** `audit-codebase.md` every phase heading
  (`### Phase 1 — Orientation (ticket)` followed by
  `#### Opus, plan mode`).
- **Fix:** Single line: `### Phase 1 — Orientation (ticket) — Opus, plan
  mode`, matching `workflow.md`'s pattern.

### [POLISH] Mode flag syntax is inconsistent with `workflow.md` arg style

- **Where:** `audit-codebase.md` line 19-32 (uses `--scope=ticket
  NAT-1234`) vs `workflow.md` (positional arg).
- **Fix:** Either align both to flag-style (`/workflow --ticket NAT-1234`)
  or both to positional. Right now they diverge.

---

## 3. `uitest-pipeline.md` findings

### [BLOCKER] `pr-preflight` skill is referenced but doesn't exist

- **Where:** `uitest-pipeline.md` Phase 4a line 195.
- **Problem:** `~/.claude/skills/pr-preflight/SKILL.md` is not present
  in the skill library. The Phase 4a read fails on every run.
- **Fix:** Replace `pr-preflight` with `swift-pr-gate` (which exists
  and runs the same gate checks). Adjust the Phase 4a body to match
  `swift-pr-gate`'s six-gate structure.
- **Why it matters:** Phase 4a fails immediately — every UI-test PR
  from this command bypasses preflight or halts.

### [BLOCKER] Shell glob patterns are destroyed by markdown rendering

- **Where:** `uitest-pipeline.md` line 19
  (`find . -path "_UITests_.swift" | sort`) and line 110
  (`grep -rn ... --include="_.swift" .`).
- **Problem:** The original asterisks (`*UITests*.swift`, `*.swift`)
  were eaten by markdown emphasis. As written, the commands match
  files literally named `_UITests_.swift` and `_.swift` — zero
  matches in any real project.
- **Fix:** Wrap every shell pattern in inline code (already done for
  some lines, missed for these), or escape the asterisks. Final form:
  ``find . -name '*UITests*.swift' | sort`` and
  ``grep -rn 'accessibilityIdentifier\|accessibilityLabel' --include='*.swift' .``.
- **Why it matters:** The subagent dutifully runs the rendered command,
  finds nothing, and either invents identifiers or skips Phase 1
  research.

### [BLOCKER] `prompt:review` referenced as a subcommand of a non-existent `prompt` skill

- **Where:** `uitest-pipeline.md` Phase 4b line 214 — *"Read
  ~/.claude/skills/prompt/SKILL.md, subcommand prompt:review"*.
- **Problem:** `prompt:review` is a top-level skill in its own right
  (`~/.claude/skills/prompt:review/SKILL.md`), not a subcommand of a
  `prompt` skill (which doesn't exist). The path is wrong and the
  "subcommand" framing is wrong.
- **Fix:** Replace with `Apply skill prompt:review`.
- **Why it matters:** Phase 4b read fails; the review prompt either
  isn't generated or generated from memory.

### [BLOCKER] Hardcoded Atlassian cloud ID

- **Where:** `uitest-pipeline.md` Phase 0 line 45 —
  `cloud ID 6e66531e-dc70-4caa-93ad-a2524854ff4f`.
- **Problem:** Embeds one project's Atlassian instance ID in a shared
  command. Anyone running this command against a different Atlassian
  cloud has it silently misroute.
- **Fix:** Read the cloud ID from a `pipeline` config block in
  `CLAUDE.md` (the same block `pipeline-preflight` now uses), or
  resolve it once via `mcp__claude_ai_Atlassian__getAccessibleAtlassianResources`
  and cache.
- **Why it matters:** Tomorrow's user on a different project gets
  wrong tickets fetched and doesn't realise.

### [BLOCKER] Emoji extensively used despite global "No emojis" rule

- **Where:** `uitest-pipeline.md` Phase 0 lines 55-58, 63-66 (Automatable
  classification with `✅`, `⚠️`, `❌`); Phase 0 line 71 ("Mark Phase 0 ✓");
  the gate summary `[ ]` table; Phase 4c AC coverage table with `✅
  Covered`.
- **Problem:** `~/.claude/CLAUDE.md` global rules: *"No emojis"* in
  GitHub commit messages and (by extension and convention) skill /
  command output. Personal preference is explicit.
- **Fix:** Replace `✅` → `auto`, `⚠️` → `partial`, `❌` → `manual`, `✓`
  → `done` (or just `x` in the gate checkbox). Phase 4c AC table:
  `auto` / `partial` / `manual` column values.
- **Why it matters:** Every uitest PR description today carries
  emoji that violate the user's own explicit rule.

### [IMPROVEMENT] No `pipeline-preflight` step

- **Where:** `uitest-pipeline.md` Phase 0.
- **Problem:** UI tests can be written and run on a dirty tree, on the
  wrong branch, or against a story that the progress doc flags as
  out-of-scope.
- **Fix:** Add Phase −1 that applies `pipeline-preflight` with the same
  Reconcile / Proceed / Abort resolution semantics as `workflow.md`.

### [IMPROVEMENT] Raw `xcodebuild` instead of `xcodebuildmcp-cli` / MCP Xcode tools

- **Where:** `uitest-pipeline.md` Phase 2 line 162 ("Find the correct
  xcodebuild invocation in CLAUDE.md").
- **Problem:** `swift-uitest` itself prefers `xcodebuildmcp-cli` per its
  own SKILL.md, and MCP Xcode tools (`mcp__xcode__BuildProject`,
  `mcp__xcode__RunSomeTests`) exist for the same purpose. Raw
  `xcodebuild` is slower and produces noisier logs that the
  orchestrator must read.
- **Fix:** In Phase 2 step 7, prefer the MCP tools (via `ToolSearch`)
  with raw `xcodebuild` as the documented fall-back when Xcode is not
  open. Mirror `swift-uitest`'s own preference.

### [IMPROVEMENT] PR-description template diverges from `swift-pr-gate` Gate 5

- **Where:** `uitest-pipeline.md` Phase 4c lines 237-265 vs
  `swift-pr-gate` Gate 5.
- **Problem:** Two PR-description templates for the same artefact. UI
  test PRs use the uitest template; non-UI-test PRs use the gate
  template. Reviewers see inconsistent shapes.
- **Fix:** Phase 4c delegates to `swift-pr-gate` Gate 5 and supplements
  with UI-test-specific fields (AC coverage table) as a Gate 5 addendum.

### [IMPROVEMENT] Phase mode hints are HTML comments

- **Where:** `uitest-pipeline.md` Phase 1 line 77
  (`<!-- Opus, plan mode -->`), Phase 2 line 121
  (`<!-- Sonnet, normal mode -->`), Phase 3 line 174.
- **Problem:** `workflow.md` uses explicit spawn blocks; uitest-pipeline
  uses HTML comments that don't appear in rendered output. The
  orchestrator can't be sure which model to spawn.
- **Fix:** Replace HTML comments with explicit `### Phase N — Title —
  Sonnet, normal mode` headings matching `workflow.md`.

### [IMPROVEMENT] `present_files` tool referenced but doesn't exist

- **Where:** `uitest-pipeline.md` Phase 4b line 223, Phase 4c line 230.
- **Problem:** `present_files` isn't in Claude Code's tool list. The
  instruction "present via the present_files tool" is unactionable.
- **Fix:** Just save the file to `${PLANS_DIR}` and report the path to
  the user.

### [IMPROVEMENT] Phase 0 classification has no escalation if too many `manual` items

- **Where:** `uitest-pipeline.md` Phase 0 lines 68-70 ("if more than
  half the items are ❌, stop and explain why XCUITest is the wrong
  tool").
- **Problem:** The threshold is binary (half = stop). No middle path
  for "mostly automatable but with caveats". And there's no record of
  the decision in the discovery note.
- **Fix:** Always record the auto/partial/manual count in the discovery
  note. If `manual > auto + partial`, halt and surface; otherwise
  continue with a "manual coverage" addendum to the PR plan.

### [IMPROVEMENT] No `pipeline-preflight` parity in Phase 4a

- **Where:** Phase 4a should be the second preflight (the PR gate).
- **Fix:** Already covered by the BLOCKER swapping in `swift-pr-gate`
  for the missing `pr-preflight`.

### [POLISH] Gate summary has phase labels that don't match the rest of the doc

- **Where:** `uitest-pipeline.md` lines 28-34 (gate summary uses
  `Phase 4a — Preflight` etc.) but earlier and later prose just says
  "Phase 4 PR artefacts".
- **Fix:** Pick one. The 4a/4b/4c granularity is useful — adopt it
  everywhere.

### [POLISH] Page Object file path inconsistency

- **Where:** Both `uitest-pipeline.md` and `swift-uitest` reference
  `swift-uitest/references/accessibility-ids.md` and
  `swift-uitest/references/page-objects.md` as relative paths.
- **Fix:** Use absolute path or named-skill reference
  (`Apply skill swift-uitest then read references/accessibility-ids.md`).

---

## 4. Per-skill recommendations

### `swift-uitest`

- **[IMPROVEMENT] No halt / unautomatable escalation defined.** The
  skill describes how to *write* UI tests but doesn't say what to do
  when a test cannot be authored at all (e.g. an OS dialog with no
  accessibility surface, an in-app purchase sheet). Add an explicit
  "escalate to manual test plan" path mirroring `swift-testing`'s
  "surface as BLOCKER" pattern.
- **[IMPROVEMENT] tvOS gotchas buried in narrative.** Focus binding,
  `opacity: 0` removing tree children, `.searchable()` not producing a
  searchField — these are hard rules that belong in a "tvOS hard
  stops" section near the top, not as paragraphs in the body.
- **[POLISH] References folder lives in the skill dir, not in
  `${PLANS_DIR}`.** Project-specific identifier and Page Object lists
  arguably belong outside the skill (each project has its own); keep
  the skill's references as templates and let projects override.

### `swift-uitest-debug`

- **[IMPROVEMENT] No explicit "declare test unautomatable" rule after
  Opus diagnosis.** Phase 3 of `uitest-pipeline.md` mentions this but
  the skill itself doesn't. Codify: *"if Phase 3 (Opus diagnosis) plus
  Phase 4 (Sonnet fix from diagnosis) still fails, the test is
  declared unautomatable — replace with a manual test step in the PR
  description and Jira ticket. Do not weaken the test or remove
  assertions."*
- **[POLISH] Triage categories are clean but not numbered consistently.**
  Six categories in Phase 0 — wrap them in a single table with severity
  and bypass-Sonnet flag.

### `prompt:review`

- **[BLOCKER] Output path looks like a sandbox path.** Skill saves to
  `/mnt/user-data/outputs/pr-review-...md` — this is a Claude sandbox
  convention that doesn't exist on the user's machine. Save to
  `${PLANS_DIR}/pr-review-[slug].md` instead.
- **[IMPROVEMENT] Reconcile with `swift-code-review`.** Both encode the
  same checklist (architecture, concurrency, scope, tests). Move the
  canonical checklist into `swift-code-review` and have `prompt:review`
  *generate a prompt that says "apply swift-code-review"*. Drift between
  the two is otherwise inevitable.
- **[POLISH] `present_files` tool referenced** — same as
  `uitest-pipeline.md`. The tool doesn't exist; just save the file and
  report the path.

### `swift-architect` (delta from original review)

- **[IMPROVEMENT] Audit mode (Mode 2) is now reachable from
  `audit-codebase.md` Phase 1.** Worth adding a one-line note in the
  skill that "audit-codebase invokes Mode 2 with per-ticket scope" so
  the skill author knows the calling pattern.

### `swift-code-review` (delta from original review)

- **[IMPROVEMENT] `audit-codebase.md` Phase 3 should call this skill
  instead of duplicating the checklist.** Already flagged above as a
  BLOCKER on the audit-codebase side; no change to the skill itself
  needed.

---

## 5. Top 10 fixes ranked by impact

If only ten changes ship, these in this order:

1. **`audit-codebase.md` skill paths — remove `user/` segment.**
   (BLOCKER — every run fails the first read today.)
2. **`uitest-pipeline.md` — swap `pr-preflight` for `swift-pr-gate`.**
   (BLOCKER — Phase 4a fails on every run.)
3. **`uitest-pipeline.md` — fix the destroyed shell glob patterns.**
   (BLOCKER — Phase 0 / Phase 1 discovery returns empty results.)
4. **Both commands — route every artefact through `${PLANS_DIR}`.**
   (BLOCKER cross-cutting — repo plan-storage violation.)
5. **`audit-codebase.md` — update `ticket-to-pr` to `workflow`.**
   (BLOCKER — handoff command doesn't exist.)
6. **`uitest-pipeline.md` — remove emoji per global rule.**
   (BLOCKER cross-cutting — explicit user rule.)
7. **Unify severity vocabulary to BLOCKER / WARNING / SUGGESTION
   end-to-end.** (BLOCKER cross-cutting — three vocabularies today.)
8. **`audit-codebase.md` Phase 3 — apply `swift-code-review` instead
   of the inline checklist.** (IMPROVEMENT — eliminates checklist
   drift.)
9. **Both commands — add a Phase −1 that applies `pipeline-preflight`.**
   (IMPROVEMENT — catches dirty tree / wrong base before work begins.)
10. **`uitest-pipeline.md` — replace HTML-comment model hints with
    explicit Sonnet spawn blocks (matching `workflow.md`).**
    (IMPROVEMENT — orchestrator can't tell today which model is
    intended.)

---

## What this review did NOT touch

- The actual content of UI tests produced by `swift-uitest` (the skill
  is hands-on; that's a separate review).
- Whether `xcodebuildmcp-cli` is the right canonical build tool — left
  as the skill's own decision.
- Any change to `workflow.md` or the skills covered in the original
  `recommendations.md` — those are tracked separately.
