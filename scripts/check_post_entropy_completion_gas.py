#!/usr/bin/env python3
"""Validate issue #672 post-entropy mint completion planning evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_EVIDENCE = (
    REPO_ROOT / "release-artifacts/post-entropy-mint-completion-gas.json"
)
EXPECTED_SCHEMA_VERSION = "6529stream.post-entropy-mint-completion-gas.v1"
EXPECTED_STATUS = "planning_target_fixture"
EXPECTED_SNAPSHOT_TEST = (
    "StreamPostEntropyCompletionGasTest:"
    "testMeasureWorstCaseEoaPostCoordinatorTail()"
)
EXPECTED_SNAPSHOT_COMMAND = (
    "forge snapshot --via-ir --match-path "
    "test/StreamPostEntropyCompletionGas.t.sol --match-test "
    "testMeasureWorstCaseEoaPostCoordinatorTail --snap "
    "release-artifacts/baselines/v0.1.0/post-entropy-completion-gas.snap"
)
EXPECTED_MEASUREMENT_SCENARIO = {
    "recipient_class": "EOA",
    "storage_state": "first_mint_all_zero_to_nonzero",
    "starts_after": "successful_entropy_coordinator_return",
    "ends_after": "erc721_safe_mint_and_transfer_event",
    "includes": [
        "prepared-state cleanup",
        "collection live-supply write",
        "global live-supply write",
        "token metadata-record write",
        "collection metadata-accumulator write",
        "pending-metadata count write",
        "ERC-721 balance write",
        "ERC-721 owner write",
        "Transfer event",
    ],
}
EXPECTED_ADMISSION_FORMULA = (
    "ceil(registrationGasLimit * 64 / 63) + POST_ENTROPY_PARENT_RESERVE"
)
EXPECTED_REGISTRATION_GAS_LIMIT_SOURCE = (
    "live ENTROPY_REGISTRATION_GAS_LIMIT governed parameter"
)
EXPECTED_ADMISSION_SCOPE = "planning_eip150_and_eoa_tail_terms_only"
EXPECTED_EXCLUDED_CALL_BOUNDARY_COSTS = [
    "ABI argument encoding and memory expansion",
    "low-level CALL upfront and dynamic costs",
    "source-level work between the admission check and CALL opcode",
]
EXPECTED_LIMITATIONS = [
    "This is checksum-bound target-fixture planning evidence, not an as-built StreamCore measurement.",
    "The admission formula is a planning lower bound over EIP-150 forwarding and the measured EOA tail; this fixture does not prove an exact as-built gasleft threshold at the low-level CALL boundary.",
    "The target fixture checks the pure below/at/above policy predicate and a high-parent-gas full-stipend path separately; it does not prove full-stipend forwarding from an exact supplied threshold.",
    "Issue #654 must measure and enforce the complete low-level-call admission boundary, including ABI encoding, memory expansion, CALL upfront and dynamic costs, and source-level pre-call work, then prove the exact forwarded stipend and post-return reserve against the linked Core.",
    "The committed governed-parameter inventory remains incomplete and is not updated by this artifact.",
    "This artifact makes no production-readiness or deployment claim.",
]
SNAPSHOT_LINE_RE = re.compile(
    r"^(?P<test>[^ ]+) \(gas: (?P<gas>[0-9]+)\)$"
)
RESERVE_CONSTANT_RE = re.compile(
    r"uint256 public constant POST_ENTROPY_PARENT_RESERVE = (?P<value>[0-9_]+);"
)
REQUIRED_SPEC_FRAGMENTS = {
    "docs/stream-entropy-coordinator.md": [
        "ceil(ENTROPY_REGISTRATION_GAS_LIMIT * 64 / 63)",
        "post-entropy parent reserve",
        "first-mint, all-zero-to-nonzero EOA-recipient tail",
        "Contract-recipient callback gas is outside this fixed EOA guarantee",
        "planning lower bound, not an as-built exact `gasleft()` threshold",
        "ABI encoding and memory expansion",
        "`CALL` upfront and dynamic costs",
        "Issue #654 must evaluate and measure the complete low-level-call admission boundary",
        "prove the exact forwarded stipend",
    ],
    "docs/launch-conformance-matrix.md": [
        "pure below/at/above policy-predicate tests",
        "separate high-parent-gas full-stipend scenario",
        "actual low-level `CALL` boundary",
        "EOA-recipient completion tail",
    ],
    "docs/launch-v1-target-architecture.md": [
        "post-entropy completion-gas planning evidence",
        "zero `StreamCore` runtime delta",
        "does not prove the exact executable admission threshold",
        "complete pre-call cost and exact-forwarding proof",
    ],
}
FORBIDDEN_SPEC_FRAGMENTS = [
    "contract-recipient callback is guaranteed by the post-entropy reserve",
    "post-entropy completion evidence makes StreamCore production-ready",
    "Core's exact admission requirement is",
    "just below, exactly at, and just above the computed parent threshold",
    "That predecessor pins the EIP-150 ceiling formula, the measured first-mint EOA tail, full-stipend and threshold tests",
]


class CompletionGasCheckError(ValueError):
    """Raised when completion-gas evidence is malformed or stale."""


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _require_mapping(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise CompletionGasCheckError(f"{label} must be an object")
    return value


def _load_evidence(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise CompletionGasCheckError(f"evidence file missing: {path}") from exc
    except json.JSONDecodeError as exc:
        raise CompletionGasCheckError(f"invalid evidence JSON: {exc}") from exc
    return _require_mapping(value, "evidence")


def _validate_source_bindings(evidence: dict[str, Any], repo_root: Path) -> None:
    sources = evidence.get("sources")
    if not isinstance(sources, list) or len(sources) != 5:
        raise CompletionGasCheckError("sources must contain exactly five bindings")
    expected_paths = [
        "test/StreamPostEntropyCompletionGas.t.sol",
        "test/helpers/StreamPostEntropyCompletionGasHarness.sol",
        "docs/stream-entropy-coordinator.md",
        "docs/launch-conformance-matrix.md",
        "docs/launch-v1-target-architecture.md",
    ]
    actual_paths = [row.get("path") for row in sources if isinstance(row, dict)]
    if actual_paths != expected_paths:
        raise CompletionGasCheckError(
            f"source binding order/path mismatch: {actual_paths}"
        )
    for row in sources:
        binding = _require_mapping(row, "source binding")
        path = repo_root / str(binding["path"])
        if not path.is_file():
            raise CompletionGasCheckError(f"bound source missing: {binding['path']}")
        expected_hash = f"sha256:{_sha256(path)}"
        if binding.get("sha256") != expected_hash:
            raise CompletionGasCheckError(
                f"bound source hash mismatch: {binding['path']}"
            )
        if binding.get("size_bytes") != path.stat().st_size:
            raise CompletionGasCheckError(
                f"bound source size mismatch: {binding['path']}"
            )


def _parse_snapshot(path: Path) -> tuple[str, int]:
    lines = [line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    if len(lines) != 1:
        raise CompletionGasCheckError(
            "completion-gas snapshot must contain exactly one measurement"
        )
    match = SNAPSHOT_LINE_RE.fullmatch(lines[0])
    if match is None:
        raise CompletionGasCheckError("invalid completion-gas snapshot line")
    return match.group("test"), int(match.group("gas"))


def _validate_measurement(evidence: dict[str, Any], repo_root: Path) -> int:
    measurement = _require_mapping(evidence.get("measurement"), "measurement")
    snapshot_path = repo_root / str(measurement.get("snapshot_path"))
    if not snapshot_path.is_file():
        raise CompletionGasCheckError("completion-gas snapshot path is missing")
    if measurement.get("snapshot_sha256") != f"sha256:{_sha256(snapshot_path)}":
        raise CompletionGasCheckError("completion-gas snapshot hash mismatch")
    test_name, measured_gas = _parse_snapshot(snapshot_path)
    if test_name != EXPECTED_SNAPSHOT_TEST:
        raise CompletionGasCheckError("completion-gas snapshot test mismatch")
    if measurement.get("snapshot_test") != EXPECTED_SNAPSHOT_TEST:
        raise CompletionGasCheckError("evidence snapshot test mismatch")
    if measurement.get("measured_upper_bound_gas") != measured_gas:
        raise CompletionGasCheckError("measured upper-bound gas mismatch")
    scenario = _require_mapping(measurement.get("scenario"), "measurement scenario")
    if scenario != EXPECTED_MEASUREMENT_SCENARIO:
        raise CompletionGasCheckError("measurement scenario boundary or contents drift")
    return measured_gas


def _validate_admission_model(
    evidence: dict[str, Any], measured_gas: int, repo_root: Path
) -> None:
    model = _require_mapping(evidence.get("admission_model"), "admission_model")
    if model.get("formula") != EXPECTED_ADMISSION_FORMULA:
        raise CompletionGasCheckError("admission formula drift")
    if model.get("proof_scope") != EXPECTED_ADMISSION_SCOPE:
        raise CompletionGasCheckError("admission proof scope drift")
    if (
        model.get("excluded_call_boundary_costs")
        != EXPECTED_EXCLUDED_CALL_BOUNDARY_COSTS
    ):
        raise CompletionGasCheckError("excluded call-boundary costs drift")
    if (
        model.get("registration_gas_limit_source")
        != EXPECTED_REGISTRATION_GAS_LIMIT_SOURCE
    ):
        raise CompletionGasCheckError("registration gas-limit source drift")
    if model.get("eip150_numerator") != 64 or model.get("eip150_denominator") != 63:
        raise CompletionGasCheckError("EIP-150 admission ratio must be 64/63")
    margin_bps = model.get("measurement_margin_bps")
    quantum = model.get("rounding_quantum_gas")
    if margin_bps != 2_500 or quantum != 1_000:
        raise CompletionGasCheckError("completion reserve margin policy drift")
    padded = (measured_gas * (10_000 + margin_bps) + 9_999) // 10_000
    expected_reserve = ((padded + quantum - 1) // quantum) * quantum
    if model.get("post_entropy_parent_reserve_gas") != expected_reserve:
        raise CompletionGasCheckError("post-entropy parent reserve is not measurement-derived")
    reference_limit = model.get("reference_registration_gas_limit")
    if reference_limit != 120_000:
        raise CompletionGasCheckError("reference registration gas limit drift")
    expected_minimum = (
        reference_limit + (reference_limit + 62) // 63 + expected_reserve
    )
    if model.get("reference_planning_parent_gas_lower_bound") != expected_minimum:
        raise CompletionGasCheckError("reference planning parent-gas lower bound mismatch")
    if model.get("legacy_unmeasured_parent_allowance_gas") != 30_000:
        raise CompletionGasCheckError("legacy unmeasured allowance disposition drift")

    harness = (
        repo_root / "test/helpers/StreamPostEntropyCompletionGasHarness.sol"
    ).read_text(encoding="utf-8")
    matches = list(RESERVE_CONSTANT_RE.finditer(harness))
    if len(matches) != 1:
        raise CompletionGasCheckError(
            "expected exactly one POST_ENTROPY_PARENT_RESERVE declaration"
        )
    actual_reserve = int(matches[0].group("value").replace("_", ""))
    if actual_reserve != expected_reserve:
        raise CompletionGasCheckError("harness reserve constant mismatch")


def _validate_core_boundary(evidence: dict[str, Any], repo_root: Path) -> None:
    boundary = _require_mapping(evidence.get("core_boundary"), "core_boundary")
    if boundary.get("implementation_status") != "target_fixture_only":
        raise CompletionGasCheckError("evidence must remain target-fixture-only")
    if boundary.get("stream_core_delta_bytes") != 0:
        raise CompletionGasCheckError("issue #672 must record zero StreamCore delta")
    if boundary.get("stream_core_runtime_bytes") != 24_135:
        raise CompletionGasCheckError("transitional StreamCore runtime drift")
    if (
        boundary.get("stream_core_eip170_margin_bytes")
        != 24_576 - boundary["stream_core_runtime_bytes"]
    ):
        raise CompletionGasCheckError("StreamCore EIP-170 margin is not runtime-derived")
    if boundary.get("production_complete_runtime_ceiling_bytes") != 22_576:
        raise CompletionGasCheckError("production Core ceiling drift")
    if boundary.get("approved_runtime_objective_bytes") != 22_184:
        raise CompletionGasCheckError("approved Core objective drift")
    if boundary.get("implementation_owner") != "#654":
        raise CompletionGasCheckError("actual Core implementation owner must remain #654")
    source = _require_mapping(boundary.get("stream_core_source"), "StreamCore source")
    core_path = repo_root / "smart-contracts/StreamCore.sol"
    if source.get("path") != "smart-contracts/StreamCore.sol":
        raise CompletionGasCheckError("StreamCore source path mismatch")
    if source.get("sha256") != f"sha256:{_sha256(core_path)}":
        raise CompletionGasCheckError("StreamCore source hash mismatch")
    if source.get("size_bytes") != core_path.stat().st_size:
        raise CompletionGasCheckError("StreamCore source size mismatch")


def _validate_callback_scope(evidence: dict[str, Any]) -> None:
    scope = _require_mapping(
        evidence.get("receiver_callback_scope"), "receiver_callback_scope"
    )
    expected = {
        "fixed_reserve_guarantee": "EOA_recipient_only",
        "contract_receiver_callback": "caller_supplied_and_unbounded",
        "failure_behavior": "whole_transaction_revert",
    }
    if scope != expected:
        raise CompletionGasCheckError("receiver callback scope drift")


def _validate_compiler_profile(evidence: dict[str, Any]) -> None:
    profile = _require_mapping(evidence.get("compiler_profile"), "compiler_profile")
    expected = {
        "solc_version": "0.8.19",
        "evm_version": "paris",
        "optimizer_enabled": True,
        "optimizer_runs": 200,
        "via_ir": True,
        "bytecode_hash": "none",
    }
    for key, value in expected.items():
        if profile.get(key) != value:
            raise CompletionGasCheckError(f"compiler profile drift: {key}")
    if profile.get("snapshot_command") != EXPECTED_SNAPSHOT_COMMAND:
        raise CompletionGasCheckError("snapshot command drift")


def _validate_limitations(evidence: dict[str, Any]) -> None:
    if evidence.get("limitations") != EXPECTED_LIMITATIONS:
        raise CompletionGasCheckError("planning limitations drift")


def _validate_spec_fragments(repo_root: Path) -> None:
    for relative_path, fragments in REQUIRED_SPEC_FRAGMENTS.items():
        text = (repo_root / relative_path).read_text(encoding="utf-8")
        normalized = " ".join(text.split())
        for fragment in fragments:
            if " ".join(fragment.split()) not in normalized:
                raise CompletionGasCheckError(
                    f"missing #672 spec fragment in {relative_path}: {fragment}"
                )
    all_text = " ".join(
        (repo_root / path).read_text(encoding="utf-8")
        for path in REQUIRED_SPEC_FRAGMENTS
    )
    all_text = " ".join(all_text.split())
    for fragment in FORBIDDEN_SPEC_FRAGMENTS:
        if " ".join(fragment.split()) in all_text:
            raise CompletionGasCheckError(
                f"forbidden #672 spec claim present: {fragment}"
            )


def validate_evidence(path: Path = DEFAULT_EVIDENCE, repo_root: Path = REPO_ROOT) -> None:
    evidence = _load_evidence(path)
    if evidence.get("schema_version") != EXPECTED_SCHEMA_VERSION:
        raise CompletionGasCheckError("unexpected completion-gas schema version")
    if evidence.get("status") != EXPECTED_STATUS:
        raise CompletionGasCheckError("completion-gas evidence must remain planning")
    if evidence.get("issue") != 672:
        raise CompletionGasCheckError("completion-gas issue binding must be 672")
    _validate_compiler_profile(evidence)
    _validate_source_bindings(evidence, repo_root)
    measured_gas = _validate_measurement(evidence, repo_root)
    _validate_admission_model(evidence, measured_gas, repo_root)
    _validate_callback_scope(evidence)
    _validate_core_boundary(evidence, repo_root)
    _validate_limitations(evidence)
    _validate_spec_fragments(repo_root)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, default=DEFAULT_EVIDENCE)
    args = parser.parse_args(argv)
    evidence = args.evidence
    if not evidence.is_absolute():
        evidence = REPO_ROOT / evidence
    try:
        validate_evidence(evidence)
    except (CompletionGasCheckError, OSError, KeyError, TypeError) as exc:
        print(f"post-entropy completion-gas check failed: {exc}", file=sys.stderr)
        return 1
    print("post-entropy completion-gas planning evidence is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
