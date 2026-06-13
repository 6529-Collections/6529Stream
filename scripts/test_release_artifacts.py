#!/usr/bin/env python3
"""Focused tests for release artifact generation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("generate_release_artifacts.py")
SPEC = importlib.util.spec_from_file_location("generate_release_artifacts", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
generator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(generator)


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


class ReleaseArtifactTests(unittest.TestCase):
    def test_generator_outputs_event_topic_interface_id_and_hashes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            out_dir = root / "out"
            output_dir = root / "release-artifacts" / "latest"
            config_path = root / "release-artifacts" / "contracts.json"

            abi = [
                {
                    "type": "function",
                    "name": "supportsInterface",
                    "inputs": [{"name": "interfaceId", "type": "bytes4"}],
                    "outputs": [{"name": "", "type": "bool"}],
                    "stateMutability": "view",
                },
                {
                    "type": "function",
                    "name": "balanceOf",
                    "inputs": [{"name": "owner", "type": "address"}],
                    "outputs": [{"name": "", "type": "uint256"}],
                    "stateMutability": "view",
                },
                {
                    "type": "event",
                    "name": "Transfer",
                    "inputs": [
                        {"name": "from", "type": "address", "indexed": True},
                        {"name": "to", "type": "address", "indexed": True},
                        {"name": "tokenId", "type": "uint256", "indexed": True},
                    ],
                    "anonymous": False,
                },
            ]
            artifact = {
                "abi": abi,
                "bytecode": {"object": "0x6000"},
                "deployedBytecode": {"object": "0x6001"},
                "methodIdentifiers": {
                    "balanceOf(address)": "70a08231",
                    "supportsInterface(bytes4)": "01ffc9a7",
                },
            }
            write_json(out_dir / "Example.sol" / "Example.json", artifact)
            write_json(out_dir / "IExample.sol" / "IExample.json", artifact)
            write_json(
                config_path,
                {
                    "schema_version": "6529stream.release-artifact-contracts.v1",
                    "production_contracts": [
                        {"name": "Example", "source": "smart-contracts/Example.sol"}
                    ],
                    "interfaces": [
                        {
                            "name": "IExample",
                            "source": "smart-contracts/IExample.sol",
                            "interface_id": "0x12345678",
                        }
                    ],
                },
            )

            written = generator.generate_artifacts(root, config_path, out_dir, output_dir, "cast")
            self.assertEqual(
                sorted(path.name for path in written),
                [
                    "abi-checksums.json",
                    "event-topic-catalog.json",
                    "interface-ids.json",
                    "release-artifact-manifest.json",
                ],
            )

            abi_checksums = generator.load_json(output_dir / "abi-checksums.json")
            self.assertEqual(
                abi_checksums["contracts"]["Example"]["abi_sha256"],
                generator.sha256_json(abi),
            )
            self.assertEqual(
                abi_checksums["contracts"]["Example"]["bytecode_sha256"],
                generator.bytecode_hash("0x6000")["sha256"],
            )
            self.assertEqual(abi_checksums["contracts"]["Example"]["bytecode_linked"], True)
            self.assertEqual(abi_checksums["contracts"]["Example"]["bytecode_hash_mode"], "bytes")

            events = generator.load_json(output_dir / "event-topic-catalog.json")
            self.assertEqual(
                events["topics"][0]["topic0"],
                "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
            )
            self.assertEqual(events["topics"][0]["signature"], "Transfer(address,address,uint256)")
            self.assertEqual(events["topics"][0]["inputs"][2]["indexed"], True)

            interfaces = generator.load_json(output_dir / "interface-ids.json")
            expected_interface_id = 0x70A08231 ^ 0x01FFC9A7
            self.assertEqual(
                interfaces["interfaces"]["IExample"]["interface_id"],
                "0x12345678",
            )
            self.assertEqual(
                interfaces["interfaces"]["IExample"]["computed_selector_xor"],
                f"0x{expected_interface_id:08x}",
            )
            self.assertEqual(interfaces["interfaces"]["IExample"]["interface_id_source"], "configured")

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                self.assertEqual(
                    generator.check_artifacts(root, config_path, out_dir, output_dir, "cast"),
                    0,
                )

            (output_dir / "SHA256SUMS").write_text(
                "0" * 64 + "  release-artifacts/latest/abi-checksums.json\n",
                encoding="utf-8",
                newline="\n",
            )
            write_json(
                output_dir / "release-checksums.json",
                {"schema_version": "6529stream.release-checksums.v1"},
            )
            write_json(
                output_dir / "release-manifest.json",
                {"schema_version": "6529stream.release-manifest.v1"},
            )
            write_json(
                output_dir / "public-beta-evidence.json",
                {"schema_version": "6529stream.public-beta-evidence.v1"},
            )
            write_text(
                output_dir / "public-beta-blockers.md",
                "# Public Beta Evidence Blocker Report\n",
            )
            write_text(
                output_dir / "production-release-blockers.md",
                "# Production Release Evidence Blocker Report\n",
            )
            write_json(
                output_dir / "release-evidence-packet-index.json",
                {"schema_version": "6529stream.release-evidence-packet-index.v1"},
            )
            write_text(
                output_dir / "release-evidence-packet-index.md",
                "# Release Evidence Packet Index\n",
            )
            write_json(
                output_dir / "source-verification-inputs.json",
                {"schema_version": "6529stream.source-verification-inputs.v1"},
            )
            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                self.assertEqual(
                    generator.check_artifacts(root, config_path, out_dir, output_dir, "cast"),
                    0,
                )

            with (output_dir / "abi-checksums.json").open("a", encoding="utf-8") as handle:
                handle.write("\n")
            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                self.assertEqual(
                    generator.check_artifacts(root, config_path, out_dir, output_dir, "cast"),
                    1,
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
