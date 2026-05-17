import datetime
from pathlib import Path
from conftest import load_script

rollover = load_script("obsidian/obsidian-rollover/scripts/rollover.py")


class TestDailyPath:
    def test_constructs_correct_path(self):
        vault = Path("/vault")
        date = datetime.date(2025, 3, 5)
        result = rollover.daily_path(vault, date)
        assert result == Path("/vault/daily/2025/03-Mar/25-03-5.md")

    def test_zero_pads_month_in_folder(self):
        result = rollover.daily_path(Path("/v"), datetime.date(2025, 1, 10))
        assert "01-Jan" in str(result)


class TestExtractOpenTodos:
    def test_returns_empty_for_no_todos(self):
        assert rollover.extract_open_todos("## Heading\nSome text\n") == []

    def test_extracts_single_open_todo(self):
        assert rollover.extract_open_todos("- [ ] Buy milk\n") == ["Buy milk"]

    def test_ignores_done_todos(self):
        assert rollover.extract_open_todos("- [x] Done\n- [ ] Open\n") == ["Open"]

    def test_extracts_multiple_open_todos(self):
        result = rollover.extract_open_todos("- [ ] First\n- [ ] Second\n")
        assert result == ["First", "Second"]

    def test_ignores_empty_placeholder(self):
        assert rollover.extract_open_todos("- [ ] \n") == []


class TestExtractDoneTodos:
    def test_returns_empty_for_no_done_todos(self):
        assert rollover.extract_done_todos("- [ ] Open\n") == set()

    def test_extracts_lowercase_x(self):
        result = rollover.extract_done_todos("- [x] Done thing\n")
        assert rollover._normalise("Done thing") in result

    def test_extracts_uppercase_x(self):
        result = rollover.extract_done_todos("- [X] Capital X done\n")
        assert len(result) == 1

    def test_ignores_open_todos(self):
        result = rollover.extract_done_todos("- [ ] Open\n")
        assert len(result) == 0


class TestNormalise:
    def test_strips_markdown_link(self):
        assert rollover._normalise("[label](https://example.com)") == "label"

    def test_collapses_internal_whitespace(self):
        assert rollover._normalise("foo   bar") == "foo bar"

    def test_strips_leading_and_trailing_whitespace(self):
        assert rollover._normalise("  hello  ") == "hello"

    def test_lowercases(self):
        assert rollover._normalise("Hello World") == "hello world"


class TestInsertIntoTodoSection:
    def test_creates_new_section_when_missing(self):
        result = rollover.insert_into_todo_section("# Note\n\nContent.\n", ["- [ ] Task"])
        assert "## To-Do" in result
        assert "- [ ] Task" in result

    def test_inserts_before_divider(self):
        content = "## To-Do\n\n- [ ] Existing\n\n---\n"
        result = rollover.insert_into_todo_section(content, ["- [ ] New"])
        assert result.index("- [ ] New") < result.index("---")

    def test_inserts_before_next_heading(self):
        content = "## To-Do\n\n- [ ] Existing\n\n## Notes\n"
        result = rollover.insert_into_todo_section(content, ["- [ ] New"])
        assert result.index("- [ ] New") < result.index("## Notes")

    def test_preserves_trailing_newline(self):
        content = "## To-Do\n\n---\n"
        result = rollover.insert_into_todo_section(content, ["- [ ] Task"])
        assert result.endswith("\n")
