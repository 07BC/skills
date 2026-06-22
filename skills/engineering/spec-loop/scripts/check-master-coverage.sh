#!/usr/bin/env bash
#
# check-master-coverage.sh — assert every frozen master AC is covered by some child.
#
# The master-level companion to spec-pipeline's check-traceability.sh (which is
# per-child). spec-loop's completion oracle requires that every acceptance
# criterion declared on the master is claimed by at least one child's `covers:`.
# Decomposition is supposed to guarantee this; this script proves it before the
# loop calls the master complete.
#
# Usage:
#   check-master-coverage.sh --master-acs <file> --manifest <file>
#
#   --master-acs  file listing the master's frozen AC IDs. Accepts either bare
#                 IDs (one per line) or markdown list lines of the form
#                 `- **NAT-123-AC1** — text` (the master-issue / master-doc form).
#   --manifest    the children manifest emitted by resolve-children.sh:
#                 child_id<TAB>covers<TAB>depends_on<TAB>state
#                 where `covers` is a comma- or space-separated list of AC IDs.
#
# Exit 0 and prints "MASTER COVERAGE OK" when every master AC appears in the union
# of children's covers. Otherwise exit 1 and list the uncovered AC IDs.

set -euo pipefail

die() { printf 'check-master-coverage: %s\n' "$1" >&2; exit 2; }

master_acs=""
manifest=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --master-acs) master_acs="${2:-}"; shift 2 ;;
    --manifest)   manifest="${2:-}"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -n "$master_acs" && -f "$master_acs" ]] || die "--master-acs <file> is required and must exist"
[[ -n "$manifest" && -f "$manifest" ]] || die "--manifest <file> is required and must exist"

# Extract AC IDs from the master file. An AC ID matches <UPPER>-<num>-AC<num>.
master_ids="$(grep -oE '[A-Z][A-Z0-9]*-[0-9]+-AC[0-9]+' "$master_acs" | sort -u || true)"
[[ -n "$master_ids" ]] || die "no AC IDs (<PREFIX>-NNN-ACn) found in $master_acs"

# Union of all covers IDs across the manifest (column 2).
covered_ids="$(cut -f2 "$manifest" | grep -oE '[A-Z][A-Z0-9]*-[0-9]+-AC[0-9]+' | sort -u || true)"

# master_ids not present in covered_ids.
uncovered="$(comm -23 <(printf '%s\n' "$master_ids") <(printf '%s\n' "$covered_ids"))"

if [[ -n "$uncovered" ]]; then
  printf '❌ MASTER COVERAGE — master ACs no child covers:\n' >&2
  printf '   %s\n' $uncovered >&2
  exit 1
fi

printf 'MASTER COVERAGE OK — %d master AC(s) all covered\n' "$(printf '%s\n' "$master_ids" | wc -l | tr -d ' ')"
