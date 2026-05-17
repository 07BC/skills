from conftest import load_script

fetch_transcripts = load_script("productivity/yt-research/scripts/fetch_transcripts.py")


class TestSlugify:
    def test_replaces_spaces_with_hyphens(self):
        assert fetch_transcripts.slugify("Hello World") == "Hello-World"

    def test_strips_special_characters(self):
        assert fetch_transcripts.slugify("Hello! World?") == "Hello-World"

    def test_truncates_to_max_len(self):
        long_title = "A" * 100
        result = fetch_transcripts.slugify(long_title, max_len=80)
        assert len(result) == 80

    def test_empty_string_returns_empty(self):
        assert fetch_transcripts.slugify("") == ""

    def test_preserves_hyphens(self):
        assert fetch_transcripts.slugify("already-hyphenated") == "already-hyphenated"


class TestFormatMarkdown:
    def test_includes_title_in_h1(self):
        result = fetch_transcripts.format_markdown("abc123", "My Video", "Some text")
        assert "# My Video" in result

    def test_includes_video_id(self):
        result = fetch_transcripts.format_markdown("abc123", "My Video", "Some text")
        assert "abc123" in result

    def test_includes_youtube_url(self):
        result = fetch_transcripts.format_markdown("abc123", "My Video", "Some text")
        assert "https://www.youtube.com/watch?v=abc123" in result

    def test_includes_transcript_heading(self):
        result = fetch_transcripts.format_markdown("abc123", "My Video", "Some text")
        assert "## Transcript" in result

    def test_empty_transcript_produces_no_body_text(self):
        result = fetch_transcripts.format_markdown("abc123", "My Video", "")
        assert "## Transcript" in result
        body_after_heading = result.split("## Transcript\n\n", 1)[1]
        assert body_after_heading.strip() == ""

    def test_groups_six_lines_into_one_paragraph(self):
        lines = "\n".join([f"line{i}" for i in range(6)])
        result = fetch_transcripts.format_markdown("vid", "Title", lines)
        transcript_body = result.split("## Transcript\n\n", 1)[1]
        paragraphs = [p.strip() for p in transcript_body.split("\n\n") if p.strip()]
        assert len(paragraphs) == 1

    def test_overflow_lines_form_second_paragraph(self):
        lines = "\n".join([f"line{i}" for i in range(7)])
        result = fetch_transcripts.format_markdown("vid", "Title", lines)
        transcript_body = result.split("## Transcript\n\n", 1)[1]
        paragraphs = [p.strip() for p in transcript_body.split("\n\n") if p.strip()]
        assert len(paragraphs) == 2

    def test_ignores_blank_lines_in_transcript(self):
        transcript = "line1\n\n\nline2"
        result = fetch_transcripts.format_markdown("vid", "Title", transcript)
        assert "line1" in result
        assert "line2" in result

    def test_single_line_transcript_forms_one_paragraph(self):
        result = fetch_transcripts.format_markdown("vid", "Title", "just one line")
        transcript_body = result.split("## Transcript\n\n", 1)[1]
        paragraphs = [p.strip() for p in transcript_body.split("\n\n") if p.strip()]
        assert len(paragraphs) == 1
        assert "just one line" in paragraphs[0]
