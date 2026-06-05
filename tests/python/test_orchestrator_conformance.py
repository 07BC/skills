"""Conformance check for the orchestrator contract.

Enforces the concept-based structure documented in docs/orchestrator-contract.md
(per ADR 0002). Each required concept is matched by a set of accepted synonyms,
so legitimately-different orchestrators (e.g. spec-pipeline) still pass without
being forced to rename their sections.

Scope: phase-gated orchestrators that spawn subagents. discovery.md is a setup
utility (no subagents, no phase loop) and is intentionally excluded.
"""

import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).parent.parent.parent

ORCHESTRATORS = [
    "commands/Mr Will/workflow.md",
    "commands/Mr Will/uitest.md",
    "commands/Mr Will/audit.md",
    "commands/Mr Will/solve.md",
    "commands/Mr Will/discovery.md",
    "skills/engineering/spec-pipeline/SKILL.md",
]


def _phase_heading_count(text: str) -> int:
    """Count ##-level headings that begin with Phase / Stage / Step."""
    return len(
        re.findall(r"(?im)^#{2,4}\s+(?:phase|stage|step)\b", text)
    )


# Each required concept: name -> predicate over the file's text.
REQUIRED_CONCEPTS = {
    "model & mode declared": lambda t: re.search(
        r"(?i)running as:|model\s*&\s*mode|model\s+and\s+mode|model intent", t
    )
    is not None,
    "cites pipeline-preflight": lambda t: "pipeline-preflight" in t,
    "has a failure section": lambda t: re.search(
        r"(?i)halt conditions|escalation|failure modes", t
    )
    is not None,
    "cites subagent-reliability": lambda t: "subagent-reliability" in t,
    "has >=3 phase/step headings": lambda t: _phase_heading_count(t) >= 3,
}


@pytest.fixture(scope="module", params=ORCHESTRATORS)
def orchestrator(request):
    path = REPO_ROOT / request.param
    assert path.is_file(), f"orchestrator not found: {request.param}"
    return request.param, path.read_text(encoding="utf-8")


def test_orchestrator_meets_contract(orchestrator):
    rel_path, text = orchestrator
    missing = [name for name, ok in REQUIRED_CONCEPTS.items() if not ok(text)]
    assert not missing, (
        f"{rel_path} is missing required orchestrator-contract concept(s): "
        f"{', '.join(missing)}. See docs/orchestrator-contract.md."
    )
