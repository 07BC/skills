#!/usr/bin/env bash
set -euo pipefail

# Symlinks the entire agents/ folder from this repo to ~/.claude/agents.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.claude/agents"

BOLD='\033[1m'; CYAN='\033[1;36m'; GREEN='\033[32m'; RESET='\033[0m'

printf "${CYAN}${BOLD}🤖 Agents${RESET}\n"

if [ -d "$DEST" ] && [ ! -L "$DEST" ]; then
  rm -rf "$DEST"
elif [ -L "$DEST" ]; then
  rm "$DEST"
fi

ln -sfn "$REPO/agents" "$DEST"
printf "  ${GREEN}✅ linked: %s → %s${RESET}\n" "$DEST" "$REPO/agents"
