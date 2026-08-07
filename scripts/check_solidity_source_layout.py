#!/usr/bin/env python3
"""Fail closed on Solidity source-layout and stale pre-migration paths."""

from __future__ import annotations

import argparse
import hashlib
import json
import posixpath
import re
import sys
from pathlib import Path, PurePosixPath
from typing import Any, Sequence


MANIFEST_PATH = Path("smart-contracts/source-layout.json")
EXPECTED_SCHEMA = "6529stream.solidity-source-layout.v1"
EXPECTED_SOURCE_ROOT = "smart-contracts"
EXPECTED_MIGRATION_BASE_COMMIT = "2ef4901609399d2808848b39ed2a3f877e945dba"
EXPECTED_MIGRATION_SOURCE_COUNT = 120
EXPECTED_MOVES_SHA256 = "9698c02514a3831f4c858a2087e20644f2c16ddea05e38f23ea4a07819db56ef"
EXPECTED_POLICY = {
    "allowed_top_level_directories": [
        "compatibility",
        "core",
        "domains",
        "integrations",
        "interfaces",
        "libraries",
        "vendor",
    ],
    "abi_only_directory": "smart-contracts/interfaces/compatibility",
    "concrete_compatibility_directory": "smart-contracts/compatibility",
    "stale_path_policy": "Old flat source paths are permitted only in this migration manifest.",
}
TEXT_SUFFIXES = {
    ".js",
    ".json",
    ".md",
    ".ps1",
    ".py",
    ".sh",
    ".sol",
    ".toml",
    ".txt",
    ".yaml",
    ".yml",
}
TEXT_ROOTS = (
    Path(".github"),
    Path("deployments"),
    Path("docs"),
    Path("ops"),
    Path("release-artifacts"),
    Path("script"),
    Path("scripts"),
    Path("smart-contracts"),
    Path("test"),
)
ROOT_TEXT_FILES = (
    Path("AGENTS.md"),
    Path("CHANGELOG.md"),
    Path("Makefile"),
    Path("README.md"),
    Path("SECURITY.md"),
    Path("foundry.toml"),
    Path("slither.config.json"),
)
DECLARATION_RE = re.compile(
    r"(?:^|[;}])\s*(?:abstract\s+)?(contract|interface|library)\s+"
    r"[A-Za-z_$][A-Za-z0-9_$]*",
    re.MULTILINE,
)
IMPORT_RE = re.compile(
    r'^\s*import\s+(?:[^"\']*\s+from\s+)?["\']([^"\']+)["\'];',
    re.MULTILINE,
)


class SourceLayoutError(RuntimeError):
    """Raised when the reviewed source-layout manifest is malformed."""


def _read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise SourceLayoutError(f"missing source-layout manifest: {path}") from exc
    except json.JSONDecodeError as exc:
        raise SourceLayoutError(f"invalid JSON in {path}: {exc}") from exc


def _normalized_source_path(value: Any, *, field: str) -> str:
    if not isinstance(value, str) or not value:
        raise SourceLayoutError(f"{field} must be a non-empty string")
    if "\\" in value:
        raise SourceLayoutError(f"{field} must use forward slashes: {value!r}")
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or "." in path.parts:
        raise SourceLayoutError(f"{field} must be normalized and repository-relative: {value!r}")
    if path.as_posix() != value:
        raise SourceLayoutError(f"{field} must be normalized: {value!r}")
    return value


