#!/usr/bin/env bash
# Detect the project formatter from config files; optionally apply it.
# Usage: find_formatter.sh [--apply]
#
# Without --apply: prints "<command>" or an empty line if no formatter found.
# With --apply:    prints the command being run to stderr, then runs it.
#
# Detection order:
#   .swiftformat              -> swiftformat .
#   .prettierrc / prettier.*  -> npx prettier --write .
#   rustfmt.toml              -> cargo fmt
#   pyproject.toml or .flake8 -> ruff format . (preferred) or black .

set -euo pipefail

APPLY="false"
if [ "${1:-}" = "--apply" ]; then APPLY="true"; fi

CMD=""
if [ -f .swiftformat ]; then
  CMD="swiftformat ."
elif [ -f .prettierrc ] || [ -f .prettierrc.json ] || [ -f .prettierrc.js ] \
  || [ -f prettier.config.js ] || [ -f prettier.config.cjs ] || [ -f prettier.config.mjs ]; then
  CMD="npx prettier --write ."
elif [ -f rustfmt.toml ]; then
  CMD="cargo fmt"
elif [ -f pyproject.toml ] || [ -f .flake8 ]; then
  if command -v ruff >/dev/null 2>&1; then
    CMD="ruff format ."
  elif command -v black >/dev/null 2>&1; then
    CMD="black ."
  fi
fi

if [ -z "$CMD" ]; then
  echo ""
  exit 0
fi

if [ "$APPLY" = "true" ]; then
  echo "running: $CMD" >&2
  $CMD
else
  echo "$CMD"
fi
