#!/usr/bin/env python3
"""Check that StreamCore bytecode spend is reviewed before it grows."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Sequence

import check_contract_size_budget


POLICY_SCHEMA = "6529stream.core-bytecode-spend-policy.v1"
DEFAULT_CONFIG = Path("release-artifacts/contracts.json")
DEFAULT_FOUNDRY_OUT = Path("out")
DEFAULT_CONTRACT = "StreamCore"
DOC_BASELINE_PATHS = (Path("docs/architecture.md"), Path("docs/tooling.md"))
EXCEPTION_STATUSES = {"accepted", "rejected", "superseded"}


class CoreBytecodePolicyError(RuntimeError):
    pass


def load_json(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise CoreBytecodePolicyError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise CoreBytecodePolicyError(f"invalid JSON in {path}: {exc}") from exc


def require_dict(value: Any, path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise CoreBytecodePolicyError(f"{path} must be an object")
    return value


def require_string(value: Any, path: str) -> str:
    if not isinstance(value, str) or value == "":
        raise CoreBytecodePolicyError(f"{path} must be a non-empty string")
    return value


def require_int(value: Any, path: str) -> int:
    if not isinstance(value, int) or isinstance(value, bool):
        raise CoreBytecodePolicyError(f"{path} must be an integer")
    return value


def core_policy(config: dict[str, Any]) -> dict[str, Any]:
    policy = require_dict(config.get("core_bytecode_spend_policy"), "core_bytecode_spend_policy")
    schema = require_string(
        policy.get("schema_version"), "core_bytecode_spend_policy.schema_version"
    )
    if schema != POLICY_SCHEMA:
        raise CoreBytecodePolicyError(
            f"core_bytecode_spend_policy.schema_version must be {POLICY_SCHEMA}"
        )
    contract = require_string(policy.get("contract"), "core_bytecode_spend_policy.contract")
    if contract != DEFAULT_CONTRACT:
        raise CoreBytecodePolicyError(
            f"core_bytecode_spend_policy.contract must be {DEFAULT_CONTRACT}"
        )
    baseline = require_int(
        policy.get("approved_runtime_size_bytes"),
        "core_bytecode_spend_policy.approved_runtime_size_bytes",
    )
    if baseline <= 0:
        raise CoreBytecodePolicyError(
            "core_bytecode_spend_policy.approved_runtime_size_bytes must be positive"
        )
    require_string(policy.get("tracking"), "core_bytecode_spend_policy.tracking")
    exceptions = policy.get("exceptions", [])
    if not isinstance(exceptions, list):
        raise CoreBytecodePolicyError("core_bytecode_spend_policy.exceptions must be a list")
    rejected = policy.get("rejected_experiments", [])
    if not isinstance(rejected, list):
        raise CoreBytecodePolicyError(
            "core_bytecode_spend_policy.rejected_experiments must be a list"
        )
    reductions = policy.get("accepted_reductions", [])
    if not isinstance(reductions, list):
        raise CoreBytecodePolicyError(
            "core_bytecode_spend_policy.accepted_reductions must be a list"
        )
    for index, reduction in enumerate(reductions):
        validate_accepted_reduction(reduction, index)
    return policy


def validate_accepted_reduction(reduction: Any, index: int) -> None:
    record = require_dict(reduction, f"core_bytecode_spend_policy.accepted_reductions[{index}]")
    for key in ("id", "issue", "summary", "decision"):
        require_string(
            record.get(key), f"core_bytecode_spend_policy.accepted_reductions[{index}].{key}"
        )
    baseline = require_int(
        record.get("baseline_runtime_size_bytes"),
        f"core_bytecode_spend_policy.accepted_reductions[{index}].baseline_runtime_size_bytes",
    )
    runtime_size = require_int(
        record.get("runtime_size_bytes"),
        f"core_bytecode_spend_policy.accepted_reductions[{index}].runtime_size_bytes",
    )
    measured_delta = require_int(
        record.get("measured_delta_bytes"),
        f"core_bytecode_spend_policy.accepted_reductions[{index}].measured_delta_bytes",
    )
    runtime_margin = require_int(
        record.get("runtime_margin_bytes"),
        f"core_bytecode_spend_policy.accepted_reductions[{index}].runtime_margin_bytes",
    )
    if baseline <= 0 or runtime_size <= 0:
        raise CoreBytecodePolicyError(
            f"core_bytecode_spend_policy.accepted_reductions[{index}] runtime sizes "
            "must be positive"
        )
    if runtime_margin <= 0:
        raise CoreBytecodePolicyError(
            f"core_bytecode_spend_policy.accepted_reductions[{index}].runtime_margin_bytes "
            "must be positive"
        )
    if runtime_size >= baseline:
        raise CoreBytecodePolicyError(
            f"core_bytecode_spend_policy.accepted_reductions[{index}].runtime_size_bytes "
            "must be smaller than the reduction baseline"
        )
    expected_delta = runtime_size - baseline
    if measured_delta != expected_delta:
        raise CoreBytecodePolicyError(
            f"core_bytecode_spend_policy.accepted_reductions[{index}].measured_delta_bytes "
            f"must equal runtime_size_bytes minus baseline_runtime_size_bytes "
            f"({expected_delta})"
        )
    if measured_delta >= 0:
        raise CoreBytecodePolicyError(
            f"core_bytecode_spend_policy.accepted_reductions[{index}].measured_delta_bytes "
            "must be negative for accepted headroom recovery"
        )


def accepted_exception_maximum(exception: Any, index: int) -> int | None:
    record = require_dict(exception, f"core_bytecode_spend_policy.exceptions[{index}]")
    status = require_string(
        record.get("status"), f"core_bytecode_spend_policy.exceptions[{index}].status"
    )
    if status not in EXCEPTION_STATUSES:
        raise CoreBytecodePolicyError(
            f"core_bytecode_spend_policy.exceptions[{index}].status must be one of "
            f"{', '.join(sorted(EXCEPTION_STATUSES))}"
        )
    if status != "accepted":
        return None
    for key in ("id", "issue", "rationale", "mitigation"):
        require_string(record.get(key), f"core_bytecode_spend_policy.exceptions[{index}].{key}")
    maximum = require_int(
        record.get("max_runtime_size_bytes"),
        f"core_bytecode_spend_policy.exceptions[{index}].max_runtime_size_bytes",
    )
    measured_delta = require_int(
        record.get("measured_delta_bytes"),
        f"core_bytecode_spend_policy.exceptions[{index}].measured_delta_bytes",
    )
    if maximum <= 0:
        raise CoreBytecodePolicyError(
            f"core_bytecode_spend_policy.exceptions[{index}].max_runtime_size_bytes "
            "must be positive"
        )
    if measured_delta <= 0:
        raise CoreBytecodePolicyError(
            f"core_bytecode_spend_policy.exceptions[{index}].measured_delta_bytes "
            "must be positive for accepted Core spend"
        )
    return maximum


def assert_margin_consistency(config: dict[str, Any], policy: dict[str, Any]) -> None:
    budget = require_dict(config.get("runtime_size_budget"), "runtime_size_budget")
    runtime_limit = require_int(
        budget.get("eip_170_runtime_limit_bytes"),
        "runtime_size_budget.eip_170_runtime_limit_bytes",
    )
    baseline = require_int(
        policy.get("approved_runtime_size_bytes"),
        "core_bytecode_spend_policy.approved_runtime_size_bytes",
    )
    approved_margin = require_int(
        policy.get("approved_runtime_margin_bytes"),
        "core_bytecode_spend_policy.approved_runtime_margin_bytes",
    )
    expected_margin = runtime_limit - baseline
    if approved_margin != expected_margin:
        raise CoreBytecodePolicyError(
            "core_bytecode_spend_policy.approved_runtime_margin_bytes must equal "
            f"runtime limit {runtime_limit} minus approved runtime {baseline}; "
            f"expected {expected_margin}, got {approved_margin}"
        )


def assert_docs_match_baseline(repo_root: Path, baseline: int, margin: int) -> None:
    baseline_text = f"{baseline:,}"
    margin_text = f"{margin:,}"
    for path in DOC_BASELINE_PATHS:
        doc_path = repo_root / path
        try:
            text = doc_path.read_text(encoding="utf-8")
        except FileNotFoundError as exc:
            raise CoreBytecodePolicyError(f"missing required baseline doc: {path}") from exc
        if baseline_text not in text:
            raise CoreBytecodePolicyError(
                f"{path} must mention approved StreamCore runtime {baseline_text} bytes"
            )
        if margin_text not in text:
            raise CoreBytecodePolicyError(
                f"{path} must mention approved StreamCore margin {margin_text} bytes"
            )


def current_core_size(repo_root: Path, config_path: Path, foundry_out: Path) -> int:
    report = check_contract_size_budget.build_report(repo_root, config_path, foundry_out)
    for row in report:
        if row["contract"] == DEFAULT_CONTRACT:
            return int(row["runtime_size_bytes"])
    raise CoreBytecodePolicyError(f"{DEFAULT_CONTRACT} was not present in the size report")


def check_policy(repo_root: Path, config_path: Path, foundry_out: Path) -> int:
    config_abs = config_path if config_path.is_absolute() else repo_root / config_path
    config = require_dict(load_json(config_abs), str(config_abs))
    policy = core_policy(config)
    assert_margin_consistency(config, policy)
    baseline = require_int(
        policy.get("approved_runtime_size_bytes"),
        "core_bytecode_spend_policy.approved_runtime_size_bytes",
    )
    margin = require_int(
        policy.get("approved_runtime_margin_bytes"),
        "core_bytecode_spend_policy.approved_runtime_margin_bytes",
    )
    assert_docs_match_baseline(repo_root, baseline, margin)
    runtime_size = current_core_size(repo_root, config_path, foundry_out)
    if runtime_size <= baseline:
        print(
            f"{DEFAULT_CONTRACT}: runtime {runtime_size} bytes, approved baseline "
            f"{baseline} bytes [pass]"
        )
        return 0

    accepted_maximums = [
        maximum
        for index, exception in enumerate(policy.get("exceptions", []))
        if (maximum := accepted_exception_maximum(exception, index)) is not None
    ]
    approved_maximum = max(accepted_maximums, default=baseline)
    if runtime_size <= approved_maximum:
        print(
            f"{DEFAULT_CONTRACT}: runtime {runtime_size} bytes exceeds baseline {baseline} "
            f"but is covered by accepted exception maximum {approved_maximum} [pass]"
        )
        return 0

    print(
        f"error: {DEFAULT_CONTRACT} runtime {runtime_size} bytes exceeds approved baseline "
        f"{baseline} bytes without a covering accepted bytecode-spend exception",
        file=sys.stderr,
    )
    return 1


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--foundry-out", type=Path, default=DEFAULT_FOUNDRY_OUT)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    repo_root = args.repo_root.resolve()
    try:
        return check_policy(repo_root, args.config, args.foundry_out)
    except (CoreBytecodePolicyError, check_contract_size_budget.SizeBudgetError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
