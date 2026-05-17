#!/bin/bash
# Only emit the handover reminder when the bash command was a git commit.
# Claude Code PostToolUse hooks receive tool input JSON on stdin.
input=$(cat)
if echo "$input" | grep -q '"git commit'; then
    echo '{"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": "REMINDER: You just made a git commit. Per CLAUDE.md, you MUST now update the most recent daily note in ~/Developer/obsidian/daily/ with a ## Handover section documenting what was committed, why, what files changed, and what the UK team needs to know. Do not skip this step."}}'
fi
