#!/usr/bin/env python3
"""Hostile tests for the fail-closed canonical deployment executor."""

from __future__ import annotations

import copy
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import execute_canonical_deployment_plan as executor


SENDER = "0x0000000000000000000000000000000000000011"
DEPLOYED = executor.create_address(SENDER, 0)
TX_HASH = "0x" + ("33" * 32)
BLOCK_HASH = "0x" + ("44" * 32)
TIP_HASH = "0x" + ("55" * 32)
INITCODE = "0x6000"
RUNTIME = "0x6001"


def plan_document(
    *,
    production: bool = False,
    v2: bool = False,
) -> dict[str, object]:
    if v2:
        production = True
    return {
        "release_posture": {
            "production_candidate": production,
            "status": (
                "candidate_complete_tooling_only"
                if v2
                else "non_production_tooling_only"
            ),
        },
        "candidate": {
            "candidate_id": "fixture",
            "sha256": "sha256:" + ("11" * 32),
            "schema_version": (
                executor.materializer.CANDIDATE_V2_SCHEMA
                if v2
                else executor.materializer.CANDIDATE_SCHEMA
            ),
            "candidate_kind": (
                "genesis_release_candidate"
                if v2
                else "non_production_fixture"
            ),
            "candidate_identity_sha256": (
                "sha256:" + ("77" * 32) if v2 else None
            ),
            "candidate_identity_keccak256": (
                "0x" + ("88" * 32) if v2 else None
            ),
        },
        "release_build": {
            "receipt_sha256": "sha256:" + ("22" * 32),
            "target_catalog_sha256": "sha256:" + ("33" * 32),
            "config_sha256": "sha256:" + ("55" * 32),
            "foundry_config_sha256": "sha256:" + ("66" * 32),
        },
        "network": {
            "environment": "local" if v2 else "anvil",
            "chain_id": 31337,
        },
        "deployments": [
            {
                "order": 1,
                "instance_id": "fixture",
                "target": {
                    "name": "Fixture",
                    "source": "smart-contracts/Fixture.sol",
                },
                "artifact": {
                    "path": "out-release/Fixture.sol/Fixture.json",
                    "sha256": "sha256:" + ("44" * 32),
                },
                "constructor": {
                    "canonical_types": [],
                    "arguments": [],
                    "encoded_args": "0x",
                    "encoded_args_keccak256": executor.materializer.keccak256_hex(
                        b""
                    ),
                },
                "libraries": [],
                "immutables": [],
                "linked_creation_bytecode_keccak256": (
                    executor.materializer.keccak256_hex(
                        bytes.fromhex(INITCODE[2:])
                    )
                ),
                "initcode": INITCODE,
                "initcode_length_bytes": 2,
                "initcode_keccak256": executor.materializer.keccak256_hex(
                    bytes.fromhex(INITCODE[2:])
                ),
                "expected_runtime_bytecode": RUNTIME,
                "expected_runtime_length_bytes": 2,
                "expected_runtime_keccak256": executor.materializer.keccak256_hex(
                    bytes.fromhex(RUNTIME[2:])
                ),
                **({"expected_address": DEPLOYED} if v2 else {}),
            }
        ],
    }


def journal_identity(
    *,
    chain_id: int = 31337,
    network: dict[str, object] | None = None,
) -> dict[str, object]:
    plan = plan_document()
    plan_sha256 = "sha256:" + ("11" * 32)
    network = network or {
        "environment": "anvil",
        "chain_id": chain_id,
        "execution_mode": "anvil",
        "rpc_scope": "ephemeral_loopback_anvil",
    }
    return {
        "schema_version": executor.JOURNAL_SCHEMA,
        "execution_key": executor.execution_key(plan_sha256, chain_id, SENDER),
        "plan_sha256": plan_sha256,
        "candidate_id": plan["candidate"]["candidate_id"],
        "release_receipt_sha256": plan["release_build"]["receipt_sha256"],
        "target_catalog_sha256": plan["release_build"]["target_catalog_sha256"],
        "release_config_sha256": plan["release_build"]["config_sha256"],
        "release_foundry_config_sha256": plan["release_build"][
            "foundry_config_sha256"
        ],
        "executor_script_sha256": "sha256:" + ("71" * 32),
        "executor_foundry_config_sha256": "sha256:" + ("72" * 32),
        "executor_driver_sha256": "sha256:" + ("73" * 32),
        "execution_schema_sha256": "sha256:" + ("74" * 32),
        "network": network,
        "chain_id": chain_id,
        "sender": SENDER,
        "deployment_authority": [
            executor.deployment_authority_record(plan["deployments"][0])
        ],
    }


def address_info(*addresses: str) -> list[tuple[object, ...]]:
    results: list[tuple[object, ...]] = []
    for address in addresses:
        parsed = executor.ipaddress.ip_address(address)
        family = executor.socket.AF_INET if parsed.version == 4 else executor.socket.AF_INET6
        sockaddr: tuple[object, ...] = (
            (address, 443)
            if parsed.version == 4
            else (address, 443, 0, 0)
        )
        results.append((family, executor.socket.SOCK_STREAM, 6, "", sockaddr))
    return results


def broadcast_document() -> dict[str, object]:
    return {
        "transactions": [
            {
                "hash": TX_HASH,
                "transactionType": "CREATE",
                "contractName": None,
                "contractAddress": DEPLOYED,
                "transaction": {
                    "from": SENDER,
                    "to": None,
                    "gas": "0x100000",
                    "value": "0x0",
                    "input": INITCODE,
                    "nonce": "0x0",
                    "chainId": "0x7a69",
                },
                "additionalContracts": [],
            }
        ],
        "receipts": [
            {
                "transactionHash": TX_HASH,
                "status": "0x1",
                "from": SENDER,
                "to": None,
                "contractAddress": DEPLOYED,
            }
        ],
        "libraries": [],
        "pending": [],
        "chain": 31337,
    }


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def prepare_executor_files(root: Path) -> None:
    for path, content in (
        (executor.DEFAULT_FOUNDRY_CONFIG, "[profile.default]\n"),
        (executor.DEFAULT_SCRIPT, "// test broadcaster\n"),
        (executor.EXECUTOR_DRIVER_PATH, "# test executor driver\n"),
        (executor.EXECUTION_SCHEMA_PATH, "{}\n"),
    ):
        target = root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")


class FakeRpc:
    def __init__(self, *, runtime: str = RUNTIME) -> None:
        self.runtime = runtime

    def __call__(self, method: str, params: object) -> object:
        if method == "eth_getTransactionByHash":
            return {
                "hash": TX_HASH,
                "from": SENDER,
                "to": None,
                "value": "0x0",
                "input": INITCODE,
                "nonce": "0x0",
                "chainId": "0x7a69",
                "blockNumber": "0x1",
                "blockHash": BLOCK_HASH,
            }
        if method == "eth_getTransactionReceipt":
            return {
                "transactionHash": TX_HASH,
                "status": "0x1",
                "from": SENDER,
                "to": None,
                "contractAddress": DEPLOYED,
                "blockNumber": "0x1",
                "blockHash": BLOCK_HASH,
            }
        if method == "eth_blockNumber":
            return "0x1"
        if method == "eth_getBlockByNumber":
            return {"hash": BLOCK_HASH}
        if method == "eth_getBlockByHash":
            return {"number": "0x1", "hash": BLOCK_HASH}
        if method == "eth_getCode":
            return self.runtime
        raise AssertionError(f"unexpected RPC method {method}: {params}")


