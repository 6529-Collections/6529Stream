#!/usr/bin/env python3
"""Focused tests for repository Markdown link validation."""

from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_markdown_links.py")
REPO_ROOT = SCRIPT_PATH.parent.parent
SPEC = importlib.util.spec_from_file_location("check_markdown_links", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)


def write(path: Path, value: str) -> None:
    """Write UTF-8 test content."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


class MarkdownLinkTests(unittest.TestCase):
    def test_default_roots_include_agents_guide(self) -> None:
        """The agent operating guide is part of the default checked docs."""
        self.assertIn(Path("AGENTS.md"), checker.DEFAULT_INCLUDED_ROOTS)

    def test_accepts_committed_markdown(self) -> None:
        """The committed Markdown corpus satisfies the checker."""
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(REPO_ROOT)])

        self.assertEqual(result, 0)

    def test_accepts_valid_local_file_and_anchor_links(self) -> None:
        """Existing files and generated heading anchors pass."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write(root / "README.md", "# Home\n\nSee [Guide](docs/guide.md#deep-link).\n")
            write(root / "docs" / "guide.md", "# Guide\n\n## Deep Link\n")

            checker.validate_markdown_links(root, [Path("README.md")])

    def test_accepts_same_file_anchor_link(self) -> None:
        """Same-file fragments are validated against local headings."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write(root / "README.md", "# Home\n\n[Jump](#deep-link)\n\n## Deep Link\n")

            checker.validate_markdown_links(root, [Path("README.md")])

    def test_accepts_duplicate_heading_suffix(self) -> None:
        """Duplicate Markdown headings expose GitHub-style numeric suffixes."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write(root / "README.md", "# Home\n\n[Second](docs/guide.md#item-1)\n")
            write(root / "docs" / "guide.md", "# Guide\n\n## Item\n\n## Item\n")

            checker.validate_markdown_links(root, [Path("README.md")])

    def test_accepts_line_anchor_within_file_length(self) -> None:
        """Line anchors pass when the referenced line exists."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write(root / "README.md", "# Home\n\n[Script](scripts/tool.py#L2)\n")
            write(root / "scripts" / "tool.py", "one\n two\n")

            checker.validate_markdown_links(root, [Path("README.md")])

    def test_ignores_links_inside_fenced_code_blocks(self) -> None:
        """Example links inside fenced code are not treated as repo links."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write(
                root / "README.md",
                "# Home\n\n```md\n[Broken](missing.md)\n```\n",
            )

            checker.validate_markdown_links(root, [Path("README.md")])

    def test_ignores_indented_tilde_fenced_code_blocks(self) -> None:
        """Indented tilde fences are stripped before link scanning."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write(
                root / "README.md",
                "# Home\n\n  ~~~md\n  [Broken](missing.md)\n  ~~~\n",
            )

            checker.validate_markdown_links(root, [Path("README.md")])

    def test_accepts_parentheses_inside_inline_link_target(self) -> None:
        """Inline targets may contain balanced parentheses."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write(root / "README.md", "# Home\n\n[Guide](docs/guide-(draft).md)\n")
            write(root / "docs" / "guide-(draft).md", "# Guide\n")

            checker.validate_markdown_links(root, [Path("README.md")])

    def test_accepts_reference_style_local_link_definition(self) -> None:
        """Reference-style link definitions are validated."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write(root / "README.md", "# Home\n\nSee [Guide][guide].\n\n[guide]: docs/guide.md\n")
            write(root / "docs" / "guide.md", "# Guide\n")

            checker.validate_markdown_links(root, [Path("README.md")])

    def test_rejects_missing_reference_style_target(self) -> None:
        """Broken reference-style local targets fail."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write(root / "README.md", "# Home\n\nSee [Guide][guide].\n\n[guide]: docs/missing.md\n")

            with self.assertRaisesRegex(checker.MarkdownLinkError, "target is missing"):
                checker.validate_markdown_links(root, [Path("README.md")])

    def test_rejects_missing_local_file(self) -> None:
        """Broken local file links fail with document context."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write(root / "README.md", "# Home\n\n[Missing](docs/missing.md)\n")

            with self.assertRaisesRegex(checker.MarkdownLinkError, "target is missing"):
                checker.validate_markdown_links(root, [Path("README.md")])

    def test_rejects_missing_markdown_anchor(self) -> None:
        """Markdown fragments must resolve to headings or explicit anchors."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write(root / "README.md", "# Home\n\n[Guide](docs/guide.md#missing)\n")
            write(root / "docs" / "guide.md", "# Guide\n")

            with self.assertRaisesRegex(checker.MarkdownLinkError, "missing Markdown anchor"):
                checker.validate_markdown_links(root, [Path("README.md")])

    def test_rejects_line_anchor_beyond_file_length(self) -> None:
        """Line anchors fail when they point beyond the target file."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write(root / "README.md", "# Home\n\n[Script](scripts/tool.py#L3)\n")
            write(root / "scripts" / "tool.py", "one\n two\n")

            with self.assertRaisesRegex(checker.MarkdownLinkError, "line anchor exceeds"):
                checker.validate_markdown_links(root, [Path("README.md")])

    def test_rejects_repository_escape(self) -> None:
        """Relative links cannot escape the repository."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write(root / "README.md", "# Home\n\n[Escape](../outside.md)\n")

            with self.assertRaisesRegex(checker.MarkdownLinkError, "escapes repository"):
                checker.validate_markdown_links(root, [Path("README.md")])

    def test_cli_accepts_custom_include(self) -> None:
        """The CLI accepts explicit include roots."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write(root / "docs" / "guide.md", "# Guide\n")

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    ["--repo-root", str(root), "--include", "docs/guide.md"]
                )

            self.assertEqual(result, 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
