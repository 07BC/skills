---
name: ios-memgraph-leaks
description: Capture and inspect iOS and tvOS leaks and memgraphs. Use when debugging leaked objects, retain cycles, memory growth, or before/after leak evidence — including tvOS simulators, adhoc-signed or preinstalled bundles that only yield a restricted "corpse", and per-screen accumulation across a navigate-in-and-out flow.
---

# iOS Memgraph Leaks

Use this skill to prove iOS leaks from a live simulator process or an existing `.memgraph`. Pair it with `../ios-simulator-control/SKILL.md` when the task also needs simulator build, install, launch, UI driving, logs, or screenshots.

## Core Workflow

1. Build, launch, and drive the exact flow that should release objects.
2. Capture a memgraph from the running simulator process with `scripts/capture_sim_memgraph.sh`.
3. Summarize leaks with `scripts/summarize_memgraph_leaks.py`.
4. For each app-owned leaked type, inspect ownership with `leaks --traceTree=<address> <file.memgraph>` and grouped leak evidence.
5. Make the smallest root-cause patch, then recapture the same flow on the same simulator when possible.
6. Report proof: before/after leak counts, disappeared root types, remaining leaks, memgraph paths, and test/build results.

Do not claim a leak fix from a smaller memgraph alone. A credible fix explains the ownership path that kept the object alive and shows that the same path or type disappears after the patch.

## Capture

Prefer capturing from the simulator already used for the reproduction. Resolve the simulator UDID and app bundle identifier, then capture the running app:

```bash
SKILL_DIR="<absolute path to this loaded skill folder>"
SIM="<simulator-udid>"
BUNDLE_ID="<app.bundle.identifier>"
MEMGRAPH_DIR="$(mktemp -d "${TMPDIR:-/tmp}/claude-ios-memgraph.XXXXXX")"

"$SKILL_DIR/scripts/capture_sim_memgraph.sh" \
  --udid "$SIM" \
  --bundle-id "$BUNDLE_ID" \
  --out-dir "$MEMGRAPH_DIR"
```

Do not derive `SKILL_DIR` from the target app repo's `pwd`; installed plugins usually live outside the app being debugged. Store captures in a run-specific temp or user-chosen folder, not under `SKILL_DIR`.

If the process cannot be found, confirm the bundle identifier and use `xcrun simctl spawn "$SIM" launchctl list` to inspect running labels.

## Restricted "corpse" captures (adhoc-signed / preinstalled bundles)

A bundle without the `get-task-allow` entitlement (Release/adhoc-signed, or already installed) cannot be attached to by `leaks`, so a live `leaks <pid>` yields only a restricted **corpse** with no symbolication. Do not re-sign the installed bundle in place to add the entitlement — it breaks the bundle seal and the app will not launch. Instead:

1. Capture the graph anyway — the corpse still contains the full heap:
   ```bash
   xcrun simctl spawn booted leaks --outputGraph /tmp/app.memgraph <bundle.id>
   ```
2. Analyse the graph file with `heap` (resolves class names and counts on a corpse where live `leaks` cannot):
   ```bash
   heap /tmp/app.memgraph                       # full class histogram
   leaks --traceTree=<address> /tmp/app.memgraph
   ```
3. For trace trees, relaunch the app with malloc stack logging so allocation backtraces are recorded:
   ```bash
   SIMCTL_CHILD_MallocStackLogging=1 xcrun simctl launch booted <bundle.id>
   ```

If a clean Debug rebuild is possible in the environment it will carry `get-task-allow` and avoid this entirely — but in CI/headless or signing-identity-less setups, the corpse + `heap` path is the reliable route.

## tvOS: driving the flow and reading the signal

tvOS has no coordinate taps — the focus engine is driven by remote/HID **key presses**. Drive the flow with `Select=40`, `Menu=41`, and arrow keys (Up/Down/Left/Right), via XcodeBuildMCP UI automation or `xcrun simctl`, and **gate every input with a screenshot** to confirm focus actually moved before the next press.

For "does X release after the user leaves it", the reliable signal is the **live instance count of a per-screen class after returning to a baseline screen**, not a smaller total memgraph:

1. Drive `enter screen → back ×N` (e.g. watch a stream → Home, repeated 3+ times), settle ~10s, capture.
2. Count live instances of a class that exists **only** on the target screen (`heap` histogram). More than one after returning to baseline = accumulation / leak.
3. Avoid confounded classes — e.g. `AVPlayer` is inflated by Home-screen preview players, so prefer a class unique to the target screen (a chat/session view model, its WebSocket, etc.). Note the confound in the report rather than over-claiming.

## Summarize

Summarize an existing memgraph:

```bash
"$SKILL_DIR/scripts/summarize_memgraph_leaks.py" \
  /path/to/app.memgraph \
  --trace-limit 5 \
  --out /path/to/leak-summary.md
```

Use `--trace-limit` sparingly. Trace trees are useful root-cause evidence, but large memgraphs can produce noisy output. If a trace tree says `Found 0 roots referencing`, treat it as an unreachable/self-retained leak candidate and use the summary's grouped leak tree or `leaks --groupByType <file.memgraph>` to identify the retained fields and payload chain.

## Root Cause Rules

- Identify the first app-owned leaked type in the leak output or trace.
- Determine the intended lifetime: process, session, account, view, request, or task.
- Treat lazy or deferred allocation as a scope reduction, not a leak fix, unless the original eager allocation itself violated the intended lifetime.
- Prove retain-cycle claims with either a `traceTree` ownership path or an isolated reproduction.
- For unreachable/self-cycle leaks, `traceTree` may have no root path; use `leaks --groupByType` plus source verification to find the self-retaining edge.
- Do not claim success just because total leak count went down; prove the specific type or path disappeared.
- Separate real root-cause branches from candidate/noise branches.
- Prefer deleting the retaining edge over adding broad cleanup code.

## Report

A useful leak report includes:

- the exact flow and simulator/app build
- the memgraph and summary paths
- app-owned leaked types and counts
- at least one ownership path, or grouped leak tree evidence when the object is unreachable from roots
- the smallest proposed or applied retaining-edge fix
- before/after evidence when a fix was made

If the memgraph shows only framework/runtime noise, say that and recommend the next narrower capture rather than inventing an app leak.
