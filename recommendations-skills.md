# Recommendations — full skills audit

> **Status: applied.** Every BLOCKER, IMPROVEMENT, and POLISH below
> was fixed in a follow-up pass. The four carve-outs resolved as:
>
> - `swift-document` reframed as **opt-in only**, with an explicit
>   guard at the top that other skills (including `swift-engineer`
>   and `swift-code-review`) never trigger it.
> - Category lists unified: `obsidian-learn`'s 9 categories
>   (`style`, `architecture`, `prohibitions`, `bugs`, `prompting`,
>   `tooling`, `patterns`, `research`, `git`) are now the canonical
>   set. `session-saver` was updated to write to the same filenames.
> - `grill-with-docs` now applies `grill-me` for the interview logic
>   and only layers documentation updates on top — no more
>   duplicated interview prose.
> - `daily-notes` **fully migrated to Claude Code**: the Claude.ai
>   `recent_chats` / `conversation_search` dependency was removed.
>   The skill now runs on `git log`, file timestamps, and Jira via
>   the Atlassian MCP with the cloud ID sourced from `CLAUDE.md`.
>
> One audit finding was **a false positive**: the "unbundled
> reference files" BLOCKER class. On verification all referenced
> files exist alongside their skills:
> `swift-concurrency-expert/references/` (3 `.md` files),
> `swiftopher-columbus/scripts/` (7 `.sh` files),
> `swift-lint/scripts/run-lint.sh`, and `obsidian-audit/references/`
> + `obsidian-audit/scripts/`. No fix needed there.
>
> Two recommendations were dropped after closer reading:
> `git-commit`'s "duplicate full-stops rule" (the rule is stated
> once; the audit was wrong) and `spec-pipeline`'s
> Phase/Stage-rename (~50 occurrences of "Stage" through the skill;
> the rewrite-risk outweighs the cross-skill consistency win — left
> as a noted POLISH).

> **Scope:** every SKILL.md under `skills/` (45 skills, 7 buckets).
> **New audits in this doc:** 31 skills.
> **Linked, not re-examined:** 14 skills already covered in earlier
> audits — see `recommendations.md` (workflow.md + 9 dependent skills)
> and `recommendations-commands.md` (audit-codebase, uitest-pipeline,
> swift-uitest, swift-uitest-debug, prompt:review).
>
> Same severity ladder as prior audits: **BLOCKER** (broken today) /
> **IMPROVEMENT** (speed / accuracy / robustness win) / **POLISH**
> (coherence). Every finding cites a `skill-name:section` and proposes
> a one-line fix.

---

## 1. Cross-cutting findings

These patterns repeat across many skills. Fix once at the cross-cutting
level and the per-skill entries get smaller.

### [BLOCKER] Emoji in skill bodies and generated output

- **Where:** `grill-with-docs`, `swift-style`, `swift-mv-guardian`,
  `swiftui-liquid-glass`, `story-to-spec` (status frontmatter),
  `daily-notes`, `regression-check` (severity labels in output
  template), `jira-bulk` (summary report).
- **Problem:** Global `~/.claude/CLAUDE.md` is explicit: *"No emojis."*
  Skill bodies and the templates they produce both violate this.
  Earlier audits caught the same pattern in `uitest-pipeline.md`.
- **Fix:** Sweep each named skill: replace `auto`/`partial`/`manual`
  for classification, plain text labels (`BLOCKER`, `WARNING`,
  `SUGGESTION`) for severity, `ready`/`blocked` for status, `OK`/`FAIL`
  for results.
- **Why it matters:** Every PR description and daily note generated
  from these skills carries emoji that the user has explicitly opted
  out of. Reviewers see the same violation every time.

### [BLOCKER] Skills reference files / scripts not verified to exist

- **Where:** `swift-concurrency-expert` (`references/swift-6-2-concurrency.md`
  et al), `swiftopher-columbus` (`scripts/explore.sh`,
  `pattern-inventory.sh`, ~6 others), `swift-lint`
  (`scripts/run-lint.sh`), `obsidian-audit` (`references/tag-rules.md`,
  `property-schema.md`, `changelog-format.md`).
- **Problem:** Each skill assumes a bundled file or script exists.
  None of these are confirmed in the repo. If absent, the skill halts
  silently or produces empty output.
