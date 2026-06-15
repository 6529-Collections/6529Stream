#!/usr/bin/env python3
"""Focused tests for the integrations README checker."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_integrations_readme.py")
SPEC = importlib.util.spec_from_file_location("check_integrations_readme", SCRIPT_PATH)
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


def target_links() -> str:
    """Render Markdown list items for all required link targets."""
    return "\n".join(
        f"- [{target}](../../{target})" for target in checker.REQUIRED_LINK_TARGETS
    )


def minimal_integrations_readme() -> str:
    """Build the smallest integrations README accepted by the checker."""
    commands = "\n".join(checker.REQUIRED_COMMANDS)
    links = target_links()
    return f"""# Integrations

This pre-audit local baseline is not production-ready and not a security claim.
It does not replace fork/testnet/live evidence for public beta or production.

## Maturity And Scope

The local baseline helps React, mobile, Electron, indexer, operator UI, and
backend signing service teams locate integration inputs.

## Consumer Surfaces

React, mobile, Electron, indexer, operator UI, and backend signing service
consumers are named here.

## Source Of Truth

ABIs, address books, deployment manifests, release manifest, source verification inputs,
ABI compatibility baseline, event topic catalog, interface IDs, metadata,
EIP-712, ERC-1271, risk register, and public-beta evidence status are named.

## Canonical Artifacts

{links}

## Integration Flows

Future work: INT-002, INT-003, INT-004, INT-005, INT-006, INT-007, INT-008, and INT-009.
The fixed-price mint flow is listed.
The auction frontend and indexer flow spec is listed.
The wallet, EIP-712, ERC-1271, and Safe signing guide is listed.
The event and indexer reconstruction spec is listed.
The metadata rendering, cache, animation sandbox, and marketplace integration guide is listed.
The React/Next frontend reference architecture is listed.
The mobile and WalletConnect integration guide is listed.
The maintained frontend package, generated SDK, maintained mobile SDK,
React Native app, and WalletConnect dependency recommendation boundaries are listed.

## Readiness Boundaries

Public beta and production remain blocked until reviewed evidence exists.

## Validation Commands

```sh
{commands}
```

## Maintenance

Refresh when integration docs or release artifacts move.
"""


class IntegrationsReadmeTests(unittest.TestCase):
    def test_accepts_committed_readme(self) -> None:
        """The committed integrations README satisfies the checker."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])

        self.assertEqual(result, 0)

    def test_accepts_minimal_valid_readme(self) -> None:
        """A minimal complete integrations README passes validation."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(
                root / checker.DEFAULT_INTEGRATIONS_README,
                minimal_integrations_readme(),
            )

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_accepts_custom_readme_path(self) -> None:
        """The CLI accepts a non-default integrations README path."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            custom_path = Path("docs/custom-integrations/README.md")
            write_text(root / custom_path, minimal_integrations_readme())

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
            text = minimal_integrations_readme().replace("## Source Of Truth\n", "")
            write_text(root / checker.DEFAULT_INTEGRATIONS_README, text)

            with self.assertRaisesRegex(
                checker.IntegrationsReadmeError, "missing required headings"
            ):
                checker.validate_integrations_readme(
                    root, root / checker.DEFAULT_INTEGRATIONS_README
                )

    def test_rejects_missing_required_phrase(self) -> None:
        """Missing readiness and artifact language is rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_integrations_readme().replace("not production-ready", "ready")
            write_text(root / checker.DEFAULT_INTEGRATIONS_README, text)

            with self.assertRaisesRegex(
                checker.IntegrationsReadmeError, "missing required content"
            ):
                checker.validate_integrations_readme(
                    root, root / checker.DEFAULT_INTEGRATIONS_README
                )

    def test_required_phrases_tolerate_markdown_wrapping(self) -> None:
        """Required phrases may span Markdown-wrapped lines."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_integrations_readme().replace(
                "metadata rendering, cache, animation sandbox, and marketplace integration guide",
                "metadata rendering, cache, animation sandbox, and marketplace\nintegration guide",
            )
            write_text(root / checker.DEFAULT_INTEGRATIONS_README, text)

            checker.validate_integrations_readme(
                root, root / checker.DEFAULT_INTEGRATIONS_README
            )

    def test_rejects_missing_required_link(self) -> None:
        """Required artifact links cannot be silently dropped."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            original = minimal_integrations_readme()
            text = original.replace(
                "- [release-artifacts/latest/release-manifest.json](../../release-artifacts/latest/release-manifest.json)\n",
                "",
            )
            self.assertNotEqual(text, original, "replacement had no effect")
            write_text(root / checker.DEFAULT_INTEGRATIONS_README, text)

            with self.assertRaisesRegex(
                checker.IntegrationsReadmeError, "missing required links"
            ):
                checker.validate_integrations_readme(
                    root, root / checker.DEFAULT_INTEGRATIONS_README
                )

    def test_rejects_missing_linked_file(self) -> None:
        """Local links must resolve to existing repository files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            (root / "release-artifacts/latest/release-manifest.json").unlink()
            write_text(
                root / checker.DEFAULT_INTEGRATIONS_README,
                minimal_integrations_readme(),
            )

            with self.assertRaisesRegex(
                checker.IntegrationsReadmeError, "linked targets are missing"
            ):
                checker.validate_integrations_readme(
                    root, root / checker.DEFAULT_INTEGRATIONS_README
                )

    def test_rejects_missing_required_command(self) -> None:
        """Validation commands must stay visible in the README."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_integrations_readme().replace(
                "python scripts/check_integrations_readme.py\n", ""
            )
            write_text(root / checker.DEFAULT_INTEGRATIONS_README, text)

            with self.assertRaisesRegex(
                checker.IntegrationsReadmeError, "missing required commands"
            ):
                checker.validate_integrations_readme(
                    root, root / checker.DEFAULT_INTEGRATIONS_README
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
