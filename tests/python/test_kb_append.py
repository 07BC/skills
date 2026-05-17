from pathlib import Path
from conftest import load_script

kb_append = load_script("obsidian/obsidian-learn/scripts/kb_append.py")


class TestExistingText:
    def test_returns_empty_string_when_file_missing(self, tmp_path):
        assert kb_append.existing_text(tmp_path / "nonexistent.md") == ""

    def test_returns_file_content_when_present(self, tmp_path):
        f = tmp_path / "kb.md"
        f.write_text("hello\n", encoding="utf-8")
        assert kb_append.existing_text(f) == "hello\n"


class TestInsertUnderDate:
    def test_creates_new_section_in_empty_content(self):
        result = kb_append.insert_under_date("", "2025-03-01", ["entry one"])
        assert "## 2025-03-01" in result
        assert "entry one" in result

    def test_appends_new_section_after_existing_content(self):
        content = "## 2025-02-01\n\nold entry\n"
        result = kb_append.insert_under_date(content, "2025-03-01", ["new entry"])
        assert "## 2025-03-01" in result
        assert "new entry" in result
        assert result.count("## 2025-02") == 1

    def test_inserts_within_existing_heading_without_duplicating(self):
        content = "## 2025-03-01\n\nexisting\n"
        result = kb_append.insert_under_date(content, "2025-03-01", ["new entry"])
        assert result.count("## 2025-03-01") == 1
        assert "new entry" in result

    def test_inserts_before_next_heading(self):
        content = "## 2025-03-01\n\nexisting\n\n## 2025-03-02\n\nother\n"
        result = kb_append.insert_under_date(content, "2025-03-01", ["new"])
        assert result.index("new") < result.index("## 2025-03-02")

    def test_preserves_trailing_newline(self):
        content = "## 2025-03-01\n\nexisting\n"
        result = kb_append.insert_under_date(content, "2025-03-01", ["new"])
        assert result.endswith("\n")

    def test_no_trailing_newline_when_original_has_none(self):
        content = "## 2025-03-01\n\nexisting"
        result = kb_append.insert_under_date(content, "2025-04-01", ["new"])
        assert not result.endswith("\n\n")
