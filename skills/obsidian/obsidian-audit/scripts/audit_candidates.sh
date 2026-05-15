#!/usr/bin/env bash
# Emit absolute paths of files that are candidates for audit.
# Usage: audit_candidates.sh [optional-relative-or-absolute-path-inside-vault]
#
# Selection rules (any of these is sufficient to be a candidate):
#   1. File is inside the optional path arg (if provided).
#   2. Otherwise: file has no frontmatter, or has frontmatter but no `tags:` key,
#      or its mtime is newer than the timestamp recorded in .audit/state.json.
# Always excludes: templates/, assets/, .audit/, .obsidian/, .git/.

set -euo pipefail

VAULT="/Users/j.lesouef/Developer/obsidian"
STATE_FILE="$VAULT/.audit/state.json"

if [ ! -d "$VAULT" ]; then
  echo "Vault not found at $VAULT" >&2
  exit 1
fi

# Resolve scope
SCOPE_ARG="${1:-}"
if [ -n "$SCOPE_ARG" ]; then
  if [[ "$SCOPE_ARG" = /* ]]; then
    SCOPE="$SCOPE_ARG"
  else
    SCOPE="$VAULT/$SCOPE_ARG"
  fi
  if [ ! -e "$SCOPE" ]; then
    echo "Scope path not found: $SCOPE" >&2
    exit 1
  fi
else
  SCOPE="$VAULT"
fi

# Read last audit timestamp (epoch seconds) if available
LAST_EPOCH=0
if [ -f "$STATE_FILE" ]; then
  ISO=$(/usr/bin/awk -F'"' '/last_audit_iso/ { print $4; exit }' "$STATE_FILE" 2>/dev/null || echo "")
  if [ -n "$ISO" ]; then
    # macOS date: parse ISO 8601 to epoch
    LAST_EPOCH=$(/bin/date -j -f "%Y-%m-%dT%H:%M:%S%z" "$ISO" +%s 2>/dev/null || echo 0)
  fi
fi

EXCLUDES=(
  -path "$VAULT/templates" -prune -o
  -path "$VAULT/assets" -prune -o
  -path "$VAULT/.audit" -prune -o
  -path "$VAULT/.obsidian" -prune -o
  -path "$VAULT/.git" -prune -o
)

needs_audit() {
  local f="$1"
  # Read first 50 lines once
  local head
  head=$(/usr/bin/head -n 50 "$f" 2>/dev/null || true)
  # No frontmatter at all?
  if ! /usr/bin/printf '%s\n' "$head" | /usr/bin/grep -q '^---'; then
    return 0
  fi
  # Has frontmatter but no `tags:` key?
  local fm
  fm=$(/usr/bin/printf '%s\n' "$head" | /usr/bin/awk '/^---$/{c++; next} c==1{print} c>1{exit}')
  if ! /usr/bin/printf '%s\n' "$fm" | /usr/bin/grep -qE '^tags:'; then
    return 0
  fi
  # mtime newer than last audit?
  if [ "$LAST_EPOCH" -gt 0 ]; then
    local mtime
    mtime=$(/usr/bin/stat -f %m "$f")
    if [ "$mtime" -gt "$LAST_EPOCH" ]; then
      return 0
    fi
  else
    # No prior audit recorded — treat all files as candidates on first run.
    return 0
  fi
  return 1
}

# When scope is an explicit path, take all .md under it (still respecting excludes)
# When scope is the vault root, use needs_audit() to filter
if [ "$SCOPE" = "$VAULT" ]; then
  /usr/bin/find "$SCOPE" "${EXCLUDES[@]}" -type f -name '*.md' -print | while IFS= read -r f; do
    if needs_audit "$f"; then
      echo "$f"
    fi
  done
else
  /usr/bin/find "$SCOPE" "${EXCLUDES[@]}" -type f -name '*.md' -print
fi
