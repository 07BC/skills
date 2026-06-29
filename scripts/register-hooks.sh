#!/usr/bin/env bash
set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"

if [[ ! -f "$SETTINGS" ]]; then
  echo "settings.json not found at $SETTINGS" >&2
  exit 1
fi

# Upsert one hook entry into settings.json, keyed by command string.
# Idempotent: second run is a no-op. Never removes unrelated entries.
upsert() {
  local event="$1"
  local entry="$2"
  local cmd
  cmd=$(printf '%s' "$entry" | jq -r '.hooks[0].command')

  local exists
  exists=$(jq --arg event "$event" --arg cmd "$cmd" \
    '(.hooks[$event] // []) | map(select(.hooks[] | .command == $cmd)) | length > 0' \
    "$SETTINGS")

  local GREEN='\033[32m'; local DIM='\033[2m'; local RESET='\033[0m'

  if [[ "$exists" == "true" ]]; then
    printf "  ${DIM}↩  already registered: %s (%s)${RESET}\n" "$cmd" "$event"
    return
  fi

  local tmp
  tmp=$(mktemp "${SETTINGS}.XXXXXX")
  if jq --arg event "$event" --argjson entry "$entry" \
    '.hooks[$event] = ((.hooks[$event] // []) + [$entry])' \
    "$SETTINGS" > "$tmp"; then
    mv "$tmp" "$SETTINGS"
    printf "  ${GREEN}✅ registered: %s (%s)${RESET}\n" "$cmd" "$event"
  else
    rm -f "$tmp"
    printf "  ❌ jq failed registering: %s (%s)\n" "$cmd" "$event" >&2
    return 1
  fi
}

# Remove any hook entry under $event whose command contains $substr. Idempotent;
# used to evict stale registrations left behind by a renamed hook file.
prune() {
  local event="$1"
  local substr="$2"
  local present
  present=$(jq --arg event "$event" --arg substr "$substr" \
    '[(.hooks[$event] // [])[] | select([.hooks[].command | contains($substr)] | any)] | length' \
    "$SETTINGS")

  local YELLOW='\033[33m'; local DIM='\033[2m'; local RESET='\033[0m'
  if [[ "$present" == "0" ]]; then
    printf "  ${DIM}↩  nothing stale to prune: %s (%s)${RESET}\n" "$substr" "$event"
    return
  fi

  local tmp
  tmp=$(mktemp "${SETTINGS}.XXXXXX")
  if jq --arg event "$event" --arg substr "$substr" \
    '.hooks[$event] = ((.hooks[$event] // []) | map(select([.hooks[].command | contains($substr)] | any | not)))' \
    "$SETTINGS" > "$tmp"; then
    mv "$tmp" "$SETTINGS"
    printf "  ${YELLOW}🧹 pruned stale: %s (%s)${RESET}\n" "$substr" "$event"
  else
    rm -f "$tmp"
    printf "  ❌ jq failed pruning: %s (%s)\n" "$substr" "$event" >&2
    return 1
  fi
}

# Evict the orphaned loader left behind by the swift-engineer → swift-engineering rename.
prune "PreToolUse" "swift-engineer-loader.sh"

# git-commit-reminder: fires on every Bash PostToolUse, filters git commit internally
upsert "PostToolUse" '{"matcher":"Bash","hooks":[{"type":"command","command":"bash $HOME/.claude/hooks/git-commit-reminder.sh","statusMessage":"Checking for git commit handover..."}]}'

# swift-engineering-loader: fires on PreToolUse file edits, filters .swift internally
upsert "PreToolUse" '{"matcher":"Edit|Write|MultiEdit|mcp__xcode__XcodeWrite|mcp__xcode__XcodeUpdate","hooks":[{"type":"command","command":"bash $HOME/.claude/hooks/swift-engineering-loader.sh","statusMessage":"Loading Swift engineering chain..."}]}'

# swift-single-type-check: PreToolUse on Write, denies a .swift write with >1 top-level type
upsert "PreToolUse" '{"matcher":"Write","hooks":[{"type":"command","command":"bash $HOME/.claude/hooks/swift-single-type-check.sh","statusMessage":"Checking one-type-per-file..."}]}'