def load_manifest(repo_root: Path) -> dict[str, Any]:
    manifest_path = repo_root / MANIFEST_PATH
    payload = _read_json(manifest_path)
    if not isinstance(payload, dict):
        raise SourceLayoutError("source-layout manifest root must be an object")
    if set(payload) != {
        "schema_version",
        "migration_base_commit",
        "source_root",
        "policy",
        "moves",
    }:
        raise SourceLayoutError("source-layout manifest has unexpected or missing root fields")
    if payload.get("schema_version") != EXPECTED_SCHEMA:
        raise SourceLayoutError(
            f"source-layout schema must be {EXPECTED_SCHEMA!r}, got "
            f"{payload.get('schema_version')!r}"
        )
    if payload.get("source_root") != EXPECTED_SOURCE_ROOT:
        raise SourceLayoutError(
            f"source_root must be {EXPECTED_SOURCE_ROOT!r}, got "
            f"{payload.get('source_root')!r}"
        )
    if payload.get("migration_base_commit") != EXPECTED_MIGRATION_BASE_COMMIT:
        raise SourceLayoutError(
            "migration_base_commit must remain the exact reviewed migration base "
            f"{EXPECTED_MIGRATION_BASE_COMMIT}"
        )

    policy = payload.get("policy")
    if policy != EXPECTED_POLICY:
        raise SourceLayoutError("policy must remain the exact reviewed source-layout policy")
    allowed = policy.get("allowed_top_level_directories")
    if (
        not isinstance(allowed, list)
        or not allowed
        or any(not isinstance(value, str) or not value for value in allowed)
        or len(allowed) != len(set(allowed))
    ):
        raise SourceLayoutError("allowed_top_level_directories must be unique strings")
    if allowed != sorted(allowed):
        raise SourceLayoutError("allowed_top_level_directories must be sorted")
    for field in ("abi_only_directory", "concrete_compatibility_directory"):
        value = _normalized_source_path(policy.get(field), field=f"policy.{field}")
        if not value.startswith(f"{EXPECTED_SOURCE_ROOT}/"):
            raise SourceLayoutError(f"policy.{field} must remain under smart-contracts")

    moves = payload.get("moves")
    if not isinstance(moves, list) or len(moves) != EXPECTED_MIGRATION_SOURCE_COUNT:
        count = len(moves) if isinstance(moves, list) else None
        raise SourceLayoutError(
            f"moves must contain exactly {EXPECTED_MIGRATION_SOURCE_COUNT} rows, got {count}"
        )
    if all(
        isinstance(move, dict)
        and isinstance(move.get("old_path"), str)
        and isinstance(move.get("new_path"), str)
        for move in moves
    ):
        raw_old_paths = [move.get("old_path") for move in moves]
        raw_new_paths = [move.get("new_path") for move in moves]
        if len(raw_old_paths) != len(set(raw_old_paths)):
            raise SourceLayoutError("old_path values must be unique")
        if len(raw_new_paths) != len(set(raw_new_paths)):
            raise SourceLayoutError("new_path values must be unique")
    old_paths: list[str] = []
    new_paths: list[str] = []
    for index, move in enumerate(moves):
        if not isinstance(move, dict) or set(move) != {"old_path", "new_path"}:
            raise SourceLayoutError(
                f"moves[{index}] must contain exactly old_path and new_path"
            )
        old_path = _normalized_source_path(move["old_path"], field=f"moves[{index}].old_path")
        new_path = _normalized_source_path(move["new_path"], field=f"moves[{index}].new_path")
        old_parts = PurePosixPath(old_path).parts
        new_parts = PurePosixPath(new_path).parts
        if len(old_parts) != 2 or old_parts[0] != EXPECTED_SOURCE_ROOT or not old_path.endswith(".sol"):
            raise SourceLayoutError(f"old_path must identify one flat Solidity source: {old_path}")
        if len(new_parts) < 3 or new_parts[0] != EXPECTED_SOURCE_ROOT or not new_path.endswith(".sol"):
            raise SourceLayoutError(f"new_path must identify one nested Solidity source: {new_path}")
        if new_parts[1] not in allowed:
            raise SourceLayoutError(
                f"new_path uses unapproved top-level directory {new_parts[1]!r}: {new_path}"
            )
        if old_parts[-1] != new_parts[-1]:
            raise SourceLayoutError(
                f"migration may move but not rename Solidity files: {old_path} -> {new_path}"
            )
        old_paths.append(old_path)
        new_paths.append(new_path)
    if len(old_paths) != len(set(old_paths)):
        raise SourceLayoutError("old_path values must be unique")
    if len(new_paths) != len(set(new_paths)):
        raise SourceLayoutError("new_path values must be unique")
    moves_digest = hashlib.sha256(
        json.dumps(moves, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()
    if moves_digest != EXPECTED_MOVES_SHA256:
        raise SourceLayoutError("moves must remain the exact reviewed 120-row migration map")
    return payload


def _relative(path: Path, repo_root: Path) -> str:
    return path.relative_to(repo_root).as_posix()


def _solidity_declaration_kinds(path: Path) -> list[str]:
    return DECLARATION_RE.findall(path.read_text(encoding="utf-8"))


def _text_files(repo_root: Path) -> list[Path]:
    files: set[Path] = set()
    for relative_root in TEXT_ROOTS:
        root = repo_root / relative_root
        if not root.exists():
            continue
        files.update(
            path
            for path in root.rglob("*")
            if path.is_file() and path.suffix.lower() in TEXT_SUFFIXES
        )
    for relative_path in ROOT_TEXT_FILES:
        path = repo_root / relative_path
        if path.is_file():
            files.add(path)
    return sorted(files)


def check_repository(repo_root: Path) -> list[str]:
    repo_root = repo_root.resolve()
    errors: list[str] = []
    try:
        manifest = load_manifest(repo_root)
    except SourceLayoutError as exc:
        return [str(exc)]

    source_root = repo_root / EXPECTED_SOURCE_ROOT
    moves = manifest["moves"]
    expected_sources = {move["new_path"] for move in moves}
    actual_sources = {
        _relative(path, repo_root) for path in source_root.rglob("*.sol") if path.is_file()
    }
    missing = sorted(expected_sources - actual_sources)
    if missing:
        errors.append(f"manifest targets are missing: {missing}")

    root_sources = sorted(path.name for path in source_root.glob("*.sol") if path.is_file())
    if root_sources:
        errors.append(f"top-level Solidity sources are forbidden: {root_sources}")

    allowed = set(manifest["policy"]["allowed_top_level_directories"])
    for source in sorted(actual_sources):
        parts = PurePosixPath(source).parts
        if len(parts) < 3 or parts[1] not in allowed:
            errors.append(f"Solidity source is outside the approved hierarchy: {source}")

    interfaces = f"{EXPECTED_SOURCE_ROOT}/interfaces/"
    abi_only = manifest["policy"]["abi_only_directory"].rstrip("/") + "/"
    concrete = manifest["policy"]["concrete_compatibility_directory"].rstrip("/") + "/"
    for source in sorted(actual_sources):
        if not source.startswith((interfaces, concrete)):
            continue
        kinds = _solidity_declaration_kinds(repo_root / source)
        if not kinds:
            errors.append(f"compatibility source has no contract/interface/library declaration: {source}")
        elif source.startswith(interfaces) and "contract" in kinds:
            errors.append(f"interface source must not declare a concrete contract: {source}")
        elif source.startswith(abi_only) and set(kinds) != {"interface"}:
            errors.append(f"ABI-only compatibility source must declare interfaces only: {source}")
        elif source.startswith(concrete) and "interface" in kinds:
            errors.append(
                f"concrete compatibility source must not declare an interface: {source}"
            )

    for solidity_root in (source_root, repo_root / "test", repo_root / "script"):
        if not solidity_root.exists():
            continue
        for path in sorted(solidity_root.rglob("*.sol")):
            text = path.read_text(encoding="utf-8")
            for import_target in IMPORT_RE.findall(text):
                if not import_target.startswith("."):
                    continue
                normalized_import = posixpath.normpath(import_target)
                if import_target.startswith("./"):
                    normalized_import = f"./{normalized_import}"
                if (
                    "\\" in import_target
                    or "//" in import_target
                    or normalized_import != import_target
                ):
                    errors.append(
                        f"relative import is not normalized: {_relative(path, repo_root)} -> "
                        f"{import_target}"
                    )
                    continue
                resolved = (path.parent / import_target).resolve()
                try:
                    resolved.relative_to(repo_root)
                except ValueError:
                    errors.append(
                        f"relative import escapes the repository: {_relative(path, repo_root)} -> "
                        f"{import_target}"
                    )
                    continue
                if not resolved.is_file():
                    errors.append(
                        f"relative import does not resolve: {_relative(path, repo_root)} -> "
                        f"{import_target}"
                    )

    old_paths = [move["old_path"] for move in moves]
    manifest_absolute = (repo_root / MANIFEST_PATH).resolve()
    for path in _text_files(repo_root):
        if path.resolve() == manifest_absolute:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            errors.append(f"source-layout text surface is not UTF-8: {_relative(path, repo_root)}")
            continue
        normalized_text = text.replace("\\", "/").casefold()
        for old_path in old_paths:
            if old_path.casefold() in normalized_text:
                errors.append(
                    f"stale pre-migration source path in {_relative(path, repo_root)}: {old_path}"
                )
    return errors


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    errors = check_repository(args.repo_root)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(
        "Solidity source layout is valid: 120 immutable reviewed moves are present; "
        "all sources use approved nested placement, resolved imports, and current paths."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
