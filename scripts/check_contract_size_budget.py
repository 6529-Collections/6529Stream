#!/usr/bin/env python3
"""Check production runtime bytecode sizes against the release budget."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Sequence

import build_release_artifacts as release_build


BUDGET_SCHEMA = "6529stream.contract-runtime-size-budget.v1"
DEFAULT_CONFIG = release_build.DEFAULT_CONFIG
DEFAULT_FOUNDRY_CONFIG = release_build.DEFAULT_FOUNDRY_CONFIG
DEFAULT_FOUNDRY_OUT = release_build.DEFAULT_OUTPUT_DIR
EXPECTED_SOLC_VERSION = "0.8.19+commit.7dd6d404"
EXPECTED_EVM_VERSION = "paris"
EXPECTED_OPTIMIZER_RUNS = 200
CANONICAL_RELEASE_BUILD_COMMAND = release_build.CANONICAL_BUILD_COMMAND
HEX_RE = re.compile(r"^[0-9a-fA-F]*$")
SOLIDITY_LINK_PLACEHOLDER_RE = re.compile(r"__\$[0-9a-fA-F]{34}\$__")


class SizeBudgetError(RuntimeError):
    pass


def load_json(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except OSError as exc:
        raise SizeBudgetError(f"cannot read required file {path}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise SizeBudgetError(f"invalid JSON in {path}: {exc}") from exc


def load_receipt_bound_json(path: Path, expected_sha256: str, label: str) -> Any:
    """Read, hash, and parse one exact file version from a validated receipt."""
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise SizeBudgetError(f"cannot read {label} {path}: {exc}") from exc
    actual_sha256 = release_build.sha256_bytes(raw)
    if actual_sha256 != expected_sha256:
        raise SizeBudgetError(
            f"{label} no longer matches the validated canonical release receipt: "
            f"expected {expected_sha256}, got {actual_sha256}"
        )
    try:
        return json.loads(raw.decode("utf-8"))
    except UnicodeDecodeError as exc:
        raise SizeBudgetError(f"{label} is not UTF-8: {path}") from exc
    except json.JSONDecodeError as exc:
        raise SizeBudgetError(f"invalid JSON in {path}: {exc}") from exc


def require_dict(value: Any, path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise SizeBudgetError(f"{path} must be an object")
    return value


def require_int(value: Any, path: str) -> int:
    if not isinstance(value, int) or isinstance(value, bool):
        raise SizeBudgetError(f"{path} must be an integer")
    return value


def require_string(value: Any, path: str) -> str:
    if not isinstance(value, str) or value == "":
        raise SizeBudgetError(f"{path} must be a non-empty string")
    return value


def keccak256_hex(data: bytes) -> str:
    try:
        from eth_hash.auto import keccak

        return "0x" + keccak(data).hex()
    except ImportError:
        pass

    try:
        from Crypto.Hash import keccak as crypto_keccak

        digest = crypto_keccak.new(digest_bits=256)
        digest.update(data)
        return "0x" + digest.hexdigest()
    except ImportError as exc:
        raise SizeBudgetError(
            "Ethereum Keccak support is required to validate artifact source hashes; "
            "install the project's required tool environment before running the size "
            "budget checker; release and audit jobs must use the hashed "
            "requirements-tools.lock"
        ) from exc


def normalize_path(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def production_contracts(config: dict[str, Any]) -> dict[str, dict[str, Any]]:
    contracts = config.get("production_contracts")
    if not isinstance(contracts, list) or not contracts:
        raise SizeBudgetError("production_contracts must be a non-empty list")

    by_name: dict[str, dict[str, Any]] = {}
    for index, entry in enumerate(contracts):
        record = require_dict(entry, f"production_contracts[{index}]")
        name = require_string(record.get("name"), f"production_contracts[{index}].name")
        if name in by_name:
            raise SizeBudgetError(f"duplicate production contract: {name}")
        by_name[name] = record
    return by_name


def load_release_config(
    repo_root: Path,
    config_path: Path,
    release_manifest: dict[str, Any] | None = None,
) -> dict[str, Any]:
    config_abs = config_path if config_path.is_absolute() else repo_root / config_path
    if release_manifest is None:
        return require_dict(load_json(config_abs), str(config_abs))

    source = require_dict(release_manifest.get("source"), "release build manifest.source")
    recorded_path = require_string(
        source.get("config"),
        "release build manifest.source.config",
    )
    if normalize_path(config_abs, repo_root) != recorded_path:
        raise SizeBudgetError("contract config path does not match the validated release receipt")
    expected_sha256 = require_string(
        source.get("config_sha256"),
        "release build manifest.source.config_sha256",
    )
    return require_dict(
        load_receipt_bound_json(config_abs, expected_sha256, "contract config"),
        str(config_abs),
    )


def receipt_artifact(
    release_manifest: dict[str, Any],
    foundry_out: Path,
    repo_root: Path,
    name: str,
    source: str,
) -> tuple[Path, dict[str, Any]]:
    records = release_manifest.get("targets")
    if not isinstance(records, list):
        raise SizeBudgetError("release build manifest.targets must be an array")
    matches = []
    for index, value in enumerate(records):
        record = require_dict(value, f"release build manifest.targets[{index}]")
        if record.get("kind") == "production_contract" and record.get("name") == name:
            matches.append(record)
    if len(matches) != 1:
        raise SizeBudgetError(
            f"validated release receipt must contain exactly one production artifact for {name}"
        )

    record = matches[0]
    if record.get("source") != source:
        raise SizeBudgetError(f"validated release receipt source is stale for {name}")
    relative = Path(
        require_string(
            record.get("artifact_relative_path"),
            f"release build manifest target {name}.artifact_relative_path",
        )
    )
    if relative.is_absolute() or ".." in relative.parts:
        raise SizeBudgetError(f"validated release receipt artifact path is unsafe for {name}")
    artifact_path = foundry_out / relative
    recorded_artifact_path = require_string(
        record.get("artifact_path"),
        f"release build manifest target {name}.artifact_path",
    )
    if normalize_path(artifact_path, repo_root) != recorded_artifact_path:
        raise SizeBudgetError(f"validated release receipt artifact path is stale for {name}")
    expected_sha256 = require_string(
        record.get("artifact_sha256"),
        f"release build manifest target {name}.artifact_sha256",
    )
    artifact = require_dict(
        load_receipt_bound_json(
            artifact_path,
            expected_sha256,
            f"canonical artifact for {name}",
        ),
        str(artifact_path),
    )
    return artifact_path, artifact


def find_artifact(foundry_out: Path, name: str, source: str | None) -> Path:
    if source:
        direct = foundry_out / Path(source).name / f"{name}.json"
        if direct.exists():
            return direct

    matches = sorted(foundry_out.glob(f"**/{name}.json"))
    if not matches:
        raise SizeBudgetError(f"could not find Foundry artifact for {name} under {foundry_out}")
    if len(matches) > 1:
        locations = ", ".join(str(match) for match in matches)
        raise SizeBudgetError(f"ambiguous Foundry artifact for {name}: {locations}")
    return matches[0]


def deployed_runtime_size_bytes(artifact: dict[str, Any], artifact_path: Path) -> int:
    deployed = require_dict(artifact.get("deployedBytecode"), f"{artifact_path}.deployedBytecode")
    bytecode = require_string(deployed.get("object"), f"{artifact_path}.deployedBytecode.object")
    hex_value = bytecode[2:] if bytecode.startswith("0x") else bytecode
    linked_equivalent = SOLIDITY_LINK_PLACEHOLDER_RE.sub("0" * 40, hex_value)
    if len(linked_equivalent) % 2 != 0 or not HEX_RE.fullmatch(linked_equivalent):
        raise SizeBudgetError(
            f"{artifact_path}.deployedBytecode.object must be hex or Solidity link placeholders"
        )
    return len(linked_equivalent) // 2


def artifact_profile_error(artifact_path: Path, reason: str) -> SizeBudgetError:
    return SizeBudgetError(
        f"{artifact_path} is not a current canonical release artifact: {reason}. "
        f"Run `{CANONICAL_RELEASE_BUILD_COMMAND}` before checking runtime budgets."
    )


def metadata_source_path(repo_root: Path, source_key: str) -> Path | None:
    source_path = (repo_root / Path(source_key)).resolve()
    try:
        source_path.relative_to(repo_root.resolve())
    except ValueError:
        return None
    return source_path


def artifact_metadata(artifact: dict[str, Any], artifact_path: Path) -> dict[str, Any]:
    value = artifact.get("metadata")
    if value is None:
        value = artifact.get("rawMetadata")
    if isinstance(value, dict):
        return value
    if isinstance(value, str) and value:
        try:
            return require_dict(json.loads(value), f"{artifact_path}.metadata")
        except json.JSONDecodeError as exc:
            raise artifact_profile_error(artifact_path, f"metadata is invalid JSON: {exc}") from exc
    raise artifact_profile_error(artifact_path, "metadata is missing")


def validate_current_production_artifact(
    repo_root: Path,
    artifact: dict[str, Any],
    artifact_path: Path,
    contract_name: str,
    source: str,
) -> None:
    metadata = artifact_metadata(artifact, artifact_path)
    compiler = require_dict(metadata.get("compiler"), f"{artifact_path}.metadata.compiler")
    compiler_version = require_string(
        compiler.get("version"),
        f"{artifact_path}.metadata.compiler.version",
    )
    if compiler_version != EXPECTED_SOLC_VERSION:
        raise artifact_profile_error(
            artifact_path,
            f"compiler version is {compiler_version}, expected {EXPECTED_SOLC_VERSION}",
        )

    settings = require_dict(metadata.get("settings"), f"{artifact_path}.metadata.settings")
    evm_version = require_string(
        settings.get("evmVersion"),
        f"{artifact_path}.metadata.settings.evmVersion",
    )
    if evm_version != EXPECTED_EVM_VERSION:
        raise artifact_profile_error(
            artifact_path,
            f"EVM version is {evm_version}, expected {EXPECTED_EVM_VERSION}",
        )

    optimizer = require_dict(
        settings.get("optimizer"),
        f"{artifact_path}.metadata.settings.optimizer",
    )
    if optimizer.get("enabled") is not True:
        raise artifact_profile_error(artifact_path, "optimizer is not enabled")
    optimizer_runs = require_int(
        optimizer.get("runs"),
        f"{artifact_path}.metadata.settings.optimizer.runs",
    )
    if optimizer_runs != EXPECTED_OPTIMIZER_RUNS:
        raise artifact_profile_error(
            artifact_path,
            f"optimizer runs are {optimizer_runs}, expected {EXPECTED_OPTIMIZER_RUNS}",
        )

    normalized_source = Path(source).as_posix()
    compilation_target = require_dict(
        settings.get("compilationTarget"),
        f"{artifact_path}.metadata.settings.compilationTarget",
    )
    if compilation_target.get(normalized_source) != contract_name:
        raise artifact_profile_error(
            artifact_path,
            f"compilation target does not identify {normalized_source}:{contract_name}",
        )

    sources = require_dict(metadata.get("sources"), f"{artifact_path}.metadata.sources")
    require_dict(
        sources.get(normalized_source),
        f"{artifact_path}.metadata.sources.{normalized_source}",
    )

    for source_key in sorted(sources):
        source_metadata = require_dict(
            sources.get(source_key),
            f"{artifact_path}.metadata.sources.{source_key}",
        )
        recorded_hash = require_string(
            source_metadata.get("keccak256"),
            f"{artifact_path}.metadata.sources.{source_key}.keccak256",
        )
        source_path = metadata_source_path(repo_root, source_key)
        if source_path is None or not source_path.is_file():
            if source_key == normalized_source:
                raise artifact_profile_error(
                    artifact_path,
                    f"source file is missing: {repo_root / normalized_source}",
                )
            continue
        actual_hash = keccak256_hex(source_path.read_bytes())
        if recorded_hash.lower() != actual_hash.lower():
            raise artifact_profile_error(
                artifact_path,
                f"source hash for {source_key} does not match the current checkout",
            )


def budget_contracts(config: dict[str, Any]) -> tuple[int, dict[str, dict[str, Any]]]:
    budget = require_dict(config.get("runtime_size_budget"), "runtime_size_budget")
    schema = require_string(budget.get("schema_version"), "runtime_size_budget.schema_version")
    if schema != BUDGET_SCHEMA:
        raise SizeBudgetError(f"runtime_size_budget.schema_version must be {BUDGET_SCHEMA}")
    eip_170_limit = require_int(
        budget.get("eip_170_runtime_limit_bytes"),
        "runtime_size_budget.eip_170_runtime_limit_bytes",
    )
    if eip_170_limit <= 0:
        raise SizeBudgetError("runtime_size_budget.eip_170_runtime_limit_bytes must be positive")
    contracts = require_dict(budget.get("contracts"), "runtime_size_budget.contracts")
    if not contracts:
        raise SizeBudgetError("runtime_size_budget.contracts must not be empty")
    return eip_170_limit, {str(name): require_dict(value, f"runtime_size_budget.contracts.{name}") for name, value in contracts.items()}


def build_report(
    repo_root: Path,
    config_path: Path,
    foundry_out: Path,
    release_manifest: dict[str, Any] | None = None,
) -> list[dict[str, Any]]:
    foundry_out_abs = foundry_out if foundry_out.is_absolute() else repo_root / foundry_out
    config = load_release_config(repo_root, config_path, release_manifest)
    production = production_contracts(config)
    default_limit, budgets = budget_contracts(config)

    report = []
    for name in sorted(budgets):
        if name not in production:
            raise SizeBudgetError(f"runtime_size_budget contract is not production-listed: {name}")

    for name in sorted(production):
        production_entry = production[name]
        budget = budgets.get(name, {})
        source = require_string(production_entry.get("source"), f"production_contracts.{name}.source")
        configured_source = budget.get("source")
        if configured_source is not None and configured_source != source:
            raise SizeBudgetError(f"{name} budget source does not match production source")

        if release_manifest is None:
            artifact_path = find_artifact(foundry_out_abs, name, source)
            artifact = require_dict(load_json(artifact_path), str(artifact_path))
        else:
            artifact_path, artifact = receipt_artifact(
                release_manifest,
                foundry_out_abs,
                repo_root,
                name,
                source,
            )
        validate_current_production_artifact(repo_root, artifact, artifact_path, name, source)
        runtime_size = deployed_runtime_size_bytes(artifact, artifact_path)
        runtime_limit = require_int(
            budget.get("runtime_limit_bytes", default_limit),
            f"runtime_size_budget.contracts.{name}.runtime_limit_bytes",
        )
        if runtime_limit <= 0:
            raise SizeBudgetError(f"{name} runtime limit must be positive")
        if name in budgets:
            minimum_margin = require_int(
                budget.get("minimum_runtime_margin_bytes"),
                f"runtime_size_budget.contracts.{name}.minimum_runtime_margin_bytes",
            )
            warning_margin = require_int(
                budget.get("warning_runtime_margin_bytes", minimum_margin),
                f"runtime_size_budget.contracts.{name}.warning_runtime_margin_bytes",
            )
        else:
            minimum_margin = 0
            warning_margin = 0
        if minimum_margin < 0 or warning_margin < minimum_margin:
            raise SizeBudgetError(f"{name} has invalid runtime margin thresholds")

        margin = runtime_limit - runtime_size
        status = "pass"
        if margin < minimum_margin:
            status = "fail"
        elif margin < warning_margin:
            status = "warn"
        report.append(
            {
                "contract": name,
                "source": source,
                "artifact": normalize_path(artifact_path, repo_root),
                "runtime_size_bytes": runtime_size,
                "runtime_limit_bytes": runtime_limit,
                "runtime_margin_bytes": margin,
                "minimum_runtime_margin_bytes": minimum_margin,
                "warning_runtime_margin_bytes": warning_margin,
                "status": status,
                "tracking": budget.get("tracking", ""),
            }
        )
    return report


def validate_canonical_release_output(
    repo_root: Path,
    config_path: Path,
    foundry_config_path: Path,
    foundry_out: Path,
) -> dict[str, Any]:
    try:
        return release_build.validate_release_output(
            repo_root,
            config_path,
            foundry_config_path,
            foundry_out,
        )
    except (OSError, release_build.ReleaseBuildError) as exc:
        raise SizeBudgetError(
            f"canonical release output validation failed: {exc}"
        ) from exc


def print_report(report: list[dict[str, Any]]) -> None:
    for row in report:
        print(
            "{contract}: runtime {runtime_size_bytes} bytes, margin {runtime_margin_bytes} "
            "bytes, minimum {minimum_runtime_margin_bytes}, warning "
            "{warning_runtime_margin_bytes} [{status}]".format(**row)
        )


def check_report(report: list[dict[str, Any]]) -> int:
    failing = [row for row in report if row["status"] == "fail"]
    if failing:
        for row in failing:
            print(
                "error: {contract} runtime margin {runtime_margin_bytes} is below "
                "minimum {minimum_runtime_margin_bytes}; see {tracking}. If this "
                f"uses stale or non-canonical artifacts, rerun "
                f"`{CANONICAL_RELEASE_BUILD_COMMAND}`".format(
                    **row
                ),
                file=sys.stderr,
            )
        return 1

    warnings = [row for row in report if row["status"] == "warn"]
    for row in warnings:
        print(
            "warning: {contract} runtime margin {runtime_margin_bytes} is below "
            "warning threshold {warning_runtime_margin_bytes}; see {tracking}".format(**row),
            file=sys.stderr,
        )
    return 0


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument(
        "--foundry-config",
        type=Path,
        default=DEFAULT_FOUNDRY_CONFIG,
    )
    parser.add_argument("--foundry-out", type=Path, default=DEFAULT_FOUNDRY_OUT)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    repo_root = args.repo_root.resolve()
    try:
        release_manifest = validate_canonical_release_output(
            repo_root,
            args.config,
            args.foundry_config,
            args.foundry_out,
        )
        report = build_report(
            repo_root,
            args.config,
            args.foundry_out,
            release_manifest,
        )
    except SizeBudgetError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    print_report(report)
    return check_report(report)


if __name__ == "__main__":
    sys.exit(main())
