#!/usr/bin/env python3
"""Focused tests for the first-30-minutes contributor guide checker."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_first_30_minutes.py")
SPEC = importlib.util.spec_from_file_location("check_first_30_minutes", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def seed_required_targets(root: Path) -> None:
    """Create placeholder files for every required guide link target."""
    for relative in checker.REQUIRED_LINK_TARGETS:
        write_text(root / relative, f"seed for {relative}\n")


def target_links(prefix: str = "") -> str:
    """Render Markdown list items for all required link targets."""
    return "\n".join(
        f"- [{target}]({prefix}{target})" for target in checker.REQUIRED_LINK_TARGETS
    )


def minimal_guide(link_prefix: str = "../") -> str:
    """Build the smallest first-30-minutes guide accepted by the checker."""
    commands = "\n".join(checker.REQUIRED_COMMANDS)
    links = target_links(link_prefix)
    return f"""# First 30 Minutes

This fresh-contributor path is pre-audit, not production-ready, does not prove
protocol correctness, and runs without production secrets.

## What This Guide Proves

This guide covers generated artifact drift, release manifest and checksum bundle
work, known and reviewed warning noise, public beta remains blocked, and
production release remains blocked.

## Prerequisites

Foundry `v1.7.1`, Solidity compiler `0.8.19`, Python 3.8 or newer, Slither
`0.11.5`, Windows PowerShell, and the PowerShell wrapper are named here.

## Clone And Verify Tools

`forge` is not on `PATH` is named here.

```sh
{commands}
```

## Run The Local Gate

Local gate details.

## Choose A Contribution Path

docs-only changes, Solidity or Foundry test changes, and release-artifact or
generated-evidence changes are named here.

## Generated Artifact Drift

Generated artifact drift details.

## Known Warning Noise

Known warning details.

## Troubleshooting

Troubleshooting details.

## No Secrets And Maturity Boundaries

Do not commit private keys or WalletConnect project secrets.

{links}
"""


class First30MinutesTests(unittest.TestCase):
    def test_accepts_committed_guide(self) -> None:
        """The committed guide satisfies the checker."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])

        self.assertEqual(result, 0)

    def test_accepts_minimal_valid_guide(self) -> None:
        """A minimal complete first-30-minutes guide passes validation."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(root / checker.DEFAULT_GUIDE, minimal_guide())

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_accepts_custom_guide_path(self) -> None:
        """The CLI accepts a non-default guide path."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            custom_path = Path("docs/onboarding/first-30.md")
            write_text(root / custom_path, minimal_guide("../../"))

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    ["--repo-root", str(root), "--guide", str(custom_path)]
                )

            self.assertEqual(result, 0)

    def test_rejects_missing_heading(self) -> None:
        """Missing required headings are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_guide().replace("## Generated Artifact Drift\n", "")
            write_text(root / checker.DEFAULT_GUIDE, text)

            with self.assertRaisesRegex(
                checker.First30MinutesError, "missing required headings"
            ):
                checker.validate_guide(root, root / checker.DEFAULT_GUIDE)

    def test_rejects_missing_required_phrase(self) -> None:
        """Missing setup or maturity language is rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_guide().replace("not production-ready", "ready")
            write_text(root / checker.DEFAULT_GUIDE, text)

            with self.assertRaisesRegex(
                checker.First30MinutesError, "missing required content"
            ):
                checker.validate_guide(root, root / checker.DEFAULT_GUIDE)

    def test_required_phrases_tolerate_markdown_wrapping(self) -> None:
        """Required phrases may span Markdown-wrapped lines."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_guide().replace(
                "release-artifact or\ngenerated-evidence changes",
                "release-artifact or generated-evidence changes",
            )
            write_text(root / checker.DEFAULT_GUIDE, text)

            checker.validate_guide(root, root / checker.DEFAULT_GUIDE)

    def test_rejects_missing_required_link(self) -> None:
        """Required navigation links cannot be silently dropped."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            original = minimal_guide()
            text = original.replace("- [docs/tooling.md](../docs/tooling.md)\n", "")
            self.assertNotEqual(text, original, "replacement had no effect")
            write_text(root / checker.DEFAULT_GUIDE, text)

            with self.assertRaisesRegex(
                checker.First30MinutesError, "missing required links"
            ):
                checker.validate_guide(root, root / checker.DEFAULT_GUIDE)

    def test_rejects_missing_linked_file(self) -> None:
        """Local links must resolve to existing repository files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            (root / "docs/tooling.md").unlink()
            write_text(root / checker.DEFAULT_GUIDE, minimal_guide())

            with self.assertRaisesRegex(
                checker.First30MinutesError, "linked targets are missing"
            ):
                checker.validate_guide(root, root / checker.DEFAULT_GUIDE)

    def test_rejects_missing_required_command(self) -> None:
        """Validation commands must stay visible in the guide."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_guide().replace("python scripts/check_first_30_minutes.py\n", "")
            write_text(root / checker.DEFAULT_GUIDE, text)

            with self.assertRaisesRegex(
                checker.First30MinutesError, "missing required commands"
            ):
                checker.validate_guide(root, root / checker.DEFAULT_GUIDE)

    def test_rejects_required_command_outside_code_fence(self) -> None:
        """Validation commands must be presented as runnable code lines."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_guide().replace("make check\n", "")
            text = text.replace(
                "## Run The Local Gate\n",
                "Required command mention: make check.\n\n## Run The Local Gate\n",
            )
            write_text(root / checker.DEFAULT_GUIDE, text)

            with self.assertRaisesRegex(
                checker.First30MinutesError, "missing required commands"
            ):
                checker.validate_guide(root, root / checker.DEFAULT_GUIDE)

    def test_accepts_forward_slash_windows_command_variants(self) -> None:
        """Windows helper paths may use slash variants in fenced code blocks."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_guide().replace(
                "scripts\\check.ps1",
                "scripts/check.ps1",
            ).replace(
                "scripts\\bootstrap-windows.ps1",
                "scripts/bootstrap-windows.ps1",
            )
            write_text(root / checker.DEFAULT_GUIDE, text)

            checker.validate_guide(root, root / checker.DEFAULT_GUIDE)


if __name__ == "__main__":
    unittest.main(verbosity=2)
