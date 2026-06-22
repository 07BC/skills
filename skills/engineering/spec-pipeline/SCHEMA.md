# Spec Pipeline Config Schema

The pipeline reads project config from a fenced YAML block in the project's `CLAUDE.md`. This file documents the schema. The same structure is parsed by `scripts/read-pipeline-config.sh`.

## Where it lives

In the target project's `CLAUDE.md`:

````markdown
## Spec Pipeline Config

```yaml
spec_pipeline:
  ticket_prefix: NAT
  github_repo: my-org/my-app
  workspace: MyApp.xcworkspace
  scheme: "MyApp"
  destination: "platform=tvOS Simulator,name=Apple TV"
  tests_target: MyAppTests
  target_architecture_doc: docs/engineering/target-architecture.md
  context_docs: [CONTEXT.md, CONTEXT-MAP.md]
  spec_dir: docs/specs
  plan_dir: docs/plans
  audit_dir: AI/plans
  cycle_budget: 3
  coverage_floor: 90
```
````

The parser extracts the first ```` ```yaml ```` block that contains a top-level `spec_pipeline:` key and reads its child keys.

## Fields

| Key | Required | Type | Default | Meaning |
|---|---|---|---|---|
| `ticket_prefix` | recommended | string | (none) | Ticket prefix for branch naming and `/git-commit`. E.g. `NAT`. When absent, the pipeline derives branch names from spec ID without a prefix. Also anchors frozen AC IDs (`<PREFIX>-NNN-ACn`) in `/spec-decomposition`. |
| `github_repo` | recommended | string | (current repo) | `owner/name` of the GitHub repo holding the master + child issues. Required by `/spec-decomposition` and by `/spec-pipeline --from-issue`. When unset, both fall back to `gh repo view`. |
| `coverage_floor` | optional | integer | `90` | Minimum changed-line coverage percent the Phase 3 test gate enforces (`coverage-gate.sh`). Genuinely-untestable paths go in an exclusions file, not a lower floor. |
| `tests_dir` | optional | string | (auto-detected) | Directory holding test sources, scanned by the test gate for `// AC:` annotations. When unset, the pipeline derives it from tracked `*Tests/` / `*UITests/` paths. Set it when auto-detection picks the wrong dir. |
| `workspace` | yes | string | — | `.xcworkspace` file at repo root. |
| `scheme` | yes | string | — | Xcode scheme name (quote if contains spaces). |
| `destination` | yes | string | — | Full `-destination` argument value (quote it). |
| `tests_target` | yes | string | — | Unit test target name for `-only-testing:` filters. |
| `target_architecture_doc` | recommended | string | (none) | Path to the project's architecture authority doc. Read by `spec-distiller`, `spec-planner`, and `spec-engineer`. Generate with `/architecture-doc` if you don't have one. |
| `context_docs` | optional | string list | `[]` | Additional project context docs that agents should read on start. |
| `spec_dir` | optional | string | `docs/specs` | Where `spec-distiller` writes specs. |
| `plan_dir` | optional | string | `docs/plans` | Where `spec-distiller` writes plans. |
| `audit_dir` | optional | string | `AI/plans` | Sub-path inside `$OBSIDIAN_VAULT` for audit logs. |
| `cycle_budget` | optional | integer | `3` | Max Phase 4 review cycles before escalating. |

## Required vs optional

Hard requirements (pipeline refuses to start without these): `workspace`, `scheme`, `destination`, `tests_target`.

Recommended (pipeline warns and asks once):

- `ticket_prefix` — for branch naming and commit prefixes.
- `target_architecture_doc` — if the field is set but the file is missing, the pipeline prompts the user before Phase 1: generate it with `/architecture-doc`, proceed without it (agents fall back to the `swift-engineering` skill body for architecture authority), or abort. Omitting the field entirely is treated as "no architecture doc available" and the pipeline runs without warning.

Everything else has a sensible default.

## Vault path resolution

The audit log writes to `$OBSIDIAN_VAULT/$audit_dir/<spec-id>.md`.

`$OBSIDIAN_VAULT` resolution order:
1. The `OBSIDIAN_VAULT` environment variable, if set.
2. `$HOME/Developer/obsidian` (default).

Matches the override pattern from `vault_preconditions.sh` (audit 2026-05-16).

## Parsing rules (what `read-pipeline-config.sh` does)

- Locates the first ```` ```yaml ```` fence containing a top-level `spec_pipeline:` key.
- Extracts simple `key: value` pairs (with optional double-quoted values).
- Special-cases `context_docs: [a, b, c]` inline list syntax.
- Emits one shell variable per key on stdout, suitable for `eval` consumption:

```
SPEC_PIPELINE_WORKSPACE='MyApp.xcworkspace'
SPEC_PIPELINE_SCHEME='MyApp'
SPEC_PIPELINE_DESTINATION='platform=tvOS Simulator,name=Apple TV'
SPEC_PIPELINE_TESTS_TARGET='MyAppTests'
SPEC_PIPELINE_TICKET_PREFIX='NAT'
SPEC_PIPELINE_TARGET_ARCHITECTURE_DOC='docs/engineering/target-architecture.md'
SPEC_PIPELINE_CONTEXT_DOCS='CONTEXT.md CONTEXT-MAP.md'
SPEC_PIPELINE_SPEC_DIR='docs/specs'
SPEC_PIPELINE_PLAN_DIR='docs/plans'
SPEC_PIPELINE_AUDIT_DIR='AI/plans'
SPEC_PIPELINE_CYCLE_BUDGET='3'
SPEC_PIPELINE_GITHUB_REPO='my-org/my-app'
SPEC_PIPELINE_COVERAGE_FLOOR='90'
```

- Exits non-zero with a printable error if any required field is missing or the fence cannot be found.

## Adding to a project

The project must also add three lines to its `.gitignore` (all pipeline artefacts are gitignored per design — see plan Q13):

```
docs/specs/
docs/plans/
master-plan.md
```
