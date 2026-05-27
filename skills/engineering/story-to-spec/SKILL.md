---
name: story-to-spec
description: >
  Takes a story from Jira, a local markdown file, or a free-form prompt
  and distils it into a structured spec document. Writes the spec to
  docs/specs/ in the project and the Obsidian vault. No worktrees, no
  planning, no implementation — spec authoring only.
---

# Story to Spec

`/story-to-spec` reads a story and produces a structured spec document ready
for implementation. It does not create worktrees, implementation plans, or PRs.

Use `/spec-pipeline` when you want the full end-to-end flow.

---

## Help mode

If `$ARGUMENTS` is empty, `--help`, `-h`, or `help`, print the block below
verbatim and exit. Do not read files or make any tool calls.

```
/story-to-spec — distil a story into a spec document

Usage:
  /story-to-spec --from-jira KEY        fetch ticket from Jira → write spec
  /story-to-spec --from-spec PATH       read local markdown → write spec
  /story-to-spec --from-prompt "TEXT"   free-form description → write spec
  /story-to-spec KEY                    shorthand for --from-jira

Output:
  docs/specs/<spec-id>.md          (inside the project — add to .gitignore)
  $OBSIDIAN_VAULT/<project>/plans/<spec-id>.md
```

---

## Step 1 — Parse input

Parse `$ARGUMENTS` left-to-right. The first recognised flag or pattern wins.

| Input | Sets |
|---|---|
| `--from-jira <KEY>` | `source_type=jira`, `jira_key=<KEY>` |
| `--from-spec <PATH>` | `source_type=spec`, `input_path=<PATH>` |
| `--from-prompt "<TEXT>"` | `source_type=prompt`, `raw_text=<TEXT>` |
| Matches `^[A-Z]+-[0-9]+$` | Treat as `--from-jira` |

Unknown flags: print `unknown flag <flag>; run /story-to-spec --help` and exit.

---

## Step 2 — Resolve input → raw_text + spec_id

### `--from-jira <KEY>`

1. Load the Jira read tools via ToolSearch:
   ```
   ToolSearch("select:mcp__plugin_atlassian_atlassian__getJiraIssue,mcp__plugin_atlassian_atlassian__getAccessibleAtlassianResources")
   ```
   If either tool fails to load, stop:
   > Atlassian MCP is not available. Use `--from-spec` or `--from-prompt` instead.

2. Call `mcp__plugin_atlassian_atlassian__getAccessibleAtlassianResources` then
   `mcp__plugin_atlassian_atlassian__getJiraIssue` for the key. Extract:
   - Summary (one line)
   - Description (full body)
   - Acceptance criteria (verbatim)
   - Issue type

3. If the ticket has no acceptance criteria, stop:
   > Ticket <KEY> has no acceptance criteria. Add ACs in Jira before re-running.
   Never invent acceptance criteria.

4. Compose `raw_text` as a markdown blob with all extracted fields.

5. Derive the spec ID:
   ```bash
   SCRIPTS="$HOME/.claude/skills/spec-pipeline/scripts"
   spec_id="$(bash ${SCRIPTS}/derive-spec-id.sh --from-jira "<KEY>" "<summary>")"
   ```

### `--from-spec <PATH>`

1. Verify the file exists. If not, stop with a clear error.
2. `raw_text` = file contents verbatim.
3. ```bash
   spec_id="$(bash ${SCRIPTS}/derive-spec-id.sh --from-spec "<PATH>")"
   ```

### `--from-prompt "<TEXT>"`

1. `raw_text="<TEXT>"`
2. ```bash
   spec_id="$(bash ${SCRIPTS}/derive-spec-id.sh --from-prompt "<TEXT>")"
   ```
3. Confirm the derived `spec_id` with the user via `AskUserQuestion` (prompts
   can produce odd slugs):
   - Option A: `<derived-slug>` (Recommended)
   - Option B: Let me type a different slug

---

## Step 3 — Read project context

Read `CLAUDE.md` from the current working directory (required for architecture
context — do not halt if absent, just note it and continue).

Look for a `spec_pipeline:` YAML block. If found, extract:
- `target_architecture_doc` — read the file if it exists
- `context_docs` — read each file if it exists

If the `spec_pipeline:` block is absent, scan `CLAUDE.md` for any inline
references to architecture docs (e.g. `docs/engineering-doc.md`,
`docs/target_architecture/`) and read those files if they exist.

If a referenced file is missing, skip it with a one-line warning — do not halt.

---

