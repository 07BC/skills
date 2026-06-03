#!/usr/bin/env bash
set -euo pipefail

# Symlinks all hook scripts in this repo to ~/.claude/hooks/.
# Registration into settings.json is handled by register-hooks.sh.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.claude/hooks"

mkdir -p "$DEST"

BOLD='\033[1m'; CYAN='\033[1;36m'; GREEN='\033[32m'; RESET='\033[0m'

printf "${CYAN}${BOLD}🪝 Hooks${RESET}\n"

linked=0

for f in "$REPO/hooks"/*; do
  name="$(basename "$f")"
  case "$name" in *.md|*.json|README*) continue;; esac
  ln -sfn "$f" "$DEST/$name"
  printf "  %s\n" "$name"
  linked=$((linked + 1))
done

printf "  ${GREEN}✅ %d linked${RESET}\n" "$linked"
