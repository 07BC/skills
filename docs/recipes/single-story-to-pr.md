# Recipe: single story → PR

Take one already-scoped story or subtask (`NAT-1234`) to a reviewed pull request with
[`/workflow`](../../commands/Mr%20Will/workflow.md). One subtask, one branch, one PR.

## When to use

- The work is a **single, scoped subtask** — not a multi-AC epic that needs splitting.
- You want architecture-drift tracking wired into the run (GitHub master issue + sub-issues).
- You're happy to babysit a few control points (it runs as an Opus-planned orchestration).

For a ticket with many ACs that should become several PRs, use
[ticket-to-per-child-prs](./ticket-to-per-child-prs.md) instead. To drive a whole ticket to one
PR unattended, use [ticket-to-single-pr-autonomous](./ticket-to-single-pr-autonomous.md).

## Prerequisites

- Project `CLAUDE.md` with build config (workspace/scheme/destination/test target) and agent
  routing — see the [project setup section of the README](../../README.md#set-up-a-project-claudemd).
- **Atlassian MCP** connected (for a Jira input) and **`gh` CLI** authenticated (for the PR and
  architecture tracking). See the [external dependencies table](../../README.md#external-dependencies).
- A clean working tree on the correct base branch (`/workflow` Phase 0 gates on this).

## Steps

1. **Run the orchestrator.**

   ```
   /workflow NAT-1234
   ```

   The input auto-detects: a Jira key, a spec file path, or a free-form description all work.

2. **`/workflow` drives the phases for you** — read the Jira ticket + ACs, reconcile the GitHub
   architecture tree ([`discovery-init`](../../skills/discovery/discovery-init/SKILL.md) on the
   first run, [`discovery-check`](../../skills/discovery/discovery-check/SKILL.md) after),
   produce an implementation brief, then **implement → test → review** via `swift-engineering`,
   `swift-testing`, and `swift-code-review` subagents, gating on a real-green test run.

3. **Confirm the PR.** Phase 8 runs the pre-PR gate (build, tests, scope, branch name, PR
   description, Jira status) and creates the PR with `gh`, transitioning the Jira subtask to
   **In Review**. This is the human boundary — it does not merge.

## What you get

- One PR on a branch derived from the ticket key + subtask title.
- A discovery note under `PLANS_DIR`, and the GitHub architecture tree reconciled.
- The Jira subtask moved to **In Review**.

## If it stalls

`/workflow` halts and writes a blocked report rather than pushing through a broken state. See
[delivery-lifecycle.md → When a run fails](../delivery-lifecycle.md#when-a-run-fails). Re-invoke
to resume, or type `continue` if a long run pauses at a turn boundary.

## Variant

- Many ACs, want several reviewable PRs → [ticket-to-per-child-prs](./ticket-to-per-child-prs.md).
- Many ACs, want one unattended PR → [ticket-to-single-pr-autonomous](./ticket-to-single-pr-autonomous.md).
