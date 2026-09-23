"""Concrete synthetic source joins and clearly stubbed wrapper boundaries.

The actual retained token fixture is exercised separately by the worked CLI
roundtrip. Fabricated source fixtures here never establish chain acceptance.
"""
from contextlib import ExitStack
from copy import deepcopy
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from . import dossier_gather as gather
from .canonical import MuseumError, dumps, keccak256, loads
from .chain_abi import calldata, encode
from .test_object_dossier_native import reference, bundle
from .test_owner_catalog_source import Fixture as OwnerFixture, A


def inputs(ref, rows):
    return dumps({"profile": gather.INPUT_PROFILE, "version": "1", "disclosure": "public",
        "sourceState": ref["sourceState"], "sources": rows})


def replay(ref, rows, files):
    raw = inputs(ref, rows)
    with patch("socket.socket", side_effect=AssertionError("gather must remain offline")):
        return gather._replay_sources(raw, keccak256(raw), files, ref)


class GatherReplayTests(unittest.TestCase):
    def test_prepare_inputs_preserves_original_triplets_and_hashes(self):
        source = OwnerFixture().source(); ref = reference(source.a)
        row, files = bundle("owner", source)
        prepared = gather.prepare_inputs(ref["sourceState"], files, disclosure="public", provenance="synthetic_fixture")
        self.assertEqual(loads(prepared["inputs.json"], maximum=gather.MAX_MANIFEST)["sources"], [row])
        self.assertEqual({p[5:]: b for p, b in prepared.items() if p.startswith("data/")}, files)
        for bad in (files | {"extra.txt": b"unselected"}, {k: v for k, v in files.items() if not k.endswith("snapshot.json")}):
            with self.assertRaises(MuseumError):
                gather.prepare_inputs(ref["sourceState"], bad, disclosure="public", provenance="synthetic_fixture")

    def test_citation_original_identity_and_rec_choices_join_the_reference(self):
        from .test_canonical_citation_source import Fixture
        f = Fixture(recovery=True); source = f.source()
        ref = reference(source.a, serial="7")
        row, files = bundle("citation", source)
        sources, _ = replay(ref, [row], files)
        choices = gather._citation_choices(ref, sources)["choices"]
        self.assertTrue(any(c["kind"] == "rec" and c["hash"] == sources[0]["snapshot"]["recovery"]["records"][0]["record"][10][2] for c in choices))
        payloads, manifests = gather._citation_files(sources)
        self.assertEqual({m["kind"] for m in manifests}, {"fin", "snap", "rec"})
        for m in manifests:
            self.assertEqual(keccak256(payloads[m["path"]]), m["manifestHash"])
            if m["chunks"]:
                self.assertEqual(b"".join(payloads[c["path"]] for c in m["chunks"]), payloads[m["path"]])
        # A coherently re-pinned transcript/snapshot passes its own native replay,
        # but cannot change the original token's serial or lifecycle in the join.
        f.call(f.core, "tokenCollectionIdentity(uint256)", ("bool", "uint256", "uint256", "bool"), (True, 1, 8, False), ("uint256",), (41,))
        changed = f.source(); changed_row, changed_files = bundle("citation", changed)
        with self.assertRaisesRegex(MuseumError, "collection serial"):
            replay(ref, [changed_row], changed_files)
        burned = Fixture(recovery=True, burned=True).source()
        burned_row, burned_files = bundle("citation", burned)
        with self.assertRaisesRegex(MuseumError, "citation Core facts"):
            replay(ref, [burned_row], burned_files)

    def test_owner_native_occurrences_and_derived_chain_choices(self):
        source = OwnerFixture().source()
        ref = reference(source.a)
        row, files = bundle("owner", source)
        sources, coverage = replay(ref, [row], files)
        self.assertEqual(sources[0]["snapshot"], loads(source.snapshot(), maximum=gather.MAX_BYTES))
        self.assertEqual(sources[0]["undeclaredAnchorFields"], [])
        self.assertEqual(coverage[0]["status"], "synthetic_only")
        choices = gather._citation_choices(ref, sources)["choices"]
        native = [r for r in choices if r["sourceId"] != "retained-token-fixture"]
        self.assertTrue(native)
        self.assertTrue(all(r["kind"] == "chain" and r["provenance"] == "synthetic_fixture" for r in native))
        self.assertEqual({r["hash"] for r in native}, {l["head"] for l in sources[0]["snapshot"]["lanes"] if l["count"] != "0"})

    def test_general_v2_dispatch_uses_real_reader_and_keeps_original_chunks(self):
        from .test_general_attestation_source_v2 import Fixture
        f = Fixture(generic_payload_bytes=24576); source = f.reader()
        ref = reference(source.a, collection=source.a["collectionId"])
        row, files = bundle("general", source)
        sources, _ = replay(ref, [row], files)
        self.assertEqual(sources[0]["snapshot"], loads(source.snapshot(), maximum=gather.MAX_BYTES))
        self.assertEqual(len(sources[0]["snapshot"]["lanes"]), 4)
        self.assertTrue(any(len(r["payloadChunks"]) == 3 for r in sources[0]["snapshot"]["records"]))

    def test_legacy_inventory_joins_original_fields_without_inventing_missing_fields(self):
        from .test_object_inventory_source import Fixture
        f = Fixture(); source = f.source(); snap = loads(source.snapshot(), maximum=gather.MAX_BYTES)
        # The source does not authenticate these two enclosing context fields.
        context = source.a | {"core": snap["core"], "environment": "local_evm_fixture",
            "deploymentEvidenceHash": keccak256(b"synthetic external context")}
        ref = reference(context)
        row, files = bundle("inventory", source)
        sources, _ = replay(ref, [row], files)
        self.assertEqual(sources[0]["undeclaredAnchorFields"], ["environment", "deploymentEvidenceHash"])
        self.assertNotIn("environment", sources[0]["anchor"])
        self.assertNotIn("deploymentEvidenceHash", sources[0]["anchor"])
        changed = deepcopy(ref); changed["sourceState"]["tokenId"] = "999"
        from .canonical import subject_id
        from .citations_v2 import canonical_citation
        s = changed["sourceState"]
        s["subjectId"] = subject_id("token", s["chainId"], s["core"], s["collectionId"], token_id="999")
        s["canonicalCitation"] = canonical_citation(s["chainId"], s["core"], "999", {"kind": "chain", "hash": s["blockHash"]})
        with self.assertRaisesRegex(MuseumError, "token membership"):
            replay(changed, [row], files)

    def test_source_pin_rehashed_snapshot_and_provenance_tampering_reject(self):
        source = OwnerFixture().source(); ref = reference(source.a); row, files = bundle("owner", source)
        changed = dict(files); snap = loads(source.snapshot(), maximum=gather.MAX_BYTES)
        snap["claims"]["actualChainAcceptance"] = True
        changed[row["snapshotPath"]] = dumps(snap)
        with self.assertRaisesRegex(MuseumError, "replay differs"):
            replay(ref, [row | {"snapshotHash": keccak256(changed[row["snapshotPath"]])}], changed)
        with self.assertRaisesRegex(MuseumError, "replay differs"):
            replay(ref, [row | {"provenance": "trusted_rpc"}], files)
        raw = inputs(ref, [row])
        with self.assertRaisesRegex(MuseumError, "external pin"):
            gather._replay_sources(raw, keccak256(b"wrong"), files, ref)

    def test_shared_rpc_and_code_conflicts_and_logical_duplicates_reject(self):
        source = OwnerFixture().source(); ref = reference(source.a); row, files = bundle("owner", source)
        query = source.reader.rows[0]
        ref["rpcReadPins"] = [{"requestHash": keccak256(dumps([query["method"], query["params"]])),
            "resultHash": keccak256(dumps("contradiction"))}]
        with self.assertRaisesRegex(MuseumError, "conflicting results"):
            replay(ref, [row], files)
        ref = reference(source.a)
        ref["sourceAnchor"]["runtimePins"] = deepcopy(ref["sourceAnchor"]["runtimePins"])
        ref["sourceAnchor"]["runtimePins"][0]["runtimeHash"] = keccak256(b"wrong")
        with self.assertRaises(MuseumError):
            replay(ref, [row], files)
        other, more = bundle("owner", source, identifier="zz")
        with self.assertRaisesRegex(MuseumError, "duplicate logical"):
            replay(reference(source.a), [row, other], files | more)

    def test_no_native_sources_preserves_unknowns_and_closed_file_set(self):
        source = OwnerFixture().source(); ref = reference(source.a)
        self.assertEqual(replay(ref, [], {}), ([], []))
        row, files = bundle("owner", source)
        for rows, originals in (([row | {"complete": True}], files),
                ([row], files | {"unused": b"data"}), ([row | {"id": "retained-token-fixture"}], files)):
            with self.assertRaises(MuseumError):
                replay(ref, rows, originals)


