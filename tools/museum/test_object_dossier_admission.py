"""Fast supplied-component wiring tests for the partial dossier assembler."""
from copy import deepcopy
from hashlib import sha256
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads, subject_id
from .object_dossier_components import MODE
from .object_dossier_inventory import REQUIREMENTS
from . import object_dossier as dossier


CORE = "0x" + "11" * 20
BLOCK = "0x" + "22" * 32
HEAD = "0x" + "33" * 32
PIN = "0x" + "44" * 32


def source_state():
    return {"chainId": "31337", "core": CORE, "collectionId": "1", "tokenId": "7",
        "collectionSerial": "1", "subjectId": subject_id("token", "31337", CORE, "1", token_id="7"),
        "blockNumber": "900", "blockHash": BLOCK,
        "canonicalCitation": "eip155:31337/erc721:" + CORE + "/7@chain:" + HEAD}


def component(identifier, requirement, path, content):
    return {"id": identifier, "requirement": requirement, "profile": "EXTERNAL_COMPONENT_V1",
        "path": path, "bytes": str(len(content)), "sha256": "0x" + sha256(content).hexdigest(),
        "keccak256": keccak256(content)}


class ObjectDossierAdmissionTests(unittest.TestCase):
    def setUp(self):
        self.state = source_state()
        self.retained = {"manifest.json": b"retained manifest", "inputs.json.gz": b"retained inputs"}
        self.originals = {"test-image.png": b"image", "deployment-evidence.json": b"mint evidence"}
        self.export = SimpleNamespace(manifest_hash="0x" + "55" * 32)
        self.bag = SimpleNamespace(manifest_hash="0x" + "66" * 32,
            files=(("data/example.bin", b"scoped bag"),))
        self.ocfl = SimpleNamespace(inventory_hash="0x" + "77" * 32)
        self.snapshot = {"tool/" + name + ".txt": (name + "\n").encode()
            for name in dossier.SOURCE_NAMES}

    def assemble(self, rows=(), files=None, state=None):
        selected_state = deepcopy(self.state if state is None else state)
        value = {"mode": MODE, "version": "1", "disclosure": "public", "sourceState": selected_state,
            "components": list(rows)}
        raw = dumps(value)
        component_input = (raw, keccak256(raw), {} if files is None else files)
        replay = (deepcopy(self.state), self.originals, self.export, self.bag, self.ocfl)
        with patch.object(dossier, "_replay", return_value=replay):
            return dossier.assemble(self.retained, PIN, components=component_input,
                tool_snapshot=self.snapshot)

    def test_components_are_namespaced_and_reported_only_as_supplied_unverified(self):
        content = b"same occurrence bytes"
        rows = [component("a:first", "OD-C2PA", "claims/first.bin", content),
            component("b:second", "OD-IIIF", "claims/second.bin", content)]
        result = self.assemble(rows, {row["path"]: content for row in rows})
        files = dict(result.files)
        self.assertEqual(files["supplied/data/claims/first.bin"], content)
        self.assertEqual(files["supplied/data/claims/second.bin"], content)
        self.assertEqual(loads(files["supplied/components.json"], canonical=True)["components"], rows)
        states = {row["code"]: row for row in result.report["results"]}
        self.assertEqual(states["OD-C2PA"]["state"], "supplied_unverified")
        self.assertEqual(states["OD-IIIF"]["state"], "supplied_unverified")
        self.assertEqual(states["OD-C2PA"]["suppliedHashes"], [keccak256(content)])
        self.assertEqual(states["OD-C2PA"]["evidenceRefs"], [])
        manifest = loads(result.manifest, canonical=True)
        self.assertEqual(manifest["suppliedComponentsHash"], keccak256(files["supplied/components.json"]))
        self.assertFalse(result.report["complete"])

    def test_every_nonidentity_component_stays_unverified_and_cannot_complete(self):
        codes = sorted(row["code"] for row in REQUIREMENTS if row["code"] != "identity")
        rows, files = [], {}
        for index, code in enumerate(codes):
            content = ("supplied:" + code).encode()
            path = f"all/{index:02d}.bin"
            rows.append(component(f"component:{index:02d}", code, path, content))
            files[path] = content
        result = self.assemble(rows, files)
        states = {row["code"]: row["state"] for row in result.report["results"]}
        self.assertEqual(states["identity"], "verified")
        self.assertEqual({code for code, state in states.items() if state == "verified"}, {"identity"})
        self.assertTrue(all(states[code] == "supplied_unverified" for code in codes))
        self.assertEqual(result.report["counts"]["verified"], 1)
        self.assertEqual(result.report["counts"]["suppliedUnverified"], len(codes))
        self.assertFalse(result.report["complete"])
        self.assertFalse(result.report["conformanceClaimed"])

    def test_supplied_identity_cannot_replace_or_duplicate_verified_core_identity(self):
        content = b"claimed identity"
        row = component("component:identity", "identity", "identity.bin", content)
        with self.assertRaisesRegex(MuseumError, "supplied identity cannot replace"):
            self.assemble([row], {row["path"]: content})

    def test_wrong_source_block_or_subject_rejects_before_any_report_is_emitted(self):
        content = b"component"
        row = component("component:one", "OD-C2PA", "component.bin", content)
        mutations = []
        wrong_block = deepcopy(self.state); wrong_block["blockNumber"] = "901"; mutations.append(wrong_block)
        wrong_subject = deepcopy(self.state); wrong_subject["subjectId"] = "0x" + "88" * 32; mutations.append(wrong_subject)
        for state in mutations:
            with self.subTest(state=state), \
                    patch.object(dossier, "assess", side_effect=AssertionError("phantom report")), \
                    self.assertRaises(MuseumError):
                self.assemble([row], {row["path"]: content}, state=state)


if __name__ == "__main__": unittest.main()
