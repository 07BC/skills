#!/usr/bin/env bash
# Produces a canonical kebab-case spec ID from an input source.
#
# Usage:
#   derive-spec-id.sh --from-jira <KEY> <summary>
#   derive-spec-id.sh --from-spec <path/to/spec.md>
#   derive-spec-id.sh --from-prompt <free-form prompt text>
#
# Output (stdout): single line, kebab-case ID, no leading/trailing dashes.
#
# Slugging rules:
#   - lowercase
#   - non-alphanumeric runs collapse to a single hyphen
#   - leading/trailing hyphens stripped
#   - truncated to 60 chars max (excluding any ticket prefix)
#
# Spec ID formats:
#   --from-jira NAT-1234 "Fix focus timing"  -> NAT-1234-fix-focus-timing
#   --from-spec docs/specs/auth-refactor.md  -> auth-refactor
#   --from-prompt "Build sharing menu"       -> build-sharing-menu

set -euo pipefail

slugify() {
  # Stdin: free text. Stdout: kebab-case slug.
  awk '
  {
    s = tolower($0)
    gsub(/[^a-z0-9]+/, "-", s)
    gsub(/^-+/, "", s)
    gsub(/-+$/, "", s)
    if (length(s) > 60) s = substr(s, 1, 60)
    gsub(/-+$/, "", s)
    print s
  }
  '
}

if [[ $# -lt 2 ]]; then
  echo "derive-spec-id: usage: derive-spec-id.sh --from-jira <KEY> <summary> | --from-spec <path> | --from-prompt <text>" >&2
  exit 2
fi

mode="$1"
shift

case "$mode" in
  --from-jira)
    if [[ $# -lt 2 ]]; then
      echo "derive-spec-id: --from-jira requires <KEY> <summary>" >&2
      exit 2
    fi
    key="$1"
    shift
    # Remaining args form the summary; combine and slug.
    summary_slug="$(printf '%s' "$*" | slugify)"
    if [[ -z "$summary_slug" ]]; then
      printf '%s\n' "$key"
    else
      printf '%s-%s\n' "$key" "$summary_slug"
    fi
    ;;

  --from-spec)
    if [[ $# -lt 1 ]]; then
      echo "derive-spec-id: --from-spec requires <path>" >&2
      exit 2
    fi
    path="$1"
    base="$(basename "$path")"
    # Strip trailing .md (or other markdown ext) if present.
    base="${base%.md}"
    base="${base%.markdown}"
    slug="$(printf '%s' "$base" | slugify)"
    if [[ -z "$slug" ]]; then
      echo "derive-spec-id: empty spec id after slugging '${path}'" >&2
      exit 3
    fi
    printf '%s\n' "$slug"
    ;;

  --from-prompt)
    if [[ $# -lt 1 ]]; then
      echo "derive-spec-id: --from-prompt requires <text>" >&2
      exit 2
    fi
    slug="$(printf '%s' "$*" | slugify)"
    if [[ -z "$slug" ]]; then
      echo "derive-spec-id: empty spec id from prompt" >&2
      exit 3
    fi
    printf '%s\n' "$slug"
    ;;

  *)
    echo "derive-spec-id: unknown mode '${mode}' (expected --from-jira | --from-spec | --from-prompt)" >&2
    exit 2
    ;;
esac
