#!/usr/bin/env bash
#
# build_status.sh — report the state of the most recent background build/test
# log and the current branch's CI run, in one pass.
#
# Usage:
#   build_status.sh            # newest /tmp/*.log + CI for current branch
#   build_status.sh nat1826    # newest /tmp/*<pattern>*.log + CI
#
# Background builds in this workflow are launched as:
#   xcodebuild ... > /tmp/<name>.log 2>&1 &
# so "has the build finished?" is answered by grepping the xcodebuild
# terminal markers in that log. No marker yet => still running.

set -uo pipefail

PATTERN="${1:-}"

# ---------------------------------------------------------------------------
# 1. Local background build / test
# ---------------------------------------------------------------------------
if [[ -n "$PATTERN" ]]; then
  LOG="$(ls -t /tmp/*"$PATTERN"*.log 2>/dev/null | head -1)"
else
  LOG="$(ls -t /tmp/*.log 2>/dev/null | head -1)"
fi

echo "=== local build/test ==="
if [[ -z "${LOG:-}" || ! -f "${LOG:-}" ]]; then
  echo "state: NONE — no matching /tmp/*.log found"
else
  echo "log:   $LOG  (modified $(date -r "$LOG" '+%H:%M:%S'))"
  if   grep -q '\*\* BUILD FAILED \*\*'       "$LOG"; then
    echo "state: BUILD FAILED"
    echo "--- first errors ---"
    grep -nE 'error:' "$LOG" | head -10
  elif grep -q '\*\* TEST FAILED \*\*'        "$LOG"; then
    echo "state: TEST FAILED"
    echo "--- first failures ---"
    grep -nE 'error:|failed|XCTAssert|Issue recorded|#expect' "$LOG" | head -10
  elif grep -q '\*\* BUILD INTERRUPTED \*\*'  "$LOG"; then
    echo "state: BUILD INTERRUPTED"
    tail -5 "$LOG"
  elif grep -q '\*\* TEST SUCCEEDED \*\*'     "$LOG"; then
    echo "state: TEST SUCCEEDED"
  elif grep -q '\*\* BUILD SUCCEEDED \*\*'    "$LOG"; then
    echo "state: BUILD SUCCEEDED"
  else
    echo "state: RUNNING — no terminal marker yet"
    echo "--- tail ---"
    tail -3 "$LOG"
  fi
fi

# Corroborate with the process table: a marker can be absent simply because
# the redirect is still buffering.
if pgrep -fl '[x]codebuild' >/dev/null 2>&1; then
  echo "proc:  xcodebuild RUNNING"
else
  echo "proc:  no xcodebuild process"
fi

# ---------------------------------------------------------------------------
# 2. CI for the current branch
# ---------------------------------------------------------------------------
echo ""
echo "=== CI ==="
BRANCH="$(git branch --show-current 2>/dev/null)"
if [[ -z "$BRANCH" ]]; then
  echo "not on a git branch"
elif ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI unavailable"
else
  echo "branch: $BRANCH"
  # gh pr checks resolves the PR for the branch and prints per-check state.
  # Falls back to the raw run list when the branch has no open PR.
  if ! gh pr checks 2>/dev/null; then
    gh run list --branch "$BRANCH" --limit 3 \
      2>/dev/null || echo "no CI runs found for $BRANCH"
  fi
fi
