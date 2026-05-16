#!/usr/bin/env bash
# Verify the Obsidian vault is a git repo with a clean working tree.
# Usage: vault_preconditions.sh
#
# Exits 0 if OK. Prints diagnostic to stderr and exits non-zero on:
#   - vault directory missing
#   - vault is not a git repo
#   - vault has uncommitted changes (audit diff would be muddied)
#
# VAULT env defaults to "$HOME/raw" (matches the SKILL.md prose).
#
# CANONICAL COPY. Duplicates live at:
#   skills/obsidian/obsidian-rollover/scripts/vault_preconditions.sh
#   skills/obsidian/daily-notes/scripts/vault_preconditions.sh
#   skills/obsidian/obsidian-learn/scripts/vault_preconditions.sh
#   skills/obsidian/session-saver/scripts/vault_preconditions.sh
# Keep all five in sync.

set -euo pipefail

VAULT="${VAULT:-$HOME/raw}"

if [ ! -d "$VAULT" ]; then
  echo "Vault not found at $VAULT" >&2
  exit 1
fi

if ! git -C "$VAULT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Vault is not a git repo: $VAULT" >&2
  exit 1
fi

if [ -n "$(git -C "$VAULT" status --porcelain)" ]; then
  echo "Vault has uncommitted changes — commit or stash before continuing." >&2
  exit 1
fi
