#!/usr/bin/env python3
"""Focused tests for the release-readiness checker."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_release_readiness.py")
SPEC = importlib.util.spec_from_file_location("check_release_readiness", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def seed_required_targets(root: Path) -> None:
    """Create placeholder files for every required dashboard link target."""
    for relative in checker.REQUIRED_LINK_TARGETS:
        write_text(root / relative, f"seed for {relative}\n")


def target_links() -> str:
    """Render Markdown list items for all required link targets."""
    return "\n".join(
        f"- [{target}](../{target})" for target in checker.REQUIRED_LINK_TARGETS
    )


def minimal_release_readiness_doc() -> str:
    """Build the smallest dashboard document accepted by the checker."""
    commands = "\n".join(checker.REQUIRED_COMMANDS)
    links = target_links()
    return f"""# Release Readiness

This pre-audit local baseline is not production-ready and not a security claim.
Local evidence does not replace fork/testnet/live evidence for public beta.

## Maturity And Scope

The dashboard covers public beta and production release readiness.

## Readiness Summary

Release manifest, checksum bundle, bytecode-to-release proof, live bytecode proof,
source verification inputs, ceremony evidence, randomizer operations evidence,
release-signature evidence, Slither baseline, signed release tag gate,
post-bundle release-signature evidence,
public-beta evidence status, non-local release evidence, incident response,
incident drill evidence, incident_drill_evidence, check_incident_drill_evidence.py,
signer compromise drill evidence, signer_compromise_drill_evidence,
check_signer_compromise_drill_evidence.py,
stuck auction drill evidence, stuck_auction_drill_evidence,
check_stuck_auction_drill_evidence.py,
the integration entrypoint,
the fixed-price mint and drop authorization flow spec,
the auction frontend and indexer flow spec,
the wallet, EIP-712, ERC-1271, and Safe signing guide,
the event and indexer reconstruction spec,
the metadata rendering, cache, animation sandbox, and marketplace integration guide,
ONE-005 retained marketplace/indexer evidence for OpenSea, Reservoir, Blur,
and Manifold,
the React/Next frontend reference architecture,
the maintained frontend package boundary, the generated SDK boundary,
the mobile and WalletConnect integration guide,
the maintained mobile SDK boundary, the React Native app boundary,
the WalletConnect dependency recommendation boundary,
the Electron security and wallet integration guide,
the maintained Electron app boundary, the native desktop app boundary,
the desktop SDK boundary, the code-signing implementation boundary,
the signed-update implementation boundary,
the operator admin UI specification,
the GOV-009 protocol monitoring specification,
the GOV-010 operator dashboard query model, dashboard query model, query inputs,
source artifacts, freshness, severity, and no-secret telemetry,
the maintained operator dashboard boundary, the Safe app boundary,
the multisig transaction builder boundary, the monitoring service boundary,
the production signer custody implementation boundary,
the risk register,
release evidence packet index, drop authorization signing fixtures,
release evidence issue backlog, release evidence issue links, release evidence issue body sync,
release evidence issue closure readiness, release evidence live audit report bundle,
production broadcast retention checker, production broadcast retention retained artifact,
production verified-addresses checker, production verified-addresses retained artifact,
live metadata-browser evidence, live_metadata_browser_evidence, and
check_live_metadata_browser_evidence.py
are summarized.
The release evidence live audit report schema is summarized.
The release evidence live audit Markdown parity is summarized.
The release evidence live audit report archive is summarized.
Future retained live audit reports use release-artifacts/evidence/live-audit-reports/
with YYYYMMDDTHHMMSSZ archive IDs, --generated-at labels, no secrets,
release-mode CI profile, manual workflow_dispatch,
expected to fail until retained evidence is complete, and release mode requires
public-beta readiness before production-release readiness,
snapshot_freshness, currentness_claim, profile_generated_at markers, and are
not readiness proof by themselves.
The unsigned payload-generator examples are summarized.
The drop authorization signing fixtures are summarized.
The drop authorization signing evidence and signer custody readiness evidence
are summarized.
The 1/1 provenance manifest and artist/story/authenticity local artifact model
are summarized with the collector-verifiable permanence package,
one-of-one permanence manifest, browser proof, fully on-chain versus
decentralized storage, royalty policy, ERC-2981 disclosure, royalty
disclosure, not payment enforcement, No production-readiness claim depends on
marketplaces honoring royalties, warning disposition baseline, fixed NatSpec
warning noise, accepted solc, documentation, linter, vendored, test-only,
ABI-compatibility, StreamCore size-tradeoff warning decisions, NatSpec coverage
baseline, burn-down queue, and without token finality, marketplace
readiness, royalty enforcement, or ownership proof beyond chain state.
The test matrix and ADR index evidence are summarized.

## Local Evidence Already Passing

Local evidence is listed for review.

## Public Beta Blockers

Fork/testnet/live evidence, explorer verification, verified deployed addresses,
and external audit evidence remain blockers.

## Production Release Blockers

Production signatures, signed Git tags, and post-audit remediation evidence
remain blockers.

## Required Evidence Links

{links}

