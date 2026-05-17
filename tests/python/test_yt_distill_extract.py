from conftest import load_script

extract = load_script("productivity/yt-distill/scripts/extract_candidates.py")


class TestClassify:
    def test_plugin_term_returns_plugins(self):
        assert extract.classify("This is an MCP server integration", "keyword_paragraph") == "plugins"

    def test_skill_term_returns_skills(self):
        assert extract.classify("This is a Claude Code skill", "keyword_paragraph") == "skills"

    def test_slash_command_type_returns_skills(self):
        assert extract.classify("use /some-command", "slash_command") == "skills"

    def test_prompt_term_returns_prompts(self):
        assert extract.classify("Tell Claude to write the prompt", "keyword_paragraph") == "prompts"

    def test_technique_term_returns_techniques(self):
        assert extract.classify("A workflow pattern for daily use", "keyword_paragraph") == "techniques"

    def test_verbatim_prompt_with_quotes_returns_prompts(self):
        assert extract.classify('"You are a helpful assistant"', "verbatim_prompt") == "prompts"

    def test_blockquote_with_quotes_returns_prompts(self):
        assert extract.classify('"Do the thing now"', "blockquote") == "prompts"

    def test_unclassifiable_text_returns_unknown(self):
        assert extract.classify("something with no relevant keywords at all here", "keyword_paragraph") == "?"

    def test_plugin_takes_priority_over_skill(self):
        assert extract.classify("MCP server plugin skill agent", "keyword_paragraph") == "plugins"


class TestUpdateHeadingPath:
    def test_adds_first_heading(self):
        stack: list = []
        result = extract.update_heading_path(stack, 1, "Top")
        assert result == ["Top"]

    def test_adds_nested_heading(self):
        stack: list = []
        extract.update_heading_path(stack, 1, "Top")
        result = extract.update_heading_path(stack, 2, "Sub")
        assert result == ["Top", "Sub"]

    def test_replaces_same_level_heading(self):
        stack: list = []
        extract.update_heading_path(stack, 1, "First")
        result = extract.update_heading_path(stack, 1, "Second")
        assert result == ["Second"]

    def test_pops_deeper_levels_on_shallower_heading(self):
        stack: list = []
        extract.update_heading_path(stack, 1, "Top")
        extract.update_heading_path(stack, 2, "Sub")
        extract.update_heading_path(stack, 3, "Deep")
        result = extract.update_heading_path(stack, 2, "NewSub")
        assert result == ["Top", "NewSub"]

    def test_empty_stack_with_deep_heading(self):
        stack: list = []
        result = extract.update_heading_path(stack, 3, "Orphan")
        assert result == ["Orphan"]


class TestIsQuotedSentence:
    def test_double_quoted_string_is_true(self):
        assert extract.is_quoted_sentence('"You are a helpful assistant."')

    def test_curly_double_quoted_string_is_true(self):
        assert extract.is_quoted_sentence('“You are a helpful assistant.”')

    def test_unquoted_string_is_false(self):
        assert not extract.is_quoted_sentence("Not a quoted sentence at all.")

    def test_too_short_string_is_false(self):
        assert not extract.is_quoted_sentence('"Hi"')

    def test_only_opening_quote_is_false(self):
        assert not extract.is_quoted_sentence('"No closing quote here')

    def test_empty_string_is_false(self):
        assert not extract.is_quoted_sentence("")


class TestFlushParagraph:
    def test_joins_lines_with_space(self):
        result = extract.flush_paragraph(["Hello", "World"])
        assert result == "Hello World"

    def test_strips_leading_and_trailing_whitespace(self):
        result = extract.flush_paragraph(["  Hello  ", "  World  "])
        assert result == "Hello World"

    def test_single_line_returns_stripped(self):
        result = extract.flush_paragraph(["  single  "])
        assert result == "single"

    def test_empty_buffer_returns_empty(self):
        result = extract.flush_paragraph([])
        assert result == ""