class CanonicalSnapshotTests(unittest.TestCase):
    def test_exact_snapshot_is_bound_and_mutation_is_rejected(self) -> None:
        plan = plan_document()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            plan_path = root / "tmp/plan.json"
            plan_path.parent.mkdir(parents=True)
            raw = executor.materializer.json_text(plan).encode("utf-8")
            plan_path.write_bytes(raw)
            with mock.patch.object(
                executor.materializer,
                "materialize_deployment_plan",
                return_value=plan,
            ):
                _, actual_raw, digest = executor.canonical_plan_snapshot(
                    root,
                    root / "candidate.json",
                    plan_path,
                )
                self.assertEqual(raw, actual_raw)
                self.assertEqual(executor.prefixed_sha256(raw), digest)

                plan_path.write_bytes(raw + b" ")
                with self.assertRaisesRegex(
                    executor.CanonicalExecutionError,
                    "stale or mutated",
                ):
                    executor.canonical_plan_snapshot(
                        root,
                        root / "candidate.json",
                        plan_path,
                    )

    def test_production_candidate_is_hard_failed(self) -> None:
        plan = plan_document(production=True)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            plan_path = root / "tmp/plan.json"
            plan_path.parent.mkdir(parents=True)
            plan_path.write_bytes(
                executor.materializer.json_text(plan).encode("utf-8")
            )
            with mock.patch.object(
                executor.materializer,
                "materialize_deployment_plan",
                return_value=plan,
            ):
                with self.assertRaisesRegex(
                    executor.CanonicalExecutionError,
                    "invalid authority posture",
                ):
                    executor.canonical_plan_snapshot(
                        root,
                        root / "candidate.json",
                        plan_path,
                    )

    def test_v2_identity_fields_are_validated_before_execution(self) -> None:
        cases = (
            (
                "candidate_identity_sha256",
                "sha256:" + ("zz" * 32),
                "candidate.candidate_identity_sha256 must be a lowercase "
                "sha256: digest",
            ),
            (
                "candidate_identity_keccak256",
                "0x" + ("zz" * 32),
                "candidate.candidate_identity_keccak256 must be a 32-byte "
                "0x-prefixed hash",
            ),
        )
        for field, malformed, expected_error in cases:
            with self.subTest(field=field), tempfile.TemporaryDirectory() as directory:
                plan = plan_document(v2=True)
                plan["candidate"][field] = malformed
                root = Path(directory)
                plan_path = root / "tmp/plan.json"
                plan_path.parent.mkdir(parents=True)
                plan_path.write_bytes(
                    executor.materializer.json_text(plan).encode("utf-8")
                )
                with mock.patch.object(
                    executor.materializer,
                    "materialize_deployment_plan",
                    return_value=plan,
                ):
                    with self.assertRaises(
                        executor.CanonicalExecutionError
                    ) as raised:
                        executor.canonical_plan_snapshot(
                            root,
                            root / "candidate.json",
                            plan_path,
                        )
                self.assertEqual(str(raised.exception), expected_error)


class CandidateAddressBindingTests(unittest.TestCase):
    def test_v2_create_sequence_accepts_exact_sender_nonce_order(self) -> None:
        plan = plan_document(v2=True)
        self.assertEqual(
            executor.require_v2_expected_create_addresses(
                plan,
                sender=SENDER,
                starting_nonce=0,
            ),
            [DEPLOYED],
        )

    def test_v2_create_sequence_rejects_omission_sender_nonce_and_drift(self) -> None:
        cases: list[tuple[str, dict[str, object], str, int, str]] = []
        missing = plan_document(v2=True)
        del missing["deployments"][0]["expected_address"]
        cases.append(("missing", missing, SENDER, 0, "expected_address"))
        cases.append(
            (
                "wrong-sender",
                plan_document(v2=True),
                "0x0000000000000000000000000000000000000012",
                0,
                "does not match CREATE address",
            )
        )
        cases.append(
            (
                "wrong-nonce",
                plan_document(v2=True),
                SENDER,
                1,
                "does not match CREATE address",
            )
        )
        drifted = plan_document(v2=True)
        drifted["deployments"][0]["expected_address"] = (
            "0x00000000000000000000000000000000000000ff"
        )
        cases.append(
            (
                "drifted-address",
                drifted,
                SENDER,
                0,
                "does not match CREATE address",
            )
        )
        for name, plan, sender, nonce, expected_error in cases:
            with self.subTest(case=name), self.assertRaisesRegex(
                executor.CanonicalExecutionError,
                expected_error,
            ):
                executor.require_v2_expected_create_addresses(
                    plan,
                    sender=sender,
                    starting_nonce=nonce,
                )

    def test_library_consumer_address_drift_fails_before_forge(self) -> None:
        plan = plan_document(v2=True)
        library = plan["deployments"][0]
        library["instance_id"] = "fixture-library"
        wrong_library_address = executor.create_address(SENDER, 7)
        library["expected_address"] = wrong_library_address
        consumer = copy.deepcopy(library)
        consumer["order"] = 2
        consumer["instance_id"] = "fixture-consumer"
        consumer["expected_address"] = executor.create_address(SENDER, 1)
        consumer["libraries"] = [
            {
                "source": "smart-contracts/FixtureLibrary.sol",
                "name": "FixtureLibrary",
                "address": wrong_library_address,
                "creation_positions": [],
                "runtime_positions": [],
            }
        ]
        plan["deployments"] = [library, consumer]
        raw = executor.materializer.json_text(plan).encode("utf-8")
        digest = executor.prefixed_sha256(raw)
        command_runner = mock.Mock()
        forge_command = mock.Mock()

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = root / "tmp/address-drift.json"
            prepare_executor_files(root)

            def rpc(method: str, params: object) -> object:
                if method == "eth_chainId":
                    return "0x7a69"
                if method == "eth_getTransactionCount":
                    return "0x0"
                raise AssertionError(f"unexpected RPC method {method}: {params}")

            with (
                mock.patch.object(
                    executor,
                    "canonical_plan_snapshot",
                    return_value=(plan, raw, digest),
                ),
                mock.patch.object(
                    executor,
                    "validate_broadcaster_source",
                    return_value=executor.prefixed_sha256(
                        (root / executor.DEFAULT_SCRIPT).read_bytes()
                    ),
                ),
                mock.patch.object(
                    executor,
                    "forge_command",
                    forge_command,
                ),
                self.assertRaisesRegex(
                    executor.CanonicalExecutionError,
                    "fixture-library expected address .* does not match CREATE",
                ),
            ):
                executor.execute_plan(
                    root,
                    root / "candidate.json",
                    root / "tmp/plan.json",
                    output,
                    rpc_url="http://127.0.0.1:8545",
                    sender=SENDER,
                    signer_cli=["--unlocked"],
                    execution_mode="local",
                    ephemeral_local=False,
                    command_runner=command_runner,
                    rpc=rpc,
                )
        forge_command.assert_not_called()
        command_runner.assert_not_called()