## Release Commands

```sh
{commands}
```

## Maintenance

Refresh whenever release evidence or blockers change.
"""


class ReleaseReadinessTests(unittest.TestCase):
    def test_accepts_committed_doc(self) -> None:
        """The committed dashboard satisfies the checker."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])

        self.assertEqual(result, 0)

    def test_accepts_minimal_valid_doc(self) -> None:
        """A minimal complete dashboard passes validation."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(
                root / checker.DEFAULT_RELEASE_READINESS,
                minimal_release_readiness_doc(),
            )

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_accepts_custom_release_readiness_path(self) -> None:
        """The CLI accepts a non-default dashboard path."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            custom_path = Path("custom/release-dashboard.md")
            write_text(root / custom_path, minimal_release_readiness_doc())

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--release-readiness",
                        str(custom_path),
                    ]
                )

            self.assertEqual(result, 0)

    def test_rejects_missing_document(self) -> None:
        """A missing dashboard reports the missing-document error."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)

            with self.assertRaisesRegex(
                checker.ReleaseReadinessError, "missing document"
            ):
                checker.validate_release_readiness(
                    root, root / checker.DEFAULT_RELEASE_READINESS
                )

    def test_rejects_missing_heading(self) -> None:
        """Missing required headings are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_release_readiness_doc().replace(
                "## Public Beta Blockers\n", ""
            )
            write_text(root / checker.DEFAULT_RELEASE_READINESS, text)

            with self.assertRaisesRegex(
                checker.ReleaseReadinessError, "missing required headings"
            ):
                checker.validate_release_readiness(
                    root, root / checker.DEFAULT_RELEASE_READINESS
                )

    def test_rejects_missing_maturity_language(self) -> None:
        """Missing maturity warnings are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_release_readiness_doc().replace(
                "not production-ready", "ready"
            )
            write_text(root / checker.DEFAULT_RELEASE_READINESS, text)

            with self.assertRaisesRegex(
                checker.ReleaseReadinessError, "missing required maturity language"
            ):
                checker.validate_release_readiness(
                    root, root / checker.DEFAULT_RELEASE_READINESS
                )

    def test_rejects_missing_readiness_phrase(self) -> None:
        """Missing readiness-blocker phrases are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_release_readiness_doc()
            text = text.replace("production signatures", "signature files")
            text = text.replace("Production signatures", "Signature files")
            write_text(root / checker.DEFAULT_RELEASE_READINESS, text)

            with self.assertRaisesRegex(
                checker.ReleaseReadinessError, "missing required content"
            ):
                checker.validate_release_readiness(
                    root, root / checker.DEFAULT_RELEASE_READINESS
                )

    def test_required_phrases_tolerate_markdown_wrapping(self) -> None:
        """Required phrases may span Markdown-wrapped lines."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_release_readiness_doc().replace(
                "metadata rendering, cache, animation sandbox, and marketplace integration guide",
                "metadata rendering, cache, animation sandbox, and marketplace\nintegration guide",
            )
            write_text(root / checker.DEFAULT_RELEASE_READINESS, text)

            checker.validate_release_readiness(
                root, root / checker.DEFAULT_RELEASE_READINESS
            )

    def test_rejects_missing_command(self) -> None:
        """Missing required commands are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_release_readiness_doc().replace(
                "python scripts/check_release_readiness.py\n", ""
            )
            write_text(root / checker.DEFAULT_RELEASE_READINESS, text)

            with self.assertRaisesRegex(
                checker.ReleaseReadinessError, "missing required commands"
            ):
                checker.validate_release_readiness(
                    root, root / checker.DEFAULT_RELEASE_READINESS
                )

    def test_rejects_missing_required_link(self) -> None:
        """Missing required evidence links are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_release_readiness_doc().replace(
                "- [README.md](../README.md)\n", ""
            )
            write_text(root / checker.DEFAULT_RELEASE_READINESS, text)

            with self.assertRaisesRegex(
                checker.ReleaseReadinessError, "missing required links"
            ):
                checker.validate_release_readiness(
                    root, root / checker.DEFAULT_RELEASE_READINESS
                )

    def test_rejects_missing_linked_file(self) -> None:
        """Links to missing required files are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            (root / "SECURITY.md").unlink()
            write_text(
                root / checker.DEFAULT_RELEASE_READINESS,
                minimal_release_readiness_doc(),
            )

            with self.assertRaisesRegex(
                checker.ReleaseReadinessError, "linked targets are missing"
            ):
                checker.validate_release_readiness(
                    root, root / checker.DEFAULT_RELEASE_READINESS
                )

    def test_rejects_escaped_link_target(self) -> None:
        """Links that escape the repository root are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_release_readiness_doc() + "\n[escape](../../outside.md)\n"
            write_text(root / checker.DEFAULT_RELEASE_READINESS, text)

            with self.assertRaisesRegex(
                checker.ReleaseReadinessError, "linked path escapes repository"
            ):
                checker.validate_release_readiness(
                    root, root / checker.DEFAULT_RELEASE_READINESS
                )


if __name__ == "__main__":
    unittest.main()
