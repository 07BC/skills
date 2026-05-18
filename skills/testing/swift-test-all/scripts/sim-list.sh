#!/usr/bin/env bash
# List available iOS/tvOS/watchOS simulators with their OS versions.
# Marks the canonical simulator from CLAUDE.md with "← canonical".
#
# Usage: sim-list.sh [--platform <iOS|tvOS|watchOS|visionOS>]
#
# Exit 0 always (informational tool).

set -euo pipefail

PLATFORM_FILTER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform) PLATFORM_FILTER="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# Find canonical sim name from the nearest CLAUDE.md, walking up from cwd,
# then falling back to ~/Developer/CLAUDE.md.
CANONICAL=""
search_dir="$(pwd)"
while [[ "$search_dir" != "/" ]]; do
  if [[ -f "$search_dir/CLAUDE.md" ]]; then
    CANONICAL=$(/usr/bin/grep -oE "iPhone [0-9A-Za-z]+" "$search_dir/CLAUDE.md" 2>/dev/null | /usr/bin/head -1 || true)
    [[ -n "$CANONICAL" ]] && break
  fi
  search_dir="$(dirname "$search_dir")"
done
if [[ -z "$CANONICAL" && -f "$HOME/Developer/CLAUDE.md" ]]; then
  CANONICAL=$(/usr/bin/grep -oE "iPhone [0-9A-Za-z]+" "$HOME/Developer/CLAUDE.md" 2>/dev/null | /usr/bin/head -1 || true)
fi

echo "=== runtimes ==="
xcrun simctl list runtimes available 2>/dev/null \
  | /usr/bin/grep -E "^(iOS|tvOS|watchOS|visionOS)" \
  | /usr/bin/awk '{print $1, $2}' || true

echo "=== simulators ==="
# bash 3.2: regex with capture groups must be in a variable
runtime_pattern='^-- (.+) --$'
device_pattern='^[[:space:]]+([^(]+)[[:space:]]'
current_runtime=""
xcrun simctl list devices available 2>/dev/null | while IFS= read -r line; do
  if [[ "$line" =~ $runtime_pattern ]]; then
    current_runtime="${BASH_REMATCH[1]}"
    if [[ -n "$PLATFORM_FILTER" ]] && [[ "$current_runtime" != *"$PLATFORM_FILTER"* ]]; then
      current_runtime=""
    fi
    continue
  fi
  [[ -z "$current_runtime" ]] && continue
  [[ "$line" =~ $device_pattern ]] || continue
  sim_name=$(/usr/bin/printf '%s' "${BASH_REMATCH[1]}" | /usr/bin/sed 's/[[:space:]]*$//')
  marker=""
  [[ -n "$CANONICAL" ]] && [[ "$sim_name" == *"$CANONICAL"* ]] && marker=" <- canonical per CLAUDE.md"
  echo "$sim_name ($current_runtime)$marker"
done
