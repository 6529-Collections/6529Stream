#!/usr/bin/env python3
"""Validate autonomous run-state and execution-backlog consistency."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path


DEFAULT_RUN_STATE = Path("ops/AUTONOMOUS_RUN.md")
DEFAULT_BACKLOG = Path("ops/EXECUTION_BACKLOG.md")

REQUIRED_STATE_FIELDS = [
    "Remote",
    "Active PR branch",
    "Last merged PR",
    "Active issue",
    "Active PR",
    "Next issue",
    "Roadmap file",
    "Execution backlog file",
    "State file",
    "Last updated",
]

PR_URL_RE = re.compile(r"github\.com/6529-Collections/6529Stream/pull/(\d+)")
ISSUE_URL_RE = re.compile(r"github\.com/6529-Collections/6529Stream/issues/(\d+)")
ACTIVE_PR_WITH_ISSUE_RE = re.compile(r"\bActive PR #(?P<pr>\d+)\s*/\s*issue #(?P<issue>\d+)\b")
ACTIVE_ISSUE_ONLY_RE = re.compile(r"\bActive issue #(?P<issue>\d+)\b")
BRANCH_RE = re.compile(r"branch `([^`]+)`")


class AutonomousStateError(Exception):
    """Raised when autonomous state files disagree."""


@dataclass(frozen=True)
class ActiveBacklogRow:
    item_id: str
    title: str
    pr_number: int | None
    issue_number: int | None
    branch: str | None
    raw: str


def strip_cell(value: str) -> str:
    value = value.strip()
    if value.startswith("`") and value.endswith("`") and value.count("`") == 2:
        return value[1:-1]
    return value


def parse_current_state(run_state_text: str) -> dict[str, str]:
    lines = run_state_text.splitlines()
    in_section = False
    fields: dict[str, str] = {}

    for line in lines:
        if line.startswith("## "):
            in_section = line == "## Current Repository State"
            continue
        if not in_section or not line.startswith("|"):
            continue

        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) != 2:
            continue
        field, value = cells
        if field in {"Field", "---"} or value == "---":
            continue
        fields[strip_cell(field)] = strip_cell(value)

    missing = [field for field in REQUIRED_STATE_FIELDS if field not in fields]
    if missing:
        raise AutonomousStateError(
            "current repository state is missing required field(s): " + ", ".join(missing)
        )
    return fields


def number_from_url(value: str, regex: re.Pattern[str], field: str) -> int | None:
    if value == "TBD":
        return None
    match = regex.search(value)
    if not match:
        raise AutonomousStateError(f"{field} must be a GitHub URL or TBD: {value}")
    return int(match.group(1))


def parse_backlog_rows(backlog_text: str) -> list[ActiveBacklogRow]:
    rows: list[ActiveBacklogRow] = []
    for line in backlog_text.splitlines():
        if not line.startswith("| `"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) < 4:
            continue
        item_id = strip_cell(cells[0])
        title = cells[1]
        status = cells[-1]

        pr_issue_match = ACTIVE_PR_WITH_ISSUE_RE.search(status)
        issue_only_match = ACTIVE_ISSUE_ONLY_RE.search(status)
        branch_match = BRANCH_RE.search(status)
        if pr_issue_match or issue_only_match:
            rows.append(
                ActiveBacklogRow(
                    item_id=item_id,
                    title=title,
                    pr_number=int(pr_issue_match.group("pr")) if pr_issue_match else None,
                    issue_number=int(
                        pr_issue_match.group("issue")
                        if pr_issue_match
                        else issue_only_match.group("issue")
                    ),
                    branch=branch_match.group(1) if branch_match else None,
                    raw=line,
                )
            )
    return rows


def validate_state(run_state_path: Path, backlog_path: Path) -> None:
    state = parse_current_state(run_state_path.read_text(encoding="utf-8"))
    active_rows = parse_backlog_rows(backlog_path.read_text(encoding="utf-8"))

    active_pr_rows = [row for row in active_rows if row.pr_number is not None]
    active_issue_rows = [row for row in active_rows if row.issue_number is not None]
    if len(active_pr_rows) > 1:
        rows = ", ".join(f"{row.item_id} PR #{row.pr_number}" for row in active_pr_rows)
        raise AutonomousStateError(f"multiple backlog rows claim active PRs: {rows}")
    if len(active_issue_rows) > 1:
        rows = ", ".join(f"{row.item_id} issue #{row.issue_number}" for row in active_issue_rows)
        raise AutonomousStateError(f"multiple backlog rows claim active issues: {rows}")

    expected_pr = number_from_url(state["Active PR"], PR_URL_RE, "Active PR")
    expected_issue = number_from_url(state["Active issue"], ISSUE_URL_RE, "Active issue")
    expected_branch = state["Active PR branch"]

    if expected_pr is None:
        if active_pr_rows:
            row = active_pr_rows[0]
            raise AutonomousStateError(
                f"state Active PR is TBD but backlog still claims active PR #{row.pr_number}"
            )
        if expected_issue is None:
            return
        if not active_issue_rows:
            raise AutonomousStateError(
                f"state Active issue #{expected_issue} has no active backlog row"
            )
        active = active_issue_rows[0]
        if active.issue_number != expected_issue:
            raise AutonomousStateError(
                f"backlog active issue #{active.issue_number} does not match state issue #{expected_issue}"
            )
        if active.branch != expected_branch:
            raise AutonomousStateError(
                f"backlog active branch {active.branch!r} does not match state branch {expected_branch!r}"
            )
        return

    if not active_pr_rows:
        raise AutonomousStateError(f"state Active PR #{expected_pr} has no active backlog row")

    active = active_pr_rows[0]
    if active.pr_number != expected_pr:
        raise AutonomousStateError(
            f"backlog active PR #{active.pr_number} does not match state Active PR #{expected_pr}"
        )
    if active.issue_number != expected_issue:
        raise AutonomousStateError(
            f"backlog active issue #{active.issue_number} does not match state issue #{expected_issue}"
        )
    if active.branch != expected_branch:
        raise AutonomousStateError(
            f"backlog active branch {active.branch!r} does not match state branch {expected_branch!r}"
        )


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-state", type=Path, default=DEFAULT_RUN_STATE)
    parser.add_argument("--backlog", type=Path, default=DEFAULT_BACKLOG)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        validate_state(args.run_state, args.backlog)
    except AutonomousStateError as exc:
        print(f"autonomous state check failed: {exc}", file=sys.stderr)
        return 1
    print("autonomous state is consistent")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
