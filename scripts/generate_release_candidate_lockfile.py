#!/usr/bin/env python3
"""Generate a deterministic release-candidate lockfile."""

from __future__ import annotations

import argparse
import filecmp
import hashlib
import json
import sys
import tempfile
from pathlib import Path
from typing import Any, Sequence

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import check_release_signatures as release_signature_checker


LOCKFILE_SCHEMA = "6529stream.release-candidate-lockfile.v1"
GENERATOR_VERSION = "1"
SELF_REFERENTIAL_DIGEST_STATUS = "not_available_self_referential"
NON_RELEASE_LOCK_STATUS = "not_locked_until_signed_release_tag"

DEFAULT_OUTPUT = Path("release-artifacts/latest/release-candidate-lockfile.json")
DEFAULT_RELEASE_MANIFEST = Path("release-artifacts/latest/release-manifest.json")
DEFAULT_BYTECODE_PROOF = Path("release-artifacts/latest/bytecode-release-proof.json")
DEFAULT_RELEASE_ARTIFACTS_DIR = Path("release-artifacts/latest")
DEFAULT_RELEASE_SIGNATURES_DIR = Path("release-artifacts/signatures")

RELEASE_MANIFEST_SCHEMA = "6529stream.release-manifest.v1"
BYTECODE_PROOF_SCHEMA = "6529stream.bytecode-release-proof.v1"
PUBLIC_BETA_EVIDENCE_SCHEMA = "6529stream.public-beta-evidence.v1"
RISK_REGISTER_SCHEMA = "6529stream.risk-register.v1"
RELEASE_NOTES_SCHEMA = "6529stream.release-notes.v1"
RELEASE_EVIDENCE_PACKET_INDEX_SCHEMA = "6529stream.release-evidence-packet-index.v1"

PUBLIC_BETA_EVIDENCE_FILENAME = "public-beta-evidence.json"
RISK_REGISTER_FILENAME = "risk-register.json"
RELEASE_NOTES_JSON_FILENAME = "release-notes.json"
RELEASE_NOTES_MARKDOWN_FILENAME = "release-notes.md"
PUBLIC_BETA_BLOCKERS_FILENAME = "public-beta-blockers.md"
PRODUCTION_RELEASE_BLOCKERS_FILENAME = "production-release-blockers.md"
RELEASE_EVIDENCE_PACKET_INDEX_JSON_FILENAME = "release-evidence-packet-index.json"
RELEASE_EVIDENCE_PACKET_INDEX_MARKDOWN_FILENAME = "release-evidence-packet-index.md"
RELEASE_EVIDENCE_ISSUE_BACKLOG_JSON_FILENAME = "release-evidence-issue-backlog.json"
RELEASE_EVIDENCE_ISSUE_BACKLOG_MARKDOWN_FILENAME = "release-evidence-issue-backlog.md"
RELEASE_EVIDENCE_ISSUE_BODY_SYNC_JSON_FILENAME = "release-evidence-issue-body-sync.json"
RELEASE_EVIDENCE_ISSUE_BODY_SYNC_MARKDOWN_FILENAME = "release-evidence-issue-body-sync.md"
CHECKSUM_FILE_NAME = "SHA256SUMS"
CHECKSUM_MANIFEST_NAME = "release-checksums.json"


class ReleaseCandidateLockfileError(RuntimeError):
    pass


