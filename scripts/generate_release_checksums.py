#!/usr/bin/env python3
"""Generate deterministic checksums for release and deployment artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


CHECKSUM_SCHEMA = "6529stream.release-checksums.v1"
GENERATOR_VERSION = "1"

DEFAULT_COVERED_PATHS = [
    Path("release-artifacts/contracts.json"),
    Path("release-artifacts/dependencies"),
    Path("release-artifacts/schema"),
    Path("release-artifacts/evidence"),
    Path("release-artifacts/drop-authorization-signing"),
    Path("release-artifacts/signer-custody-readiness"),
    Path("release-artifacts/permanence"),
    Path("release-artifacts/provenance"),
    Path("release-artifacts/signatures"),
    Path("release-artifacts/latest"),
    Path("release-artifacts/baselines"),
    Path("scripts/generate_dependency_provenance_attestation.py"),
    Path("scripts/check_release_mode.py"),
    Path("scripts/check_production_broadcast_retention.py"),
    Path("scripts/check_production_verified_addresses.py"),
    Path("scripts/generate_release_notes.py"),
    Path("scripts/verify_release_artifacts.py"),
    Path("deployments/broadcasts"),
    Path("deployments/config"),
    Path("deployments/examples"),
    Path("deployments/address-books"),
    Path("deployments/schema"),
    Path("deployments/ceremony-evidence"),
    Path("deployments/admin-ceremony"),
    Path("deployments/randomizer-operations"),
    Path("test/fixtures/drop-authorization"),
]
DEFAULT_OUTPUT_DIR = Path("release-artifacts/latest")
CHECKSUM_FILE_NAME = "SHA256SUMS"
CHECKSUM_MANIFEST_NAME = "release-checksums.json"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


class ChecksumError(RuntimeError):
    pass


def normalize_path(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def file_sha256(path: Path) -> str:
    with path.open("rb") as handle:
        return sha256_bytes(handle.read())


def read_text(path: Path) -> str:
    with path.open("r", encoding="utf-8") as handle:
        return handle.read()


def json_text(value: Any) -> str:
    return json.dumps(value, indent=2, ensure_ascii=False) + "\n"


def resolve_repo_path(repo_root: Path, path: Path) -> Path:
    if path.is_absolute():
        return path
    return repo_root / path


def output_paths(output_dir: Path) -> set[Path]:
    return {
        (output_dir / CHECKSUM_FILE_NAME).resolve(),
        (output_dir / CHECKSUM_MANIFEST_NAME).resolve(),
    }


def collect_files(repo_root: Path, covered_paths: list[Path], output_dir: Path) -> list[Path]:
    excluded = output_paths(output_dir)
    files_by_relative_path: dict[str, Path] = {}

    for configured_path in covered_paths:
        root = resolve_repo_path(repo_root, configured_path)
        if not root.exists():
            raise ChecksumError(f"covered path does not exist: {configured_path}")

        if root.is_file():
            candidates = [root]
        elif root.is_dir():
            candidates = sorted(path for path in root.rglob("*") if path.is_file())
        else:
            raise ChecksumError(f"covered path is neither a file nor directory: {configured_path}")

        for candidate in candidates:
            if candidate.resolve() in excluded:
                continue
            relative_path = normalize_path(candidate, repo_root)
            if relative_path in files_by_relative_path:
                raise ChecksumError(f"covered path listed more than once: {relative_path}")
            files_by_relative_path[relative_path] = candidate

    if not files_by_relative_path:
        raise ChecksumError("covered paths did not contain any files")

    return [files_by_relative_path[key] for key in sorted(files_by_relative_path)]


def build_checksum_lines(files: list[Path], repo_root: Path) -> list[str]:
    lines = []
    for path in files:
        digest = file_sha256(path).removeprefix("sha256:")
        lines.append(f"{digest}  {normalize_path(path, repo_root)}")
    return lines


def build_manifest(
    repo_root: Path,
    covered_paths: list[Path],
    output_dir: Path,
    files: list[Path],
    checksum_text: str,
) -> dict[str, Any]:
    output_dir_relative = normalize_path(output_dir, repo_root)
    checksum_path = output_dir / CHECKSUM_FILE_NAME
    manifest_path = output_dir / CHECKSUM_MANIFEST_NAME

    return {
        "schema_version": CHECKSUM_SCHEMA,
        "generated_by": f"scripts/generate_release_checksums.py:{GENERATOR_VERSION}",
        "algorithm": "sha256",
        "source": {
            "covered_paths": [
                normalize_path(resolve_repo_path(repo_root, path), repo_root)
                for path in covered_paths
            ],
            "output_dir": output_dir_relative,
        },
        "text_checksum_file": {
            "path": normalize_path(checksum_path, repo_root),
            "format": "sha256sum",
            "sha256": sha256_bytes(checksum_text.encode("utf-8")),
        },
        "manifest_file": {
            "path": normalize_path(manifest_path, repo_root),
            "self_hash": False,
        },
        "files": [
            {
                "path": normalize_path(path, repo_root),
                "sha256": file_sha256(path),
                "size_bytes": path.stat().st_size,
            }
            for path in files
        ],
    }


def build_outputs(
    repo_root: Path,
    covered_paths: list[Path],
    output_dir: Path,
) -> tuple[str, str]:
    files = collect_files(repo_root, covered_paths, output_dir)
    checksum_text = "\n".join(build_checksum_lines(files, repo_root)) + "\n"
    manifest = build_manifest(repo_root, covered_paths, output_dir, files, checksum_text)
    return checksum_text, json_text(manifest)


def write_outputs(repo_root: Path, covered_paths: list[Path], output_dir: Path) -> list[Path]:
    checksum_text, manifest_text = build_outputs(repo_root, covered_paths, output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    checksum_path = output_dir / CHECKSUM_FILE_NAME
    manifest_path = output_dir / CHECKSUM_MANIFEST_NAME
    checksum_path.write_text(checksum_text, encoding="utf-8", newline="\n")
    manifest_path.write_text(manifest_text, encoding="utf-8", newline="\n")
    return [checksum_path, manifest_path]


def parse_checksum_file(checksum_text: str) -> list[tuple[str, str]]:
    entries = []
    for line_number, line in enumerate(checksum_text.splitlines(), start=1):
        if not line:
            continue
        if "  " not in line:
            raise ChecksumError(f"malformed checksum line {line_number}: missing separator")
        digest, relative_path = line.split("  ", 1)
        if not SHA256_RE.fullmatch(digest):
            raise ChecksumError(f"malformed checksum line {line_number}: invalid sha256")
        if relative_path.startswith("/") or "\\" in relative_path:
            raise ChecksumError(f"malformed checksum line {line_number}: invalid path")
        if ".." in Path(relative_path).parts:
            raise ChecksumError(f"malformed checksum line {line_number}: path traversal")
        entries.append((digest, relative_path))
    return entries


def verify_committed_checksum_file(repo_root: Path, checksum_text: str) -> list[str]:
    mismatches = []
    for digest, relative_path in parse_checksum_file(checksum_text):
        path = repo_root / relative_path
        if not path.exists():
            mismatches.append(
                f"missing covered file listed in {CHECKSUM_FILE_NAME}: {relative_path}"
            )
            continue
        current_digest = file_sha256(path).removeprefix("sha256:")
        if current_digest != digest:
            mismatches.append(f"hash mismatch for {relative_path}")
    return mismatches


def check_outputs(repo_root: Path, covered_paths: list[Path], output_dir: Path) -> int:
    checksum_path = output_dir / CHECKSUM_FILE_NAME
    manifest_path = output_dir / CHECKSUM_MANIFEST_NAME
    mismatches = []

    if not checksum_path.exists():
        mismatches.append(f"missing {normalize_path(checksum_path, repo_root)}")
    if not manifest_path.exists():
        mismatches.append(f"missing {normalize_path(manifest_path, repo_root)}")

    if not mismatches:
        try:
            checksum_text = read_text(checksum_path)
            mismatches.extend(verify_committed_checksum_file(repo_root, checksum_text))
        except ChecksumError as exc:
            mismatches.append(str(exc))

    try:
        expected_checksum_text, expected_manifest_text = build_outputs(
            repo_root, covered_paths, output_dir
        )
    except ChecksumError as exc:
        mismatches.append(str(exc))
        expected_checksum_text = None
        expected_manifest_text = None

    if (
        expected_checksum_text is not None
        and checksum_path.exists()
        and read_text(checksum_path) != expected_checksum_text
    ):
        mismatches.append(f"changed {normalize_path(checksum_path, repo_root)}")
    if (
        expected_manifest_text is not None
        and manifest_path.exists()
        and read_text(manifest_path) != expected_manifest_text
    ):
        mismatches.append(f"changed {normalize_path(manifest_path, repo_root)}")

    if mismatches:
        print("release checksum bundle is out of date:", file=sys.stderr)
        for mismatch in mismatches:
            print(f"  - {mismatch}", file=sys.stderr)
        print(
            "run `python scripts/generate_release_checksums.py` and commit the regenerated files",
            file=sys.stderr,
        )
        return 1

    print("release checksum bundle is current")
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--covered-path", type=Path, action="append", dest="covered_paths")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--check", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    repo_root = Path.cwd()
    covered_paths = args.covered_paths or DEFAULT_COVERED_PATHS
    output_dir = args.output_dir

    try:
        if args.check:
            return check_outputs(repo_root, covered_paths, output_dir)
        written = write_outputs(repo_root, covered_paths, output_dir)
    except ChecksumError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    for path in written:
        print(normalize_path(path, repo_root))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
