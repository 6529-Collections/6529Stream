#!/usr/bin/env python3
"""Focused tests for live metadata browser evidence."""

from __future__ import annotations

import importlib.util
import json
import re
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_live_metadata_browser_evidence.py")
SPEC = importlib.util.spec_from_file_location(
    "check_live_metadata_browser_evidence", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def write_json(path: Path, value: object) -> None:
    """Write deterministic JSON while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def valid_template() -> str:
    """Return a valid live metadata browser retained-artifact template."""
    return """# Live Metadata Browser Retained Artifact

> Template only. This file is not completion evidence.

## Evidence Status

- Requirement ID: `live_metadata_browser_evidence`
- Evidence type: `live_metadata_browser_evidence`
- Review status: `template`
- Readiness claim: `blocked`
- Environment: `live`
- Chain ID: `1`

## Source And Production Reference

- Repository: `https://github.com/6529-Collections/6529Stream`
- Git commit: `TBD`
- CI run or operator transcript: `TBD`
- Production block or reference: `TBD`
- Network and deployment version: `TBD`
- Contract addresses: `TBD`
- Token IDs: `TBD`
- Collection IDs: `TBD`

## Required Retained Artifacts

- Browser summary JSON: `TBD`
- Generated tokenURI or digest: `TBD`
- Browser transcript or screenshot: `TBD`
- Release manifest/checksum digests: `TBD`

## Browser Results

- Metadata fetched from live contracts: `TBD`
- Browser sandbox executed: `TBD`
- Unexpected outbound requests blocked: `TBD`
- Console and page errors absent: `TBD`
- Animation bootstrap verified: `TBD`
- Parent frame isolation verified: `TBD`
- Token and collection IDs retained: `TBD`

## Review

- Operator: `TBD`
- Reviewer: `TBD`
- Review decision: `template`

## Redaction

- No secrets retained: `TBD`
- Private RPC URLs removed: `TBD`
- Private keys removed: `TBD`
- API keys removed: `TBD`
- Unreleased drop payloads removed: `TBD`

## Validation Commands

```sh
python scripts/test_live_metadata_browser_evidence.py
python scripts/check_live_metadata_browser_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/production-release-templates/live-metadata-browser-evidence-template.json --retained-artifact release-artifacts/evidence/live-metadata-browser/live-metadata-browser-retained-artifact-template.md --output release-artifacts/evidence/live-metadata-browser/live-metadata-browser-evidence.json --environment live --chain-id 1 --block-or-reference "<production block, token ID, collection ID, or browser transcript reference>" --command-or-source-system "<metadata browser transcript or CI job>" --owner "<operator>" --reviewer "<reviewer>" --source-git-commit "<release commit>" --source-ci-run "<ci run>"
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Replace every `TBD` field before requesting review.
"""


def reviewed_artifact() -> str:
    """Return a valid reviewed retained artifact."""
    return """# Live Metadata Browser Retained Artifact

## Evidence Status

- Requirement ID: `live_metadata_browser_evidence`
- Evidence type: `live_metadata_browser_evidence`
- Review status: `reviewed`
- Readiness claim: `blocked`
- Environment: `live`
- Chain ID: `1`

## Source And Production Reference

- Repository: `https://github.com/6529-Collections/6529Stream`
- Git commit: `1234567890abcdef1234567890abcdef12345678`
- CI run or operator transcript: `ci-run-123`
- Production block or reference: `mainnet block 12345678`
- Network and deployment version: `mainnet-6529stream-v0.1.0-001`
- Contract addresses: `StreamCore=0x1111111111111111111111111111111111111111`
- Token IDs: `10000000000`
- Collection IDs: `1`

## Required Retained Artifacts

- Browser summary JSON: `release-artifacts/evidence/live-metadata-browser/browser-summary.json`
- Generated tokenURI or digest: `release-artifacts/evidence/live-metadata-browser/token-uri-digest.txt`
- Browser transcript or screenshot: `release-artifacts/evidence/live-metadata-browser/browser-transcript.md`
- Release manifest/checksum digests: `release-artifacts/latest/release-manifest.json and SHA256SUMS`

## Browser Results

- Metadata fetched from live contracts: `yes`
- Browser sandbox executed: `yes`
- Unexpected outbound requests blocked: `yes`
- Console and page errors absent: `yes`
- Animation bootstrap verified: `yes`
- Parent frame isolation verified: `yes`
- Token and collection IDs retained: `yes`

## Review

- Operator: `release-operator`
- Reviewer: `release-reviewer`
- Review decision: `reviewed`

## Redaction

- No secrets retained: `yes`
- Private RPC URLs removed: `yes`
- Private keys removed: `yes`
- API keys removed: `yes`
- Unreleased drop payloads removed: `yes`

## Validation Commands

```sh
python scripts/test_live_metadata_browser_evidence.py
python scripts/check_live_metadata_browser_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/production-release-templates/live-metadata-browser-evidence-template.json --retained-artifact release-artifacts/evidence/live-metadata-browser/live-metadata-browser-retained-artifact-template.md --output release-artifacts/evidence/live-metadata-browser/live-metadata-browser-evidence.json --environment live --chain-id 1 --block-or-reference "mainnet block 12345678" --command-or-source-system "metadata browser transcript" --owner release-operator --reviewer release-reviewer --source-git-commit 1234567890abcdef1234567890abcdef12345678 --source-ci-run ci-run-123
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Reviewed retained evidence remains blocked until linked from the shared
  production-release evidence manifest.
"""


def pending_review_artifact() -> str:
    """Return a valid pending-review retained artifact."""
    return reviewed_artifact().replace(
        "- Review status: `reviewed`",
        "- Review status: `pending_review`",
    ).replace(
        "- Review decision: `reviewed`",
        "- Review decision: `pending_review`",
    )


BROWSER_SUMMARY_PATH = "release-artifacts/evidence/live-metadata-browser/browser-summary.json"
TOKEN_DIGEST_PATH = "release-artifacts/evidence/live-metadata-browser/token-uri-digest.txt"
BROWSER_TRANSCRIPT_PATH = "release-artifacts/evidence/live-metadata-browser/browser-transcript.md"


def browser_summary(
    *,
    contracts: dict[str, object] | None = None,
    page_errors: list[str] | None = None,
) -> dict[str, object]:
    """Return a compact retained live browser summary fixture."""
    return {
        "schema_version": "6529stream.live-metadata-browser-evidence.v1",
        "environment": "live",
        "chain_id": 1,
        "no_secrets": True,
        "source": {
            "git_commit": "1234567890abcdef1234567890abcdef12345678",
            "command_or_source_system": "metadata browser transcript",
        },
        "contracts": contracts
        or {"StreamCore": {"address": "0x1111111111111111111111111111111111111111"}},
        "token_results": [
            {
                "token_id": 10000000000,
                "collection_id": 1,
                "token_uri_sha256": (
                    "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                ),
                "sandbox": {
                    "metadata_fetched_from_live_contract": True,
                    "browser_executed": True,
                    "dependency_loaded": True,
                    "draw_is_function": True,
                    "parent_access_blocked": True,
                    "unexpected_requests": [],
                    "page_errors": [] if page_errors is None else page_errors,
                    "console_errors": [],
                },
            }
        ],
    }


def seed_reviewed_retained_files(
    root: Path,
    *,
    secret_text: str | None = None,
    page_errors: list[str] | None = None,
) -> None:
    """Create retained files referenced by reviewed_artifact under a root."""
    write_json(root / BROWSER_SUMMARY_PATH, browser_summary(page_errors=page_errors))
    write_text(
        root / TOKEN_DIGEST_PATH,
        "tokenURI sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n",
    )
    transcript = "sanitized retained live metadata browser transcript\n"
    if secret_text is not None:
        transcript += secret_text
    write_text(root / BROWSER_TRANSCRIPT_PATH, transcript)


def artifact_with_field(text: str, label: str, value: str) -> str:
    """Replace one Markdown bullet field value."""
    return re.sub(
        rf"^- {re.escape(label)}: .*$",
        lambda _match: f"- {label}: `{value}`",
        text,
        flags=re.MULTILINE,
    )


class LiveMetadataBrowserEvidenceTests(unittest.TestCase):
    """Checker behavior for live metadata browser evidence."""

    def test_committed_template_passes(self) -> None:
        """The committed template satisfies the checker."""
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main([])

        self.assertEqual(result, 0)

    def test_template_state_does_not_resolve_retained_files(self) -> None:
        """Template artifacts can keep non-existent retained-file placeholders."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "template-missing-retained-files.md"
            text = valid_template()
            text = artifact_with_field(
                text, "Browser summary JSON", "missing/live/browser-summary.json"
            )
            text = artifact_with_field(
                text,
                "Generated tokenURI or digest",
                "missing/live/token-output.json",
            )
            text = artifact_with_field(
                text,
                "Browser transcript or screenshot",
                "missing/live/transcript.md",
            )
            write_text(path, text)

            checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_artifact_passes(self) -> None:
        """A filled reviewed artifact can pass before manifest linkage."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "reviewed.md"
            seed_reviewed_retained_files(repo_root)
            write_text(path, reviewed_artifact())

            checker.validate_artifact(path, repo_root=repo_root)

    def test_pending_review_validates_payloads(self) -> None:
        """Pending-review evidence validates retained payload shape early."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "pending-review.md"
            seed_reviewed_retained_files(repo_root, page_errors=["boom"])
            write_text(path, pending_review_artifact())

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "page_errors must be empty",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_wrong_requirement_fails(self) -> None:
        """The artifact must map only to the live metadata-browser row."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "wrong-requirement.md"
            write_text(
                path,
                valid_template().replace(
                    "`live_metadata_browser_evidence`",
                    "`live_ceremony_evidence`",
                    1,
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "live_metadata_browser_evidence",
            ):
                checker.validate_artifact(path)

    def test_wrong_environment_fails(self) -> None:
        """The artifact is only for live mainnet production evidence."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "wrong-environment.md"
            write_text(path, valid_template().replace("- Environment: `live`", "- Environment: `fork`"))

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "Environment",
            ):
                checker.validate_artifact(path)

    def test_reviewed_placeholders_fail(self) -> None:
        """Reviewed artifacts cannot retain template placeholders."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "reviewed-placeholder.md"
            write_text(
                path,
                reviewed_artifact().replace("`mainnet block 12345678`", "`TBD`"),
            )

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "Production block or reference",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_template_notice_fails(self) -> None:
        """Reviewed artifacts must remove the template-only notice."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "reviewed-template-notice.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    "# Live Metadata Browser Retained Artifact\n\n",
                    "# Live Metadata Browser Retained Artifact\n\n"
                    "> Template only. This file is not completion evidence.\n\n",
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "non-template evidence",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_template_without_notice_fails(self) -> None:
        """Template-state artifacts must keep the template-only notice."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "template-without-notice.md"
            write_text(
                path,
                valid_template().replace(
                    "> Template only. This file is not completion evidence.\n\n",
                    "",
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "template-only notice",
            ):
                checker.validate_artifact(path)

    def test_missing_retained_file_fails(self) -> None:
        """Reviewed retained artifact references must point to files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "reviewed-missing-retained-file.md"
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "missing retained file",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    @unittest.skipIf(not hasattr(Path, "symlink_to"), "symlinks unavailable")
    def test_symlinked_retained_file_fails(self) -> None:
        """Reviewed retained files must be ordinary files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_reviewed_retained_files(repo_root)
            symlink = (
                repo_root
                / "release-artifacts/evidence/live-metadata-browser/browser-summary-link.json"
            )
            try:
                symlink.symlink_to(repo_root / BROWSER_SUMMARY_PATH)
            except OSError as exc:
                self.skipTest(f"symlink creation unavailable: {exc}")
            path = repo_root / "reviewed-symlink-retained-file.md"
            write_text(
                path,
                artifact_with_field(
                    reviewed_artifact(),
                    "Browser summary JSON",
                    "release-artifacts/evidence/live-metadata-browser/browser-summary-link.json",
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "symlinked retained",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    @unittest.skipIf(not hasattr(Path, "symlink_to"), "symlinks unavailable")
    def test_symlinked_retained_directory_fails(self) -> None:
        """Reviewed retained files cannot cross symlinked directories."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_reviewed_retained_files(repo_root)
            target_dir = repo_root / "release-artifacts/evidence/live-metadata-target"
            target_dir.mkdir(parents=True)
            write_json(target_dir / "browser-summary.json", browser_summary())
            symlink_dir = repo_root / "release-artifacts/evidence/live-metadata-link"
            try:
                symlink_dir.symlink_to(target_dir, target_is_directory=True)
            except OSError as exc:
                self.skipTest(f"directory symlink creation unavailable: {exc}")
            path = repo_root / "reviewed-symlink-retained-directory.md"
            write_text(
                path,
                artifact_with_field(
                    reviewed_artifact(),
                    "Browser summary JSON",
                    "release-artifacts/evidence/live-metadata-link/browser-summary.json",
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "symlinked retained",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_artifact_with_declared_hashes_passes(self) -> None:
        """Declared retained hashes are accepted when they match disk."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_reviewed_retained_files(repo_root)
            summary_hash = checker.file_sha256(repo_root / BROWSER_SUMMARY_PATH)
            path = repo_root / "reviewed-hashes.md"
            write_text(
                path,
                artifact_with_field(
                    reviewed_artifact(),
                    "Browser summary JSON",
                    f"{BROWSER_SUMMARY_PATH} / {summary_hash}",
                ),
            )

            checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_placeholder_fails_clearly(self) -> None:
        """Retained artifact placeholders fail before path resolution."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_reviewed_retained_files(repo_root)
            path = repo_root / "placeholder-retained.md"
            write_text(
                path,
                artifact_with_field(reviewed_artifact(), "Browser summary JSON", "TBD"),
            )

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "must be replaced before non-template review",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_parent_path_escape_fails(self) -> None:
        """Retained artifact paths cannot escape through parent segments."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_reviewed_retained_files(repo_root)
            path = repo_root / "escape-retained.md"
            write_text(
                path,
                artifact_with_field(
                    reviewed_artifact(),
                    "Browser summary JSON",
                    "../browser-summary.json",
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "escape",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_absolute_path_fails(self) -> None:
        """Retained artifact paths must be repo-relative."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_reviewed_retained_files(repo_root)
            path = repo_root / "absolute-retained.md"
            write_text(
                path,
                artifact_with_field(
                    reviewed_artifact(),
                    "Browser summary JSON",
                    "/tmp/browser-summary.json",
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "repo-relative",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_backslash_path_fails(self) -> None:
        """Retained artifact paths cannot use Windows backslashes."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_reviewed_retained_files(repo_root)
            path = repo_root / "backslash-retained.md"
            write_text(
                path,
                artifact_with_field(
                    reviewed_artifact(),
                    "Browser summary JSON",
                    "release-artifacts\\evidence\\live-metadata-browser\\browser-summary.json",
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "escape",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_whitespace_path_fails(self) -> None:
        """Retained artifact references must be a single path."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_reviewed_retained_files(repo_root)
            path = repo_root / "whitespace-retained.md"
            write_text(
                path,
                artifact_with_field(
                    reviewed_artifact(),
                    "Browser summary JSON",
                    "release-artifacts/evidence/live-metadata-browser/browser summary.json",
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "one repo-relative path",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_multiple_hashes_fail(self) -> None:
        """A retained reference cannot silently carry multiple digests."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_reviewed_retained_files(repo_root)
            path = repo_root / "multi-hash-retained.md"
            write_text(
                path,
                artifact_with_field(
                    reviewed_artifact(),
                    "Browser summary JSON",
                    f"{BROWSER_SUMMARY_PATH} / sha256:{'a' * 64} / sha256:{'b' * 64}",
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "multiple sha256",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_hash_drift_fails(self) -> None:
        """Declared retained hashes must match disk contents."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_reviewed_retained_files(repo_root)
            path = repo_root / "hash-drift-retained.md"
            write_text(
                path,
                artifact_with_field(
                    reviewed_artifact(),
                    "Browser summary JSON",
                    f"{BROWSER_SUMMARY_PATH} / sha256:{'f' * 64}",
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "sha256 mismatch",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_hash_without_separator_fails(self) -> None:
        """Declared retained hashes need an explicit path/hash separator."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_reviewed_retained_files(repo_root)
            summary_hash = checker.file_sha256(repo_root / BROWSER_SUMMARY_PATH)
            path = repo_root / "hash-no-separator-retained.md"
            write_text(
                path,
                artifact_with_field(
                    reviewed_artifact(),
                    "Browser summary JSON",
                    f"{BROWSER_SUMMARY_PATH}/{summary_hash}",
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "separate path and sha256 digest",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_malformed_hash_fails(self) -> None:
        """Malformed retained hashes fail explicitly."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_reviewed_retained_files(repo_root)
            path = repo_root / "malformed-hash-retained.md"
            write_text(
                path,
                artifact_with_field(
                    reviewed_artifact(),
                    "Browser summary JSON",
                    f"{BROWSER_SUMMARY_PATH} / sha256:{'A' * 64}",
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "malformed sha256",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_hash_trailing_text_fails(self) -> None:
        """Declared retained hashes cannot hide trailing field text."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_reviewed_retained_files(repo_root)
            summary_hash = checker.file_sha256(repo_root / BROWSER_SUMMARY_PATH)
            path = repo_root / "hash-trailing-retained.md"
            write_text(
                path,
                artifact_with_field(
                    reviewed_artifact(),
                    "Browser summary JSON",
                    f"{BROWSER_SUMMARY_PATH} / {summary_hash} unexpected",
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "trailing text",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_summary_schema_mismatch_fails(self) -> None:
        """The retained browser summary must use the expected schema."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "reviewed-schema-mismatch.md"
            seed_reviewed_retained_files(root)
            summary_path = root / BROWSER_SUMMARY_PATH
            summary = json.loads(summary_path.read_text(encoding="utf-8"))
            summary["schema_version"] = "wrong"
            write_json(summary_path, summary)
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "schema_version",
            ):
                checker.validate_artifact(path, repo_root=root)

    def test_summary_unexpected_requests_fail(self) -> None:
        """The retained browser summary must reject unexpected network requests."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "reviewed-unexpected-request.md"
            seed_reviewed_retained_files(root)
            summary_path = root / BROWSER_SUMMARY_PATH
            summary = json.loads(summary_path.read_text(encoding="utf-8"))
            summary["token_results"][0]["sandbox"]["unexpected_requests"] = [
                "https://example.invalid"
            ]
            write_json(summary_path, summary)
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "unexpected_requests must be empty",
            ):
                checker.validate_artifact(path, repo_root=root)

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
                checker.LiveMetadataBrowserEvidenceError,
                "check_public_beta_evidence",
            ):
                checker.validate_artifact(path)

    def test_wrong_generate_template_argument_fails(self) -> None:
        """The generator command must use the metadata-browser envelope template."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "wrong-template-argument.md"
            write_text(
                path,
                valid_template().replace(
                    "live-metadata-browser-evidence-template.json",
                    "live-ceremony-evidence-template.json",
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "live-metadata-browser-evidence-template",
            ):
                checker.validate_artifact(path)

    def test_secret_like_values_fail(self) -> None:
        """Secret-shaped key/value text is rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "secret.md"
            write_text(path, valid_template() + "\napi_key=do-not-commit\n")

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "secret-like",
            ):
                checker.validate_artifact(path)

    def test_safe_token_explorer_url_passes_secret_scan(self) -> None:
        """Safe explorer token URLs are not treated as provider credentials."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "safe-token-url.md"
            write_text(
                path,
                valid_template()
                + "\n- Explorer reference: https://etherscan.io/token/"
                + "0x1111111111111111111111111111111111111111?a=10000000000\n",
            )

            checker.validate_artifact(path)

    def test_credential_query_url_fails_secret_scan(self) -> None:
        """Credential-bearing URL query parameters still fail closed."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "credential-query-url.md"
            write_text(
                path,
                valid_template() + "\nhttps://example.invalid/path?token=do-not-commit\n",
            )

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "secret-like CLI",
            ):
                checker.validate_artifact(path)

    def test_credentialed_url_fails_secret_scan(self) -> None:
        """Credentialed URLs are secret-shaped even outside explicit keys."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "credentialed-url.md"
            write_text(
                path,
                valid_template() + "\nhttps://user:pass@example.invalid/path\n",
            )

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "secret-like CLI",
            ):
                checker.validate_artifact(path)

    def test_bare_hex_secret_like_text_fails(self) -> None:
        """Unprefixed 64-hex strings are treated as secret-shaped material."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bare-hex.md"
            write_text(path, valid_template() + f"\n{'a' * 64}\n")

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "bare 64-hex",
            ):
                checker.validate_artifact(path)

    def test_referenced_artifact_secret_values_fail(self) -> None:
        """Reviewed retained transcript files are scanned too."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "reviewed-referenced-secret.md"
            seed_reviewed_retained_files(
                repo_root,
                secret_text="--private-key 0xabc123\n",
            )
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "secret-like CLI",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_duplicate_summary_contract_address_fails(self) -> None:
        """Browser summaries must not duplicate contract addresses."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "reviewed-duplicate-contract.md"
            seed_reviewed_retained_files(root)
            summary_path = root / BROWSER_SUMMARY_PATH
            summary = browser_summary(
                contracts={
                    "StreamCore": {
                        "address": "0x1111111111111111111111111111111111111111"
                    },
                    "StreamMinter": {
                        "address": "0x1111111111111111111111111111111111111111"
                    },
                }
            )
            write_json(summary_path, summary)
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "duplicates contract address",
            ):
                checker.validate_artifact(path, repo_root=root)

    def test_angle_bracket_placeholder_fails_non_template_artifact(self) -> None:
        """Non-template artifacts cannot keep angle-bracket placeholders."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "reviewed-angle-placeholder.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    "`mainnet-6529stream-v0.1.0-001`",
                    "`<deployment version>`",
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveMetadataBrowserEvidenceError,
                "Network and deployment version",
            ):
                checker.validate_artifact(path, repo_root=repo_root)


if __name__ == "__main__":
    unittest.main()
