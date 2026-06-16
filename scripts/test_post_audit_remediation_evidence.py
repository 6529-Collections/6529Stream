#!/usr/bin/env python3
"""Focused tests for post-audit remediation retained evidence."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_post_audit_remediation_evidence.py")
SPEC = importlib.util.spec_from_file_location(
    "check_post_audit_remediation_evidence", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def valid_template() -> str:
    """Return a valid post-audit remediation retained-artifact template."""
    return """# Post-Audit Remediation Retained Artifact

> Template only. This file is not completion evidence.

## Evidence Status

- Requirement ID: `post_audit_remediation`
- Review status: `template`
- Readiness claim: `blocked`
- Environment: `audit`
- Chain ID: `not_applicable`

## Audit And Release Scope

- Repository: `https://github.com/6529-Collections/6529Stream`
- Release commit: `TBD`
- Audit report reference: `TBD`
- Audit finding tracker: `TBD`
- Release version: `TBD`

## Finding Remediation Matrix

- Finding IDs covered: `TBD`
- Critical/high remediation status: `TBD`
- Medium remediation status: `TBD`
- Low/informational disposition: `TBD`
- Fix PRs or commits: `TBD`
- Regression tests added: `TBD`

## Retest And Risk Acceptance

- Retest evidence: `TBD`
- Accepted-risk records: `TBD`
- Release notes mapping: `TBD`
- Open finding exceptions: `TBD`

## Required Retained Artifacts

- Finding-by-finding remediation tracker: `TBD`
- Retest transcript or reviewer report: `TBD`
- Accepted-risk signoff packet: `TBD`
- Updated release notes: `TBD`
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
python scripts/test_post_audit_remediation_evidence.py
python scripts/check_post_audit_remediation_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/production-release-templates/post-audit-remediation-template.json --retained-artifact release-artifacts/evidence/post-audit-remediation/post-audit-remediation-retained-artifact-template.md --output release-artifacts/evidence/post-audit-remediation/post-audit-remediation-evidence.json --environment audit --chain-id not_applicable --block-or-reference "<audit report, remediation tracker, or retest reference>" --command-or-source-system "<auditor retest source or remediation review command>" --owner "<operator>" --reviewer "<reviewer>" --source-git-commit "<release commit>" --source-ci-run "<release CI run>"
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Replace every `TBD` field before requesting review.
- Keep issue #231 open until reviewed retained evidence is linked from the
  shared production-release evidence manifest.
"""


def reviewed_artifact() -> str:
    """Return a valid reviewed retained artifact."""
    return """# Post-Audit Remediation Retained Artifact

## Evidence Status

- Requirement ID: `post_audit_remediation`
- Review status: `reviewed`
- Readiness claim: `blocked`
- Environment: `audit`
- Chain ID: `not_applicable`

## Audit And Release Scope

- Repository: `https://github.com/6529-Collections/6529Stream`
- Release commit: `1234567890abcdef1234567890abcdef12345678`
- Audit report reference: `https://example.invalid/6529stream-audit-final.pdf`
- Audit finding tracker: `release-artifacts/evidence/post-audit-remediation/remediation-tracker.md`
- Release version: `v0.1.0`

## Finding Remediation Matrix

- Finding IDs covered: `AUD-001, AUD-002, AUD-003`
- Critical/high remediation status: `0 open; AUD-001 fixed in PR #400 and retested`
- Medium remediation status: `AUD-002 accepted risk in docs/security/accepted-risks/aud-002.md`
- Low/informational disposition: `AUD-003 acknowledged in release notes`
- Fix PRs or commits: `https://github.com/6529-Collections/6529Stream/pull/400`
- Regression tests added: `test/AuditRegression.t.sol::testAudit001`

## Retest And Risk Acceptance

- Retest evidence: `release-artifacts/evidence/post-audit-remediation/retest.md`
- Accepted-risk records: `docs/security/accepted-risks/aud-002.md`
- Release notes mapping: `release-artifacts/latest/release-notes.md`
- Open finding exceptions: `none`

## Required Retained Artifacts

- Finding-by-finding remediation tracker: `release-artifacts/evidence/post-audit-remediation/remediation-tracker.md`
- Retest transcript or reviewer report: `release-artifacts/evidence/post-audit-remediation/retest.md`
- Accepted-risk signoff packet: `docs/security/accepted-risks/aud-002.md`
- Updated release notes: `release-artifacts/latest/release-notes.md`
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
python scripts/test_post_audit_remediation_evidence.py
python scripts/check_post_audit_remediation_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/production-release-templates/post-audit-remediation-template.json --retained-artifact release-artifacts/evidence/post-audit-remediation/post-audit-remediation-retained-artifact-template.md --output release-artifacts/evidence/post-audit-remediation/post-audit-remediation-evidence.json --environment audit --chain-id not_applicable --block-or-reference "https://example.invalid/6529stream-audit-final.pdf" --command-or-source-system "auditor retest report" --owner release-operator --reviewer security-reviewer --source-git-commit 1234567890abcdef1234567890abcdef12345678 --source-ci-run ci-run-123
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Reviewed retained evidence remains blocked until linked from the shared
  production-release evidence manifest.
"""


class PostAuditRemediationEvidenceTests(unittest.TestCase):
    """Checker behavior for post-audit remediation evidence."""

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
            write_text(path, valid_template().replace("## Retest And Risk Acceptance\n\n", ""))

            with self.assertRaisesRegex(
                checker.PostAuditRemediationEvidenceError,
                "Retest And Risk Acceptance",
            ):
                checker.validate_artifact(path)

    def test_wrong_requirement_fails(self) -> None:
        """The artifact must map only to the post-audit remediation row."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "wrong-requirement.md"
            write_text(
                path,
                valid_template().replace(
                    "`post_audit_remediation`", "`external_audit_report`"
                ),
            )

            with self.assertRaisesRegex(
                checker.PostAuditRemediationEvidenceError,
                "post_audit_remediation",
            ):
                checker.validate_artifact(path)

    def test_reviewed_placeholders_fail(self) -> None:
        """Reviewed artifacts cannot retain template placeholders."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "reviewed-placeholder.md"
            write_text(
                path,
                reviewed_artifact().replace("`v0.1.0`", "`TBD`"),
            )

            with self.assertRaisesRegex(
                checker.PostAuditRemediationEvidenceError,
                "Release version",
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
                checker.PostAuditRemediationEvidenceError,
                "check_public_beta_evidence",
            ):
                checker.validate_artifact(path)

    def test_secret_like_values_fail(self) -> None:
        """Secret-shaped key/value text is rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "secret.md"
            write_text(path, valid_template() + "\napi_key=do-not-commit\n")

            with self.assertRaisesRegex(
                checker.PostAuditRemediationEvidenceError,
                "secret-like",
            ):
                checker.validate_artifact(path)


if __name__ == "__main__":
    unittest.main()
