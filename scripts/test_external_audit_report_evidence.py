#!/usr/bin/env python3
"""Focused tests for external audit report retained evidence."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_external_audit_report_evidence.py")
SPEC = importlib.util.spec_from_file_location(
    "check_external_audit_report_evidence", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def valid_template() -> str:
    """Return a valid external audit retained-artifact template."""
    return """# External Audit Report Retained Artifact

> Template only. This file is not completion evidence.

## Evidence Status

- Requirement ID: `external_audit_report`
- Review status: `template`
- Readiness claim: `blocked`
- Environment: `audit`
- Chain ID: `not_applicable`

## Audit Scope And Report Reference

- Repository: `https://github.com/6529-Collections/6529Stream`
- Audited commit: `TBD`
- Audit firm: `TBD`
- Audit report reference: `TBD`
- Audit report date: `TBD`
- Scope summary: `TBD`
- Out-of-scope summary: `TBD`

## Findings And Remediation

- Finding IDs: `TBD`
- Critical/high findings: `TBD`
- Medium findings: `TBD`
- Low/informational findings: `TBD`
- Remediation links: `TBD`
- Accepted-risk references: `TBD`
- Retest status: `TBD`

## Required Retained Artifacts

- Final audit report or public report reference: `TBD`
- Audit scope statement: `TBD`
- Finding remediation tracker: `TBD`
- Retest or verification evidence: `TBD`
- Release manifest/checksum digests: `TBD`

## Review

- Operator: `TBD`
- Reviewer: `TBD`
- Review decision: `template`

## Redaction

- No secrets retained: `TBD`
- Private auditor portal credentials removed: `TBD`
- Private RPC URLs removed: `TBD`
- Private keys removed: `TBD`
- Unreleased drop payloads removed: `TBD`

## Validation Commands

```sh
python scripts/test_external_audit_report_evidence.py
python scripts/check_external_audit_report_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/public-beta-templates/external-audit-report-template.json --retained-artifact release-artifacts/evidence/external-audit-report/external-audit-report-retained-artifact-template.md --output release-artifacts/evidence/external-audit-report/external-audit-report-evidence.json --environment audit --chain-id not_applicable --block-or-reference "<final audit report ID or public URL>" --command-or-source-system "<auditor report source>" --owner "<operator>" --reviewer "<reviewer>" --source-git-commit "<audited commit>" --source-ci-run "<release CI run>"
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Replace every `TBD` field before requesting review.
- Keep #215 open until reviewed retained evidence is linked from the shared
  public-beta evidence manifest.
"""


def reviewed_artifact() -> str:
    """Return a valid reviewed retained artifact."""
    return """# External Audit Report Retained Artifact

## Evidence Status

- Requirement ID: `external_audit_report`
- Review status: `reviewed`
- Readiness claim: `blocked`
- Environment: `audit`
- Chain ID: `not_applicable`

## Audit Scope And Report Reference

- Repository: `https://github.com/6529-Collections/6529Stream`
- Audited commit: `1234567890abcdef1234567890abcdef12345678`
- Audit firm: `Example Audit LLC`
- Audit report reference: `https://example.invalid/6529stream-audit-final.pdf`
- Audit report date: `2026-06-14`
- Scope summary: `smart-contracts/src and release artifacts at commit 1234567890abcdef1234567890abcdef12345678`
- Out-of-scope summary: `production private keys, unreleased drop payloads, and live infrastructure credentials`

## Findings And Remediation

- Finding IDs: `EXT-001, EXT-002`
- Critical/high findings: `0 open; EXT-001 remediated in issue #400`
- Medium findings: `1 accepted risk; EXT-002 tracked in issue #401`
- Low/informational findings: `2 acknowledged in issues #402 and #403`
- Remediation links: `https://github.com/6529-Collections/6529Stream/issues/400`
- Accepted-risk references: `docs/security/accepted-risks/example.md`
- Retest status: `retest passed for EXT-001; accepted-risk signoff retained for EXT-002`

## Required Retained Artifacts

