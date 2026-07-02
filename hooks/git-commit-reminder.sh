#!/bin/bash
# Only emit the handover reminder when the bash command was actually a git
# commit. Claude Code PostToolUse hooks receive tool input JSON on stdin,
# which also carries the Bash tool's "description" field and its captured
# tool_response output — both of which can innocently contain the words
# "git" and "commit" (e.g. a `git log` call described as "Show recent git
# commit history", or `git status` output like "nothing to commit"). Grepping
# the raw JSON blob false-positives on those. Instead, extract only
# tool_input.command and match against that.
#
# Match anchor: `git`, whitespace, `commit`, followed by end-of-string OR
# whitespace OR a closing quote. This rejects `git commit-reminder.sh`,
# `git checkout`, `git status`, and similar near-misses while accepting
# `git commit`, `git commit -m "..."`, and chained forms like `cmd && git
# commit -am "x"`.
input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')
if echo "$command" | grep -qE 'git[[:space:]]+commit($|[[:space:]"])'; then
    echo '{"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": "REMINDER: You just made a git commit. Append a ## Handover section to TODAY'\''s Obsidian daily note using the CLI: obsidian daily:append content=\"...\". Do NOT find or edit the file manually and do NOT use a hardcoded path — the CLI resolves the correct note for today (vault uses nested YYYY/MM-MMM/YY-MM-D.md format, not a flat daily/ folder). Document: what was committed, why, what files changed, UK team impact. Do not skip this step."}}'
fi
