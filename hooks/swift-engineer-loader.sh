#!/usr/bin/env bash
# PreToolUse on file-editing tools. If the edit targets a .swift file, inject
# context forcing the engineering chain to be loaded and applied.
input=$(cat)
path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty')
case "$path" in
  *.swift)
    cat <<'JSON'
{"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": "Editing Swift. You MUST be applying the engineering chain: load skill swift-engineer (it loads swift-style + swift-mv-guardian). All Swift must conform — MV architecture (no ObservableObject/@Published/ViewModel types), swift-style formatting, Swift 6 concurrency. If not yet loaded this session, load now and re-check this edit before proceeding."}}
JSON
    ;;
esac
