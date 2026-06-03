#!/usr/bin/env bash
set -euo pipefail

# Symlinks all hook scripts in this repo to ~/.claude/hooks/.
# Registration into settings.json is handled by register-hooks.sh.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.claude/hooks"

mkdir -p "$DEST"

echo "== Hooks =="

linked=0

for f in "$REPO/hooks"/*; do
  name="$(basename "$f")"
  case "$name" in *.md|*.json|README*) continue;; esac
  ln -sfn "$f" "$DEST/$name"
  printf "  %s\n" "$name"
  linked=$((linked + 1))
done

echo "  [$linked linked]"
