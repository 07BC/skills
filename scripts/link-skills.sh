#!/usr/bin/env bash
set -euo pipefail

# Links all skills in this repo to ~/.claude/skills/ so they can be loaded by
# Claude Code. Each skill's parent directory is symlinked into ~/.claude/skills.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.claude/skills"

# If ~/.claude/skills is itself a symlink that resolves into this repo, abort:
# running the script would create symlinks back into the repo's own tree.
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

echo "== Skills =="

linked=0
pruned=0

# Prune stale symlinks pointing into this repo whose targets no longer exist.
while IFS= read -r sym; do
  target="$(readlink "$sym")"
  case "$target" in
    "$REPO"/skills/*)
      if [ ! -e "$sym" ]; then
        rm "$sym"
        printf "  pruned: %s\n" "$(basename "$sym")"
        pruned=$((pruned + 1))
      fi
      ;;
  esac
done < <(find "$DEST" -maxdepth 1 -type l)

while IFS= read -r -d '' skill_md; do
  src="$(dirname "$skill_md")"
  name="$(basename "$src")"
  target="$DEST/$name"

  if [ -e "$target" ] && [ ! -L "$target" ]; then
    rm -rf "$target"
  fi

  ln -sfn "$src" "$target"
  printf "  %s\n" "$name"
  linked=$((linked + 1))
done < <(find "$REPO/skills" -name SKILL.md -not -path '*/node_modules/*' -not -path '*/deprecated/*' -print0)

# Link shared _lib directories so scripts can resolve ../../_lib at runtime.
while IFS= read -r -d '' lib_dir; do
  ln -sfn "$lib_dir" "$DEST/_lib"
  printf "  _lib\n"
done < <(find "$REPO/skills" -type d -name "_lib" -not -path '*/deprecated/*' -print0)

echo "  [$linked linked, $pruned pruned]"
