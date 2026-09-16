"""Wrapper boundary controls with an explicitly stubbed base; no capture claim.

The retained actual capture is also exercised by the separate CLI integration
build/replay. These fast cases isolate typed joins, preservation and tampering.
"""
from contextlib import ExitStack
from copy import deepcopy
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads
from .chain_abi import calldata, encode
from . import object_dossier as base
from . import object_dossier_native_assembly as assembly
from .test_object_dossier_native import reference, bundle, envelope
from .test_owner_catalog_source import Fixture


class NativeAssemblyBoundaries(unittest.TestCase):
    def setUp(self):
        fixture = Fixture()
        views = {}
        for name, kinds, values in (("tokenCollectionIdentity", ("bool", "uint256", "uint256", "bool"), (True, 1, 1, False)),
                ("tokenLifecycle", ("uint8",), (2,)), ("ownerOf", ("address",), ("0x" + f"{2:040x}",))):
            views[name] = {"to": fixture.anchor["core"], "blockHash": fixture.anchor["blockHash"],
                "data": calldata(name + "(uint256)", ("uint256",), (71,)), "result": "0x" + encode(kinds, values).hex()}
        evidence = dumps({"tokenSourceBlockViews": views})
        fixture.anchor["deploymentEvidenceHash"] = keccak256(evidence)
        source = fixture.source(); self.reference = reference(source.a)
        row, files = bundle("owner", source)
        raw = envelope(self.reference, [row]); self.inputs = raw, keccak256(raw), files
        manifest = dumps({"sourceState": self.reference["sourceState"], "source": {"retainedManifestHash": keccak256(b"fixture")}})
        self.base_files = {"manifest.json": manifest, "inventory/report.json": b'{"complete":false}',
            "source/retained/manifest.json": b"stub retained manifest",
            "source/retained/inputs.json.gz": b"stub retained inputs", "keep.bin": b"unchanged"}
        self.base_hash = keccak256(manifest)
        self.base_result = base.Assembly(tuple(self.base_files.items()), manifest, {})
        self.originals = {"anchor.json": source.anchor_bytes, "deployment-evidence.json": evidence,
                          "transcript.json": source.transcript()}
        self.tools = {"tool/" + name + ".txt": b"raise RuntimeError('inert only')\n" for name in assembly.SOURCES}

    def context(self):
        stack = ExitStack()
        stack.enter_context(patch.object(base, "verify", return_value=self.base_result))
        stack.enter_context(patch.object(assembly, "read_fixture", return_value=(self.originals, {})))
        stack.enter_context(patch("socket.socket", side_effect=AssertionError("offline wrapper")))
        return stack

    def test_original_base_and_native_bytes_preserved_and_rebuilt_without_executing_snapshots(self):
        with self.context():
            result = assembly.assemble(self.base_files, self.base_hash, self.inputs, tool_snapshot=self.tools)
            files = dict(result.files)
            for path, raw in self.base_files.items(): self.assertEqual(files["base/" + path], raw)
            for path, raw in self.inputs[2].items(): self.assertEqual(files["native/data/" + path], raw)
            with patch.object(assembly, "_tools", wraps=assembly._tools) as snapshot:
                rebuilt = assembly.verify(files, result.manifest_hash)
                self.assertIsNotNone(snapshot.call_args.args[0])
            self.assertEqual(rebuilt.files, result.files)
            self.assertFalse(result.report["claims"]["fullObjectDossierConformance"])
            self.assertEqual(result.report["checks"][0]["status"], "synthetic_only")
            self.assertEqual(files["base/inventory/report.json"], self.base_files["inventory/report.json"])

    def test_wrong_external_pin_changed_files_and_rehashed_conformance_claim_reject_before_base_replay(self):
        with self.context():
            result = assembly.assemble(self.base_files, self.base_hash, self.inputs, tool_snapshot=self.tools)
        files = dict(result.files)
        manifest = loads(result.manifest, maximum=2 * 1024 * 1024)
        with patch.object(base, "verify", side_effect=AssertionError("must reject first")):
            with self.assertRaisesRegex(MuseumError, "external manifest"): assembly.verify(files, keccak256(b"wrong"))
            changed = dict(files); changed["base/keep.bin"] = b"changed"
            with self.assertRaisesRegex(MuseumError, "file commitments"): assembly.verify(changed, result.manifest_hash)
            value = deepcopy(manifest); value["claims"]["fullObjectDossierConformance"] = True
            raw = dumps(value); changed = files | {"manifest.json": raw}
            with self.assertRaisesRegex(MuseumError, "closed manifest"): assembly.verify(changed, keccak256(raw))

    def test_reference_is_derived_from_verified_originals_not_the_envelope(self):
        originals = dict(self.originals); originals["deployment-evidence.json"] = b"different graph"
        with self.context(), patch.object(assembly, "read_fixture", return_value=(originals, {})):
            with self.assertRaisesRegex(MuseumError, "original deployment"):
                assembly.assemble(self.base_files, self.base_hash, self.inputs, tool_snapshot=self.tools)

    def test_rehashed_missing_required_original_has_stable_rejection(self):
        with self.context():
            result = assembly.assemble(self.base_files, self.base_hash, self.inputs, tool_snapshot=self.tools)
        files = dict(result.files); files.pop("native/inputs.json")
        value = loads(result.manifest, maximum=2 * 1024 * 1024)
        value["files"] = [base._ref(p, b) for p, b in sorted(files.items()) if p != "manifest.json"]
        raw = dumps(value); files["manifest.json"] = raw
        with patch.object(base, "verify", side_effect=AssertionError("must reject first")):
            with self.assertRaisesRegex(MuseumError, "required original file"):
                assembly.verify(files, keccak256(raw))

    def test_missing_extra_or_non_utf8_inert_source_is_rejected(self):
        for snapshot in ({}, self.tools | {"extra": b"source"},
                         self.tools | {next(iter(self.tools)): b"\xff"}):
            with self.subTest(keys=list(snapshot)), self.context(), self.assertRaises((MuseumError, UnicodeDecodeError)):
                assembly.assemble(self.base_files, self.base_hash, self.inputs, tool_snapshot=snapshot)


if __name__ == "__main__": unittest.main()
