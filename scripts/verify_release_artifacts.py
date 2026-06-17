#!/usr/bin/env python3
"""Verify committed release artifacts without regenerating them.

This is the consumer-facing offline verifier for a checked-out release bundle.
It validates the signable checksum file, checksum manifest, top-level release
manifest, and bytecode release proof agree with the files on disk.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any, Iterable, NamedTuple, Sequence


SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
SHA256_PREFIX_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
CHECKSUM_SCHEMA = "6529stream.release-checksums.v1"
RELEASE_MANIFEST_SCHEMA = "6529stream.release-manifest.v1"
BYTECODE_PROOF_SCHEMA = "6529stream.bytecode-release-proof.v1"
RELEASE_CANDIDATE_LOCKFILE_SCHEMA = "6529stream.release-candidate-lockfile.v1"

DEFAULT_RELEASE_DIR = Path("release-artifacts/latest")
CHECKSUM_FILE_NAME = "SHA256SUMS"
CHECKSUM_MANIFEST_NAME = "release-checksums.json"
RELEASE_MANIFEST_NAME = "release-manifest.json"
BYTECODE_PROOF_NAME = "bytecode-release-proof.json"
RELEASE_CANDIDATE_LOCKFILE_NAME = "release-candidate-lockfile.json"
SELF_REFERENTIAL_SHA256_MARKERS = {"not_available_self_referential"}


class ReleaseArtifactVerificationError(RuntimeError):
    pass


class VerificationSummary(NamedTuple):
    checksum_entries: int
    checksum_manifest_records: int
    release_manifest_records: int
    bytecode_proof_records: int
    release_candidate_lockfile_records: int


def normalize_path(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def resolve_release_file(repo_root: Path, relative_path: str, field: str) -> Path:
    if "\\" in relative_path:
        raise ReleaseArtifactVerificationError(f"{field} must use forward slashes")
    candidate = Path(relative_path)
    if candidate.is_absolute() or ".." in candidate.parts:
        raise ReleaseArtifactVerificationError(f"{field} must stay inside the repository")
    resolved = (repo_root / candidate).resolve()
    try:
        resolved.relative_to(repo_root.resolve())
    except ValueError as exc:
        raise ReleaseArtifactVerificationError(
            f"{field} must stay inside the repository"
        ) from exc
    return resolved


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def file_sha256(path: Path) -> str:
    try:
        return sha256_bytes(path.read_bytes())
    except FileNotFoundError as exc:
        raise ReleaseArtifactVerificationError(f"missing required file: {path}") from exc


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ReleaseArtifactVerificationError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ReleaseArtifactVerificationError(f"invalid JSON in {path}: {exc}") from exc


def require_dict(value: Any, field: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ReleaseArtifactVerificationError(f"{field} must be an object")
    return value


def require_string(value: Any, field: str) -> str:
    if not isinstance(value, str) or value == "":
        raise ReleaseArtifactVerificationError(f"{field} must be a non-empty string")
    return value


def require_schema(data: Any, expected: str, field: str) -> dict[str, Any]:
    document = require_dict(data, field)
    schema = document.get("schema_version") or document.get("manifest_schema_version")
    if schema != expected:
        raise ReleaseArtifactVerificationError(f"{field} must use schema {expected}")
    return document


def parse_checksum_file(checksum_text: str) -> list[tuple[str, str]]:
    entries: list[tuple[str, str]] = []
    seen_paths: set[str] = set()
    for line_number, line in enumerate(checksum_text.splitlines(), start=1):
        if not line:
            continue
        if "  " not in line:
            raise ReleaseArtifactVerificationError(
                f"malformed checksum line {line_number}: missing separator"
            )
        digest, relative_path = line.split("  ", 1)
        if not SHA256_RE.fullmatch(digest):
            raise ReleaseArtifactVerificationError(
                f"malformed checksum line {line_number}: invalid sha256"
            )
        if relative_path.startswith("/") or "\\" in relative_path:
            raise ReleaseArtifactVerificationError(
                f"malformed checksum line {line_number}: invalid path"
            )
        if ".." in Path(relative_path).parts:
            raise ReleaseArtifactVerificationError(
                f"malformed checksum line {line_number}: path traversal"
            )
        if relative_path in seen_paths:
            raise ReleaseArtifactVerificationError(
                f"malformed checksum line {line_number}: duplicate path {relative_path}"
            )
        seen_paths.add(relative_path)
        entries.append((digest, relative_path))
    if not entries:
        raise ReleaseArtifactVerificationError("checksum file contains no entries")
    return entries


def verify_file_record(
    repo_root: Path,
    *,
    path: str,
    sha256: str,
    size_bytes: int | None,
    source: str,
) -> None:
    if not SHA256_PREFIX_RE.fullmatch(sha256):
        raise ReleaseArtifactVerificationError(f"{source} has invalid sha256 for {path}")
    resolved = resolve_release_file(repo_root, path, f"{source}.path")
    if not resolved.is_file():
        raise ReleaseArtifactVerificationError(f"{source} references missing file: {path}")
    actual = file_sha256(resolved)
    if actual != sha256:
        raise ReleaseArtifactVerificationError(
            f"{source} hash mismatch for {path}: expected {sha256}, got {actual}"
        )
    if size_bytes is not None and resolved.stat().st_size != size_bytes:
        raise ReleaseArtifactVerificationError(
            f"{source} size mismatch for {path}: expected {size_bytes}, "
            f"got {resolved.stat().st_size}"
        )


def verify_checksum_file(
    repo_root: Path,
    checksum_path: Path,
) -> dict[str, str]:
    # SHA256SUMS is LF-pinned by the release policy; the byte-level digest check
    # below still fails if a checkout rewrites it with CRLF line endings.
    checksum_text = checksum_path.read_text(encoding="utf-8")
    entries = parse_checksum_file(checksum_text)
    digests: dict[str, str] = {}
    for digest, relative_path in entries:
        resolved = resolve_release_file(
            repo_root,
            relative_path,
            f"{CHECKSUM_FILE_NAME}.{relative_path}",
        )
        if not resolved.is_file():
            raise ReleaseArtifactVerificationError(
                f"{CHECKSUM_FILE_NAME} references missing file: {relative_path}"
            )
        actual = file_sha256(resolved).removeprefix("sha256:")
        if actual != digest:
            raise ReleaseArtifactVerificationError(
                f"{CHECKSUM_FILE_NAME} hash mismatch for {relative_path}: "
                f"expected {digest}, got {actual}"
            )
        digests[relative_path] = digest
    return digests


def verify_checksum_manifest(
    repo_root: Path,
    checksum_manifest_path: Path,
    checksum_path: Path,
    checksum_entries: dict[str, str],
) -> int:
    data = require_schema(
        load_json(checksum_manifest_path),
        CHECKSUM_SCHEMA,
        CHECKSUM_MANIFEST_NAME,
    )
    if data.get("algorithm") != "sha256":
        raise ReleaseArtifactVerificationError("release checksum manifest must use sha256")

    checksum_record = require_dict(
        data.get("text_checksum_file"),
        "release-checksums.text_checksum_file",
    )
    checksum_record_path = require_string(
        checksum_record.get("path"),
        "release-checksums.text_checksum_file.path",
    )
    if normalize_path(checksum_path, repo_root) != checksum_record_path:
        raise ReleaseArtifactVerificationError("release checksum manifest SHA256SUMS path mismatch")
    if checksum_record.get("sha256") != file_sha256(checksum_path):
        raise ReleaseArtifactVerificationError("release checksum manifest SHA256SUMS hash mismatch")

    manifest_record = require_dict(
        data.get("manifest_file"),
        "release-checksums.manifest_file",
    )
    if manifest_record.get("path") != normalize_path(checksum_manifest_path, repo_root):
        raise ReleaseArtifactVerificationError(
            "release checksum manifest self path mismatch"
        )
    if manifest_record.get("self_hash") is not False:
        raise ReleaseArtifactVerificationError(
            "release checksum manifest self_hash must be false"
        )

    files = data.get("files")
    if not isinstance(files, list) or not files:
        raise ReleaseArtifactVerificationError("release checksum manifest files must be non-empty")

    manifest_entries: dict[str, dict[str, Any]] = {}
    for index, raw_entry in enumerate(files):
        entry = require_dict(raw_entry, f"release-checksums.files[{index}]")
        path = require_string(entry.get("path"), f"release-checksums.files[{index}].path")
        sha256 = require_string(entry.get("sha256"), f"release-checksums.files[{index}].sha256")
        size = entry.get("size_bytes")
        if not isinstance(size, int) or isinstance(size, bool):
            raise ReleaseArtifactVerificationError(
                f"release-checksums.files[{index}].size_bytes must be an integer"
            )
        if path in manifest_entries:
            raise ReleaseArtifactVerificationError(
                f"release checksum manifest has duplicate path {path}"
            )
        manifest_entries[path] = entry
        verify_file_record(
            repo_root,
            path=path,
            sha256=sha256,
            size_bytes=size,
            source="release-checksums",
        )

    if set(manifest_entries) != set(checksum_entries):
        missing = sorted(set(checksum_entries) - set(manifest_entries))
        extra = sorted(set(manifest_entries) - set(checksum_entries))
        detail = []
        if missing:
            detail.append(f"missing manifest records: {', '.join(missing[:5])}")
        if extra:
            detail.append(f"extra manifest records: {', '.join(extra[:5])}")
        raise ReleaseArtifactVerificationError(
            "release checksum manifest does not match SHA256SUMS"
            + (f" ({'; '.join(detail)})" if detail else "")
        )

    for path, digest in checksum_entries.items():
        if manifest_entries[path]["sha256"] != f"sha256:{digest}":
            raise ReleaseArtifactVerificationError(
                f"release checksum manifest hash mismatch for {path}"
            )
    return len(manifest_entries)


def iter_file_records(value: Any, source: str) -> Iterable[tuple[str, str, int | None, str]]:
    if isinstance(value, dict):
        path = value.get("path")
        sha256 = value.get("sha256")
        size_bytes = value.get("size_bytes")
        if isinstance(path, str) and "sha256" in value:
            if not isinstance(sha256, str):
                raise ReleaseArtifactVerificationError(f"{source}.sha256 must be a string")
            if not SHA256_PREFIX_RE.fullmatch(sha256):
                if sha256 not in SELF_REFERENTIAL_SHA256_MARKERS:
                    raise ReleaseArtifactVerificationError(
                        f"{source}.sha256 has invalid sha256 marker for {path}"
                    )
            elif isinstance(size_bytes, int) and not isinstance(size_bytes, bool):
                yield path, sha256, size_bytes, source
        for key, child in value.items():
            yield from iter_file_records(child, f"{source}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from iter_file_records(child, f"{source}[{index}]")


def verify_nested_file_records(repo_root: Path, document: Any, source: str) -> int:
    count = 0
    for path, sha256, size_bytes, field in iter_file_records(document, source):
        verify_file_record(
            repo_root,
            path=path,
            sha256=sha256,
            size_bytes=size_bytes,
            source=field,
        )
        count += 1
    return count


def require_checksum_covered(checksum_entries: dict[str, str], required_paths: Sequence[str]) -> None:
    missing = [path for path in required_paths if path not in checksum_entries]
    if missing:
        raise ReleaseArtifactVerificationError(
            f"required files are not checksum-covered: {', '.join(missing)}"
        )


def verify_bytecode_proof_release_manifest_binding(
    repo_root: Path,
    bytecode_proof: dict[str, Any],
    release_manifest_path: Path,
) -> None:
    source = require_dict(bytecode_proof.get("source"), "bytecode-release-proof.source")
    release_manifest = require_dict(
        source.get("release_manifest"),
        "bytecode-release-proof.source.release_manifest",
    )
    path = require_string(
        release_manifest.get("path"),
        "bytecode-release-proof.source.release_manifest.path",
    )
    if path != normalize_path(release_manifest_path, repo_root):
        raise ReleaseArtifactVerificationError(
            "bytecode release proof release_manifest path mismatch"
        )
    sha256 = require_string(
        release_manifest.get("sha256"),
        "bytecode-release-proof.source.release_manifest.sha256",
    )
    if sha256 != file_sha256(release_manifest_path):
        raise ReleaseArtifactVerificationError(
            "bytecode release proof release_manifest hash mismatch"
        )


def verify_release_artifacts(
    repo_root: Path,
    release_dir: Path = DEFAULT_RELEASE_DIR,
) -> VerificationSummary:
    repo_root = repo_root.resolve()
    resolved_release_dir = release_dir if release_dir.is_absolute() else repo_root / release_dir
    checksum_path = resolved_release_dir / CHECKSUM_FILE_NAME
    checksum_manifest_path = resolved_release_dir / CHECKSUM_MANIFEST_NAME
    release_manifest_path = resolved_release_dir / RELEASE_MANIFEST_NAME
    bytecode_proof_path = resolved_release_dir / BYTECODE_PROOF_NAME
    release_candidate_lockfile_path = resolved_release_dir / RELEASE_CANDIDATE_LOCKFILE_NAME

    checksum_entries = verify_checksum_file(repo_root, checksum_path)
    required_paths = [
        normalize_path(release_manifest_path, repo_root),
        normalize_path(bytecode_proof_path, repo_root),
        normalize_path(release_candidate_lockfile_path, repo_root),
    ]
    require_checksum_covered(checksum_entries, required_paths)
    checksum_manifest_records = verify_checksum_manifest(
        repo_root,
        checksum_manifest_path,
        checksum_path,
        checksum_entries,
    )

    release_manifest = require_schema(
        load_json(release_manifest_path),
        RELEASE_MANIFEST_SCHEMA,
        RELEASE_MANIFEST_NAME,
    )
    bytecode_proof = require_schema(
        load_json(bytecode_proof_path),
        BYTECODE_PROOF_SCHEMA,
        BYTECODE_PROOF_NAME,
    )
    release_candidate_lockfile = require_schema(
        load_json(release_candidate_lockfile_path),
        RELEASE_CANDIDATE_LOCKFILE_SCHEMA,
        RELEASE_CANDIDATE_LOCKFILE_NAME,
    )

    release_manifest_records = verify_nested_file_records(
        repo_root,
        release_manifest,
        RELEASE_MANIFEST_NAME,
    )
    bytecode_proof_records = verify_nested_file_records(
        repo_root,
        bytecode_proof,
        BYTECODE_PROOF_NAME,
    )
    release_candidate_lockfile_records = verify_nested_file_records(
        repo_root,
        release_candidate_lockfile,
        RELEASE_CANDIDATE_LOCKFILE_NAME,
    )
    verify_bytecode_proof_release_manifest_binding(
        repo_root,
        bytecode_proof,
        release_manifest_path,
    )

    return VerificationSummary(
        checksum_entries=len(checksum_entries),
        checksum_manifest_records=checksum_manifest_records,
        release_manifest_records=release_manifest_records,
        bytecode_proof_records=bytecode_proof_records,
        release_candidate_lockfile_records=release_candidate_lockfile_records,
    )


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--release-dir", type=Path, default=DEFAULT_RELEASE_DIR)
    parser.add_argument("--json", action="store_true", help="emit machine-readable summary")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    try:
        summary = verify_release_artifacts(args.repo_root, args.release_dir)
    except ReleaseArtifactVerificationError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps(summary._asdict(), indent=2, ensure_ascii=False))
    else:
        print(
            "release artifact verification passed: "
            f"{summary.checksum_entries} checksum entries, "
            f"{summary.checksum_manifest_records} checksum manifest records, "
            f"{summary.release_manifest_records} release manifest file records, "
            f"{summary.bytecode_proof_records} bytecode proof file records, "
            f"{summary.release_candidate_lockfile_records} "
            "release candidate lockfile file records"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
