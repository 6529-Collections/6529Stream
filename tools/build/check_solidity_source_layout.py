#!/usr/bin/env python3
"""Validate the active Solidity layout while preserving immutable migration history."""

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
CURRENT_MANIFEST_PATH = Path("smart-contracts/source-layout-current.json")
CURRENT_SCHEMA = "6529stream.solidity-source-layout.current.v1"
HISTORICAL_MANIFEST_BYTES_SHA256 = "a4a8be3df18da217e4efc3d4d09b151807bdc152125f524f1493dd39690d9f65"
HISTORICAL_RECEIPT_PATH = Path("release-artifacts/evidence/solidity-layout-equivalence.json")
HISTORICAL_RECEIPT_BYTES_SHA256 = "899a1ef7fa89bd762a5ea1860c906206cf30a89c19e28502dcb81e85fe82254b"
FROZEN_EVIDENCE_AREAS = (
    "deployments/current/sepolia-2026-09-09/",
    "deployments/current/sepolia-current-rc-1/compilation/",
    "release-artifacts/baselines/",
)
FROZEN_EVIDENCE_FILES = {
    'release-artifacts/evidence/local-anvil/snapshots/pre-reorganization-330ac1d4/deployments/address-books/anvil-6529stream-v0.1.0-001.json',
    'release-artifacts/evidence/local-anvil/snapshots/pre-reorganization-330ac1d4/deployments/ceremony-evidence/anvil-6529stream-v0.1.0-001-local.json',
    'release-artifacts/evidence/local-anvil/snapshots/pre-reorganization-330ac1d4/deployments/examples/anvil-6529stream-v0.1.0-001.json',
    'release-artifacts/evidence/local-anvil/snapshots/pre-reorganization-330ac1d4/deployments/randomizer-operations/anvil-6529stream-v0.1.0-001-local.json',
    'release-artifacts/evidence/local-anvil/snapshots/pre-reorganization-330ac1d4/docs/adr/0005-randomness.md.txt',
    'release-artifacts/evidence/local-anvil/snapshots/pre-reorganization-330ac1d4/release-artifacts/latest/abi-checksums.json',
    'release-artifacts/evidence/local-anvil/snapshots/pre-reorganization-330ac1d4/script/RehearseAuctionCeremony.s.sol.txt',
    'release-artifacts/evidence/local-anvil/snapshots/pre-reorganization-330ac1d4/script/RehearseDeployment.s.sol.txt',
    'release-artifacts/evidence/local-anvil/snapshots/pre-reorganization-330ac1d4/script/RehearseEmergencyRedeployment.s.sol.txt',
    'release-artifacts/evidence/local-anvil/snapshots/pre-reorganization-330ac1d4/script/RehearseMetadataBrowser.s.sol.txt',
    'release-artifacts/evidence/local-anvil/snapshots/pre-reorganization-330ac1d4/test/StreamEmergencyWithdraw.t.sol.txt',
    'release-artifacts/evidence/local-anvil/snapshots/pre-reorganization-330ac1d4/test/StreamPaymentsInvariant.t.sol.txt',
    'release-artifacts/evidence/local-anvil/snapshots/pre-reorganization-330ac1d4/test/StreamRandomizerAdversarial.t.sol.txt',
    'release-artifacts/evidence/local-anvil/snapshots/pre-reorganization-330ac1d4/test/StreamRandomizerLifecycle.t.sol.txt',
    'release-artifacts/evidence/local-anvil/snapshots/pre-reorganization-330ac1d4/test/StreamRandomizerPayments.t.sol.txt',
    'release-artifacts/evidence/local-anvil/snapshots/pre-reorganization-330ac1d4/test/StreamRandomizerRetry.t.sol.txt',
    "release-artifacts/evidence/fork-deployment-rehearsal/snapshots/pre-reorganization-330ac1d4/address-book.json",
    "release-artifacts/evidence/fork-deployment-rehearsal/snapshots/pre-reorganization-330ac1d4/deployment-manifest.json",
    "release-artifacts/evidence/fork-metadata-browser/fork-metadata-browser-retained-artifact-template.md",
    "release-artifacts/evidence/marketplace-indexer/fork-testnet-marketplace-indexer-retained-artifact.md",
    "release-artifacts/record-family-authorization-inventory.json",
    "test/fixtures/warning-dispositions/forge-size-output.txt",
}
CURRENT_STALE_PATH_POLICY = (
    "Retired source paths are forbidden in active surfaces; exact historical evidence "
    "files are exempt only at their recorded SHA-256 identity."
)
EXPECTED_SCHEMA = "6529stream.solidity-source-layout.v1"
EXPECTED_SOURCE_ROOT = "smart-contracts"
EXPECTED_MIGRATION_BASE_COMMIT = "2ef4901609399d2808848b39ed2a3f877e945dba"
EXPECTED_EQUIVALENCE_RECEIPT_CANONICAL_SHA256 = (
    "c5fb8861b5cf1f327bbf48927426d2260ecc561ba1647debb8e81d3dd27f3502"
)
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
    Path("tools"),
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
STALE_PATH_EVIDENCE_ALLOWLIST = {
    Path(
        "docs/architecture/"
        "artist-record-event-reconstruction-historical-git-objects-v1.json"
    ): {f"{EXPECTED_SOURCE_ROOT}/StreamArtistApprovals.sol": 2},
    Path("tools/protocol/check_artist_record_event_reconstruction_correction.py"): {
        f"{EXPECTED_SOURCE_ROOT}/StreamArtistApprovals.sol": 2
    },
    Path("tools/protocol/test_artist_record_event_reconstruction_correction.py"): {
        f"{EXPECTED_SOURCE_ROOT}/StreamArtistApprovals.sol": 1
    },
}
DECLARATION_RE = re.compile(
    r"(?:^|[;}])\s*(?:abstract\s+)?(contract|interface|library|struct|enum)\s+"
    r"[A-Za-z_$][A-Za-z0-9_$]*",
    re.MULTILINE,
)
IMPORT_RE = re.compile(
    r'^\s*import\s+(?:[^"\']*\s+from\s+)?["\']([^"\']+)["\'];',
    re.MULTILINE,
)