- **Fix:** Either bundle the files alongside the SKILL.md (and
  reference them as siblings), or add an inline fallback: *"If the
  script is not found, run the equivalent shell commands below."*
- **Why it matters:** A skill that depends on an unbundled artefact
  fails on first install. Every fresh checkout breaks the same way.

### [BLOCKER] Atlassian cloud ID hardcoded

- **Where:** `daily-notes:196` — `cloudId: "6e66531e-dc70-4caa-93ad-a2524854ff4f"`.
  Same pattern previously caught in `uitest-pipeline.md` Phase 0 (now
  fixed).
- **Problem:** Embeds one project's Atlassian instance ID in a shared
  skill. Anyone running this skill against a different cloud silently
  fetches wrong tickets.
- **Fix:** Source the cloud ID from `CLAUDE.md` (`jira:` config block),
  or resolve once via
  `mcp__claude_ai_Atlassian__getAccessibleAtlassianResources` and cache.
  `jira-bulk` and `plan-to-jira` already do this correctly — copy the
  pattern.
- **Why it matters:** The skill is functionally single-project today
  even though the description implies portability.

### [BLOCKER] `present_files` tool referenced but doesn't exist

- **Where:** `daily-notes:152`, `prompt:writer` (and previously in
  `uitest-pipeline.md` / `prompt:review`, both fixed).
- **Problem:** `present_files` isn't in Claude Code's tool list.
  Steps that invoke it fail.
- **Fix:** Replace with: *"Save the file and report the absolute path
  to the user."*

### [BLOCKER] Skill name in frontmatter vs directory name

- **Where:** all four `obsidian/` skills (`obsidian-audit` directory
  vs `obsidian:audit` name in frontmatter, same for `learn`, `manage`,
  `rollover`).
- **Problem:** Per the global skill-loading convention (`make link`
  uses directory names; `~/.claude/skills/<dir>` becomes the symlink
  name), but invocation by users typically uses the frontmatter name
  (`obsidian:audit`).
- **Status:** Not a defect — the colon-namespacing is intentional. The
  symlink is created against the directory name; the frontmatter
  declares the invocable name. Both addressable.
- **Fix:** Document the convention once at the top of each affected
  skill or in `CLAUDE.md`: *"Obsidian skills use `obsidian:<verb>`
  invocation; the on-disk directory uses hyphenated form."*
- **Why it matters:** Today an author migrating one of these skills
  could "fix" the apparent mismatch by renaming and break invocation.

### [IMPROVEMENT] Plan-storage rule violated by `story-to-spec`

- **Where:** `story-to-spec:130-131` — writes specs to
  `${project_root}/docs/specs/`.
- **Problem:** Global plan-storage rule (`~/.claude/CLAUDE.md`) mandates
  `${HOME}/Developer/obsidian/<project>/plans/` for plans, specs,
  post-mortems. Spec storage in the repo got it scoped wrong.
- **Fix:** Route the authoritative copy to
  `${HOME}/Developer/obsidian/${PROJECT_NAME}/plans/specs/`. Keep
  `docs/specs/` as an optional secondary copy if the project needs
  in-repo specs.

### [IMPROVEMENT] Severity vocabulary still drifts

- **Where:** `regression-check` uses `🔴 BLOCKER / 🟡 RISK / 🟢
  NICE-TO-CHECK / ✅ Cleared` (emoji aside, the `RISK` /
  `NICE-TO-CHECK` labels diverge from the now-canonical
  `BLOCKER / WARNING / SUGGESTION` from `swift-code-review`).
- **Problem:** Three audits, three vocabularies — same axis. Same
  finding as audit-codebase had with `blocking|major|minor`.
- **Fix:** Adopt `BLOCKER / WARNING / SUGGESTION` everywhere. Map
  `RISK → WARNING`, `NICE-TO-CHECK → SUGGESTION`.

### [IMPROVEMENT] Raw `xcodebuild` invocations should prefer MCP / `xcodebuildmcp-cli`

- **Where:** Most `swift-*` skills still describe `xcodebuild`
  invocations directly. `xcodebuildmcp-cli` exists as the canonical
  CLI alias, and the MCP Xcode tools (`mcp__xcode__BuildProject`,
  `mcp__xcode__RunSomeTests`, `mcp__xcode__XcodeListNavigatorIssues`)
  are faster + structured.
