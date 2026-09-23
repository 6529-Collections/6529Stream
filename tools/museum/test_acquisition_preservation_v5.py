"""Original release chronology, exact native preimages and unchanged packet retention."""
from copy import deepcopy
from contextlib import redirect_stdout
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import acquisition_preservation_v5 as assembly
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .independent_wire import ZERO
from .preservation_v5_fixture import PreservationV5Fixture

H = lambda value: keccak256(str(value).encode())


def publication(block, log=0):
    return {"blockNumber": str(block), "transactionIndex": "0", "logIndex": str(log),
        "blockHash": H("block" + str(block)), "transactionHash": H("tx" + str(block))}


def event(block, log=0):
    row = publication(block, log)
    return {key: hex(int(value)) if key in ("blockNumber", "transactionIndex", "logIndex") else value
        for key, value in row.items()}


def join_inputs():
    context = [H("subject"), H("membership"), H("inventory"), H("script"), H("source context"), True]
    facts = [context[4], H("saved masters"), H("saved reference")]
    source = ["0x" + "11" * 20, H("metadata code"), "0x" + "22" * 20,
        H("provider code"), H("configuration"), "0", "2", H("admission action")]
    release = {"receiptHash": H("release receipt"), "releaseKey": H("release key"), "collectionId": "1",
        "sourceId": "1", "sourceSetHash": H("source head"), "publication": publication(8, 5),
        "receipt": [H("release receipt"), H("release key"), "1", H("tier"), "0x" + "33" * 20,
            H("settlement"), "8", "1", H("source head"), context, facts]}
    selection = ["1", context[0], H("manifest"), "1", H("display"), H("object"),
        [H("master record")], [H("artist"), H("binding"), "1", H("identity")],
        H("master object"), H("coverage"), "0", ZERO, "1", H("selection")]
    candidate = {"subjectId": context[0], "manifestHash": H("manifest"), "inventoryHash": context[2],
        "hashes": [H("display"), ZERO, ZERO], "association": selection[7],
        "slotSelections": [selection, None, None], "archiveHashes": [H("archive"), ZERO, ZERO],
        "factsHash": facts[1], "publication": publication(6)}
    receipt = [H("reference"), H("reference chain"), "1", H("reference id"), ZERO, "1",
        context[0], context[1], H("prospective source"), H("payload"), "300", "0x" + "44" * 20,
        "3", "1", "5", "5", H("reason"), H("schema"), H("profile"), H("canon")]
    record = {"recordHash": receipt[0], "receipt": receipt, "publication": publication(5),
        "originalSource": ["1", release["sourceSetHash"], source, context], "evidenceHash": facts[2],
        "originalDependencies": [None] * 6 + ["100", "200", "300"]}
    snapshots = {"masters": {"historicalCandidates": [candidate], "mediaContext": {"inventoryHash": H("new current")},
        "source": {"host": source[0], "codePins": [{"address": source[0], "runtimeHash": source[1]}]},
        "manifestSelections": [{"manifestHash": H("manifest"), "supportedHost": True,
            "host": source[0], "codeHash": source[1], "publication": publication(3)}],
        "slots": {"1": {"history": [selection], "events": [event(6)]},
            "2": {"history": [], "events": []}, "3": {"history": [], "events": []}}},
        "references": {"records": [record], "currentSource": {"status": "not_evaluated"},
            "gasHistory": {"registrations": [{"parameterId": H(index), "genesisValue": str(index * 100),
                "publication": publication(1, index)} for index in (1, 2, 3)], "updates": []}}}
    catalogue = {"sources": [{"sourceId": "1", "source": source, "admission": {"publication": publication(2)}}]}
    packet = {"conservation": {"floor": {"floor": {"releases": [release]}, "catalogue": catalogue}}}
    return packet, snapshots, {"sourceId": "1"}


