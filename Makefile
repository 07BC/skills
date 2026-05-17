.PHONY: all help install link hook plugin test-python venv

HOOKS_DEST := $(HOME)/.claude/hooks

help:
	@echo "Targets:"
	@echo "  install      full install — skills, hook binary, plugin"
	@echo "  link         refresh skill symlinks in ~/.claude/skills/"
	@echo "  hook         install session-saver hook binary to ~/.claude/hooks/"
	@echo "  plugin       install the j plugin via claude CLI"
	@echo "  venv         create .venv with pytest"
	@echo "  test-python  run Python script tests"

install: link hook

link:
	@bash scripts/link-skills.sh

hook:
	@mkdir -p $(HOOKS_DEST)
	@cp hooks/session-saver $(HOOKS_DEST)/session-saver
	@chmod +x $(HOOKS_DEST)/session-saver
	@echo "installed session-saver -> $(HOOKS_DEST)/session-saver"

plugin:
	claude plugin marketplace add 07BC/skills 2>/dev/null || true
	claude plugin install j

venv:
	python3.13 -m venv .venv
	.venv/bin/pip install --quiet pytest

test-python: .venv
	.venv/bin/pytest -v

.venv:
	$(MAKE) venv
