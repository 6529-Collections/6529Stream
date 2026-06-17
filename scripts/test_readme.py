#!/usr/bin/env python3
"""Focused tests for the root README checker."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_readme.py")
SPEC = importlib.util.spec_from_file_location("check_readme", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def seed_required_targets(root: Path) -> None:
    """Create placeholder files for every required README link target."""
    for relative in checker.REQUIRED_LINK_TARGETS:
        write_text(root / relative, f"seed for {relative}\n")


def target_links(prefix: str = "") -> str:
    """Render Markdown list items for all required link targets."""
    return "\n".join(
        f"- [{target}]({prefix}{target})" for target in checker.REQUIRED_LINK_TARGETS
    )


def minimal_readme(link_prefix: str = "") -> str:
    """Build the smallest root README accepted by the checker."""
    commands = "\n".join(checker.REQUIRED_COMMANDS)
    links = target_links(link_prefix)
    return f"""# 6529Stream

## Current Maturity

This pre-audit local baseline is not production-ready and not a security claim.
It does not prove protocol correctness and does not replace public beta or
production release evidence. It needs reviewed fork/testnet or live deployment
rehearsal, signed release artifacts, verified addresses, explorer verification,
signer custody readiness, production signing, live metadata/indexer/marketplace
evidence, external audit, post-audit remediation, signed tag ceremony, and
accepted release-mode evidence.

## First 30 Minutes

Foundry, Solidity compiler, and Slither are named here.

```sh
{commands}
```

## Find Your Path

Auditor or security reviewer, Integrator, frontend, mobile, Electron, or indexer engineer,
Operator or deployer, Contributor, and Protocol maintainer are named here.
EIP-712 and ERC-1271 are named here.

{links}

## Drop Flow

The drop flow is summarized.

## Quickstart

The deploy-and-wire ceremony runs without production secrets.
The root README itself is part of the gate. release-impacting PRs are documented.

## Tooling

Tooling is summarized.

## Repository Layout

Repository layout is summarized.

## Important Docs

Important docs are summarized.

## Security

Do not use these contracts for production drops.
"""


class ReadmeTests(unittest.TestCase):
    def test_accepts_committed_readme(self) -> None:
        """The committed root README satisfies the checker."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])

        self.assertEqual(result, 0)

    def test_accepts_minimal_valid_readme(self) -> None:
        """A minimal complete README passes validation."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(root / checker.DEFAULT_README, minimal_readme())

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_accepts_custom_readme_path(self) -> None:
        """The CLI accepts a non-default README path."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            custom_path = Path("docs/public-front-door.md")
            write_text(root / custom_path, minimal_readme("../"))

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    ["--repo-root", str(root), "--readme", str(custom_path)]
                )

            self.assertEqual(result, 0)

    def test_rejects_missing_heading(self) -> None:
        """Missing required headings are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_readme().replace("## Find Your Path\n", "")
            write_text(root / checker.DEFAULT_README, text)

            with self.assertRaisesRegex(
                checker.ReadmeError, "missing required headings"
            ):
                checker.validate_readme(root, root / checker.DEFAULT_README)

    def test_rejects_missing_required_phrase(self) -> None:
        """Missing maturity language is rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_readme().replace("not production-ready", "ready")
            write_text(root / checker.DEFAULT_README, text)

            with self.assertRaisesRegex(
                checker.ReadmeError, "missing required content"
            ):
                checker.validate_readme(root, root / checker.DEFAULT_README)

    def test_required_phrases_tolerate_markdown_wrapping(self) -> None:
        """Required phrases may span Markdown-wrapped lines."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_readme().replace(
                "live metadata/indexer/marketplace evidence",
                "live metadata/indexer/marketplace\nevidence",
            )
            write_text(root / checker.DEFAULT_README, text)

            checker.validate_readme(root, root / checker.DEFAULT_README)

    def test_rejects_missing_required_link(self) -> None:
        """Required navigation links cannot be silently dropped."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            original = minimal_readme()
            text = original.replace("- [docs/audit-package.md](docs/audit-package.md)\n", "")
            self.assertNotEqual(text, original, "replacement had no effect")
            write_text(root / checker.DEFAULT_README, text)

            with self.assertRaisesRegex(checker.ReadmeError, "missing required links"):
                checker.validate_readme(root, root / checker.DEFAULT_README)

    def test_rejects_missing_linked_file(self) -> None:
        """Local links must resolve to existing repository files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            (root / "docs/audit-package.md").unlink()
            write_text(root / checker.DEFAULT_README, minimal_readme())

            with self.assertRaisesRegex(checker.ReadmeError, "linked targets are missing"):
                checker.validate_readme(root, root / checker.DEFAULT_README)

    def test_rejects_missing_required_command(self) -> None:
        """Validation commands must stay visible in the README."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_readme().replace("python scripts/check_readme.py\n", "")
            write_text(root / checker.DEFAULT_README, text)

            with self.assertRaisesRegex(checker.ReadmeError, "missing required commands"):
                checker.validate_readme(root, root / checker.DEFAULT_README)


if __name__ == "__main__":
    unittest.main(verbosity=2)