class IsolationTests(unittest.TestCase):
    def test_execution_surfaces_do_not_bind_raw_candidate_artifact_sha(self) -> None:
        scripts_root = Path(__file__).resolve().parent
        repo_root = scripts_root.parent
        executor_source = (
            scripts_root / "execute_canonical_deployment_plan.py"
        ).read_text(encoding="utf-8")
        receipt_schema = (
            repo_root / executor.EXECUTION_SCHEMA_PATH
        ).read_text(encoding="utf-8")
        self.assertNotIn("candidate_sha256", executor_source)
        self.assertNotIn("candidate_sha256", receipt_schema)

    def test_ambient_foundry_and_dapp_settings_are_removed(self) -> None:
        env = executor.forge_environment(
            {
                "PATH": "safe",
                "FOUNDRY_OUT": "hostile",
                "DAPP_LIBRARIES": "hostile",
                "ETH_PRIVATE_KEY": "hostile",
                "AWS_SECRET_ACCESS_KEY": "hostile",
                "GITHUB_TOKEN": "hostile",
            },
            rpc_url="http://127.0.0.1:8545",
            sender=SENDER,
            plan_path=Path("deployments/plan.json"),
            plan_sha256="sha256:" + ("aa" * 32),
            deployment_index=0,
            deployment_count=1,
            session_root=Path("tmp/session"),
            broadcast_root=Path("tmp/broadcast"),
        )
        self.assertEqual("safe", env["PATH"])
        self.assertNotIn("DAPP_LIBRARIES", env)
        self.assertNotIn("ETH_PRIVATE_KEY", env)
        self.assertNotIn("AWS_SECRET_ACCESS_KEY", env)
        self.assertNotIn("GITHUB_TOKEN", env)
        self.assertEqual(Path("tmp/session/out"), Path(env["FOUNDRY_OUT"]))
        self.assertEqual(Path("tmp/session/cache"), Path(env["FOUNDRY_CACHE_PATH"]))

    def test_compiler_closure_rejects_production_source(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            session = Path(directory)
            build_info = session / "out/build-info/fixture.json"
            write_json(
                build_info,
                {
                    "source_id_to_path": {
                        "0": "DeployCanonicalInitcode.s.sol",
                        "1": "smart-contracts/core/StreamCore.sol",
                    }
                },
            )
            with self.assertRaisesRegex(
                executor.CanonicalExecutionError,
                "compiler closure",
            ):
                executor.validate_build_closure(session)

    def test_broadcaster_source_rejects_production_import(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            script = root / "bad.s.sol"
            script.write_text(
                'import "../smart-contracts/core/StreamCore.sol";\n',
                encoding="utf-8",
            )
            with self.assertRaisesRegex(
                executor.CanonicalExecutionError,
                "forbidden token",
            ):
                executor.validate_broadcaster_source(root, script)

    def test_receipt_paths_reuse_exact_canonical_portable_policy(self) -> None:
        schema = executor.materializer.load_json(
            Path(__file__).resolve().parent.parent / executor.EXECUTION_SCHEMA_PATH
        )
        self.assertEqual(
            executor.materializer.REPO_PATH_PATTERN,
            schema["$defs"]["repo_path"]["pattern"],
        )
        for hostile in (
            "CON",
            "reports/aux.json",
            "reports/name. ",
            "reports/trailing.",
        ):
            deployment = plan_document()["deployments"][0]
            deployment["target"]["source"] = hostile
            with self.subTest(hostile=hostile), self.assertRaisesRegex(
                executor.CanonicalExecutionError,
                "normalized portable",
            ):
                executor.deployment_authority_record(deployment)


class NetworkAndSignerTests(unittest.TestCase):
    def test_execution_mode_cannot_relabel_or_reach_live_mainnet(self) -> None:
        plan = plan_document()
        with self.assertRaisesRegex(
            executor.CanonicalExecutionError,
            "requires --local-anvil",
        ):
            executor.execution_network_record(
                plan,
                rpc_url="http://127.0.0.1:8545",
                execution_mode="anvil",
                live_broadcast_authorized=False,
                ephemeral_local=False,
            )

        plan["network"] = {"environment": "fork", "chain_id": 1}
        with self.assertRaisesRegex(
            executor.CanonicalExecutionError,
            "chain-31337 plan",
        ):
            executor.execution_network_record(
                plan,
                rpc_url="http://127.0.0.1:8545",
                execution_mode="fork",
                live_broadcast_authorized=False,
                ephemeral_local=False,
            )

    def test_sepolia_requires_exact_chain_and_explicit_live_authorization(self) -> None:
        plan = plan_document()
        plan["network"] = {
            "environment": "testnet",
            "chain_id": executor.SEPOLIA_CHAIN_ID,
        }
        with self.assertRaisesRegex(
            executor.CanonicalExecutionError,
            "explicit --authorize-live-broadcast",
        ):
            executor.execution_network_record(
                plan,
                rpc_url="https://sepolia.example",
                execution_mode="sepolia",
                live_broadcast_authorized=False,
                ephemeral_local=False,
            )
        record = executor.execution_network_record(
            plan,
            rpc_url="https://sepolia.example",
            execution_mode="sepolia",
            live_broadcast_authorized=True,
            ephemeral_local=False,
            resolver=lambda *_: address_info("8.8.8.8"),
        )
        self.assertEqual("authorized_live_sepolia", record["rpc_scope"])
        self.assertEqual(
            ["8.8.8.8"],
            record["rpc_resolution"]["resolved_addresses"],
        )
        self.assertFalse(record["rpc_resolution"]["actual_peer_verified"])
        for rpc_url in (
            "http://localhost:8545",
            "https://LOCALHOST.:8545",
            "https://127.0.0.1:8545",
            "https://127.1:8545",
            "https://2130706433:8545",
            "http://[::1]:8545",
            "http://[::ffff:127.0.0.1]:8545",
        ):
            with self.subTest(rpc_url=rpc_url), self.assertRaisesRegex(
                executor.CanonicalExecutionError,
                "rejects loopback and localhost",
            ):
                executor.execution_network_record(
                    plan,
                    rpc_url=rpc_url,
                    execution_mode="sepolia",
                    live_broadcast_authorized=True,
                    ephemeral_local=False,
                )
        with self.assertRaisesRegex(
            executor.CanonicalExecutionError,
            "unsupported execution mode",
        ):
            executor.execution_network_record(
                plan,
                rpc_url="https://sepolia.example",
                execution_mode="rehearsal",
                live_broadcast_authorized=True,
                ephemeral_local=False,
            )

    def test_sepolia_dns_resolution_accepts_only_one_pinned_public_set(self) -> None:
        plan = plan_document()
        plan["network"] = {
            "environment": "testnet",
            "chain_id": executor.SEPOLIA_CHAIN_ID,
        }
        record = executor.execution_network_record(
            plan,
            rpc_url="https://public-rpc.example",
            execution_mode="sepolia",
            live_broadcast_authorized=True,
            ephemeral_local=False,
            resolver=lambda *_: address_info(
                "2606:4700:4700::1111",
                "8.8.8.8",
                "::ffff:8.8.8.8",
            ),
        )
        self.assertEqual(
            ["8.8.8.8", "2606:4700:4700::1111"],
            record["rpc_resolution"]["resolved_addresses"],
        )
        self.assertEqual(
            executor.PUBLIC_RPC_RESOLUTION_POLICY,
            record["rpc_resolution"]["policy"],
        )

    def test_sepolia_dns_aliases_fail_if_any_answer_is_non_public(self) -> None:
        plan = plan_document()
        plan["network"] = {
            "environment": "testnet",
            "chain_id": executor.SEPOLIA_CHAIN_ID,
        }
        hostile = {
            "loopback alias": ("127.0.0.1",),
            "mixed public loopback": ("8.8.8.8", "::1"),
            "mapped IPv6 loopback": ("::ffff:127.0.0.1",),
            "private": ("10.0.0.1",),
            "unspecified": ("::",),
            "link local": ("fe80::1",),
        }
        for label, addresses in hostile.items():
            with self.subTest(label=label), self.assertRaisesRegex(
                executor.CanonicalExecutionError,
                "globally routable",
            ):
                executor.execution_network_record(
                    plan,
                    rpc_url="https://lvh.me",
                    execution_mode="sepolia",
                    live_broadcast_authorized=True,
                    ephemeral_local=False,
                    resolver=lambda *_, values=addresses: address_info(*values),
                )

    def test_sepolia_dns_failure_is_rejected(self) -> None:
        plan = plan_document()
        plan["network"] = {
            "environment": "testnet",
            "chain_id": executor.SEPOLIA_CHAIN_ID,
        }

        def fail_resolution(*_: object) -> list[tuple[object, ...]]:
            raise executor.socket.gaierror("host not found")

        with self.assertRaisesRegex(
            executor.CanonicalExecutionError,
            "hostname resolution failed",
        ):
            executor.execution_network_record(
                plan,
                rpc_url="https://missing.example",
                execution_mode="sepolia",
                live_broadcast_authorized=True,
                ephemeral_local=False,
                resolver=fail_resolution,
            )

    def test_sepolia_dns_drift_rejects_before_rpc_connection(self) -> None:
        plan = plan_document()
        plan["network"] = {
            "environment": "testnet",
            "chain_id": executor.SEPOLIA_CHAIN_ID,
        }
        resolver = mock.Mock(
            side_effect=[
                address_info("8.8.8.8", "2606:4700:4700::1111"),
                address_info("2606:4700:4700::1111", "8.8.8.8"),
                address_info("1.1.1.1"),
            ]
        )
        record = executor.execution_network_record(
            plan,
            rpc_url="https://public-rpc.example",
            execution_mode="sepolia",
            live_broadcast_authorized=True,
            ephemeral_local=False,
            resolver=resolver,
        )
        base_rpc = mock.Mock(return_value="0xaa")
        guarded = executor.resolution_guarded_rpc(
            base_rpc,
            "https://public-rpc.example",
            record["rpc_resolution"]["resolved_addresses"],
            resolver=resolver,
        )
        self.assertEqual("0xaa", guarded("eth_chainId", []))
        with self.assertRaisesRegex(
            executor.CanonicalExecutionError,
            "changed after authorization",
        ):
            guarded("eth_chainId", [])
        base_rpc.assert_called_once_with("eth_chainId", [])

    def test_sepolia_dns_failure_after_pinning_rejects_before_connection(self) -> None:
        resolver = mock.Mock(
            side_effect=[
                address_info("8.8.8.8"),
                executor.socket.gaierror("resolution unavailable"),
            ]
        )
        pinned = executor.resolve_public_rpc_addresses(
            "https://public-rpc.example",
            resolver=resolver,
        )
        base_rpc = mock.Mock(return_value="0xaa")
        guarded = executor.resolution_guarded_rpc(
            base_rpc,
            "https://public-rpc.example",
            pinned,
            resolver=resolver,
        )
        with self.assertRaisesRegex(
            executor.CanonicalExecutionError,
            "hostname resolution failed",
        ):
            guarded("eth_chainId", [])
        base_rpc.assert_not_called()

    def test_sepolia_dns_evidence_schema_never_claims_peer_verification(self) -> None:
        schema = executor.materializer.load_json(
            Path(__file__).resolve().parent.parent / executor.EXECUTION_SCHEMA_PATH
        )
        validator = executor.materializer.Draft202012Validator(
            schema["properties"]["network"]
        )
        network = {
            "environment": "testnet",
            "chain_id": executor.SEPOLIA_CHAIN_ID,
            "execution_mode": "sepolia",
            "rpc_scope": "authorized_live_sepolia",
            "rpc_resolution": {
                "policy": executor.PUBLIC_RPC_RESOLUTION_POLICY,
                "resolved_addresses": ["8.8.8.8", "2606:4700:4700::1111"],
                "actual_peer_verified": False,
            },
        }
        self.assertEqual([], list(validator.iter_errors(network)))
        for mutate in (
            lambda value: value.pop("rpc_resolution"),
            lambda value: value["rpc_resolution"].__setitem__(
                "actual_peer_verified", True
            ),
        ):
            hostile = copy.deepcopy(network)
            mutate(hostile)
            self.assertNotEqual([], list(validator.iter_errors(hostile)))

    def test_output_modes_are_mutually_exclusive(self) -> None:
        with mock.patch("sys.stderr"), self.assertRaises(SystemExit):
            executor.parse_args(
                [
                    "--mode",
                    "anvil",
                    "--ephemeral-output",
                    "--output",
                    "tmp/explicit.json",
                ]
            )

    def test_reviewed_signer_modes_never_accept_raw_keys(self) -> None:
        self.assertEqual(["--unlocked"], executor.signer_arguments("unlocked"))
        self.assertEqual(["--ledger"], executor.signer_arguments("ledger"))
        self.assertEqual(
            ["--keystore", "wallet.json", "--password-file", "password.txt"],
            executor.signer_arguments(
                "keystore",
                keystore=Path("wallet.json"),
                password_file=Path("password.txt"),
            ),
        )
        with self.assertRaises(executor.CanonicalExecutionError):
            executor.signer_arguments("keystore")
        with self.assertRaises(executor.CanonicalExecutionError):
            executor.signer_arguments("private-key")
        with self.assertRaises(executor.CanonicalExecutionError):
            executor.signer_arguments("interactive")
        with self.assertRaises(executor.CanonicalExecutionError):
            executor.signer_arguments("browser")
        command = executor.forge_command(
            Path("executor"),
            sender=SENDER,
            signer_cli=["--ledger"],
            broadcast=True,
        )
        self.assertIn("--ledger", command)
        self.assertIn("--broadcast", command)
        self.assertNotIn("--unlocked", command)
        self.assertNotIn("--private-key", command)


class StrictJsonRpcTests(unittest.TestCase):
    class Response:
        def __init__(self, raw: bytes) -> None:
            self.raw = raw

        def __enter__(self) -> "StrictJsonRpcTests.Response":
            return self

        def __exit__(self, *args: object) -> None:
            return None

        def read(self) -> bytes:
            return self.raw

    def call_with(self, raw: bytes) -> object:
        with mock.patch.object(executor, "urlopen", return_value=self.Response(raw)):
            return executor.rpc_client("https://rpc.example")("eth_chainId", [])

    def test_duplicate_result_member_is_rejected(self) -> None:
        with self.assertRaisesRegex(
            executor.CanonicalExecutionError,
            "failed without retaining success",
        ):
            self.call_with(
                b'{"jsonrpc":"2.0","id":1,"result":"0x1","result":"0x2"}'
            )

    def test_hostile_rpc_numeric_unicode_and_utf8_values_are_rejected(self) -> None:
        hostile = {
            "unsafe integer": (
                b'{"jsonrpc":"2.0","id":1,"result":9007199254740992}'
            ),
            "float": b'{"jsonrpc":"2.0","id":1,"result":1.5}',
            "nan": b'{"jsonrpc":"2.0","id":1,"result":NaN}',
            "surrogate": b'{"jsonrpc":"2.0","id":1,"result":"\\ud800"}',
            "invalid utf8": b'{"jsonrpc":"2.0","id":1,"result":"\xff"}',
        }
        for label, raw in hostile.items():
            with self.subTest(label=label), self.assertRaisesRegex(
                executor.CanonicalExecutionError,
                "failed without retaining success",
            ):
                self.call_with(raw)

    def test_rpc_protocol_version_and_id_are_bound(self) -> None:
        for raw in (
            b'{"jsonrpc":"1.0","id":1,"result":"0x1"}',
            b'{"jsonrpc":"2.0","id":2,"result":"0x1"}',
            b'{"jsonrpc":"2.0","id":true,"result":"0x1"}',
            b'{"jsonrpc":"2.0","id":false,"result":"0x1"}',
            b'{"jsonrpc":"2.0","id":null,"result":"0x1"}',
            b'{"jsonrpc":"2.0","id":"1","result":"0x1"}',
            b'{"jsonrpc":"2.0","id":-1,"result":"0x1"}',
        ):
            with self.subTest(raw=raw), self.assertRaisesRegex(
                executor.CanonicalExecutionError,
                "wrong protocol version or id",
            ):
                self.call_with(raw)

    def test_rpc_id_float_and_out_of_safe_range_are_rejected(self) -> None:
        for raw in (
            b'{"jsonrpc":"2.0","id":1.0,"result":"0x1"}',
            b'{"jsonrpc":"2.0","id":9007199254740992,"result":"0x1"}',
        ):
            with self.subTest(raw=raw), self.assertRaises(
                executor.CanonicalExecutionError
            ):
                self.call_with(raw)

    def test_rpc_exact_non_bool_integer_id_is_accepted(self) -> None:
        self.assertEqual(
            "0x1",
            self.call_with(b'{"jsonrpc":"2.0","id":1,"result":"0x1"}'),
        )

    def test_rpc_success_and_error_envelopes_have_exact_member_sets(self) -> None:
        hostile = (
            b'{"jsonrpc":"2.0","id":1,"result":"0x1","error":null}',
            b'{"jsonrpc":"2.0","id":1,"result":"0x1","unexpected":true}',
            b'{"jsonrpc":"2.0","id":1,"error":null,"unexpected":true}',
            b'{"jsonrpc":"2.0","id":1}',
        )
        for raw in hostile:
            with self.subTest(raw=raw), self.assertRaisesRegex(
                executor.CanonicalExecutionError,
                "ambiguous response shape",
            ):
                self.call_with(raw)
        with self.assertRaisesRegex(
            executor.CanonicalExecutionError,
            "error response",
        ):
            self.call_with(
                b'{"jsonrpc":"2.0","id":1,"error":{"code":-1,"message":"no"}}'
            )


class JournalAndLockTests(unittest.TestCase):
    @staticmethod
    def prebroadcast_document(
        status: str,
        *,
        identity: dict[str, object] | None = None,
    ) -> dict[str, object]:
        document = {
            **copy.deepcopy(identity or journal_identity()),
            "status": status,
            "success": False,
            "active_deployment": None,
            "verified_deployments": [],
        }
        if status == "failed_preflight":
            document.update(
                {
                    "failure_type": "CanonicalExecutionError",
                    "failure": "preflight rejected before broadcast",
                }
            )
        return document

    def test_execution_key_lock_is_exclusive(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            lock = executor.acquire_execution_lock(parent, "a" * 64, "first")
            try:
                with self.assertRaisesRegex(
                    executor.CanonicalExecutionError,
                    "active or left a stale lock",
                ):
                    executor.acquire_execution_lock(parent, "a" * 64, "second")
            finally:
                executor.release_execution_lock(lock)

    def test_sender_lock_excludes_different_plans_on_same_chain_and_sender(self) -> None:
        plan_a = "sha256:" + ("11" * 32)
        plan_b = "sha256:" + ("22" * 32)
        self.assertNotEqual(
            executor.execution_key(plan_a, 31337, SENDER),
            executor.execution_key(plan_b, 31337, SENDER),
        )
        lock_key_a = executor.sender_lock_key(31337, SENDER)
        lock_key_b = executor.sender_lock_key(31337, SENDER)
        self.assertEqual(lock_key_a, lock_key_b)
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            lock = executor.acquire_execution_lock(parent, lock_key_a, "plan-a")
            try:
                with self.assertRaisesRegex(
                    executor.CanonicalExecutionError,
                    "repository-local chain/sender",
                ):
                    executor.acquire_execution_lock(parent, lock_key_b, "plan-b")
            finally:
                executor.release_execution_lock(lock)

    def test_sender_lock_keeps_other_senders_and_chains_independent(self) -> None:
        other_sender = "0x0000000000000000000000000000000000000022"
        keys = (
            executor.sender_lock_key(31337, SENDER),
            executor.sender_lock_key(31337, other_sender),
            executor.sender_lock_key(executor.SEPOLIA_CHAIN_ID, SENDER),
        )
        self.assertEqual(3, len(set(keys)))
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            locks = [
                executor.acquire_execution_lock(parent, key, f"run-{index}")
                for index, key in enumerate(keys)
            ]
            for lock in locks:
                executor.release_execution_lock(lock)

    def test_unresolved_matching_journal_blocks_retry(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            path = parent / "session" / "execution-journal.json"
            identity = journal_identity()
            write_json(
                path,
                {
                    **identity,
                    "status": "failed_or_ambiguous",
                    "success": False,
                    "active_deployment": None,
                    "verified_deployments": [],
                },
            )
            with self.assertRaisesRegex(
                executor.CanonicalExecutionError,
                "reconcile its exact journal",
            ):
                executor.reject_ambiguous_journals(
                    parent,
                    expected_identity=identity,
                )

    def test_exact_coherent_preflight_and_ephemeral_discard_allow_retry(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            identity = journal_identity()
            for index, status in enumerate(
                ("preflight", "failed_preflight", "discarded_ephemeral_chain")
            ):
                journal = self.prebroadcast_document(status, identity=identity)
                if status == "discarded_ephemeral_chain":
                    journal["ephemeral_chain_destroyed"] = True
                write_json(
                    parent / str(index) / "execution-journal.json",
                    journal,
                )
            executor.reject_ambiguous_journals(
                parent,
                expected_identity=identity,
            )

    def test_retry_safe_status_requires_exact_coherent_prebroadcast_state(self) -> None:
        identity = journal_identity()
        mutations = {
            "success true": lambda value: value.__setitem__("success", True),
            "success missing": lambda value: value.pop("success"),
            "active deployment": lambda value: value.__setitem__(
                "active_deployment", {"status": "prepared"}
            ),
            "active missing": lambda value: value.pop("active_deployment"),
            "verified row": lambda value: value["verified_deployments"].append(
                {"transaction_hash": TX_HASH}
            ),
            "verified missing": lambda value: value.pop("verified_deployments"),
            "unexpected transaction set": lambda value: value.__setitem__(
                "transactions", []
            ),
            "malformed RPC evidence": lambda value: value.__setitem__(
                "rpc_preflight", {}
            ),
            "boolean nonce": lambda value: value.__setitem__("initial_nonce", True),
            "schema changed": lambda value: value.__setitem__(
                "schema_version", "hostile"
            ),
            "network changed": lambda value: value["network"].__setitem__(
                "rpc_scope", "operator_loopback_local"
            ),
            "execution key changed": lambda value: value.__setitem__(
                "execution_key", "0" * 64
            ),
            "candidate missing": lambda value: value.pop("candidate_id"),
        }
        for status in ("preflight", "failed_preflight"):
            for label, mutate in mutations.items():
                with self.subTest(status=status, mutation=label), tempfile.TemporaryDirectory() as directory:
                    parent = Path(directory)
                    document = self.prebroadcast_document(status, identity=identity)
                    mutate(document)
                    write_json(parent / "run" / "execution-journal.json", document)
                    with self.assertRaises(executor.CanonicalExecutionError):
                        executor.reject_ambiguous_journals(
                            parent,
                            expected_identity=identity,
                        )

    def test_failed_preflight_requires_exact_failure_state(self) -> None:
        identity = journal_identity()
        for field, replacement in (
            ("failure_type", None),
            ("failure_type", ""),
            ("failure", None),
            ("failure", ""),
        ):
            with self.subTest(field=field, replacement=replacement), tempfile.TemporaryDirectory() as directory:
                parent = Path(directory)
                document = self.prebroadcast_document(
                    "failed_preflight",
                    identity=identity,
                )
                if replacement is None:
                    document.pop(field)
                else:
                    document[field] = replacement
                write_json(parent / "run" / "execution-journal.json", document)
                with self.assertRaises(executor.CanonicalExecutionError):
                    executor.reject_ambiguous_journals(
                        parent,
                        expected_identity=identity,
                    )

    def test_retry_safe_journal_requires_every_exact_identity_field(self) -> None:
        identity = journal_identity()
        for field in executor.JOURNAL_IDENTITY_FIELDS:
            with self.subTest(field=field), tempfile.TemporaryDirectory() as directory:
                parent = Path(directory)
                document = self.prebroadcast_document(
                    "preflight",
                    identity=identity,
                )
                document.pop(field)
                write_json(parent / "run" / "execution-journal.json", document)
                with self.assertRaises(executor.CanonicalExecutionError):
                    executor.reject_ambiguous_journals(
                        parent,
                        expected_identity=identity,
                    )

    def test_verified_same_plan_sepolia_journal_is_terminal(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            path = parent / "sepolia" / "execution-journal.json"
            identity = journal_identity(
                chain_id=executor.SEPOLIA_CHAIN_ID,
                network={
                    "environment": "testnet",
                    "chain_id": executor.SEPOLIA_CHAIN_ID,
                    "execution_mode": "sepolia",
                    "rpc_scope": "authorized_live_sepolia",
                    "rpc_resolution": {
                        "policy": executor.PUBLIC_RPC_RESOLUTION_POLICY,
                        "resolved_addresses": ["8.8.8.8"],
                        "actual_peer_verified": False,
                    },
                },
            )
            write_json(
                path,
                {
                    **identity,
                    "status": executor.FINAL_JOURNAL_STATUS,
                    "success": True,
                    "active_deployment": None,
                    "verified_deployments": [],
                },
            )
            with self.assertRaisesRegex(
                executor.CanonicalExecutionError,
                "terminal or unresolved",
            ):
                executor.reject_ambiguous_journals(
                    parent,
                    expected_identity=identity,
                )

    def test_ephemeral_retry_requires_post_destruction_marker(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            path = parent / "anvil" / "execution-journal.json"
            identity = journal_identity()
            document = {
                **identity,
                "status": executor.FINAL_JOURNAL_STATUS,
                "success": True,
                "active_deployment": None,
                "verified_deployments": [],
            }
            write_json(path, document)
            with self.assertRaises(executor.CanonicalExecutionError):
                executor.reject_ambiguous_journals(
                    parent,
                    expected_identity=identity,
                )
            executor.mark_ephemeral_chain_destroyed(path)
            executor.reject_ambiguous_journals(
                parent,
                expected_identity=identity,
            )
            marked = executor.materializer.load_json(path)
            self.assertEqual("discarded_ephemeral_chain", marked["status"])
            self.assertTrue(marked["ephemeral_chain_destroyed"])
            self.assertFalse(marked["success"])

    def test_unproved_or_external_discard_marker_cannot_enable_retry(self) -> None:
        for label, network, destroyed in (
            (
                "missing proof",
                {
                    "execution_mode": "anvil",
                    "rpc_scope": "ephemeral_loopback_anvil",
                },
                False,
            ),
            (
                "external local",
                {
                    "execution_mode": "local",
                    "rpc_scope": "operator_loopback_local",
                },
                True,
            ),
        ):
            with self.subTest(label=label), tempfile.TemporaryDirectory() as directory:
                parent = Path(directory)
                identity = journal_identity(network={
                    "environment": "anvil" if label == "missing proof" else "local",
                    "chain_id": 31337,
                    **network,
                })
                document = {
                    **identity,
                    "status": "discarded_ephemeral_chain",
                    "success": False,
                    "ephemeral_chain_destroyed": destroyed,
                    "active_deployment": None,
                    "verified_deployments": [],
                }
                write_json(parent / "run" / "execution-journal.json", document)
                with self.assertRaisesRegex(
                    executor.CanonicalExecutionError,
                    "terminal or unresolved",
                ):
                    executor.reject_ambiguous_journals(
                        parent,
                        expected_identity=identity,
                    )


class BroadcastBindingTests(unittest.TestCase):
    def validate(self, value: dict[str, object]) -> tuple[str, str]:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "run-latest.json"
            write_json(path, value)
            return executor.transaction_hash_from_broadcast(
                path,
                expected_chain_id=31337,
                expected_sender=SENDER,
                expected_nonce=0,
                expected_contract_address=DEPLOYED,
                expected_initcode=INITCODE,
            )

    def test_exact_single_create_is_accepted(self) -> None:
        self.assertEqual((TX_HASH, DEPLOYED), self.validate(broadcast_document()))

    def test_hostile_broadcast_mutations_are_rejected(self) -> None:
        mutations = {
            "wrong chain": lambda value: value.__setitem__("chain", 1),
            "pending": lambda value: value["pending"].append({"hash": TX_HASH}),
            "library": lambda value: value["libraries"].append("Library"),
            "two transactions": lambda value: value["transactions"].append(
                copy.deepcopy(value["transactions"][0])
            ),
            "wrong type": lambda value: value["transactions"][0].__setitem__(
                "transactionType",
                "CALL",
            ),
            "recipient": lambda value: value["transactions"][0][
                "transaction"
            ].__setitem__("to", DEPLOYED),
            "additional contract": lambda value: value["transactions"][
                0
            ].__setitem__("additionalContracts", [{"address": DEPLOYED}]),
            "wrong sender": lambda value: value["transactions"][0][
                "transaction"
            ].__setitem__(
                "from",
                "0x0000000000000000000000000000000000000099",
            ),
            "wrong nonce": lambda value: value["transactions"][0][
                "transaction"
            ].__setitem__("nonce", "0x1"),
            "nonzero value": lambda value: value["transactions"][0][
                "transaction"
            ].__setitem__("value", "0x1"),
            "mutated input": lambda value: value["transactions"][0][
                "transaction"
            ].__setitem__("input", "0x6001"),
            "wrong receipt hash": lambda value: value["receipts"][0].__setitem__(
                "transactionHash",
                "0x" + ("99" * 32),
            ),
            "failed receipt": lambda value: value["receipts"][0].__setitem__(
                "status",
                "0x0",
            ),
            "receipt recipient": lambda value: value["receipts"][0].__setitem__(
                "to",
                DEPLOYED,
            ),
            "receipt sender": lambda value: value["receipts"][0].__setitem__(
                "from",
                "0x0000000000000000000000000000000000000099",
            ),
            "receipt contract": lambda value: value["receipts"][0].__setitem__(
                "contractAddress",
                "0x0000000000000000000000000000000000000099",
            ),
        }
        for label, mutate in mutations.items():
            with self.subTest(label=label):
                value = broadcast_document()
                mutate(value)
                with self.assertRaises(executor.CanonicalExecutionError):
                    self.validate(value)

    def test_duplicate_json_member_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "run-latest.json"
            path.write_text('{"chain":31337,"chain":31337}\n', encoding="utf-8")
            with self.assertRaisesRegex(
                executor.CanonicalExecutionError,
                "duplicate JSON member",
            ):
                executor.transaction_hash_from_broadcast(
                    path,
                    expected_chain_id=31337,
                    expected_sender=SENDER,
                    expected_nonce=0,
                    expected_contract_address=DEPLOYED,
                    expected_initcode=INITCODE,
                )


class RpcPostflightTests(unittest.TestCase):
    def test_sender_nonce_interleaving_is_rejected(self) -> None:
        def rpc(method: str, params: object) -> object:
            if method == "eth_getTransactionCount":
                return "0x2"
            raise AssertionError(f"unexpected RPC method {method}: {params}")

        with self.assertRaisesRegex(
            executor.CanonicalExecutionError,
            "nonce interleaving",
        ):
            executor.require_uncontended_sender_nonce(
                rpc,
                sender=SENDER,
                expected_nonce=1,
            )

    def test_exact_transaction_receipt_and_runtime_are_retained(self) -> None:
        retained = executor.verify_chain_deployment(
            FakeRpc(),
            transaction_hash=TX_HASH,
            expected_sender=SENDER,
            expected_chain_id=31337,
            expected_nonce=0,
            expected_initcode=INITCODE,
            expected_contract_address=DEPLOYED,
            expected_runtime=RUNTIME,
            expected_runtime_hash=executor.materializer.keccak256_hex(
                bytes.fromhex(RUNTIME[2:])
            ),
        )
        self.assertEqual(DEPLOYED, retained["contract_address"])
        self.assertEqual(0, retained["nonce"])

    def test_runtime_mismatch_is_rejected(self) -> None:
        with self.assertRaisesRegex(
            executor.CanonicalExecutionError,
            "runtime bytes differ",
        ):
            executor.verify_chain_deployment(
                FakeRpc(runtime="0x6002"),
                transaction_hash=TX_HASH,
                expected_sender=SENDER,
                expected_chain_id=31337,
                expected_nonce=0,
                expected_initcode=INITCODE,
                expected_contract_address=DEPLOYED,
                expected_runtime=RUNTIME,
                expected_runtime_hash=executor.materializer.keccak256_hex(
                    bytes.fromhex(RUNTIME[2:])
                ),
            )

    def test_hostile_rpc_transaction_mutations_are_rejected(self) -> None:
        class MutatedTransactionRpc(FakeRpc):
            def __init__(self, field: str, value: str) -> None:
                super().__init__()
                self.field = field
                self.value = value

            def __call__(self, method: str, params: object) -> object:
                result = super().__call__(method, params)
                if method == "eth_getTransactionByHash":
                    result[self.field] = self.value
                return result

        mutations = (
            ("input", "0x6002", "transaction input differs"),
            ("value", "0x1", "nonzero value"),
        )
        for field, value, message in mutations:
            with self.subTest(field=field):
                with self.assertRaisesRegex(
                    executor.CanonicalExecutionError,
                    message,
                ):
                    executor.verify_chain_deployment(
                        MutatedTransactionRpc(field, value),
                        transaction_hash=TX_HASH,
                        expected_sender=SENDER,
                        expected_chain_id=31337,
                        expected_nonce=0,
                        expected_initcode=INITCODE,
                        expected_contract_address=DEPLOYED,
                        expected_runtime=RUNTIME,
                        expected_runtime_hash=executor.materializer.keccak256_hex(
                            bytes.fromhex(RUNTIME[2:])
                        ),
                    )

    def test_reorged_receipt_block_is_rejected(self) -> None:
        class ReorgRpc(FakeRpc):
            def __call__(self, method: str, params: object) -> object:
                if method == "eth_getBlockByNumber":
                    return {"hash": "0x" + ("55" * 32)}
                return super().__call__(method, params)

        with self.assertRaisesRegex(
            executor.CanonicalExecutionError,
            "no longer canonical",
        ):
            executor.verify_chain_deployment(
                ReorgRpc(),
                transaction_hash=TX_HASH,
                expected_sender=SENDER,
                expected_chain_id=31337,
                expected_nonce=0,
                expected_initcode=INITCODE,
                expected_contract_address=DEPLOYED,
                expected_runtime=RUNTIME,
                expected_runtime_hash=executor.materializer.keccak256_hex(
                    bytes.fromhex(RUNTIME[2:])
                ),
            )

    def test_reorg_between_runtime_read_and_final_receipt_check_is_rejected(self) -> None:
        class LateReorgRpc(FakeRpc):
            def __init__(self) -> None:
                super().__init__()
                self.block_reads = 0

            def __call__(self, method: str, params: object) -> object:
                if method == "eth_getBlockByNumber":
                    self.block_reads += 1
                    if self.block_reads >= 2:
                        return {"hash": "0x" + ("55" * 32)}
                return super().__call__(method, params)

        with self.assertRaisesRegex(
            executor.CanonicalExecutionError,
            "changed during canonical runtime verification",
        ):
            executor.verify_chain_deployment(
                LateReorgRpc(),
                transaction_hash=TX_HASH,
                expected_sender=SENDER,
                expected_chain_id=31337,
                expected_nonce=0,
                expected_initcode=INITCODE,
                expected_contract_address=DEPLOYED,
                expected_runtime=RUNTIME,
                expected_runtime_hash=executor.materializer.keccak256_hex(
                    bytes.fromhex(RUNTIME[2:])
                ),
            )

    def test_runtime_reads_use_canonical_block_hash_selector(self) -> None:
        class RecordingRpc(FakeRpc):
            def __init__(self) -> None:
                super().__init__()
                self.code_params: list[object] = []

            def __call__(self, method: str, params: object) -> object:
                if method == "eth_getCode":
                    self.code_params.append(params)
                return super().__call__(method, params)

        rpc = RecordingRpc()
        executor.verify_chain_deployment(
            rpc,
            transaction_hash=TX_HASH,
            expected_sender=SENDER,
            expected_chain_id=31337,
            expected_nonce=0,
            expected_initcode=INITCODE,
            expected_contract_address=DEPLOYED,
            expected_runtime=RUNTIME,
            expected_runtime_hash=executor.materializer.keccak256_hex(
                bytes.fromhex(RUNTIME[2:])
            ),
        )
        self.assertEqual(
            [
                {"blockHash": BLOCK_HASH, "requireCanonical": True},
                {"blockHash": BLOCK_HASH, "requireCanonical": True},
                {"blockHash": BLOCK_HASH, "requireCanonical": True},
            ],
            [params[1] for params in rpc.code_params],
        )

    def test_final_sweep_uses_captured_tip_for_every_runtime_read(self) -> None:
        class FinalTipRpc(FakeRpc):
            def __init__(self) -> None:
                super().__init__()
                self.code_params: list[object] = []

            def __call__(self, method: str, params: object) -> object:
                if method == "eth_blockNumber":
                    return "0x2"
                if method == "eth_getBlockByNumber":
                    return {"hash": TIP_HASH if params[0] == "0x2" else BLOCK_HASH}
                if method == "eth_getBlockByHash":
                    if params[0] == TIP_HASH:
                        return {"number": "0x2", "hash": TIP_HASH}
                    return {"number": "0x1", "hash": BLOCK_HASH}
                if method == "eth_getCode":
                    self.code_params.append(params)
                return super().__call__(method, params)

        rpc = FinalTipRpc()
        executor.verify_chain_deployment(
            rpc,
            transaction_hash=TX_HASH,
            expected_sender=SENDER,
            expected_chain_id=31337,
            expected_nonce=0,
            expected_initcode=INITCODE,
            expected_contract_address=DEPLOYED,
            expected_runtime=RUNTIME,
            expected_runtime_hash=executor.materializer.keccak256_hex(
                bytes.fromhex(RUNTIME[2:])
            ),
            verification_tip={"block_number": 2, "block_hash": TIP_HASH},
        )
        self.assertEqual(3, len(rpc.code_params))
        self.assertTrue(
            all(
                params[1]
                == {"blockHash": TIP_HASH, "requireCanonical": True}
                for params in rpc.code_params
            )
        )

    def test_tip_unchanged_rejects_advancement_and_reorg(self) -> None:
        tip = {"block_number": 1, "block_hash": BLOCK_HASH}

        class AdvancedRpc(FakeRpc):
            def __call__(self, method: str, params: object) -> object:
                if method == "eth_blockNumber":
                    return "0x2"
                return super().__call__(method, params)

        with self.assertRaisesRegex(
            executor.CanonicalExecutionError,
            "advanced or regressed",
        ):
            executor.assert_canonical_tip_unchanged(AdvancedRpc(), tip)

        class ReorgedTipRpc(FakeRpc):
            def __call__(self, method: str, params: object) -> object:
                if method == "eth_getBlockByNumber":
                    return {"hash": TIP_HASH}
                return super().__call__(method, params)

        with self.assertRaisesRegex(
            executor.CanonicalExecutionError,
            "tip changed",
        ):
            executor.assert_canonical_tip_unchanged(ReorgedTipRpc(), tip)


class FailureRetentionTests(unittest.TestCase):
    def test_ephemeral_failure_requires_proved_chain_destruction_before_retry(self) -> None:
        plan = plan_document()
        raw = executor.materializer.json_text(plan).encode("utf-8")
        digest = executor.prefixed_sha256(raw)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = root / "tmp/success.json"
            prepare_executor_files(root)

            def rpc(method: str, params: object) -> object:
                if method == "eth_chainId":
                    return "0x7a69"
                raise AssertionError(f"unexpected RPC method {method}: {params}")

            def fail_command(
                command: object,
                cwd: Path,
                env: object,
            ) -> subprocess.CompletedProcess[str]:
                raise executor.CanonicalExecutionError("simulated command failure")

            with (
                mock.patch.object(
                    executor,
                    "canonical_plan_snapshot",
                    return_value=(plan, raw, digest),
                ),
                mock.patch.object(
                    executor,
                    "validate_broadcaster_source",
                    return_value=executor.prefixed_sha256(
                        (root / executor.DEFAULT_SCRIPT).read_bytes()
                    ),
                ),
            ):
                with self.assertRaisesRegex(
                    executor.CanonicalExecutionError,
                    "simulated command failure",
                ):
                    executor.execute_plan(
                        root,
                        root / "candidate.json",
                        root / "tmp/plan.json",
                        output,
                        rpc_url="http://127.0.0.1:8545",
                        sender=SENDER,
                        signer_cli=["--unlocked"],
                        execution_mode="anvil",
                        ephemeral_local=True,
                        command_runner=fail_command,
                        rpc=rpc,
                    )
            self.assertFalse(output.exists())
            journals = list(
                (root / executor.SESSION_ROOT).glob("*/execution-journal.json")
            )
            self.assertEqual(1, len(journals))
            journal = json.loads(journals[0].read_text(encoding="utf-8"))
            self.assertFalse(journal["success"])
            self.assertEqual(
                "awaiting_ephemeral_chain_destruction",
                journal["status"],
            )
            with (
                mock.patch.object(
                    executor,
                    "canonical_plan_snapshot",
                    return_value=(plan, raw, digest),
                ),
                mock.patch.object(
                    executor,
                    "validate_broadcaster_source",
                    return_value=executor.prefixed_sha256(
                        (root / executor.DEFAULT_SCRIPT).read_bytes()
                    ),
                ),
                ):
                with self.assertRaisesRegex(
                    executor.CanonicalExecutionError,
                    "terminal or unresolved",
                ):
                    executor.execute_plan(
                        root,
                        root / "candidate.json",
                        root / "tmp/plan.json",
                        output,
                        rpc_url="http://127.0.0.1:8545",
                        sender=SENDER,
                        signer_cli=["--unlocked"],
                        execution_mode="anvil",
                        ephemeral_local=True,
                        command_runner=fail_command,
                        rpc=rpc,
                    )
            executor.mark_ephemeral_chain_destroyed(journals[0])
            with (
                mock.patch.object(
                    executor,
                    "canonical_plan_snapshot",
                    return_value=(plan, raw, digest),
                ),
                mock.patch.object(
                    executor,
                    "validate_broadcaster_source",
                    return_value=executor.prefixed_sha256(
                        (root / executor.DEFAULT_SCRIPT).read_bytes()
                    ),
                ),
            ):
                with self.assertRaisesRegex(
                    executor.CanonicalExecutionError,
                    "simulated command failure",
                ):
                    executor.execute_plan(
                        root,
                        root / "candidate.json",
                        root / "tmp/plan.json",
                        output,
                        rpc_url="http://127.0.0.1:8545",
                        sender=SENDER,
                        signer_cli=["--unlocked"],
                        execution_mode="anvil",
                        ephemeral_local=True,
                        command_runner=fail_command,
                        rpc=rpc,
                    )
            self.assertEqual(
                2,
                len(list((root / executor.SESSION_ROOT).glob("*/execution-journal.json"))),
            )

    def test_eip_1898_preflight_failure_runs_no_broadcast_and_is_retry_safe(self) -> None:
        plan = plan_document()
        plan["network"] = {"environment": "local", "chain_id": 31337}
        raw = executor.materializer.json_text(plan).encode("utf-8")
        digest = executor.prefixed_sha256(raw)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = root / "tmp/success.json"
            prepare_executor_files(root)
            commands: list[object] = []

            def rpc(method: str, params: object) -> object:
                if method == "eth_chainId":
                    return "0x7a69"
                if method == "eth_blockNumber":
                    return "0x1"
                if method == "eth_getBlockByNumber":
                    return {"hash": BLOCK_HASH}
                if method == "eth_getBlockByHash":
                    return {"number": "0x1", "hash": BLOCK_HASH}
                if method == "eth_getCode":
                    raise executor.CanonicalExecutionError(
                        "provider lacks EIP-1898 selector"
                    )
                raise AssertionError(f"unexpected RPC method {method}: {params}")

            def run_command(
                command: object,
                cwd: Path,
                env: object,
            ) -> subprocess.CompletedProcess[str]:
                commands.append(command)
                self.assertNotIn("--broadcast", command)
                write_json(
                    Path(env["FOUNDRY_OUT"]) / "build-info/fixture.json",
                    {"source_id_to_path": {"0": "DeployCanonicalInitcode.s.sol"}},
                )
                return subprocess.CompletedProcess(command, 0, "", "")

            for _ in range(2):
                with (
                    mock.patch.object(
                        executor,
                        "canonical_plan_snapshot",
                        return_value=(plan, raw, digest),
                    ),
                    mock.patch.object(
                        executor,
                        "validate_broadcaster_source",
                        return_value=executor.prefixed_sha256(
                            (root / executor.DEFAULT_SCRIPT).read_bytes()
                        ),
                    ),
                ):
                    with self.assertRaisesRegex(
                        executor.CanonicalExecutionError,
                        "lacks EIP-1898",
                    ):
                        executor.execute_plan(
                            root,
                            root / "candidate.json",
                            root / "tmp/plan.json",
                            output,
                            rpc_url="http://127.0.0.1:8545",
                            sender=SENDER,
                            signer_cli=["--unlocked"],
                            execution_mode="local",
                            ephemeral_local=False,
                            command_runner=run_command,
                            rpc=rpc,
                        )
            self.assertEqual(2, len(commands))
            journals = list(
                (root / executor.SESSION_ROOT).glob("*/execution-journal.json")
            )
            self.assertEqual(2, len(journals))
            self.assertTrue(
                all(
                    json.loads(path.read_text(encoding="utf-8"))["status"]
                    == "failed_preflight"
                    for path in journals
                )
            )


class SuccessfulExecutionTests(unittest.TestCase):
    def execute(
        self,
        root: Path,
        output: Path,
        *,
        publish_side_effect: object | None = None,
        v2: bool = False,
    ) -> dict[str, object]:
        plan = plan_document(v2=v2)
        raw = executor.materializer.json_text(plan).encode("utf-8")
        digest = executor.prefixed_sha256(raw)
        prepare_executor_files(root)
        source_schema = (
            Path(__file__).resolve().parent.parent / executor.EXECUTION_SCHEMA_PATH
        )
        (root / executor.EXECUTION_SCHEMA_PATH).write_bytes(source_schema.read_bytes())

        class ExecutionRpc(FakeRpc):
            def __init__(self) -> None:
                super().__init__()
                self.nonce = 0

            def __call__(self, method: str, params: object) -> object:
                if method == "eth_chainId":
                    return "0x7a69"
                if method == "eth_getTransactionCount":
                    return hex(self.nonce)
                return super().__call__(method, params)

        rpc = ExecutionRpc()

        def run_command(
            command: object,
            cwd: Path,
            env: object,
        ) -> subprocess.CompletedProcess[str]:
            if "--broadcast" in command:
                broadcast = (
                    Path(env["FOUNDRY_BROADCAST"])
                    / "DeployCanonicalInitcode.s.sol"
                    / "31337"
                    / "run-latest.json"
                )
                write_json(broadcast, broadcast_document())
                rpc.nonce = 1
            else:
                build_info = Path(env["FOUNDRY_OUT"]) / "build-info/fixture.json"
                write_json(
                    build_info,
                    {"source_id_to_path": {"0": "DeployCanonicalInitcode.s.sol"}},
                )
            return subprocess.CompletedProcess(command, 0, "", "")

        patches = [
            mock.patch.object(
                executor,
                "canonical_plan_snapshot",
                return_value=(plan, raw, digest),
            ),
            mock.patch.object(
                executor,
                "validate_broadcaster_source",
                return_value=executor.prefixed_sha256(
                    (root / executor.DEFAULT_SCRIPT).read_bytes()
                ),
            ),
        ]
        if publish_side_effect is not None:
            patches.append(
                mock.patch.object(
                    executor,
                    "write_json_exclusive",
                    side_effect=publish_side_effect,
                )
            )
        with patches[0], patches[1]:
            if len(patches) == 3:
                with patches[2]:
                    return executor.execute_plan(
                        root,
                        root / "candidate.json",
                        root / "tmp/plan.json",
                        output,
                        rpc_url="http://127.0.0.1:8545",
                        sender=SENDER,
                        signer_cli=["--unlocked"],
                        execution_mode="local" if v2 else "anvil",
                        ephemeral_local=not v2,
                        command_runner=run_command,
                        rpc=rpc,
                    )
            return executor.execute_plan(
                root,
                root / "candidate.json",
                root / "tmp/plan.json",
                output,
                rpc_url="http://127.0.0.1:8545",
                sender=SENDER,
                signer_cli=["--unlocked"],
                execution_mode="local" if v2 else "anvil",
                ephemeral_local=not v2,
                command_runner=run_command,
                rpc=rpc,
            )

    def test_success_path_schema_validates_and_publishes_after_final_sweep(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = root / "tmp/success.json"
            receipt = self.execute(root, output)
            self.assertTrue(output.is_file())
            self.assertEqual(
                receipt,
                json.loads(output.read_text(encoding="utf-8")),
            )
            self.assertTrue(
                receipt["finalization"]["tip_unchanged_during_final_sweep"]
            )
            journals = list(
                (root / executor.SESSION_ROOT).glob("*/execution-journal.json")
            )
            journal = json.loads(journals[0].read_text(encoding="utf-8"))
            self.assertTrue(journal["success"])
            self.assertEqual(executor.FINAL_JOURNAL_STATUS, journal["status"])

    def test_complete_v2_identity_is_bound_in_execution_receipt(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = root / "tmp/v2-success.json"
            receipt = self.execute(root, output, v2=True)
            self.assertTrue(receipt["release_posture"]["production_candidate"])
            self.assertFalse(receipt["release_posture"]["readiness_evidence"])
            self.assertEqual(
                receipt["release_posture"]["status"],
                "candidate_complete_execution_only",
            )
            self.assertEqual(
                receipt["plan"]["candidate_identity_sha256"],
                "sha256:" + ("77" * 32),
            )
            self.assertEqual(
                receipt["plan"]["candidate_identity_keccak256"],
                "0x" + ("88" * 32),
            )
            self.assertNotIn("candidate_sha256", receipt["plan"])
            invalid_receipt = copy.deepcopy(receipt)
            invalid_receipt["plan"]["candidate_identity_keccak256"] = None
            with self.assertRaisesRegex(
                executor.materializer.DeploymentPlanError,
                "canonical deployment execution receipt does not satisfy",
            ):
                executor.materializer.validate_draft_2020_12_schema(
                    root.resolve(),
                    executor.EXECUTION_SCHEMA_PATH,
                    invalid_receipt,
                    "canonical deployment execution receipt",
                )

    def test_receipt_publication_failure_resets_journal_success(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = root / "tmp/success.json"
            with self.assertRaisesRegex(
                executor.CanonicalExecutionError,
                "simulated publication collision",
            ):
                self.execute(
                    root,
                    output,
                    publish_side_effect=executor.CanonicalExecutionError(
                        "simulated publication collision"
                    ),
                )
            journals = list(
                (root / executor.SESSION_ROOT).glob("*/execution-journal.json")
            )
            journal = json.loads(journals[0].read_text(encoding="utf-8"))
            self.assertFalse(journal["success"])
            self.assertEqual(
                "awaiting_ephemeral_chain_destruction",
                journal["status"],
            )

    def test_runtime_postflight_failure_writes_no_success_receipt(self) -> None:
        plan = plan_document()
        raw = executor.materializer.json_text(plan).encode("utf-8")
        digest = executor.prefixed_sha256(raw)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = root / "tmp/success.json"
            prepare_executor_files(root)

            class ExecutionRpc(FakeRpc):
                def __init__(self) -> None:
                    super().__init__(runtime="0x6002")

                def __call__(self, method: str, params: object) -> object:
                    if method == "eth_chainId":
                        return "0x7a69"
                    if method == "eth_getTransactionCount":
                        return "0x0"
                    return super().__call__(method, params)

            def run_command(
                command: object,
                cwd: Path,
                env: object,
            ) -> subprocess.CompletedProcess[str]:
                executor_root = Path(command[command.index("--root") + 1])
                self.assertTrue(
                    executor_root.as_posix().endswith("/executor")
                )
                self.assertTrue(
                    (executor_root / "DeployCanonicalInitcode.s.sol").is_file()
                )
                self.assertTrue((executor_root / "foundry.toml").is_file())
                if "--broadcast" in command:
                    broadcast = (
                        Path(env["FOUNDRY_BROADCAST"])
                        / "DeployCanonicalInitcode.s.sol"
                        / "31337"
                        / "run-latest.json"
                    )
                    write_json(broadcast, broadcast_document())
                else:
                    build_info = (
                        Path(env["FOUNDRY_OUT"])
                        / "build-info"
                        / "fixture.json"
                    )
                    write_json(
                        build_info,
                        {
                            "source_id_to_path": {
                                "0": "DeployCanonicalInitcode.s.sol"
                            }
                        },
                    )
                return subprocess.CompletedProcess(command, 0, "", "")

            with (
                mock.patch.object(
                    executor,
                    "canonical_plan_snapshot",
                    return_value=(plan, raw, digest),
                ),
                mock.patch.object(
                    executor,
                    "validate_broadcaster_source",
                    return_value=executor.prefixed_sha256(
                        (root / executor.DEFAULT_SCRIPT).read_bytes()
                    ),
                ),
            ):
                with self.assertRaisesRegex(
                    executor.CanonicalExecutionError,
                    "runtime bytes differ",
                ):
                    executor.execute_plan(
                        root,
                        root / "candidate.json",
                        root / "tmp/plan.json",
                        output,
                        rpc_url="http://127.0.0.1:8545",
                        sender=SENDER,
                        signer_cli=["--unlocked"],
                        execution_mode="anvil",
                        ephemeral_local=True,
                        command_runner=run_command,
                        rpc=ExecutionRpc(),
                    )
            self.assertFalse(output.exists())
            journals = list(
                (root / executor.SESSION_ROOT).glob("*/execution-journal.json")
            )
            self.assertEqual(1, len(journals))
            journal = json.loads(journals[0].read_text(encoding="utf-8"))
            self.assertFalse(journal["success"])
            self.assertEqual(
                "awaiting_ephemeral_chain_destruction",
                journal["status"],
            )


if __name__ == "__main__":
    unittest.main()
