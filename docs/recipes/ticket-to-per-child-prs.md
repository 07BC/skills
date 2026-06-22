# Recipe: ticket with many ACs → one PR per child

Take a scoped Jira ticket carrying many acceptance criteria, split it into a GitHub **spec tree**,
and ship each child as its own reviewable PR with
[`/spec-pipeline`](../../skills/engineering/spec-pipeline/SKILL.md). One child, one PR, in
dependency order.

## When to use

- The ticket is too big for one PR — its ACs cluster into several shippable pieces.
- You want each piece **reviewed and merged independently** before the next starts.
- You want the traceability spine: frozen AC ID → child `covers:` → task `implements:` → test.

For one PR covering the whole ticket unattended, use
[ticket-to-single-pr-autonomous](./ticket-to-single-pr-autonomous.md). For a single scoped
subtask, use [single-story-to-pr](./single-story-to-pr.md).

## Prerequisites

- Project `CLAUDE.md` with a `spec_pipeline:` block — `ticket_prefix`, `github_repo`, build
  config, `target_architecture_doc`. See [SCHEMA.md](../../skills/engineering/spec-pipeline/SCHEMA.md).
- **Atlassian MCP** (to read the Jira ticket) and **`gh` CLI** (for the spec tree + PRs).
- See [Which "master" does what](./README.md#which-master-does-what) — this recipe builds and
  consumes the **GitHub spec tree**.

## Steps

1. **Decompose the ticket into a spec tree.**

   ```
   /spec-decomposition --from-jira NAT-1234
   ```

   [`/spec-decomposition`](../../skills/engineering/spec-decomposition/SKILL.md) reads the ticket,
   **freezes stable AC IDs** (`NAT-1234-AC1` …), and creates a GitHub **master issue** plus one
   **child sub-issue** per spec — each declaring `covers: [AC IDs]` and `depends_on: [child #s]`.
   It prints the children and the suggested order.

2. **Ship each child, in dependency order.** For each child sub-issue number:

   ```
   /spec-pipeline --from-issue 412
   ```

   `/spec-pipeline` runs the full inner chain for that child: distil → validate plan → per-task
   **engineer → test → concurrency audit → dual review → commit** → whole-diff review → PR. A
   child does **not** start until every `depends_on` child is **merged to main** (the sequencing
   gate), so merge each PR before running the next dependent child.

3. **Confirm each PR.** The final phase opens the child PR with `gh` and waits for your
   confirmation — it never merges. Review, merge, then move to the next child.

## What you get

- A GitHub master issue + child sub-issues with frozen, immutable AC IDs.
- One PR per child, each scoped to its `covers:` ACs, in dependency order.
- A durable audit log per child under the configured `audit_dir` (Obsidian).

## If it stalls

Each phase retries within budget then halts with a blocked report; the run resumes in-place on
re-invoke. See [delivery-lifecycle.md → When a run fails](../delivery-lifecycle.md#when-a-run-fails).

## Variant

- Same decomposition, but one PR for everything, unattended →
  [ticket-to-single-pr-autonomous](./ticket-to-single-pr-autonomous.md) (it consumes the **same**
  spec master this recipe creates, via `--from-master`).
