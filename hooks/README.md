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
