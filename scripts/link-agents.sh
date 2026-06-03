#!/usr/bin/env bash
set -euo pipefail

# Links all agents in this repo to ~/.claude/agents/ so they can be loaded by
# Claude Code. Each agent's .md file is symlinked directly.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.claude/agents"

mkdir -p "$DEST"

echo "== Agents =="

linked=0
pruned=0

while IFS= read -r sym; do
  target="$(readlink "$sym")"
  case "$target" in
    "$REPO"/agents/*)
      if [ ! -e "$sym" ]; then
        rm "$sym"
        printf "  pruned: %s\n" "$(basename "$sym")"
        pruned=$((pruned + 1))
      fi
      ;;
  esac
done < <(find "$DEST" -maxdepth 1 -type l)

if [ -d "$REPO/agents" ]; then
  while IFS= read -r -d '' agent_md; do
    name="$(basename "$agent_md")"
    target="$DEST/$name"

    if [ -e "$target" ] && [ ! -L "$target" ]; then
      rm -rf "$target"
    fi

    ln -sfn "$agent_md" "$target"
    printf "  %s\n" "$name"
    linked=$((linked + 1))
  done < <(find "$REPO/agents" -maxdepth 1 -name "*.md" -print0)
fi

echo "  [$linked linked, $pruned pruned]"
