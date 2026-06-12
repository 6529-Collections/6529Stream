#!/usr/bin/env python3
"""Focused tests for the incident-response checker."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_incident_response.py")
SPEC = importlib.util.spec_from_file_location("check_incident_response", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def seed_required_targets(root: Path) -> None:
    """Create placeholder files for every required runbook link target."""
    for relative in checker.REQUIRED_LINK_TARGETS:
        write_text(root / relative, f"seed for {relative}\n")


def target_links(prefix: str = "../") -> str:
    """Render Markdown list items for all required link targets."""
    return "\n".join(
        f"- [{target}]({prefix}{target})" for target in checker.REQUIRED_LINK_TARGETS
    )


def minimal_incident_response_doc(link_prefix: str = "../") -> str:
    """Build the smallest incident-response runbook accepted by the checker."""
    commands = "\n".join(checker.REQUIRED_COMMANDS)
    links = target_links(link_prefix)
    return f"""# Protocol Incident Response

This pre-audit runbook is not production-ready, not a security claim, and uses
no-secret evidence retention plus private reporting.

## Maturity And Scope

It covers stuck auctions, failed randomness, stale randomness, bad Merkle roots,
bad metadata, dependency configuration, signer compromise, and release artifact
or evidence mistakes.

## Roles And Severity

Incident lead, protocol maintainer, operations maintainer, communications owner,
and reviewer roles are assigned.

## Universal Triage

Universal triage considers emergency pause, withdrawal availability, signer revocation,
retry/recovery, evidence retention, and post-incident review.

## Evidence Retention And Communications

Public-safe artifacts are retained without secrets.

## Runbook: Stuck Auctions Or Settlement

Auction custody, settlement, credits, and withdrawals are checked.

## Runbook: Failed Or Stale Randomness

Randomizer request, callback, provider epoch, stale, failed, and retry states
are checked.

## Runbook: Bad Merkle Roots Or Curator Claims

Merkle root, root epoch, leaf encoding, and double claims are checked.

## Runbook: Bad Metadata Or Dependency Configuration

Metadata, dependency source, freeze, and repinning mistakes are checked.

## Runbook: Signer Compromise Or Drop Authorization

Signer epoch, payload, domain, cancellation, and rotation mistakes are checked.

## Runbook: Release Artifact Or Evidence Mistake

Manifest, checksum, address-book, evidence, and release notes mistakes are
checked.

## Reopening And Post-Incident Review

Reopening requires a reviewed recovery decision.

## Local Verification Commands

```sh
{commands}
```

## Maintenance

{links}
"""


class IncidentResponseTests(unittest.TestCase):
    def test_accepts_committed_doc(self) -> None:
        """The committed incident-response runbook satisfies the checker."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])

        self.assertEqual(result, 0)

    def test_accepts_minimal_valid_doc(self) -> None:
        """A minimal complete incident-response runbook passes validation."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(
                root / checker.DEFAULT_INCIDENT_RESPONSE,
                minimal_incident_response_doc(),
            )

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_accepts_custom_incident_response_path(self) -> None:
        """The CLI accepts a non-default runbook path."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            custom_path = Path("incident-response.md")
            write_text(root / custom_path, minimal_incident_response_doc(""))

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--incident-response",
                        str(custom_path),
                    ]
                )

            self.assertEqual(result, 0)

    def test_rejects_missing_heading(self) -> None:
        """Missing required headings are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_incident_response_doc().replace(
                "## Runbook: Failed Or Stale Randomness\n", ""
            )
            write_text(root / checker.DEFAULT_INCIDENT_RESPONSE, text)

            with self.assertRaisesRegex(
                checker.IncidentResponseError, "missing required headings"
            ):
                checker.validate_incident_response(
                    root, root / checker.DEFAULT_INCIDENT_RESPONSE
                )

    def test_rejects_missing_maturity_language(self) -> None:
        """Missing maturity warnings are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_incident_response_doc().replace(
                "not production-ready", "ready"
            )
            write_text(root / checker.DEFAULT_INCIDENT_RESPONSE, text)

            with self.assertRaisesRegex(
                checker.IncidentResponseError, "missing required maturity language"
            ):
                checker.validate_incident_response(
                    root, root / checker.DEFAULT_INCIDENT_RESPONSE
                )

    def test_rejects_missing_incident_phrase(self) -> None:
        """Missing required incident themes are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_incident_response_doc().replace(
                "retry/recovery", "retry path"
            )
            write_text(root / checker.DEFAULT_INCIDENT_RESPONSE, text)

            with self.assertRaisesRegex(
                checker.IncidentResponseError, "missing required incident content"
            ):
                checker.validate_incident_response(
                    root, root / checker.DEFAULT_INCIDENT_RESPONSE
                )

    def test_rejects_missing_command(self) -> None:
        """Missing required commands are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_incident_response_doc().replace(
                "python scripts/check_incident_response.py\n", ""
            )
            write_text(root / checker.DEFAULT_INCIDENT_RESPONSE, text)

            with self.assertRaisesRegex(
                checker.IncidentResponseError, "missing required commands"
            ):
                checker.validate_incident_response(
                    root, root / checker.DEFAULT_INCIDENT_RESPONSE
                )

    def test_rejects_missing_required_link(self) -> None:
        """Missing required links are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_incident_response_doc().replace(
                "- [SECURITY.md](../SECURITY.md)\n", ""
            )
            write_text(root / checker.DEFAULT_INCIDENT_RESPONSE, text)

            with self.assertRaisesRegex(
                checker.IncidentResponseError, "missing required links"
            ):
                checker.validate_incident_response(
                    root, root / checker.DEFAULT_INCIDENT_RESPONSE
                )

    def test_rejects_missing_linked_file(self) -> None:
        """Links to missing files are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            (root / "SECURITY.md").unlink()
            write_text(
                root / checker.DEFAULT_INCIDENT_RESPONSE,
                minimal_incident_response_doc(),
            )

            with self.assertRaisesRegex(
                checker.IncidentResponseError, "linked targets are missing"
            ):
                checker.validate_incident_response(
                    root, root / checker.DEFAULT_INCIDENT_RESPONSE
                )

    def test_rejects_link_escape(self) -> None:
        """Links that escape the repository are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_incident_response_doc()
            text += "\n- [escape](../../outside.md)\n"
            write_text(root / checker.DEFAULT_INCIDENT_RESPONSE, text)

            with self.assertRaisesRegex(
                checker.IncidentResponseError, "linked path escapes repository"
            ):
                checker.validate_incident_response(
                    root, root / checker.DEFAULT_INCIDENT_RESPONSE
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
