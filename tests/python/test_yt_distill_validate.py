import os
import pytest
from conftest import load_script

validate = load_script("productivity/yt-distill/scripts/validate_output.py")


def write(path: str, content: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(content)


class TestValidateIndex:
    def test_missing_index_reports_error(self, tmp_path):
        errors: list[str] = []
        validate.validate_index(str(tmp_path), errors)
        assert any("missing index.md" in e for e in errors)

    def test_index_without_h1_reports_error(self, tmp_path):
        write(str(tmp_path / "index.md"), "No heading here\n")
        errors: list[str] = []
        validate.validate_index(str(tmp_path), errors)
        assert any("missing an H1" in e for e in errors)

    def test_valid_index_reports_no_errors(self, tmp_path):
        write(str(tmp_path / "index.md"), "# My Library\n\nSome content.\n")
        errors: list[str] = []
        validate.validate_index(str(tmp_path), errors)
        assert errors == []

    def test_broken_relative_link_reports_error(self, tmp_path):
        content = "# My Library\n\n[Missing](skills/nonexistent.md)\n"
        write(str(tmp_path / "index.md"), content)
        errors: list[str] = []
        validate.validate_index(str(tmp_path), errors)
        assert any("broken link" in e for e in errors)

    def test_valid_relative_link_reports_no_error(self, tmp_path):
        target = tmp_path / "skills" / "my-skill.md"
        write(str(target), "# Skill\n\n**Source:** `video.md`\n")
        content = "# My Library\n\n[My Skill](skills/my-skill.md)\n"
        write(str(tmp_path / "index.md"), content)
        errors: list[str] = []
        validate.validate_index(str(tmp_path), errors)
        assert errors == []

    def test_http_links_are_not_checked(self, tmp_path):
        content = "# My Library\n\n[External](https://example.com)\n"
        write(str(tmp_path / "index.md"), content)
        errors: list[str] = []
        validate.validate_index(str(tmp_path), errors)
        assert errors == []


class TestValidateMd:
    def test_missing_h1_reports_error(self, tmp_path):
        path = str(tmp_path / "file.md")
        write(path, "No heading\n\n**Source:** `video.md`\n")
        errors: list[str] = []
        validate.validate_md(path, errors)
        assert any("missing an H1" in e for e in errors)

    def test_frontmatter_reports_error(self, tmp_path):
        path = str(tmp_path / "file.md")
        write(path, "---\ntitle: test\n---\n\n# Heading\n\n**Source:** `video.md`\n")
        errors: list[str] = []
        validate.validate_md(path, errors)
        assert any("frontmatter" in e for e in errors)

    def test_missing_source_citation_reports_error(self, tmp_path):
        path = str(tmp_path / "file.md")
        write(path, "# Heading\n\nContent without citation.\n")
        errors: list[str] = []
        validate.validate_md(path, errors)
        assert any("Source" in e for e in errors)

    def test_duplicate_h2_reports_error(self, tmp_path):
        path = str(tmp_path / "file.md")
        content = "# Heading\n\n**Source:** `video.md`\n\n## Same\n\n## Same\n"
        write(path, content)
        errors: list[str] = []
        validate.validate_md(path, errors)
        assert any("duplicate H2" in e for e in errors)

    def test_duplicate_h2_is_case_insensitive(self, tmp_path):
        path = str(tmp_path / "file.md")
        content = "# Heading\n\n**Source:** `video.md`\n\n## My Skill\n\n## my skill\n"
        write(path, content)
        errors: list[str] = []
        validate.validate_md(path, errors)
        assert any("duplicate H2" in e for e in errors)

    def test_valid_file_reports_no_errors(self, tmp_path):
        path = str(tmp_path / "file.md")
        content = "# Heading\n\n## Entry One\n\n**Source:** `video.md`\n\n## Entry Two\n\n**Source:** `other.md`\n"
        write(path, content)
        errors: list[str] = []
        validate.validate_md(path, errors)
        assert errors == []

    def test_sources_plural_is_accepted(self, tmp_path):
        path = str(tmp_path / "file.md")
        content = "# Heading\n\n**Sources:** `video.md`, `other.md`\n"
        write(path, content)
        errors: list[str] = []
        validate.validate_md(path, errors)
        source_errors = [e for e in errors if "Source" in e]
        assert source_errors == []
