# Hooks

This directory contains hook binaries that complement skills in this plugin.

## git-commit-reminder

**Script:** `hooks/git-commit-reminder.sh`

Emits a reminder after every `git commit` to update the Obsidian daily-note handover section. Reads the `Bash` tool input from stdin and only fires when the command starts with `git commit`; all other Bash invocations pass through silently.

### Install

1. Copy the script to `~/.claude/hooks/`:

   ```bash
   mkdir -p ~/.claude/hooks
   cp hooks/git-commit-reminder.sh ~/.claude/hooks/git-commit-reminder.sh
   chmod +x ~/.claude/hooks/git-commit-reminder.sh
   ```

2. Add the following to `~/.claude/settings.json` under `"hooks"` → `"PostToolUse"`:

   ```json
   {
     "matcher": "Bash",
     "hooks": [
       {
         "type": "command",
         "command": "bash $HOME/.claude/hooks/git-commit-reminder.sh",
         "statusMessage": "Checking for git commit handover..."
       }
     ]
   }
   ```
