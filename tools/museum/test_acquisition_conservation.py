"""Concrete offline composition controls; synthetic supplied provenance only."""
from contextlib import redirect_stdout
from copy import deepcopy
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from ..metadata import acquisition_packet_v4 as definition
from . import acquisition_conservation as assembly
from . import public_conservation_floor_source as floor_source
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import decode, encode
from .dossier_gather import ITEMS
from .independent_wire import ZERO, ZERO_ADDRESS
from .test_native_conservation_fixture import NativeConservationFixture
from .test_public_conservation_floor_source import PublicConservationFloorFixture


def compose(captures, **kwargs):
    args = []
    for role in assembly.CAPTURES:
        args.extend((captures[role]["files"], captures[role]["manifestHash"]))
    return assembly.compose(*args, **({"disclosure": "public", "packet_schema_hash": definition.PACKET_SCHEMA_HASH,
        "conservation_schema_hash": definition.CONSERVATION_SCHEMA_HASH} | kwargs))


class WrongDocumentarySlotFixture(NativeConservationFixture):
    """A generic provider saves a real selected record in the opposite fact slot."""

    def __init__(self, *, selected_kind):
        self.selected_kind = selected_kind
        super().__init__(paid=True)

    def _paid_floor(self, source_head):
        if self.selected_kind == 1:
            chosen = self.append_waiver(block=2); self.update_heads()
        else: chosen = self.originals[0]
        super()._paid_floor(source_head)
        self.wrong_slot_record = chosen["recordHash"]
        first_log = next(log for r in self.receipts.values() for log in r["logs"]
            if log["address"] == self.floor and log["topics"][0] == floor_source.FIRST_EVENT)
        first, version = decode((floor_source.FIRST, "uint16"), hex_bytes(first_log["data"]))
        facts = list(first[8])
        facts[2], facts[3] = (ZERO, self.wrong_slot_record) if self.selected_kind == 0 else (self.wrong_slot_record, ZERO)
        anchor = {"chainId": self.a["chainId"], "core": self.core, "conservationFloor": self.floor}
        first = (ZERO, *first[1:8], tuple(facts))
        first = (floor_source.receipt_hash(anchor, floor_source.FIRST_DOMAIN, floor_source.FIRST, first), *first[1:])
        first_log["topics"][2] = first[0]
        first_log["data"] = "0x" + encode((floor_source.FIRST, "uint16"), (first, version)).hex()
        self.add(self.floor, "firstSale(uint256)", ("uint256",), (first[1],), (floor_source.FIRST,), (first,))
        settlement_log = next(log for r in self.receipts.values() for log in r["logs"]
            if log["address"] == self.floor and log["topics"][0] == floor_source.SETTLEMENT_EVENT)
        row, version = decode((floor_source.SETTLEMENT, "uint16"), hex_bytes(settlement_log["data"]))
        row = (ZERO, *row[1:10], first[0], *row[11:])
        row = (floor_source.receipt_hash(anchor, floor_source.SETTLEMENT_DOMAIN, floor_source.SETTLEMENT, row), *row[1:])
        settlement_log["topics"][2] = row[0]
        settlement_log["data"] = "0x" + encode((floor_source.SETTLEMENT, "uint16"), (row, version)).hex()
        self.add(self.floor, "settlementReceipt(bytes32)", ("bytes32",), (row[3],), (floor_source.SETTLEMENT,), (row,))


