#!/usr/bin/env bash
# Changed-line coverage gate for /spec-pipeline.
#
# Measures coverage of the lines THIS branch added/changed versus a base ref —
# not whole-file coverage of touched files (which punishes one-line edits to big
# files). It intersects xccov per-line hit data with the `+` lines of the diff.
#
# Usage:
#   coverage-gate.sh --xcresult <Run.xcresult> --base <ref> --floor <pct> \
#       [--root <repo-root>] [--exclude <glob>]... [--exclusions <file>]
#
#   --floor       integer percent, e.g. 90
#   --exclude     a path glob whose changed lines are ignored (repeatable),
#                 e.g. --exclude '*/Generated/*' --exclude '*Preview*'
#   --exclusions  file of newline-separated path globs (same effect as --exclude)
#
# Assumes Xcode's per-line format from:
#   xcrun xccov view --file <source> <xcresult>
# whose lines read like "   <lineno>: <count>" where <count> is an integer hit
# count, or "*" / absent for a non-executable line. Only executable changed
# lines count toward the denominator.
#
# Exit: 0 = at/above floor, 1 = below floor, 2 = bad invocation/tooling.

set -euo pipefail

die() { echo "coverage-gate: $*" >&2; exit 2; }

xcresult="" base="" floor="" root="."
excludes=()
exclusions_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --xcresult)   xcresult="${2:-}"; shift 2 ;;
    --base)       base="${2:-}"; shift 2 ;;
    --floor)      floor="${2:-}"; shift 2 ;;
    --root)       root="${2:-}"; shift 2 ;;
    --exclude)    excludes+=("${2:-}"); shift 2 ;;
    --exclusions) exclusions_file="${2:-}"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -n "$xcresult" && -e "$xcresult" ]] || die "missing or unreadable --xcresult"
[[ -n "$base" ]]  || die "--base <ref> is required"
[[ "$floor" =~ ^[0-9]+$ ]] || die "--floor must be an integer percent"
command -v xcrun >/dev/null 2>&1 || die "xcrun not found"

if [[ -n "$exclusions_file" && -f "$exclusions_file" ]]; then
  while IFS= read -r line; do
    line="${line%%#*}"; line="$(printf '%s' "$line" | xargs || true)"
    [[ -n "$line" ]] && excludes+=("$line")
  done < "$exclusions_file"
fi

excluded() {  # excluded <path> → 0 if it matches any exclude glob
  local p="$1" g
  for g in "${excludes[@]:-}"; do
    [[ -n "$g" ]] && [[ "$p" == $g ]] && return 0
  done
  return 1
}

# Swift files changed vs base (added/modified, not deleted).
changed_files="$(git -C "$root" diff --name-only --diff-filter=AM "$base"...HEAD -- '*.swift' || true)"
[[ -n "$changed_files" ]] || { echo "✅ COVERAGE OK — no changed Swift files."; exit 0; }

total_changed=0
total_covered=0
worst_report=""

for f in $changed_files; do
  if excluded "$f"; then
    worst_report+="   ~ ${f}: excluded"$'\n'
    continue
  fi

  # Added/modified NEW-file line numbers from a zero-context diff.
  added_lines="$(git -C "$root" diff --unified=0 "$base"...HEAD -- "$f" \
    | awk '
      /^@@/ {
        # @@ -a,b +c,d @@   → new-file hunk starts at c
        match($0, /\+[0-9]+/); n = substr($0, RSTART+1, RLENGTH-1) + 0; next
      }
      /^\+/ && !/^\+\+\+/ { print n; n++ }
      /^[ ]/ { n++ }
    ' || true)"
  [[ -z "$added_lines" ]] && continue

  # Per-line coverage for this file from the xcresult.
  # Map: lineno → hit count (integer). Non-executable lines are absent.
  cov="$(xcrun xccov view --file "$f" "$xcresult" 2>/dev/null || true)"
  [[ -n "$cov" ]] || { worst_report+="   ? ${f}: no coverage data (not in this xcresult)"$'\n'; continue; }

  # For each added line that is executable (present in cov), tally covered.
  file_changed=0 file_covered=0 misses=""
  for ln in $added_lines; do
    hit="$(printf '%s\n' "$cov" | awk -v L="$ln" '
      { gsub(/^[[:space:]]+/, "") }
      $0 ~ "^"L":" {
        c = $2
        if (c ~ /^[0-9]+$/) { print c; exit }   # executable line
      }')"
    [[ -z "$hit" ]] && continue   # non-executable changed line — skip
    file_changed=$((file_changed+1))
    if [[ "$hit" -gt 0 ]]; then
      file_covered=$((file_covered+1))
    else
      misses+="${ln} "
    fi
  done

  total_changed=$((total_changed+file_changed))
  total_covered=$((total_covered+file_covered))
  if [[ -n "$misses" ]]; then
    worst_report+="   ✗ ${f}: uncovered changed lines: ${misses}"$'\n'
  fi
done

if [[ "$total_changed" -eq 0 ]]; then
  echo "✅ COVERAGE OK — no executable changed lines to cover."
  exit 0
fi

pct=$(( total_covered * 100 / total_changed ))
echo "Changed-line coverage: ${total_covered}/${total_changed} = ${pct}% (floor ${floor}%)"
[[ -n "$worst_report" ]] && printf '%s' "$worst_report"

if [[ "$pct" -lt "$floor" ]]; then
  echo "⛔️ COVERAGE BELOW FLOOR — add tests for the uncovered changed lines, or list genuinely-untestable paths in the exclusions file."
  exit 1
fi
echo "✅ COVERAGE OK"
exit 0
