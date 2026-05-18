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

  if [[ "$exists" == "true" ]]; then
    echo "already registered: $cmd ($event)"
    return
  fi

  local tmp
  tmp=$(mktemp "${SETTINGS}.XXXXXX")
  if jq --arg event "$event" --argjson entry "$entry" \
    '.hooks[$event] = ((.hooks[$event] // []) + [$entry])' \
    "$SETTINGS" > "$tmp"; then
    mv "$tmp" "$SETTINGS"
    echo "registered: $cmd ($event)"
  else
    rm -f "$tmp"
    echo "jq failed registering: $cmd ($event)" >&2
    return 1
  fi
}

# git-commit-reminder: fires on every Bash PostToolUse, filters git commit internally
upsert "PostToolUse" '{"matcher":"Bash","hooks":[{"type":"command","command":"bash $HOME/.claude/hooks/git-commit-reminder.sh","statusMessage":"Checking for git commit handover..."}]}'

# session-saver: periodic snapshots after every tool call
upsert "PostToolUse" '{"matcher":"","hooks":[{"type":"command","command":"$HOME/.claude/hooks/session-saver"}]}'

# session-saver: final save when session ends
upsert "Stop" '{"hooks":[{"type":"command","command":"$HOME/.claude/hooks/session-saver"}]}'
