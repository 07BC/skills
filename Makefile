.PHONY: all help install link unlink agents unagent hook test-python venv test

HOOKS_DEST  := $(HOME)/.claude/hooks
SKILLS_DEST := $(HOME)/.claude/skills
AGENTS_DEST := $(HOME)/.claude/agents

help:
	@echo "Targets:"
	@echo "  install      full install — skills, agents, hooks"
	@echo "  link         refresh skill symlinks in ~/.claude/skills/"
	@echo "  unlink       remove skill symlinks from ~/.claude/skills/ that point into this repo"
	@echo "  agents       symlink agents/*.md into ~/.claude/agents/"
	@echo "  unagent      remove agent symlinks from ~/.claude/agents/ that point into this repo"
	@echo "  hook         install hooks from hooks/ to ~/.claude/hooks/"
	@echo "  test         run all tests"
	@echo "  test-python  run Python script tests"
	@echo "  venv         create .venv with pytest"

test: test-python

install: link agents hook

link:
	@bash scripts/link-skills.sh

unlink:
	@REPO="$$(cd . && pwd)"; \
	find "$(SKILLS_DEST)" -maxdepth 1 -type l | while read -r sym; do \
	  target="$$(readlink "$$sym")"; \
	  case "$$target" in \
	    "$$REPO"/skills/*) rm "$$sym" && echo "removed $$(basename $$sym)";; \
	  esac; \
	done

agents:
	@mkdir -p "$(AGENTS_DEST)"
	@REPO="$$(cd . && pwd)"; \
	for f in "$$REPO/agents"/*.md; do \
	  [ -f "$$f" ] || continue; \
	  name="$$(basename "$$f")"; \
	  ln -sfn "$$f" "$(AGENTS_DEST)/$$name"; \
	  echo "linked $$name -> $(AGENTS_DEST)/$$name"; \
	done

unagent:
	@REPO="$$(cd . && pwd)"; \
	find "$(AGENTS_DEST)" -maxdepth 1 -name "*.md" -type l | while read -r sym; do \
	  target="$$(readlink "$$sym")"; \
	  case "$$target" in \
	    "$$REPO"/agents/*) rm "$$sym" && echo "removed $$(basename $$sym)";; \
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
