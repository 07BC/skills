#!/usr/bin/env bash
# find-callers.sh — find call/reference sites for a symbol across the repo.
#
# Usage:
#   find-callers.sh <symbol> [<root>]
#   find-callers.sh <symbol1> <symbol2> ... [--root <dir>]
#
# Examples:
#   find-callers.sh handleBackground
#   find-callers.sh VODPlayerViewModel --root Chagi
#
# Output (stdout):
#   ## symbol: <name>  (matches: N)
#     <file>:<line>: <context line>
#     ...
#
# - Excludes the apparent definition site (line containing `func <name>`,
#   `class <name>`, etc.) to avoid noise.
# - Uses ripgrep when available, falls back to grep -rn.
# - Searches Swift files by default. Override with FIND_CALLERS_GLOB env var
#   (e.g. FIND_CALLERS_GLOB='*.kt' for Kotlin).
#
# Heuristic only — does not understand scope, shadowing, or overloads. Treat
# matches as candidates to read, not authoritative call sites.

set -euo pipefail

GLOB="${FIND_CALLERS_GLOB:-*.swift}"
ROOT=""
SYMBOLS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT="${2:-}"
      [[ -z "$ROOT" ]] && { echo "error: --root requires a directory" >&2; exit 2; }
      shift 2
      ;;
    -h|--help)
      sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "error: unknown flag $1" >&2
      exit 2
      ;;
    *)
      SYMBOLS+=("$1")
      shift
      ;;
  esac
done

# If positional args include something that looks like a path and no --root was given,
# treat the last arg as the root for backwards-compat with the simpler form.
# (bash 3.2-safe — no negative array subscripts.)
if [[ -z "$ROOT" && ${#SYMBOLS[@]} -ge 2 ]]; then
  LAST_IDX=$((${#SYMBOLS[@]} - 1))
  LAST="${SYMBOLS[$LAST_IDX]}"
  if [[ -d "$LAST" ]]; then
    ROOT="$LAST"
    unset "SYMBOLS[$LAST_IDX]"
    SYMBOLS=("${SYMBOLS[@]}")  # re-pack to remove the hole
  fi
fi

ROOT="${ROOT:-.}"

[[ ${#SYMBOLS[@]} -eq 0 ]] && { echo "error: need at least one symbol" >&2; exit 2; }
[[ ! -d "$ROOT" ]] && { echo "error: root $ROOT is not a directory" >&2; exit 2; }

# Pick search tool.
if command -v rg >/dev/null 2>&1; then
  search() {
    local sym="$1"
    rg --line-number --no-heading --color=never --glob "$GLOB" \
       -e "\\b${sym}\\b" "$ROOT" 2>/dev/null || true
  }
else
  search() {
    local sym="$1"
    grep -rn --include="$GLOB" -E "\\b${sym}\\b" "$ROOT" 2>/dev/null || true
  }
fi

# Definition-line detector: lines that declare this symbol.
is_definition() {
  local sym="$1"
  local content="$2"
  # Definition prefixes for Swift: func, class, struct, enum, actor, protocol, var, let, typealias
  if echo "$content" | grep -qE "\\b(func|class|struct|enum|actor|protocol|var|let|typealias)[[:space:]]+${sym}\\b"; then
    return 0
  fi
  # Extensions on this type
  if echo "$content" | grep -qE "\\bextension[[:space:]]+${sym}\\b"; then
    return 0
  fi
  return 1
}

for sym in "${SYMBOLS[@]}"; do
  RESULTS=$(search "$sym")
  COUNT=0
  TMP=$(mktemp)
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # Split file:line:content
    file=$(echo "$line" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    content=$(echo "$line" | cut -d: -f3-)
    if is_definition "$sym" "$content"; then
      continue
    fi
    echo "  ${file}:${lineno}: ${content}" >> "$TMP"
    COUNT=$((COUNT + 1))
  done <<< "$RESULTS"

  echo "## symbol: ${sym}  (matches: ${COUNT})"
  if [[ "$COUNT" -gt 0 ]]; then
    cat "$TMP"
  else
    echo "  (no callers found)"
  fi
  echo
  rm -f "$TMP"
done
