#!/usr/bin/env python3
"""Focused tests for the React/Next reference documentation checker."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_react_next_reference.py")
SPEC = importlib.util.spec_from_file_location("check_react_next_reference", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def seed_required_targets(root: Path) -> None:
    """Create placeholder files for every required React/Next reference link."""
    for relative in checker.REQUIRED_LINK_TARGETS:
        write_text(root / relative, f"seed for {relative}\n")


def target_links() -> str:
    """Render Markdown list items for all required link targets."""
    return "\n".join(
        f"- [{target}](../../{target})" for target in checker.REQUIRED_LINK_TARGETS
    )


def minimal_react_next_reference() -> str:
    """Build the smallest React/Next reference doc accepted by the checker."""
    commands = "\n".join(checker.REQUIRED_COMMANDS)
    links = target_links()
    return f"""# React/Next Frontend Reference Architecture

This pre-audit local baseline is not production-ready and not a security claim.
It does not replace fork/testnet/live evidence for public beta or production.
The 6529.io, React, Next, viem, wagmi, TanStack Query, generated types,
environment separation, chain config, transaction state, and INT-007 guide
says no package dependency is introduced. INT-013 TypeScript artifact loading
and chain config snippets cover release artifact loading, address book loading,
release manifest hash validation, deployment manifest cross-checks, ABI
checksum awareness, fail-closed wrong-chain guards, and chain config
construction.

## Maturity And Scope

Local baseline, not a generated SDK, and not a dependency recommendation.

## Source Of Truth

{links}

Release manifest, ABI surface, address book, deployment manifest, ABI checksum,
event topic catalog, interface IDs, release checksums, bytecode-to-release
proof, risk register, and public-beta evidence are named.

## Non-Goals

No production package is added.

## Application Layers

Public client, wallet client, contract client layer, and chain ID are named.

## Artifact Import Flow

Artifact import flow is named.

## Environment And Network Selection

NEXT_PUBLIC_, secrets, private keys, signer service, backend signing service,
signed `DropAuthorization` fields, and `tokenData` are named.

## Contract Client Layer

Contract client layer is named.

## Query And Cache Boundaries

Query key, cache invalidation, read-after-event, confirmation depth, reorg, and
optimistic state are named.

## Transaction Orchestration

Transaction receipt and custom errors are named.

## Wallet And Signature Boundaries

WalletConnect, ERC-1271, and EIP-712 are named.

## Error, Toast, And Telemetry Policy

Toast and telemetry are named.

## Metadata, Animation, And Marketplace Rendering

MetadataUpdate, BatchMetadataUpdate, CollectionFrozen, TokenBurned, Transfer,
DependencyVersionPinned, DependencyVersionCreated, DependencyVersionDeprecated,
animation sandbox, iframe, allow-scripts, Electron, and mobile are named.

## Indexer And Event Reconciliation

Indexer reconciliation is named.

## Security And Secret Handling

Security and secret handling are named.

## Testing Strategy

Testing strategy is named.

## Pseudocode Examples

Pseudocode examples are named.

## Validation Commands

```sh
{commands}
```

## Maintenance

