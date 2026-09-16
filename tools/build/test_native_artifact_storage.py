"""Native fixture exports preserve storage-layout availability without fabricating it."""
import copy
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = "smart-contracts/Example.sol"
NAME = "Example"
spec = importlib.util.spec_from_file_location("native_fixture_projection", ROOT / "test/helpers/native_assembly_artifacts.py")
projection = importlib.util.module_from_spec(spec)
spec.loader.exec_module(projection)

class NativeArtifactStorageTests(unittest.TestCase):
    def fixture(self, root, emitted):
        metadata = json.dumps({"settings": {"compilationTarget": {SOURCE: NAME}}})
        evm = {"bytecode": {"object": "00", "sourceMap": "", "linkReferences": {}},
               "deployedBytecode": {"object": "00", "sourceMap": "", "linkReferences": {}, "immutableReferences": {}},
               "methodIdentifiers": {}}
        native = {"abi": [], "metadata": metadata, "evm": evm}
        if emitted: native["storageLayout"] = {"storage": [], "types": {}}
        source = {"ast": {"absolutePath": SOURCE, "nodes": []}, "id": 0}
        build = {"id": "unit", "solcVersion": "0.8.19",
                 "input": {"sources": {SOURCE: {"content": "contract Example {}"}}},
                 "output": {"contracts": {SOURCE: {NAME: native}}, "sources": {SOURCE: source}}}
        artifact = {"abi": [], "bytecode": copy.deepcopy(evm["bytecode"]),
                    "deployedBytecode": copy.deepcopy(evm["deployedBytecode"]),
                    "methodIdentifiers": {}, "rawMetadata": metadata, "metadata": json.loads(metadata), **source}
        if emitted: artifact["storageLayout"] = copy.deepcopy(native["storageLayout"])
        files = {"out/current/build-info/unit.json": build, "out/current/Example.sol/Example.json": artifact,
                 "products.json": {NAME: SOURCE}, "helpers.json": {},
                 "cache/current/solidity-files-cache.json": {"files": {SOURCE: {"artifacts": {NAME: {"0.8.19": {
                     "current": {"path": "Example.sol/Example.json", "build_id": "unit"}}}}}}}}
        for name, value in files.items():
            path = root / name; path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(value), encoding="utf-8")
        return root / "out/current/Example.sol/Example.json"

    def export(self, root):
        return subprocess.run([sys.executable, str(ROOT / "test/helpers/native_assembly_native_exports.py"),
            "--project", str(root), "--build-id", "unit", "--products", str(root / "products.json"),
            "--helpers", str(root / "helpers.json"), "--output", str(root / "export")],
            text=True, encoding="utf-8", stdout=subprocess.PIPE, stderr=subprocess.STDOUT)

    def test_both_non_emission_and_real_empty_layout_round_trip_distinctly(self):
        for emitted in (False, True):
            with self.subTest(emitted=emitted), tempfile.TemporaryDirectory() as folder:
                root = Path(folder); self.fixture(root, emitted)
                result = self.export(root); self.assertEqual(result.returncode, 0, result.stdout)
                exported = json.loads((root / "export/Example.sol/Example.json").read_text(encoding="utf-8"))
                self.assertEqual("storageLayout" in exported, emitted)
                manifest = json.loads((root / "export/manifest.json").read_text(encoding="utf-8"))
                self.assertEqual(manifest["products"][NAME]["storageLayoutEmitted"], {"physical": emitted, "current": emitted})
                report = projection.project(root / "out/current/build-info/unit.json", root / "export", root / "projection", {NAME: SOURCE}, True)
                self.assertEqual(report["products"][NAME]["storageLayoutEmitted"], emitted)

    def test_one_sided_emission_or_layout_mutation_is_rejected(self):
        for native_emitted, physical_emitted, mutate in ((False, True, False), (True, False, False), (True, True, True)):
            with self.subTest(native=native_emitted, physical=physical_emitted, mutate=mutate), tempfile.TemporaryDirectory() as folder:
                root = Path(folder); path = self.fixture(root, native_emitted)
                artifact = json.loads(path.read_text(encoding="utf-8"))
                if physical_emitted: artifact["storageLayout"] = {"storage": ["changed"] if mutate else [], "types": {}}
                else: artifact.pop("storageLayout", None)
                path.write_text(json.dumps(artifact), encoding="utf-8")
                self.assertNotEqual(self.export(root).returncode, 0)
                self.assertFalse((root / "export").exists())

    def test_projection_cannot_claim_a_fabricated_empty_layout(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); self.fixture(root, False)
            result = self.export(root); self.assertEqual(result.returncode, 0, result.stdout)
            path = root / "export/Example.sol/Example.json"; artifact = json.loads(path.read_text(encoding="utf-8"))
            artifact["storageLayout"] = {"storage": [], "types": {}}
            path.write_text(json.dumps(artifact), encoding="utf-8")
            with self.assertRaisesRegex(AssertionError, "storage layout emission"):
                projection.project(root / "out/current/build-info/unit.json", root / "export", root / "projection", {NAME: SOURCE}, True)
            self.assertFalse((root / "projection").exists())

if __name__ == "__main__": unittest.main()
