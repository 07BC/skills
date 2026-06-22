#!/usr/bin/env bash
# Child-scope traceability gate for /spec-pipeline.
#
# Proves, deterministically, that one child spec's IDs line up across the
# spine: master AC IDs (frozen, declared in the child's `covers:`) → tasks
# (`implements:`) → tests (`// AC:`). Master-scope coverage (every master AC
# covered by SOME child) is NOT checked here — that reads GitHub and lives in
# /spec-decomposition. This gate is local to one child's worktree.
#
# Usage:
#   check-traceability.sh --spec <child-spec.md> --plan <plan.md> \
#       [--tests-dir <dir> ...] [--exclusions <file>] [--scope-only]
#
#   --scope-only   run checks 1 and 2 only (scope-creep + unplanned), skip the
#                  test check. Use pre-implementation (drift gate, Step 5.6) when
#                  no tests exist yet. --tests-dir is then optional.
#
# Conventions parsed:
#   - Child spec frontmatter:  covers: [NAT-123-AC1, NAT-123-AC2]
#   - Plan task block:         implements: [NAT-123-AC1]   (one per task)
#   - Test annotation:         // AC: NAT-123-AC1, NAT-123-AC2
#   - Exclusions file:         one AC ID per line, optional "# reason" after it.
#                              An excluded AC is exempt from the test check.
#
# Checks (any failure ⇒ non-zero exit, report on stdout):
#   1. SCOPE CREEP — every `implements:` ID is in the child's `covers:` set.
#   2. UNPLANNED   — every `covers:` ID is implemented by ≥1 task.
#   3. UNTESTED    — every `covers:` ID has ≥1 test annotation, OR is excluded.
#
# Exit: 0 = clean, 1 = one or more gate failures, 2 = bad invocation.

set -euo pipefail

die() { echo "check-traceability: $*" >&2; exit 2; }

spec="" plan="" exclusions="" scope_only=0
tests_dirs=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --spec)       spec="${2:-}"; shift 2 ;;
    --plan)       plan="${2:-}"; shift 2 ;;
    --tests-dir)  tests_dirs+=("${2:-}"); shift 2 ;;
    --exclusions) exclusions="${2:-}"; shift 2 ;;
    --scope-only) scope_only=1; shift ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -n "$spec" && -f "$spec" ]] || die "missing or unreadable --spec"
[[ -n "$plan" && -f "$plan" ]] || die "missing or unreadable --plan"
[[ "$scope_only" -eq 1 || ${#tests_dirs[@]} -gt 0 ]] || \
  die "at least one --tests-dir is required (or pass --scope-only)"

# --- extract ID lists into newline-separated, de-duplicated sets ---------

# IDs look like ABC-123-AC4 (ticket prefix, number, -AC, number).
id_pattern='[A-Z][A-Z0-9]*-[0-9]+-AC[0-9]+'

# covers: from the spec frontmatter (first --- … --- block). Inline list form.
covers="$(awk '
  /^---[[:space:]]*$/ { fence++; next }
  fence==1 && /^[[:space:]]*covers[[:space:]]*:/ { print }
' "$spec" | grep -oE "$id_pattern" | sort -u || true)"

# implements: from anywhere in the plan (one per task block).
implements="$(grep -hoE "implements[[:space:]]*:[^]]*" "$plan" 2>/dev/null \
  | grep -oE "$id_pattern" | sort -u || true)"

# // AC: annotations across every test directory (skipped under --scope-only).
tested=""
if [[ "$scope_only" -eq 0 ]]; then
  tested="$(grep -rhoE "//[[:space:]]*AC:[^/]*" "${tests_dirs[@]}" 2>/dev/null \
    | grep -oE "$id_pattern" | sort -u || true)"
fi

# excluded IDs (optional).
excluded=""
if [[ -n "$exclusions" && -f "$exclusions" ]]; then
  excluded="$(grep -oE "$id_pattern" "$exclusions" | sort -u || true)"
fi

[[ -n "$covers" ]] || die "child spec declares no covers: AC IDs — cannot gate"

# --- helpers --------------------------------------------------------------

# not_in <candidate-set> <reference-set>  → lines in candidate absent from ref
not_in() {
  comm -23 <(printf '%s\n' "$1" | sed '/^$/d' | sort -u) \
           <(printf '%s\n' "$2" | sed '/^$/d' | sort -u)
}

fail=0
report=""

# 1. SCOPE CREEP — implements ∉ covers
creep="$(not_in "$implements" "$covers")"
if [[ -n "$creep" ]]; then
  fail=1
  report+=$'\n❌ SCOPE CREEP — tasks implement AC IDs not in the child covers set:\n'
  report+="$(printf '   - %s\n' $creep)"$'\n'
fi

# 2. UNPLANNED — covers ∉ implements
unplanned="$(not_in "$covers" "$implements")"
if [[ -n "$unplanned" ]]; then
  fail=1
  report+=$'\n❌ UNPLANNED — covered AC IDs no task implements:\n'
  report+="$(printf '   - %s\n' $unplanned)"$'\n'
fi

# 3. UNTESTED — covers ∉ (tested ∪ excluded). Skipped under --scope-only.
if [[ "$scope_only" -eq 0 ]]; then
  tested_or_excluded="$(printf '%s\n%s\n' "$tested" "$excluded" | sed '/^$/d' | sort -u)"
  untested="$(not_in "$covers" "$tested_or_excluded")"
  if [[ -n "$untested" ]]; then
    fail=1
    report+=$'\n❌ UNTESTED — covered AC IDs with no // AC: test annotation (and not excluded):\n'
    report+="$(printf '   - %s\n' $untested)"$'\n'
  fi
fi

if [[ "$fail" -eq 0 ]]; then
  n="$(printf '%s\n' "$covers" | grep -c .)"
  if [[ "$scope_only" -eq 1 ]]; then
    echo "✅ TRACEABILITY OK (scope-only) — ${n} AC(s): no scope creep, every AC planned."
  else
    echo "✅ TRACEABILITY OK — ${n} AC(s): every AC implemented and tested (or excluded)."
  fi
  exit 0
fi

echo "⛔️ TRACEABILITY FAILED${report}"
exit 1