- Final audit report or public report reference: `https://example.invalid/6529stream-audit-final.pdf`
- Audit scope statement: `docs/audit-package.md`
- Finding remediation tracker: `release-artifacts/evidence/external-audit-report/remediation-tracker.md`
- Retest or verification evidence: `release-artifacts/evidence/external-audit-report/retest.md`
- Release manifest/checksum digests: `release-artifacts/latest/release-manifest.json and SHA256SUMS`

## Review

- Operator: `release-operator`
- Reviewer: `security-reviewer`
- Review decision: `reviewed`

## Redaction

- No secrets retained: `yes`
- Private auditor portal credentials removed: `yes`
- Private RPC URLs removed: `yes`
- Private keys removed: `yes`
- Unreleased drop payloads removed: `yes`

## Validation Commands

```sh
python scripts/test_external_audit_report_evidence.py
python scripts/check_external_audit_report_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/public-beta-templates/external-audit-report-template.json --retained-artifact release-artifacts/evidence/external-audit-report/external-audit-report-retained-artifact-template.md --output release-artifacts/evidence/external-audit-report/external-audit-report-evidence.json --environment audit --chain-id not_applicable --block-or-reference "https://example.invalid/6529stream-audit-final.pdf" --command-or-source-system "auditor final report" --owner release-operator --reviewer security-reviewer --source-git-commit 1234567890abcdef1234567890abcdef12345678 --source-ci-run ci-run-123
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Reviewed retained evidence remains blocked until linked from the shared
  public-beta evidence manifest.
"""


class ExternalAuditReportEvidenceTests(unittest.TestCase):
    """Checker behavior for external audit report evidence."""

    def test_committed_template_passes(self) -> None:
        """The committed template satisfies the checker."""
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main([])

        self.assertEqual(result, 0)

    def test_reviewed_artifact_passes(self) -> None:
        """A filled reviewed artifact can pass before manifest linkage."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "reviewed.md"
            write_text(path, reviewed_artifact())

            checker.validate_artifact(path)

    def test_missing_heading_fails(self) -> None:
        """Required sections cannot silently disappear."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "missing-heading.md"
            write_text(path, valid_template().replace("## Findings And Remediation\n\n", ""))

            with self.assertRaisesRegex(
                checker.ExternalAuditReportEvidenceError,
                "Findings And Remediation",
            ):
                checker.validate_artifact(path)

    def test_wrong_requirement_fails(self) -> None:
        """The artifact must map only to the external audit row."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "wrong-requirement.md"
            write_text(
                path,
                valid_template().replace(
                    "`external_audit_report`", "`post_audit_remediation`"
                ),
            )

            with self.assertRaisesRegex(
                checker.ExternalAuditReportEvidenceError,
                "external_audit_report",
            ):
                checker.validate_artifact(path)

    def test_reviewed_placeholders_fail(self) -> None:
        """Reviewed artifacts cannot retain template placeholders."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "reviewed-placeholder.md"
            write_text(
                path,
                reviewed_artifact().replace("`Example Audit LLC`", "`TBD`"),
            )

            with self.assertRaisesRegex(
                checker.ExternalAuditReportEvidenceError,
                "Audit firm",
            ):
                checker.validate_artifact(path)

    def test_missing_validation_command_fails(self) -> None:
        """The template must carry the full validation sequence."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "missing-command.md"
            write_text(
                path,
                valid_template().replace(
                    "python scripts/check_public_beta_evidence.py\n", ""
                ),
            )

            with self.assertRaisesRegex(
                checker.ExternalAuditReportEvidenceError,
                "check_public_beta_evidence",
            ):
                checker.validate_artifact(path)

    def test_secret_like_values_fail(self) -> None:
        """Secret-shaped key/value text is rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "secret.md"
            write_text(path, valid_template() + "\napi_key=do-not-commit\n")

            with self.assertRaisesRegex(
                checker.ExternalAuditReportEvidenceError,
                "secret-like",
            ):
                checker.validate_artifact(path)


if __name__ == "__main__":
    unittest.main()
