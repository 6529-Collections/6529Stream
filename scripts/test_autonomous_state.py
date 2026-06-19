#!/usr/bin/env python3
"""Focused tests for the autonomous state checker."""

from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_autonomous_state.py")
SPEC = importlib.util.spec_from_file_location("check_autonomous_state", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def run_state(
    *,
    branch: str = "codex/example",
    issue: str = "https://github.com/6529-Collections/6529Stream/issues/123",
    pr: str = "https://github.com/6529-Collections/6529Stream/pull/124",
) -> str:
    return f"""# Autonomous Run State

## Current Repository State

| Field | Value |
| --- | --- |
| Remote | `https://github.com/6529-Collections/6529Stream.git` |
| Active PR branch | `{branch}` |
| Last merged PR | `https://github.com/6529-Collections/6529Stream/pull/122` |
| Active issue | `{issue}` |
| Active PR | `{pr}` |
| Next issue | Continue the active PR. |
| Roadmap file | `ops/ROADMAP.md` |
| Execution backlog file | `ops/EXECUTION_BACKLOG.md` |
| State file | `ops/AUTONOMOUS_RUN.md` |
| Last updated | `2026-06-18 18:00 UTC` |

## Worklog
"""


def backlog(active_row: str) -> str:
    return f"""# Execution Backlog

## Later PR Inventory

| Item | Intended PR | Gate | Dependency |
| --- | --- | --- | --- |
{active_row}
"""


def backlog_with_detail(active_row: str, detail: str) -> str:
    return backlog(active_row) + f"""
### OSS-999: Detailed Example

{detail}

Gate: G.
"""


def active_row(
    *,
    item: str = "REL-999",
    title: str = "Example active item",
    pr: int = 124,
    issue: int = 123,
    branch: str = "codex/example",
) -> str:
    return (
        f"| `{item}` | {title} | G | Active PR #{pr} / issue #{issue} "
        f"on branch `{branch}`; continue the work |"
    )


def active_issue_row(
    *,
    item: str = "OSS-999",
    title: str = "Example active issue",
    issue: int = 123,
    branch: str = "codex/example",
) -> str:
    return (
        f"| `{item}` | {title} | G | Active issue #{issue} "
        f"on branch `{branch}`; continue before opening a PR |"
    )


class AutonomousStateTests(unittest.TestCase):
    def write_case(self, root: Path, state_text: str, backlog_text: str) -> tuple[Path, Path]:
        run_state_path = root / checker.DEFAULT_RUN_STATE
        backlog_path = root / checker.DEFAULT_BACKLOG
        write_text(run_state_path, state_text)
        write_text(backlog_path, backlog_text)
        return run_state_path, backlog_path

    def test_accepts_committed_state(self) -> None:
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(
                [
                    "--run-state",
                    str(repo_root / checker.DEFAULT_RUN_STATE),
                    "--backlog",
                    str(repo_root / checker.DEFAULT_BACKLOG),
                ]
            )

        self.assertEqual(result, 0)

    def test_accepts_matching_active_state(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            run_state_path, backlog_path = self.write_case(
                root,
                run_state(),
                backlog(active_row()),
            )

            checker.validate_state(run_state_path, backlog_path)

    def test_strip_cell_only_unwraps_single_code_span(self) -> None:
        self.assertEqual(checker.strip_cell("`TBD`"), "TBD")
        self.assertEqual(checker.strip_cell("`a` and `b`"), "`a` and `b`")

    def test_rejects_multiple_active_pr_rows(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            run_state_path, backlog_path = self.write_case(
                root,
                run_state(),
                backlog(active_row() + "\n" + active_row(item="REL-998", pr=126, issue=125)),
            )

            with self.assertRaisesRegex(checker.AutonomousStateError, "multiple backlog rows"):
                checker.validate_state(run_state_path, backlog_path)

    def test_rejects_multiple_active_issue_rows(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            run_state_path, backlog_path = self.write_case(
                root,
                run_state(pr="TBD"),
                backlog(
                    active_issue_row()
                    + "\n"
                    + active_issue_row(item="OSS-998", issue=125)
                ),
            )

            with self.assertRaisesRegex(checker.AutonomousStateError, "multiple backlog rows"):
                checker.validate_state(run_state_path, backlog_path)

    def test_active_pr_issue_parser_ignores_unrelated_issue_text(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            row = (
                "| `REL-999` | Example active item | G | See issue #999 for "
                "historical context; Active PR #124 / issue #123 on branch "
                "`codex/example`; continue the work |"
            )
            run_state_path, backlog_path = self.write_case(root, run_state(), backlog(row))

            checker.validate_state(run_state_path, backlog_path)

    def test_rejects_mismatched_active_pr(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            run_state_path, backlog_path = self.write_case(
                root,
                run_state(),
                backlog(active_row(pr=999)),
            )

            with self.assertRaisesRegex(checker.AutonomousStateError, "does not match state"):
                checker.validate_state(run_state_path, backlog_path)

    def test_rejects_mismatched_active_issue(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            run_state_path, backlog_path = self.write_case(
                root,
                run_state(),
                backlog(active_row(issue=999)),
            )

            with self.assertRaisesRegex(checker.AutonomousStateError, "active issue"):
                checker.validate_state(run_state_path, backlog_path)

    def test_rejects_mismatched_active_branch(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            run_state_path, backlog_path = self.write_case(
                root,
                run_state(),
                backlog(active_row(branch="codex/other")),
            )

            with self.assertRaisesRegex(checker.AutonomousStateError, "active branch"):
                checker.validate_state(run_state_path, backlog_path)

    def test_rejects_missing_required_state_field(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            state = run_state().replace("| Active PR | `https://github.com/6529-Collections/6529Stream/pull/124` |\n", "")
            run_state_path, backlog_path = self.write_case(root, state, backlog(active_row()))

            with self.assertRaisesRegex(checker.AutonomousStateError, "missing required field"):
                checker.validate_state(run_state_path, backlog_path)

    def test_accepts_tbd_active_pr_with_matching_active_issue_row(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            run_state_path, backlog_path = self.write_case(
                root,
                run_state(pr="TBD"),
                backlog(active_issue_row()),
            )

            checker.validate_state(run_state_path, backlog_path)

    def test_rejects_tbd_active_pr_without_active_issue_row(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            inactive_backlog = backlog(
                "| `REL-999` | Example inactive item | G | Merged in PR #124; issue #123 closed completed |"
            )
            run_state_path, backlog_path = self.write_case(
                root,
                run_state(pr="TBD"),
                inactive_backlog,
            )

            with self.assertRaisesRegex(checker.AutonomousStateError, "no active backlog row"):
                checker.validate_state(run_state_path, backlog_path)

    def test_rejects_tbd_active_pr_with_mismatched_active_issue(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            run_state_path, backlog_path = self.write_case(
                root,
                run_state(pr="TBD"),
                backlog(active_issue_row(issue=999)),
            )

            with self.assertRaisesRegex(checker.AutonomousStateError, "active issue"):
                checker.validate_state(run_state_path, backlog_path)

    def test_rejects_tbd_active_pr_with_mismatched_active_issue_branch(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            run_state_path, backlog_path = self.write_case(
                root,
                run_state(pr="TBD"),
                backlog(active_issue_row(branch="codex/other")),
            )

            with self.assertRaisesRegex(checker.AutonomousStateError, "active branch"):
                checker.validate_state(run_state_path, backlog_path)

    def test_rejects_tbd_active_pr_when_backlog_claims_active_pr(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            run_state_path, backlog_path = self.write_case(
                root,
                run_state(pr="TBD"),
                backlog(active_row()),
            )

            with self.assertRaisesRegex(checker.AutonomousStateError, "Active PR is TBD"):
                checker.validate_state(run_state_path, backlog_path)

    def test_accepts_matching_active_detailed_status(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            run_state_path, backlog_path = self.write_case(
                root,
                run_state(pr="TBD"),
                backlog_with_detail(
                    active_issue_row(),
                    "Status: Active issue #123 on branch `codex/example`.",
                ),
            )

            checker.validate_state(run_state_path, backlog_path)

    def test_accepts_matching_active_detailed_status_with_repeated_references(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            run_state_path, backlog_path = self.write_case(
                root,
                run_state(),
                backlog_with_detail(
                    active_row(),
                    (
                        "Status: Active PR #124 / issue #123 on branch `codex/example`. "
                        "Follow-up remains on issue #123 and PR #124."
                    ),
                ),
            )

            checker.validate_state(run_state_path, backlog_path)

    def test_rejects_active_detailed_status_with_secondary_stale_issue(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            run_state_path, backlog_path = self.write_case(
                root,
                run_state(pr="TBD"),
                backlog_with_detail(
                    active_issue_row(),
                    "Status: Active issue #123; stale tracker issue #999 remains in prose.",
                ),
            )

            with self.assertRaisesRegex(checker.AutonomousStateError, "issue reference"):
                checker.validate_state(run_state_path, backlog_path)

    def test_rejects_active_detailed_status_with_secondary_stale_pr(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            run_state_path, backlog_path = self.write_case(
                root,
                run_state(),
                backlog_with_detail(
                    active_row(),
                    "Status: Active PR #124 / issue #123; superseded stale PR #999 is closed.",
                ),
            )

            with self.assertRaisesRegex(checker.AutonomousStateError, "PR reference"):
                checker.validate_state(run_state_path, backlog_path)

    def test_rejects_active_detailed_status_with_pr_when_state_has_no_active_pr(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            run_state_path, backlog_path = self.write_case(
                root,
                run_state(pr="TBD"),
                backlog_with_detail(
                    active_issue_row(),
                    "Status: Active issue #123; PR #124 will be opened after validation.",
                ),
            )

            with self.assertRaisesRegex(checker.AutonomousStateError, "no active PR"):
                checker.validate_state(run_state_path, backlog_path)

    def test_inactive_detailed_status_does_not_match_incidental_progress_text(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            run_state_path, backlog_path = self.write_case(
                root,
                run_state(pr="TBD"),
                backlog_with_detail(
                    active_issue_row(),
                    "Status: Planned; no longer in progress on stale issue #999.",
                ),
            )

            checker.validate_state(run_state_path, backlog_path)

    def test_detailed_status_parser_ignores_fenced_examples(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            run_state_path, backlog_path = self.write_case(
                root,
                run_state(pr="TBD"),
                backlog_with_detail(
                    active_issue_row(),
                    "\n".join(
                        [
                            "```text",
                            "Status: In progress on issue #999.",
                            "```",
                            "Status: Active issue #123 on branch `codex/example`.",
                        ]
                    ),
                ),
            )

            checker.validate_state(run_state_path, backlog_path)

    def test_rejects_stale_in_progress_detailed_status(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            run_state_path, backlog_path = self.write_case(
                root,
                run_state(pr="TBD"),
                backlog_with_detail(
                    active_issue_row(),
                    "Status: In progress on issue #999.",
                ),
            )

            with self.assertRaisesRegex(checker.AutonomousStateError, "issue reference"):
                checker.validate_state(run_state_path, backlog_path)

    def test_rejects_stale_pr_not_opened_detailed_status(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            run_state_path, backlog_path = self.write_case(
                root,
                run_state(pr="TBD"),
                backlog_with_detail(
                    active_issue_row(),
                    (
                        "Status: Local validation complete on issue #999 and branch "
                        "`codex/old`; PR not opened yet."
                    ),
                ),
            )

            with self.assertRaisesRegex(checker.AutonomousStateError, "issue reference"):
                checker.validate_state(run_state_path, backlog_path)

    def test_rejects_active_detailed_status_branch_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            run_state_path, backlog_path = self.write_case(
                root,
                run_state(pr="TBD"),
                backlog_with_detail(
                    active_issue_row(),
                    "Status: Active issue #123 on branch `codex/old`.",
                ),
            )

            with self.assertRaisesRegex(checker.AutonomousStateError, "does not match state branch"):
                checker.validate_state(run_state_path, backlog_path)


if __name__ == "__main__":
    raise SystemExit(unittest.main(verbosity=2))