def load_json(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise ReleaseCandidateLockfileError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ReleaseCandidateLockfileError(f"invalid JSON in {path}: {exc}") from exc
    except UnicodeDecodeError as exc:
        raise ReleaseCandidateLockfileError(f"invalid UTF-8 in {path}: {exc}") from exc
    except OSError as exc:
        raise ReleaseCandidateLockfileError(f"unable to read required file {path}: {exc}") from exc


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def normalize_path(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def file_sha256(path: Path) -> str:
    try:
        with path.open("rb") as handle:
            return sha256_bytes(handle.read())
    except FileNotFoundError as exc:
        raise ReleaseCandidateLockfileError(f"missing required file: {path}") from exc


def require_dict(value: Any, path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ReleaseCandidateLockfileError(f"{path} must be an object")
    return value


def require_list(value: Any, path: str) -> list[Any]:
    if not isinstance(value, list):
        raise ReleaseCandidateLockfileError(f"{path} must be an array")
    return value


def require_string(value: Any, path: str) -> str:
    if not isinstance(value, str) or value == "":
        raise ReleaseCandidateLockfileError(f"{path} must be a non-empty string")
    return value


def require_schema(value: Any, expected: str, path: str) -> dict[str, Any]:
    data = require_dict(value, path)
    schema = data.get("schema_version") or data.get("manifest_schema_version")
    if schema != expected:
        raise ReleaseCandidateLockfileError(f"{path} must use schema {expected}")
    return data


def json_schema_version(value: Any) -> str | None:
    if not isinstance(value, dict):
        return None
    schema = value.get("schema_version") or value.get("manifest_schema_version")
    if isinstance(schema, str) and schema:
        return schema
    return None


def file_record(path: Path, repo_root: Path, *, schema_required: bool = False) -> dict[str, Any]:
    if not path.is_file():
        raise ReleaseCandidateLockfileError(f"missing required file: {path}")
    record: dict[str, Any] = {
        "path": normalize_path(path, repo_root),
        "sha256": file_sha256(path),
        "size_bytes": path.stat().st_size,
    }
    if path.suffix == ".json":
        schema = json_schema_version(load_json(path))
        if schema_required and schema is None:
            raise ReleaseCandidateLockfileError(f"{path} is missing a schema version")
        if schema is not None:
            record["schema_version"] = schema
    return record


def self_referential_output(path: Path, repo_root: Path, *, format_name: str) -> dict[str, Any]:
    return {
        "path": normalize_path(path, repo_root),
        "format": format_name,
        "sha256": SELF_REFERENTIAL_DIGEST_STATUS,
        "digest_status": SELF_REFERENTIAL_DIGEST_STATUS,
        "reason": (
            "The checksum bundle covers release-candidate-lockfile.json. "
            "Embedding the checksum bundle digest in the lockfile would create "
            "a self-referential hash cycle."
        ),
    }


def requirement_counts(requirements: Sequence[Any]) -> dict[str, dict[str, int]]:
    counts: dict[str, dict[str, int]] = {}
    for raw_requirement in requirements:
        requirement = require_dict(raw_requirement, "requirements[]")
        phase = require_string(requirement.get("phase"), "requirements[].phase")
        status = require_string(requirement.get("status"), "requirements[].status")
        phase_counts = counts.setdefault(phase, {})
        phase_counts[status] = phase_counts.get(status, 0) + 1
    return {phase: dict(sorted(values.items())) for phase, values in sorted(counts.items())}


def blocker_ids(requirements: Sequence[Any]) -> dict[str, list[str]]:
    blockers: dict[str, list[str]] = {}
    for raw_requirement in requirements:
        requirement = require_dict(raw_requirement, "requirements[]")
        phase = require_string(requirement.get("phase"), "requirements[].phase")
        status = require_string(requirement.get("status"), "requirements[].status")
        if status in {"complete", "accepted_risk"}:
            continue
        requirement_id = require_string(requirement.get("id"), "requirements[].id")
        blockers.setdefault(phase, []).append(requirement_id)
    return {phase: sorted(values) for phase, values in sorted(blockers.items())}


def release_signature_records(directory: Path, repo_root: Path) -> list[dict[str, Any]]:
    if not directory.is_dir():
        raise ReleaseCandidateLockfileError(f"missing required directory: {directory}")
    paths = sorted(path for path in directory.glob("*.json") if path.is_file())
    if not paths:
        raise ReleaseCandidateLockfileError(
            f"required directory has no release signature evidence: {directory}"
        )

    records: list[dict[str, Any]] = []
    for path in paths:
        try:
            release_signature_checker.validate_evidence(path, repo_root)
        except release_signature_checker.ReleaseSignatureEvidenceError as exc:
            raise ReleaseCandidateLockfileError(
                f"invalid release signature evidence {path}: {exc}"
            ) from exc

        evidence = require_schema(
            load_json(path),
            release_signature_checker.EVIDENCE_SCHEMA,
            str(path),
        )
        network = require_dict(evidence.get("network"), f"{path}.network")
        source = require_dict(evidence.get("source"), f"{path}.source")
        signing_identity = require_dict(
            evidence.get("signing_identity"),
            f"{path}.signing_identity",
        )
        signatures = require_dict(evidence.get("signatures"), f"{path}.signatures")
        retained_artifacts = require_list(
            evidence.get("retained_artifacts"),
            f"{path}.retained_artifacts",
        )
        record = file_record(path, repo_root, schema_required=True)
        record.update(
            {
                "evidence_id": require_string(evidence.get("evidence_id"), "evidence_id"),
                "release_version": require_string(
                    evidence.get("release_version"),
                    "release_version",
                ),
                "environment": require_string(
                    network.get("environment"),
                    "network.environment",
                ),
                "chain_id": network.get("chain_id"),
                "source": {
                    "git_commit": require_string(source.get("git_commit"), "source.git_commit"),
                    "source_dirty": source.get("source_dirty"),
                    "ci_run": require_string(source.get("ci_run"), "source.ci_run"),
                },
                "signing_identity_status": require_string(
                    signing_identity.get("status"),
                    "signing_identity.status",
                ),
                "signature_statuses": {
                    key: require_string(
                        require_dict(value, f"signatures.{key}").get("status"),
                        f"signatures.{key}.status",
                    )
                    for key, value in sorted(signatures.items())
                },
                "retained_artifact_categories": sorted(
                    require_string(
                        require_dict(item, "retained_artifacts[]").get("category"),
                        "retained_artifacts[].category",
                    )
                    for item in retained_artifacts
                ),
            }
        )
        records.append(record)
    return records


def build_lockfile(
    repo_root: Path,
    output_path: Path,
    release_manifest_path: Path,
    bytecode_proof_path: Path,
    release_artifacts_dir: Path,
    release_signatures_dir: Path,
) -> dict[str, Any]:
    release_manifest = require_schema(
        load_json(release_manifest_path),
        RELEASE_MANIFEST_SCHEMA,
        str(release_manifest_path),
    )
    bytecode_proof = require_schema(
        load_json(bytecode_proof_path),
        BYTECODE_PROOF_SCHEMA,
        str(bytecode_proof_path),
    )
    public_beta_evidence_path = release_artifacts_dir / PUBLIC_BETA_EVIDENCE_FILENAME
    public_beta_evidence = require_schema(
        load_json(public_beta_evidence_path),
        PUBLIC_BETA_EVIDENCE_SCHEMA,
        str(public_beta_evidence_path),
    )
    risk_register_path = release_artifacts_dir / RISK_REGISTER_FILENAME
    risk_register = require_schema(
        load_json(risk_register_path),
        RISK_REGISTER_SCHEMA,
        str(risk_register_path),
    )
    release_notes_json_path = release_artifacts_dir / RELEASE_NOTES_JSON_FILENAME
    require_schema(
        load_json(release_notes_json_path),
        RELEASE_NOTES_SCHEMA,
        str(release_notes_json_path),
    )
    packet_index_json_path = release_artifacts_dir / RELEASE_EVIDENCE_PACKET_INDEX_JSON_FILENAME
    require_schema(
        load_json(packet_index_json_path),
        RELEASE_EVIDENCE_PACKET_INDEX_SCHEMA,
        str(packet_index_json_path),
    )

    release = require_dict(release_manifest.get("release"), "release_manifest.release")
    source = require_dict(public_beta_evidence.get("source"), "public_beta_evidence.source")
    status = require_dict(public_beta_evidence.get("status"), "public_beta_evidence.status")
    requirements = require_list(
        public_beta_evidence.get("requirements"),
        "public_beta_evidence.requirements",
    )
    risks = require_list(risk_register.get("risks"), "risk_register.risks")

    return {
        "schema_version": LOCKFILE_SCHEMA,
        "generated_by": f"scripts/generate_release_candidate_lockfile.py:{GENERATOR_VERSION}",
        "release": {
            "project": require_string(release.get("project"), "release.project"),
            "version": require_string(
                public_beta_evidence.get("release_version"),
                "public_beta_evidence.release_version",
            ),
            "status": require_string(release.get("status"), "release.status"),
            "public_beta": require_string(status.get("public_beta"), "status.public_beta"),
            "production_release": require_string(
                status.get("production_release"),
                "status.production_release",
            ),
            "requirement_counts": requirement_counts(requirements),
            "blocking_requirement_ids": blocker_ids(requirements),
            "risk_count": len(risks),
        },
        "source_lock": {
            "mode": "pre_audit_local_baseline",
            "status": NON_RELEASE_LOCK_STATUS,
            "repository": require_string(source.get("repository"), "source.repository"),
            "git_commit": require_string(source.get("git_commit"), "source.git_commit"),
            "source_dirty": source.get("source_dirty"),
            "ci_run": require_string(source.get("ci_run"), "source.ci_run"),
            "reason": (
                "This committed local baseline is deterministic across future commits. "
                "A public release candidate must replace this with a signed tag, "
                "release commit, CI run, and production signature evidence."
            ),
        },
        "locked_inputs": {
            "release_manifest": file_record(
                release_manifest_path,
                repo_root,
                schema_required=True,
            ),
            "bytecode_release_proof": file_record(
                bytecode_proof_path,
                repo_root,
                schema_required=True,
            ),
            "public_beta_evidence": file_record(
                public_beta_evidence_path,
                repo_root,
                schema_required=True,
            ),
            "risk_register": file_record(
                risk_register_path,
                repo_root,
                schema_required=True,
            ),
            "release_notes": {
                "json": file_record(
                    release_notes_json_path,
                    repo_root,
                    schema_required=True,
                ),
                "markdown": file_record(
                    release_artifacts_dir / RELEASE_NOTES_MARKDOWN_FILENAME,
                    repo_root,
                ),
            },
            "blocker_reports": {
                "public_beta": file_record(
                    release_artifacts_dir / PUBLIC_BETA_BLOCKERS_FILENAME,
                    repo_root,
                ),
                "production_release": file_record(
                    release_artifacts_dir / PRODUCTION_RELEASE_BLOCKERS_FILENAME,
                    repo_root,
                ),
            },
            "release_evidence_packet_index": {
                "json": file_record(
                    packet_index_json_path,
                    repo_root,
                    schema_required=True,
                ),
                "markdown": file_record(
                    release_artifacts_dir / RELEASE_EVIDENCE_PACKET_INDEX_MARKDOWN_FILENAME,
                    repo_root,
                ),
            },
            "release_evidence_issue_backlog": {
                "json": file_record(
                    release_artifacts_dir / RELEASE_EVIDENCE_ISSUE_BACKLOG_JSON_FILENAME,
                    repo_root,
                    schema_required=True,
                ),
                "markdown": file_record(
                    release_artifacts_dir / RELEASE_EVIDENCE_ISSUE_BACKLOG_MARKDOWN_FILENAME,
                    repo_root,
                ),
            },
            "release_evidence_issue_body_sync": {
                "json": file_record(
                    release_artifacts_dir / RELEASE_EVIDENCE_ISSUE_BODY_SYNC_JSON_FILENAME,
                    repo_root,
                    schema_required=True,
                ),
                "markdown": file_record(
                    release_artifacts_dir / RELEASE_EVIDENCE_ISSUE_BODY_SYNC_MARKDOWN_FILENAME,
                    repo_root,
                ),
            },
        },
        "release_signature_evidence": release_signature_records(
            release_signatures_dir,
            repo_root,
        ),
        "checksum_bundle": {
            "status": "generated_after_release_candidate_lockfile",
            "coverage_expectation": {
                "release_candidate_lockfile_path": normalize_path(output_path, repo_root),
                "covered_by_checksum_bundle": True,
            },
            "outputs": [
                self_referential_output(
                    release_artifacts_dir / CHECKSUM_FILE_NAME,
                    repo_root,
                    format_name="sha256sum",
                ),
                self_referential_output(
                    release_artifacts_dir / CHECKSUM_MANIFEST_NAME,
                    repo_root,
                    format_name="json",
                ),
            ],
        },
        "signed_tag_gate": {
            "status": NON_RELEASE_LOCK_STATUS,
            "release_mode_command": (
                "python scripts/check_signed_release_tag.py --mode release "
                "--tag vX.Y.Z --evidence path/to/post-bundle-release-signature-evidence.json"
            ),
        },
        "validation": {
            "commands": [
                "python scripts/test_release_candidate_lockfile.py",
                "python scripts/generate_release_candidate_lockfile.py --check",
                "python scripts/test_release_manifest.py",
                "python scripts/generate_release_manifest.py --check",
                "python scripts/test_bytecode_release_proof.py",
                "python scripts/generate_bytecode_release_proof.py --check",
                "python scripts/test_release_checksums.py",
                "python scripts/generate_release_checksums.py --check",
                "python scripts/test_verify_release_artifacts.py",
                "python scripts/verify_release_artifacts.py",
                "python scripts/check_release_signatures.py",
                "python scripts/check_signed_release_tag.py",
            ],
        },
        "limitations": [
            "This local baseline is not launch approval.",
            "Public beta remains blocked until public-beta evidence rows are complete or accepted-risk.",
            "Production remains blocked until production signatures, signed tag, live deployment evidence, and production broadcast retention are complete.",
        ],
    }


def build_output_text(
    repo_root: Path,
    output_path: Path,
    release_manifest_path: Path,
    bytecode_proof_path: Path,
    release_artifacts_dir: Path,
    release_signatures_dir: Path,
) -> str:
    lockfile = build_lockfile(
        repo_root,
        output_path,
        release_manifest_path,
        bytecode_proof_path,
        release_artifacts_dir,
        release_signatures_dir,
    )
    return json.dumps(lockfile, indent=2, ensure_ascii=False) + "\n"


def write_output(
    repo_root: Path,
    output_path: Path,
    release_manifest_path: Path,
    bytecode_proof_path: Path,
    release_artifacts_dir: Path,
    release_signatures_dir: Path,
) -> Path:
    output_text = build_output_text(
        repo_root,
        output_path,
        release_manifest_path,
        bytecode_proof_path,
        release_artifacts_dir,
        release_signatures_dir,
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(output_text, encoding="utf-8", newline="\n")
    return output_path


def check_output(
    repo_root: Path,
    output_path: Path,
    release_manifest_path: Path,
    bytecode_proof_path: Path,
    release_artifacts_dir: Path,
    release_signatures_dir: Path,
) -> int:
    if not output_path.exists():
        print(f"missing {normalize_path(output_path, repo_root)}", file=sys.stderr)
        print(
            "run `python scripts/generate_release_candidate_lockfile.py` "
            "and commit the regenerated file",
            file=sys.stderr,
        )
        return 1

    expected_text = build_output_text(
        repo_root,
        output_path,
        release_manifest_path,
        bytecode_proof_path,
        release_artifacts_dir,
        release_signatures_dir,
    )

    with tempfile.TemporaryDirectory() as temp_dir:
        expected = Path(temp_dir) / output_path.name
        expected.write_text(expected_text, encoding="utf-8", newline="\n")
        if not filecmp.cmp(expected, output_path, shallow=False):
            print(
                f"changed {normalize_path(output_path, repo_root)}",
                file=sys.stderr,
            )
            print(
                "run `python scripts/generate_release_candidate_lockfile.py` "
                "and commit the regenerated file",
                file=sys.stderr,
            )
            return 1

    print("release candidate lockfile is current")
    return 0


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--release-manifest", type=Path, default=DEFAULT_RELEASE_MANIFEST)
    parser.add_argument("--bytecode-proof", type=Path, default=DEFAULT_BYTECODE_PROOF)
    parser.add_argument("--release-artifacts-dir", type=Path, default=DEFAULT_RELEASE_ARTIFACTS_DIR)
    parser.add_argument("--release-signatures-dir", type=Path, default=DEFAULT_RELEASE_SIGNATURES_DIR)
    parser.add_argument("--check", action="store_true")
    return parser.parse_args(list(argv))


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    repo_root = Path.cwd()

    try:
        if args.check:
            return check_output(
                repo_root,
                args.output,
                args.release_manifest,
                args.bytecode_proof,
                args.release_artifacts_dir,
                args.release_signatures_dir,
            )
        written = write_output(
            repo_root,
            args.output,
            args.release_manifest,
            args.bytecode_proof,
            args.release_artifacts_dir,
            args.release_signatures_dir,
        )
    except ReleaseCandidateLockfileError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(normalize_path(written, repo_root))
    return 0


if __name__ == "__main__":
    sys.exit(main())
