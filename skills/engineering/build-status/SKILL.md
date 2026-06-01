---
name: build-status
description: Reports whether the in-flight build, test run, or CI check has finished, and whether it passed or failed. Reads the most recent background build log in /tmp and the current branch's CI run, then reports running / passed / failed with the first errors on failure. Use when the user asks "has the build finished?", "is the sim build done?", "check build status", "did the tests pass?", "did CI pass?", or pastes "Build status check — has the sim build finished?".
---

# build-status

Answer "has the build/test/CI finished, and did it pass?" in one pass —
without re-deriving the log path or the `gh` incantation each time.

This skill exists because that exact question was asked verbatim dozens of
times across sessions while builds ran in the background. It replaces the
hand-typed status-check macro.

## How builds run in this workflow

Builds and test runs are launched in the background, redirected to a named
log under `/tmp`:

```bash
xcodebuild ... > /tmp/<name>-build.log 2>&1 &
```

So "finished" is determined by the **xcodebuild terminal markers** in that
log, not by the process alone:

- `** BUILD SUCCEEDED **` / `** TEST SUCCEEDED **` → passed
- `** BUILD FAILED **`   / `** TEST FAILED **`    → failed
- `** BUILD INTERRUPTED **`                       → interrupted
- no marker yet                                   → still running

## Steps

1. Run the bundled script (it covers both the local build log and CI):

   ```bash
   scripts/build_status.sh            # newest /tmp/*.log + CI for this branch
   scripts/build_status.sh nat1826    # narrow to /tmp/*nat1826*.log
   ```

   If the user named a specific build/ticket (e.g. "the fix-build", "the
   nat1826 build"), pass that as the pattern argument so the right log is
   selected rather than just the newest.

   If the script is missing from the skill directory (it ships alongside
   this file), fall back to the manual sequence below.

2. Read the script's two blocks and report in **one line per surface**:
   - **Local:** `RUNNING` / `BUILD SUCCEEDED` / `TEST SUCCEEDED` /
     `BUILD FAILED` / `TEST FAILED` / `INTERRUPTED` / `NONE`.
   - **CI:** the per-check state from `gh pr checks`, or the latest run.

3. **On failure**, surface the first `error:` / failure lines the script
   printed — do not dump the whole log. Enough to act on, nothing more.

4. **If still running**, say so plainly and do not invent progress. Offer to
   poll: if the user wants to wait, use `ScheduleWakeup` with a short delay
   (the build cache stays warm under ~270s) rather than busy-looping.

## Manual fallback

If the script is unavailable:

```bash
LOG="$(ls -t /tmp/*.log | head -1)"
grep -qE '\*\* (BUILD|TEST) FAILED \*\*' "$LOG"    && echo FAILED
grep -qE '\*\* (BUILD|TEST) SUCCEEDED \*\*' "$LOG"  && echo PASSED
# neither => still running; confirm with: pgrep -fl '[x]codebuild'
gh pr checks 2>/dev/null || gh run list --branch "$(git branch --show-current)" --limit 3
```

## What NOT to do

- Do not launch a new build — this skill only **reports** on an existing
  one. Building/testing is `swift-test-all` / `xcodebuildmcp-cli`.
- Do not report "passed" off the process exiting alone — require the
  `SUCCEEDED` marker. A process can exit on failure or interruption.
- Do not paste the full build log. First errors only.
- Do not busy-loop with `sleep` to wait; schedule a wake-up instead.
