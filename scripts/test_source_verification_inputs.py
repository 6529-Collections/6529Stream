#!/usr/bin/env python3
"""Focused tests for source-verification input generation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("generate_source_verification_inputs.py")
SPEC = importlib.util.spec_from_file_location("generate_source_verification_inputs", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
generator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(generator)


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def example_abi() -> list[dict[str, object]]:
    return [
        {
            "type": "constructor",
            "inputs": [
                {"name": "owner", "type": "address", "internalType": "address"},
            ],
            "stateMutability": "nonpayable",
        },
        {
            "type": "function",
            "name": "owner",
            "inputs": [],
            "outputs": [{"name": "", "type": "address"}],
            "stateMutability": "view",
        },
    ]


def artifact(
    *,
    name: str = "Example",
    source: str = "smart-contracts/Example.sol",
    bytecode: str = "0x6000",
    runtime: str = "0x6001",
    link_references: dict[str, object] | None = None,
    runtime_link_references: dict[str, object] | None = None,
) -> dict[str, object]:
    abi = example_abi()
    return {
        "abi": abi,
        "bytecode": {
            "object": bytecode,
            "linkReferences": link_references or {},
        },
        "deployedBytecode": {
            "object": runtime,
            "linkReferences": runtime_link_references
            if runtime_link_references is not None
            else link_references or {},
        },
        "metadata": {
            "compiler": {"version": "0.8.19+commit.7dd6d404"},
            "language": "Solidity",
            "settings": {
                "compilationTarget": {source: name},
                "evmVersion": "paris",
                "libraries": {},
                "metadata": {"bytecodeHash": "ipfs"},
                "optimizer": {"enabled": True, "runs": 200},
                "viaIR": True,
            },
            "sources": {
                source: {
                    "keccak256": "0x" + "1" * 64,
                    "license": "MIT",
                },
                "smart-contracts/Library.sol": {
                    "keccak256": "0x" + "2" * 64,
                    "license": "MIT",
                },
            },
            "version": 1,
        },
    }


def seed_tree(
    root: Path,
    *,
    linked: bool = False,
    runtime_link_offset: int | None = None,
) -> dict[str, Path]:
    source = root / "smart-contracts" / "Example.sol"
    library = root / "smart-contracts" / "Library.sol"
    artifact_path = root / "out" / "Example.sol" / "Example.json"
    config = root / "release-artifacts" / "contracts.json"
    checksums = root / "release-artifacts" / "latest" / "abi-checksums.json"
    output = root / "release-artifacts" / "latest" / "source-verification-inputs.json"
    foundry_config = root / "foundry.toml"

    write_text(source, "contract Example { address public owner; }\n")
    write_text(
        library,
        "library Library { function ok() internal pure returns (bool) { return true; } }\n",
    )
    write_text(
        foundry_config,
        "\n".join(
            [
                "[profile.default]",
                'src = "smart-contracts"',
                'out = "out"',
                'solc_version = "0.8.19"',
                "auto_detect_solc = false",
                'evm_version = "paris"',
                "optimizer = true",
                "optimizer_runs = 200",
                "",
            ]
        ),
    )

    link_references = None
    runtime_link_references = None
    bytecode = "0x6000"
    runtime = "0x6001"
    if linked:
        link_references = {
            "smart-contracts/Library.sol": {
                "Library": [
                    {"start": 12, "length": 20},
                ]
            }
        }
        if runtime_link_offset is not None:
            runtime_link_references = {
                "smart-contracts/Library.sol": {
                    "Library": [
                        {"start": runtime_link_offset, "length": 20},
                    ]
                }
            }
        bytecode = "0x60__$1234567890abcdef1234567890abcdef12$__"
        runtime = "0x61__$1234567890abcdef1234567890abcdef12$__"

    value = artifact(
        bytecode=bytecode,
        runtime=runtime,
        link_references=link_references,
        runtime_link_references=runtime_link_references,
    )
    write_json(artifact_path, value)
    write_json(
        config,
        {
            "schema_version": "6529stream.release-artifact-contracts.v1",
            "production_contracts": [
                {"name": "Example", "source": "smart-contracts/Example.sol"},
            ],
            "interfaces": [],
        },
    )
    write_json(
        checksums,
        {
            "schema_version": "6529stream.abi-checksums.v1",
            "contracts": {
                "Example": {
                    "source": "smart-contracts/Example.sol",
                    "artifact_path": "out/Example.sol/Example.json",
                    "abi_sha256": generator.sha256_json(value["abi"]),
                    "bytecode_sha256": generator.bytecode_hash(bytecode)["sha256"],
                    "deployed_bytecode_sha256": generator.bytecode_hash(runtime)["sha256"],
                }
            },
        },
    )

    return {
        "config": config,
        "foundry_config": foundry_config,
        "out": root / "out",
        "checksums": checksums,
        "output": output,
        "source": source,
        "artifact": artifact_path,
    }


class SourceVerificationInputTests(unittest.TestCase):
    def test_generator_writes_deterministic_inputs(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root, linked=True)

            written = generator.write_output(
                root,
                paths["output"],
                paths["config"],
                paths["foundry_config"],
                paths["out"],
                paths["checksums"],
            )
            first = written.read_text(encoding="utf-8")
            generator.write_output(
                root,
                paths["output"],
                paths["config"],
                paths["foundry_config"],
                paths["out"],
                paths["checksums"],
            )
            self.assertEqual(first, written.read_text(encoding="utf-8"))

            data = json.loads(first)
            self.assertEqual(data["schema_version"], generator.SOURCE_VERIFICATION_SCHEMA)
            self.assertEqual(data["toolchain"]["solidity_version_pin"], "0.8.19")
            self.assertEqual(data["toolchain"]["via_ir"], [True])
            self.assertIn("smart-contracts/Library.sol", data["source_files"])

            contract = data["contracts"]["Example"]
            self.assertEqual(contract["source_sha256"], generator.file_sha256(paths["source"]))
            self.assertEqual(contract["constructor"]["inputs"][0]["name"], "owner")
            self.assertTrue(contract["library_linking"]["requires_linking"])
            self.assertEqual(contract["bytecode_hashes"]["creation"]["linked"], False)
            self.assertIn("--via-ir", contract["verification"]["template"])
            self.assertIn("--constructor-args", contract["verification"]["template"])
            self.assertIn(
                "--libraries smart-contracts/Library.sol:Library:<library-address>",
                contract["verification"]["template"],
            )

    def test_library_verification_template_deduplicates_creation_and_runtime_links(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root, linked=True, runtime_link_offset=48)

            written = generator.write_output(
                root,
                paths["output"],
                paths["config"],
                paths["foundry_config"],
                paths["out"],
                paths["checksums"],
            )
            data = json.loads(written.read_text(encoding="utf-8"))

            contract = data["contracts"]["Example"]
            library_placeholder = "smart-contracts/Library.sol:Library:<library-address>"
            self.assertEqual(contract["verification"]["template"].count(library_placeholder), 1)
            self.assertNotEqual(
                contract["library_linking"]["creation_link_references"],
                contract["library_linking"]["runtime_link_references"],
            )

    def test_check_mode_accepts_current_inputs(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            generator.write_output(
                root,
                paths["output"],
                paths["config"],
                paths["foundry_config"],
                paths["out"],
                paths["checksums"],
            )

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = generator.check_output(
                    root,
                    paths["output"],
                    paths["config"],
                    paths["foundry_config"],
                    paths["out"],
                    paths["checksums"],
                )
            self.assertEqual(result, 0)

    def test_check_mode_rejects_source_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            generator.write_output(
                root,
                paths["output"],
                paths["config"],
                paths["foundry_config"],
                paths["out"],
                paths["checksums"],
            )
            write_text(paths["source"], "contract Example { address public changedOwner; }\n")

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = generator.check_output(
                    root,
                    paths["output"],
                    paths["config"],
                    paths["foundry_config"],
                    paths["out"],
                    paths["checksums"],
                )
            self.assertEqual(result, 1)

    def test_missing_source_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            paths["source"].unlink()

            with self.assertRaisesRegex(generator.SourceVerificationError, "missing"):
                generator.build_manifest(
                    root,
                    paths["output"],
                    paths["config"],
                    paths["foundry_config"],
                    paths["out"],
                    paths["checksums"],
                )

    def test_missing_artifact_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            paths["artifact"].unlink()

            with self.assertRaisesRegex(generator.SourceVerificationError, "artifact"):
                generator.build_manifest(
                    root,
                    paths["output"],
                    paths["config"],
                    paths["foundry_config"],
                    paths["out"],
                    paths["checksums"],
                )

    def test_abi_checksum_mismatch_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            checksum_data = json.loads(paths["checksums"].read_text(encoding="utf-8"))
            checksum_data["contracts"]["Example"]["abi_sha256"] = "sha256:" + "0" * 64
            write_json(paths["checksums"], checksum_data)

            with self.assertRaisesRegex(generator.SourceVerificationError, "ABI checksum"):
                generator.build_manifest(
                    root,
                    paths["output"],
                    paths["config"],
                    paths["foundry_config"],
                    paths["out"],
                    paths["checksums"],
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
