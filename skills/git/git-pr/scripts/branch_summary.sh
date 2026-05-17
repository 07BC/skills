#!/usr/bin/env bash
# Summarise the current branch's divergence from a base branch.
# Usage: branch_summary.sh [base-branch]   (default base: main)
#
# Outputs two blocks:
#   === commits (BASE..HEAD) ===
#   <oneline log>
#
#   === diffstat (BASE...HEAD) ===
#   <diff --stat>

set -euo pipefail

BASE="${1:-main}"

git rev-parse --verify "$BASE" >/dev/null 2>&1 || {
  echo "Base branch not found: $BASE" >&2
  exit 1
}

echo "=== commits ($BASE..HEAD) ==="
git log "$BASE..HEAD" --oneline

echo
echo "=== diffstat ($BASE...HEAD) ==="
git diff "$BASE...HEAD" --stat