- **Fix:** Each skill that runs build/test should prefer MCP tools when
  Xcode is open, fall back to `xcodebuildmcp-cli`, then raw
  `xcodebuild`. The new `workflow.md` and `swift-pr-gate` already do
  this; replicate the pattern in the rest.

### [IMPROVEMENT] Skill paths sometimes appear as paths rather than names

- **Where:** Scattered in `swift-cidi`, `swiftopher-columbus`,
  `swift-tvos` examples — references to other skills as
  `~/.claude/skills/<name>/SKILL.md` instead of `Apply skill <name>`.
- **Problem:** Same finding-class as audit-codebase and uitest-pipeline.
  Path references fail when symlinks move; named references are stable.
- **Fix:** Sweep each skill, replace path-style with named-style.

---

## 2. Cross-skill drift

Pairs of skills whose rules contradict each other or whose internal
state has fallen out of sync. These are the same shape as the
`swift-engineer` vs `swift-code-review` `///` contradiction caught in
`recommendations.md`.

### [BLOCKER] `swift-document` mandates `///`; `swift-engineer` forbids it

- **Where:** `swift-document` description claims it *"Adds or updates
  Apple DocC-style `///` documentation comments"*; `swift-engineer`
  Core Principle #1 forbids `///`.
- **Fix:** `swift-document` should be reframed as *"explicit
  user-invoked only — default is no `///`"*. Add a guard at the top:
  *"This skill is opt-in. Default Swift authoring forbids `///` per
  `swift-engineer`. Only run when the user explicitly asks for DocC
  docs."*
- **Why it matters:** A user who triggers `swift-document` ad-hoc gets
  `///` everywhere; the next `swift-code-review` pass flags the same
  comments as violations. Infinite loop unless the skill is
  framed as a deliberate exception.

### [BLOCKER] `swift-style` requires `///`; `swift-engineer` forbids it

- **Where:** `swift-style:235` — *"All public and internal
  protocol-satisfying methods require `///` documentation."*
- **Problem:** Same contradiction as `swift-code-review` had before
  it was fixed earlier today. `swift-style` is a dependency of
  `swift-engineer`; the contradiction is structurally guaranteed.
- **Fix:** Remove the `///` requirement from `swift-style`. Replace
  with the same "no `///`, comments only for non-obvious WHY"
  language now used in `swift-engineer` and `swift-code-review`.

### [BLOCKER] `session-saver` vs `obsidian-learn` write to different category files

- **Where:** `session-saver:89-97` writes
  `swift-architecture.md`, `swift-prohibitions.md`, `swift-bugs.md`,
  `prompting-patterns.md`, `swift-style.md`. `obsidian-learn` writes
  `architecture.md`, `prohibitions.md`, `bugs.md`, `prompting.md`,
  `swift-style.md`.
- **Problem:** Two skills, one shared knowledge base, two different
  filename conventions. Entries from the same session end up in
  different files depending on which skill processes them.
- **Fix:** Pick one convention. Drop the `swift-` prefix in
  `session-saver` to match `obsidian-learn` (the knowledge base is
  iOS/Swift-centric anyway; the prefix is redundant).

### [IMPROVEMENT] `obsidian-learn` defines 9 categories; `session-saver` defines 5

- **Where:** `obsidian-learn` documents `style, architecture,
  prohibitions, bugs, prompting, tooling, patterns, research, git`.
  `session-saver` documents `architecture, prohibitions, bugs,
  prompting, style`.
- **Problem:** Same root cause as the filename drift — drift between
  consumer and producer.
- **Fix:** Align category lists. Either `session-saver` extracts all
  9, or `obsidian-learn` shrinks to 5. The user can pick; default
  recommendation is keep 9 (richer signal).

### [IMPROVEMENT] `grill-me` and `grill-with-docs` overlap heavily

- **Where:** Both skills.
- **Problem:** Both interview the user about a plan. `grill-with-docs`
  adds inline documentation updates as a side-effect. The interview
  logic is duplicated.
