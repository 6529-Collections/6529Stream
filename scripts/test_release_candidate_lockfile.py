#!/usr/bin/env python3
"""Focused tests for release-candidate lockfile generation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("generate_release_candidate_lockfile.py")
SPEC = importlib.util.spec_from_file_location("generate_release_candidate_lockfile", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
generator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(generator)


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def file_ref(root: Path, relative_path: str) -> dict[str, object]:
    path = root / relative_path
    return {
        "path": relative_path,
        "sha256": generator.file_sha256(path),
    }


def signature_result(status: str) -> dict[str, object]:
    return {
        "status": status,
        "format": "not_applicable_local",
        "artifact_path": "not_applicable_local",
        "verification_command": "not_applicable_local",
        "evidence": [],
        "notes": f"{status} signature result",
    }


def seed_release_tree(root: Path) -> dict[str, Path]:
    latest = root / "release-artifacts" / "latest"
    signatures = root / "release-artifacts" / "signatures"

    write_json(
        latest / "release-manifest.json",
        {
            "schema_version": generator.RELEASE_MANIFEST_SCHEMA,
            "generated_by": "unit-test",
            "release": {
                "project": "6529Stream",
                "status": "pre_audit_local_baseline",
            },
            "release_artifacts": {},
        },
    )
    write_json(
        latest / "bytecode-release-proof.json",
        {
            "schema_version": generator.BYTECODE_PROOF_SCHEMA,
            "generated_by": "unit-test",
            "source": {
                "release_manifest": file_ref(
                    root,
                    "release-artifacts/latest/release-manifest.json",
                )
            },
        },
    )
    write_json(
        latest / "public-beta-evidence.json",
        {
            "schema_version": generator.PUBLIC_BETA_EVIDENCE_SCHEMA,
            "release_version": "v0.1.0-local",
            "source": {
                "repository": "https://github.com/6529-Collections/6529Stream",
                "git_commit": "0" * 40,
                "source_dirty": False,
                "ci_run": "local",
            },
            "status": {"public_beta": "blocked", "production_release": "blocked"},
            "requirements": [
                {
                    "id": "fork_deployment_rehearsal",
                    "phase": "public_beta",
                    "status": "complete",
                    "owner": "Codex",
                    "evidence": [],
                    "risk_acceptance": None,
                    "notes": "complete fixture",
                },
                {
                    "id": "external_audit_report",
                    "phase": "public_beta",
                    "status": "missing",
                    "owner": "TBD",
                    "evidence": [],
                    "risk_acceptance": None,
                    "notes": "missing fixture",
                },
                {
                    "id": "signed_git_tag",
                    "phase": "production_release",
                    "status": "missing",
                    "owner": "TBD",
                    "evidence": [],
                    "risk_acceptance": None,
                    "notes": "missing fixture",
                },
            ],
        },
    )
    write_json(
        latest / "risk-register.json",
        {
            "schema_version": generator.RISK_REGISTER_SCHEMA,
            "risks": [{"id": "RISK-AUD-002"}],
        },
    )
    write_json(
        latest / "release-notes.json",
        {"schema_version": generator.RELEASE_NOTES_SCHEMA, "release": {}},
    )
    write_text(latest / "release-notes.md", "# Release Notes\n")
    write_text(latest / "public-beta-blockers.md", "# Public Beta Blockers\n")
    write_text(latest / "production-release-blockers.md", "# Production Blockers\n")
    write_json(
        latest / "release-evidence-packet-index.json",
        {
            "schema_version": generator.RELEASE_EVIDENCE_PACKET_INDEX_SCHEMA,
            "items": [],
        },
    )
    write_text(latest / "release-evidence-packet-index.md", "# Evidence Packet\n")
    write_json(
        latest / "release-evidence-issue-backlog.json",
        {"schema_version": "6529stream.release-evidence-issue-backlog.v1", "issues": []},
    )
    write_text(latest / "release-evidence-issue-backlog.md", "# Evidence Issues\n")
    write_json(
        latest / "release-evidence-issue-body-sync.json",
        {"schema_version": "6529stream.release-evidence-issue-body-sync.v1", "issues": []},
    )
    write_text(latest / "release-evidence-issue-body-sync.md", "# Evidence Issue Sync\n")
    write_text(latest / "SHA256SUMS", "placeholder\n")
    write_json(latest / "release-checksums.json", {"schema_version": "fixture.checksums"})
    write_json(
        root / "release-artifacts" / "schema" / "release-signature-evidence.schema.json",
        {"schema_version": "https://json-schema.org/draft/2020-12/schema"},
    )
    write_json(
        signatures / "anvil-local.json",
        {
            "schema_version": generator.release_signature_checker.EVIDENCE_SCHEMA,
            "evidence_id": "anvil-release-signature-local",
            "protocol_version": "0.1.0",
            "release_version": "v0.1.0-local",
            "network": {
                "environment": "local",
                "name": "anvil",
                "chain_id": 31337,
                "confirmation_depth": 0,
            },
            "source": {
                "repository": "https://github.com/6529-Collections/6529Stream",
                "git_commit": "0" * 40,
                "source_dirty": False,
                "ci_run": "local",
            },
            "artifacts": {
                "release_manifest": {
                    "path": "release-artifacts/latest/release-manifest.json",
                    "digest_status": generator.SELF_REFERENTIAL_DIGEST_STATUS,
                    "reason": "fixture self reference",
                },
                "checksum_bundle": {
                    "path": "release-artifacts/latest/SHA256SUMS",
                    "digest_status": generator.SELF_REFERENTIAL_DIGEST_STATUS,
                    "reason": "fixture self reference",
                },
            },
            "signing_identity": {
                "status": "not_available_local",
                "public_key_fingerprint": "not_applicable_local",
                "key_custody": "not_applicable_local",
                "rotation_policy": "fixture rotation policy",
            },
            "signatures": {
                "detached_checksum_signature": signature_result("not_available_local"),
                "signed_git_tag": signature_result("not_available_local"),
            },
            "retained_artifacts": [
                {
                    **file_ref(
                        root,
                        "release-artifacts/schema/release-signature-evidence.schema.json",
                    ),
                    "category": "release_signature_schema",
                }
            ],
            "redaction_policy": {
                "no_secrets": True,
                "redacted_fields": ["private_key", "mnemonic", "api_key", "rpc_url"],
            },
            "operator_notes": "fixture only",
        },
    )
    return {
        "latest": latest,
        "signatures": signatures,
        "output": latest / "release-candidate-lockfile.json",
        "release_manifest": latest / "release-manifest.json",
        "bytecode_proof": latest / "bytecode-release-proof.json",
    }


class ReleaseCandidateLockfileTests(unittest.TestCase):
    def test_build_lockfile_records_status_artifacts_and_signature_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_release_tree(root)

            lockfile = generator.build_lockfile(
                root,
                paths["output"],
                paths["release_manifest"],
                paths["bytecode_proof"],
                paths["latest"],
                paths["signatures"],
            )

            self.assertEqual(lockfile["schema_version"], generator.LOCKFILE_SCHEMA)
            self.assertEqual(lockfile["release"]["project"], "6529Stream")
            self.assertEqual(lockfile["release"]["public_beta"], "blocked")
            self.assertEqual(
                lockfile["release"]["requirement_counts"]["public_beta"],
                {"complete": 1, "missing": 1},
            )
            self.assertEqual(
                lockfile["release"]["blocking_requirement_ids"]["production_release"],
                ["signed_git_tag"],
            )
            self.assertEqual(
                lockfile["source_lock"]["status"],
                generator.NON_RELEASE_LOCK_STATUS,
            )
            self.assertEqual(
                lockfile["locked_inputs"]["release_manifest"]["sha256"],
                generator.file_sha256(paths["release_manifest"]),
            )
            self.assertEqual(
                lockfile["locked_inputs"]["bytecode_release_proof"]["sha256"],
                generator.file_sha256(paths["bytecode_proof"]),
            )
            self.assertEqual(
                lockfile["release_signature_evidence"][0]["signature_statuses"],
                {
                    "detached_checksum_signature": "not_available_local",
                    "signed_git_tag": "not_available_local",
                },
            )
            self.assertEqual(
                lockfile["checksum_bundle"]["outputs"][0]["sha256"],
                generator.SELF_REFERENTIAL_DIGEST_STATUS,
            )

    def test_check_mode_accepts_current_lockfile(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_release_tree(root)
            generator.write_output(
                root,
                paths["output"],
                paths["release_manifest"],
                paths["bytecode_proof"],
                paths["latest"],
                paths["signatures"],
            )

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = generator.check_output(
                    root,
                    paths["output"],
                    paths["release_manifest"],
                    paths["bytecode_proof"],
                    paths["latest"],
                    paths["signatures"],
                )
            self.assertEqual(result, 0)

    def test_check_mode_rejects_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_release_tree(root)
            generator.write_output(
                root,
                paths["output"],
                paths["release_manifest"],
                paths["bytecode_proof"],
                paths["latest"],
                paths["signatures"],
            )
            write_text(paths["latest"] / "release-notes.md", "# Release Notes\n\nChanged.\n")

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = generator.check_output(
                    root,
                    paths["output"],
                    paths["release_manifest"],
                    paths["bytecode_proof"],
                    paths["latest"],
                    paths["signatures"],
                )
            self.assertEqual(result, 1)
            self.assertIn(
                "changed release-artifacts/latest/release-candidate-lockfile.json",
                stderr.getvalue(),
            )

    def test_generator_rejects_missing_required_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_release_tree(root)
            (paths["latest"] / "risk-register.json").unlink()

            with self.assertRaisesRegex(
                generator.ReleaseCandidateLockfileError,
                "missing required file",
            ):
                generator.build_lockfile(
                    root,
                    paths["output"],
                    paths["release_manifest"],
                    paths["bytecode_proof"],
                    paths["latest"],
                    paths["signatures"],
                )

    def test_generator_rejects_invalid_release_signature_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_release_tree(root)
            evidence_path = paths["signatures"] / "anvil-local.json"
            evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
            evidence["source"]["git_commit"] = "not-a-commit"
            write_json(evidence_path, evidence)

            with self.assertRaisesRegex(
                generator.ReleaseCandidateLockfileError,
                "invalid release signature evidence",
            ):
                generator.build_lockfile(
                    root,
                    paths["output"],
                    paths["release_manifest"],
                    paths["bytecode_proof"],
                    paths["latest"],
                    paths["signatures"],
                )

    def test_committed_lockfile_is_non_release_and_tracks_checks(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        lockfile = json.loads(
            (repo_root / generator.DEFAULT_OUTPUT).read_text(encoding="utf-8")
        )

        self.assertEqual(lockfile["schema_version"], generator.LOCKFILE_SCHEMA)
        self.assertEqual(lockfile["source_lock"]["status"], generator.NON_RELEASE_LOCK_STATUS)
        self.assertIn(
            "python scripts/generate_release_candidate_lockfile.py --check",
            lockfile["validation"]["commands"],
        )
        self.assertEqual(
            lockfile["checksum_bundle"]["coverage_expectation"][
                "release_candidate_lockfile_path"
            ],
            "release-artifacts/latest/release-candidate-lockfile.json",
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
