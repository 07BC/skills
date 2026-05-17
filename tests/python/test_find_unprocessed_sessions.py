from pathlib import Path
from conftest import load_script

fus = load_script("obsidian/session-saver/scripts/find_unprocessed_sessions.py")


class TestIsProcessed:
    def test_returns_false_for_plain_text(self):
        assert not fus.is_processed("# Just a note\n")

    def test_returns_false_when_frontmatter_lacks_processed(self):
        text = "---\ntitle: My Session\n---\n# Content"
        assert not fus.is_processed(text)

    def test_returns_true_when_processed_true(self):
        text = "---\nprocessed: true\n---\n# Content"
        assert fus.is_processed(text)

    def test_returns_false_when_processed_false(self):
        text = "---\nprocessed: false\n---\n# Content"
        assert not fus.is_processed(text)

    def test_returns_false_for_empty_frontmatter(self):
        text = "---\n---\n# Content"
        assert not fus.is_processed(text)


class TestBaseName:
    def test_strips_t1_suffix(self):
        assert fus.base_name(Path("session-2025-01-01-t1.md")) == "session-2025-01-01.md"

    def test_strips_t12_suffix(self):
        assert fus.base_name(Path("session-2025-01-01-t12.md")) == "session-2025-01-01.md"

    def test_leaves_name_without_suffix_unchanged(self):
        assert fus.base_name(Path("session-2025-01-01.md")) == "session-2025-01-01.md"