Refresh when integration docs change.
"""


class ReactNextReferenceTests(unittest.TestCase):
    def test_accepts_committed_doc(self) -> None:
        """The committed React/Next guide satisfies the checker."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])

        self.assertEqual(result, 0)

    def test_accepts_minimal_valid_doc(self) -> None:
        """A minimal complete React/Next doc passes validation."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(
                root / checker.DEFAULT_REACT_NEXT_REFERENCE,
                minimal_react_next_reference(),
            )

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_accepts_custom_doc_path(self) -> None:
        """The CLI accepts a non-default React/Next reference path."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            custom_path = Path("docs/custom/frontend.md")
            write_text(root / custom_path, minimal_react_next_reference())

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--react-next-reference",
                        str(custom_path),
                    ]
                )

            self.assertEqual(result, 0)

    def test_rejects_missing_heading(self) -> None:
        """Missing required headings are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_react_next_reference().replace(
                "## Transaction Orchestration\n", ""
            )
            write_text(root / checker.DEFAULT_REACT_NEXT_REFERENCE, text)

            with self.assertRaisesRegex(
                checker.ReactNextReferenceError, "missing required headings"
            ):
                checker.validate_react_next_reference(
                    root, root / checker.DEFAULT_REACT_NEXT_REFERENCE
                )

    def test_rejects_missing_required_phrase(self) -> None:
        """Missing maturity language is rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_react_next_reference().replace(
                "not production-ready", "ready"
            )
            write_text(root / checker.DEFAULT_REACT_NEXT_REFERENCE, text)

            with self.assertRaisesRegex(
                checker.ReactNextReferenceError, "missing required content"
            ):
                checker.validate_react_next_reference(
                    root, root / checker.DEFAULT_REACT_NEXT_REFERENCE
                )

    def test_required_phrases_tolerate_markdown_wrapping(self) -> None:
        """Required phrases may span Markdown-wrapped lines."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_react_next_reference().replace(
                "does not replace fork/testnet/live evidence",
                "does not replace fork/testnet/live\nevidence",
            )
            write_text(root / checker.DEFAULT_REACT_NEXT_REFERENCE, text)

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_rejects_missing_required_link(self) -> None:
        """Required source links cannot be silently dropped."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            original = minimal_react_next_reference()
            text = original.replace(
                "- [docs/integrations/metadata-rendering.md](../../docs/integrations/metadata-rendering.md)\n",
                "",
            )
            self.assertNotEqual(text, original, "replacement had no effect")
            write_text(root / checker.DEFAULT_REACT_NEXT_REFERENCE, text)

            with self.assertRaisesRegex(
                checker.ReactNextReferenceError, "missing required links"
            ):
                checker.validate_react_next_reference(
                    root, root / checker.DEFAULT_REACT_NEXT_REFERENCE
                )

    def test_rejects_missing_linked_file(self) -> None:
        """Local links must resolve to existing repository files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            (root / "docs/integrations/metadata-rendering.md").unlink()
            write_text(
                root / checker.DEFAULT_REACT_NEXT_REFERENCE,
                minimal_react_next_reference(),
            )

            with self.assertRaisesRegex(
                checker.ReactNextReferenceError, "linked targets are missing"
            ):
                checker.validate_react_next_reference(
                    root, root / checker.DEFAULT_REACT_NEXT_REFERENCE
                )

    def test_rejects_path_label_that_resolves_elsewhere(self) -> None:
        """Path-like link labels must resolve to the same repo path they name."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_react_next_reference().replace(
                (
                    "- [docs/integrations/metadata-rendering.md]"
                    "(../../docs/integrations/metadata-rendering.md)\n"
                ),
                (
                    "- [docs/integrations/metadata-rendering.md]"
                    "(../../docs/integrations/contract-flows.md)\n"
                ),
            )
            write_text(root / checker.DEFAULT_REACT_NEXT_REFERENCE, text)

            with self.assertRaisesRegex(
                checker.ReactNextReferenceError, "resolves to"
            ):
                checker.validate_react_next_reference(
                    root, root / checker.DEFAULT_REACT_NEXT_REFERENCE
                )

    def test_rejects_missing_required_command(self) -> None:
        """Validation commands must stay visible in the doc."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_react_next_reference().replace(
                "python scripts/check_react_next_reference.py\n", ""
            )
            write_text(root / checker.DEFAULT_REACT_NEXT_REFERENCE, text)

            with self.assertRaisesRegex(
                checker.ReactNextReferenceError, "missing required commands"
            ):
                checker.validate_react_next_reference(
                    root, root / checker.DEFAULT_REACT_NEXT_REFERENCE
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
