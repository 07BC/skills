.PHONY: all help install uninstall link unlink commands unlink-commands hook unlink-hooks test-python venv test

HOOKS_DEST  := $(HOME)/.claude/hooks
SKILLS_DEST := $(HOME)/.claude/skills
COMMANDS_DEST := $(HOME)/.claude/commands

help:
	@echo "Targets:"
	@echo "  install          full install — skills, commands, hooks"
	@echo "  link             refresh skill symlinks in ~/.claude/skills/"
	@echo "  unlink           remove skill symlinks from ~/.claude/skills/ that point into this repo"
	@echo "  commands         refresh command symlinks in ~/.claude/commands/"
	@echo "  unlink-commands  remove command symlinks from ~/.claude/commands/ that point into this repo"
	@echo "  uninstall        remove all skill, command, and hook symlinks from ~/.claude/"
	@echo "  hook             install hooks from hooks/ to ~/.claude/hooks/"
	@echo "  unlink-hooks     remove hook symlinks from ~/.claude/hooks/ that point into this repo"
	@echo "  test             run all tests"
	@echo "  test-python      run Python script tests"
	@echo "  venv             create .venv with pytest"

test: test-python

install: link commands hook

uninstall: unlink unlink-commands unlink-hooks

link:
	@bash scripts/link-skills.sh

commands:
	@bash scripts/link-commands.sh

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

unlink-hooks:
	@REPO="$$(cd . && pwd)"; \
	find "$(HOOKS_DEST)" -maxdepth 1 -type l | while read -r sym; do \
	  target="$$(readlink "$$sym")"; \
	  case "$$target" in \
	    "$$REPO"/hooks/*) rm "$$sym" && echo "removed $$(basename $$sym)";; \
	  esac; \
	done

hook:
	@mkdir -p $(HOOKS_DEST)
	@REPO="$$(cd . && pwd)"; \
	for f in hooks/*; do \
	  name=$$(basename "$$f"); \
	  case "$$name" in *.md|*.json) continue;; esac; \
	  ln -sfn "$$REPO/$$f" "$(HOOKS_DEST)/$$name"; \
	  echo "linked $$name -> $(HOOKS_DEST)/$$name"; \
	done
	@bash scripts/register-hooks.sh

venv:
	python3.13 -m venv .venv
	.venv/bin/pip install --quiet pytest

test-python: .venv
	.venv/bin/pytest -v

.venv:
	$(MAKE) venv
