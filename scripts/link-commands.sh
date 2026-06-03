#!/usr/bin/env bash
set -euo pipefail

# Links all commands in this repo to ~/.claude/commands/ so they can be loaded by Claude Code.
# Each command's .md file is symlinked into ~/.claude/commands preserving the .md extension.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.claude/commands"

if [ -L "$DEST" ]; then
  resolved="$(readlink -f "$DEST")"
  case "$resolved" in
    "$REPO"|"$REPO"/*)
      echo "error: $DEST is a symlink into this repo ($resolved)." >&2
      echo "Remove it (rm \"$DEST\") and re-run; the script will recreate it as a real dir." >&2
      exit 1
      ;;
  esac
fi

mkdir -p "$DEST"

echo "== Commands =="

linked=0
pruned=0

# Prune stale symlinks pointing into this repo whose targets no longer exist.
while IFS= read -r sym; do
  target="$(readlink "$sym")"
  case "$target" in
    "$REPO"/commands/*)
      if [ ! -e "$sym" ]; then
        rm "$sym"
        printf "  pruned: %s\n" "$(basename "$sym")"
        pruned=$((pruned + 1))
      fi
      ;;
  esac
done < <(find "$DEST" -maxdepth 1 -type l)

while IFS= read -r -d '' cmd_md; do
  name="$(basename "$cmd_md")"
  target="$DEST/$name"

  if [ -e "$target" ] && [ ! -L "$target" ]; then
    rm -rf "$target"
  fi

  ln -sfn "$cmd_md" "$target"
  printf "  %s\n" "$name"
  linked=$((linked + 1))
done < <(find "$REPO/commands" -name "*.md" -not -path '*/deprecated/*' -print0)

echo "  [$linked linked, $pruned pruned]"
