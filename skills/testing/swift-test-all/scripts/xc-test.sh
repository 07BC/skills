#!/usr/bin/env bash
# Run the Xcode test suite for the current project.
# Self-contained: detects workspace/scheme/destination from CLAUDE.md,
# with fallbacks to filesystem discovery.
#
# Usage: xc-test.sh [test-filter]
#   test-filter: optional -only-testing: value, e.g. MyTarget/MySuite/testName
#
# Exit codes:
#   0  all tests passed
#   1  one or more tests failed
#   2  config error (no workspace or scheme found)
#   3  output parse error
#   4  destination not available on this machine

set -euo pipefail

FILTER="${1:-}"
LOG=/tmp/xc-test.log

# ── Config detection ──────────────────────────────────────────────────────────

detect_workspace() {
  # 1. CLAUDE.md in cwd or parents
  local dir="$(pwd)"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/CLAUDE.md" ]]; then
      local ws
      ws=$(/usr/bin/grep -oE '[A-Za-z0-9_-]+\.xcworkspace' "$dir/CLAUDE.md" 2>/dev/null | /usr/bin/head -1 || true)
      if [[ -n "$ws" && -d "$dir/$ws" ]]; then
        echo "$dir/$ws"; return
      fi
    fi
    dir="$(dirname "$dir")"
  done
  # 2. Glob
  local found
  found=$(ls *.xcworkspace 2>/dev/null | /usr/bin/head -1 || true)
  [[ -n "$found" ]] && echo "$(pwd)/$found" && return
  echo "" # not found
}

detect_scheme() {
  local ws="$1"
  # 1. CLAUDE.md
  local dir="$(pwd)"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/CLAUDE.md" ]]; then
      local sch
      sch=$(/usr/bin/grep -oE 'scheme[[:space:]]*:[[:space:]]*[A-Za-z0-9_-]+' "$dir/CLAUDE.md" 2>/dev/null | /usr/bin/awk '{print $NF}' | /usr/bin/head -1 || true)
      [[ -n "$sch" ]] && echo "$sch" && return
    fi
    dir="$(dirname "$dir")"
  done
  # 2. xcodebuild -list
  if [[ -n "$ws" ]]; then
    xcodebuild -workspace "$ws" -list 2>/dev/null | /usr/bin/awk '/Schemes:/,0' | /usr/bin/grep -v "Schemes:" | /usr/bin/grep -v "^$" | /usr/bin/head -1 | /usr/bin/xargs || true
  fi
}

detect_destination() {
  # 1. CLAUDE.md (look for platform=iOS Simulator,name=...)
  local dir="$(pwd)"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/CLAUDE.md" ]]; then
      local dest
      dest=$(/usr/bin/grep -oE "platform=iOS Simulator,name=[A-Za-z0-9 ]+" "$dir/CLAUDE.md" 2>/dev/null | /usr/bin/head -1 || true)
      [[ -n "$dest" ]] && echo "$dest" && return
    fi
    dir="$(dirname "$dir")"
  done
  # 2. ~/Developer/CLAUDE.md canonical
  if [[ -f "$HOME/Developer/CLAUDE.md" ]]; then
    local dest
    dest=$(/usr/bin/grep -oE "platform=iOS Simulator,name=[A-Za-z0-9 ]+" "$HOME/Developer/CLAUDE.md" 2>/dev/null | /usr/bin/head -1 || true)
    [[ -n "$dest" ]] && echo "$dest" && return
    # Try just the sim name
    local sim
    sim=$(/usr/bin/grep -oE "iPhone [0-9A-Za-z]+" "$HOME/Developer/CLAUDE.md" 2>/dev/null | /usr/bin/head -1 || true)
    [[ -n "$sim" ]] && echo "platform=iOS Simulator,name=$sim" && return
  fi
  # 3. Fallback
  echo "platform=iOS Simulator,name=iPhone 16e"
}

WORKSPACE=$(detect_workspace)
if [[ -z "$WORKSPACE" ]]; then
  echo "xc-test: no .xcworkspace found" >&2
  exit 2
fi

SCHEME=$(detect_scheme "$WORKSPACE")
if [[ -z "$SCHEME" ]]; then
  echo "xc-test: no scheme found" >&2
  exit 2
fi

DESTINATION=$(detect_destination)

echo "=== config ==="
echo "workspace: $WORKSPACE"
echo "scheme:    $SCHEME"
echo "dest:      $DESTINATION"
[[ -n "$FILTER" ]] && echo "filter:    $FILTER"

# ── Destination validation ────────────────────────────────────────────────────

SIM_NAME=$(/usr/bin/sed 's/.*name=//' <<< "$DESTINATION" | /usr/bin/sed 's/,.*//')
if ! xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -showdestinations 2>&1 | \
     /usr/bin/grep -q "name:$SIM_NAME"; then
  echo "" >&2
  echo "Destination not available: $DESTINATION" >&2
  echo "Run scripts/sim-list.sh to see available simulators." >&2
  exit 4
fi

# ── Skip UITests ──────────────────────────────────────────────────────────────

UI_TARGETS=$(xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -showTestPlans 2>/dev/null | \
             /usr/bin/grep UITests || true)
SKIP_FLAGS=""
for t in $UI_TARGETS; do
  SKIP_FLAGS="$SKIP_FLAGS -skip-testing:$t"
done
ONLY=""
[[ -n "$FILTER" ]] && ONLY="-only-testing:$FILTER"

# ── Run ───────────────────────────────────────────────────────────────────────

echo "=== running ==="
set +e
xcodebuild test \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  $SKIP_FLAGS \
  $ONLY \
  2>&1 | /usr/bin/tee "$LOG"
EXIT=$?
set -e

echo "=== summary ==="
PASSED=$(/usr/bin/grep -c "passed" "$LOG" 2>/dev/null || echo 0)
FAILED=$(/usr/bin/grep -c "failed" "$LOG" 2>/dev/null || echo 0)
if [[ $EXIT -eq 0 ]]; then
  echo "✅ Tests passed"
else
  echo "❌ Tests failed"
  /usr/bin/grep -E "(FAILED|error:|fatal)" "$LOG" | /usr/bin/head -20 || true
fi
/bin/rm -f "$LOG"
exit $EXIT
