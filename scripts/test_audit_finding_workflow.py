#!/usr/bin/env python3
"""Focused tests for the audit finding workflow checker."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_audit_finding_workflow.py")
REPO_ROOT = SCRIPT_PATH.parent.parent
WORKFLOW_PATH = REPO_ROOT / "docs" / "audit-finding-workflow.md"
ISSUE_TEMPLATE_PATH = REPO_ROOT / ".github" / "ISSUE_TEMPLATE" / "audit_finding.yml"
SPEC = importlib.util.spec_from_file_location("check_audit_finding_workflow", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def read_workflow() -> str:
    return WORKFLOW_PATH.read_text(encoding="utf-8")


def read_issue_template() -> str:
    return ISSUE_TEMPLATE_PATH.read_text(encoding="utf-8")


def seed_required_targets(root: Path) -> None:
    for relative in checker.REQUIRED_LINK_TARGETS:
        write(root / relative, f"seed for {relative}\n")


class AuditFindingWorkflowTests(unittest.TestCase):
    def test_accepts_committed_workflow(self) -> None:
        """The committed workflow satisfies the checker."""
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(REPO_ROOT)])

        self.assertEqual(result, 0)

    def test_accepts_custom_paths(self) -> None:
        """The CLI accepts custom workflow and issue-template paths."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            workflow = root / checker.DEFAULT_WORKFLOW
            template = root / checker.DEFAULT_ISSUE_TEMPLATE
            write(workflow, read_workflow())
            write(template, read_issue_template())

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--workflow",
                        str(checker.DEFAULT_WORKFLOW),
                        "--issue-template",
                        str(checker.DEFAULT_ISSUE_TEMPLATE),
                    ]
                )

            self.assertEqual(result, 0)

    def test_rejects_missing_heading(self) -> None:
        """Required workflow sections cannot silently disappear."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            workflow = root / checker.DEFAULT_WORKFLOW
            template = root / checker.DEFAULT_ISSUE_TEMPLATE
            write(workflow, read_workflow().replace("## Accepted Risk\n", "## Risk\n"))
            write(template, read_issue_template())

            with self.assertRaisesRegex(
                checker.AuditFindingWorkflowError, "missing required headings"
            ):
                checker.validate_workflow(root, workflow, template)

    def test_rejects_duplicate_heading(self) -> None:
        """Required workflow sections stay unique."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            workflow = root / checker.DEFAULT_WORKFLOW
            template = root / checker.DEFAULT_ISSUE_TEMPLATE
            write(
                workflow,
                read_workflow().replace("## Triage", "## Triage\n\n## Triage", 1),
            )
            write(template, read_issue_template())

            with self.assertRaisesRegex(
                checker.AuditFindingWorkflowError, "duplicate required headings"
            ):
                checker.validate_workflow(root, workflow, template)

    def test_rejects_missing_required_command(self) -> None:
        """Validation commands must remain visible as runnable code."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            workflow = root / checker.DEFAULT_WORKFLOW
            template = root / checker.DEFAULT_ISSUE_TEMPLATE
            write(
                workflow,
                read_workflow().replace(
                    "python scripts/check_release_readiness.py\n", ""
                ),
            )
            write(template, read_issue_template())

            with self.assertRaisesRegex(
                checker.AuditFindingWorkflowError, "missing required commands"
            ):
                checker.validate_workflow(root, workflow, template)

    def test_rejects_command_outside_fenced_block(self) -> None:
        """Plain prose command mentions do not satisfy validation evidence."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            workflow = root / checker.DEFAULT_WORKFLOW
            template = root / checker.DEFAULT_ISSUE_TEMPLATE
            text = read_workflow().replace("make check\n", "")
            text = text.replace("## Remediation Path\n", "Mention make check.\n\n## Remediation Path\n")
            write(workflow, text)
            write(template, read_issue_template())

            with self.assertRaisesRegex(
                checker.AuditFindingWorkflowError, "missing required commands"
            ):
                checker.validate_workflow(root, workflow, template)

    def test_rejects_missing_required_link(self) -> None:
        """The workflow must keep release evidence handoff links."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            workflow = root / checker.DEFAULT_WORKFLOW
            template = root / checker.DEFAULT_ISSUE_TEMPLATE
            write(
                workflow,
                read_workflow().replace(
                    "[`docs/non-local-release-evidence.md`](non-local-release-evidence.md)",
                    "`docs/non-local-release-evidence.md`",
                ),
            )
            write(template, read_issue_template())

            with self.assertRaisesRegex(
                checker.AuditFindingWorkflowError, "missing required links"
            ):
                checker.validate_workflow(root, workflow, template)

    def test_accepts_anchor_and_query_local_links(self) -> None:
        """Local links may include anchors or query strings without path drift."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            workflow = root / checker.DEFAULT_WORKFLOW
            template = root / checker.DEFAULT_ISSUE_TEMPLATE
            write(
                workflow,
                read_workflow().replace(
                    "](audit-package.md)",
                    "](audit-package.md?view=review#scope)",
                    1,
                ),
            )
            write(template, read_issue_template())

            checker.validate_workflow(root, workflow, template)

    def test_rejects_issue_template_status_drift(self) -> None:
        """Issue-template status options remain aligned with the workflow."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            workflow = root / checker.DEFAULT_WORKFLOW
            template = root / checker.DEFAULT_ISSUE_TEMPLATE
            write(workflow, read_workflow())
            write(template, read_issue_template().replace("Ready for retest", "Ready"))

            with self.assertRaisesRegex(
                checker.AuditFindingWorkflowError, "missing required options"
            ):
                checker.validate_workflow(root, workflow, template)

    def test_rejects_issue_template_option_prefix_drift(self) -> None:
        """Required options must match exact YAML list items."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            workflow = root / checker.DEFAULT_WORKFLOW
            template = root / checker.DEFAULT_ISSUE_TEMPLATE
            write(workflow, read_workflow())
            write(template, read_issue_template().replace("- Low", "- Low severity"))

            with self.assertRaisesRegex(
                checker.AuditFindingWorkflowError, "missing required options"
            ):
                checker.validate_workflow(root, workflow, template)

    def test_rejects_issue_template_closure_check_drift(self) -> None:
        """Closure checks stay aligned with audit/release evidence policy."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            workflow = root / checker.DEFAULT_WORKFLOW
            template = root / checker.DEFAULT_ISSUE_TEMPLATE
            write(workflow, read_workflow())
            write(
                template,
                read_issue_template().replace(
                    "Release notes, risk register, and post-audit remediation evidence impact were considered.",
                    "Release impact was considered.",
                ),
            )

            with self.assertRaisesRegex(
                checker.AuditFindingWorkflowError, "missing required closure checks"
            ):
                checker.validate_workflow(root, workflow, template)


if __name__ == "__main__":
    unittest.main(verbosity=2)
