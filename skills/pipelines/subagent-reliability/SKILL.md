---
name: subagent-reliability
description: >
  Recovery procedure for spawned subagents that drop or return no usable
  report mid-run. Distinct from the "subagent reported failure" path that
  triggers a pipeline's regular fix loop. Use when a subagent returns a raw
  API error, an empty response, a timeout, or a socket-closed message.
  Pipelines (`/workflow`, `/spec-pipeline`) and any orchestrator that
  dispatches Sonnet subagents should cite this skill; never inline its
  rules.
---

# Subagent reliability

Spawned subagent connections can drop mid-run. Observed example:

> `API Error: The socket connection was closed unexpectedly. For more
> information, pass `verbose: true` in the second argument to fetch()`

…returned after the subagent ran for ~200 seconds and had already started
producing file edits. The pipeline orchestrator's retry budget assumes the
subagent reports a result; a crash is a different failure mode and needs a
different response.

This skill is read by orchestrators. It does not auto-fire on human messages.

---

## When to apply

A subagent's terminal state is one of:

| State | Treat as | Recovery path |
|---|---|---|
| Subagent reported success | Pass | Continue to next phase |
| Subagent reported failure (build broken, test failed, scope violated) | Failure | Existing fix-loop / retry budget |
| Subagent returned no usable result (raw API error, empty response, timeout, socket-closed) | **Crash** | **This skill** |

The distinguishing signal: did the subagent emit a structured report
(success or failure)? If not, it crashed — apply the recovery procedure
below before consuming any retry-budget slot.

---

## Recovery procedure

### 1. Inspect actual state before deciding

```bash
git status --short
git diff --stat
```

Compare the modified-files set against the subagent's task brief:

- Did it complete some subset of the intended work?
- Did it write to files outside its declared scope?
- Did it leave temporary or scratch files behind?

Then run the build / test command the subagent should have run:

```bash
# Per project — usually one of:
xcodebuild build -scheme <SCHEME> -destination '<DESTINATION>'
```

This is the truth source. The subagent's lack of report does not mean its
work is broken — only that you don't know yet.

### 2. Decide between three paths

#### A. Recover in place (build clean + scope correct)

Proceed to the next phase without re-spawning. The subagent did enough.
Note partial completion in the orchestrator's phase report.

When to choose: **all three** of the following hold:

- Build (and tests, when applicable) pass.
- The subagent touched at least 80% of the files it was supposed to
  touch — derive the "supposed" set from the task brief (e.g. file list
  in the discovery note). If the brief doesn't enumerate files, judge by
  whether every public deliverable named in the brief has a corresponding
  edit.
- No file outside the brief's scope was modified, and no `MUST NOT touch`
  file was modified.

If any of the three fails, do not recover in place. Re-spawn fresh (path C).

#### B. Resume the agent (continuation token available)

When the subagent terminal output contains an `agentId:` continuation
token (`agentId: ac3d54b0cd694e18f (use SendMessage ...)`), use
`SendMessage` with a short brief listing the remaining work. This is
cheaper than a fresh re-spawn because it keeps the subagent's working
context.

When to choose: partial completion plus a clear list of remaining items
plus an `agentId` in the terminal output.

**If the `agentId` is missing** (terminated before the runtime printed
the token, or output was truncated), do not guess. Treat the crash as if
the subagent had no continuation and route to either path A
(recover-in-place, if the 80% file-coverage threshold is met) or path C
(re-spawn fresh, otherwise). The resume path requires a live token —
fabricating one fails the `SendMessage` call.

#### C. Re-spawn fresh (partial state inconsistent)

If the partial state is broken (build fails, scope creep into protected
files, files left in a half-edited state), revert via `git restore .` for
unstaged changes (or `git checkout -- <file>` for individual reverts), then
re-spawn the subagent with a fresh prompt.

**This path counts against the phase's retry budget.** A re-spawn after a
crash is functionally equivalent to a re-spawn after a reported failure.

### 3. Always log

Record in the orchestrator's phase report:

> Subagent crash recovered: {recover-in-place | resumed | re-spawned}.
> Reason: {one-line summary}.

The log lets future post-mortems distinguish crashes from real failures
when looking at retry-budget consumption.

---

## Anti-patterns

- **Immediately re-spawning a crashed subagent without inspecting state.**
  You'll either duplicate work (subagent had already finished most of it)
  or compound a broken state (subagent left the tree in a half-edited
  state that the re-spawn won't know to clean up first).
- **Burning retry-budget slots on crash recovery.** Crashes are
  infrastructure, not pipeline failures. Counting recover-in-place or
  resume against the budget will trigger spurious halt-and-block reports.
- **Assuming the crash itself broke the build.** It probably didn't —
  the build only sees committed work. Always verify with the build before
  assuming a regression.
- **Re-spawning with an unchanged prompt.** If the original prompt caused
  the subagent to run for 200+ seconds (which is what most often precedes
  the socket drop), trim it. Move long context to a discovery note the
  subagent reads instead of embedding it inline.

---

## Verification

After this skill is referenced from a pipeline orchestrator:

- A simulated crash (e.g. injected via prompting the subagent to halt
  silently after partial work) is recovered without consuming a retry
  budget slot.
- The orchestrator's phase report distinguishes "subagent crashed,
  recovered in place" from "subagent reported failure, fix loop ran".
- The retry budget for the phase remains unchanged after a recover-in-place
  outcome.