class PreservationChronologyTests(unittest.TestCase):
    def setUp(self): self.packet, self.snapshots, self.provider = join_inputs()

    @property
    def release(self): return self.packet["conservation"]["floor"]["floor"]["releases"][0]

    def join(self): return assembly._join(self.packet, self.snapshots, self.provider)

    def test_original_hashes_join_without_current_eligibility_or_generic_conversion(self):
        result = self.join(); release = result["releases"][0]
        self.assertEqual(release["masters"]["status"], "original_native_master_evidence_joined")
        self.assertEqual(release["references"]["status"], "original_native_prospective_evidence_joined")
        self.assertEqual(result["currentProspectiveSource"]["status"], "not_evaluated")
        self.assertFalse(result["historicalExecutionRevalidated"])
        self.assertFalse(result["genericPreservation"]["mediaClassInferred"])
        self.assertFalse(result["sourceCoverageComplete"])

    def test_later_master_and_reference_replacements_preserve_original_join(self):
        native = self.snapshots["masters"]
        later = deepcopy(native["slots"]["1"]["history"][0]); later[13] = H("later master")
        native["slots"]["1"]["history"].append(later)
        native["slots"]["1"]["events"].append(event(9))
        record = deepcopy(self.snapshots["references"]["records"][0])
        record.update(recordHash=H("later reference"), evidenceHash=H("later ref evidence"), publication=publication(9, 2))
        self.snapshots["references"]["records"].append(record)
        self.assertTrue(self.join()["releases"][0]["references"]["headAtReleaseMatches"])

    def test_same_transaction_master_replacement_before_release_rejects(self):
        row = deepcopy(self.snapshots["masters"]["slots"]["1"]["history"][0])
        row[13] = H("replacement")
        self.snapshots["masters"]["slots"]["1"]["history"].append(row)
        self.snapshots["masters"]["slots"]["1"]["events"].append(event(8, 4))
        with self.assertRaisesRegex(MuseumError, "master superseded before"): self.join()

    def test_same_transaction_reference_replacement_before_release_rejects(self):
        row = deepcopy(self.snapshots["references"]["records"][0])
        row.update(recordHash=H("replacement"), evidenceHash=H("replacement evidence"), publication=publication(8, 4))
        self.snapshots["references"]["records"].append(row)
        with self.assertRaisesRegex(MuseumError, "reference superseded before"): self.join()

    def test_matching_late_master_is_not_backdated(self):
        self.snapshots["masters"]["historicalCandidates"][0]["publication"] = publication(8, 6)
        with self.assertRaisesRegex(MuseumError, "master evidence does not precede"): self.join()

    def test_matching_late_reference_is_not_backdated(self):
        self.snapshots["references"]["records"][0]["publication"] = publication(8, 6)
        with self.assertRaisesRegex(MuseumError, "prospective publication does not precede"): self.join()

    def test_inventory_and_scope_are_not_replaced_by_current_media_context(self):
        self.snapshots["masters"]["historicalCandidates"][0]["inventoryHash"] = H("wrong inventory")
        with self.assertRaisesRegex(MuseumError, "scope/inventory differs"): self.join()

    def test_manifest_selection_change_before_release_invalidates_matching_old_master(self):
        row = deepcopy(self.snapshots["masters"]["manifestSelections"][0])
        row.update(manifestHash=H("replacement manifest"), publication=publication(8, 4))
        self.snapshots["masters"]["manifestSelections"].append(row)
        with self.assertRaisesRegex(MuseumError, "selected manifest changed before"): self.join()

    def test_reselection_of_original_manifest_is_valid_without_new_storage_event(self):
        a = deepcopy(self.snapshots["masters"]["manifestSelections"][0]); b = deepcopy(a)
        b.update(manifestHash=H("temporary replacement"), publication=publication(7))
        a["publication"] = publication(8, 4)
        self.snapshots["masters"]["manifestSelections"] += [b, a]
        self.assertTrue(self.join()["releases"][0]["masters"]["selectedHeadAtReleaseMatches"])

    def test_reference_requires_exact_original_source_and_release_context(self):
        original = deepcopy(self.snapshots)
        for index, wrong in ((0, "2"), (1, H("other source set")), (2, [H("wrong")]), (3, [H("wrong")])):
            with self.subTest(index=index):
                self.snapshots = deepcopy(original)
                self.snapshots["references"]["records"][0]["originalSource"][index] = wrong
                with self.assertRaisesRegex(MuseumError, "original floor source/context differs"): self.join()

    def test_reference_source_must_be_admitted_before_publication(self):
        self.packet["conservation"]["floor"]["catalogue"]["sources"][0]["admission"]["publication"] = publication(7)
        with self.assertRaisesRegex(MuseumError, "source admission does not precede"): self.join()

    def test_gas_update_before_release_invalidates_original_reference_currentness(self):
        self.snapshots["references"]["gasHistory"]["updates"] = [
            {"parameterId": H(1), "newValue": "150", "publication": publication(8, 4)}]
        with self.assertRaisesRegex(MuseumError, "gas changed before original release"): self.join()

    def test_gas_update_after_release_preserves_original_reference(self):
        self.snapshots["references"]["gasHistory"]["updates"] = [
            {"parameterId": H(1), "newValue": "150", "publication": publication(8, 6)}]
        self.assertTrue(self.join()["releases"][0]["references"]["headAtReleaseMatches"])

    def test_missing_original_preimages_remain_unresolved(self):
        self.snapshots["masters"]["historicalCandidates"] = []
        self.snapshots["references"]["records"] = []
        row = self.join()["releases"][0]
        for role in ("masters", "references"):
            self.assertEqual(row[role]["status"], "historical_inputs_not_observed")

    def test_empty_current_association_is_not_invented_as_historical(self):
        self.snapshots["masters"]["historicalCandidates"][0]["publication"] = None
        self.assertEqual(self.join()["releases"][0]["masters"]["status"],
            "historical_empty_inventory_association_unresolved")

    def test_later_provider_release_does_not_borrow_first_provider_configuration(self):
        self.release["sourceId"] = "2"
        row = self.join()["releases"][0]
        for role in ("masters", "references"):
            self.assertEqual(row[role]["status"], "original_provider_configuration_not_captured")

    def test_zero_reference_hash_has_native_not_required_status(self):
        self.release["receipt"][10][2] = ZERO
        self.assertEqual(self.join()["releases"][0]["references"]["status"], "native_reference_not_required")


class PreservationAssemblyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = PreservationV5Fixture()
        cls.inputs = cls.fixture.preservation_inputs()
        cls.result = cls.compose(cls.inputs)

    @staticmethod
    def compose(inputs):
        return assembly.compose(*sum(([row.files, row.manifest_hash] for row in inputs), []), disclosure="public")

    def test_all_original_bytes_paths_and_nine_sources_survive_full_reconstruction(self):
        files = dict(self.result.files)
        for path, raw in self.inputs[0].files:
            self.assertEqual(files[assembly.ORIGINAL_MANIFEST if path == "manifest.json" else path], raw)
        for role, component in zip(("masters", "references"), self.inputs[1:], strict=True):
            for path, raw in component.files: self.assertEqual(files[assembly.PREFIXES[role] + path], raw)
        self.assertEqual(len(self.result.report["sourceReconciliation"]["inputs"]), 9)
        self.assertEqual(assembly.verify(files, self.result.manifest_hash).files, self.result.files)
        packet = loads(files["packet/acquisition-packet.json"], maximum=32 * 1024 * 1024)
        self.assertEqual(keccak256(files[packet["rights"]["selectionEvidence"]["uri"]]),
            packet["rights"]["selectionEvidence"]["hash"]["digest"])
        self.assertEqual([row["item"] for row in self.result.report["items"]], [str(i) for i in range(1, 20)])
        self.assertEqual(self.result.report["items"][7]["sourceCoverage"], "partial")
        self.assertFalse(self.result.report["sourceCoverageComplete"])

    def test_saved_originals_use_exact_native_records_and_do_not_convert_generic_fields(self):
        join = self.result.report["nativePreservationJoin"]["releases"][0]
        self.assertEqual(join["masters"]["savedEvidenceHash"], self.fixture.release[10][1])
        self.assertEqual(join["references"]["savedEvidenceHash"], self.fixture.release[10][2])
        self.assertEqual(join["references"]["record"]["recordHash"], self.fixture.prospective_rows[0]["receipt"][0])
        self.assertEqual(join["masters"]["candidate"]["slotSelections"][0][6][0], self.fixture.media_selections[1][0][6][0])
        self.assertFalse(self.result.report["nativePreservationJoin"]["genericPreservation"]["genericSchemaAuthenticated"])

    def test_waiver_empty_absence_and_later_replacements_preserve_their_distinctions(self):
        for mode, expected in (("waived", "original_native_master_evidence_joined"),
                ("empty", "historical_empty_inventory_association_unresolved"),
                ("absent", "historical_inputs_not_observed"), ("replaced", "original_native_master_evidence_joined"),
                ("manifest_changed", "original_native_master_evidence_joined")):
            with self.subTest(mode=mode):
                result = self.compose(PreservationV5Fixture(master_mode=mode).preservation_inputs())
                row = result.report["nativePreservationJoin"]["releases"][0]
                self.assertEqual(row["masters"]["status"], expected)
                self.assertEqual(row["references"]["status"], "original_native_prospective_evidence_joined")
                self.assertFalse(result.report["canonicalPacketReady"])

    def test_later_reference_and_gas_changes_keep_saved_receipt(self):
        fixture = PreservationV5Fixture(reference_mode="superseded", raised=True)
        result = self.compose(fixture.preservation_inputs())
        row = result.report["nativePreservationJoin"]["releases"][0]["references"]
        self.assertEqual(row["record"]["recordHash"], fixture.prospective_rows[0]["receipt"][0])
        self.assertNotEqual(row["record"]["recordHash"], fixture.prospective_rows[-1]["receipt"][0])
        self.assertTrue(row["headAtReleaseMatches"])

    def test_empty_prospective_history_does_not_invent_saved_reference_inputs(self):
        result = self.compose(PreservationV5Fixture(reference_mode="empty").preservation_inputs())
        row = result.report["nativePreservationJoin"]["releases"][0]
        self.assertEqual(row["masters"]["status"], "original_native_master_evidence_joined")
        self.assertEqual(row["references"]["status"], "historical_inputs_not_observed")

    def test_current_reference_artist_does_not_override_captured_binding(self):
        packet = loads(dict(self.inputs[0].files)["packet/acquisition-packet.json"], maximum=32 * 1024 * 1024)
        snapshots = {role: loads(dict(component.files)["source/snapshot.json"], maximum=32 * 1024 * 1024)
            for role, component in zip(("masters", "references"), self.inputs[1:], strict=True)}
        snapshots["references"]["currentSource"]["source"][7][2] = "2"
        with self.assertRaisesRegex(MuseumError, "current source Artist observations differ"):
            assembly._join(packet, snapshots, self.result.report["providerBinding"])

    def test_individually_replayable_conflicting_reference_receipt_is_rejected(self):
        from . import public_prospective_reference_capture as capture
        files = dict(self.inputs[2].files)
        transcript = loads(files["source/transcript.json"], maximum=64 * 1024 * 1024)
        for row in transcript["calls"]:
            if row["method"] == "eth_getTransactionReceipt": row["result"]["effectiveGasPrice"] = "0x2"
        raw = dumps(transcript); anchor = files["source/anchor.json"]
        changed = capture.replay(anchor, keccak256(anchor), capture._source().PROFILE_HASH, raw, keccak256(raw),
            provenance="synthetic_fixture", disclosure="public")
        with self.assertRaisesRegex(MuseumError, "repeated RPC outcome|repeated receipt"):
            self.compose((*self.inputs[:2], changed))

    def test_semantically_conflicting_current_manifest_across_different_rpc_queries_rejects(self):
        from . import public_prospective_reference_capture as capture
        fixture = PreservationV5Fixture()
        original = list(fixture.prospective_source)
        original[13] = H("different current manifest")
        context = list(original[3])
        from . import public_prospective_reference_source as source
        context[4] = source.hash_abi(("bytes32", "bytes32", "bytes32", "uint8", source.SOURCE[8], "bytes32"),
            (original[2][4], original[13], original[11], 1, original[8], context[1]))
        original[3] = tuple(context); fixture.prospective_source = tuple(original); fixture._prospective_heads()
        adapter = fixture.prospective_source_adapter(); adapter.snapshot(); transcript = adapter.transcript()
        native = capture.replay(adapter.anchor_bytes, keccak256(adapter.anchor_bytes), source.PROFILE_HASH,
            transcript, keccak256(transcript), provenance="synthetic_fixture", disclosure="public")
        with self.assertRaisesRegex(MuseumError, "current source media observations differ"):
            self.compose((*self.inputs[:2], native))

    def test_external_pins_public_disclosure_and_rehashed_report_tamper(self):
        wrong = H("wrong external pin")
        with self.assertRaises(MuseumError): assembly.verify(self.result.files, wrong)
        class Unreadable:
            def __iter__(self): raise AssertionError("read before disclosure")
        with self.assertRaisesRegex(MuseumError, "public disclosure"):
            assembly.compose(Unreadable(), wrong, Unreadable(), wrong, Unreadable(), wrong, disclosure="restricted")
        files = dict(self.result.files)
        report = loads(files["preservation/native-join.json"], maximum=32 * 1024 * 1024)
        report["sourceCoverageComplete"] = True; files["preservation/native-join.json"] = dumps(report)
        manifest = loads(files["manifest.json"], maximum=1048576)
        manifest["files"] = [assembly.base._ref(path, raw) for path, raw in sorted(files.items()) if path != "manifest.json"]
        files["manifest.json"] = dumps(manifest)
        with self.assertRaisesRegex(MuseumError, "reconstruction differs"):
            assembly.verify(files, keccak256(files["manifest.json"]))

    def test_offline_cli_dispatch_exact_export_refusal_and_no_overwrite(self):
        from .package_v2 import verify_package
        with TemporaryDirectory() as temporary:
            root = Path(temporary); paths = [root / role for role in ("packet", "masters", "references")]
            output = root / "joined"; args = ["assemble"]
            for role, path, value in zip(("packet", "masters", "references"), paths, self.inputs, strict=True):
                write_tree(dict(value.files), path)
                args += ["--" + role, str(path), "--" + role + "-hash", value.manifest_hash]
            args += ["--disclosure", "public", "--output", str(output)]
            with patch("socket.socket", side_effect=AssertionError("offline")), redirect_stdout(io.StringIO()):
                assembly.main(args)
                self.assertEqual(verify_package(output, self.result.manifest_hash).files, self.result.files)
            exported = io.StringIO()
            with patch("socket.socket", side_effect=AssertionError("offline")), redirect_stdout(exported):
                assembly.main(["export-supplied-packet", str(output), "--manifest-hash", self.result.manifest_hash])
            self.assertEqual(exported.getvalue().encode(), dict(self.inputs[0].files)["packet/acquisition-packet.json"])
            with self.assertRaisesRegex(MuseumError, "complete source-covered canonical packet unavailable"):
                assembly.complete_packet(self.result.files, self.result.manifest_hash)
            with self.assertRaisesRegex(MuseumError, "new directory"): assembly.main(args)
            self.assertEqual(read_tree(output), dict(self.result.files))


if __name__ == "__main__": unittest.main()
