"""Conformance check: every skill/agent a command references must resolve.

Commands are thin launchers — each names a skill or agent and delegates to it.
That reference rots silently: when a skill is deleted (the `ios-debugger-agent`
skill) or moved to `deprecated/` (the `swiftui-ui-patterns` /
`swiftui-view-refactor` skills behind the old `/ui-patterns` and
`/view-refactor` commands), nothing complained — the command just pointed at a
dead target. This test catches that.

It scans every command file, extracts backticked names adjacent to the words
`skill` / `agent` / `subagent`, and asserts each resolves to a LIVE local skill
directory or a local agent file. References that are external on purpose
(plugin-provided skills, unmigrated skills, registry agent types) are
allowlisted below so legitimately-remote dependencies don't fail the check —
adding to an allowlist is a deliberate act that documents the external dep.
"""

import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).parent.parent.parent
COMMANDS_DIR = REPO_ROOT / "commands"
SKILLS_DIR = REPO_ROOT / "skills"
AGENTS_DIR = REPO_ROOT / "agents"

# Skills referenced by commands that intentionally live outside this repo.
#   verify            -> plugin-provided skill (root plugins, not in this repo)
#   pr-comment-review -> unmigrated skill, still a real dir in ~/.claude/skills/
EXTERNAL_SKILLS = {"verify", "pr-comment-review"}

# Agent types resolved from the plugin/subagent registry, not from agents/.
#   code-explorer / code-architect -> the feature-dev:* registry agents /solve uses
EXTERNAL_AGENTS = {"code-explorer", "code-architect"}

# `name` (skill|agent|subagent)      AND      (skill|agent|subagent) `name`
_REF_PATTERNS = [
    re.compile(r"`([a-z0-9-]+)`\s+(skill|subagent|agent)s?\b", re.IGNORECASE),
    re.compile(r"\b(skill|subagent|agent)s?\s+`([a-z0-9-]+)`", re.IGNORECASE),
]
_ROLE_WORDS = {"skill", "subagent", "agent"}


def _command_files():
    return sorted(COMMANDS_DIR.rglob("*.md"))


def _extract_refs(text):
    """Return a set of (name, kind) where kind is 'skill' or 'agent'."""
    refs = set()
    for pattern in _REF_PATTERNS:
        for match in pattern.finditer(text):
            a, b = match.group(1), match.group(2)
            role, name = (a, b) if a.lower() in _ROLE_WORDS else (b, a)
            kind = "skill" if role.lower() == "skill" else "agent"
            refs.add((name, kind))
    return refs


def _live_skill_exists(name):
    return any(
        "deprecated" not in path.parts
        for path in SKILLS_DIR.rglob(f"{name}/SKILL.md")
    )


def _deprecated_skill_exists(name):
    deprecated = SKILLS_DIR / "deprecated"
    return deprecated.exists() and any(deprecated.rglob(f"{name}/SKILL.md"))


def _agent_exists(name):
    if any(AGENTS_DIR.rglob(f"{name}.md")):
        return True
    name_line = re.compile(rf"(?m)^name:\s*{re.escape(name)}\s*$")
    return any(
        name_line.search(path.read_text(encoding="utf-8"))
        for path in AGENTS_DIR.rglob("*.md")
    )


@pytest.fixture(
    scope="module",
    params=[str(p.relative_to(REPO_ROOT)) for p in _command_files()],
)
def command(request):
    path = REPO_ROOT / request.param
    assert path.is_file(), f"command not found: {request.param}"
    return request.param, path.read_text(encoding="utf-8")


def test_command_references_resolve(command):
    rel_path, text = command
    problems = []
    for name, kind in sorted(_extract_refs(text)):
        if kind == "skill":
            if name in EXTERNAL_SKILLS or _live_skill_exists(name):
                continue
            if _deprecated_skill_exists(name):
                problems.append(f"skill `{name}` is DEPRECATED (skills/deprecated/)")
            else:
                problems.append(f"skill `{name}` is not a live local skill")
        else:
            if name in EXTERNAL_AGENTS or _agent_exists(name):
                continue
            problems.append(f"agent `{name}` has no file in agents/")
    assert not problems, (
        f"{rel_path} references unresolved skills/agents: "
        + "; ".join(problems)
        + ". Fix the reference, un-deprecate the target, or add it to "
        "EXTERNAL_SKILLS / EXTERNAL_AGENTS in this test."
    )
