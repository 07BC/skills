.PHONY: all help install uninstall link unlink commands unlink-commands agents unlink-agents hook unlink-hooks test-python venv test

HOOKS_DEST    := $(HOME)/.claude/hooks
SKILLS_DEST   := $(HOME)/.claude/skills
COMMANDS_DEST := $(HOME)/.claude/commands
AGENTS_DEST   := $(HOME)/.claude/agents

help:
	@echo "Targets:"
	@echo "  install          full install — skills, commands, agents, hooks"
	@echo "  link             prune stale, then refresh skill symlinks in ~/.claude/skills/"
	@echo "  unlink           remove skill symlinks from ~/.claude/skills/ that point into this repo"
	@echo "  commands         prune stale, then refresh command symlinks in ~/.claude/commands/"
	@echo "  unlink-commands  remove command symlinks from ~/.claude/commands/ that point into this repo"
	@echo "  agents           prune stale, then refresh agent symlinks in ~/.claude/agents/"
	@echo "  unlink-agents    remove agent symlinks from ~/.claude/agents/ that point into this repo"
	@echo "  uninstall        remove all skill, command, agent, and hook symlinks from ~/.claude/"
	@echo "  hook             install hooks from hooks/ to ~/.claude/hooks/ and register in settings.json"
	@echo "  unlink-hooks     remove hook symlinks from ~/.claude/hooks/ that point into this repo"
	@echo "  test             run all tests"
	@echo "  test-python      run Python script tests"
	@echo "  venv             create .venv with pytest"

test: test-python

install: link commands agents hook

uninstall: unlink unlink-commands unlink-agents unlink-hooks

link:
	@bash scripts/link-skills.sh

commands:
	@bash scripts/link-commands.sh

agents:
	@bash scripts/link-agents.sh

unlink:
	@REPO="$$(cd . && pwd)"; \
	find "$(SKILLS_DEST)" -maxdepth 1 -type l | while read -r sym; do \
	  target="$$(readlink "$$sym")"; \
	  case "$$target" in \
	    "$$REPO"/skills/*) rm "$$sym" && echo "removed $$(basename $$sym)";; \
	  esac; \
	done

unlink-commands:
	@REPO="$$(cd . && pwd)"; \
	find "$(COMMANDS_DEST)" -maxdepth 1 -type l | while read -r sym; do \
	  target="$$(readlink "$$sym")"; \
	  case "$$target" in \
	    "$$REPO"/commands/*) rm "$$sym" && echo "removed $$(basename $$sym)";; \
	  esac; \
	done

unlink-agents:
	@REPO="$$(cd . && pwd)"; \
	if [ -L "$(AGENTS_DEST)" ]; then \
	  target="$$(readlink "$(AGENTS_DEST)")"; \
	  case "$$target" in \
	    "$$REPO"/agents) rm "$(AGENTS_DEST)" && echo "removed agents symlink";; \
	  esac; \
	fi

unlink-hooks:
	@REPO="$$(cd . && pwd)"; \
	find "$(HOOKS_DEST)" -maxdepth 1 -type l | while read -r sym; do \
	  target="$$(readlink "$$sym")"; \
	  case "$$target" in \
	    "$$REPO"/hooks/*) rm "$$sym" && echo "removed $$(basename $$sym)";; \
	  esac; \
	done

hook:
	@bash scripts/link-hooks.sh
	@bash scripts/register-hooks.sh

venv:
	python3.13 -m venv .venv
	.venv/bin/pip install --quiet pytest

test-python: .venv
	.venv/bin/pytest -v

.venv:
	$(MAKE) venv
