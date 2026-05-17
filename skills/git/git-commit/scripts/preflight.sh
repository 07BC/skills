#!/usr/bin/env bash
# Pre-commit preflight: short status, full diff, and ticket extraction.
# Usage: preflight.sh
#
# Outputs three blocks separated by blank lines:
#   === status ===   short porcelain status
#   === diff ===     full unstaged + staged diff
#   === ticket ===   ticket key parsed from branch name, or empty line
#
# Exit non-zero if not inside a git work tree.

set -euo pipefail

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "Not inside a git repo." >&2
  exit 1
}

echo "=== status ==="
git status --short

echo
echo "=== diff ==="
git diff

echo
echo "=== ticket ==="
git rev-parse --abbrev-ref HEAD | /usr/bin/grep -oE '[A-Z]+-[0-9]+' | /usr/bin/head -1 || true
