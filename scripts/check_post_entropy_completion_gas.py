#!/usr/bin/env python3
"""Validate issue #672 as-built post-entropy mint completion evidence."""

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
EXPECTED_SCHEMA_VERSION = "6529stream.post-entropy-mint-completion-gas.v2"
EXPECTED_STATUS = "as_built_permanent_core_source"
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
    "registrationGasLimit + ceil(registrationGasLimit / 63) "
    "+ POST_ENTROPY_PARENT_RESERVE + ENTROPY_CALL_UPFRONT_GAS"
)
EXPECTED_REGISTRATION_GAS_LIMIT_SOURCE = (
    "live ENTROPY_REGISTRATION_GAS_LIMIT governed parameter"
)
EXPECTED_ADMISSION_SCOPE = "as_built_complete_low_level_call_boundary"
EXPECTED_INCLUDED_CALL_BOUNDARY_COSTS = [
    "ABI argument encoding and memory expansion",
    "cold low-level CALL upfront and account-access costs",
    "source-level work between the admission check and CALL opcode",
]
EXPECTED_ACTUAL_BOUNDARY_TEST = (
    "StreamCorePermanentTargetTest:"
    "testActualCoreCallBoundaryRejectsBelowAndForwardsFullStipendAtThreshold()"
)
EXPECTED_ROLLBACK_TESTS = [
    "StreamCorePermanentTargetTest:testEntropyFailureRollsBackAllCoreState()",
    "StreamCorePermanentTargetTest:testEntropyReturnDataFailsClosedAndRollsBack()",
]
EXPECTED_LIMITATIONS = [
    "This artifact binds the measured EOA tail to the as-built permanent StreamCore source, its linked via-IR runtime receipt, and an executable exact-boundary/full-stipend regression test.",
    "The fixed reserve covers the measured EOA-recipient completion tail; contract-recipient callback gas remains caller-supplied and unbounded.",
    "The exact deployment instance and the two unresolved artist/revenue pointer rows remain blocked by issues #656 and #670.",
    "The governed-parameter candidate binding remains incomplete under issue #684.",
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
        "ENTROPY_REGISTRATION_GAS_LIMIT + "
        "ceil(ENTROPY_REGISTRATION_GAS_LIMIT / 63)",
        "post-entropy parent reserve",
        "first-mint, all-zero-to-nonzero EOA-recipient tail",
        "Contract-recipient callback gas is outside this fixed EOA guarantee",
        "encodes the coordinator calldata before the admission check",
        "3,300-gas cold `CALL` upfront reserve",
        "testActualCoreCallBoundaryRejectsBelowAndForwardsFullStipendAtThreshold",
    ],
    "docs/launch-conformance-matrix.md": [
        "as-built permanent-Core below/at/above call-boundary test",
        "exact governed stipend",
        "EOA-recipient completion tail",
    ],
    "docs/launch-v1-target-architecture.md": [
        "as-built permanent-Core entropy registration",
        "ABI encoding precedes the parent-gas admission check",
        "cold-call upfront reserve",
        "candidate instance remains blocked by #656 and #670",
    ],
}
FORBIDDEN_SPEC_FRAGMENTS = [
    "contract-recipient callback is guaranteed by the post-entropy reserve",
    "post-entropy completion evidence makes StreamCore production-ready",
    "Issue #654 must evaluate and measure the complete low-level-call admission boundary",
    "This is checksum-bound target-fixture planning evidence, not an as-built StreamCore measurement.",
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
    if not isinstance(sources, list) or len(sources) != 8:
        raise CompletionGasCheckError("sources must contain exactly eight bindings")
    expected_paths = [
        "test/StreamPostEntropyCompletionGas.t.sol",
        "test/helpers/StreamPostEntropyCompletionGasHarness.sol",
        "smart-contracts/core/StreamCore.sol",
        "smart-contracts/core/StreamCoreReadBuffer.sol",
        "test/StreamCorePermanentTarget.t.sol",
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
    if model.get("included_call_boundary_costs") != EXPECTED_INCLUDED_CALL_BOUNDARY_COSTS:
        raise CompletionGasCheckError("included call-boundary costs drift")
    if model.get("call_upfront_reserve_gas") != 3_300:
        raise CompletionGasCheckError("cold CALL upfront reserve drift")
    if model.get("actual_boundary_test") != EXPECTED_ACTUAL_BOUNDARY_TEST:
        raise CompletionGasCheckError("actual Core boundary test drift")
    if model.get("rollback_tests") != EXPECTED_ROLLBACK_TESTS:
        raise CompletionGasCheckError("entropy rollback test set drift")
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
        reference_limit + (reference_limit + 62) // 63 + expected_reserve + 3_300
    )
    if model.get("reference_as_built_parent_gas_requirement") != expected_minimum:
        raise CompletionGasCheckError("reference as-built parent-gas requirement mismatch")
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
    if boundary.get("implementation_status") != "as_built_permanent_core_source":
        raise CompletionGasCheckError("evidence must bind the as-built permanent Core source")
    runtime_bytes = boundary.get("stream_core_runtime_bytes")
    if not isinstance(runtime_bytes, int) or isinstance(runtime_bytes, bool):
        raise CompletionGasCheckError("StreamCore runtime must be an integer")
    if runtime_bytes > 22_576:
        raise CompletionGasCheckError("as-built StreamCore exceeds the production ceiling")
    if boundary.get("transitional_stream_core_runtime_bytes") != 24_128:
        raise CompletionGasCheckError("transitional StreamCore baseline drift")
    if boundary.get("stream_core_delta_bytes") != runtime_bytes - 24_128:
        raise CompletionGasCheckError("StreamCore delta is not runtime-derived")
    if (
        boundary.get("stream_core_eip170_margin_bytes")
        != 24_576 - runtime_bytes
    ):
        raise CompletionGasCheckError("StreamCore EIP-170 margin is not runtime-derived")
    if boundary.get("production_complete_runtime_ceiling_bytes") != 22_576:
        raise CompletionGasCheckError("production Core ceiling drift")
    if boundary.get("approved_runtime_objective_bytes") != 22_184:
        raise CompletionGasCheckError("approved Core objective drift")
    if boundary.get("implementation_owner") != "#654 permanent-Core slice":
        raise CompletionGasCheckError("actual Core implementation owner must remain #654")
    if boundary.get("candidate_instance_binding") != "missing":
        raise CompletionGasCheckError("candidate instance must remain honestly unbound")
    if boundary.get("candidate_instance_blocked_by") != ["#656", "#670"]:
        raise CompletionGasCheckError("candidate instance blocker set drift")
    source = _require_mapping(boundary.get("stream_core_source"), "StreamCore source")
    core_path = repo_root / "smart-contracts/core/StreamCore.sol"
    if source.get("path") != "smart-contracts/core/StreamCore.sol":
        raise CompletionGasCheckError("StreamCore source path mismatch")
    if source.get("sha256") != f"sha256:{_sha256(core_path)}":
        raise CompletionGasCheckError("StreamCore source hash mismatch")
    if source.get("size_bytes") != core_path.stat().st_size:
        raise CompletionGasCheckError("StreamCore source size mismatch")

    core = core_path.read_text(encoding="utf-8")
    core_test = (repo_root / "test/StreamCorePermanentTarget.t.sol").read_text(
        encoding="utf-8"
    )
    required_core_fragments = (
        "uint256 private constant _ENTROPY_PARENT_GAS_RESERVE = 162_000;",
        "uint256 private constant _ENTROPY_CALL_UPFRONT_GAS = 3_300;",
        "bytes memory callData = abi.encodeWithSelector(",
        "_ENTROPY_PARENT_GAS_RESERVE + _ENTROPY_CALL_UPFRONT_GAS",
        "if (!ok || returnSize != 0) revert EntropyRegistrationFailed();",
    )
    for fragment in required_core_fragments:
        if fragment not in core:
            raise CompletionGasCheckError(
                f"missing as-built entropy boundary fragment: {fragment}"
            )
    for test_name in (
        "testActualCoreCallBoundaryRejectsBelowAndForwardsFullStipendAtThreshold",
        "testEntropyFailureRollsBackAllCoreState",
        "testEntropyReturnDataFailsClosedAndRollsBack",
    ):
        if f"function {test_name}(" not in core_test:
            raise CompletionGasCheckError(
                f"missing as-built entropy regression test: {test_name}"
            )


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
        raise CompletionGasCheckError("as-built limitations drift")


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
        raise CompletionGasCheckError("completion-gas evidence must bind the as-built Core")
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
    print("post-entropy completion-gas as-built evidence is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
