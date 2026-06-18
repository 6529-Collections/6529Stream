#!/usr/bin/env python3
"""Focused tests for live release evidence issue snapshot fetching."""

from __future__ import annotations

import importlib.util
import json
import subprocess
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
from typing import Sequence


SCRIPT_PATH = Path(__file__).with_name("fetch_release_evidence_issue_snapshot.py")
SPEC = importlib.util.spec_from_file_location(
    "fetch_release_evidence_issue_snapshot",
    SCRIPT_PATH,
)
assert SPEC is not None and SPEC.loader is not None
fetcher = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(fetcher)


def write_json(path: Path, value: object, *, bom: bool = False) -> None:
    """Write deterministic JSON while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(value, indent=2, sort_keys=True) + "\n"
    if bom:
        text = "\ufeff" + text
    path.write_text(text, encoding="utf-8", newline="\n")


def issue_links(numbers: list[int] | None = None) -> dict[str, object]:
    """Return a minimal release evidence issue links document."""
    return {
        "links": [
            {
                "entry_id": f"entry-{number}",
                "issue_number": number,
            }
            for number in (numbers or [215, 218])
        ]
    }


def gh_issue(number: int) -> dict[str, object]:
    """Return a GitHub issue view payload."""
    return {
        "number": number,
        "title": f"Issue {number}",
        "state": "OPEN",
        "body": f"Body {number}\n",
        "url": f"https://github.com/6529-Collections/6529Stream/issues/{number}",
        "closed": False,
        "closedAt": None,
    }


class FakeGh:
    """Callable fake for subprocess-backed gh commands."""

    def __init__(
        self,
        issues: dict[int, dict[str, object]] | None = None,
        *,
        returncode: int = 0,
        stdout: str | None = None,
        stderr: str = "",
    ) -> None:
        self.issues = issues or {215: gh_issue(215), 218: gh_issue(218)}
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr
        self.commands: list[list[str]] = []

    def __call__(
        self,
        command: Sequence[str],
        timeout_seconds: int,
    ) -> subprocess.CompletedProcess[str]:
        """Return mocked gh output for one command."""
        self.commands.append(list(command))
        if self.stdout is not None or self.returncode != 0:
            return subprocess.CompletedProcess(
                list(command),
                self.returncode,
                stdout=self.stdout or "",
                stderr=self.stderr,
            )
        issue_number = int(command[3])
        return subprocess.CompletedProcess(
            list(command),
            0,
            stdout=json.dumps(self.issues[issue_number]),
            stderr="",
        )


class ReleaseEvidenceIssueLiveSnapshotTests(unittest.TestCase):
    """Live issue snapshot fetcher behavior."""

    def test_builds_snapshot_for_linked_issues(self) -> None:
        """The fetcher reads exact linked issue numbers and preserves order."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            links = root / fetcher.DEFAULT_ISSUE_LINKS
            write_json(links, issue_links())
            fake_gh = FakeGh()

            snapshot = fetcher.build_snapshot(
                repo_root=root,
                issue_links_path=links,
                repo=fetcher.DEFAULT_REPO,
                gh="gh",
                timeout_seconds=10,
                run_command=fake_gh,
            )

        self.assertEqual(snapshot["schema_version"], fetcher.SNAPSHOT_SCHEMA)
        self.assertEqual([issue["number"] for issue in snapshot["issues"]], [215, 218])
        self.assertEqual(snapshot["source"]["issue_count"], 2)
        self.assertEqual(fake_gh.commands[0][0:6], ["gh", "issue", "view", "215", "--repo", fetcher.DEFAULT_REPO])

    def test_accepts_utf8_bom_issue_links(self) -> None:
        """Windows-exported issue-link JSON with a UTF-8 BOM is accepted."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            links = root / fetcher.DEFAULT_ISSUE_LINKS
            write_json(links, issue_links([215]), bom=True)

            numbers = fetcher.load_issue_numbers(links)

        self.assertEqual(numbers, [215])

    def test_rejects_duplicate_issue_links(self) -> None:
        """Duplicate linked issue numbers make the live snapshot ambiguous."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            links = root / fetcher.DEFAULT_ISSUE_LINKS
            write_json(links, issue_links([215, 215]))

            with self.assertRaisesRegex(
                fetcher.ReleaseEvidenceIssueSnapshotError,
                "duplicate issue_number",
            ):
                fetcher.load_issue_numbers(links)

    def test_rejects_gh_failure(self) -> None:
        """GitHub CLI failures are surfaced with the issue number."""
        fake_gh = FakeGh(returncode=1, stderr="not found")

        with self.assertRaisesRegex(
            fetcher.ReleaseEvidenceIssueSnapshotError,
            "gh issue view failed for #215: not found",
        ):
            fetcher.fetch_issue(
                gh="gh",
                repo=fetcher.DEFAULT_REPO,
                issue_number=215,
                timeout_seconds=10,
                run_command=fake_gh,
            )

    def test_rejects_invalid_gh_json(self) -> None:
        """Invalid GitHub CLI JSON fails closed."""
        fake_gh = FakeGh(stdout="{not json")

        with self.assertRaisesRegex(
            fetcher.ReleaseEvidenceIssueSnapshotError,
            "invalid JSON",
        ):
            fetcher.fetch_issue(
                gh="gh",
                repo=fetcher.DEFAULT_REPO,
                issue_number=215,
                timeout_seconds=10,
                run_command=fake_gh,
            )

    def test_rejects_wrong_issue_number(self) -> None:
        """A mismatched issue number from gh is not silently accepted."""
        fake_gh = FakeGh({215: gh_issue(218)})

        with self.assertRaisesRegex(
            fetcher.ReleaseEvidenceIssueSnapshotError,
            "while fetching #215",
        ):
            fetcher.fetch_issue(
                gh="gh",
                repo=fetcher.DEFAULT_REPO,
                issue_number=215,
                timeout_seconds=10,
                run_command=fake_gh,
            )

    def test_main_writes_snapshot_file(self) -> None:
        """CLI mode writes a deterministic snapshot file."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            links = root / fetcher.DEFAULT_ISSUE_LINKS
            output = root / "tmp" / "snapshot.json"
            write_json(links, issue_links([215]))

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = fetcher.main(
                    [
                        "--repo-root",
                        str(root),
                        "--issue-links",
                        str(links),
                        "--output",
                        str(output),
                    ],
                    run_command=FakeGh({215: gh_issue(215)}),
                )

            data = json.loads(output.read_text(encoding="utf-8"))

        self.assertEqual(result, 0)
        self.assertEqual(data["issues"][0]["number"], 215)

    def test_default_run_command_reports_missing_gh(self) -> None:
        """A missing GitHub CLI gets a user-facing setup error."""
        original_run = fetcher.subprocess.run

        def missing_gh(*_args: object, **_kwargs: object) -> object:
            raise FileNotFoundError("gh")

        fetcher.subprocess.run = missing_gh
        try:
            with self.assertRaisesRegex(
                fetcher.ReleaseEvidenceIssueSnapshotError,
                "install GitHub CLI or pass --gh",
            ):
                fetcher.default_run_command(["gh", "issue", "view", "215"], 10)
        finally:
            fetcher.subprocess.run = original_run

    def test_default_run_command_reports_timeout(self) -> None:
        """A timed-out GitHub CLI call fails closed with command context."""
        original_run = fetcher.subprocess.run

        def timeout(*args: object, **kwargs: object) -> object:
            raise subprocess.TimeoutExpired(
                cmd=args[0],
                timeout=kwargs.get("timeout", 10),
            )

        fetcher.subprocess.run = timeout
        try:
            with self.assertRaisesRegex(
                fetcher.ReleaseEvidenceIssueSnapshotError,
                "timed out while fetching issue snapshot",
            ):
                fetcher.default_run_command(["gh", "issue", "view", "215"], 10)
        finally:
            fetcher.subprocess.run = original_run


if __name__ == "__main__":
    unittest.main(verbosity=2)