- **Fix:** Make `grill-with-docs` *call* `grill-me` ("Apply skill
  `grill-me` first; then update the documentation files listed in
  Step X"), so the interview logic lives in one place.

---

## 3. Per-bucket findings

Already-audited skills get a one-line pointer at the top of each
sub-section. New audits follow.

---

### 3.1 Engineering bucket

**Already audited (see `recommendations.md`):**
- `swift-architect`, `swift-engineer`, `swift-quality`,
  `swift-concurrency`, `swift-testing`, `swift-code-review`,
  `swift-pr-gate`, `swift-discovery`.

#### `grill-me`

- **[POLISH] Body is ~12 lines.** Effectively a stub. Not a defect
  given the skill is a thin prompt-shape, but worth flagging that any
  drift between `grill-me` and `grill-with-docs` is now hard to spot
  because there's so little surface area.
- **Fix:** Inline the questions / decision tree the skill uses at runtime
  so authors can read the contract without running it.

#### `grill-with-docs`

- **[BLOCKER] Emoji** — see cross-cutting BLOCKER.
- **[IMPROVEMENT] Duplicates `grill-me`** — see cross-skill drift.

#### `spec-pipeline`

- **[IMPROVEMENT] Step 1.5 asks the user to invoke `swiftopher-columbus`**
  but doesn't resolve it as a skill.
  - **Fix:** Replace manual instruction with a programmatic spawn:
    *"Apply skill `swiftopher-columbus` to generate the architecture
    doc, then re-enter Phase 1."*
- **[POLISH] Mixes "Phase" and "Stage" interchangeably** — pick one
  (recommend "Phase" to match `workflow.md`).

#### `story-to-spec`

- **[IMPROVEMENT] Plan-storage violation** — see cross-cutting.
- **[BLOCKER] Emoji in frontmatter status** (`status: 🟢 Ready` / `🟡
  BLOCKED`) — see cross-cutting.

#### `swift-cidi`

- **[IMPROVEMENT] Hardcodes scheme names (`Chagi`, `kick-apple-public`)
  in examples.** Readers may copy-paste.
  - **Fix:** Use `$SCHEME` placeholder throughout examples; define
    once at the top.

#### `swift-concurrency-expert`

- **[BLOCKER] References unverified `references/*.md` files** — see
  cross-cutting.

#### `swift-document`

- **[BLOCKER] Mandates `///`; contradicts `swift-engineer`** — see
  cross-skill drift.

#### `swift-lint`

- **[BLOCKER] References `scripts/run-lint.sh` without confirming it
  exists or providing a fallback** — see cross-cutting.

#### `swift-mv-guardian`

- **[BLOCKER] Emoji** — see cross-cutting.
- **[IMPROVEMENT] Mode 1 has no escape if iOS 17+ deployment can't be
  reached.** Tells the user to bump the target; doesn't say what to do
  if they can't.
  - **Fix:** Add: *"If the deployment target cannot be bumped, MV
    (which requires `@Observable`) is not viable. Use MVVM or
    `ObservableObject` instead. Hand off to `swift-architect` for an
    MVVM audit."*

#### `swift-style`

- **[BLOCKER] Mandates `///`; contradicts `swift-engineer`** — see
  cross-skill drift.
- **[BLOCKER] Emoji** — see cross-cutting.
- **[POLISH] 100-char column limit declared but not cross-referenced
  with `swift-engineer` or project `.swiftlint.yml`.**
  - **Fix:** Note: *"Align this with `.swiftlint.yml` if present;
    otherwise 100 is the default."*

#### `swift-tvos`

- **[IMPROVEMENT] Step 0 asks "when did it last work?" without defining
  "working".** Did focus move? Did the whole navigation flow
  complete? Ambiguous.
  - **Fix:** Tighten the question: *"Define 'working': did focus move
    to the expected element on the expected screen, AND did
    subsequent navigation steps complete successfully? Bug reports
    that can't answer both halves are not actionable."*

#### `swiftopher-columbus`

- **[BLOCKER] References ~6 `scripts/*.sh` files unverified to exist**
  — see cross-cutting.

#### `swiftui-liquid-glass`

- **[BLOCKER] Emoji** — see cross-cutting.
- **[IMPROVEMENT] Context7 URI is non-standard syntax.** Reads as
  unclear: *"/websites/developer_apple_swiftui — query via
  `mcp__context7__query-docs`"*.
  - **Fix:** Simplify: *"Query Context7 for `/websites/developer_apple_swiftui`
    when you need an API detail beyond what this skill encodes."*

#### `xcodebuildmcp-cli`

- **[POLISH]** No findings — this skill is the canonical wrapper and
  reads cleanly. Other skills should reference it more.

---

### 3.2 Testing bucket

**Already audited (see `recommendations.md` / `recommendations-commands.md`):**
- `swift-quality`, `swift-testing`, `swift-uitest`, `swift-uitest-debug`,
  `swift-test-all`.

#### `regression-check`

- **[BLOCKER] Severity emoji in output template** (`🔴 BLOCKER /
  🟡 RISK / 🟢 NICE-TO-CHECK / ✅ Cleared`) — see cross-cutting.
- **[IMPROVEMENT] Severity vocab drift** (`RISK`, `NICE-TO-CHECK`) —
  see cross-cutting.
- **[IMPROVEMENT] Step 3 ("Behavioural ripples") is the skill's flagship
  contribution but is narrative prose with no concrete algorithm.**
  - **Fix:** Add a checklist: *"For each changed file, search for: KVO
    observers, Combine sinks, NotificationCenter posts, scenePhase
    handlers, lifecycle methods, shared state (singletons,
    `@AppStorage`), SwiftUI state (`@State`, `@Environment`)."*
- **[IMPROVEMENT] Step 4 concurrency audit lacks a checklist** despite
  warning *"never commit on SourceKit alone"*.
  - **Fix:** Reference `swift-concurrency-expert` and list the actual
    checks to run (thread checker, navigator issues, race tests).

---

### 3.3 Git bucket

#### `git-commit`

- **[POLISH] "no full stops" rule restated redundantly** — once is
  enough.
- **[IMPROVEMENT] Depends on `scripts/preflight.sh` but doesn't say
  where the script lives.**
  - **Fix:** Add: *"Your repository must have a `scripts/preflight.sh`.
    If absent, manually run `git status`, `git diff`, and extract the
    ticket from the branch name."*

#### `git-pr`

- **[IMPROVEMENT] No timeout or halt for long-running tests.**
  - **Fix:** *"If tests do not complete within 5 minutes, terminate
    and report the timeout. Do not raise the PR."*
- **[IMPROVEMENT] BLOCKER mapping unclear** — what blocks PR creation
  vs what's OK to ship with?
  - **Fix:** *"BLOCKER findings from `swift-code-review` must be fixed
    before PR creation. WARNING and SUGGESTION findings can ship with
    the PR but should appear in the description's review-summary
    section."*
- **[IMPROVEMENT] Undefined test target for Swift projects.**
  - **Fix:** Source from `CLAUDE.md`'s `TEST_TARGET` (the same value
    `workflow.md` now derives in Phase 1).

