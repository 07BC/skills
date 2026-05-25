#!/usr/bin/env bash
set -euo pipefail

# Links all commands in this repo to ~/.claude/commands/ so they can be loaded by Claude Code.
# Each command's .md file is symlinked into ~/.claude/agents with a flattened name.

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

find "$REPO/commands" -name "*.md" -not -path '*/deprecated/*' -print0 |
while IFS= read -r -d '' cmd_md; do
  name="$(basename "$cmd_md" .md)"
  target="$DEST/$name"

  if [ -e "$target" ] && [ ! -L "$target" ]; then
    rm -rf "$target"
  fi

  ln -sfn "$cmd_md" "$target"
  echo "linked $name -> $cmd_md"
done
