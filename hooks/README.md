# Hooks

This directory contains hook binaries that complement skills in this plugin.

## session-saver

**Binary:** `hooks/session-saver` (arm64 Mach-O)

Automatically saves Claude Code session transcripts to `~/raw/sessions/` so the `session-saver` skill can later process them into durable knowledge entries.

### Install

1. Copy the binary to `~/.claude/hooks/`:

   ```bash
   mkdir -p ~/.claude/hooks
   cp hooks/session-saver ~/.claude/hooks/session-saver
   chmod +x ~/.claude/hooks/session-saver
   ```

2. Add the following to `~/.claude/settings.json` under `"hooks"`:

   ```json
   "hooks": {
     "PostToolUse": [
       {
         "matcher": "",
         "hooks": [
           {
             "type": "command",
             "command": "$HOME/.claude/hooks/session-saver"
           }
         ]
       }
     ],
     "Stop": [
       {
         "hooks": [
           {
             "type": "command",
             "command": "$HOME/.claude/hooks/session-saver"
           }
         ]
       }
     ]
   }
   ```

The `PostToolUse` entry with an empty `matcher` fires after every tool call (periodic snapshots). The `Stop` entry fires when the session ends (final save). Together they ensure no transcript is lost.

Sessions are written to `~/raw/sessions/` and named by session ID. The `session-saver` skill (in `skills/obsidian/session-saver/`) processes these files into `~/raw/knowledge/`.

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