## Step 4 — Resolve output paths

The authoritative copy of every spec lives in the Obsidian vault per
the global plan-storage rule. The in-repo `docs/specs/` copy is
optional and only used when the project's `spec_pipeline:` block
declares it (set `keep_in_repo_specs: true` to opt in).

```bash
project_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
project_name="$(basename "$project_root")"
obsidian_vault="${OBSIDIAN_VAULT:-${HOME}/Developer/obsidian}"

# Authoritative output — in the Obsidian vault
obsidian_output="${obsidian_vault}/${project_name}/plans/${spec_id}.md"
mkdir -p "$(dirname "$obsidian_output")"

# Optional in-repo copy — only when the project opts in
keep_in_repo="$(yq -r '.spec_pipeline.keep_in_repo_specs // false' CLAUDE.md 2>/dev/null)"
if [ "$keep_in_repo" = "true" ]; then
  spec_output="${project_root}/docs/specs/${spec_id}.md"
  mkdir -p "$(dirname "$spec_output")"
fi
```

If `$obsidian_output` already exists, ask via `AskUserQuestion` before
overwriting:
- Option A: Overwrite (Recommended if the story has changed)
- Option B: Abort — I'll choose a different spec ID

---

## Step 5 — Distil the spec

Read all gathered context in this order before writing:

1. `CLAUDE.md`
2. `target_architecture_doc` (if available)
3. Each file in `context_docs` (if available)
4. The `raw_text`

Synthesise a spec document with the following structure. Write every section
in order. Omit a section only if explicitly noted as optional.

```markdown
---
spec_id: <spec_id>
status: ready
source: <jira:<KEY> | spec:<input_path> | prompt>
---

# <Title>

One sentence drawn from the story summary. Imperative mood. No "The app will…" preamble.

## Summary

One concise paragraph: what this story delivers, why it matters to the user,
and which layer of the architecture it primarily touches.

## Acceptance Criteria

Numbered list. Reproduce verbatim from Jira or the spec file where they exist.
For `--from-prompt` input or source files with no explicit ACs, derive them
from the description. If you cannot derive ACs without guessing, omit this
section and add an open question instead — never invent criteria.

## Architecture Notes

How this story fits the existing codebase. Reference specific types, services,
layers, or constraints found in CLAUDE.md and the architecture doc. Cover:
- Which existing types or services this story touches or extends
- New types or services that need to be introduced
- Data model changes (SwiftData entities, fields)
- Concurrency boundaries crossed (MainActor, actor isolation)

Omit this section only if no architecture context was available at all.

## Constraints

Hard rules from CLAUDE.md that directly apply to this story's scope.
Examples: `Decimal everywhere`, `no ViewModels`, `AUD locale only`.
Do not list every rule in the project — only those relevant here.
Omit if none apply specifically to this story.

## Open Questions

List any ambiguities that cannot be resolved from the available context.
Each entry: one question, one sentence, specific enough to act on.
Omit this section entirely if there are no open questions.
```

**If `## Open Questions` is present**, change the frontmatter status:
```
status: blocked-on-open-questions
```

---

## Step 6 — Write outputs

Write the spec to `$obsidian_output` (the authoritative copy in the
Obsidian vault).

If the in-repo copy is enabled (`keep_in_repo_specs: true`), also
write to `$spec_output`:

```bash
cp "$obsidian_output" "$spec_output"
```

When writing an in-repo copy, check whether `docs/specs/` appears in
the project's `.gitignore`. If not, print:

```
Reminder: add docs/specs/ to .gitignore — specs are not committed.
```

---

## Step 7 — Report

Print to the user:

```
Spec written

  Spec ID:  <spec_id>
  Project:  <spec_output>
  Obsidian: <obsidian_output>
  Status:   <ready | blocked-on-open-questions>
```

If status is BLOCKED, also print the `## Open Questions` section verbatim so
the user can act on them without opening the file.

---

## Hard rules

- **Never invent acceptance criteria** — if absent and non-inferrable, add an
  open question and set status to BLOCKED.
- **Never create worktrees, branches, or PRs** — spec authoring only.
- **Never write to Jira** — all Jira access is read-only.
- **Never overwrite an existing spec without asking** — Step 4 guards this.
- **`derive-spec-id.sh` requires spec-pipeline to be installed** — if the
  script is absent, derive the ID manually using the same rules: lowercase,
  non-alphanumeric runs collapse to a single hyphen, 60 chars max, ticket key
  prepended for Jira sources.
