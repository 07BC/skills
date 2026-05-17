#!/usr/bin/env bash
# Resolve and print the Obsidian vault root.
# Run:     bash _lib/obsidian-path.sh          → prints $VAULT
# Capture: VAULT=$(bash _lib/obsidian-path.sh)
# VAULT env var is honoured if already set.
set -euo pipefail
: "${VAULT:=$HOME/raw}"
echo "$VAULT"