#### `git-push`

- **[IMPROVEMENT] Formatter binary missing — "note it and continue"
  is vague.**
  - **Fix:** *"Print: 'Formatter `<name>` not installed; skipping
    format step. Install with `<command>` to reformat on future pushes.'"*
- **[IMPROVEMENT] Ambiguous upstream-mismatch handling.**
  - **Fix:** *"If the upstream remote is not `origin`, halt and ask
    the user which remote to push to. Don't silently push to `origin`."*

---

### 3.4 Obsidian bucket

#### `daily-notes`

- **[BLOCKER] `present_files` referenced but doesn't exist** — see
  cross-cutting.
- **[BLOCKER] Hardcoded Atlassian cloud ID** — see cross-cutting.
- **[BLOCKER] Claude.ai vs Claude Code path ambiguity.** Workflow
  calls `recent_chats()` / `conversation_search()` which are
  Claude.ai-only. The skill is invocable from Claude Code.
  - **Fix:** Add a preflight: *"This skill requires Claude.ai
    conversation tools. If running under Claude Code, skip directly
    to the git-commits / Jira / file-changes inputs and report that
    conversation data is unavailable."*
- **[IMPROVEMENT] Voice/style rules drift between Step 5 and quality
  checklist.**
  - **Fix:** Consolidate the prohibitions list once: *"Never include
    'prompt', 'AI', 'Claude Code', 'wrote a skill'. Always include
    concrete file names, methods, root causes."*

#### `obsidian-audit`

- **[BLOCKER] References `references/tag-rules.md`,
  `property-schema.md`, `changelog-format.md` — unverified** — see
  cross-cutting.
- **[IMPROVEMENT] "2+ rule" enforcement is split across two passes,
  which reads as a contradiction.**
  - **Fix:** Clarify the order: *"Pass 1 reads every file and proposes
    tag changes. Step 3 runs AFTER Pass 1 and removes any tag with
    count < 2 from the change set. Pass 2 writes only the surviving
    changes."*
