#!/usr/bin/env bash
# First-pass test coverage heuristic: name-match production types against test files.
# False positives and negatives are expected — for real coverage use xcrun xccov.
#
# Usage: test-gap.sh <prod-dir> <test-dir>
#
# Exit 0 always (reporting tool).

set -euo pipefail

PROD="${1:?prod dir required}"
TEST_DIR="${2:?test dir required}"

[ -d "$PROD" ]     || { echo "Prod dir not found: $PROD" >&2; exit 1; }
[ -d "$TEST_DIR" ] || { echo "Test dir not found: $TEST_DIR" >&2; exit 1; }

tested=0
total=0

echo "=== test gap ==="
while IFS= read -r f; do
  ((total++))
  name=$(/usr/bin/basename "$f" .swift)
  if /usr/bin/grep -rlq "\\b${name}\\b" "$TEST_DIR" --include='*Tests.swift' 2>/dev/null; then
    echo "TESTED $f"
    ((tested++))
  else
    echo "GAP    $f"
  fi
done < <(/usr/bin/find "$PROD" -name '*.swift' \
    -not -path '*/Resources/*' \
    -not -name '*+Generated.swift' \
  | /usr/bin/sort)

echo "=== summary ==="
echo "$tested/$total covered (name-match heuristic — see swift-audit SKILL.md for caveats)"
