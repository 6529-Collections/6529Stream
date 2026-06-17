#!/usr/bin/env python3
"""Focused tests for GitHub issue-template validation."""

from __future__ import annotations

import importlib.util
import shutil
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_issue_templates.py")
REPO_ROOT = SCRIPT_PATH.parent.parent
SPEC = importlib.util.spec_from_file_location("check_issue_templates", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def copy_templates(root: Path) -> Path:
    """Copy committed issue templates into a temporary repository tree."""
    destination = root / checker.DEFAULT_TEMPLATE_DIR
    shutil.copytree(REPO_ROOT / checker.DEFAULT_TEMPLATE_DIR, destination)
    return destination


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write(path: Path, value: str) -> None:
    path.write_text(value, encoding="utf-8", newline="\n")


class IssueTemplateTests(unittest.TestCase):
    def test_accepts_committed_templates(self) -> None:
        """The committed issue templates satisfy the checker."""
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main([])

        self.assertEqual(result, 0)

    def test_accepts_custom_template_dir(self) -> None:
        """The CLI accepts a non-default template directory."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            template_dir = copy_templates(root)

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--template-dir", str(template_dir)])

            self.assertEqual(result, 0)

    def test_rejects_missing_template(self) -> None:
        """All required forms must exist."""
        with tempfile.TemporaryDirectory() as temp_dir:
            template_dir = copy_templates(Path(temp_dir))
            (template_dir / "integration_report.yml").unlink()

            with self.assertRaisesRegex(
                checker.IssueTemplateError, "missing issue template"
            ):
                checker.validate_issue_templates(template_dir)

    def test_rejects_missing_label(self) -> None:
        """Required labels cannot be silently dropped."""
        with tempfile.TemporaryDirectory() as temp_dir:
            template_dir = copy_templates(Path(temp_dir))
            path = template_dir / "release_evidence.yml"
            write(path, read(path).replace("  - evidence\n", ""))

            with self.assertRaisesRegex(
                checker.IssueTemplateError, "missing required labels"
            ):
                checker.validate_issue_templates(template_dir)

    def test_rejects_malformed_labels_block(self) -> None:
        """Malformed labels blocks fail before being treated as absent labels."""
        with tempfile.TemporaryDirectory() as temp_dir:
            template_dir = copy_templates(Path(temp_dir))
            path = template_dir / "integration_report.yml"
            write(
                path,
                read(path).replace(
                    "labels:\n  - integration\n  - documentation\n",
                    "labels:\n  integration\n  documentation\n",
                ),
            )

            with self.assertRaisesRegex(
                checker.IssueTemplateError, "malformed labels block"
            ):
                checker.validate_issue_templates(template_dir)

    def test_rejects_missing_field_id(self) -> None:
        """Required issue-form IDs cannot be silently dropped."""
        with tempfile.TemporaryDirectory() as temp_dir:
            template_dir = copy_templates(Path(temp_dir))
            path = template_dir / "audit_finding.yml"
            write(path, read(path).replace("    id: threat_model\n", ""))

            with self.assertRaisesRegex(
                checker.IssueTemplateError, "missing required field ids"
            ):
                checker.validate_issue_templates(template_dir)

    def test_rejects_missing_maturity_language(self) -> None:
        """Pre-audit and no-production claims must stay visible."""
        with tempfile.TemporaryDirectory() as temp_dir:
            template_dir = copy_templates(Path(temp_dir))
            path = template_dir / "integration_report.yml"
            write(path, read(path).replace("not production-ready", "ready"))

            with self.assertRaisesRegex(
                checker.IssueTemplateError, "missing required content"
            ):
                checker.validate_issue_templates(template_dir)

    def test_rejects_missing_no_secret_guidance(self) -> None:
        """No-secret guidance is part of evidence intake."""
        with tempfile.TemporaryDirectory() as temp_dir:
            template_dir = copy_templates(Path(temp_dir))
            path = template_dir / "release_evidence.yml"
            write(path, read(path).replace("production deployment secrets", ""))

            with self.assertRaisesRegex(
                checker.IssueTemplateError, "missing required content"
            ):
                checker.validate_issue_templates(template_dir)

    def test_rejects_missing_private_security_guidance(self) -> None:
        """Audit findings must preserve private disclosure guidance."""
        with tempfile.TemporaryDirectory() as temp_dir:
            template_dir = copy_templates(Path(temp_dir))
            path = template_dir / "audit_finding.yml"
            write(path, read(path).replace("SECURITY.md", "security docs"))

            with self.assertRaisesRegex(
                checker.IssueTemplateError, "missing required content"
            ):
                checker.validate_issue_templates(template_dir)

    def test_rejects_missing_required_validations(self) -> None:
        """Templates must keep required field validations."""
        with tempfile.TemporaryDirectory() as temp_dir:
            template_dir = copy_templates(Path(temp_dir))
            path = template_dir / "integration_report.yml"
            write(path, read(path).replace("validations:\n      required: true", ""))

            with self.assertRaisesRegex(
                checker.IssueTemplateError, "required field validations"
            ):
                checker.validate_issue_templates(template_dir)

    def test_rejects_missing_config_link(self) -> None:
        """Config contact links remain part of the checked issue surface."""
        with tempfile.TemporaryDirectory() as temp_dir:
            template_dir = copy_templates(Path(temp_dir))
            path = template_dir / "config.yml"
            write(path, read(path).replace("Integration documentation", "Integration docs"))

            with self.assertRaisesRegex(
                checker.IssueTemplateError, "missing required content"
            ):
                checker.validate_issue_templates(template_dir)


if __name__ == "__main__":
    unittest.main(verbosity=2)