- **[IMPROVEMENT] Error handling is permissive but undocumented.**
  - **Fix:** List which errors are caught (file not found, permission
    denied, malformed change-set JSON) and which halt (YAML parse
    errors in note files, disk full).

#### `obsidian-learn`

- **[IMPROVEMENT] Index-based dedup but no fallback if index is
  missing or stale.**
  - **Fix:** *"If the index is absent or older than 30 days, rebuild
    by re-reading all category files. The index lives at
    `~/Developer/obsidian/knowledge/_index.md`."*
- **[IMPROVEMENT] Category file creation requires manual frontmatter
  on first write.**
  - **Fix:** `scripts/kb_append.py` should auto-write frontmatter on
    first creation: `tags: [ai-knowledge, <category>]`.
- **[IMPROVEMENT] Category list drift with `session-saver`** — see
  cross-skill drift.

#### `obsidian-manage`

- **[IMPROVEMENT] Vault root assumes single-vault Obsidian
  configuration.**
  - **Fix:** *"If `obsidian vault info=path` returns the wrong vault,
    pass `--vault=<path>` explicitly. Don't rely on the global
    default."*
- **[IMPROVEMENT] Wikilinks vs markdown links guidance inconsistent
  with the CLI's actual output.**
  - **Fix:** *"The Obsidian CLI emits markdown links. When grepping
    vault content, match `[text](...)`, not `[[...]]`."*

#### `obsidian-rollover`

- **[IMPROVEMENT] `scripts/rollover.py` failure path undocumented.**
  - **Fix:** *"Run `scripts/rollover.py --dry-run` first. Inspect the
    preview. If the preview misses tasks or duplicates them, halt and
    debug before running without `--dry-run`."*
- **[IMPROVEMENT] Near-duplicate detection rules live in the script,
  not the skill.**
  - **Fix:** Inline the rule in the skill body: *"Duplicates matched
    by stripping bold/italic markers; for tasks > 30 chars,
    substring containment; for shorter tasks, exact-match before the
    ` — ` separator."*

#### `session-saver`

- **[BLOCKER] Category file naming drift with `obsidian-learn`** —
  see cross-skill drift.
- **[IMPROVEMENT] No dedup against existing knowledge entries.**
  - **Fix:** Before Step 3, read target files and skip entries
    already present. Log skipped count.
- **[IMPROVEMENT] "Durable and reusable" threshold uncalibrated.**
  - **Fix:** *"If a session has fewer than 2 entries across all
    categories, still mark it processed; report in the summary that
    no durable learnings were extracted."*

---

### 3.5 Personal bucket

**Already audited (see `recommendations-commands.md`):**
- `prompt:review` (migrated into canonical repo earlier today).

#### `prompt:writer`

- **[IMPROVEMENT] XCUITest block ordering vs preamble unclear.**
  - **Fix:** State the canonical ordering: *"XCUITest rules → Preamble
    → Task statement → Constraints → Implementation → Verification →
    Model & mode."*
- **[IMPROVEMENT] Correction Detection section is orphaned from
  steps 1-7.**
  - **Fix:** Integrate into Step 6 as a concrete inclusion: *"In the
    prompt, instruct the executing session to record self-corrections
    in a `## Corrections` section of the plan / scratchpad."*
- **[POLISH] Frontmatter `:` is intentional CLI namespacing** — not
  a defect.

---

### 3.6 Pipelines bucket

**Already audited (see `recommendations.md`):**
- `pipeline-preflight`, `subagent-reliability`.

No new findings in this bucket — both skills were rewritten in the
first audit pass.

---

### 3.7 Productivity bucket

#### `jira-bulk`

- **[POLISH] Emoji in report summary** — see cross-cutting.
- **Otherwise clean.** Cloud ID sourced correctly via
  `getAccessibleAtlassianResources` — the pattern other Jira-touching
  skills should follow.

#### `plan-to-jira`

- **Clean.** Cloud ID sourced correctly; `AskUserQuestion` used over
  inline text questions; no emoji; no plan-storage violations.

#### `yt-distill`

- **[IMPROVEMENT] Doesn't explicitly cite `yt-research` as a
  prerequisite.** Description says "output of yt-research" but Step 0
  doesn't reinforce.
  - **Fix:** Add to preamble: *"This skill processes the output of
    `yt-research`. Run `yt-research` first if you haven't."*

