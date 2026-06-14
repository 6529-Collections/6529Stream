#!/usr/bin/env python3
"""Focused tests for Foundry broadcast manifest-input generation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("generate_broadcast_manifest_input.py")
SPEC = importlib.util.spec_from_file_location("generate_broadcast_manifest_input", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
generator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(generator)


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def tx_hash(byte: str) -> str:
    return "0x" + (byte * 64)


def template_config(root: Path) -> Path:
    path = root / "deployments" / "config" / "template.json"
    write_json(
        path,
        {
            "schema_version": "6529stream.deployment-manifest-input.v1",
            "output": "deployments/examples/template.json",
            "manifest": {
                "deployment_version": "anvil-example-001",
                "network": {"chain_id": 31337},
                "contracts": [
                    {
                        "name": "Alpha",
                        "address": "0x0000000000000000000000000000000000000001",
                    },
                    {
                        "name": "Beta",
                        "address": "0x0000000000000000000000000000000000000002",
                    },
                ],
                "rehearsal": {"notes": "template"},
            },
        },
    )
    return path


def broadcast_file(root: Path) -> Path:
    path = root / "deployments" / "broadcasts" / "run-latest.json"
    write_json(
        path,
        {
            "chain": 31337,
            "transactions": [
                {
                    "transactionType": "CALL",
                    "contractName": "Alpha",
                    "contractAddress": "0x1000000000000000000000000000000000000001",
                    "hash": tx_hash("0"),
                },
                {
                    "transactionType": "CREATE",
                    "contractName": "Alpha",
                    "contractAddress": "0x1000000000000000000000000000000000000001",
                    "hash": tx_hash("1"),
                },
                {
                    "transactionType": "CREATE2",
                    "contractName": "Beta",
                    "contractAddress": "0x1000000000000000000000000000000000000002",
                    "hash": tx_hash("2"),
                },
            ],
            "receipts": [
                {
                    "transactionHash": tx_hash("1"),
                    "status": "0x1",
                    "contractAddress": "0x1000000000000000000000000000000000000001",
                },
                {
                    "transactionHash": tx_hash("2"),
                    "status": 1,
                    "contractAddress": "0x1000000000000000000000000000000000000002",
                },
            ],
        },
    )
    return path


class BroadcastManifestInputTests(unittest.TestCase):
    def test_generator_writes_config_and_detects_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            template = template_config(root)
            broadcast = broadcast_file(root)
            output = root / "deployments" / "config" / "broadcast.json"
            manifest_output = root / "deployments" / "examples" / "broadcast.json"

            written = generator.generate_manifest_input(
                template,
                broadcast,
                output,
                manifest_output,
            )
            self.assertEqual(written, output)

            generated = generator.load_json(output)
            self.assertEqual(generated["schema_version"], generator.INPUT_SCHEMA)
            self.assertEqual(generated["output"], manifest_output.as_posix())
            self.assertEqual(
                generated["manifest"]["deployment_version"],
                "anvil-example-001-broadcast",
            )
            self.assertEqual(
                generated["manifest"]["contracts"][0]["address"],
                "0x1000000000000000000000000000000000000001",
            )
            self.assertEqual(
                generated["broadcast_evidence"]["broadcast_sha256"],
                generator.sha256_file(broadcast),
            )
            self.assertEqual(
                generated["broadcast_evidence"]["deployments"][1]["transaction_hash"],
                tx_hash("2"),
            )

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = generator.check_manifest_input(
                    template,
                    broadcast,
                    output,
                    manifest_output,
                )
            self.assertEqual(result, 0)

            generated["manifest"]["contracts"][0]["address"] = (
                "0x10000000000000000000000000000000000000ff"
            )
            write_json(output, generated)
            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = generator.check_manifest_input(
                    template,
                    broadcast,
                    output,
                    manifest_output,
                )
            self.assertEqual(result, 1)

    def test_generator_rejects_wrong_chain(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            template = template_config(root)
            broadcast = broadcast_file(root)
            data = generator.load_json(broadcast)
            data["chain"] = 1
            write_json(broadcast, data)

            with self.assertRaisesRegex(generator.BroadcastManifestError, "does not match"):
                generator.build_manifest_input(
                    template,
                    broadcast,
                    root / "out.json",
                    root / "manifest.json",
                )

    def test_generator_rejects_missing_expected_contract(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            template = template_config(root)
            broadcast = broadcast_file(root)
            data = generator.load_json(broadcast)
            data["transactions"] = data["transactions"][:2]
            write_json(broadcast, data)

            with self.assertRaisesRegex(generator.BroadcastManifestError, "missing deployments"):
                generator.build_manifest_input(
                    template,
                    broadcast,
                    root / "out.json",
                    root / "manifest.json",
                )

    def test_generator_rejects_unexpected_contract(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            template = template_config(root)
            broadcast = broadcast_file(root)
            data = generator.load_json(broadcast)
            data["transactions"].append(
                {
                    "transactionType": "CREATE",
                    "contractName": "Gamma",
                    "contractAddress": "0x1000000000000000000000000000000000000003",
                    "hash": tx_hash("3"),
                }
            )
            data["receipts"].append(
                {
                    "transactionHash": tx_hash("3"),
                    "status": "0x1",
                    "contractAddress": "0x1000000000000000000000000000000000000003",
                }
            )
            write_json(broadcast, data)

            with self.assertRaisesRegex(generator.BroadcastManifestError, "unexpected"):
                generator.build_manifest_input(
                    template,
                    broadcast,
                    root / "out.json",
                    root / "manifest.json",
                )

    def test_generator_records_explicitly_ignored_deployments(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            template = template_config(root)
            template_data = generator.load_json(template)
            template_data["broadcast_evidence"] = {
                "ignored_deployments": ["LinkedLibrary"],
            }
            write_json(template, template_data)

            broadcast = broadcast_file(root)
            data = generator.load_json(broadcast)
            data["transactions"].append(
                {
                    "transactionType": "CREATE2",
                    "contractName": "LinkedLibrary",
                    "contractAddress": "0x1000000000000000000000000000000000000003",
                    "hash": tx_hash("3"),
                }
            )
            data["receipts"].append(
                {
                    "transactionHash": tx_hash("3"),
                    "status": "0x1",
                    "contractAddress": "0x1000000000000000000000000000000000000003",
                }
            )
            write_json(broadcast, data)

            generated = generator.build_manifest_input(
                template,
                broadcast,
                root / "out.json",
                root / "manifest.json",
            )

            self.assertEqual(
                generated["broadcast_evidence"]["ignored_deployments"],
                [
                    {
                        "contract": "LinkedLibrary",
                        "address": "0x1000000000000000000000000000000000000003",
                        "transaction_hash": tx_hash("3"),
                    }
                ],
            )
            self.assertNotIn(
                "LinkedLibrary",
                [
                    deployment["contract"]
                    for deployment in generated["broadcast_evidence"]["deployments"]
                ],
            )

    def test_generator_accepts_sequential_receipt_for_unlocked_broadcast(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            template = template_config(root)
            broadcast = broadcast_file(root)
            data = generator.load_json(broadcast)
            data["transactions"][2]["hash"] = tx_hash("9")
            write_json(broadcast, data)

            generated = generator.build_manifest_input(
                template,
                broadcast,
                root / "out.json",
                root / "manifest.json",
            )

            self.assertEqual(
                generated["broadcast_evidence"]["deployments"][1]["transaction_hash"],
                tx_hash("2"),
            )

    def test_generator_rejects_failed_receipt(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            template = template_config(root)
            broadcast = broadcast_file(root)
            data = generator.load_json(broadcast)
            data["receipts"][0]["status"] = "0x0"
            write_json(broadcast, data)

            with self.assertRaisesRegex(generator.BroadcastManifestError, "did not succeed"):
                generator.build_manifest_input(
                    template,
                    broadcast,
                    root / "out.json",
                    root / "manifest.json",
                )

    def test_generator_rejects_boolean_receipt_status(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            template = template_config(root)
            broadcast = broadcast_file(root)
            data = generator.load_json(broadcast)
            data["receipts"][0]["status"] = True
            write_json(broadcast, data)

            with self.assertRaisesRegex(generator.BroadcastManifestError, "did not succeed"):
                generator.build_manifest_input(
                    template,
                    broadcast,
                    root / "out.json",
                    root / "manifest.json",
                )

    def test_generator_rejects_receipt_address_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            template = template_config(root)
            broadcast = broadcast_file(root)
            data = generator.load_json(broadcast)
            data["receipts"][1]["contractAddress"] = (
                "0x1000000000000000000000000000000000000003"
            )
            write_json(broadcast, data)

            with self.assertRaisesRegex(generator.BroadcastManifestError, "address does not match"):
                generator.build_manifest_input(
                    template,
                    broadcast,
                    root / "out.json",
                    root / "manifest.json",
                )

    def test_generator_rejects_duplicate_contract_name(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            template = template_config(root)
            broadcast = broadcast_file(root)
            data = generator.load_json(broadcast)
            data["transactions"][2]["contractName"] = "Alpha"
            write_json(broadcast, data)

            with self.assertRaisesRegex(generator.BroadcastManifestError, "duplicate deployment"):
                generator.build_manifest_input(
                    template,
                    broadcast,
                    root / "out.json",
                    root / "manifest.json",
                )

    def test_generator_rejects_secret_like_keys(self) -> None:
        for key in ("privateKey", "PrivateKey", "private-key", "RPCURL", "RPC-URL"):
            with self.subTest(key=key), tempfile.TemporaryDirectory() as temp_dir:
                root = Path(temp_dir)
                template = template_config(root)
                broadcast = broadcast_file(root)
                data = generator.load_json(broadcast)
                data[key] = "not-for-commit"
                write_json(broadcast, data)

                with self.assertRaisesRegex(generator.BroadcastManifestError, "forbidden"):
                    generator.build_manifest_input(
                        template,
                        broadcast,
                        root / "out.json",
                        root / "manifest.json",
                    )


if __name__ == "__main__":
    unittest.main(verbosity=2)
