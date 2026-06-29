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

## swift-single-type-check

**Script:** `hooks/swift-single-type-check.sh`

Enforces the "one type per file" hard rule deterministically, because prose alone (three skills + the engineering-chain loader) did not. Fires `PreToolUse` on the `Write` tool: if the written file ends in `.swift` and its content declares more than one top-level type (`struct`/`class`/`enum`/`actor`), it returns `permissionDecision: deny` so the write never lands, with a reason telling the model to split it one-type-per-file. `extension` on the primary type is the only exception; nested/indented types are not counted.

Scoped to `Write` only — it does not nag incremental `Edit`/`MultiEdit` of existing multi-type files. Xcode MCP write tools are not yet covered.

Run `bash hooks/swift-single-type-check.sh --self-test` to verify the detection heuristic.

### Install

Installed by `make hook` (symlink via `scripts/link-hooks.sh`, registration via `scripts/register-hooks.sh`). Registered under `"hooks"` → `"PreToolUse"`:

```json
{
  "matcher": "Write",
  "hooks": [
    {
      "type": "command",
      "command": "bash $HOME/.claude/hooks/swift-single-type-check.sh",
      "statusMessage": "Checking one-type-per-file..."
    }
  ]
}
```
