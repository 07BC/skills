#!/usr/bin/env bash
# PreToolUse on file-editing tools. If the edit targets a .swift file, inject
# context forcing the engineering chain to be loaded and applied.
input=$(cat)
path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty')
case "$path" in
  *.swift)
    cat <<'JSON'
{"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": "Editing Swift. You MUST be applying the engineering chain: load skill swift-engineering (it loads swift-style and the project's architect skill — swift-mv-architecture or swift-mvvm-architecture per CLAUDE.md). All Swift must conform — the declared architecture (no ObservableObject/@Published in either; ViewModel types are forbidden in MV), swift-style formatting, Swift 6 concurrency. If not yet loaded this session, load now and re-check this edit before proceeding."}}
JSON
    ;;
esac
