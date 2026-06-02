import datetime
from conftest import load_script

rollover = load_script("obsidian/obsidian-rollover/scripts/rollover.py")


class TestDailyRel:
    def test_constructs_correct_relative_path(self):
        result = rollover._daily_rel(datetime.date(2025, 3, 5))
        assert result == "daily/2025/03-Mar/25-03-5.md"

    def test_zero_pads_month_in_folder(self):
        result = rollover._daily_rel(datetime.date(2025, 1, 10))
        assert "01-Jan" in result

    def test_day_is_not_zero_padded(self):
        # Matches the on-disk daily-note naming (e.g. 25-06-2.md, not 25-06-02.md).
        assert rollover._daily_rel(datetime.date(2025, 6, 2)).endswith("25-06-2.md")


class TestText:
    def test_extracts_open_todo(self):
        assert rollover._text("- [ ] Buy milk") == "Buy milk"

    def test_open_matcher_ignores_done_line(self):
        assert rollover._text("- [x] Done") is None

    def test_extracts_done_todo_when_done_true(self):
        assert rollover._text("- [x] Done thing", done=True) == "Done thing"

    def test_extracts_uppercase_x_when_done_true(self):
        assert rollover._text("- [X] Capital X done", done=True) == "Capital X done"

    def test_done_matcher_ignores_open_line(self):
        assert rollover._text("- [ ] Open", done=True) is None

    def test_ignores_empty_placeholder(self):
        assert rollover._text("- [ ] ") is None

    def test_strips_trailing_whitespace(self):
        assert rollover._text("- [ ] Buy milk  ") == "Buy milk"

    def test_matches_indented_todo(self):
        assert rollover._text("  - [ ] Indented") == "Indented"


class TestNorm:
    def test_strips_markdown_link(self):
        assert rollover._norm("[label](https://example.com)") == "label"

    def test_strips_bold_and_italic_markers(self):
        assert rollover._norm("**bold** and *italic*") == "bold and italic"

    def test_collapses_internal_whitespace(self):
        assert rollover._norm("foo   bar") == "foo bar"

    def test_strips_leading_and_trailing_whitespace(self):
        assert rollover._norm("  hello  ") == "hello"

    def test_lowercases(self):
        assert rollover._norm("Hello World") == "hello world"


class TestIsDup:
    def test_exact_match_is_dup(self):
        assert rollover._is_dup("abc", {"abc"}) is True

    def test_absent_is_not_dup(self):
        assert rollover._is_dup("abc", {"xyz"}) is False

    def test_short_substring_is_not_dup(self):
        # Short strings must not be substring-matched, or unrelated tasks collide.
        assert rollover._is_dup("abc", {"abcdef"}) is False

    def test_long_substring_containment_is_dup(self):
        seen = {"monday first: nat-694 — fix the thing in the widget pipeline"}
        norm = "nat-694 — fix the thing in the widget pipeline"
        assert len(norm) > 30
        assert rollover._is_dup(norm, seen) is True

    def test_same_key_before_dash_is_dup(self):
        seen = {"nat-694 — original phrasing of the task"}
        assert rollover._is_dup("nat-694 — rephrased context after the dash", seen) is True


class TestInsert:
    def test_creates_new_section_when_missing(self):
        result = rollover._insert("# Note\n\nContent.\n", ["- [ ] Task"])
        assert "## To-Do" in result
        assert "- [ ] Task" in result

    def test_inserts_before_divider(self):
        content = "## To-Do\n\n- [ ] Existing\n\n---\n"
        result = rollover._insert(content, ["- [ ] New"])
        assert result.index("- [ ] New") < result.index("---")

    def test_inserts_before_next_heading(self):
        content = "## To-Do\n\n- [ ] Existing\n\n## Notes\n"
        result = rollover._insert(content, ["- [ ] New"])
        assert result.index("- [ ] New") < result.index("## Notes")

    def test_preserves_trailing_newline(self):
        result = rollover._insert("## To-Do\n\n---\n", ["- [ ] Task"])
        assert result.endswith("\n")

    def test_matches_todo_heading_case_insensitively(self):
        # The section scan lower-cases, so "## TO-DO" is still found (no new section).
        result = rollover._insert("## TO-DO\n\n---\n", ["- [ ] Task"])
        assert result.count("To-Do") + result.count("TO-DO") == 1


class TestTasks:
    def test_parses_task_texts_from_json(self, monkeypatch):
        monkeypatch.setattr(
            rollover, "_obsidian", lambda *a: '[{"text": "- [ ] A"}, {"text": "- [ ] B"}]'
        )
        assert rollover._tasks("daily") == ["- [ ] A", "- [ ] B"]

    def test_empty_output_returns_empty_list(self, monkeypatch):
        monkeypatch.setattr(rollover, "_obsidian", lambda *a: "")
        assert rollover._tasks("daily") == []

    def test_no_tasks_sentinel_returns_empty_list(self, monkeypatch):
        monkeypatch.setattr(rollover, "_obsidian", lambda *a: "No tasks found")
        assert rollover._tasks("daily") == []

    def test_cli_failure_returns_empty_list(self, monkeypatch):
        def boom(*a):
            raise RuntimeError("obsidian tasks failed")

        monkeypatch.setattr(rollover, "_obsidian", boom)
        assert rollover._tasks("daily") == []