class GatherWrapperTests(unittest.TestCase):
    def setUp(self):
        f = OwnerFixture()
        views = {}
        for name, kinds, values in (("tokenCollectionIdentity", ("bool", "uint256", "uint256", "bool"), (True, 1, 1, False)),
                ("tokenLifecycle", ("uint8",), (2,)), ("ownerOf", ("address",), (A(2),))):
            views[name] = {"to": f.anchor["core"], "blockHash": f.anchor["blockHash"],
                "data": calldata(name + "(uint256)", ("uint256",), (71,)), "result": "0x" + encode(kinds, values).hex()}
        evidence = dumps({"tokenSourceBlockViews": views})
        f.anchor["deploymentEvidenceHash"] = keccak256(evidence)
        source = f.source(); self.ref = reference(source.a)
        row, self.source_files = bundle("owner", source)
        self.raw = inputs(self.ref, [row]); self.raw_hash = keccak256(self.raw)
        self.retained = {"manifest.json": b"stub only", "inputs.json.gz": b"stub only"}
        self.retained_hash = keccak256(b"stub fixture pin")
        self.originals = {"anchor.json": source.anchor_bytes, "deployment-evidence.json": evidence,
            "transcript.json": source.transcript()}
        self.bag = SimpleNamespace(files=(("stream-manifest.json", b"stub scoped bag"),), manifest_hash=keccak256(b"bag"))
        self.result_tuple = (self.ref["sourceState"], self.originals,
            SimpleNamespace(manifest_hash=keccak256(b"export")), self.bag,
            SimpleNamespace(inventory_hash=keccak256(b"ocfl")))
        self.tools = {"tool/" + p + ".txt": b"raise RuntimeError('inert only')\n" for p in gather.TOOL_NAMES}

    def context(self):
        stack = ExitStack()
        stack.enter_context(patch.object(gather.base, "_replay", return_value=self.result_tuple))
        stack.enter_context(patch("socket.socket", side_effect=AssertionError("offline wrapper")))
        return stack

    def build(self):
        return gather.gather(self.retained, self.retained_hash, self.raw, self.raw_hash,
            self.source_files, disclosure="public", tool_snapshot=self.tools)

    def test_exact_originals_real_extracted_occurrences_and_offline_reconstruction(self):
        with self.context():
            result = self.build(); files = dict(result.files)
            rebuilt = gather.verify(files, result.manifest_hash)
        self.assertEqual(rebuilt.files, result.files)
        self.assertEqual(files["source/scoped-bag/stream-manifest.json"], b"stub scoped bag")
        for name, raw in self.source_files.items():
            self.assertEqual(files["sources/" + name], raw)
        extracted = loads(files["gathered/index.json"], maximum=gather.MAX_BYTES)
        self.assertEqual(len(extracted["records"]), 4)
        self.assertEqual(len(extracted["heads"]), 11)
        for row in extracted["records"]:
            self.assertIn(row["payloadPath"], files)
            self.assertIn(row["signatureBundlePath"], files)
        self.assertEqual(len(result.report["items"]), 19)
        self.assertEqual([r["item"] for r in result.report["items"] if r["status"] == "derived"], ["1", "2", "19"])
        self.assertFalse(result.report["canonicalPacketReady"])
        self.assertIn(b"Ownership and title provenance", files["packet/examination.md"])

    def test_public_preflight_before_sources_and_strict_packet_refusal(self):
        with patch.object(gather.base, "_replay", side_effect=AssertionError("must not read")):
            with self.assertRaisesRegex(MuseumError, "public disclosure"):
                gather.gather({}, "", b"", "", {}, disclosure="restricted")
        with self.context():
            result = self.build()
            with self.assertRaisesRegex(MuseumError, "unresolved items: 3, 4, 5"):
                gather.export_complete_packet(dict(result.files), result.manifest_hash)

    def test_closed_package_dispatch_replays_the_new_mode(self):
        from pathlib import Path
        from tempfile import TemporaryDirectory
        from .bagit import write_tree
        from .package_v2 import verify_package
        with self.context(), TemporaryDirectory(prefix="gather-dispatch-") as temporary:
            result = self.build()
            path = Path(temporary) / "package"
            write_tree(dict(result.files), path)
            self.assertEqual(verify_package(path, result.manifest_hash).files, result.files)

    def test_both_cli_write_commands_check_disclosure_before_files(self):
        for command, extra in (("prepare-inputs", ["--captures", "missing", "--provenance", "trusted_rpc"]),
                ("build", ["--sources", "missing", "--sources-hash", keccak256(b"missing")])):
            arguments = ["dossier_gather", command, "--fixture", "missing", "--fixture-hash", self.retained_hash,
                "--output", "missing", "--disclosure", "restricted", *extra]
            with self.subTest(command=command), patch("sys.argv", arguments), \
                    patch.object(gather, "read_tree", side_effect=AssertionError("public preflight must precede reads")):
                with self.assertRaisesRegex(MuseumError, "public disclosure"):
                    gather.main()

    def test_file_pins_and_rehashed_completion_claim_reject_before_replay(self):
        with self.context():
            result = self.build()
        files = dict(result.files)
        with patch.object(gather.base, "_replay", side_effect=AssertionError("must reject first")):
            with self.assertRaisesRegex(MuseumError, "external manifest"):
                gather.verify(files, keccak256(b"wrong"))
            changed = files | {"packet/examination.md": b"changed"}
            with self.assertRaisesRegex(MuseumError, "file commitments"):
                gather.verify(changed, result.manifest_hash)
            value = loads(result.manifest, maximum=gather.MAX_MANIFEST)
            value["claims"]["canonicalAcquisitionPacketEmitted"] = True
            raw = dumps(value)
            with self.assertRaisesRegex(MuseumError, "closed manifest"):
                gather.verify(files | {"manifest.json": raw}, keccak256(raw))

    def test_rehashed_derived_field_must_rebuild_and_inert_code_is_not_executed(self):
        with self.context():
            result = self.build(); files = dict(result.files)
            report = loads(files["packet/fields.json"], maximum=gather.MAX_BYTES)
            report["derived"]["erc721Identity"]["collectionSerial"] = "999"
            files["packet/fields.json"] = dumps(report)
            value = loads(result.manifest, maximum=gather.MAX_MANIFEST)
            value["files"] = [gather.base._ref(p, b) for p, b in sorted(files.items()) if p != "manifest.json"]
            raw = dumps(value); files["manifest.json"] = raw
            with self.assertRaisesRegex(MuseumError, "source reconstruction"):
                gather.verify(files, keccak256(raw))


if __name__ == "__main__":
    unittest.main()
