"""Reject executable-origin substitutions and changed provenance before any RPC."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from .canonical import dumps, keccak256
from .token_native_manifest import EXTENSIONS, build_manifest


class TokenNativeManifestTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.base = self.root / "base"
        self.extension = self.root / "extension"
        self.base.mkdir(); self.extension.mkdir()
        self.products = {name: self.product(self.base, name) for name in ("StreamCore", "StreamMetadataRenderer")}
        museum_products = {name: self.product(self.extension, name) for name in EXTENSIONS}
        # The original extension compiler consumed an older renderer source.
        for name in EXTENSIONS:
            path = Path(museum_products[name]["artifact"])
            value = json.loads(path.read_bytes())
            value["bytecode"]["linkReferences"] = {"smart-contracts/StreamMetadataRenderer.sol": {"StreamMetadataRenderer": []}}
            path.write_bytes(dumps(value)); museum_products[name]["sha256"] = self.hash(path)
        safe = self.write("safe.json", {})
        self.museum = self.write("museum.json", {"mode": "current_museum_native_products_v1",
            "products": museum_products, "safeFixture": safe})
        self.handoff = {"acceptedGraphHead": "a" * 40, "tests": {"accepted": True},
            "captureManifest": self.write("capture.json", {}),
            "acceptedResult": self.write("result.json", {"accepted": True}),
            "currentGraphProjection": self.write("projection.json", {}), "sourceRecipes": [],
            "products": {row["source"] + ":" + name: dict(row, contract=name) for name, row in self.products.items()}}
        self.handoff_pin = self.write("handoff.json", self.handoff)

    @staticmethod
    def hash(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()

    def write(self, name, value):
        path = self.root / name; path.write_bytes(dumps(value))
        return {"path": str(path), "sha256": self.hash(path)}

    def product(self, project, name):
        source = "smart-contracts/" + name + ".sol"
        path = project / source; path.parent.mkdir(exist_ok=True)
        raw = ("contract " + name + " {}\r\n").encode(); path.write_bytes(raw)
        artifact = project / "out" / (name + ".sol") / (name + ".json")
        artifact.parent.mkdir(parents=True)
        artifact.write_bytes(dumps({"abi": [], "metadata": {"settings": {"compilationTarget": {source: name}},
            "sources": {source: {"keccak256": keccak256(raw)}}},
            "bytecode": {"object": "0x00", "linkReferences": {}},
            "deployedBytecode": {"object": "0x00", "linkReferences": {}}}))
        return {"source": source, "artifact": str(artifact), "sha256": self.hash(artifact)}

    def build(self):
        return json.loads(build_manifest(self.handoff_pin["path"], self.handoff_pin["sha256"],
            self.museum["path"], self.museum["sha256"], ["StreamCore"]))

    def test_new_composition_keeps_exact_origins_and_original_source_bytes(self):
        result = self.build()
        self.assertFalse(result["tokenComposition"]["joinedCompositionPreviouslyAccepted"])
        self.assertEqual(result["products"]["StreamMetadataRenderer"]["origin"], "accepted_mint_graph")
        self.assertEqual(set(result["products"]), set(self.products) | EXTENSIONS)
        for row in result["tokenComposition"]["extensionCompilationSources"]:
            self.assertTrue(row["contentUtf8"].endswith("\r\n"))
            self.assertEqual(hashlib.sha256(row["contentUtf8"].encode()).hexdigest(), row["sha256"])

    def test_changed_artifact_is_rejected(self):
        Path(self.products["StreamCore"]["artifact"]).write_bytes(b"{}")
        with self.assertRaisesRegex(ValueError, "input pin differs"): self.build()

    def test_changed_original_compilation_source_is_rejected(self):
        (self.extension / "smart-contracts/StreamCollectionAttestations.sol").write_bytes(b"changed")
        with self.assertRaisesRegex(ValueError, "compilation source changed"): self.build()

    def test_extension_cannot_overlap_the_base(self):
        name = "StreamCollectionAttestations"
        row = self.product(self.base, name)
        self.handoff["products"][row["source"] + ":" + name] = dict(row, contract=name)
        self.handoff_pin = self.write("handoff.json", self.handoff)
        with self.assertRaisesRegex(ValueError, "unexpectedly overlaps"): self.build()

    def test_unaccepted_base_result_is_rejected_even_when_handoff_says_accepted(self):
        self.handoff["acceptedResult"] = self.write("result.json", {"accepted": False})
        self.handoff_pin = self.write("handoff.json", self.handoff)
        with self.assertRaisesRegex(ValueError, "result was not accepted"): self.build()

    def test_changed_handoff_is_rejected_before_selection(self):
        Path(self.handoff_pin["path"]).write_bytes(b"{}")
        with self.assertRaisesRegex(ValueError, "input pin differs"): self.build()


if __name__ == "__main__": unittest.main()
