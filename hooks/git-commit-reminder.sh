#!/bin/bash
# Only emit the handover reminder when the bash command was actually a git
# commit. Claude Code PostToolUse hooks receive tool input JSON on stdin.
#
# Match anchor: `git`, whitespace, `commit`, followed by end-of-string OR
# whitespace OR a closing quote. This rejects `git commit-reminder.sh`,
# `git checkout`, `git status`, and similar near-misses while accepting
# `git commit`, `git commit -m "..."`, and chained forms like `cmd && git
# commit -am "x"`.
input=$(cat)
if echo "$input" | grep -qE 'git[[:space:]]+commit($|[[:space:]"])'; then
    echo '{"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": "REMINDER: You just made a git commit. Per CLAUDE.md, you MUST now update the most recent daily note in ~/Developer/obsidian/daily/ with a ## Handover section documenting what was committed, why, what files changed, and what the UK team needs to know. Do not skip this step."}}'
fi
