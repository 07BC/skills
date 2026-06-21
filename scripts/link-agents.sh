#!/usr/bin/env bash
set -euo pipefail

# Links all agents in this repo to ~/.claude/agents/ so they can be loaded by Claude Code.
# Each agent's .md file is symlinked flat into ~/.claude/agents/.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.claude/agents"

# If ~/.claude/agents is a whole-directory symlink into this repo, convert it to a real dir.
if [ -L "$DEST" ]; then
  resolved="$(readlink -f "$DEST")"
  case "$resolved" in
    "$REPO"/agents)
      rm "$DEST"
      mkdir -p "$DEST"
      ;;
    "$REPO"/agents/*)
      echo "error: $DEST is a symlink into this repo ($resolved)." >&2
      echo "Remove it (rm \"$DEST\") and re-run." >&2
      exit 1
      ;;
  esac
fi

mkdir -p "$DEST"

BOLD='\033[1m'; CYAN='\033[1;36m'; YELLOW='\033[33m'; GREEN='\033[32m'; RESET='\033[0m'

printf "${CYAN}${BOLD}🤖 Agents${RESET}\n"

linked=0
pruned=0

# Prune stale symlinks pointing into this repo whose targets no longer exist.
while IFS= read -r sym; do
  target="$(readlink "$sym")"
  case "$target" in
    "$REPO"/agents/*)
      if [ ! -e "$sym" ]; then
        rm "$sym"
        printf "  ${YELLOW}🗑️  pruned: %s${RESET}\n" "$(basename "$sym")"
        pruned=$((pruned + 1))
      fi
      ;;
  esac
done < <(find "$DEST" -maxdepth 1 -type l)

while IFS= read -r -d '' agent_md; do
  name="$(basename "$agent_md")"
  target="$DEST/$name"

  if [ -e "$target" ] && [ ! -L "$target" ]; then
    rm -rf "$target"
  fi

  ln -sfn "$agent_md" "$target"
  printf "  %s\n" "$name"
  linked=$((linked + 1))
done < <(find "$REPO/agents" -name "*.md" -not -path '*/deprecated/*' -print0)

printf "  ${GREEN}✅ %d linked, %d pruned${RESET}\n" "$linked" "$pruned"
