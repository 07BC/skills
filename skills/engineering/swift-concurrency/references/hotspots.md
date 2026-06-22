# Concurrency Hotspots — grep checklist for review

A fast triage pass for any diff or file under concurrency review. Each pattern is a
`grep` target and the question to ask when it appears. None is banned outright — each
is a place where data races and isolation bugs cluster, so each needs a justification.

| Grep for | Why it's a hotspot | What to check |
|---|---|---|
| `DispatchQueue` | Pre-concurrency threading mixed with async/await | Can it be an `actor` or `@MainActor` isolation instead? GCD + async in one type is where ordering bugs hide. |
| `Task.detached` | Drops caller isolation **and** task-local values; rarely correct | Is the detachment justified in a comment? Usually a plain `Task {}` (or a `@concurrent` function) is what was wanted. |
| `Task {` inside a loop | Unbounded task fan-out | Should this be a `withTaskGroup` with a concurrency cap? Loose `Task {}` per iteration loses structured cancellation and back-pressure. |
| `withCheckedContinuation` / `withCheckedThrowingContinuation` | Continuation must resume **exactly once** | Trace every path: early return, thrown error, delegate callback firing twice. Resume-zero hangs; resume-twice traps. |
| `AsyncStream` | Buffering policy and termination | Is the buffering policy set (`.bufferingNewest`)? Is the continuation `finish()`ed on every teardown path? Unbounded + never-finished = leak. |
| `@unchecked Sendable` | Compiler safety switched off | Is there a documented invariant *and* a follow-up to remove it? If the type holds mutable state, it should be an `actor`. |
| `nonisolated(unsafe)` | Same — escape hatch | Justified single-init-then-read-only value, or a hidden race? |
| `MainActor.run {` | Manual hop, often a smell | Can isolation inference do this instead? A pile of `MainActor.run` blocks usually means the function should be `@MainActor` or `nonisolated(nonsending)`. |
| `.assumeIsolated` | Asserts isolation rather than proving it | Is the caller *guaranteed* on that actor at runtime? Wrong assumption traps in release. |
| force unwrap (`!`) after `await` | State may have changed across the suspension | Re-validate optionals/indices captured before the `await` — the actor could have mutated in between (reentrancy). |
| `Task.sleep` outside tests | Wall-clock wait standing in for synchronisation | Almost always the wrong tool in production — prefer an `AsyncSequence` or continuation. |

## How to use

Run the greps, then for each hit ask the column-3 question. A hit with a one-line
justification comment is fine; a hit with none is the finding. Pair this with
`bug-patterns.md` — the hotspots tell you *where* to look, the bug-patterns tell you
*what failure* you're looking for.
