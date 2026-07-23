#!/usr/bin/env python3
"""Build canonical release artifacts one configured target at a time."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Callable, Sequence

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover - the checked toolchain is Python 3.12.
    tomllib = None  # type: ignore[assignment]


RELEASE_BUILD_SCHEMA = "6529stream.release-build.v1"
GENERATOR_VERSION = "1"
DEFAULT_CONFIG = Path("release-artifacts/contracts.json")
DEFAULT_FOUNDRY_CONFIG = Path("foundry.toml")
DEFAULT_OUTPUT_DIR = Path("out-release")
MANIFEST_FILENAME = "release-build-manifest.json"
CANONICAL_BUILD_COMMAND = "python scripts/build_release_artifacts.py"
FOUNDRY_VERSION = "1.7.1"
SOLC_VERSION = "0.8.19"
SOLC_LONG_VERSION = "0.8.19+commit.7dd6d404"
EVM_VERSION = "paris"
OPTIMIZER_RUNS = 200
SANITIZED_ENVIRONMENT_PREFIXES = ("DAPP_", "FOUNDRY_")
CONTROLLED_FORGE_ENVIRONMENT = {"FOUNDRY_PROFILE": "default"}
TARGET_GROUPS = (
    ("production_contract", "production_contracts"),
    ("interface", "interfaces"),
)
TARGET_NAME_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


class ReleaseBuildError(RuntimeError):
    """Raised when canonical release artifacts cannot be built or validated."""


CommandRunner = Callable[[list[str], Path], None]


def load_json(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise ReleaseBuildError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ReleaseBuildError(f"invalid JSON in {path}: {exc}") from exc


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def file_sha256(path: Path) -> str:
    try:
        content = path.read_bytes()
    except FileNotFoundError as exc:
        raise ReleaseBuildError(f"missing required file: {path}") from exc
    return "sha256:" + hashlib.sha256(content).hexdigest()


def canonical_json_sha256(value: Any) -> str:
    encoded = json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")
    return "sha256:" + hashlib.sha256(encoded).hexdigest()


def ordered_json_bytes(value: Any) -> bytes:
    """Serialize parsed compiler input while preserving Foundry's object order."""
    return json.dumps(
        value,
        sort_keys=False,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def keccak256_hex(value: bytes) -> str:
    try:
        from eth_hash.auto import keccak

        return "0x" + keccak(value).hex()
    except ImportError:
        pass

    try:
        from Crypto.Hash import keccak as crypto_keccak

        digest = crypto_keccak.new(digest_bits=256)
        digest.update(value)
        return "0x" + digest.hexdigest()
    except ImportError as exc:
        raise ReleaseBuildError(
            "Ethereum Keccak support is required to validate compiler metadata; "
            "install the hashed requirements-tools.lock environment"
        ) from exc


def normalize_path(path: Path, repo_root: Path) -> str:
    lexical = Path(os.path.abspath(os.path.normpath(path)))
    try:
        return lexical.relative_to(repo_root).as_posix()
    except ValueError:
        try:
            return lexical.resolve().relative_to(repo_root.resolve()).as_posix()
        except ValueError:
            return lexical.as_posix()


def require_dict(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ReleaseBuildError(f"{label} must be an object")
    return value


def require_list(value: Any, label: str) -> list[Any]:
    if not isinstance(value, list):
        raise ReleaseBuildError(f"{label} must be an array")
    return value


def require_string(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value:
        raise ReleaseBuildError(f"{label} must be a non-empty string")
    return value


def lexical_repo_path(repo_root: Path, value: Path, label: str) -> Path:
    path = value if value.is_absolute() else repo_root / value
    lexical = Path(os.path.abspath(os.path.normpath(path)))
    try:
        lexical.relative_to(repo_root)
    except ValueError as exc:
        if os.name != "nt":
            raise ReleaseBuildError(
                f"{label} must stay inside the repository: {value}"
            ) from exc
        # Windows may return an absolute input with an 8.3 path component while
        # Path.resolve() expands the repository root. Inspect every component
        # before resolution, then accept the alias only if it resolves inside.
        cursor = Path(lexical.anchor)
        for part in lexical.parts[1:]:
            cursor /= part
            if path_is_link_or_reparse(cursor):
                raise ReleaseBuildError(
                    f"{label} must not use symlink, junction, or reparse "
                    f"components: {cursor}"
                ) from None
        resolved = lexical.resolve()
        try:
            resolved.relative_to(repo_root)
        except ValueError:
            raise ReleaseBuildError(
                f"{label} must stay inside the repository: {value}"
            ) from exc
        return resolved
    return lexical


def path_is_link_or_reparse(path: Path) -> bool:
    if path.is_symlink():
        return True
    is_junction = getattr(path, "is_junction", None)
    if callable(is_junction) and is_junction():
        return True
    try:
        attributes = getattr(os.lstat(path), "st_file_attributes", 0)
    except FileNotFoundError:
        return False
    reparse_flag = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)
    return bool(reparse_flag and attributes & reparse_flag)


def reject_link_or_reparse_components(
    repo_root: Path,
    path: Path,
    label: str,
) -> None:
    try:
        relative = path.relative_to(repo_root)
    except ValueError as exc:
        raise ReleaseBuildError(f"{label} must stay inside the repository: {path}") from exc
    cursor = repo_root
    for part in relative.parts:
        cursor /= part
        if path_is_link_or_reparse(cursor):
            raise ReleaseBuildError(
                f"{label} must not use symlink, junction, or reparse components: {cursor}"
            )


def resolve_repo_path(repo_root: Path, value: Path, label: str) -> Path:
    lexical = lexical_repo_path(repo_root, value, label)
    reject_link_or_reparse_components(repo_root, lexical, label)
    resolved = lexical.resolve()
    try:
        resolved.relative_to(repo_root)
    except ValueError as exc:
        raise ReleaseBuildError(f"{label} must stay inside the repository: {value}") from exc
    return resolved


def resolve_canonical_output_path(repo_root: Path, value: Path) -> Path:
    lexical = lexical_repo_path(repo_root, value, "release output directory")
    canonical = repo_root / DEFAULT_OUTPUT_DIR
    if lexical != canonical:
        raise ReleaseBuildError(
            "release output directory must be the canonical repository "
            f"{DEFAULT_OUTPUT_DIR.as_posix()} directory"
        )
    reject_link_or_reparse_components(
        repo_root,
        lexical,
        "release output directory",
    )
    return lexical.resolve()


def load_foundry_profile(path: Path) -> dict[str, Any]:
    if tomllib is None:
        raise ReleaseBuildError("Python 3.11+ is required to read foundry.toml")
    try:
        with path.open("rb") as handle:
            config = tomllib.load(handle)
    except FileNotFoundError as exc:
        raise ReleaseBuildError(f"missing required file: {path}") from exc
    except tomllib.TOMLDecodeError as exc:
        raise ReleaseBuildError(f"invalid TOML in {path}: {exc}") from exc
    profile = require_dict(config.get("profile"), "foundry.toml profile")
    return require_dict(profile.get("default"), "foundry.toml profile.default")


def validate_foundry_profile(path: Path) -> None:
    profile = load_foundry_profile(path)
    expected = {
        "solc_version": SOLC_VERSION,
        "auto_detect_solc": False,
        "evm_version": EVM_VERSION,
        "optimizer": True,
        "optimizer_runs": OPTIMIZER_RUNS,
        "bytecode_hash": "none",
        "cbor_metadata": False,
    }
    for key, expected_value in expected.items():
        actual = profile.get(key)
        if actual != expected_value:
            raise ReleaseBuildError(
                f"foundry.toml profile.default.{key} is {actual!r}, "
                f"expected {expected_value!r}"
            )


def configured_targets(repo_root: Path, config_path: Path) -> list[dict[str, str]]:
    config = require_dict(load_json(config_path), str(config_path))
    targets: list[dict[str, str]] = []
    names: set[str] = set()

    for kind, config_key in TARGET_GROUPS:
        entries = require_list(config.get(config_key, []), f"{config_path}.{config_key}")
        if config_key == "production_contracts" and not entries:
            raise ReleaseBuildError("production_contracts must not be empty")
        for index, value in enumerate(entries):
            entry = require_dict(value, f"{config_path}.{config_key}[{index}]")
            name = require_string(entry.get("name"), f"{config_key}[{index}].name")
            source = Path(
                require_string(entry.get("source"), f"{config_key}[{index}].source")
            ).as_posix()
            if not TARGET_NAME_RE.fullmatch(name):
                raise ReleaseBuildError(f"invalid Solidity target name: {name!r}")
            if name in names:
                raise ReleaseBuildError(f"duplicate configured release target name: {name}")
            names.add(name)

            source_path = resolve_repo_path(
                repo_root,
                Path(source),
                f"{config_key}[{index}].source",
            )
            if source_path.suffix != ".sol" or not source_path.is_file():
                raise ReleaseBuildError(f"configured Solidity source is missing: {source}")
            targets.append({"kind": kind, "name": name, "source": source})

    return sorted(targets, key=lambda item: (item["kind"], item["name"], item["source"]))


def artifact_metadata(artifact: dict[str, Any], label: str) -> dict[str, Any]:
    metadata = artifact.get("metadata")
    if isinstance(metadata, dict):
        return metadata
    if isinstance(metadata, str):
        try:
            return require_dict(json.loads(metadata), f"{label}.metadata")
        except json.JSONDecodeError as exc:
            raise ReleaseBuildError(f"invalid metadata JSON in {label}: {exc}") from exc
    raise ReleaseBuildError(f"{label} does not contain compiler metadata")


def metadata_source_records(
    repo_root: Path,
    metadata: dict[str, Any],
    label: str,
) -> list[dict[str, str]]:
    sources = require_dict(metadata.get("sources"), f"{label}.metadata.sources")
    records = []
    for source in sorted(sources):
        metadata_source = require_dict(
            sources.get(source),
            f"{label}.metadata.sources.{source}",
        )
        recorded_keccak = require_string(
            metadata_source.get("keccak256"),
            f"{label}.metadata.sources.{source}.keccak256",
        )
        source_path = resolve_repo_path(repo_root, Path(source), f"{label} metadata source")
        if not source_path.is_file():
            raise ReleaseBuildError(f"{label} metadata source is missing: {source}")
        source_bytes = source_path.read_bytes()
        actual_keccak = keccak256_hex(source_bytes)
        if recorded_keccak.lower() != actual_keccak.lower():
            raise ReleaseBuildError(
                f"{label} metadata keccak256 for {source} does not match the checkout"
            )
        records.append(
            {
                "path": Path(source).as_posix(),
                "sha256": sha256_bytes(source_bytes),
                "keccak256": actual_keccak,
            }
        )
    if not records:
        raise ReleaseBuildError(f"{label}.metadata.sources must not be empty")
    return records


def validate_compiler_input(
    repo_root: Path,
    compiler_input: dict[str, Any],
    label: str,
) -> dict[str, Any]:
    if compiler_input.get("language") != "Solidity":
        raise ReleaseBuildError(f"{label} compiler input language must be Solidity")
    sources = require_dict(compiler_input.get("sources"), f"{label}.input.sources")
    if not sources:
        raise ReleaseBuildError(f"{label}.input.sources must not be empty")

    source_records = []
    for source, value in sources.items():
        source_entry = require_dict(value, f"{label}.input.sources.{source}")
        content = require_string(
            source_entry.get("content"),
            f"{label}.input.sources.{source}.content",
        )
        source_path = resolve_repo_path(
            repo_root,
            Path(source),
            f"{label} compiler input source",
        )
        try:
            checkout_content = source_path.read_bytes().decode("utf-8")
        except FileNotFoundError as exc:
            raise ReleaseBuildError(
                f"{label} compiler input source is missing: {source}"
            ) from exc
        except UnicodeDecodeError as exc:
            raise ReleaseBuildError(
                f"{label} compiler input source is not UTF-8: {source}"
            ) from exc
        if content != checkout_content:
            raise ReleaseBuildError(
                f"{label} compiler input content does not match the checkout: {source}"
            )
        content_bytes = content.encode("utf-8")
        source_records.append(
            {
                "path": Path(source).as_posix(),
                "sha256": sha256_bytes(content_bytes),
                "keccak256": keccak256_hex(content_bytes),
            }
        )

    settings = require_dict(compiler_input.get("settings"), f"{label}.input.settings")
    if settings.get("viaIR") is not True:
        raise ReleaseBuildError(f"{label} compiler input does not enable viaIR")
    if settings.get("evmVersion") != EVM_VERSION:
        raise ReleaseBuildError(
            f"{label} compiler input EVM version must be {EVM_VERSION}"
        )
    optimizer = require_dict(
        settings.get("optimizer"),
        f"{label}.input.settings.optimizer",
    )
    if optimizer.get("enabled") is not True or optimizer.get("runs") != OPTIMIZER_RUNS:
        raise ReleaseBuildError(
            f"{label} compiler input optimizer must use {OPTIMIZER_RUNS} runs"
        )
    metadata = require_dict(
        settings.get("metadata"),
        f"{label}.input.settings.metadata",
    )
    if metadata.get("bytecodeHash") != "none" or metadata.get("appendCBOR") is not False:
        raise ReleaseBuildError(
            f"{label} compiler input metadata must disable bytecode hash and CBOR"
        )

    ordered_input = ordered_json_bytes(compiler_input)
    return {
        "compiler_input_sources": source_records,
        "compiler_input_source_order": [record["path"] for record in source_records],
        "compiler_input_settings_sha256": canonical_json_sha256(settings),
        "compiler_input_ordered_sha256": sha256_bytes(ordered_input),
        "compiler_input_canonical_sha256": canonical_json_sha256(compiler_input),
    }


def load_build_info_input(build_info_dir: Path, label: str) -> dict[str, Any]:
    build_info_files = sorted(build_info_dir.glob("*.json"))
    if len(build_info_files) != 1:
        locations = ", ".join(str(path) for path in build_info_files) or "none"
        raise ReleaseBuildError(
            f"{label} must emit exactly one Foundry build-info file, found: {locations}"
        )
    build_info = require_dict(load_json(build_info_files[0]), str(build_info_files[0]))
    return require_dict(build_info.get("input"), f"{build_info_files[0]}.input")


def load_retained_compiler_input(path: Path, label: str) -> dict[str, Any]:
    try:
        raw = path.read_bytes()
    except FileNotFoundError as exc:
        raise ReleaseBuildError(f"missing retained compiler input: {path}") from exc
    try:
        value = require_dict(json.loads(raw), label)
    except json.JSONDecodeError as exc:
        raise ReleaseBuildError(f"invalid retained compiler input JSON in {path}: {exc}") from exc
    if ordered_json_bytes(value) != raw:
        raise ReleaseBuildError(f"{path} is not the exact ordered compiler-input encoding")
    return value


def validate_target_artifact(
    repo_root: Path,
    artifact_path: Path,
    target: dict[str, str],
    foundry_config_path: Path,
    compiler_input: dict[str, Any],
) -> tuple[dict[str, Any], dict[str, Any]]:
    label = f"{target['source']}:{target['name']}"
    artifact = require_dict(load_json(artifact_path), str(artifact_path))
    metadata = artifact_metadata(artifact, label)
    compiler = require_dict(metadata.get("compiler"), f"{label}.metadata.compiler")
    compiler_version = require_string(
        compiler.get("version"),
        f"{label}.metadata.compiler.version",
    )
    if compiler_version != SOLC_LONG_VERSION:
        raise ReleaseBuildError(
            f"{label} compiler version is {compiler_version!r}, expected {SOLC_LONG_VERSION!r}"
        )

    settings = require_dict(metadata.get("settings"), f"{label}.metadata.settings")
    compilation_target = require_dict(
        settings.get("compilationTarget"),
        f"{label}.metadata.settings.compilationTarget",
    )
    expected_target = {target["source"]: target["name"]}
    if compilation_target != expected_target:
        raise ReleaseBuildError(
            f"{label} compilation target is {compilation_target!r}, expected {expected_target!r}"
        )
    if settings.get("viaIR") is not True:
        raise ReleaseBuildError(f"{label} was not compiled via IR")
    if settings.get("evmVersion") != EVM_VERSION:
        raise ReleaseBuildError(
            f"{label} EVM version is {settings.get('evmVersion')!r}, expected {EVM_VERSION!r}"
        )

    optimizer = require_dict(settings.get("optimizer"), f"{label}.metadata.settings.optimizer")
    if optimizer.get("enabled") is not True or optimizer.get("runs") != OPTIMIZER_RUNS:
        raise ReleaseBuildError(
            f"{label} optimizer settings must be enabled with {OPTIMIZER_RUNS} runs"
        )
    metadata_settings = require_dict(
        settings.get("metadata"),
        f"{label}.metadata.settings.metadata",
    )
    if (
        metadata_settings.get("bytecodeHash") != "none"
        or metadata_settings.get("appendCBOR") is not False
    ):
        raise ReleaseBuildError(f"{label} metadata must disable bytecode hash and CBOR output")

    source_records = metadata_source_records(repo_root, metadata, label)
    source_paths = {record["path"] for record in source_records}
    if target["source"] not in source_paths:
        raise ReleaseBuildError(f"{label} metadata does not include its configured source")
    compiler_input_bindings = validate_compiler_input(
        repo_root,
        compiler_input,
        label,
    )
    compiler_sources = compiler_input_bindings["compiler_input_sources"]
    if [record["path"] for record in source_records] != sorted(
        record["path"] for record in compiler_sources
    ):
        raise ReleaseBuildError(
            f"{label} artifact metadata source set does not match build-info input"
        )
    metadata_by_path = {record["path"]: record for record in source_records}
    for compiler_source in compiler_sources:
        if metadata_by_path[compiler_source["path"]] != compiler_source:
            raise ReleaseBuildError(
                f"{label} artifact metadata source hash does not match build-info input "
                f"for {compiler_source['path']}"
            )

    normalized_argv = normalized_forge_argv(
        target["source"],
        normalize_path(foundry_config_path, repo_root),
    )
    source_universe = {
        record["path"]: record["sha256"]
        for record in source_records
    }
    bindings = {
        "forge_environment": CONTROLLED_FORGE_ENVIRONMENT,
        "forge_argv": normalized_argv,
        "metadata_sources": source_records,
        "canonical_source_universe_sha256": canonical_json_sha256(source_universe),
        "compiler_settings_sha256": canonical_json_sha256(settings),
        **compiler_input_bindings,
        "canonical_build_input_sha256": canonical_json_sha256(
            {
                "compiler_version": compiler_version,
                "compiler_input_canonical_sha256": compiler_input_bindings[
                    "compiler_input_canonical_sha256"
                ],
                "compiler_input_ordered_sha256": compiler_input_bindings[
                    "compiler_input_ordered_sha256"
                ],
                "forge_argv": normalized_argv,
                "forge_environment": CONTROLLED_FORGE_ENVIRONMENT,
                "language": metadata.get("language", "Solidity"),
                "settings": settings,
                "source_universe": source_universe,
                "target": target,
            }
        ),
    }
    return artifact, bindings


def find_target_artifact(out_dir: Path, target: dict[str, str]) -> Path:
    direct = out_dir / Path(target["source"]).name / f"{target['name']}.json"
    if direct.is_file():
        return direct
    matches = sorted(out_dir.glob(f"**/{target['name']}.json"))
    if not matches:
        raise ReleaseBuildError(
            f"forge did not emit {target['source']}:{target['name']} under {out_dir}"
        )
    if len(matches) > 1:
        locations = ", ".join(str(path) for path in matches)
        raise ReleaseBuildError(
            f"forge emitted ambiguous artifacts for {target['name']}: {locations}"
        )
    return matches[0]


def forge_command(
    forge_bin: str,
    repo_root: Path,
    foundry_config_path: Path,
    source: str,
    out_dir: Path,
    cache_dir: Path,
    build_info_dir: Path,
) -> list[str]:
    return [
        forge_bin,
        "build",
        source,
        "--root",
        str(repo_root),
        "--config-path",
        str(foundry_config_path),
        "--out",
        str(out_dir),
        "--cache-path",
        str(cache_dir),
        "--build-info",
        "--build-info-path",
        str(build_info_dir),
        "--use",
        SOLC_VERSION,
        "--no-auto-detect",
        "--evm-version",
        EVM_VERSION,
        "--optimize",
        "true",
        "--optimizer-runs",
        str(OPTIMIZER_RUNS),
        "--via-ir",
        "--use-literal-content",
        "--no-metadata",
        "--force",
        "--skip",
        "test",
        "--skip",
        "script",
    ]


def normalized_forge_argv(source: str, foundry_config: str) -> list[str]:
    """Return the deterministic argv semantics retained in the build receipt."""
    return [
        "forge",
        "build",
        source,
        "--root",
        ".",
        "--config-path",
        foundry_config,
        "--out",
        "<isolated-out>",
        "--cache-path",
        "<isolated-cache>",
        "--build-info",
        "--build-info-path",
        "<isolated-build-info>",
        "--use",
        SOLC_VERSION,
        "--no-auto-detect",
        "--evm-version",
        EVM_VERSION,
        "--optimize",
        "true",
        "--optimizer-runs",
        str(OPTIMIZER_RUNS),
        "--via-ir",
        "--use-literal-content",
        "--no-metadata",
        "--force",
        "--skip",
        "test",
        "--skip",
        "script",
    ]


def sanitized_forge_environment() -> dict[str, str]:
    environment = {
        name: value
        for name, value in os.environ.items()
        if not name.upper().startswith(SANITIZED_ENVIRONMENT_PREFIXES)
    }
    environment.update(CONTROLLED_FORGE_ENVIRONMENT)
    return environment


def run_forge(command: list[str], cwd: Path) -> None:
    try:
        result = subprocess.run(
            command,
            cwd=cwd,
            env=sanitized_forge_environment(),
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
    except FileNotFoundError as exc:
        raise ReleaseBuildError(
            f"{command[0]!r} was not found; install Foundry and ensure forge is on PATH"
        ) from exc
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "no compiler output"
        raise ReleaseBuildError(
            f"isolated forge build failed for {command[2]} with exit code "
            f"{result.returncode}: {detail}"
        )


def normalize_forge_version(value: str) -> str:
    normalized = value.replace("\r\n", "\n").replace("\r", "\n").strip()
    if not normalized:
        raise ReleaseBuildError("forge --version returned empty output")
    return normalized


def validate_forge_version(value: str) -> str:
    normalized = normalize_forge_version(value)
    match = re.search(
        r"^forge Version:\s+(\d+\.\d+\.\d+)(?:\s|$)",
        normalized,
        flags=re.MULTILINE,
    )
    if match is None:
        raise ReleaseBuildError("forge --version output does not contain a semantic version")
    actual = match.group(1)
    if actual != FOUNDRY_VERSION:
        raise ReleaseBuildError(
            f"Foundry version is {actual}, expected pinned {FOUNDRY_VERSION}"
        )
    return normalized


def read_forge_version(forge_bin: str, repo_root: Path) -> str:
    try:
        result = subprocess.run(
            [forge_bin, "--version"],
            cwd=repo_root,
            env=sanitized_forge_environment(),
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
    except FileNotFoundError as exc:
        raise ReleaseBuildError(
            f"{forge_bin!r} was not found; install Foundry and ensure forge is on PATH"
        ) from exc
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "no version output"
        raise ReleaseBuildError(
            f"forge --version failed with exit code {result.returncode}: {detail}"
        )
    return validate_forge_version(result.stdout)


def build_manifest(
    repo_root: Path,
    config_path: Path,
    foundry_config_path: Path,
    output_dir: Path,
    targets: list[dict[str, Any]],
    forge_version: str,
) -> dict[str, Any]:
    return {
        "schema_version": RELEASE_BUILD_SCHEMA,
        "generated_by": f"scripts/build_release_artifacts.py:{GENERATOR_VERSION}",
        "source": {
            "config": normalize_path(config_path, repo_root),
            "config_sha256": file_sha256(config_path),
            "foundry_config": normalize_path(foundry_config_path, repo_root),
            "foundry_config_sha256": file_sha256(foundry_config_path),
        },
        "policy": {
            "compilation_unit": "one_configured_target_source_and_its_import_closure",
            "solc_version": SOLC_VERSION,
            "solc_long_version": SOLC_LONG_VERSION,
            "evm_version": EVM_VERSION,
            "optimizer_enabled": True,
            "optimizer_runs": OPTIMIZER_RUNS,
            "via_ir": True,
            "bytecode_hash": "none",
            "cbor_metadata": False,
            "controlled_forge_environment": CONTROLLED_FORGE_ENVIRONMENT,
            "forge_profile": "default",
            "foundry_version": FOUNDRY_VERSION,
            "forge_version": forge_version,
            "forge_version_sha256": sha256_bytes(forge_version.encode("utf-8")),
            "sanitized_environment_prefixes": list(SANITIZED_ENVIRONMENT_PREFIXES),
        },
        "output_dir": normalize_path(output_dir, repo_root),
        "targets": targets,
    }


def expected_target_identity(targets: list[dict[str, str]]) -> list[tuple[str, str, str]]:
    return [(target["kind"], target["name"], target["source"]) for target in targets]


def validate_release_output(
    repo_root: Path,
    config_path: Path,
    foundry_config_path: Path,
    output_dir: Path,
    *,
    declared_output_dir: Path | None = None,
    expected_forge_version: str | None = None,
) -> dict[str, Any]:
    repo_root = repo_root.resolve()
    config_path = resolve_repo_path(repo_root, config_path, "contract config")
    foundry_config_path = resolve_repo_path(
        repo_root,
        foundry_config_path,
        "Foundry config",
    )
    if declared_output_dir is None:
        output_dir = resolve_canonical_output_path(repo_root, output_dir)
        declared = output_dir
    else:
        declared = resolve_canonical_output_path(repo_root, declared_output_dir)
        output_dir = resolve_repo_path(
            repo_root,
            output_dir,
            "staged release output directory",
        )
        staged_relative = output_dir.relative_to(repo_root)
        if (
            len(staged_relative.parts) != 2
            or not staged_relative.parts[0].startswith(".release-build-")
            or staged_relative.parts[1] != "aggregate"
        ):
            raise ReleaseBuildError(
                "staged release output must be a build-owned .release-build-*/aggregate directory"
            )

    configured = configured_targets(repo_root, config_path)
    validate_foundry_profile(foundry_config_path)
    manifest_path = resolve_repo_path(
        repo_root,
        output_dir / MANIFEST_FILENAME,
        "release build receipt",
    )
    manifest = require_dict(load_json(manifest_path), str(manifest_path))
    if manifest.get("schema_version") != RELEASE_BUILD_SCHEMA:
        raise ReleaseBuildError(
            f"{manifest_path} schema must be {RELEASE_BUILD_SCHEMA!r}"
        )
    if manifest.get("generated_by") != (
        f"scripts/build_release_artifacts.py:{GENERATOR_VERSION}"
    ):
        raise ReleaseBuildError(f"{manifest_path} generator identity is invalid")

    source = require_dict(manifest.get("source"), f"{manifest_path}.source")
    if source.get("config") != normalize_path(config_path, repo_root):
        raise ReleaseBuildError(f"{manifest_path} config path is stale")
    if source.get("config_sha256") != file_sha256(config_path):
        raise ReleaseBuildError(f"{manifest_path} config hash is stale")
    if source.get("foundry_config") != normalize_path(foundry_config_path, repo_root):
        raise ReleaseBuildError(f"{manifest_path} foundry config path is stale")
    if source.get("foundry_config_sha256") != file_sha256(foundry_config_path):
        raise ReleaseBuildError(f"{manifest_path} foundry config hash is stale")
    if manifest.get("output_dir") != normalize_path(declared, repo_root):
        raise ReleaseBuildError(f"{manifest_path} output directory is stale")

    policy = require_dict(manifest.get("policy"), f"{manifest_path}.policy")
    recorded_forge_version = require_string(
        policy.get("forge_version"),
        f"{manifest_path}.policy.forge_version",
    )
    validate_forge_version(recorded_forge_version)
    if policy.get("forge_version_sha256") != sha256_bytes(
        recorded_forge_version.encode("utf-8")
    ):
        raise ReleaseBuildError(f"{manifest_path} forge version hash is stale")
    if (
        expected_forge_version is not None
        and recorded_forge_version != validate_forge_version(expected_forge_version)
    ):
        raise ReleaseBuildError(
            f"{manifest_path} was built by a different Forge version"
        )
    expected_policy = build_manifest(
        repo_root,
        config_path,
        foundry_config_path,
        declared,
        [],
        recorded_forge_version,
    )["policy"]
    if policy != expected_policy:
        raise ReleaseBuildError(f"{manifest_path} compiler policy is stale")

    records = require_list(manifest.get("targets"), f"{manifest_path}.targets")
    record_identity = []
    expected_files = {Path(MANIFEST_FILENAME)}
    for index, value in enumerate(records):
        record = require_dict(value, f"{manifest_path}.targets[{index}]")
        target = {
            "kind": require_string(record.get("kind"), f"targets[{index}].kind"),
            "name": require_string(record.get("name"), f"targets[{index}].name"),
            "source": require_string(record.get("source"), f"targets[{index}].source"),
        }
        record_identity.append((target["kind"], target["name"], target["source"]))
        relative_artifact = Path(
            require_string(
                record.get("artifact_relative_path"),
                f"targets[{index}].artifact_relative_path",
            )
        )
        if relative_artifact.is_absolute() or ".." in relative_artifact.parts:
            raise ReleaseBuildError(f"targets[{index}] artifact path is unsafe")
        expected_artifact_path = declared / relative_artifact
        if record.get("artifact_path") != normalize_path(expected_artifact_path, repo_root):
            raise ReleaseBuildError(f"targets[{index}] artifact path is stale")
        actual_artifact_path = resolve_repo_path(
            repo_root,
            output_dir / relative_artifact,
            f"targets[{index}] artifact",
        )
        expected_files.add(relative_artifact)

        relative_compiler_input = Path(
            require_string(
                record.get("compiler_input_relative_path"),
                f"targets[{index}].compiler_input_relative_path",
            )
        )
        if relative_compiler_input.is_absolute() or ".." in relative_compiler_input.parts:
            raise ReleaseBuildError(f"targets[{index}] compiler input path is unsafe")
        expected_compiler_input_path = declared / relative_compiler_input
        if record.get("compiler_input_path") != normalize_path(
            expected_compiler_input_path,
            repo_root,
        ):
            raise ReleaseBuildError(f"targets[{index}] compiler input path is stale")
        actual_compiler_input_path = resolve_repo_path(
            repo_root,
            output_dir / relative_compiler_input,
            f"targets[{index}] compiler input",
        )
        expected_files.add(relative_compiler_input)
        if record.get("compiler_input_sha256") != file_sha256(
            actual_compiler_input_path
        ):
            raise ReleaseBuildError(f"targets[{index}] compiler input hash is stale")
        compiler_input = load_retained_compiler_input(
            actual_compiler_input_path,
            f"targets[{index}].compiler_input",
        )
        _, bindings = validate_target_artifact(
            repo_root,
            actual_artifact_path,
            target,
            foundry_config_path,
            compiler_input,
        )
        if record.get("artifact_sha256") != file_sha256(actual_artifact_path):
            raise ReleaseBuildError(f"targets[{index}] artifact hash is stale")
        for binding_name, expected_value in bindings.items():
            if record.get(binding_name) != expected_value:
                raise ReleaseBuildError(
                    f"targets[{index}] {binding_name.replace('_', ' ')} is stale"
                )

    if record_identity != expected_target_identity(configured):
        raise ReleaseBuildError(f"{manifest_path} configured target set is stale")

    output_entries = list(output_dir.rglob("*"))
    for path in output_entries:
        reject_link_or_reparse_components(
            repo_root,
            path,
            "release output entry",
        )
    actual_files = {
        path.relative_to(output_dir)
        for path in output_entries
        if path.is_file()
    }
    if actual_files != expected_files:
        missing = sorted(expected_files - actual_files)
        extra = sorted(actual_files - expected_files)
        details = [f"missing {path.as_posix()}" for path in missing]
        details.extend(f"unexpected {path.as_posix()}" for path in extra)
        raise ReleaseBuildError(
            f"{output_dir} does not contain the exact configured artifact set: "
            + ", ".join(details)
        )
    return manifest


def replace_output_directory(staged: Path, output_dir: Path, temp_root: Path) -> None:
    if path_is_link_or_reparse(output_dir) or (
        output_dir.exists() and not output_dir.is_dir()
    ):
        raise ReleaseBuildError(
            f"release output must be a non-link, non-reparse directory: {output_dir}"
        )
    previous = temp_root / "previous-release-output"
    had_previous = output_dir.exists()
    try:
        if had_previous:
            os.replace(output_dir, previous)
        os.replace(staged, output_dir)
    except BaseException:
        if had_previous and previous.exists() and not output_dir.exists():
            try:
                os.replace(previous, output_dir)
            except BaseException as rollback_error:
                raise ReleaseBuildError(
                    "release output replacement failed and the previous output "
                    "could not be restored"
                ) from rollback_error
        raise
    if previous.exists():
        shutil.rmtree(previous)


def build_release_output(
    repo_root: Path,
    config_path: Path,
    foundry_config_path: Path,
    output_dir: Path,
    forge_bin: str = "forge",
    runner: CommandRunner = run_forge,
    forge_version_output: str | None = None,
) -> dict[str, Any]:
    repo_root = repo_root.resolve()
    config_path = resolve_repo_path(repo_root, config_path, "contract config")
    foundry_config_path = resolve_repo_path(
        repo_root,
        foundry_config_path,
        "Foundry config",
    )
    output_dir = resolve_canonical_output_path(repo_root, output_dir)
    output_dir.parent.mkdir(parents=True, exist_ok=True)

    validate_foundry_profile(foundry_config_path)
    targets = configured_targets(repo_root, config_path)
    forge_version = (
        validate_forge_version(forge_version_output)
        if forge_version_output is not None
        else read_forge_version(forge_bin, repo_root)
    )
    with tempfile.TemporaryDirectory(prefix=".release-build-", dir=repo_root) as temp:
        temp_root = Path(temp)
        staged = temp_root / "aggregate"
        staged.mkdir()
        records = []
        targets_by_source: dict[str, list[dict[str, str]]] = {}
        for target in targets:
            targets_by_source.setdefault(target["source"], []).append(target)
        source_groups = sorted(targets_by_source.items())
        for source_index, (source, source_targets) in enumerate(source_groups):
            target_root = (
                temp_root
                / "targets"
                / f"{source_index:03d}-{Path(source).stem}"
            )
            target_out = target_root / "out"
            target_cache = target_root / "cache"
            target_build_info = target_root / "build-info"
            print(
                f"[{source_index + 1}/{len(source_groups)}] building "
                f"{source} ({len(source_targets)} configured target"
                f"{'s' if len(source_targets) != 1 else ''})",
                flush=True,
            )
            runner(
                forge_command(
                    forge_bin,
                    repo_root,
                    foundry_config_path,
                    source,
                    target_out,
                    target_cache,
                    target_build_info,
                ),
                repo_root,
            )
            compiler_input = load_build_info_input(
                target_build_info,
                source,
            )
            validate_compiler_input(
                repo_root,
                compiler_input,
                source,
            )
            compiler_input_relative = (
                Path("compiler-inputs")
                / f"{source_index:03d}-{Path(source).stem}.json"
            )
            compiler_input_destination = staged / compiler_input_relative
            compiler_input_destination.parent.mkdir(parents=True, exist_ok=True)
            compiler_input_destination.write_bytes(ordered_json_bytes(compiler_input))
            for target in source_targets:
                artifact_path = find_target_artifact(target_out, target)
                _, bindings = validate_target_artifact(
                    repo_root,
                    artifact_path,
                    target,
                    foundry_config_path,
                    compiler_input,
                )
                relative_artifact = (
                    Path(Path(target["source"]).name) / f"{target['name']}.json"
                )
                destination = staged / relative_artifact
                if destination.exists():
                    raise ReleaseBuildError(
                        f"configured targets collide at {relative_artifact.as_posix()}"
                    )
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(artifact_path, destination)
                records.append(
                    {
                        **target,
                        "artifact_path": normalize_path(
                            output_dir / relative_artifact,
                            repo_root,
                        ),
                        "artifact_relative_path": relative_artifact.as_posix(),
                        "artifact_sha256": file_sha256(destination),
                        "compiler_input_path": normalize_path(
                            output_dir / compiler_input_relative,
                            repo_root,
                        ),
                        "compiler_input_relative_path": compiler_input_relative.as_posix(),
                        "compiler_input_sha256": file_sha256(
                            compiler_input_destination
                        ),
                        **bindings,
                    }
                )

        records.sort(key=lambda item: (item["kind"], item["name"], item["source"]))

        manifest = build_manifest(
            repo_root,
            config_path,
            foundry_config_path,
            output_dir,
            records,
            forge_version,
        )
        write_json(staged / MANIFEST_FILENAME, manifest)
        validate_release_output(
            repo_root,
            config_path,
            foundry_config_path,
            staged,
            declared_output_dir=output_dir,
            expected_forge_version=forge_version,
        )
        replace_output_directory(staged, output_dir, temp_root)

    return validate_release_output(
        repo_root,
        config_path,
        foundry_config_path,
        output_dir,
        expected_forge_version=forge_version,
    )


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--foundry-config", type=Path, default=DEFAULT_FOUNDRY_CONFIG)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--forge-bin", default="forge")
    parser.add_argument("--check", action="store_true")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    try:
        config_path = resolve_repo_path(repo_root, args.config, "contract config")
        foundry_config_path = resolve_repo_path(
            repo_root,
            args.foundry_config,
            "Foundry config",
        )
        output_dir = resolve_canonical_output_path(repo_root, args.output_dir)
        if args.check:
            forge_version = read_forge_version(args.forge_bin, repo_root)
            manifest = validate_release_output(
                repo_root,
                config_path,
                foundry_config_path,
                output_dir,
                expected_forge_version=forge_version,
            )
            print(
                "canonical release build is current "
                f"({len(manifest['targets'])} isolated targets)"
            )
            return 0
        manifest = build_release_output(
            repo_root,
            config_path,
            foundry_config_path,
            output_dir,
            args.forge_bin,
        )
    except (OSError, ReleaseBuildError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(
        f"{normalize_path(output_dir, repo_root)}/{MANIFEST_FILENAME} "
        f"({len(manifest['targets'])} isolated targets)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
