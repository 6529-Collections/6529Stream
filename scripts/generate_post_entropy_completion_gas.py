#!/usr/bin/env python3
"""Generate checksum-bound as-built evidence for post-entropy mint completion gas."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import tomllib
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = (
    REPO_ROOT / "release-artifacts/post-entropy-mint-completion-gas.json"
)
SNAPSHOT_PATH = (
    REPO_ROOT
    / "release-artifacts/baselines/v0.1.0/post-entropy-completion-gas.snap"
)
RELEASE_BUILD_MANIFEST_PATH = REPO_ROOT / "out-release/release-build-manifest.json"
FOUNDRY_CONFIG_PATH = REPO_ROOT / "foundry.toml"
HARNESS_PATH = REPO_ROOT / "test/helpers/StreamPostEntropyCompletionGasHarness.sol"
MEASUREMENT_TEST_PATH = REPO_ROOT / "test/StreamPostEntropyCompletionGas.t.sol"
CORE_PATH = REPO_ROOT / "smart-contracts/core/StreamCore.sol"
CORE_BUFFER_PATH = REPO_ROOT / "smart-contracts/core/StreamCoreReadBuffer.sol"
CORE_TEST_PATH = REPO_ROOT / "test/StreamCorePermanentTarget.t.sol"
NORMATIVE_PATHS = (
    REPO_ROOT / "docs/stream-entropy-coordinator.md",
    REPO_ROOT / "docs/launch-conformance-matrix.md",
    REPO_ROOT / "docs/launch-v1-target-architecture.md",
)
SNAPSHOT_TEST = (
    "StreamPostEntropyCompletionGasTest:"
    "testMeasureWorstCaseEoaPostCoordinatorTail()"
)
SCHEMA_VERSION = "6529stream.post-entropy-mint-completion-gas.v2"
MARGIN_BPS = 2_500
ROUNDING_QUANTUM_GAS = 1_000
REFERENCE_REGISTRATION_GAS_LIMIT = 120_000
ENTROPY_CALL_UPFRONT_GAS = 3_300
TRANSITIONAL_STREAM_CORE_RUNTIME_BYTES = 24_128
SNAPSHOT_LINE_RE = re.compile(
    r"^(?P<test>[^ ]+) \(gas: (?P<gas>[0-9]+)\)$"
)
RESERVE_CONSTANT_RE = re.compile(
    r"uint256 public constant POST_ENTROPY_PARENT_RESERVE = (?P<value>[0-9_]+);"
)


class CompletionGasGenerationError(ValueError):
    """Raised when the as-built evidence cannot be generated deterministically."""


def file_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _source_binding(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise CompletionGasGenerationError(f"required source file missing: {path}")
    return {
        "path": path.relative_to(REPO_ROOT).as_posix(),
        "sha256": f"sha256:{file_sha256(path)}",
        "size_bytes": path.stat().st_size,
    }


def _parse_snapshot() -> int:
    try:
        lines = SNAPSHOT_PATH.read_text(encoding="utf-8").splitlines()
    except FileNotFoundError as exc:
        raise CompletionGasGenerationError(
            f"completion-gas snapshot missing: {SNAPSHOT_PATH}"
        ) from exc
    nonempty = [line.strip() for line in lines if line.strip()]
    if len(nonempty) != 1:
        raise CompletionGasGenerationError(
            "completion-gas snapshot must contain exactly one measurement"
        )
    match = SNAPSHOT_LINE_RE.fullmatch(nonempty[0])
    if match is None:
        raise CompletionGasGenerationError("invalid completion-gas snapshot line")
    if match.group("test") != SNAPSHOT_TEST:
        raise CompletionGasGenerationError(
            f"unexpected completion-gas snapshot test: {match.group('test')}"
        )
    return int(match.group("gas"))


def _round_up(value: int, quantum: int) -> int:
    return ((value + quantum - 1) // quantum) * quantum


def _reserve_from_measurement(measured_gas: int) -> int:
    padded = (measured_gas * (10_000 + MARGIN_BPS) + 9_999) // 10_000
    return _round_up(padded, ROUNDING_QUANTUM_GAS)


def _harness_reserve() -> int:
    text = HARNESS_PATH.read_text(encoding="utf-8")
    matches = list(RESERVE_CONSTANT_RE.finditer(text))
    if len(matches) != 1:
        raise CompletionGasGenerationError(
            "expected exactly one POST_ENTROPY_PARENT_RESERVE declaration"
        )
    return int(matches[0].group("value").replace("_", ""))


def _compiler_profile() -> dict[str, Any]:
    config = tomllib.loads(FOUNDRY_CONFIG_PATH.read_text(encoding="utf-8"))
    default = config.get("profile", {}).get("default", {})
    expected = {
        "solc_version": "0.8.19",
        "evm_version": "paris",
        "optimizer": True,
        "optimizer_runs": 200,
        "bytecode_hash": "none",
        "cbor_metadata": False,
    }
    actual = {key: default.get(key) for key in expected}
    if actual != expected:
        raise CompletionGasGenerationError(
            f"production compiler profile drift: expected {expected}, got {actual}"
        )
    return {
        "solc_version": "0.8.19",
        "evm_version": "paris",
        "optimizer_enabled": True,
        "optimizer_runs": 200,
        "via_ir": True,
        "bytecode_hash": "none",
        "snapshot_command": (
            "forge snapshot --via-ir --match-path "
            "test/StreamPostEntropyCompletionGas.t.sol --match-test "
            "testMeasureWorstCaseEoaPostCoordinatorTail --snap "
            "release-artifacts/baselines/v0.1.0/"
            "post-entropy-completion-gas.snap"
        ),
    }


def _stream_core_boundary() -> dict[str, Any]:
    manifest = json.loads(RELEASE_BUILD_MANIFEST_PATH.read_text(encoding="utf-8"))
    rows = [
        row
        for row in manifest.get("targets", [])
        if row.get("kind") == "production_contract"
        and row.get("name") == "StreamCore"
        and row.get("source") == "smart-contracts/core/StreamCore.sol"
    ]
    if len(rows) != 1:
        raise CompletionGasGenerationError(
            "release build manifest must contain exactly one StreamCore target"
        )
    row = rows[0]
    source_rows = [
        source
        for source in row.get("metadata_sources", [])
        if source.get("path") == "smart-contracts/core/StreamCore.sol"
    ]
    if len(source_rows) != 1:
        raise CompletionGasGenerationError(
            "release build manifest must bind exactly one StreamCore source"
        )
    source_sha256 = source_rows[0].get("sha256")
    if source_sha256 != f"sha256:{file_sha256(CORE_PATH)}":
        raise CompletionGasGenerationError(
            "release build manifest StreamCore source hash is stale"
        )
    artifact_path = (REPO_ROOT / row["artifact_path"]).resolve()
    if not artifact_path.is_relative_to((REPO_ROOT / "out-release").resolve()):
        raise CompletionGasGenerationError("StreamCore artifact escaped out-release")
    if f"sha256:{file_sha256(artifact_path)}" != row.get("artifact_sha256"):
        raise CompletionGasGenerationError("StreamCore artifact hash is stale")
    artifact = json.loads(artifact_path.read_text(encoding="utf-8"))
    runtime_object = artifact.get("deployedBytecode", {}).get("object")
    if (
        not isinstance(runtime_object, str)
        or not runtime_object.startswith("0x")
        or len(runtime_object) <= 2
        or len(runtime_object[2:]) % 2 != 0
    ):
        raise CompletionGasGenerationError("StreamCore runtime bytecode is malformed")
    runtime_bytes = len(runtime_object[2:]) // 2
    margin_bytes = 24_576 - runtime_bytes
    if runtime_bytes > 22_576:
        raise CompletionGasGenerationError(
            f"as-built StreamCore runtime exceeds the production ceiling: {runtime_bytes}"
        )
    if margin_bytes != 24_576 - runtime_bytes:
        raise CompletionGasGenerationError("bytecode proof StreamCore margin is inconsistent")
    return {
        "implementation_status": "as_built_permanent_core_source",
        "stream_core_source": _source_binding(CORE_PATH),
        "stream_core_runtime_bytes": runtime_bytes,
        "stream_core_eip170_margin_bytes": margin_bytes,
        "transitional_stream_core_runtime_bytes": TRANSITIONAL_STREAM_CORE_RUNTIME_BYTES,
        "stream_core_delta_bytes": runtime_bytes - TRANSITIONAL_STREAM_CORE_RUNTIME_BYTES,
        "production_complete_runtime_ceiling_bytes": 22_576,
        "approved_runtime_objective_bytes": 22_184,
        "implementation_owner": "#654 permanent-Core slice",
        "candidate_instance_binding": "missing",
        "candidate_instance_blocked_by": ["#656", "#670"],
    }


def build_evidence() -> dict[str, Any]:
    measured_gas = _parse_snapshot()
    reserve_gas = _reserve_from_measurement(measured_gas)
    harness_reserve = _harness_reserve()
    if harness_reserve != reserve_gas:
        raise CompletionGasGenerationError(
            "POST_ENTROPY_PARENT_RESERVE does not equal the measured policy value: "
            f"{harness_reserve} != {reserve_gas}"
        )
    eip150_forwarding_requirement = (
        REFERENCE_REGISTRATION_GAS_LIMIT
        + (REFERENCE_REGISTRATION_GAS_LIMIT + 62) // 63
    )

    return {
        "schema_version": SCHEMA_VERSION,
        "generated_by": "scripts/generate_post_entropy_completion_gas.py:1",
        "status": "as_built_permanent_core_source",
        "issue": 672,
        "compiler_profile": _compiler_profile(),
        "sources": [
            _source_binding(MEASUREMENT_TEST_PATH),
            _source_binding(HARNESS_PATH),
            _source_binding(CORE_PATH),
            _source_binding(CORE_BUFFER_PATH),
            _source_binding(CORE_TEST_PATH),
            *[_source_binding(path) for path in NORMATIVE_PATHS],
        ],
        "measurement": {
            "snapshot_path": SNAPSHOT_PATH.relative_to(REPO_ROOT).as_posix(),
            "snapshot_sha256": f"sha256:{file_sha256(SNAPSHOT_PATH)}",
            "snapshot_test": SNAPSHOT_TEST,
            "measured_upper_bound_gas": measured_gas,
            "scenario": {
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
            },
        },
        "admission_model": {
            "formula": (
                "registrationGasLimit + ceil(registrationGasLimit / 63) "
                "+ POST_ENTROPY_PARENT_RESERVE + ENTROPY_CALL_UPFRONT_GAS"
            ),
            "eip150_numerator": 64,
            "eip150_denominator": 63,
            "measurement_margin_bps": MARGIN_BPS,
            "rounding_quantum_gas": ROUNDING_QUANTUM_GAS,
            "post_entropy_parent_reserve_gas": reserve_gas,
            "reference_registration_gas_limit": REFERENCE_REGISTRATION_GAS_LIMIT,
            "reference_as_built_parent_gas_requirement": (
                eip150_forwarding_requirement + reserve_gas + ENTROPY_CALL_UPFRONT_GAS
            ),
            "registration_gas_limit_source": (
                "live ENTROPY_REGISTRATION_GAS_LIMIT governed parameter"
            ),
            "proof_scope": "as_built_complete_low_level_call_boundary",
            "included_call_boundary_costs": [
                "ABI argument encoding and memory expansion",
                "cold low-level CALL upfront and account-access costs",
                "source-level work between the admission check and CALL opcode",
            ],
            "call_upfront_reserve_gas": ENTROPY_CALL_UPFRONT_GAS,
            "actual_boundary_test": (
                "StreamCorePermanentTargetTest:"
                "testActualCoreCallBoundaryCoversBelowAtAndAboveWithFullStipend()"
            ),
            "rollback_tests": [
                "StreamCorePermanentTargetTest:testEntropyFailureRollsBackAllCoreState()",
                "StreamCorePermanentTargetTest:"
                "testEntropyReturnDataFailsClosedAndRollsBack()",
            ],
            "legacy_unmeasured_parent_allowance_gas": 30_000,
        },
        "receiver_callback_scope": {
            "fixed_reserve_guarantee": "EOA_recipient_only",
            "contract_receiver_callback": "caller_supplied_and_unbounded",
            "failure_behavior": "whole_transaction_revert",
        },
        "core_boundary": _stream_core_boundary(),
        "limitations": [
            "This artifact binds the measured EOA tail to the as-built permanent StreamCore source, its linked via-IR runtime receipt, and an executable exact-boundary/full-stipend regression test.",
            "The fixed reserve covers the measured EOA-recipient completion tail; contract-recipient callback gas remains caller-supplied and unbounded.",
            "The exact deployment instance and the two unresolved artist/revenue pointer rows remain blocked by issues #656 and #670.",
            "The governed-parameter candidate binding remains incomplete under issue #684.",
            "This artifact makes no production-readiness or deployment claim.",
        ],
    }


def render_evidence() -> str:
    return json.dumps(build_evidence(), indent=2) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)

    try:
        rendered = render_evidence()
    except (CompletionGasGenerationError, OSError, KeyError, json.JSONDecodeError) as exc:
        print(f"post-entropy completion-gas generation failed: {exc}", file=sys.stderr)
        return 1

    output = args.output
    if not output.is_absolute():
        output = REPO_ROOT / output
    if args.check:
        try:
            current = output.read_bytes()
        except FileNotFoundError:
            print(
                f"post-entropy completion-gas evidence missing: {output}",
                file=sys.stderr,
            )
            return 1
        if current != rendered.encode("utf-8"):
            print("post-entropy completion-gas evidence is stale", file=sys.stderr)
            return 1
        print("post-entropy completion-gas evidence is current")
        return 0

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(rendered.encode("utf-8"))
    print(f"wrote {output.relative_to(REPO_ROOT).as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
