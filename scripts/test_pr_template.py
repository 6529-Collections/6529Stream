#!/usr/bin/env python3
"""Focused tests for pull request template validation."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_pr_template.py")
REPO_ROOT = SCRIPT_PATH.parent.parent
TEMPLATE_PATH = REPO_ROOT / ".github" / "PULL_REQUEST_TEMPLATE.md"
SPEC = importlib.util.spec_from_file_location("check_pr_template", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def read_template() -> str:
    return TEMPLATE_PATH.read_text(encoding="utf-8")


def write(path: Path, value: str) -> None:
    path.write_text(value, encoding="utf-8", newline="\n")


class PullRequestTemplateTests(unittest.TestCase):
    def test_accepts_committed_template(self) -> None:
        """The committed PR template satisfies the checker."""
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main([])

        self.assertEqual(result, 0)

    def test_accepts_custom_template_path(self) -> None:
        """The CLI accepts a non-default template path."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "PULL_REQUEST_TEMPLATE.md"
            write(path, read_template())

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--template", str(path)])

            self.assertEqual(result, 0)

    def test_rejects_missing_template(self) -> None:
        """The checker fails clearly when the template is absent."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "missing.md"

            with self.assertRaisesRegex(
                checker.PullRequestTemplateError, "missing pull request template"
            ):
                checker.validate_pr_template(path)

    def test_rejects_missing_release_impact_heading(self) -> None:
        """Release-impact classification remains a required section."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "PULL_REQUEST_TEMPLATE.md"
            write(path, read_template().replace("## Release Impact", "## Impact"))

            with self.assertRaisesRegex(
                checker.PullRequestTemplateError, "missing required headings"
            ):
                checker.validate_pr_template(path)

    def test_rejects_missing_generated_artifact_field(self) -> None:
        """Generated-artifact impact cannot be silently dropped."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "PULL_REQUEST_TEMPLATE.md"
            write(
                path,
                read_template().replace(
                    "- Generated artifact impact: none / regenerated / intentionally unchanged with rationale\n",
                    "",
                ),
            )

            with self.assertRaisesRegex(
                checker.PullRequestTemplateError, "missing required fields"
            ):
                checker.validate_pr_template(path)

    def test_rejects_missing_no_secret_checkbox(self) -> None:
        """No-secret contributor posture remains explicit."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "PULL_REQUEST_TEMPLATE.md"
            write(
                path,
                read_template().replace(
                    "- [ ] No private keys, signer material, RPC secrets, or production deployment secrets are included.\n",
                    "",
                ),
            )

            with self.assertRaisesRegex(
                checker.PullRequestTemplateError, "missing required checkboxes"
            ):
                checker.validate_pr_template(path)

    def test_rejects_missing_breaking_change_checkbox(self) -> None:
        """Breaking-change approval remains explicit."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "PULL_REQUEST_TEMPLATE.md"
            write(
                path,
                read_template().replace(
                    "- [ ] Breaking changes are explicitly approved by a linked issue or ADR, or this PR has no breaking changes.\n",
                    "",
                ),
            )

            with self.assertRaisesRegex(
                checker.PullRequestTemplateError, "missing required checkboxes"
            ):
                checker.validate_pr_template(path)

    def test_rejects_missing_validation_code_block(self) -> None:
        """Validation command evidence remains a fenced code block."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "PULL_REQUEST_TEMPLATE.md"
            write(path, read_template().replace("# command and result summary", ""))

            with self.assertRaisesRegex(
                checker.PullRequestTemplateError, "validation command evidence"
            ):
                checker.validate_pr_template(path)


if __name__ == "__main__":
    unittest.main(verbosity=2)