def direct_event(fixture, collection_id):
    """Frozen DIRECT tuple/hash recipes; no adapter execution or authority claim."""
    H = schema_id
    adapter = fixture.floor_sale; chain = int(fixture.a["chainId"])
    manager = "0x" + "99" * 20; authorization = H("synthetic DIRECT authorization")
    product = H("6529STREAM_DIRECT_NATIVE_FIXED_PRICE_V1")
    bindings = (fixture.core, fixture.pins[fixture.core], manager, H("synthetic manager runtime"), chain, product)
    stamp = int(next(b for b in fixture.blocks.values() if b["number"] == "0x4")["timestamp"], 16)
    sale = (H("DIRECT authorization digest"), collection_id, 99, H("DIRECT root"), H("DIRECT operation"),
        H("DIRECT mint policy"), H("DIRECT expected policy"), H("DIRECT profile"), manager, stamp,
        False, manager, 1, manager, ZERO_ADDRESS, 100)
    identity_kinds = ("bytes32", "uint256", "address", "address", "bytes32", "bytes32")
    identity = (chain, fixture.core, adapter, product, authorization)
    key = keccak256(encode(identity_kinds, (H("6529STREAM_DIRECT_PRIMARY_SALE_KEY_V1"), *identity)))
    original_hash = keccak256(encode((*identity_kinds, assembly.DIRECT_SALE),
        (H("6529STREAM_DIRECT_PRIMARY_SALE_RECEIPT_V1"), *identity, sale)))
    row = (ZERO, adapter, fixture.pins[adapter], key, authorization, original_hash, bindings, sale,
        H("MUSEUM_GRADE_LITE"), H("synthetic DIRECT first receipt"), H("synthetic DIRECT release receipt"), stamp)
    receipt_hash = keccak256(encode(("bytes32", "uint256", "address", "address", assembly.DIRECT_RECEIPT),
        (H("6529STREAM_CONSERVATION_DIRECT_RECEIPT_V1"), chain, fixture.core, fixture.floor, row)))
    row = (receipt_hash, *row[1:])
    return fixture.event(4, fixture.floor, [assembly.DIRECT_EVENT, key, receipt_hash],
        (assembly.DIRECT_RECEIPT, "uint16"), (row, 1))


class AcquisitionConservationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.captures = NativeConservationFixture().captures()
        cls.paid_captures = NativeConservationFixture(paid=True).captures()
        cls.late_captures = NativeConservationFixture(paid=True, late_declaration=True).captures()
        cls.empty, cls.paid, cls.late = [compose(c) for c in (cls.captures, cls.paid_captures, cls.late_captures)]

    @staticmethod
    def repin(files, role=None):
        if role is not None:
            prefix = "captures/" + role + "/"; path = prefix + "manifest.json"
            manifest = loads(files[path], maximum=1048576)
            manifest["files"] = [assembly.base._ref(p[len(prefix):], raw) for p, raw in sorted(files.items())
                if p.startswith(prefix) and p != path]
            files[path] = dumps(manifest)
        manifest = loads(files["manifest.json"], maximum=1048576)
        if role is not None: manifest["inputs"][role] = keccak256(files["captures/" + role + "/manifest.json"])
        manifest["files"] = [assembly.base._ref(p, raw) for p, raw in sorted(files.items()) if p != "manifest.json"]
        files["manifest.json"] = dumps(manifest)
        return keccak256(files["manifest.json"])

    def test_exact_original_packages_v4_definitions_and_all_nineteen_item_ids(self):
        files = dict(self.paid.files); report = self.paid.report
        for role, captured in self.paid_captures.items():
            originals = {p[len("captures/" + role + "/"):]: raw for p, raw in files.items()
                if p.startswith("captures/" + role + "/")}
            self.assertEqual(originals, captured["files"])
        self.assertEqual(files["definitions/packet-schema.json"], definition.PACKET_SCHEMA_BYTES)
        self.assertEqual(files["definitions/conservation-schema.json"], definition.CONSERVATION_SCHEMA_BYTES)
        self.assertEqual(files["definitions/assembly-profile.json"], assembly.PROFILE_BYTES)
        self.assertEqual(files["definitions/reconciliation-profile.json"], assembly.joined.PROFILE_BYTES)
        self.assertEqual(report["packetSchema"], "STREAM_ACQUISITION_PACKET_V4")
        self.assertEqual([(r["item"], r["name"]) for r in report["items"]],
            [(str(i), title) for i, (title, _) in enumerate(ITEMS, 1)])
        self.assertEqual(report["items"][12]["status"], "partial")
        self.assertTrue(report["items"][12]["canonicalPacketCompatible"])
        self.assertEqual([r["item"] for r in report["items"] if r["status"] == "derived_within_source_profile"], ["2", "19"])
        self.assertIn("13", report["unresolvedItems"])
        self.assertFalse(report["canonicalPacketReady"])
        self.assertEqual(report["sourceProvenance"], "synthetic_fixture")
        for key in ("actualChainAcceptance", "completeCmcPrerequisites", "completeCanonicalPacket",
                "personhoodProven", "documentaryFactsIndependentlyVerified", "archiveDeliveryProven",
                "allPaidRoutesCovered", "candidatePreimagesRecovered", "directReceiptFamilySupported"):
            self.assertFalse(report["claims"][key])

    def test_empty_paid_and_late_declaration_keep_current_and_historical_meaning(self):
        for result in (self.empty, self.paid, self.late):
            fragment = result.report["fields"]["conservation"]
            self.assertEqual((fragment["kind"], fragment["version"]), ("native_conservation", "1"))
            self.assertEqual(definition.validate_conservation(dumps(fragment), result.report["fields"]["sourceState"]), fragment)
            self.assertEqual(set(fragment["scopes"]), {"collection", "token"})
            self.assertEqual(fragment["scopes"]["collection"]["artist"]["status"], "selected")
            for scope, origin in (("collection", "estate"), ("token", "artist"), ("token", "estate")):
                self.assertEqual(fragment["scopes"][scope][origin]["status"], "absent_on_bound_selector")
            self.assertEqual(fragment["historicalFloor"]["kind"], "universal_primary_v1")
        self.assertEqual(self.empty.report["fields"]["conservation"]["historicalFloor"]["status"], "none_recorded")
        empty_joins = loads(dict(self.empty.files)["packet/documentary-joins.json"])
        self.assertEqual(empty_joins["firstSale"]["status"], "no_native_receipt")
        paid = self.paid.report["fields"]["conservation"]
        late = self.late.report["fields"]["conservation"]
        self.assertEqual((paid["tier"]["tierBasis"], paid["tier"]["effectiveTier"]), ("default", "MUSEUM_GRADE_LITE"))
        self.assertEqual((late["tier"]["tierBasis"], late["tier"]["effectiveTier"]), ("declared", "MUSEUM_GRADE"))
        self.assertEqual(late["historicalFloor"]["firstSale"]["effectiveTier"], schema_id("MUSEUM_GRADE_LITE"))
        self.assertEqual(late["historicalFloor"]["firstSale"], paid["historicalFloor"]["firstSale"])
        self.assertFalse(self.paid.report["claims"]["personhoodProven"])

    def test_documentary_join_uses_exact_original_record_and_interview_commitment(self):
        report = loads(dict(self.paid.files)["packet/documentary-joins.json"], maximum=1048576)
        first = report["firstSale"]; joins = first["joins"]
        for key in ("intentRecordHash", "identityRecordHash", "interviewEvidenceHash"):
            self.assertEqual(joins[key]["status"], "original_selected_history_joined")
        self.assertEqual(joins["interviewEvidenceHash"]["interviewStatus"], "waived")
        self.assertEqual(joins["intentRecordHash"]["recordHash"], first["facts"]["intentRecordHash"])
        self.assertEqual(joins["intentWaiverRecordHash"]["status"], "native_alternative_not_selected")
        for key in ("rightsRecordHash", "personhoodEvidenceHash"):
            self.assertEqual(joins[key]["status"], "original_producer_not_supplied")
        self.assertEqual(report["releases"][0]["mediaEvidence"]["status"], "original_master_and_archive_facts_not_supplied")
        self.assertFalse(report["completeDocumentaryPrerequisites"])

    def test_new_current_selection_does_not_replace_historical_floor_original(self):
        fixture = NativeConservationFixture(paid=True)
        first_hash = fixture.originals[0]["recordHash"]
        current = fixture.append_waiver(block=4); fixture.update_heads()
        result = compose(fixture.captures()); fragment = result.report["fields"]["conservation"]
        self.assertEqual(fragment["scopes"]["collection"]["artist"]["selection"]["record"]["evidence"]["recordHash"], current["recordHash"])
        self.assertEqual(fragment["historicalFloor"]["firstSale"]["facts"]["intentRecordHash"], first_hash)
        documentary = loads(dict(result.files)["packet/documentary-joins.json"], maximum=1048576)
        self.assertEqual(documentary["firstSale"]["joins"]["intentRecordHash"]["recordHash"], first_hash)
        self.assertEqual(documentary["firstSale"]["joins"]["interviewEvidenceHash"]["status"], "original_selected_history_joined")

    def test_coherently_saved_opposite_record_kind_is_not_a_documentary_join(self):
        for kind, slot in ((0, "intentWaiverRecordHash"), (1, "intentRecordHash")):
            fixture = WrongDocumentarySlotFixture(selected_kind=kind)
            captured = fixture.captures()  # Each original wrapper replays the rebuilt native hashes/events/getters.
            result = compose(captured)
            documentary = loads(dict(result.files)["packet/documentary-joins.json"], maximum=1048576)
            first = documentary["firstSale"]
            with self.subTest(selected_kind=kind):
                self.assertEqual(first["facts"][slot], fixture.wrong_slot_record)
                self.assertEqual(first["joins"][slot]["status"], "original_producer_not_supplied")
                self.assertNotIn("selectionHash", first["joins"][slot])
                self.assertEqual(first["joins"]["interviewEvidenceHash"]["status"], "original_producer_not_supplied")
                self.assertFalse(documentary["completeDocumentaryPrerequisites"])

    def test_schema_and_manifest_pins_and_public_disclosure_fail_before_verification(self):
        with patch.object(assembly.tier_capture, "verify", side_effect=AssertionError("no source replay")):
            for kwargs in ({"disclosure": "private"}, {"packet_schema_hash": schema_id("wrong")},
                    {"conservation_schema_hash": schema_id("wrong")}):
                with self.subTest(kwargs=kwargs), self.assertRaises(MuseumError): compose(self.captures, **kwargs)
            for role in assembly.CAPTURES:
                for digest in ("bad", "0x" + "00" * 32):
                    captures = deepcopy(self.captures); captures[role]["manifestHash"] = digest
                    with self.subTest(role=role, digest=digest), self.assertRaises(MuseumError): compose(captures)
        with self.assertRaisesRegex(MuseumError, "manifest pin"):
            assembly.verify(self.paid.files, schema_id("wrong"))

    def test_mixed_provenance_and_individually_valid_different_context_fail(self):
        captures = deepcopy(self.captures); original = captures["floor"]["files"]
        manifest = loads(original["manifest.json"], maximum=1048576)
        relabeled = assembly.floor_capture.replay(original["source/anchor.json"], manifest["anchorHash"],
            manifest["sourceProfileHash"], original["source/transcript.json"], keccak256(original["source/transcript.json"]),
            provenance="trusted_rpc", disclosure="public")
        assembly.floor_capture.verify(relabeled.files, relabeled.manifest_hash)
        captures["floor"] = {"files": dict(relabeled.files), "manifestHash": relabeled.manifest_hash}
        with self.assertRaisesRegex(MuseumError, "mixed source provenance"): compose(captures)
        source = PublicConservationFloorFixture().source(); source.snapshot(); transcript = source.transcript()
        unrelated = assembly.floor_capture.replay(source.anchor_bytes, keccak256(source.anchor_bytes),
            assembly.floor_capture._source().PROFILE_HASH, transcript, keccak256(transcript),
            provenance="synthetic_fixture", disclosure="public")
        assembly.floor_capture.verify(unrelated.files, unrelated.manifest_hash)
        captures["floor"] = {"files": dict(unrelated.files), "manifestHash": unrelated.manifest_hash}
        with self.assertRaisesRegex(MuseumError, "common anchor differs"): compose(captures)

    def test_rehashed_derivatives_definitions_and_native_interpretation_fail_reconstruction(self):
        for path in ("packet/assembly.json", "packet/conservation.json", "packet/documentary-joins.json",
                "packet/source-reconciliation.json", "packet/examination.md", "definitions/assembly-profile.json",
                "definitions/reconciliation-profile.json", "definitions/packet-schema.json", "definitions/conservation-schema.json"):
            files = dict(self.paid.files); files[path] += b"\n"
            with self.subTest(path=path), self.assertRaisesRegex(MuseumError, "reconstruction differs"):
                assembly.verify(files, self.repin(files))
        files = dict(self.paid.files); fragment = loads(files["packet/conservation.json"], maximum=1048576)
        fragment["historicalFloor"]["firstSale"]["effectiveTier"] = schema_id("MUSEUM_GRADE")
        files["packet/conservation.json"] = dumps(fragment)
        with self.assertRaisesRegex(MuseumError, "reconstruction differs"): assembly.verify(files, self.repin(files))
        files = dict(self.paid.files); report = loads(files["packet/assembly.json"], maximum=1048576)
        report["items"][12]["status"] = "complete"; report["canonicalPacketReady"] = True
        files["packet/assembly.json"] = dumps(report)
        with self.assertRaisesRegex(MuseumError, "reconstruction differs"): assembly.verify(files, self.repin(files))

    def test_rehashed_original_source_bytes_must_pass_each_frozen_capture_replay(self):
        for role, path in (("tier", "source/snapshot.json"), ("selection", "definitions/source-profile.json"),
                ("floor", "conservation-floor/floor.json")):
            files = dict(self.paid.files); files["captures/" + role + "/" + path] += b"\n"
            with self.subTest(role=role), self.assertRaises(MuseumError): assembly.verify(files, self.repin(files, role))
        files = dict(self.paid.files); path = "captures/floor/source/transcript.json"
        transcript = loads(files[path], maximum=64 * 1024 * 1024); transcript["calls"].pop(); files[path] = dumps(transcript)
        with self.assertRaises(MuseumError): assembly.verify(files, self.repin(files, "floor"))

    def test_closed_manifest_inventory_claims_and_unsupported_receipt_family(self):
        for change in (lambda v: v.update(extra=True), lambda v: v.update(mode="acquisition_packet"),
                lambda v: v["claims"].update(personhoodProven=True), lambda v: v.update(profileHash=schema_id("wrong")),
                lambda v: v.update(sourceProvenance="trusted_rpc")):
            files = dict(self.paid.files); manifest = loads(files["manifest.json"], maximum=1048576)
            change(manifest); files["manifest.json"] = dumps(manifest)
            with self.assertRaises(MuseumError): assembly.verify(files, keccak256(files["manifest.json"]))
        for missing in (True, False):
            files = dict(self.paid.files)
            if missing: del files["captures/tier/source/transcript.json"]
            else: files["unrecognized.json"] = b"{}"
            with self.assertRaises(MuseumError): assembly.verify(files, self.repin(files))
        fragment = deepcopy(self.paid.report["fields"]["conservation"])
        fragment["historicalFloor"]["kind"] = "DIRECT"
        with self.assertRaises(MuseumError): definition.validate_conservation(dumps(fragment), self.paid.report["fields"]["sourceState"])

    def test_complete_packet_is_unavailable_after_successful_reconstruction(self):
        for result in (self.empty, self.paid, self.late):
            with self.assertRaisesRegex(MuseumError, "unresolved items: " + ", ".join(result.report["unresolvedItems"])):
                assembly.complete_packet(result.files, result.manifest_hash)

    def test_target_direct_family_is_rejected_in_other_sources_retained_full_receipt(self):
        fixture = NativeConservationFixture(paid=True)
        direct_event(fixture, int(fixture.a["collectionId"]))
        captured = fixture.captures()
        with self.assertRaisesRegex(MuseumError, "unsupported observed target DIRECT"):
            compose(captured)

    def test_foreign_direct_receipt_remains_original_without_blocking_target_collection(self):
        fixture = NativeConservationFixture(paid=True)
        original = direct_event(fixture, int(fixture.a["collectionId"]) + 1)
        captured = fixture.captures(); result = compose(captured)
        transcript = loads(dict(result.files)["captures/tier/source/transcript.json"], maximum=64 * 1024 * 1024)
        retained = [log for row in transcript["calls"] if row["method"] == "eth_getTransactionReceipt"
            for log in row["result"]["logs"] if log["topics"] and log["topics"][0] == assembly.DIRECT_EVENT]
        self.assertIn(original, retained)
        self.assertEqual(result.report["fields"]["sourceState"]["collectionId"], fixture.a["collectionId"])
        self.assertFalse(result.report["claims"]["directReceiptFamilySupported"])
        self.assertFalse(result.report["claims"]["allPaidRoutesCovered"])

    def test_malformed_known_direct_event_cannot_hide_behind_foreign_scope(self):
        for defect in ("data", "topics", "receipt_hash", "key", "version", "zero_scope"):
            fixture = NativeConservationFixture(paid=True)
            original = direct_event(fixture, int(fixture.a["collectionId"]) + 1)
            if defect == "data": original["data"] = "0x01"
            elif defect == "topics": original["topics"].pop()
            elif defect == "receipt_hash": original["topics"][2] = schema_id("wrong receipt")
            elif defect == "key": original["topics"][1] = schema_id("wrong key")
            else:
                row, version = decode((assembly.DIRECT_RECEIPT, "uint16"), hex_bytes(original["data"]))
                if defect == "version": version = 2
                else: row = (*row[:7], (row[7][0], 0, *row[7][2:]), *row[8:])
                original["data"] = "0x" + encode((assembly.DIRECT_RECEIPT, "uint16"), (row, version)).hex()
            captured = fixture.captures()
            with self.subTest(defect=defect), self.assertRaisesRegex(MuseumError, "malformed observed DIRECT"):
                compose(captured)

    def args(self, paths, destination, **updates):
        values = {"disclosure": "public", "packet-schema-hash": definition.PACKET_SCHEMA_HASH,
            "conservation-schema-hash": definition.CONSERVATION_SCHEMA_HASH, "output": str(destination)}
        for role in assembly.CAPTURES:
            values[role] = str(paths[role]); values[role + "-hash"] = self.paid_captures[role]["manifestHash"]
        values.update(updates)
        return ["assemble", *[entry for key, value in values.items() for entry in ("--" + key, value)]]

    def test_cli_preflight_checks_disclosure_schema_pins_role_pins_and_output_before_input_reads(self):
        with TemporaryDirectory() as temp:
            root = Path(temp); paths = {role: root / role for role in assembly.CAPTURES}
            existing = root / "existing"; existing.mkdir()
            cases = [{"disclosure": "private"}, {"packet-schema-hash": schema_id("wrong")},
                {"conservation-schema-hash": schema_id("wrong")}, {"output": str(existing)}]
            cases += [{role + "-hash": digest} for role in assembly.CAPTURES for digest in ("bad", "0x" + "00" * 32)]
            for change in cases:
                with self.subTest(change=change), patch.object(assembly, "read_tree", side_effect=AssertionError("preflight read")), \
                        self.assertRaises(MuseumError): assembly.main(self.args(paths, root / "out", **change))
            self.assertFalse((root / "out").exists())

    def test_cli_assemble_verify_profiles_common_dispatch_and_no_overwrite_are_offline(self):
        from .package_v2 import verify_package
        with TemporaryDirectory() as temp:
            root = Path(temp); paths = {role: root / role for role in assembly.CAPTURES}
            for role, path in paths.items(): write_tree(self.paid_captures[role]["files"], path)
            output = root / "assembly"; stdout = io.StringIO()
            with patch("socket.socket", side_effect=AssertionError("offline only")), redirect_stdout(stdout):
                assembly.main(self.args(paths, output))
                assembly.main(["verify", str(output), "--manifest-hash", self.paid.manifest_hash])
                self.assertEqual(verify_package(output, self.paid.manifest_hash).files, self.paid.files)
            messages = stdout.getvalue().splitlines()
            self.assertEqual(loads(messages[0].encode())["manifestHash"], self.paid.manifest_hash)
            self.assertFalse(loads(messages[0].encode())["canonicalPacketReady"])
            self.assertEqual(read_tree(output), dict(self.paid.files))
            with self.assertRaisesRegex(MuseumError, "new directory"): assembly.main(self.args(paths, output))
            with self.assertRaisesRegex(MuseumError, "complete canonical packet unavailable"):
                assembly.main(["complete-packet", str(output), "--manifest-hash", self.paid.manifest_hash])
            for role, path in paths.items(): self.assertEqual(read_tree(path), self.paid_captures[role]["files"])
        stdout = io.StringIO()
        with redirect_stdout(stdout), patch("socket.socket", side_effect=AssertionError("offline only")):
            assembly.main(["profiles"])
        self.assertEqual(loads(stdout.getvalue().encode())["reconciliationProfileHash"], assembly.joined.PROFILE_HASH)

    def test_cli_failed_reconstruction_or_staging_never_publishes_partial_output(self):
        from . import repository_exchange
        with TemporaryDirectory() as temp:
            root = Path(temp); paths = {role: root / role for role in assembly.CAPTURES}
            for role, path in paths.items(): write_tree(self.paid_captures[role]["files"], path)
            (paths["floor"] / "source/snapshot.json").write_bytes(b"{}")
            output = root / "failed"
            with self.assertRaises(MuseumError): assembly.main(self.args(paths, output))
            self.assertFalse(output.exists())
            (paths["floor"] / "source/snapshot.json").write_bytes(self.paid_captures["floor"]["files"]["source/snapshot.json"])
            def fail_after_staging(files, destination):
                destination.mkdir(); (destination / "partial").write_bytes(b"not published")
                raise MuseumError("synthetic staged write failure")
            with patch.object(repository_exchange, "write_tree", side_effect=fail_after_staging), \
                    self.assertRaisesRegex(MuseumError, "staged write failure"):
                assembly.main(self.args(paths, output))
            self.assertFalse(output.exists())
            self.assertEqual(list(root.glob(".stream-exchange-*")), [])


if __name__ == "__main__": unittest.main()
