#!/usr/bin/env python3
"""Focused tests for the metadata rendering documentation checker."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_metadata_rendering.py")
SPEC = importlib.util.spec_from_file_location("check_metadata_rendering", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def seed_required_targets(root: Path) -> None:
    """Create placeholder files for every required metadata rendering link target."""
    for relative in checker.REQUIRED_LINK_TARGETS:
        write_text(root / relative, f"seed for {relative}\n")


def target_links() -> str:
    """Render Markdown list items for all required link targets."""
    return "\n".join(
        f"- [{target}](../../{target})" for target in checker.REQUIRED_LINK_TARGETS
    )


def minimal_metadata_rendering_doc() -> str:
    """Build the smallest metadata rendering doc accepted by the checker."""
    commands = "\n".join(checker.REQUIRED_COMMANDS)
    links = target_links()
    return f"""# Metadata Rendering

This pre-audit local baseline is not production-ready and not a security claim.
It does not replace fork/testnet/live evidence for public beta or production.
Marketplace metadata rendering, cache, animation sandbox, INT-006, OpenSea,
Reservoir, Blur, Manifold, risk register, release manifest, release checksums,
public-beta evidence, and metadata browser evidence are named.
The 1/1 provenance manifest, one-of-one-provenance-manifest.json,
one-of-one provenance, artist statement, authenticity status, certificate,
curation history, additional `tokenURI` JSON, and new `StreamCore` storage are
named.

## Maturity And Scope

Electron, mobile, and private keys are named.

## Source Of Truth

{links}

## Metadata State Model

`not_minted`, `pending`, `stale`, `failed`, `retry_failed`, `final`, `frozen`,
`burned`, `dependency_pinned`, `dependency_deprecated`, and `cache_stale` are named.

## TokenURI Behavior

tokenURI, metadata_schema_version, metadata_state,
data:application/json;base64, and animation_url are named. StreamContractMetadata,
IERC7572, IStreamContractMetadata, ERC-7572-style, contractURI(),
contractURIHash(), ContractURIUpdated, satellite/read-adapter, and
METADATA_MUTATION are named.

## 1/1 Provenance Manifests

The provenance display boundary is named.

## JSON And Fixture Expectations

Strict UTF-8 and attributes are named.

## ERC-4906 Cache Invalidation

MetadataUpdate, BatchMetadataUpdate, CollectionFrozen, DependencyVersionPinned,
DependencyVersionCreated, DependencyVersionDeprecated, TokenBurned,
ERC-721 transfer-to-zero, supportsInterface(0x49064906), no mint-only ERC-4906,
and no burn ERC-4906 are named.

## Randomness And Retry States

Randomness and retry states are named.

## Freeze, Burn, And Dependency States

Freeze, burn, and dependency states are named.

## Animation Sandbox

allow-scripts, unexpected outbound HTTP(S) requests, and parent document are named.

## Cache Strategy

Cache strategy is named.

## Marketplace And Evidence Boundaries

Marketplace and evidence boundaries are named.

## Validation Commands

```sh
{commands}
```

## Maintenance

Refresh when metadata behavior changes.
"""


class MetadataRenderingTests(unittest.TestCase):
    def test_accepts_committed_doc(self) -> None:
        """The committed metadata rendering guide satisfies the checker."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])

        self.assertEqual(result, 0)

    def test_accepts_minimal_valid_doc(self) -> None:
        """A minimal complete metadata rendering doc passes validation."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(
                root / checker.DEFAULT_METADATA_RENDERING,
                minimal_metadata_rendering_doc(),
            )

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_accepts_custom_doc_path(self) -> None:
        """The CLI accepts a non-default metadata rendering doc path."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            custom_path = Path("docs/custom-metadata/rendering.md")
            write_text(root / custom_path, minimal_metadata_rendering_doc())

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--metadata-rendering",
                        str(custom_path),
                    ]
                )

            self.assertEqual(result, 0)

    def test_rejects_missing_heading(self) -> None:
        """Missing required headings are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_metadata_rendering_doc().replace(
                "## Cache Strategy\n", ""
            )
            write_text(root / checker.DEFAULT_METADATA_RENDERING, text)

            with self.assertRaisesRegex(
                checker.MetadataRenderingError, "missing required headings"
            ):
                checker.validate_metadata_rendering(
                    root, root / checker.DEFAULT_METADATA_RENDERING
                )

    def test_rejects_missing_required_phrase(self) -> None:
        """Missing maturity language is rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_metadata_rendering_doc().replace(
                "not production-ready", "ready"
            )
            write_text(root / checker.DEFAULT_METADATA_RENDERING, text)

            with self.assertRaisesRegex(
                checker.MetadataRenderingError, "missing required content"
            ):
                checker.validate_metadata_rendering(
                    root, root / checker.DEFAULT_METADATA_RENDERING
                )

    def test_required_phrases_tolerate_markdown_wrapping(self) -> None:
        """Required phrases may span Markdown-wrapped lines."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_metadata_rendering_doc().replace(
                "does not replace fork/testnet/live evidence",
                "does not replace fork/testnet/live\nevidence",
            )
            write_text(root / checker.DEFAULT_METADATA_RENDERING, text)

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_rejects_missing_required_link(self) -> None:
        """Required source links cannot be silently dropped."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            original = minimal_metadata_rendering_doc()
            text = original.replace(
                "- [docs/metadata.md](../../docs/metadata.md)\n",
                "",
            )
            self.assertNotEqual(text, original, "replacement had no effect")
            write_text(root / checker.DEFAULT_METADATA_RENDERING, text)

            with self.assertRaisesRegex(
                checker.MetadataRenderingError, "missing required links"
            ):
                checker.validate_metadata_rendering(
                    root, root / checker.DEFAULT_METADATA_RENDERING
                )

    def test_rejects_missing_linked_file(self) -> None:
        """Local links must resolve to existing repository files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            (root / "docs/metadata.md").unlink()
            write_text(
                root / checker.DEFAULT_METADATA_RENDERING,
                minimal_metadata_rendering_doc(),
            )

            with self.assertRaisesRegex(
                checker.MetadataRenderingError, "linked targets are missing"
            ):
                checker.validate_metadata_rendering(
                    root, root / checker.DEFAULT_METADATA_RENDERING
                )

    def test_rejects_path_label_that_resolves_elsewhere(self) -> None:
        """Path-like link labels must resolve to the same repo path they name."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_metadata_rendering_doc().replace(
                "- [docs/metadata.md](../../docs/metadata.md)\n",
                "- [docs/metadata.md](../../docs/release-policy.md)\n",
            )
            write_text(root / checker.DEFAULT_METADATA_RENDERING, text)

            with self.assertRaisesRegex(
                checker.MetadataRenderingError, "resolves to"
            ):
                checker.validate_metadata_rendering(
                    root, root / checker.DEFAULT_METADATA_RENDERING
                )

    def test_rejects_missing_required_command(self) -> None:
        """Validation commands must stay visible in the doc."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_metadata_rendering_doc().replace(
                "python scripts/check_metadata_rendering.py\n", ""
            )
            write_text(root / checker.DEFAULT_METADATA_RENDERING, text)

            with self.assertRaisesRegex(
                checker.MetadataRenderingError, "missing required commands"
            ):
                checker.validate_metadata_rendering(
                    root, root / checker.DEFAULT_METADATA_RENDERING
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
