from conftest import load_script

fetch_prompts = load_script("productivity/yt-research/scripts/fetch_prompts.py")


class TestSlugify:
    def test_replaces_spaces_with_hyphens(self):
        assert fetch_prompts.slugify("Hello World") == "Hello-World"

    def test_strips_special_characters(self):
        assert fetch_prompts.slugify("Hello! World?") == "Hello-World"

    def test_truncates_to_max_len(self):
        long_title = "A" * 100
        result = fetch_prompts.slugify(long_title, max_len=80)
        assert len(result) == 80

    def test_respects_custom_max_len(self):
        result = fetch_prompts.slugify("Short Title", max_len=5)
        assert len(result) <= 5

    def test_empty_string_returns_empty(self):
        assert fetch_prompts.slugify("") == ""

    def test_preserves_hyphens(self):
        assert fetch_prompts.slugify("already-hyphenated") == "already-hyphenated"


class TestHasPrompts:
    def test_detects_prompts_from_this_video_header(self):
        assert fetch_prompts.has_prompts("PROMPTS FROM THIS VIDEO\n1) something")

    def test_detects_header_case_insensitively(self):
        assert fetch_prompts.has_prompts("prompts from this video\n1) something")

    def test_detects_prompt_colon_label(self):
        assert fetch_prompts.has_prompts("Prompt: do this task")

    def test_detects_prompt_hash_label(self):
        assert fetch_prompts.has_prompts("Prompt #1: do this task")

    def test_detects_numbered_quoted_item(self):
        assert fetch_prompts.has_prompts('1) "Write a function that"')

    def test_returns_false_for_plain_description(self):
        assert not fetch_prompts.has_prompts("Just a normal video description without any prompts.")

    def test_returns_false_for_empty_string(self):
        assert not fetch_prompts.has_prompts("")


class TestExtractPrompts:
    def test_returns_empty_for_no_matching_content(self):
        result = fetch_prompts.extract_prompts("No prompts here at all.")
        assert result == []

    def test_header_strategy_extracts_numbered_items(self):
        description = (
            "PROMPTS FROM THIS VIDEO\n\n"
            "1) My Label:\n\"do the thing\"\n"
        )
        result = fetch_prompts.extract_prompts(description)
        assert len(result) == 1
        label, text = result[0]
        assert label == "My Label"
        assert "do the thing" in text

    def test_header_strategy_extracts_multiple_items(self):
        description = (
            "PROMPTS FROM THIS VIDEO\n\n"
            "1) First Label:\n\"first prompt text\"\n"
            "2) Second Label:\n\"second prompt text\"\n"
        )
        result = fetch_prompts.extract_prompts(description)
        assert len(result) == 2

    def test_numbered_quoted_strategy_extracts_item(self):
        description = '1) "Write me a short story about a robot"'
        result = fetch_prompts.extract_prompts(description)
        assert len(result) == 1
        label, text = result[0]
        assert label == "Prompt 1"
        assert "short story" in text

    def test_numbered_quoted_strategy_labels_sequentially(self):
        description = '1) "First prompt here"\n\n2) "Second prompt here"'
        result = fetch_prompts.extract_prompts(description)
        assert any(label == "Prompt 1" for label, _ in result)


class TestFormatPromptsFile:
    def test_includes_title_in_h1(self):
        result = fetch_prompts.format_prompts_file("abc123", "My Video", [("Label", "text")])
        assert "# Prompts: My Video" in result

    def test_includes_video_id(self):
        result = fetch_prompts.format_prompts_file("abc123", "My Video", [("Label", "text")])
        assert "abc123" in result

    def test_includes_youtube_url(self):
        result = fetch_prompts.format_prompts_file("abc123", "My Video", [("Label", "text")])
        assert "https://www.youtube.com/watch?v=abc123" in result

    def test_includes_prompts_section_heading(self):
        result = fetch_prompts.format_prompts_file("abc123", "My Video", [("Label", "text")])
        assert "## Prompts From This Video" in result

    def test_renders_each_prompt_as_h3(self):
        result = fetch_prompts.format_prompts_file(
            "abc123", "My Video", [("First", "text one"), ("Second", "text two")]
        )
        assert "### First" in result
        assert "### Second" in result

    def test_renders_prompt_text_as_quoted_string(self):
        result = fetch_prompts.format_prompts_file("abc123", "My Video", [("Label", "the prompt")])
        assert '"the prompt"' in result

    def test_empty_prompts_list_renders_section_with_no_entries(self):
        result = fetch_prompts.format_prompts_file("abc123", "My Video", [])
        assert "## Prompts From This Video" in result
        assert "### " not in result
