#!/usr/bin/env python3
"""Generate checksum-bound planning evidence for post-entropy mint completion gas."""

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
BYTECODE_PROOF_PATH = REPO_ROOT / "release-artifacts/latest/bytecode-release-proof.json"
FOUNDRY_CONFIG_PATH = REPO_ROOT / "foundry.toml"
HARNESS_PATH = REPO_ROOT / "test/helpers/StreamPostEntropyCompletionGasHarness.sol"
MEASUREMENT_TEST_PATH = REPO_ROOT / "test/StreamPostEntropyCompletionGas.t.sol"
NORMATIVE_PATHS = (
    REPO_ROOT / "docs/stream-entropy-coordinator.md",
    REPO_ROOT / "docs/launch-conformance-matrix.md",
    REPO_ROOT / "docs/launch-v1-target-architecture.md",
)
SNAPSHOT_TEST = (
    "StreamPostEntropyCompletionGasTest:"
    "testMeasureWorstCaseEoaPostCoordinatorTail()"
)
SCHEMA_VERSION = "6529stream.post-entropy-mint-completion-gas.v1"
MARGIN_BPS = 2_500
ROUNDING_QUANTUM_GAS = 1_000
REFERENCE_REGISTRATION_GAS_LIMIT = 120_000
SNAPSHOT_LINE_RE = re.compile(
    r"^(?P<test>[^ ]+) \(gas: (?P<gas>[0-9]+)\)$"
)
RESERVE_CONSTANT_RE = re.compile(
    r"uint256 public constant POST_ENTROPY_PARENT_RESERVE = (?P<value>[0-9_]+);"
)


class CompletionGasGenerationError(ValueError):
    """Raised when the planning evidence cannot be generated deterministically."""


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
    proof = json.loads(BYTECODE_PROOF_PATH.read_text(encoding="utf-8"))
    rows = [
        row
        for row in proof.get("contract_proofs", [])
        if row.get("contract", {}).get("name") == "StreamCore"
    ]
    if not rows:
        raise CompletionGasGenerationError("bytecode proof has no StreamCore rows")
    sizes = {
        (
            row["sizes"]["runtime_bytecode_bytes"],
            row["sizes"]["runtime_margin_bytes"],
            row["source_verification"]["source_sha256"],
        )
        for row in rows
    }
    if len(sizes) != 1:
        raise CompletionGasGenerationError(
            "bytecode proof StreamCore rows disagree on source or runtime size"
        )
    runtime_bytes, margin_bytes, source_sha256 = next(iter(sizes))
    core_path = REPO_ROOT / "smart-contracts/StreamCore.sol"
    if source_sha256 != f"sha256:{file_sha256(core_path)}":
        raise CompletionGasGenerationError(
            "bytecode proof StreamCore source hash is stale"
        )
    return {
        "implementation_status": "target_fixture_only",
        "stream_core_source": _source_binding(core_path),
        "stream_core_runtime_bytes": runtime_bytes,
        "stream_core_eip170_margin_bytes": margin_bytes,
        "stream_core_delta_bytes": 0,
        "production_complete_runtime_ceiling_bytes": 22_576,
        "approved_runtime_objective_bytes": 22_184,
        "implementation_owner": "#654",
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
        "status": "planning_target_fixture",
        "issue": 672,
        "compiler_profile": _compiler_profile(),
        "sources": [
            _source_binding(MEASUREMENT_TEST_PATH),
            _source_binding(HARNESS_PATH),
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
                "ceil(registrationGasLimit * 64 / 63) "
                "+ POST_ENTROPY_PARENT_RESERVE"
            ),
            "eip150_numerator": 64,
            "eip150_denominator": 63,
            "measurement_margin_bps": MARGIN_BPS,
            "rounding_quantum_gas": ROUNDING_QUANTUM_GAS,
            "post_entropy_parent_reserve_gas": reserve_gas,
            "reference_registration_gas_limit": REFERENCE_REGISTRATION_GAS_LIMIT,
            "reference_planning_parent_gas_lower_bound": (
                eip150_forwarding_requirement + reserve_gas
            ),
            "registration_gas_limit_source": (
                "live ENTROPY_REGISTRATION_GAS_LIMIT governed parameter"
            ),
            "proof_scope": "planning_eip150_and_eoa_tail_terms_only",
            "excluded_call_boundary_costs": [
                "ABI argument encoding and memory expansion",
                "low-level CALL upfront and dynamic costs",
                "source-level work between the admission check and CALL opcode",
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
            "This is checksum-bound target-fixture planning evidence, not an as-built StreamCore measurement.",
            "The admission formula is a planning lower bound over EIP-150 forwarding and the measured EOA tail; this fixture does not prove an exact as-built gasleft threshold at the low-level CALL boundary.",
            "The target fixture checks the pure below/at/above policy predicate and a high-parent-gas full-stipend path separately; it does not prove full-stipend forwarding from an exact supplied threshold.",
            "Issue #654 must measure and enforce the complete low-level-call admission boundary, including ABI encoding, memory expansion, CALL upfront and dynamic costs, and source-level pre-call work, then prove the exact forwarded stipend and post-return reserve against the linked Core.",
            "The committed governed-parameter inventory remains incomplete and is not updated by this artifact.",
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
