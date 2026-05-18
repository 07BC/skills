#!/usr/bin/env bash
# diff-surface.sh — list files and Swift symbols touched by current changes.
#
# Usage:
#   diff-surface.sh                  # working tree (unstaged + staged) vs HEAD
#   diff-surface.sh --base <ref>     # branch comparison: <ref>...HEAD
#   diff-surface.sh --staged         # staged only
#
# Output (stdout):
#   FILES:
#     <file>
#     ...
#   SYMBOLS:
#     <file>:<line>  <kind> <name>
#     ...
#
# Kinds: func | class | struct | enum | actor | protocol | extension | var | let | typealias
#
# Symbols are extracted heuristically from added/modified lines. False positives
# are possible (e.g. a function in a comment). Treat as a starting list, not an
# exhaustive one.

set -euo pipefail

MODE="worktree"
BASE_REF=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      MODE="branch"
      BASE_REF="${2:-}"
      [[ -z "$BASE_REF" ]] && { echo "error: --base requires a ref" >&2; exit 2; }
      shift 2
      ;;
    --staged)
      MODE="staged"
      shift
      ;;
    -h|--help)
      sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "error: unknown arg $1" >&2
      exit 2
      ;;
  esac
done

case "$MODE" in
  worktree)  DIFF_CMD=(git diff HEAD) ;;
  staged)    DIFF_CMD=(git diff --cached) ;;
  branch)    DIFF_CMD=(git diff "${BASE_REF}...HEAD") ;;
esac

# Get touched files. Use --name-only to avoid parsing the diff body.
FILES=$("${DIFF_CMD[@]}" --name-only -- '*.swift' 2>/dev/null || true)

if [[ -z "$FILES" ]]; then
  echo "FILES:"
  echo "  (none)"
  echo "SYMBOLS:"
  echo "  (none)"
  exit 0
fi

echo "FILES:"
while IFS= read -r f; do
  [[ -n "$f" ]] && echo "  $f"
done <<< "$FILES"

echo "SYMBOLS:"

# For each modified .swift file, scan added/modified lines for declarations.
# We use the unified diff so we have line numbers in the *new* file.
# POSIX awk (BSD on macOS): match() only sets RSTART/RLENGTH, no array capture.
# Use grep/sed for token extraction inside awk instead.

while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  [[ ! -f "$f" ]] && continue

  "${DIFF_CMD[@]}" -- "$f" 2>/dev/null | awk -v file="$f" '
    function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    /^@@/ {
      # @@ -old,oldcount +new,newcount @@
      # Extract the +N portion.
      s = $0
      sub(/^.*\+/, "", s)
      sub(/[, ].*$/, "", s)
      newline = s + 0
      in_hunk = 1
      next
    }
    in_hunk && /^\+\+\+/ { next }
    in_hunk && /^\+/ {
      line = substr($0, 2)
      stripped = trim(line)
      # Strip leading modifiers (access level, attributes, decorators).
      orig = stripped
      while (match(stripped, /^(public|private|internal|fileprivate|open|static|class|final|override|mutating|nonisolated|convenience|required|dynamic|@[A-Za-z_][A-Za-z0-9_]*(\([^)]*\))?)[[:space:]]+/)) {
        stripped = substr(stripped, RSTART + RLENGTH)
      }
      # Now look for kind + name.
      if (match(stripped, /^(func|class|struct|enum|actor|protocol|extension|var|let|typealias)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/)) {
        decl = substr(stripped, RSTART, RLENGTH)
        # Split kind and name on whitespace.
        n = split(decl, parts, /[[:space:]]+/)
        kind = parts[1]
        name = parts[2]
        # Function names may include "(" — strip everything from that point.
        sub(/\(.*$/, "", name)
        printf "  %s:%d  %s %s\n", file, newline, kind, name
      }
      newline++
      next
    }
    in_hunk && /^ / { newline++; next }
    # Removed lines (^-) do not advance the new-file line counter.
  '
done <<< "$FILES"
