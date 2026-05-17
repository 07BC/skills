.PHONY: all help install link unlink hook plugin test-python venv test

HOOKS_DEST := $(HOME)/.claude/hooks
SKILLS_DEST := $(HOME)/.claude/skills

help:
	@echo "Targets:"
	@echo "  install      full install — skills, hook binary, plugin"
	@echo "  link         refresh skill symlinks in ~/.claude/skills/"
	@echo "  unlink       remove all skill symlinks from ~/.claude/skills/ that point into this repo"
	@echo "  hook         install all hooks from hooks/ to ~/.claude/hooks/"
	@echo "  plugin       install the j plugin via claude CLI"
	@echo "  test         run all tests"
	@echo "  test-python  run Python script tests"
	@echo "  venv         create .venv with pytest"

test: test-python

install: link hook

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

hook:
	@mkdir -p $(HOOKS_DEST)
	@REPO="$$(cd . && pwd)"; \
	for f in hooks/*; do \
	  name=$$(basename "$$f"); \
	  ln -sfn "$$REPO/$$f" "$(HOOKS_DEST)/$$name"; \
	  echo "linked $$name -> $(HOOKS_DEST)/$$name"; \
	done

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
