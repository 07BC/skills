#!/usr/bin/env bash
#
# render-progress.sh — render the committed master progress tracker (progress.md).
#
# A PURE formatter: it turns the master AC list + children manifest into markdown
# on stdout. spec-loop computes child done-ness from git (the source of truth)
# BEFORE calling this, writes it into the manifest's `state` column, then renders.
# Because the tracker is always re-derived from git, it cannot drift (decision 10).
#
# Usage:
#   render-progress.sh --master-key <key> --master-acs <file> --manifest <file> \
#       --sweeps-used <n> --max-sweeps <n> [--audit <path>]
#
#   --master-acs  master AC file (bare IDs or `- **ID** — text` lines)
#   --manifest    children manifest: child_id<TAB>covers<TAB>depends_on<TAB>state
#                 state ∈ pending | in-progress | done | parked[:reason]
#   --audit       optional path to the append-only audit log, linked in the footer
#
# Output is deterministic given identical inputs (no timestamps), so it is safe to
# commit on every child and produces a clean, reviewable diff.

set -euo pipefail

die() { printf 'render-progress: %s\n' "$1" >&2; exit 2; }

master_key="" master_acs="" manifest="" sweeps_used="" max_sweeps="" audit=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --master-key)  master_key="${2:-}"; shift 2 ;;
    --master-acs)  master_acs="${2:-}"; shift 2 ;;
    --manifest)    manifest="${2:-}"; shift 2 ;;
    --sweeps-used) sweeps_used="${2:-}"; shift 2 ;;
    --max-sweeps)  max_sweeps="${2:-}"; shift 2 ;;
    --audit)       audit="${2:-}"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -n "$master_key" ]] || die "--master-key is required"
[[ -n "$master_acs" && -f "$master_acs" ]] || die "--master-acs <file> is required and must exist"
[[ -n "$manifest" && -f "$manifest" ]] || die "--manifest <file> is required and must exist"
sweeps_used="${sweeps_used:-0}"
max_sweeps="${max_sweeps:-?}"

# State → status glyph.
glyph() {
  case "${1%%:*}" in
    done)        printf '✅ done' ;;
    in-progress) printf '🔄 in-progress' ;;
    parked)      printf '⛔️ parked' ;;
    *)           printf '⬜️ pending' ;;
  esac
}

# AC → covered? An AC is covered when it appears in some DONE child's covers.
done_covers="$(awk -F'\t' '$4 ~ /^done/ {print $2}' "$manifest" | grep -oE '[A-Z][A-Z0-9]*-[0-9]+-AC[0-9]+' | sort -u || true)"

ac_done() { grep -qxF "$1" <<<"$done_covers"; }

printf '# Master progress — %s\n\n' "$master_key"
printf '> Rendered from git branch state (commits + plan ✅). Do not edit by hand —\n'
printf '> spec-loop overwrites this each child from the source of truth.\n\n'
printf '**Sweeps used:** %s / %s\n\n' "$sweeps_used" "$max_sweeps"

# --- Children -------------------------------------------------------------
printf '## Child specs\n\n'
printf '| Child | depends_on | covers | Status |\n'
printf '|---|---|---|---|\n'
# Parse with cut, not `read` into fields: tab is IFS-whitespace, so `read` would
# collapse empty columns (an empty depends_on) and misalign the row.
while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  child_id="$(cut -f1 <<<"$line")"
  covers="$(cut -f2 <<<"$line")"
  depends_on="$(cut -f3 <<<"$line")"
  state="$(cut -f4 <<<"$line")"
  reason=""
  [[ "$state" == parked:* ]] && reason=" — ${state#parked:}"
  printf '| %s | %s | %s | %s%s |\n' \
    "$child_id" "${depends_on:-—}" "${covers:-—}" "$(glyph "$state")" "$reason"
done < "$manifest"
printf '\n'

# --- Master acceptance criteria ------------------------------------------
printf '## Master acceptance criteria\n\n'
printf '| AC | Status |\n'
printf '|---|---|\n'
grep -oE '[A-Z][A-Z0-9]*-[0-9]+-AC[0-9]+' "$master_acs" | sort -u | while read -r ac; do
  if ac_done "$ac"; then status='✅ covered & done'; else status='⬜️ pending'; fi
  printf '| %s | %s |\n' "$ac" "$status"
done
printf '\n'

# --- Parked questions -----------------------------------------------------
parked="$(awk -F'\t' '$4 ~ /^parked/ {print "- **" $1 "** — " substr($4, index($4, ":")+1)}' "$manifest" || true)"
if [[ -n "$parked" ]]; then
  printf '## Parked children (need a human)\n\n%s\n\n' "$parked"
fi

# --- Footer ---------------------------------------------------------------
if [[ -n "$audit" ]]; then
  printf -- '---\n\nAudit log: `%s`\n' "$audit"
fi
