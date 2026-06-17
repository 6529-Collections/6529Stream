#!/usr/bin/env python3
"""Focused tests for the withdrawals and credits flow checker."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_withdrawals_credits_flow.py")
SPEC = importlib.util.spec_from_file_location("check_withdrawals_credits_flow", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def seed_required_targets(root: Path) -> None:
    for relative in checker.REQUIRED_LINK_TARGETS:
        write_text(root / relative, f"seed for {relative}\n")
    for relative, symbols in checker.SOURCE_EXPECTATIONS.items():
        write_text(root / relative, "\n".join(symbols) + "\n")


def target_links() -> str:
    return "\n".join(
        f"- [{target}](../../{target})" for target in checker.REQUIRED_LINK_TARGETS
    )


def minimal_doc() -> str:
    commands = "\n".join(checker.REQUIRED_COMMANDS)
    phrases = "\n".join(checker.REQUIRED_PHRASES)
    links = target_links()
    headings = "\n\n".join(
        f"{'#' * level} {title}\n\n{phrases if index == 0 else 'section body'}"
        for index, (level, title) in enumerate(checker.REQUIRED_HEADINGS)
    )
    return f"""{headings}

## Source Of Truth

{links}

## Validation Commands

```sh
{commands}
```
"""


class WithdrawalsCreditsFlowTests(unittest.TestCase):
    def test_accepts_committed_doc(self) -> None:
        repo_root = Path(__file__).resolve().parents[1]
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])
        self.assertEqual(result, 0)

    def test_accepts_minimal_valid_doc(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(root / checker.DEFAULT_DOC, minimal_doc())
            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])
            self.assertEqual(result, 0)

    def test_accepts_custom_doc_path(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            custom_path = Path("docs/custom-withdrawals/credits.md")
            write_text(root / custom_path, minimal_doc())
            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root), "--doc", str(custom_path)])
            self.assertEqual(result, 0)

    def test_rejects_missing_heading(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_doc().replace("## Failure States\n", "")
            write_text(root / checker.DEFAULT_DOC, text)
            with self.assertRaisesRegex(
                checker.WithdrawalsCreditsFlowError, "missing required headings"
            ):
                checker.validate_withdrawals_credits_flow(root, root / checker.DEFAULT_DOC)

    def test_rejects_missing_required_phrase(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_doc().replace("not production-ready", "ready")
            write_text(root / checker.DEFAULT_DOC, text)
            with self.assertRaisesRegex(
                checker.WithdrawalsCreditsFlowError, "missing required content"
            ):
                checker.validate_withdrawals_credits_flow(root, root / checker.DEFAULT_DOC)

    def test_required_commands_tolerate_markdown_wrapping(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_doc().replace(
                "python scripts/generate_release_manifest.py --check",
                "python scripts/generate_release_manifest.py\n--check",
            )
            write_text(root / checker.DEFAULT_DOC, text)
            checker.validate_withdrawals_credits_flow(root, root / checker.DEFAULT_DOC)

    def test_rejects_missing_required_link(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            original = minimal_doc()
            text = original.replace(
                "- [smart-contracts/StreamDrops.sol](../../smart-contracts/StreamDrops.sol)\n",
                "",
            )
            self.assertNotEqual(text, original, "replacement had no effect")
            write_text(root / checker.DEFAULT_DOC, text)
            with self.assertRaisesRegex(
                checker.WithdrawalsCreditsFlowError, "missing required links"
            ):
                checker.validate_withdrawals_credits_flow(root, root / checker.DEFAULT_DOC)

    def test_rejects_missing_linked_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            (root / "smart-contracts/StreamDrops.sol").unlink()
            write_text(root / checker.DEFAULT_DOC, minimal_doc())
            with self.assertRaisesRegex(
                checker.WithdrawalsCreditsFlowError, "linked targets are missing"
            ):
                checker.validate_withdrawals_credits_flow(root, root / checker.DEFAULT_DOC)

    def test_rejects_source_surface_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            source_path = root / "smart-contracts/AuctionContract.sol"
            source_path.write_text(
                source_path.read_text(encoding="utf-8").replace("auctionBidderCredits", ""),
                encoding="utf-8",
                newline="\n",
            )
            write_text(root / checker.DEFAULT_DOC, minimal_doc())
            with self.assertRaisesRegex(
                checker.WithdrawalsCreditsFlowError, "source surface no longer matches"
            ):
                checker.validate_withdrawals_credits_flow(root, root / checker.DEFAULT_DOC)


if __name__ == "__main__":
    unittest.main(verbosity=2)