#### `yt-research`

- **[BLOCKER] `obsidian vault` CLI invocation has no fallback.** If
  the Obsidian CLI is absent, the skill fails with an unclear error.
  - **Fix:** Check `which obsidian` first. If absent, surface a clear
    error: *"Obsidian CLI is required. Install it with
    `brew install obsidian-cli`, or set `OBSIDIAN_VAULT_PATH` and the
    skill will use that path directly."*
- **[IMPROVEMENT] Output directory hard-pinned to Obsidian with no
  user override.**
  - **Fix:** Document the rationale: *"Output always goes to
    `${HOME}/Developer/obsidian/AI/<channel>/`. This is intentional;
    to save elsewhere, copy the folder manually after the run."*

---

## 4. Cross-skill reference health

Productivity-audit agent ran a second-pass scan across all 45 skills
for broken cross-references. **Result: no broken references found.**
Every `Apply skill <name>` invocation, every handoff sentence, every
skill-graph dependency resolves to an existing skill. The handful of
named-but-not-yet-existing skills caught in earlier audits
(`pr-preflight`, `ticket-to-pr`, `prompt` as a parent of
`prompt:review`) have all been fixed.

This is a meaningful health signal — the skill graph is internally
coherent, even though individual skills have findings to address.

---

## 5. Top 15 fixes ranked by impact

If only fifteen changes ship, these in this order:

1. **Sweep emoji from all skills** (~8 skills affected — `grill-with-docs`,
   `swift-style`, `swift-mv-guardian`, `swiftui-liquid-glass`,
   `story-to-spec`, `daily-notes`, `regression-check`, `jira-bulk`).
   Single largest cross-cutting BLOCKER class.
2. **Fix `swift-document` vs `swift-engineer` `///` contradiction.**
3. **Fix `swift-style` vs `swift-engineer` `///` contradiction.**
4. **Bundle or inline the missing reference files** for
   `swift-concurrency-expert`, `swiftopher-columbus`, `swift-lint`,
   `obsidian-audit`.
5. **Source Atlassian cloud ID from `CLAUDE.md` in `daily-notes`.**
6. **Remove `present_files` references** from `daily-notes` and
   `prompt:writer`.
7. **Fix `session-saver` vs `obsidian-learn` category filename drift.**
8. **Route `story-to-spec` output to `${PLANS_DIR}`** instead of
   `docs/specs/`.
9. **`yt-research` needs an `obsidian` CLI presence check** before
   running.
10. **Align `regression-check` severity vocab** to
    `BLOCKER / WARNING / SUGGESTION`.
11. **`daily-notes` needs a Claude.ai vs Claude Code preflight** so
    the skill doesn't silently fail under Claude Code.
12. **`swift-mv-guardian` Mode 1 needs an iOS 16- escape path.**
13. **`git-pr` needs a test-timeout + a BLOCKER-vs-other mapping.**
14. **`spec-pipeline` should programmatically spawn `swiftopher-columbus`**
    instead of telling the user to invoke it manually.
15. **Make `grill-with-docs` call `grill-me` internally** rather than
    duplicating the interview logic.

---

## 6. Carve-outs / decisions needed

- **Should `swift-document` exist at all?** Its purpose contradicts
  the project's no-`///` rule. Options: (a) reframe as opt-in,
  default-disabled; (b) deprecate. User decision.
- **`obsidian-learn` vs `session-saver` — which category list wins?**
  Recommendation: keep 9 categories from `obsidian-learn`, update
  `session-saver` to match.
- **`grill-me` vs `grill-with-docs` — merge or document the split?**
  Recommendation: keep both but make `grill-with-docs` call `grill-me`
  internally.
- **Whether to migrate `daily-notes` to a Claude-Code-friendly
  workflow** that doesn't depend on Claude.ai conversation tools.
  Without it, the skill is functionally Claude.ai-only despite the
  description implying universal availability.

---

## What this review did NOT touch

- The 14 already-audited skills' internals (linked above).
- The `_lib/`, `deprecated/`, `in-progress/` directories.
- The README's skill catalogue (out of scope for a skill-content audit).
- Hooks under `~/.claude/hooks/` and commands under `commands/` other
  than what the prior two audits covered.
