#!/usr/bin/env bash
# Reads the spec_pipeline YAML fence from a CLAUDE.md and emits
# shell-eval-able SPEC_PIPELINE_* variables on stdout.
#
# Usage:
#   eval "$(scripts/read-pipeline-config.sh [path/to/CLAUDE.md])"
#
# Default path: ./CLAUDE.md
#
# Exits non-zero (with stderr message) if:
#   - CLAUDE.md not found
#   - no ```yaml fence containing top-level spec_pipeline: key
#   - any required field is missing (workspace, scheme, destination, tests_target)
#
# See ../SCHEMA.md for the canonical schema and parsing rules.
#
# Targets bash 3.2 (macOS default) — no associative arrays, no namerefs.

set -euo pipefail

claude_md="${1:-CLAUDE.md}"

if [[ ! -f "$claude_md" ]]; then
  echo "read-pipeline-config: ${claude_md} not found" >&2
  exit 2
fi

# Extract the first ```yaml fence that contains a top-level 'spec_pipeline:'.
yaml_block="$(awk '
  BEGIN { in_fence = 0; found = 0 }
  /^```yaml[[:space:]]*$/ {
    if (in_fence == 0) { in_fence = 1; buf = ""; next }
  }
  /^```[[:space:]]*$/ {
    if (in_fence == 1) {
      if (buf ~ /(^|\n)spec_pipeline:/) {
        printf "%s", buf
        found = 1
        exit
      }
      in_fence = 0
      buf = ""
      next
    }
  }
  {
    if (in_fence == 1) {
      buf = buf $0 "\n"
    }
  }
  END {
    if (!found) exit 3
  }
' "$claude_md")" || {
  echo "read-pipeline-config: no \`\`\`yaml fence containing 'spec_pipeline:' in ${claude_md}" >&2
  exit 3
}

# Parse simple key: value pairs under spec_pipeline:.
#   key: bare_word
#   key: "quoted string"
#   key: [a, b, c]    (inline list — used for context_docs)
parsed="$(printf '%s\n' "$yaml_block" | awk '
  BEGIN { in_block = 0 }
  /^spec_pipeline:[[:space:]]*$/ { in_block = 1; next }
  in_block && /^[^[:space:]]/ { in_block = 0; next }
  in_block && /^[[:space:]]+#/ { next }
  in_block && /^[[:space:]]+[A-Za-z_][A-Za-z0-9_]*:/ {
    line = $0
    sub(/^[[:space:]]+/, "", line)
    colon = index(line, ":")
    key = substr(line, 1, colon - 1)
    val = substr(line, colon + 1)
    sub(/^[[:space:]]+/, "", val)
    sub(/[[:space:]]+#.*$/, "", val)
    sub(/[[:space:]]+$/, "", val)
    upper = toupper(key)
    if (val ~ /^\[.*\]$/) {
      gsub(/^\[[[:space:]]*/, "", val)
      gsub(/[[:space:]]*\]$/, "", val)
      gsub(/[[:space:]]*,[[:space:]]*/, " ", val)
    }
    if (val ~ /^".*"$/) {
      val = substr(val, 2, length(val) - 2)
    }
    gsub(/'\''/, "'\''\\'\'''\''", val)
    printf "SPEC_PIPELINE_%s='\''%s'\''\n", upper, val
  }
')"

# Validate required keys
missing=""
for key in WORKSPACE SCHEME DESTINATION TESTS_TARGET; do
  if ! printf '%s\n' "$parsed" | grep -q "^SPEC_PIPELINE_${key}="; then
    missing="${missing} ${key}"
  fi
done

if [[ -n "$missing" ]]; then
  echo "read-pipeline-config: missing required keys:${missing}" >&2
  echo "see ../SCHEMA.md for the full schema" >&2
  exit 4
fi

# Apply defaults for optional keys (only when absent).
add_default() {
  local key="$1"
  local val="$2"
  if ! printf '%s\n' "$parsed" | grep -q "^SPEC_PIPELINE_${key}="; then
    parsed="${parsed}
SPEC_PIPELINE_${key}='${val}'"
  fi
}

add_default SPEC_DIR 'docs/specs'
add_default PLAN_DIR 'docs/plans'
add_default AUDIT_DIR 'AI/plans'
add_default CYCLE_BUDGET '3'

# Resolve $OBSIDIAN_VAULT for downstream convenience.
if [[ -z "${OBSIDIAN_VAULT:-}" ]]; then
  parsed="${parsed}
SPEC_PIPELINE_VAULT='${HOME}/Developer/obsidian'"
else
  parsed="${parsed}
SPEC_PIPELINE_VAULT='${OBSIDIAN_VAULT}'"
fi

printf '%s\n' "$parsed"