class SourceLayoutError(RuntimeError):
    """Raised when the reviewed source-layout manifest is malformed."""


IJSON_SAFE_INTEGER_MAX = (1 << 53) - 1


def _reject_duplicate_json_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise SourceLayoutError(f"duplicate JSON member: {key}")
        result[key] = value
    return result


def _parse_ijson_integer(token: str) -> int:
    value = int(token)
    if abs(value) > IJSON_SAFE_INTEGER_MAX:
        raise SourceLayoutError(
            f"JSON integer is outside the I-JSON interoperable range: {token}"
        )
    return value


def _reject_json_float(token: str) -> float:
    raise SourceLayoutError(f"floating-point JSON is forbidden in source-layout inputs: {token}")


def _reject_json_constant(token: str) -> None:
    raise SourceLayoutError(f"non-I-JSON token is forbidden: {token}")


def _read_json(path: Path) -> Any:
    try:
        raw = path.read_bytes()
    except FileNotFoundError as exc:
        raise SourceLayoutError(f"missing source-layout manifest: {path}") from exc
    try:
        text = raw.decode("utf-8", "strict")
    except UnicodeDecodeError as exc:
        raise SourceLayoutError(f"invalid JSON in {path}: {exc}") from exc
    try:
        return json.loads(
            text,
            object_pairs_hook=_reject_duplicate_json_pairs,
            parse_int=_parse_ijson_integer,
            parse_float=_reject_json_float,
            parse_constant=_reject_json_constant,
        )
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
        "equivalence_receipt_canonical_sha256",
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
    if (
        payload.get("equivalence_receipt_canonical_sha256")
        != EXPECTED_EQUIVALENCE_RECEIPT_CANONICAL_SHA256
    ):
        raise SourceLayoutError(
            "equivalence_receipt_canonical_sha256 must remain the exact reviewed "
            "historical receipt digest"
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


def load_current_manifest(repo_root: Path, *, candidate: Any = None) -> dict[str, Any]:
    """Load one flat active owner; historical v1 never becomes current semantic proof."""
    value = _read_json(repo_root / CURRENT_MANIFEST_PATH) if candidate is None else candidate
    fields = {"schema_version", "source_root", "historical_manifest",
              "historical_equivalence_receipt", "policy", "relocations",
              "source_paths", "frozen_evidence"}
    if not isinstance(value, dict) or set(value) != fields:
        raise SourceLayoutError("current source-layout manifest fields are not exact")
    if value["schema_version"] != CURRENT_SCHEMA or value["source_root"] != EXPECTED_SOURCE_ROOT:
        raise SourceLayoutError("current source-layout schema or root is invalid")
    expected_policy = dict(EXPECTED_POLICY, stale_path_policy=CURRENT_STALE_PATH_POLICY)
    if value["policy"] != expected_policy:
        raise SourceLayoutError("current source-layout policy differs from the reviewed hierarchy")
    for field, path, digest in (
        ("historical_manifest", MANIFEST_PATH, HISTORICAL_MANIFEST_BYTES_SHA256),
        ("historical_equivalence_receipt", HISTORICAL_RECEIPT_PATH, HISTORICAL_RECEIPT_BYTES_SHA256),
    ):
        if value[field] != {"path": path.as_posix(), "sha256": digest}:
            raise SourceLayoutError(f"{field} must identify the exact frozen historical bytes")
        if not (repo_root / path).is_file() or hashlib.sha256((repo_root / path).read_bytes()).hexdigest() != digest:
            raise SourceLayoutError(f"historical file byte identity changed or is missing: {path}")
    sources = value["source_paths"]
    if not isinstance(sources, list) or not sources:
        raise SourceLayoutError("current source_paths must be a non-empty inventory")
    for path in sources:
        _normalized_source_path(path, field="source_paths")
        if not path.startswith(EXPECTED_SOURCE_ROOT + "/") or not path.endswith(".sol"):
            raise SourceLayoutError(f"current inventory is not a Solidity source: {path}")
    if sources != sorted(set(sources)) or len({x.casefold() for x in sources}) != len(sources):
        raise SourceLayoutError("current source_paths must be sorted and unique, including case")
    relocations = value["relocations"]
    if not isinstance(relocations, list):
        raise SourceLayoutError("current relocations must be a flat list")
    old_paths, new_paths = [], []
    for row in relocations:
        if not isinstance(row, dict) or set(row) != {"old_path", "new_path"}:
            raise SourceLayoutError("current relocation fields must be old_path and new_path")
        old = _normalized_source_path(row["old_path"], field="relocations.old_path")
        new = _normalized_source_path(row["new_path"], field="relocations.new_path")
        if not old.startswith(EXPECTED_SOURCE_ROOT + "/") or not old.endswith(".sol") or new not in sources:
            raise SourceLayoutError("relocations must resolve retired Solidity paths directly into current inventory")
        if old == new or old in sources:
            raise SourceLayoutError("relocation source is not retired")
        old_paths.append(old)
        new_paths.append(new)
    if old_paths != sorted(set(old_paths)) or len(new_paths) != len(set(new_paths)):
        raise SourceLayoutError("current relocations must have sorted unique sources and unique destinations")
    if set(old_paths) & set(new_paths):
        raise SourceLayoutError("current relocations must be flat; migration chains are forbidden")
    frozen = value["frozen_evidence"]
    if not isinstance(frozen, list):
        raise SourceLayoutError("frozen_evidence must name exact files and hashes")
    frozen_paths = []
    for row in frozen:
        if not isinstance(row, dict) or set(row) != {"path", "sha256", "purpose"}:
            raise SourceLayoutError("frozen evidence fields must be path, sha256, and purpose")
        path = _normalized_source_path(row["path"], field="frozen_evidence.path")
        if path not in FROZEN_EVIDENCE_FILES and not path.startswith(FROZEN_EVIDENCE_AREAS):
            raise SourceLayoutError(f"operational path cannot be exempted as frozen evidence: {path}")
        if not isinstance(row["sha256"], str) or re.fullmatch(r"[0-9a-f]{64}", row["sha256"]) is None:
            raise SourceLayoutError("frozen evidence requires an exact lowercase SHA-256")
        if not isinstance(row["purpose"], str) or not row["purpose"].strip():
            raise SourceLayoutError("frozen evidence requires an explicit historical purpose")
        candidate = (repo_root / path).resolve()
        if not candidate.is_relative_to(repo_root.resolve()):
            raise SourceLayoutError(f"frozen evidence path escapes the repository: {path}")
        if not candidate.is_file() or hashlib.sha256(candidate.read_bytes()).hexdigest() != row["sha256"]:
            raise SourceLayoutError(f"frozen evidence byte identity changed or is missing: {path}")
        frozen_paths.append(path)
    if frozen_paths != sorted(set(frozen_paths)):
        raise SourceLayoutError("frozen evidence paths must be sorted and unique")
    return value


def current_target(path: str, current: dict[str, Any]) -> str:
    """Resolve a historical v1 destination through the single flat active inventory."""
    return {row["old_path"]: row["new_path"] for row in current["relocations"]}.get(path, path)


def _relative(path: Path, repo_root: Path) -> str:
    return path.relative_to(repo_root).as_posix()


def _solidity_declaration_kinds(path: Path) -> list[str]:
    # Declaration-shaped documentation and literal bytes are not Solidity declarations.
    # Consume whole comments/quoted strings so comment markers inside a string stay data.
    non_code = re.compile(
        r"""//[^\r\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'""",
        re.DOTALL,
    )
    code = non_code.sub(" ", path.read_text(encoding="utf-8"))
    return DECLARATION_RE.findall(code)


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


def check_repository(repo_root: Path, *, current_candidate: Any = None) -> list[str]:
    repo_root = repo_root.resolve()
    errors: list[str] = []
    try:
        manifest = load_manifest(repo_root)
        current = load_current_manifest(repo_root, candidate=current_candidate)
    except SourceLayoutError as exc:
        return [str(exc)]

    source_root = repo_root / EXPECTED_SOURCE_ROOT
    moves = manifest["moves"]
    expected_sources = set(current["source_paths"])
    historical_targets = {current_target(move["new_path"], current) for move in moves}
    if not historical_targets.issubset(expected_sources):
        errors.append("historical destinations must resolve into the active inventory")
    actual_sources = {
        _relative(path, repo_root) for path in source_root.rglob("*.sol") if path.is_file()
    }
    missing = sorted(expected_sources - actual_sources)
    if missing:
        errors.append(f"manifest targets are missing: {missing}")

    extras = sorted(actual_sources - expected_sources)
    if extras:
        errors.append(f"Solidity sources are not listed in the current inventory: {extras}")

    root_sources = sorted(path.name for path in source_root.glob("*.sol") if path.is_file())
    if root_sources:
        errors.append(f"top-level Solidity sources are forbidden: {root_sources}")

    allowed = set(current["policy"]["allowed_top_level_directories"])
    for source in sorted(actual_sources):
        parts = PurePosixPath(source).parts
        if source.startswith("smart-contracts/interfaces/stream/") and len(parts) < 5:
            errors.append(f"Stream interfaces must be grouped by domain: {source}")
        if len(parts) < 3 or parts[1] not in allowed:
            errors.append(f"Solidity source is outside the approved hierarchy: {source}")

    interfaces = f"{EXPECTED_SOURCE_ROOT}/interfaces/"
    abi_only = current["policy"]["abi_only_directory"].rstrip("/") + "/"
    concrete = current["policy"]["concrete_compatibility_directory"].rstrip("/") + "/"
    for source in sorted(actual_sources):
        kinds = _solidity_declaration_kinds(repo_root / source)
        if source.startswith(("smart-contracts/core/", "smart-contracts/domains/")) and "interface" in kinds:
            errors.append(f"shared protocol interface belongs under interfaces: {source}")
        if not source.startswith((interfaces, concrete)):
            continue
        if not kinds:
            errors.append(f"interface or compatibility source has no public declaration: {source}")
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

    old_paths = sorted({move["old_path"] for move in moves} | {move["old_path"] for move in current["relocations"]})
    exempt_paths = {MANIFEST_PATH.as_posix(), CURRENT_MANIFEST_PATH.as_posix()} | {row["path"] for row in current["frozen_evidence"]}
    for path in _text_files(repo_root):
        if _relative(path, repo_root) in exempt_paths:
            continue
        relative_path = Path(_relative(path, repo_root))
        allowed_historical_paths = STALE_PATH_EVIDENCE_ALLOWLIST.get(relative_path, {})
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            errors.append(f"source-layout text surface is not UTF-8: {_relative(path, repo_root)}")
            continue
        path_normalized_text = text.replace("\\", "/")
        normalized_text = path_normalized_text.casefold()
        for old_path in old_paths:
            folded_count = normalized_text.count(old_path.casefold())
            expected_count = allowed_historical_paths.get(old_path)
            if expected_count is not None:
                exact_count = path_normalized_text.count(old_path)
                if exact_count != expected_count or folded_count != expected_count:
                    errors.append(
                        "historical stale-path evidence count or case drift in "
                        f"{_relative(path, repo_root)}: {old_path} "
                        f"(expected {expected_count}, exact {exact_count}, "
                        f"case-folded {folded_count})"
                    )
            elif folded_count:
                errors.append(
                    f"stale pre-migration source path in {_relative(path, repo_root)}: {old_path}"
                )
    return errors


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[2])
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    errors = check_repository(args.repo_root)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(
        f"Solidity source layout is valid: {len(load_current_manifest(args.repo_root)['source_paths'])} "
        "current sources use approved paths and resolved imports; the original "
        "120-move manifest and historical receipt retain their exact bytes."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
