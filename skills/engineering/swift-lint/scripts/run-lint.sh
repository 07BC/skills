#!/usr/bin/env bash
# Find the nearest .swiftlint.yml and run swiftlint from its directory.
#
# Usage: run-lint.sh [path]
#   path: directory or file to lint (default: cwd)
#
# Exits with swiftlint's exit code.

set -euo pipefail

TARGET="${1:-.}"
TARGET="$(cd "$TARGET" 2>/dev/null && pwd || /usr/bin/dirname "$(realpath "$TARGET")")"

# Walk up from TARGET to find nearest .swiftlint.yml
CONFIG=""
dir="$TARGET"
while [[ "$dir" != "/" ]]; do
  if [[ -f "$dir/.swiftlint.yml" ]]; then
    CONFIG="$dir/.swiftlint.yml"
    break
  fi
  dir="$(dirname "$dir")"
done

if [[ -z "$CONFIG" ]]; then
  echo "No .swiftlint.yml found in $TARGET or any parent directory." >&2
  exit 2
fi

CONFIG_DIR="$(dirname "$CONFIG")"

echo "=== config ==="
echo "$CONFIG"
echo "=== violations ==="

cd "$CONFIG_DIR"
set +e
swiftlint lint --config "$CONFIG" "$TARGET" 2>&1
LINT_EXIT=$?
set -e

echo "=== summary ==="
if [[ $LINT_EXIT -eq 0 ]]; then
  echo "✅ No violations"
else
  echo "⚠️  Violations found (exit $LINT_EXIT)"
fi
exit $LINT_EXIT
