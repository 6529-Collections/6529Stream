#!/usr/bin/env python3
"""Generate checksum-bound as-built evidence for issue #671 shared Core read buffer."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover - exercised by the fallback test.
    tomllib = None  # type: ignore[assignment]


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = REPO_ROOT / "release-artifacts/evidence/royalty-return-gas-buffer.json"
SNAPSHOT_PATH = (
    REPO_ROOT
    / "release-artifacts/baselines/v0.1.0/royalty-return-gas-buffer.snap"
)
RELEASE_BUILD_MANIFEST_PATH = REPO_ROOT / "out-release/release-build-manifest.json"
FOUNDRY_CONFIG_PATH = REPO_ROOT / "foundry.toml"
LIBRARY_PATH = REPO_ROOT / "smart-contracts/StreamCoreReadBuffer.sol"
EXTERNAL_READS_PATH = REPO_ROOT / "smart-contracts/StreamCoreExternalReads.sol"
CORE_PATH = REPO_ROOT / "smart-contracts/StreamCore.sol"
HOST_PATH = REPO_ROOT / "smart-contracts/StreamGasParameterHost.sol"
HARNESS_PATH = REPO_ROOT / "test/helpers/StreamRoyaltyReturnGasBufferHarness.sol"
TEST_PATH = REPO_ROOT / "test/StreamRoyaltyReturnGasBuffer.t.sol"
CORE_TEST_PATH = REPO_ROOT / "test/StreamCorePermanentTarget.t.sol"
NORMATIVE_PATHS = (
    REPO_ROOT / "docs/adr/0017-raise-only-parameter-governance.md",
    REPO_ROOT / "docs/revenue-splits-and-royalties.md",
    REPO_ROOT / "docs/metadata-router-and-renderer.md",
)
SCHEMA_VERSION = "6529stream.royalty-return-gas-buffer.v2"
SNAPSHOT_LINE_RE = re.compile(
    r"^(?P<test>[^ ]+) \(gas: (?P<gas>[0-9]+)\)$"
)
CONSTANT_RE = re.compile(
    r"uint256 public constant (?P<name>[A-Z0-9_]+) = (?P<value>[0-9_]+);"
)
SNAPSHOT_TESTS = (
    "StreamRoyaltyReturnGasBufferTest:testMeasureContractUriFallbackCompletion()",
    "StreamRoyaltyReturnGasBufferTest:testMeasureContractUriMaximumCompletion()",
    "StreamRoyaltyReturnGasBufferTest:testMeasureRoyaltyFallbackCompletion()",
    "StreamRoyaltyReturnGasBufferTest:testMeasureRoyaltySuccessCompletion()",
    "StreamRoyaltyReturnGasBufferTest:testMeasureTokenUriFallbackCompletion()",
    "StreamRoyaltyReturnGasBufferTest:testMeasureTokenUriMaximumCompletion()",
)
TEST_SCENARIOS = {
    SNAPSHOT_TESTS[0]: "contractURI_fallback",
    SNAPSHOT_TESTS[1]: "contractURI_maximum_canonical_returndata",
    SNAPSHOT_TESTS[2]: "royaltyInfo_malformed_fallback",
    SNAPSHOT_TESTS[3]: "royaltyInfo_canonical_success_and_mulDiv",
    SNAPSHOT_TESTS[4]: "tokenURI_malformed_fallback",
    SNAPSHOT_TESTS[5]: "tokenURI_maximum_canonical_returndata",
}
ROUNDING_QUANTUM_GAS = 10_000
FLOOR_MULTIPLIER = 2
GENESIS_MULTIPLIER = 4
ROYALTY_LIMIT_GENESIS = 50_000
METADATA_LIMIT_GENESIS = 500_000
MAX_METADATA_RETURNDATA = 65_536
ROYALTY_RETURNDATA = 64
TRANSITIONAL_STREAM_CORE_RUNTIME_BYTES = 24_128


class SharedBufferGenerationError(ValueError):
    """Raised when shared-buffer as-built evidence cannot be generated."""


def file_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _source_binding(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise SharedBufferGenerationError(f"required source file missing: {path}")
    return {
        "path": path.relative_to(REPO_ROOT).as_posix(),
        "sha256": f"sha256:{file_sha256(path)}",
        "size_bytes": path.stat().st_size,
    }


def _parse_snapshot() -> dict[str, int]:
    try:
        lines = SNAPSHOT_PATH.read_text(encoding="utf-8").splitlines()
    except FileNotFoundError as exc:
        raise SharedBufferGenerationError(
            f"shared-buffer snapshot missing: {SNAPSHOT_PATH}"
        ) from exc
    parsed: dict[str, int] = {}
    for line in lines:
        if not line.strip():
            continue
        match = SNAPSHOT_LINE_RE.fullmatch(line.strip())
        if match is None:
            raise SharedBufferGenerationError("invalid shared-buffer snapshot line")
        test = match.group("test")
        if test in parsed:
            raise SharedBufferGenerationError(f"duplicate snapshot test: {test}")
        parsed[test] = int(match.group("gas"))
    if tuple(parsed) != SNAPSHOT_TESTS:
        raise SharedBufferGenerationError(
            f"snapshot test set or order drift: expected {SNAPSHOT_TESTS}, got {tuple(parsed)}"
        )
    return parsed


def _round_up(value: int) -> int:
    return (
        (value + ROUNDING_QUANTUM_GAS - 1) // ROUNDING_QUANTUM_GAS
    ) * ROUNDING_QUANTUM_GAS


def _harness_constants() -> dict[str, int]:
    text = HARNESS_PATH.read_text(encoding="utf-8")
    constants = {
        match.group("name"): int(match.group("value").replace("_", ""))
        for match in CONSTANT_RE.finditer(text)
    }
    required = {
        "MAX_METADATA_RETURNDATA",
        "ROYALTY_RETURNDATA",
        "SHARED_BUFFER_FLOOR",
        "SHARED_BUFFER_GENESIS",
        "ROYALTY_LIMIT_GENESIS",
        "METADATA_LIMIT_GENESIS",
    }
    if not required.issubset(constants):
        raise SharedBufferGenerationError(
            f"missing harness constants: {sorted(required - constants.keys())}"
        )
    return constants


def _parse_toml_scalar(value: str) -> Any:
    value = value.strip()
    if value in {"true", "false"}:
        return value == "true"
    if value.startswith('"') and value.endswith('"'):
        return value[1:-1]
    try:
        return int(value)
    except ValueError:
        return value


def _load_foundry_config() -> dict[str, Any]:
    text = FOUNDRY_CONFIG_PATH.read_text(encoding="utf-8")
    if tomllib is not None:
        try:
            return tomllib.loads(text)
        except tomllib.TOMLDecodeError as exc:
            raise SharedBufferGenerationError(f"invalid foundry.toml: {exc}") from exc

    # Python 3.8-3.10 has no stdlib TOML parser. The evidence only consumes
    # scalar keys in [profile.default], so parse that bounded surface without
    # adding a release-tool dependency.
    default: dict[str, Any] = {}
    in_default = False
    in_multiline_array = False
    for raw_line in text.splitlines():
        line = raw_line.split("#", 1)[0].strip()
        if not line:
            continue
        if in_multiline_array:
            in_multiline_array = not line.endswith("]")
            continue
        if line.startswith("[") and line.endswith("]"):
            in_default = line == "[profile.default]"
            continue
        if in_default and "=" in line:
            key, value = line.split("=", 1)
            scalar = value.strip()
            if scalar.startswith("["):
                in_multiline_array = not scalar.endswith("]")
                continue
            default[key.strip()] = _parse_toml_scalar(scalar)
    return {"profile": {"default": default}}


def _compiler_profile() -> dict[str, Any]:
    config = _load_foundry_config()
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
        raise SharedBufferGenerationError(
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
            "test/StreamRoyaltyReturnGasBuffer.t.sol --match-test testMeasure "
            "--snap release-artifacts/baselines/v0.1.0/"
            "royalty-return-gas-buffer.snap"
        ),
    }


def _stream_core_boundary() -> dict[str, Any]:
    manifest = json.loads(RELEASE_BUILD_MANIFEST_PATH.read_text(encoding="utf-8"))
    rows = [
        row
        for row in manifest.get("targets", [])
        if row.get("kind") == "production_contract"
        and row.get("name") == "StreamCore"
        and row.get("source") == "smart-contracts/StreamCore.sol"
    ]
    if len(rows) != 1:
        raise SharedBufferGenerationError(
            "release build manifest must contain exactly one StreamCore target"
        )
    row = rows[0]
    source_rows = [
        source
        for source in row.get("metadata_sources", [])
        if source.get("path") == "smart-contracts/StreamCore.sol"
    ]
    if len(source_rows) != 1:
        raise SharedBufferGenerationError(
            "release build manifest must bind exactly one StreamCore source"
        )
    source_sha256 = source_rows[0].get("sha256")
    if source_sha256 != f"sha256:{file_sha256(CORE_PATH)}":
        raise SharedBufferGenerationError(
            "release build manifest StreamCore source hash is stale"
        )
    artifact_path = (REPO_ROOT / row["artifact_path"]).resolve()
    if not artifact_path.is_relative_to((REPO_ROOT / "out-release").resolve()):
        raise SharedBufferGenerationError("StreamCore artifact escaped out-release")
    if f"sha256:{file_sha256(artifact_path)}" != row.get("artifact_sha256"):
        raise SharedBufferGenerationError("StreamCore artifact hash is stale")
    artifact = json.loads(artifact_path.read_text(encoding="utf-8"))
    runtime_object = artifact.get("deployedBytecode", {}).get("object")
    if (
        not isinstance(runtime_object, str)
        or not runtime_object.startswith("0x")
        or len(runtime_object) <= 2
        or len(runtime_object[2:]) % 2 != 0
    ):
        raise SharedBufferGenerationError("StreamCore runtime bytecode is malformed")
    runtime_bytes = len(runtime_object[2:]) // 2
    margin_bytes = 24_576 - runtime_bytes
    if runtime_bytes > 22_576:
        raise SharedBufferGenerationError(
            f"as-built StreamCore runtime exceeds the production ceiling: {runtime_bytes}"
        )
    if margin_bytes != 24_576 - runtime_bytes:
        raise SharedBufferGenerationError("bytecode proof StreamCore margin is inconsistent")
    return {
        "implementation_status": "as_built_permanent_core_source",
        "stream_core_source": _source_binding(CORE_PATH),
        "stream_core_runtime_bytes": runtime_bytes,
        "stream_core_eip170_margin_bytes": margin_bytes,
        "transitional_stream_core_runtime_bytes": TRANSITIONAL_STREAM_CORE_RUNTIME_BYTES,
        "stream_core_delta_bytes": runtime_bytes - TRANSITIONAL_STREAM_CORE_RUNTIME_BYTES,
        "production_complete_runtime_ceiling_bytes": 22_576,
        "implementation_owner": "#654 permanent-Core slice",
        "candidate_instance_binding": "missing",
        "candidate_instance_blocked_by": ["#656", "#670"],
    }


def _parent_threshold(gas_limit: int, buffer: int) -> int:
    return gas_limit + (gas_limit + 62) // 63 + buffer


def _validate_as_built_source() -> None:
    library = LIBRARY_PATH.read_text(encoding="utf-8")
    core = CORE_PATH.read_text(encoding="utf-8")
    core_test = CORE_TEST_PATH.read_text(encoding="utf-8")
    for fragment in (
        "gasLimit / 63 + (gasLimit % 63 == 0 ? 0 : 1)",
        "uint256 private constant _MAX_ROUTER_RETURNDATA = 65_536;",
    ):
        if fragment not in f"{library}\n{EXTERNAL_READS_PATH.read_text(encoding='utf-8')}":
            raise SharedBufferGenerationError(
                f"missing as-built shared-buffer source fragment: {fragment}"
            )
    for fragment in (
        "_gasParameters[_GGP_ROYALTY_RETURN_GAS_BUFFER].value",
        "StreamCoreExternalReads.boundedRouterString(",
        "StreamCoreExternalReads.resolveRoyalty(",
    ):
        if fragment not in core:
            raise SharedBufferGenerationError(
                f"missing as-built Core shared-buffer fragment: {fragment}"
            )
    for test_name in (
        "testActualCoreTokenUriBoundaryRejectsBelowAndRoutesAtAndAbove",
        "testActualCoreContractUriBoundaryRejectsBelowAndRoutesAtAndAbove",
        "testMetadataRouterMaximumBoundedReturnCompletes",
        "testMetadataRouterSuccessAndEveryFailureFallsBack",
    ):
        if f"function {test_name}(" not in core_test:
            raise SharedBufferGenerationError(
                f"missing as-built shared-buffer regression test: {test_name}"
            )


def build_evidence() -> dict[str, Any]:
    _validate_as_built_source()
    measurements = _parse_snapshot()
    worst_test, worst_gas = max(measurements.items(), key=lambda item: item[1])
    floor = _round_up(worst_gas * FLOOR_MULTIPLIER)
    genesis = _round_up(worst_gas * GENESIS_MULTIPLIER)
    constants = _harness_constants()
    expected_constants = {
        "MAX_METADATA_RETURNDATA": MAX_METADATA_RETURNDATA,
        "ROYALTY_RETURNDATA": ROYALTY_RETURNDATA,
        "SHARED_BUFFER_FLOOR": floor,
        "SHARED_BUFFER_GENESIS": genesis,
        "ROYALTY_LIMIT_GENESIS": ROYALTY_LIMIT_GENESIS,
        "METADATA_LIMIT_GENESIS": METADATA_LIMIT_GENESIS,
    }
    actual_constants = {
        name: constants[name]
        for name in expected_constants
    }
    if actual_constants != expected_constants:
        raise SharedBufferGenerationError(
            f"harness sizing constants drift: expected {expected_constants}, "
            f"got {actual_constants}"
        )

    return {
        "schema_version": SCHEMA_VERSION,
        "generated_by": "scripts/generate_royalty_return_gas_buffer.py:1",
        "status": "as_built_permanent_core_source",
        "issue": 671,
        "compiler_profile": _compiler_profile(),
        "sources": [
            _source_binding(LIBRARY_PATH),
            _source_binding(EXTERNAL_READS_PATH),
            _source_binding(CORE_PATH),
            _source_binding(HOST_PATH),
            _source_binding(HARNESS_PATH),
            _source_binding(TEST_PATH),
            _source_binding(CORE_TEST_PATH),
            *[_source_binding(path) for path in NORMATIVE_PATHS],
        ],
        "shared_parameter": {
            "family": "GGP",
            "name": "ROYALTY_RETURN_GAS_BUFFER",
            "parameter_id": (
                "0x0af6f5a1a5059e398191fa0af185be12"
                "fee6d609933826603244c7f247793be7"
            ),
            "host_profile": {"id": 1, "key": "STREAM_CORE"},
            "failure_class": {"id": 1, "name": "FORWARDING_CAP"},
            "guarded_consumers": [
                "StreamCore.royaltyInfo(uint256,uint256)",
                "StreamCore.tokenURI(uint256)",
                "StreamCore.contractURI()",
            ],
            "launch_ggp_count": 22,
            "metadata_specific_buffer_added": False,
        },
        "returndata_policy": {
            "royalty_exact_bytes": ROYALTY_RETURNDATA,
            "metadata_max_abi_bytes": MAX_METADATA_RETURNDATA,
            "metadata_max_string_bytes": MAX_METADATA_RETURNDATA - 64,
            "oversized_copy_bytes": 0,
            "required_string_encoding": "canonical_nonempty_abi_string",
            "failure_behavior": "event_free_fallback_return",
        },
        "measurements": {
            "snapshot_path": SNAPSHOT_PATH.relative_to(REPO_ROOT).as_posix(),
            "snapshot_sha256": f"sha256:{file_sha256(SNAPSHOT_PATH)}",
            "boundary": {
                "starts_at": "target_fixture_parent_completion_entry",
                "ends_after": "external_return_copy_and_decode",
                "setup_gas_metering": "paused",
                "scope": "conservative_target_fixture_parent_completion_upper_bound",
            },
            "scenarios": [
                {
                    "test": test,
                    "scenario": TEST_SCENARIOS[test],
                    "measured_gas": gas,
                }
                for test, gas in measurements.items()
            ],
            "worst_test": worst_test,
            "worst_scenario": TEST_SCENARIOS[worst_test],
            "worst_measured_gas": worst_gas,
        },
        "sizing": {
            "rounding_quantum_gas": ROUNDING_QUANTUM_GAS,
            "immutable_floor_multiplier": FLOOR_MULTIPLIER,
            "genesis_multiplier": GENESIS_MULTIPLIER,
            "planning_immutable_floor": floor,
            "planning_genesis_value": genesis,
            "floor_margin_gas": floor - worst_gas,
            "genesis_margin_gas": genesis - worst_gas,
        },
        "admission_model": {
            "formula": "gasLimit + ceil(gasLimit / 63) + sharedBuffer",
            "implementation": "overflow_safe_subtraction_comparisons",
            "residues_tested_mod_63": [0, 1, 62],
            "boundary_points_tested": ["below", "at", "above"],
            "near_uint256_behavior": "no_revert_fail_closed",
            "genesis_examples": [
                {
                    "consumer": "royaltyInfo(uint256,uint256)",
                    "gas_limit": ROYALTY_LIMIT_GENESIS,
                    "minimum_parent_gas": _parent_threshold(
                        ROYALTY_LIMIT_GENESIS, genesis
                    ),
                },
                {
                    "consumer": "tokenURI(uint256)",
                    "gas_limit": METADATA_LIMIT_GENESIS,
                    "minimum_parent_gas": _parent_threshold(
                        METADATA_LIMIT_GENESIS, genesis
                    ),
                },
                {
                    "consumer": "contractURI()",
                    "gas_limit": METADATA_LIMIT_GENESIS,
                    "minimum_parent_gas": _parent_threshold(
                        METADATA_LIMIT_GENESIS, genesis
                    ),
                },
            ],
        },
        "governance_and_raise_chain": {
            "action_class": {"id": 1, "name": "DELAYED_LOOSENING"},
            "minimum_delay_seconds": 172_800,
            "strict_raise_only": True,
            "maximum_raise_multiplier": {"numerator": 2, "denominator": 1},
            "one_write_per_action_per_parameter": True,
            "independent_parameters": [
                "ROYALTY_RESOLVER_GAS_LIMIT",
                "ROYALTY_RETURN_GAS_BUFFER",
                "METADATA_ROUTER_GAS_LIMIT",
            ],
            "tested_orderings": [
                "resolver_twice_then_buffer_then_metadata_twice",
                "buffer_then_metadata_then_resolver",
                "each_limit_and_buffer_repeated_2x_to_uint256_terminal",
            ],
            "maximum_chain_behavior": "no_overflow_and_fail_closed",
            "mutation_authority_from_measurement": False,
            "probe": None,
        },
        "fixed_stipend_compatibility": {
            "status": "missing_candidate_bound_evidence",
            "disposition": "production_gate_conflict_until_all_upstream_budgets_cover_tuple",
            "consumers": [
                "royaltyInfo(uint256,uint256)",
                "tokenURI(uint256)",
                "contractURI()",
            ],
            "raise_review_rule": (
                "replay all three full-call budgets for every proposed resolver, "
                "metadata, or shared-buffer tuple"
            ),
            "blocked_by_issue": "#684",
        },
        "core_boundary": _stream_core_boundary(),
        "limitations": [
            "This artifact binds the conservative target-fixture measurements to the as-built permanent StreamCore source, linked via-IR runtime receipt, and actual Core metadata read boundaries.",
            "The reusable library owns no storage or mutation surface; the permanent Core reads one authenticated shared host row for royaltyInfo, tokenURI, and contractURI.",
            "Actual Core tokenURI and contractURI tests prove below/at/above routing, exact maximum bounded returndata, malformed/oversized fallback, and event-free return handling.",
            "The royalty resolver pointer remains intentionally un-installable until issue #670 supplies the accepted exact interface and concrete target; the target fixture retains royaltyInfo threshold coverage.",
            "Issue #656 must bind the exact deployment candidate, host instance, source verification, and deployed tuple.",
            "Issue #684 must add candidate-instance-bound cadence, fixed-stipend, reproduction, and reachable raise-chain evidence before production.",
            "The committed generic governed-parameter measurement and fixed-stipend fields remain incomplete and fail closed in production mode.",
            "This artifact has no onchain authority, adds no probe or 23rd GGP, and makes no production-readiness claim.",
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
    except (
        SharedBufferGenerationError,
        OSError,
        KeyError,
        json.JSONDecodeError,
    ) as exc:
        print(f"shared-buffer evidence generation failed: {exc}", file=sys.stderr)
        return 1

    output = args.output
    if not output.is_absolute():
        output = REPO_ROOT / output
    if args.check:
        try:
            current = output.read_bytes()
        except FileNotFoundError:
            print(f"shared-buffer evidence missing: {output}", file=sys.stderr)
            return 1
        if current != rendered.encode("utf-8"):
            print("shared-buffer evidence is stale", file=sys.stderr)
            return 1
        print("shared-buffer as-built evidence is current")
        return 0

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(rendered.encode("utf-8"))
    print(f"wrote {output.relative_to(REPO_ROOT).as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
