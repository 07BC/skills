#!/usr/bin/env bash
# Verify the Obsidian vault is a git repo with a clean working tree.
# Usage: vault_preconditions.sh
#
# Exits 0 if OK. Prints diagnostic to stderr and exits non-zero on:
#   - vault directory missing
#   - vault is not a git repo
#   - vault has uncommitted changes (audit diff would be muddied)
#
# VAULT resolved via _lib/obsidian-path.sh

set -euo pipefail

LIB_DIR="$(cd "$(dirname "$0")/../.." && pwd)/_lib"
VAULT=$(bash "$LIB_DIR/obsidian-path.sh")

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
