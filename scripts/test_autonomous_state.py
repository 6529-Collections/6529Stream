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

    def test_accepts_tbd_active_pr_when_backlog_has_no_active_pr(self) -> None:
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


if __name__ == "__main__":
    raise SystemExit(unittest.main(verbosity=2))
