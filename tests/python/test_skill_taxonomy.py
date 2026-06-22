"""Conformance check for the skill-species taxonomy (ADR 0004).

Two frontmatter fields control invocation, and they are NOT interchangeable:
  - disable-model-invocation: true  -> Claude won't auto-fire it; explicit
    invocation (Skill tool / /command) still works.  -> POLICY skills.
  - user-invocable: false           -> hidden from the user's / menu; Claude
    CAN still auto-fire it.                            -> reference/dependency.

This test pins the markers for the known policy and dependency skills so the
convention can't silently regress (e.g. someone dropping the flag).
"""

import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).parent.parent.parent

# Policy skills: cited by orchestrators, must not auto-fire on user messages.
POLICY_SKILLS = [
    "skills/pipelines/pipeline-preflight/SKILL.md",
    "skills/pipelines/subagent-reliability/SKILL.md",
]

# Dependency skills: loaded by another skill, not a user action.
DEPENDENCY_SKILLS = [
    "skills/engineering/swift-style/SKILL.md",
    "skills/engineering/ios-simulator-control/SKILL.md",
]

# User-invoked orchestrator skills: explicitly triggered (/name or Skill tool),
# never auto-fired, because they create branches/commits/issues. They must set
# disable-model-invocation: true but stay user-invocable. (Pinned here because
# spec-pipeline once silently lost this flag — see ADR 0014.)
NO_AUTOFIRE_ORCHESTRATOR_SKILLS = [
    "skills/engineering/spec-pipeline/SKILL.md",
    "skills/engineering/spec-decomposition/SKILL.md",
]


def _frontmatter(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
    assert m, f"{path} has no YAML frontmatter"
    return m.group(1)


def _has_flag(frontmatter: str, key: str) -> bool:
    return re.search(rf"(?m)^{re.escape(key)}:\s*true\b", frontmatter) is not None


@pytest.mark.parametrize("rel_path", POLICY_SKILLS)
def test_policy_skill_disables_model_invocation(rel_path):
    fm = _frontmatter(REPO_ROOT / rel_path)
    assert _has_flag(fm, "disable-model-invocation"), (
        f"{rel_path} is a policy skill and must set "
        f"`disable-model-invocation: true` (see ADR 0004)."
    )


@pytest.mark.parametrize("rel_path", DEPENDENCY_SKILLS)
def test_dependency_skill_carries_both_markers(rel_path):
    fm = _frontmatter(REPO_ROOT / rel_path)
    assert _has_flag(fm, "disable-model-invocation"), (
        f"{rel_path} is a dependency skill and must set "
        f"`disable-model-invocation: true` (see ADR 0004)."
    )
    assert re.search(r"(?m)^user-invocable:\s*false\b", fm), (
        f"{rel_path} is a dependency skill and must set "
        f"`user-invocable: false` (see ADR 0004)."
    )


@pytest.mark.parametrize("rel_path", NO_AUTOFIRE_ORCHESTRATOR_SKILLS)
def test_orchestrator_skill_disables_model_invocation(rel_path):
    fm = _frontmatter(REPO_ROOT / rel_path)
    assert _has_flag(fm, "disable-model-invocation"), (
        f"{rel_path} is a user-invoked orchestrator that creates branches/commits/"
        f"issues and must set `disable-model-invocation: true` so it never "
        f"auto-fires (see ADR 0014). It stays user-invocable."
    )
    assert not re.search(r"(?m)^user-invocable:\s*false\b", fm), (
        f"{rel_path} must stay user-invocable (do not set user-invocable: false) "
        f"— users trigger it explicitly via /{Path(rel_path).parent.name}."
    )
