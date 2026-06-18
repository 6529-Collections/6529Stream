#!/usr/bin/env python3
"""Focused tests for production release-signing retained evidence."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_production_release_signing_evidence.py")
SPEC = importlib.util.spec_from_file_location(
    "check_production_release_signing_evidence", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)

TEMPLATE_PATH = checker.DEFAULT_REPO_ROOT / checker.DEFAULT_EVIDENCE_RELATIVE
RELEASE_VERSION = "v0.1.0"
RELEASE_COMMIT = "1" * 40
SIGNER_FINGERPRINT = "a" * 40
DIGESTS_PATH = "release-artifacts/evidence/production-release-signing/release-digests.md"
CHECKSUM_BUNDLE_PATH = "release-artifacts/latest/SHA256SUMS"
DETACHED_SIGNATURE_PATH = "release-artifacts/latest/SHA256SUMS.asc"
SIGNED_TAG_OUTPUT_PATH = (
    "release-artifacts/evidence/production-release-signing/git-tag-verify.txt"
)
SIGNATURE_JSON_PATH = "release-artifacts/signatures/mainnet-v0.1.0.json"
COMMAND_OUTPUTS_PATH = (
    "release-artifacts/evidence/production-release-signing/verification-commands.txt"
)


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def write_bytes(path: Path, value: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(value)


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def template_text() -> str:
    return TEMPLATE_PATH.read_text(encoding="utf-8")


def artifact_with_field(text: str, label: str, value: str) -> str:
    old = f"- {label}: `"
    start = text.index(old) + len(old)
    end = text.index("`", start)
    return text[:start] + value + text[end:]


def file_ref(root: Path, relative_path: str, content: str = "evidence retained\n") -> dict[str, str]:
    path = root / relative_path
    write_text(path, content)
    return {"path": relative_path, "sha256": checker.file_sha256(path)}


def self_ref(relative_path: str) -> dict[str, str]:
    return {
        "path": relative_path,
        "digest_status": checker.release_signatures.SELF_REFERENTIAL_DIGEST_STATUS,
        "reason": "Self-referential release output.",
    }


def signed_result(
    artifact_path: str, verification_command: str, evidence_ref: dict[str, str]
) -> dict[str, object]:
    return {
        "status": "signed",
        "format": "gpg",
        "artifact_path": artifact_path,
        "verification_command": verification_command,
        "evidence": [evidence_ref],
        "notes": "signed production release evidence",
    }


def reviewed_artifact() -> str:
    text = template_text()
    replacements = {
        "Review status": "reviewed",
        "Release version": RELEASE_VERSION,
        "Signed Git tag": RELEASE_VERSION,
        "Release commit": RELEASE_COMMIT,
        "Signer fingerprint": SIGNER_FINGERPRINT,
        "Signer custody summary": "Safe-controlled release signer custody export retained",
        "Signer rotation/revocation policy": "Signer rotation follows release runbook",
        "Release manifest/checksum digests": DIGESTS_PATH,
        "Checksum bundle": CHECKSUM_BUNDLE_PATH,
        "Detached checksum signature evidence": DETACHED_SIGNATURE_PATH,
        "Signed Git tag verification evidence": SIGNED_TAG_OUTPUT_PATH,
        "Release signature evidence JSON": SIGNATURE_JSON_PATH,
        "Verification command outputs": COMMAND_OUTPUTS_PATH,
        "Reviewer": "release-reviewer",
        "Review decision": "reviewed",
        "No secrets retained": "yes",
        "Production signatures tracker updated": "yes",
        "Signed tag tracker updated": "yes",
        "Release signature checker executed": "yes",
        "Signed release tag checker executed": "yes",
    }
    for label, value in replacements.items():
        text = artifact_with_field(text, label, value)
    return text


def seed_reviewed_retained_files(
    root: Path,
    *,
    command_outputs_content: str | None = None,
) -> None:
    """Create retained files referenced by a reviewed artifact."""
    write_text(root / "release-artifacts/latest/release-manifest.json", "{}\n")
    write_text(
        root / CHECKSUM_BUNDLE_PATH,
        f"{'b' * 64}  release-artifacts/latest/release-manifest.json\n",
    )
    detached_ref = file_ref(
        root,
        DETACHED_SIGNATURE_PATH,
        "-----BEGIN PGP SIGNATURE-----\nredacted-test-signature\n-----END PGP SIGNATURE-----\n",
    )
    tag_ref = file_ref(
        root,
        SIGNED_TAG_OUTPUT_PATH,
        f"gpg: Good signature from release signer {SIGNER_FINGERPRINT}\n",
    )
    write_text(root / DIGESTS_PATH, "sha256:abcd release manifest and checksum digests\n")
    write_text(
        root / COMMAND_OUTPUTS_PATH,
        command_outputs_content
        or (
            "python scripts/check_release_signatures.py "
            "release-artifacts/signatures/mainnet-v0.1.0.json\n"
            "python scripts/check_signed_release_tag.py --mode release --tag v0.1.0\n"
        ),
    )
    command_outputs_ref = {
        "path": COMMAND_OUTPUTS_PATH,
        "sha256": checker.file_sha256(root / COMMAND_OUTPUTS_PATH),
    }

    evidence = {
        "schema_version": checker.release_signatures.EVIDENCE_SCHEMA,
        "evidence_id": "mainnet-release-signature",
        "protocol_version": "0.1.0",
        "release_version": RELEASE_VERSION,
        "network": {
            "environment": "production",
            "name": "mainnet",
            "chain_id": 1,
            "confirmation_depth": 64,
        },
        "source": {
            "repository": "https://github.com/6529-Collections/6529Stream",
            "git_commit": RELEASE_COMMIT,
            "source_dirty": False,
            "ci_run": "production-release-ci",
        },
        "artifacts": {
            "release_manifest": self_ref("release-artifacts/latest/release-manifest.json"),
            "checksum_bundle": self_ref(CHECKSUM_BUNDLE_PATH),
        },
        "signing_identity": {
            "status": "active",
            "public_key_fingerprint": SIGNER_FINGERPRINT,
            "key_custody": "Safe-controlled release signer",
            "rotation_policy": "Rotate signer after compromise or release-policy change.",
        },
        "signatures": {
            "detached_checksum_signature": signed_result(
                DETACHED_SIGNATURE_PATH,
                "gpg --verify release-artifacts/latest/SHA256SUMS.asc release-artifacts/latest/SHA256SUMS",
                detached_ref,
            ),
            "signed_git_tag": signed_result(
                RELEASE_VERSION,
                f"git tag -v {RELEASE_VERSION}",
                tag_ref,
            ),
        },
        "retained_artifacts": [
            {**detached_ref, "category": "detached_signature"},
            {**tag_ref, "category": "signed_git_tag"},
            {**command_outputs_ref, "category": "verification_output"},
        ],
        "redaction_policy": {
            "no_secrets": True,
            "redacted_fields": ["private_key", "mnemonic", "api_key", "rpc_url"],
        },
        "operator_notes": "reviewed production release-signing evidence",
    }
    write_json(root / SIGNATURE_JSON_PATH, evidence)


class ProductionReleaseSigningEvidenceTests(unittest.TestCase):
    def test_committed_template_passes(self) -> None:
        checker.validate_artifact(TEMPLATE_PATH, checker.DEFAULT_REPO_ROOT)

    def test_reviewed_artifact_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_reviewed_retained_files(root)
            path = root / "reviewed-release-signing.md"
            write_text(path, reviewed_artifact())

            checker.validate_artifact(path)

    def test_reviewed_template_prefix_content_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_reviewed_retained_files(root)
            text = artifact_with_field(
                reviewed_artifact(),
                "Signer custody summary",
                "Template signer custody policy adopted for this production ceremony",
            )
            path = root / "template-prefix-content.md"
            write_text(path, text)

            checker.validate_artifact(path)

    def test_reviewed_declared_hash_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_reviewed_retained_files(root)
            digest = checker.file_sha256(root / COMMAND_OUTPUTS_PATH)
            text = artifact_with_field(
                reviewed_artifact(),
                "Verification command outputs",
                f"{COMMAND_OUTPUTS_PATH} {digest}",
            )
            path = root / "reviewed-hash.md"
            write_text(path, text)

            checker.validate_artifact(path)

    def test_template_state_does_not_resolve_retained_files(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "template.md"
            write_text(path, template_text())

            checker.validate_artifact(path)

    def test_pending_review_rejects_reviewed_decision(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            text = artifact_with_field(reviewed_artifact(), "Review status", "pending_review")
            text = artifact_with_field(text, "Review decision", "reviewed")
            path = root / "pending-review-reviewed-decision.md"
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.ProductionReleaseSigningEvidenceError, "Review decision"
            ):
                checker.validate_artifact(path)

    def test_reviewed_rejects_pending_review_decision(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            text = artifact_with_field(reviewed_artifact(), "Review decision", "pending_review")
            path = root / "reviewed-pending-review-decision.md"
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.ProductionReleaseSigningEvidenceError, "Review decision"
            ):
                checker.validate_artifact(path)

    def test_reviewed_missing_retained_file_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "missing.md"
            seed_reviewed_retained_files(root)
            text = artifact_with_field(
                reviewed_artifact(),
                "Verification command outputs",
                "release-artifacts/evidence/production-release-signing/missing.txt",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.ProductionReleaseSigningEvidenceError, "missing retained file"
            ):
                checker.validate_artifact(path)

    def test_reviewed_parent_path_escape_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "escape.md"
            seed_reviewed_retained_files(root)
            text = artifact_with_field(
                reviewed_artifact(),
                "Verification command outputs",
                "../outside.txt",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.ProductionReleaseSigningEvidenceError, "escape"
            ):
                checker.validate_artifact(path)

    def test_reviewed_absolute_path_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "absolute.md"
            seed_reviewed_retained_files(root)
            text = artifact_with_field(
                reviewed_artifact(),
                "Verification command outputs",
                str(root / COMMAND_OUTPUTS_PATH),
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.ProductionReleaseSigningEvidenceError, "repo-relative"
            ):
                checker.validate_artifact(path)

    def test_reviewed_backslash_path_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "backslash.md"
            seed_reviewed_retained_files(root)
            text = artifact_with_field(
                reviewed_artifact(),
                "Verification command outputs",
                COMMAND_OUTPUTS_PATH.replace("/", "\\"),
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.ProductionReleaseSigningEvidenceError, "forward slashes"
            ):
                checker.validate_artifact(path)

    def test_reviewed_whitespace_path_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "whitespace.md"
            seed_reviewed_retained_files(root)
            text = artifact_with_field(
                reviewed_artifact(),
                "Verification command outputs",
                "release-artifacts/evidence/production-release-signing/command outputs.txt",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.ProductionReleaseSigningEvidenceError, "one repo-relative path"
            ):
                checker.validate_artifact(path)

    def test_reviewed_symlink_file_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "symlink.md"
            seed_reviewed_retained_files(root)
            target = root / COMMAND_OUTPUTS_PATH
            symlink = root / "release-artifacts/evidence/production-release-signing/symlink.txt"
            symlink.parent.mkdir(parents=True, exist_ok=True)
            try:
                symlink.symlink_to(target)
            except OSError:
                self.skipTest("symlinks are not available in this environment")
            text = artifact_with_field(
                reviewed_artifact(),
                "Verification command outputs",
                "release-artifacts/evidence/production-release-signing/symlink.txt",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.ProductionReleaseSigningEvidenceError, "symlinked"
            ):
                checker.validate_artifact(path)

    def test_reviewed_multiple_hashes_fail(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "multiple.md"
            seed_reviewed_retained_files(root)
            digest = checker.file_sha256(root / COMMAND_OUTPUTS_PATH)
            text = artifact_with_field(
                reviewed_artifact(),
                "Verification command outputs",
                f"{COMMAND_OUTPUTS_PATH} {digest} / {digest}",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.ProductionReleaseSigningEvidenceError, "multiple sha256"
            ):
                checker.validate_artifact(path)

    def test_reviewed_stale_hash_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "stale.md"
            seed_reviewed_retained_files(root)
            text = artifact_with_field(
                reviewed_artifact(),
                "Verification command outputs",
                f"{COMMAND_OUTPUTS_PATH} sha256:{'0' * 64}",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.ProductionReleaseSigningEvidenceError, "sha256 mismatch"
            ):
                checker.validate_artifact(path)

    def test_reviewed_malformed_hash_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "malformed.md"
            seed_reviewed_retained_files(root)
            text = artifact_with_field(
                reviewed_artifact(),
                "Verification command outputs",
                f"{COMMAND_OUTPUTS_PATH} sha256:{'A' * 64}",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.ProductionReleaseSigningEvidenceError, "malformed sha256"
            ):
                checker.validate_artifact(path)

    def test_reviewed_trailing_hash_text_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "trailing.md"
            seed_reviewed_retained_files(root)
            digest = checker.file_sha256(root / COMMAND_OUTPUTS_PATH)
            text = artifact_with_field(
                reviewed_artifact(),
                "Verification command outputs",
                f"{COMMAND_OUTPUTS_PATH} {digest} reviewed",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.ProductionReleaseSigningEvidenceError, "trailing text"
            ):
                checker.validate_artifact(path)

    def test_reviewed_non_utf8_retained_file_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "non-utf8.md"
            seed_reviewed_retained_files(root)
            write_bytes(root / COMMAND_OUTPUTS_PATH, b"\xff\xfe\xfd")
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.ProductionReleaseSigningEvidenceError, "valid UTF-8"
            ):
                checker.validate_artifact(path)

    def test_reviewed_retained_bare_64_hex_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "bare-hex.md"
            seed_reviewed_retained_files(root)
            write_text(root / COMMAND_OUTPUTS_PATH, "a" * 64 + "\n")
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.ProductionReleaseSigningEvidenceError, "bare 64-hex"
            ):
                checker.validate_artifact(path)

    def test_reviewed_checksum_bundle_allows_sha256sum_format(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "checksum-bundle.md"
            seed_reviewed_retained_files(root)
            write_text(
                root / CHECKSUM_BUNDLE_PATH,
                f"{'c' * 64}  release-artifacts/latest/release-manifest.json\n",
            )
            write_text(path, reviewed_artifact())

            checker.validate_artifact(path)

    def test_reviewed_retained_bearer_placeholder_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "bearer.md"
            seed_reviewed_retained_files(root)
            write_text(root / COMMAND_OUTPUTS_PATH, "Authorization: Bearer <token>\n")
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.ProductionReleaseSigningEvidenceError, "secret-like CLI or URL"
            ):
                checker.validate_artifact(path)

    def test_reviewed_redacted_rpc_placeholder_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "redacted-rpc.md"
            seed_reviewed_retained_files(
                root,
                command_outputs_content="cast call --rpc-url <redacted>\n",
            )
            write_text(path, reviewed_artifact())

            checker.validate_artifact(path)

    def test_reviewed_signature_json_must_be_production(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "wrong-env.md"
            seed_reviewed_retained_files(root)
            data = json.loads((root / SIGNATURE_JSON_PATH).read_text(encoding="utf-8"))
            data["network"]["environment"] = "testnet"
            write_json(root / SIGNATURE_JSON_PATH, data)
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.ProductionReleaseSigningEvidenceError, "mainnet or production"
            ):
                checker.validate_artifact(path)

    def test_reviewed_signature_json_commit_mismatch_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "commit-mismatch.md"
            seed_reviewed_retained_files(root)
            data = json.loads((root / SIGNATURE_JSON_PATH).read_text(encoding="utf-8"))
            data["source"]["git_commit"] = "2" * 40
            write_json(root / SIGNATURE_JSON_PATH, data)
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.ProductionReleaseSigningEvidenceError, "source.git_commit mismatch"
            ):
                checker.validate_artifact(path)


if __name__ == "__main__":
    unittest.main(verbosity=2)
