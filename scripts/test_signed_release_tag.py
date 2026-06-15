#!/usr/bin/env python3
"""Focused tests for signed release tag verification."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
from typing import Sequence


SCRIPT_PATH = Path(__file__).with_name("check_signed_release_tag.py")
SPEC = importlib.util.spec_from_file_location("check_signed_release_tag", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


COMMIT = "a" * 40
TAG = "v0.1.0"


class FakeRunner:
    def __init__(self, results: dict[tuple[str, ...], checker.CommandResult]) -> None:
        self.results = results

    def run(self, args: Sequence[str], cwd: Path) -> checker.CommandResult:
        del cwd
        key = tuple(args)
        return self.results.get(key, checker.CommandResult(1, "", f"unexpected command: {key}"))


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def file_ref(root: Path, relative_path: str, content: str | None = None) -> dict[str, str]:
    path = root / relative_path
    if content is not None:
        write_text(path, content)
    return {"path": relative_path, "sha256": checker.release_signatures.file_sha256(path)}


def self_ref(relative_path: str) -> dict[str, str]:
    return {
        "path": relative_path,
        "digest_status": checker.release_signatures.SELF_REFERENTIAL_DIGEST_STATUS,
        "reason": "Self-referential release output.",
    }


def fake_runner(
    *,
    head: str = COMMIT,
    tag_commit: str = COMMIT,
    tag_verify_code: int = 0,
    signer_fingerprint: str = "b" * 40,
) -> FakeRunner:
    return FakeRunner(
        {
            ("git", "rev-parse", "HEAD"): checker.CommandResult(0, head + "\n", ""),
            ("git", "rev-parse", "--verify", f"refs/tags/{TAG}^{{commit}}"): (
                checker.CommandResult(0, tag_commit + "\n", "")
            ),
            ("git", "tag", "-v", TAG): checker.CommandResult(
                tag_verify_code,
                "object " + COMMIT + "\n",
                f"gpg: using RSA key {signer_fingerprint}\n"
                "gpg: Good signature from release@example.test\n"
                if tag_verify_code == 0
                else "gpg: BAD signature\n",
            ),
        }
    )


def write_release_tree(
    root: Path,
    *,
    evidence_commit: str = COMMIT,
    post_bundle_evidence: bool = True,
) -> Path:
    write_text(root / "release-artifacts/latest/release-manifest.json", "{}\n")
    write_json(
        root / "release-artifacts/schema/release-signature-evidence.schema.json",
        {"schema": "release-signature-evidence"},
    )
    checksum_signature = file_ref(
        root,
        "release-artifacts/post-checksum-signatures/SHA256SUMS.asc",
        "signed checksum bundle\n",
    )
    signed_tag_output = file_ref(
        root,
        "release-artifacts/signatures/signed-tag-verification.txt",
        "gpg: Good signature from release@example.test\n",
    )
    schema = file_ref(root, "release-artifacts/schema/release-signature-evidence.schema.json")

    evidence = {
        "schema_version": checker.release_signatures.EVIDENCE_SCHEMA,
        "evidence_id": "production-release-signature-v0.1.0",
        "protocol_version": "0.1.0",
        "release_version": TAG,
        "network": {
            "environment": "production",
            "name": "release",
            "chain_id": 1,
            "confirmation_depth": 64,
        },
        "source": {
            "repository": "https://github.com/6529-Collections/6529Stream",
            "git_commit": evidence_commit,
            "source_dirty": False,
            "ci_run": "https://github.com/6529-Collections/6529Stream/actions/runs/1",
        },
        "artifacts": {
            "release_manifest": self_ref("release-artifacts/latest/release-manifest.json"),
            "checksum_bundle": self_ref("release-artifacts/latest/SHA256SUMS"),
        },
        "signing_identity": {
            "status": "active",
            "public_key_fingerprint": "b" * 40,
            "key_custody": "hardware-backed maintainer key",
            "rotation_policy": "Rotate on maintainer departure or compromise.",
        },
        "signatures": {
            "detached_checksum_signature": {
                "status": "signed",
                "format": "gpg",
                "artifact_path": "release-artifacts/post-checksum-signatures/SHA256SUMS.asc",
                "verification_command": (
                    "gpg --verify release-artifacts/post-checksum-signatures/SHA256SUMS.asc "
                    "release-artifacts/latest/SHA256SUMS"
                ),
                "evidence": [checksum_signature],
                "notes": "Signed checksum bundle.",
            },
            "signed_git_tag": {
                "status": "signed",
                "format": "gpg",
                "artifact_path": TAG,
                "verification_command": f"git tag -v {TAG}",
                "evidence": [signed_tag_output],
                "notes": "Signed Git tag.",
            },
        },
        "retained_artifacts": [
            {**schema, "category": "release_signature_schema"},
            {**checksum_signature, "category": "detached_signature"},
            {**signed_tag_output, "category": "signed_git_tag"},
            {**file_ref(root, "release-artifacts/signatures/release-review.txt", "reviewed\n"), "category": "verification_output"},
        ],
        "redaction_policy": {
            "no_secrets": True,
            "redacted_fields": ["private_key", "mnemonic", "seed_phrase", "api_key", "rpc_url"],
        },
        "operator_notes": "Reviewed production signature evidence without private key material.",
    }
    evidence_dir = (
        root / "release-artifacts/post-checksum-signatures"
        if post_bundle_evidence
        else root / "release-artifacts/signatures"
    )
    evidence_path = evidence_dir / "release-v0.1.0.json"
    write_json(evidence_path, evidence)
    checker.checksum_generator.write_outputs(
        root,
        [Path("release-artifacts/schema"), Path("release-artifacts/signatures")],
        root / "release-artifacts/latest",
    )
    return evidence_path


class SignedReleaseTagTests(unittest.TestCase):
    def test_non_release_mode_passes_without_claiming_release_status(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            with redirect_stdout(StringIO()) as stdout, redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

        self.assertEqual(result, 0)
        self.assertIn("non-release mode", stdout.getvalue())
        self.assertIn("no signed release status claimed", stdout.getvalue())

    def test_non_release_mode_rejects_tag_argument(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            with self.assertRaisesRegex(checker.SignedReleaseTagError, "only valid"):
                checker.check_signed_release_tag(root, mode="non-release", tag=TAG)

    def test_release_mode_requires_tag(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            with self.assertRaisesRegex(checker.SignedReleaseTagError, "requires --tag"):
                checker.check_signed_release_tag(root, mode="release", runner=fake_runner())

    def test_release_mode_rejects_missing_tag_ref(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_release_tree(root)
            runner = FakeRunner(
                {
                    ("git", "rev-parse", "HEAD"): checker.CommandResult(0, COMMIT + "\n", ""),
                    ("git", "rev-parse", "--verify", f"refs/tags/{TAG}^{{commit}}"): (
                        checker.CommandResult(1, "", "unknown revision")
                    ),
                }
            )

            with self.assertRaisesRegex(checker.SignedReleaseTagError, "could not resolve"):
                checker.check_signed_release_tag(root, mode="release", tag=TAG, runner=runner)

    def test_release_mode_rejects_tag_commit_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_release_tree(root)

            with self.assertRaisesRegex(checker.SignedReleaseTagError, "not HEAD"):
                checker.check_signed_release_tag(
                    root,
                    mode="release",
                    tag=TAG,
                    covered_paths=[
                        Path("release-artifacts/schema"),
                        Path("release-artifacts/signatures"),
                    ],
                    runner=fake_runner(tag_commit="c" * 40),
                )

    def test_release_mode_rejects_bad_tag_signature(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_release_tree(root)

            with self.assertRaisesRegex(checker.SignedReleaseTagError, "signature verification failed"):
                checker.check_signed_release_tag(
                    root,
                    mode="release",
                    tag=TAG,
                    covered_paths=[
                        Path("release-artifacts/schema"),
                        Path("release-artifacts/signatures"),
                    ],
                    runner=fake_runner(tag_verify_code=1),
                )

    def test_release_mode_rejects_stale_checksum_bundle(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_release_tree(root)
            write_text(root / "release-artifacts/signatures/late-file.txt", "late\n")

            with self.assertRaisesRegex(checker.SignedReleaseTagError, "checksum"):
                checker.check_signed_release_tag(
                    root,
                    mode="release",
                    tag=TAG,
                    covered_paths=[
                        Path("release-artifacts/schema"),
                        Path("release-artifacts/signatures"),
                    ],
                    runner=fake_runner(),
                )

    def test_release_mode_rejects_unmatched_signature_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_release_tree(root, evidence_commit="d" * 40)

            with self.assertRaisesRegex(checker.SignedReleaseTagError, "no release signature evidence"):
                checker.check_signed_release_tag(
                    root,
                    mode="release",
                    tag=TAG,
                    covered_paths=[
                        Path("release-artifacts/schema"),
                        Path("release-artifacts/signatures"),
                    ],
                    runner=fake_runner(),
                )

    def test_release_mode_rejects_wrong_signing_key(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence_path = write_release_tree(root)

            with self.assertRaisesRegex(checker.SignedReleaseTagError, "signer fingerprint"):
                checker.check_signed_release_tag(
                    root,
                    mode="release",
                    tag=TAG,
                    evidence=[evidence_path],
                    covered_paths=[
                        Path("release-artifacts/schema"),
                        Path("release-artifacts/signatures"),
                    ],
                    runner=fake_runner(signer_fingerprint="c" * 40),
                )

    def test_release_mode_rejects_checksum_covered_signature_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence_path = write_release_tree(root, post_bundle_evidence=False)

            with self.assertRaisesRegex(checker.SignedReleaseTagError, "post-bundle"):
                checker.check_signed_release_tag(
                    root,
                    mode="release",
                    tag=TAG,
                    evidence=[evidence_path],
                    covered_paths=[
                        Path("release-artifacts/schema"),
                        Path("release-artifacts/signatures"),
                    ],
                    runner=fake_runner(),
                )

    def test_release_mode_accepts_signed_tag_checksum_and_matching_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence_path = write_release_tree(root)

            matched = checker.check_signed_release_tag(
                root,
                mode="release",
                tag=TAG,
                evidence=[evidence_path],
                covered_paths=[
                    Path("release-artifacts/schema"),
                    Path("release-artifacts/signatures"),
                ],
                runner=fake_runner(),
            )

        self.assertEqual(matched, evidence_path)


if __name__ == "__main__":
    unittest.main(verbosity=2)
