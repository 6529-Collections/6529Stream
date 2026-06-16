#!/usr/bin/env python3
"""Focused tests for the warning-disposition checker."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_warning_dispositions.py")
SPEC = importlib.util.spec_from_file_location("check_warning_dispositions", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def seed_required_targets(root: Path) -> None:
    """Create placeholder files for required links and source markers."""
    marker_paths = set(checker.SOURCE_MARKERS)
    for relative in checker.REQUIRED_LINK_TARGETS:
        if relative in marker_paths:
            snippets = "\n".join(checker.SOURCE_MARKERS[relative])
            write_text(root / relative, f"// SPDX-License-Identifier: MIT\n{snippets}\n")
        elif relative.startswith("smart-contracts/") and relative.endswith(".sol"):
            write_text(
                root / relative,
                "// SPDX-License-Identifier: MIT\n/** @title Valid header */\n",
            )
        else:
            write_text(root / relative, f"seed for {relative}\n")


def target_links() -> str:
    """Render Markdown list items for all required link targets."""
    return "\n".join(
        f"- [{target}](../{target})" for target in checker.REQUIRED_LINK_TARGETS
    )


def minimal_warning_doc() -> str:
    """Build the smallest warning-disposition doc accepted by the checker."""
    commands = "\n".join(checker.REQUIRED_COMMANDS)
    links = target_links()
    required_content = "\n".join(f"- {phrase}" for phrase in checker.REQUIRED_PHRASES)
    return f"""# Warning Dispositions

This ONE-007 pre-audit local baseline is not production-ready and not a
security claim.

## Maturity And Scope

{required_content}

## Current Warning Baseline

{links}

## Fixed In This Pass

NATSPEC-INVALID-FIRST-PARTY-HEADERS is fixed.

## Accepted Solc Warning Dispositions

The solc warning rows are retained.

## Accepted Documentation And Linter Dispositions

The documentation and linter warning rows are retained.

## Size And ABI Policy

Warning fixes preserve ABI-neutral and bytecode-neutral behavior unless
reviewed.

## Validation Commands

```sh
{commands}
```

## Maintenance

Keep warning dispositions current.
"""


class WarningDispositionTests(unittest.TestCase):
    def test_accepts_committed_doc(self) -> None:
        """The committed warning-disposition document satisfies the checker."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])

        self.assertEqual(result, 0)

    def test_accepts_minimal_valid_doc(self) -> None:
        """A minimal complete warning-disposition document passes validation."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(root / checker.DEFAULT_WARNING_DISPOSITIONS, minimal_warning_doc())

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_accepts_custom_doc_path(self) -> None:
        """The CLI accepts a non-default warning-disposition path."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            custom_path = Path("docs/custom-warning-dispositions.md")
            write_text(root / custom_path, minimal_warning_doc())

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--warning-dispositions",
                        str(custom_path),
                    ]
                )

            self.assertEqual(result, 0)

    def test_rejects_missing_heading(self) -> None:
        """Missing required sections are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_warning_doc().replace("## Size And ABI Policy\n", "")
            write_text(root / checker.DEFAULT_WARNING_DISPOSITIONS, text)

            with self.assertRaisesRegex(
                checker.WarningDispositionError, "missing required headings"
            ):
                checker.validate_warning_dispositions(
                    root, root / checker.DEFAULT_WARNING_DISPOSITIONS
                )

    def test_rejects_missing_required_phrase(self) -> None:
        """Required warning IDs cannot disappear from the disposition doc."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_warning_doc().replace("SOLC-PURE-ROYALTY", "SOLC-ROYALTY")
            write_text(root / checker.DEFAULT_WARNING_DISPOSITIONS, text)

            with self.assertRaisesRegex(
                checker.WarningDispositionError, "missing required content"
            ):
                checker.validate_warning_dispositions(
                    root, root / checker.DEFAULT_WARNING_DISPOSITIONS
                )

    def test_rejects_missing_required_command(self) -> None:
        """Validation commands must stay visible."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_warning_doc().replace(
                "python scripts/check_warning_dispositions.py\n", ""
            )
            write_text(root / checker.DEFAULT_WARNING_DISPOSITIONS, text)

            with self.assertRaisesRegex(
                checker.WarningDispositionError, "missing required commands"
            ):
                checker.validate_warning_dispositions(
                    root, root / checker.DEFAULT_WARNING_DISPOSITIONS
                )

    def test_rejects_missing_required_link(self) -> None:
        """Required warning-source links cannot be silently removed."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            original = minimal_warning_doc()
            text = original.replace(
                "- [docs/tooling.md](../docs/tooling.md)\n", ""
            )
            self.assertNotEqual(text, original, "replacement had no effect")
            write_text(root / checker.DEFAULT_WARNING_DISPOSITIONS, text)

            with self.assertRaisesRegex(
                checker.WarningDispositionError, "missing required links"
            ):
                checker.validate_warning_dispositions(
                    root, root / checker.DEFAULT_WARNING_DISPOSITIONS
                )

    def test_rejects_missing_linked_file(self) -> None:
        """Local links must resolve to files in the repository."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            (root / "docs" / "tooling.md").unlink()
            write_text(root / checker.DEFAULT_WARNING_DISPOSITIONS, minimal_warning_doc())

            with self.assertRaisesRegex(
                checker.WarningDispositionError, "links to missing files"
            ):
                checker.validate_warning_dispositions(
                    root, root / checker.DEFAULT_WARNING_DISPOSITIONS
                )

    def test_rejects_invalid_natspec_tag_regression(self) -> None:
        """Legacy colon-suffixed NatSpec tags are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            source = root / "smart-contracts" / "StreamCore.sol"
            source.write_text(
                source.read_text(encoding="utf-8") + "\n/// @title: Bad\n",
                encoding="utf-8",
                newline="\n",
            )
            write_text(root / checker.DEFAULT_WARNING_DISPOSITIONS, minimal_warning_doc())

            with self.assertRaisesRegex(
                checker.WarningDispositionError, "invalid NatSpec header tags"
            ):
                checker.validate_warning_dispositions(
                    root, root / checker.DEFAULT_WARNING_DISPOSITIONS
                )

    def test_rejects_missing_source_marker(self) -> None:
        """Accepted warning rows must stay anchored to current source."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            source = root / "smart-contracts" / "RandomizerNXT.sol"
            source.write_text(
                source.read_text(encoding="utf-8").replace("_saltfun_o", ""),
                encoding="utf-8",
                newline="\n",
            )
            write_text(root / checker.DEFAULT_WARNING_DISPOSITIONS, minimal_warning_doc())

            with self.assertRaisesRegex(
                checker.WarningDispositionError, "source markers drifted"
            ):
                checker.validate_warning_dispositions(
                    root, root / checker.DEFAULT_WARNING_DISPOSITIONS
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
