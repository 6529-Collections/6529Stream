"""Synthetic owner-wire exhibition controls; no deployed exhibition evidence."""
from copy import deepcopy
from pathlib import Path
import unittest
from unittest.mock import patch

from .account_profile import JCS_BYTES, JCS_ID
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, record_chain, schema_id, subject_id
from .chain_abi import Array, calldata, decode, encode
from .chain_rpc import ReplayTransport
from .independent_wire import DOCUMENT, DOCUMENT_SPEC, RAW_BYTES, ZERO, generic_hash
from .owner_exhibitions import (CLAIMS, FAMILY, MODE, NAME, PROFILE_BYTES, PROFILE_HASH, QUALIFICATION,
    SCHEMA_BYTES, SOURCE_PROFILE, OwnerExhibitionSource, admit, fields, project_owner_exhibitions,
    render, validate_payload, validator)
from .owner_record_source import OWNER_RECORD, RECEIPT, OwnerRecordSource, domain, words
from .test_exhibitions import exhibition
from .test_loans import OwnerFixture
from .test_preservation_resources import A, H

ROOT = Path(__file__).resolve().parents[2] / "schemas/museum"


def owner_exhibition():
    value = exhibition()
    value["subject"] = {"kind": "token", "collectionId": "1", "tokenId": "41"}
    return value


class OwnerExhibitionFixture(OwnerFixture):
    """Original wire-shaped synthetic replies, never actual-chain publication evidence."""

    def __init__(self, anchor=None, relayed=None, edit=None, burned=False):
        super().__init__(anchor=anchor)
        self.a["profile"] = SOURCE_PROFILE
        self.a["records"], self.rows, self.lanes = [], {}, {}
        self.evidence = dumps({"mode": "synthetic_owner_exhibition_wire_control", "notAnActualDeployment": True})
        self.a["deploymentEvidenceHash"] = keccak256(self.evidence)
        self.burned = burned
        self.register(NAME, SCHEMA_BYTES)
        self.value = owner_exhibition()
        if edit:
            edit(self.value)
        self.exhibition_hash = self.append("EXHIBITION", NAME, self.value, relayed)
        self.selected = [self.exhibition_hash]

    def register(self, name, raw, canonicalization=JCS_ID):
        chunks = [self.chunk(raw[index:index + 8192]) for index in range(0, len(raw), 8192)]
        spec = (name, 0, keccak256(raw), canonicalization, ZERO, "", len(raw))
        document = (True, 0, keccak256(encode((DOCUMENT_SPEC, Array("bytes32")), (spec, chunks))), spec, chunks)
        self.add(self.a["schemas"], "document(bytes32)", ("bytes32",), (schema_id(name),), (DOCUMENT,), (document,))
        self.documents[name] = raw

    def identity(self, token=41, *, exists=True, collection=1, serial=7, burned=None):
        self.add(self.a["core"], "tokenCollectionIdentity(uint256)", ("uint256",), (token,),
            ("bool", "uint256", "uint256", "bool"),
            (exists, collection, serial, self.burned if burned is None else burned))

    def append(self, family, schema, value, relayed=None, *, payload_raw=None, canonicalization=JCS_ID):
        if family != "EXHIBITION":
            return super().append(family, schema, value, relayed)
        token = int(value["subject"]["tokenId"])
        record_type = schema_id(family)
        raw = dumps(value) if payload_raw is None else payload_raw
        payload_hash = keccak256(raw)
        subject = subject_id("token", self.a["chainId"], self.a["core"], "0", token_id=str(token))
        record = (record_type, subject, schema_id(schema), (1, hex_bytes(payload_hash), canonicalization),
            "ipfs://original-owner-exhibition", raw, 1)
        prior = self.lanes.get((token, record_type), [])
        stamp = int(self.a["timestamp"]) - 1
        receipt = [token, A(9), stamp, len(prior), ZERO, relayed is not None, ZERO, 0, 0,
            keccak256(self.documents[schema]), keccak256(JCS_BYTES),
            schema_id("DIRECT" if relayed is None else relayed), ZERO]
        if relayed is None:
            bundle = encode(("bytes32", "address", "bytes32"), (schema_id("DIRECT"), A(9), payload_hash))
        else:
            receipt[7], receipt[8] = 37 + len(prior), stamp + 100
            body = words(record, receipt)
            saved_domain = domain(int(self.a["chainId"]), self.a["host"])
            signature = bytes.fromhex("12" * 65) if relayed == "EIP712" else b"explicit synthetic ERC1271 bytes"
            bundle = encode(("bytes32", ("bytes32",) * 14, "bytes"),
                (saved_domain, decode(("bytes32",) * 14, body), signature))
            receipt[6] = keccak256(b"\x19\x01" + hex_bytes(saved_domain) + hex_bytes(keccak256(body)))
            self.add(self.a["host"], "isOwnerRecordNonceUsed(address,uint256)", ("address", "uint256"),
                (A(9), receipt[7]), ("bool",), (True,))
        receipt[12] = keccak256(bundle)
        generic = (record_type, subject, record[3], record[4], record[2], receipt[11],
            (1, hex_bytes(receipt[12]), RAW_BYTES), record[6])
        digest = generic_hash(int(self.a["chainId"]), self.a["host"], self.a["core"], token, A(9), generic)
        previous = ZERO if not prior else self.rows[prior[-1]][1][4]
        receipt[4] = record_chain(self.a["chainId"], self.a["host"], str(token), record_type, previous,
            digest, str(len(prior)))
        self.rows[digest] = (record, tuple(receipt), bundle)
        self.lanes.setdefault((token, record_type), []).append(digest)
        self.chunk(raw)
        pointer = self.chunks_pointer(self.chunk(bundle))
        self.add(self.a["host"], "ownerRecord(bytes32)", ("bytes32",), (digest,),
            (OWNER_RECORD, RECEIPT), (record, tuple(receipt)))
        self.add(self.a["host"], "ownerRecordSignatureBundle(bytes32)", ("bytes32",), (digest,),
            ("address", "bytes"), (pointer, bundle))
        self.add(self.a["host"], "recordHashAt(uint256,bytes32,uint256)", ("uint256", "bytes32", "uint256"),
            (token, record_type, receipt[3]), ("bytes32",), (digest,))
        self.a["records"].append({"recordHash": digest, "tokenId": str(token)})
        self.identity(token)
        return digest

    def adapter(self):
        return OwnerExhibitionSource(dumps(self.a), self)

    def replay(self):
        synthetic = self.adapter()
        synthetic.snapshot()
        transcript = synthetic.reader.transcript()
        source = OwnerExhibitionSource(dumps(self.a), ReplayTransport(transcript, keccak256(transcript)),
            provenance="trusted_rpc")
        return source, {"anchor.json": dumps(self.a), "transcript.json": transcript,
            "deployment-evidence.json": self.evidence}, synthetic


class OwnerExhibitionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.model = validator(ROOT)

    def project(self, fixture=None):
        fixture = fixture or OwnerExhibitionFixture()
        source, _, _ = fixture.replay()
        source_hash = keccak256(source.snapshot())
        return fixture, source, project_owner_exhibitions(source, fixture.selected,
            source_hash=source_hash, profile_hash=PROFILE_HASH, model=self.model)

    def decoded(self, files, name):
        return loads(files["exhibitions/" + name + ".json"], maximum=2097152, canonical=True)

    def test_original_definitions_and_old_owner_reader_are_unchanged(self):
        from . import exhibitions
        self.assertEqual(SCHEMA_BYTES, (ROOT / "exhibition/STREAM_EXHIBITION_V1.json").read_bytes())
        self.assertEqual(keccak256(SCHEMA_BYTES), "0xef47f6195633773a1533e3bde6e1dfee86ca3d111256353fc40f23f75c4bf8c5")
        self.assertEqual(exhibitions.PROFILE_HASH, "0x75d3a1d9c2de4bdac2907f4a1d40105734da995d5615609d546c43c85dbaab0c")
        self.assertNotEqual(PROFILE_BYTES, exhibitions.PROFILE_BYTES)
        self.assertNotIn(FAMILY, OwnerRecordSource.families)
        fixture = OwnerExhibitionFixture()
        with self.assertRaisesRegex(MuseumError, "anchor shape"):
            OwnerRecordSource(dumps(fixture.a), fixture)

    def test_original_direct_eip712_and_erc1271_receipts_replay_without_current_owner(self):
        for scheme in (None, "EIP712", "ERC1271"):
            with self.subTest(scheme=scheme):
                fixture = OwnerExhibitionFixture(relayed=scheme)
                source, inputs, synthetic = fixture.replay()
                raw = source.snapshot()
                snapshot = loads(raw, maximum=2097152, canonical=True)
                row = snapshot["records"][0]
                self.assertEqual(row["receipt"][11], schema_id("DIRECT" if scheme is None else scheme))
                self.assertEqual(row["authority"]["mode"], "historical_owner_receipt")
                self.assertEqual(row["authority"]["owner"], A(9))
                self.assertFalse(row["authority"]["currentOwnerProven"])
                self.assertTrue(snapshot["claims"]["selectedHistoricalReceiptsChecked"])
                self.assertFalse(snapshot["claims"]["fullLaneHistory"])
                self.assertEqual(inputs["deployment-evidence.json"], fixture.evidence)
                calls = loads(inputs["transcript.json"], maximum=2097152)["calls"]
                identity_data = calldata("tokenCollectionIdentity(uint256)", ("uint256",), (41,))
                self.assertEqual(sum(row["method"] == "eth_call" and row["params"][0]["data"] == identity_data
                    for row in calls), 1)
                self.assertFalse(any(row["method"] == "eth_call" and
                    row["params"][0]["data"].startswith(calldata("ownerOf(uint256)", ("uint256",), (41,))[:10])
                    for row in calls))
                self.assertEqual(synthetic.records[fixture.exhibition_hash]["record"], row["record"])

    def test_token_and_permanent_collection_mapping_are_exact_but_burn_is_historical(self):
        for change in ({"exists": False}, {"collection": 0}, {"serial": 0}, {"collection": 2}):
            fixture = OwnerExhibitionFixture()
            fixture.identity(**change)
            with self.subTest(change=change), self.assertRaises(MuseumError):
                fixture.adapter().snapshot()
        for edit in (lambda value: value["subject"].update(kind="collection"),
                     lambda value: value["subject"].update(collectionId="2")):
            with self.assertRaises(MuseumError):
                OwnerExhibitionFixture(edit=edit).adapter().snapshot()
        wrong_token = OwnerExhibitionFixture()
        wrong_token.a["records"][0]["tokenId"] = "42"
        with self.assertRaisesRegex(MuseumError, "receipt/family/subject"):
            wrong_token.adapter().snapshot()
        fixture, source, files = self.project(OwnerExhibitionFixture(burned=True))
        identity = loads(source.snapshot(), maximum=2097152)["additionalEvidence"]["collectionIdentities"]["41"]
        self.assertEqual(identity, {"mappingExists": True, "collectionId": "1", "collectionSerial": "7",
            "burned": True, "subjectId": subject_id("token", fixture.a["chainId"], fixture.a["core"], "1", token_id="41")})
        self.assertEqual(self.decoded(files, "report")["activities"], "1")
        self.assertFalse(self.decoded(files, "report")["claims"]["tokenLifecycleProven"])
        big = str(2**256 - 1)
        _, source, _ = self.project(OwnerExhibitionFixture(edit=lambda value: value["subject"].update(tokenId=big)))
        self.assertIn(big, source.collection_identities)

    def test_wrong_family_registered_schema_and_canonicalization_reject(self):
        fixture = OwnerExhibitionFixture()
        wrong = fixture.append("LOAN", NAME, fixture.value)
        fixture.a["records"] = [{"recordHash": wrong, "tokenId": "41"}]
        with self.assertRaisesRegex(MuseumError, "receipt/family/subject"):
            fixture.adapter().snapshot()
        fixture = OwnerExhibitionFixture()
        fixture.register(NAME, dumps({"type": "object"}))
        with self.assertRaises(MuseumError):
            fixture.adapter().snapshot()
        fixture = OwnerExhibitionFixture()
        fixture.register("OTHER_EXHIBITION", SCHEMA_BYTES)
        wrong = fixture.append("EXHIBITION", "OTHER_EXHIBITION", fixture.value)
        fixture.a["records"] = [{"recordHash": wrong, "tokenId": "41"}]
        with self.assertRaisesRegex(MuseumError, "exact public EXHIBITION"):
            fixture.adapter().snapshot()
        fixture = OwnerExhibitionFixture()
        wrong = fixture.append("EXHIBITION", NAME, fixture.value, canonicalization=RAW_BYTES)
        fixture.a["records"] = [{"recordHash": wrong, "tokenId": "41"}]
        with self.assertRaises(MuseumError):
            fixture.adapter().snapshot()

    def test_payload_bytes_and_exact_canonical_json_reject_tamper(self):
        for raw in (b"", dumps(owner_exhibition()) + b" ", b'{"version":"1","version":"1"}', b"x" * 8193):
            fixture = OwnerExhibitionFixture()
            wrong = fixture.append("EXHIBITION", NAME, fixture.value, payload_raw=raw)
            fixture.a["records"] = [{"recordHash": wrong, "tokenId": "41"}]
            with self.subTest(length=len(raw)), self.assertRaises(MuseumError):
                fixture.adapter().snapshot()
        fixture = OwnerExhibitionFixture()
        record, receipt, _ = fixture.rows[fixture.exhibition_hash]
        changed = list(record); changed[5] += b"!"
        fixture.add(fixture.a["host"], "ownerRecord(bytes32)", ("bytes32",), (fixture.exhibition_hash,),
            (OWNER_RECORD, RECEIPT), (tuple(changed), receipt))
        with self.assertRaisesRegex(MuseumError, "embedded keccak"):
            fixture.adapter().snapshot()

    def test_immediate_predecessor_must_be_public_same_schema_but_is_not_selected(self):
        fixture = OwnerExhibitionFixture()
        value = deepcopy(fixture.value); value["exhibitionId"] = "urn:test:later-exhibition"
        later = fixture.append("EXHIBITION", NAME, value)
        fixture.a["records"] = [{"recordHash": later, "tokenId": "41"}]
        fixture.selected = [later]
        _, source, files = self.project(fixture)
        self.assertEqual(set(source.records), {later})
        self.assertEqual(len(self.decoded(files, "sidecar")), 1)
        self.assertFalse(loads(source.snapshot(), maximum=2097152)["claims"]["fullLaneHistory"])
        identity_calls = [row for row in loads(source.reader.transcript(), maximum=2097152)["calls"]
            if row["method"] == "eth_call" and row["params"][0]["data"] ==
                calldata("tokenCollectionIdentity(uint256)", ("uint256",), (41,))]
        self.assertEqual(len(identity_calls), 1)
        for kind in ("schema", "opaque", "malformed", "wrong_collection"):
            fixture = OwnerExhibitionFixture()
            fixture.rows, fixture.lanes, fixture.a["records"] = {}, {}, []
            value = deepcopy(fixture.value)
            if kind == "schema":
                fixture.register("OTHER_EXHIBITION", SCHEMA_BYTES)
                fixture.append("EXHIBITION", "OTHER_EXHIBITION", value)
            elif kind in ("opaque", "malformed"):
                fixture.append("EXHIBITION", NAME, value, payload_raw=b"" if kind == "opaque" else b"{}")
            else:
                value["subject"]["collectionId"] = "2"
                fixture.append("EXHIBITION", NAME, value)
            value = deepcopy(fixture.value); value["exhibitionId"] = "urn:test:later-exhibition"
            later = fixture.append("EXHIBITION", NAME, value)
            fixture.a["records"] = [{"recordHash": later, "tokenId": "41"}]
            source = fixture.adapter()
            with self.subTest(predecessor=kind), self.assertRaises(MuseumError):
                source.snapshot()
            self.assertIsNone(source._snapshot)
            self.assertFalse(source.records)

    def test_public_entry_requires_exact_trusted_source_pins_and_captured_set(self):
        fixture = OwnerExhibitionFixture()
        source = fixture.adapter(); source.snapshot()
        with self.assertRaisesRegex(MuseumError, "concrete recorded"):
            project_owner_exhibitions(source, fixture.selected, source_hash=keccak256(source.snapshot()),
                profile_hash=PROFILE_HASH, model=self.model)
        source, _, _ = fixture.replay(); pin = keccak256(source.snapshot())
        for selected in ([], fixture.selected * 2, [H(99)], fixture.selected * 65):
            with self.subTest(selected=len(selected)), self.assertRaises(MuseumError):
                project_owner_exhibitions(source, selected, source_hash=pin, profile_hash=PROFILE_HASH, model=self.model)
        for source_pin, profile_pin in ((H(99), PROFILE_HASH), (pin, H(99))):
            with self.assertRaises(MuseumError):
                project_owner_exhibitions(source, fixture.selected, source_hash=source_pin, profile_hash=profile_pin, model=self.model)
        value = deepcopy(fixture.value); value["exhibitionId"] = "urn:test:second"
        fixture.selected.append(fixture.append("EXHIBITION", NAME, value))
        source, _, _ = fixture.replay(); pin = keccak256(source.snapshot())
        with self.assertRaisesRegex(MuseumError, "equal captured"):
            project_owner_exhibitions(source, fixture.selected[:1], source_hash=pin, profile_hash=PROFILE_HASH, model=self.model)

    def test_completed_graph_dates_roles_and_references_keep_owner_claim_qualification(self):
        with patch("socket.socket", side_effect=AssertionError("no network")):
            fixture, source, files = self.project()
        items = {loads(raw)["type"]: loads(raw) for path, raw in files.items()
            if path.startswith("exhibitions/resources/")}
        self.assertEqual(set(items), {"Activity", "Group", "Place"})
        event = items["Activity"]
        self.assertEqual(event["participant"], [{"id": "urn:test:institution", "type": "Group"}])
        self.assertEqual(event["took_place_at"], [{"id": "urn:test:venue", "type": "Place"}])
        self.assertNotIn("carried_out_by", event)
        self.assertEqual(event["timespan"]["begin_of_the_begin"], fixture.value["opening"]["earliest"])
        self.assertEqual(event["timespan"]["end_of_the_end"], fixture.value["closing"]["latest"])
        sidecar = self.decoded(files, "sidecar")[0]
        self.assertEqual(sidecar["exhibition"], fixture.value)
        self.assertEqual(sidecar["original"], source.records[fixture.exhibition_hash])
        self.assertEqual(sidecar["authority"]["owner"], A(9))
        self.assertNotEqual(items["Group"]["id"], sidecar["authority"]["owner"])
        self.assertEqual({row["sourcePath"]: row["value"] for row in self.decoded(files, "coverage")}, dict(fields(fixture.value)))
        provenance = self.decoded(files, "provenance")
        self.assertTrue(provenance)
        self.assertTrue(all(row["rule"].startswith("urn:6529stream:museum:owner-exhibition:v1:") for row in provenance))
        self.assertTrue(all(row["source"]["owner"] == A(9) for row in provenance))
        report = self.decoded(files, "report")
        self.assertEqual(report["mode"], MODE)
        self.assertEqual(report["claims"], CLAIMS)
        self.assertFalse(any(report["claims"].values()))
        self.assertIn("not a proved token lifecycle", QUALIFICATION)

    def test_noncompleted_missing_names_unknown_and_unsupported_dates_remain_explicit(self):
        for status in ("planned", "cancelled", "unknown"):
            _, _, files = self.project(OwnerExhibitionFixture(edit=lambda value: value.update(status=status)))
            self.assertFalse(self.decoded(files, "index")["resources"])
            self.assertEqual(self.decoded(files, "report")["dispositions"][0]["disposition"], "nonperformed_source")
        for field in ("title", "institution", "venue"):
            _, _, files = self.project(OwnerExhibitionFixture(edit=lambda value: value[field].update(name=None)))
            self.assertEqual(self.decoded(files, "report")["status"], "incomplete")
            self.assertEqual(self.decoded(files, "report")["dispositions"][0]["disposition"], "unsupported")
        for edit in (lambda value: value["opening"].update(precision="unknown", earliest=None, latest=None),
                     lambda value: value["opening"].update(calendar="julian"),
                     lambda value: value["opening"].update(timezone="Europe/Paris")):
            fixture, _, files = self.project(OwnerExhibitionFixture(edit=edit))
            event = next(loads(raw) for path, raw in files.items()
                if path.startswith("exhibitions/resources/") and loads(raw)["type"] == "Activity")
            self.assertNotIn("begin_of_the_begin", event["timespan"])
            self.assertEqual(self.decoded(files, "sidecar")[0]["exhibition"]["opening"], fixture.value["opening"])

    def test_invalid_dates_references_and_account_equivalence_reject(self):
        mutations = (lambda value: value["opening"].update(earliest="not-a-date", latest="not-a-date"),
            lambda value: value["closing"].update(earliest="2020-01-01T00:00:00Z", latest="2020-01-01T00:00:00Z"),
            lambda value: value["opening"].update(latest="2026-09-13T10:00:00Z"),
            lambda value: value["institution"]["reference"]["hash"].update(digest=ZERO),
            lambda value: value["institution"].update(entityId="eip155:31337:" + A(9)),
            lambda value: value["institution"]["identity"].update(value="0x" + "00" * 20),
            lambda value: value["artistIntent"].update(recordHash=ZERO))
        for edit in mutations:
            with self.subTest(edit=edit), self.assertRaises(MuseumError):
                OwnerExhibitionFixture(edit=edit).adapter().snapshot()

    def test_shared_exact_entities_deduplicate_with_all_provenance_and_collisions_reject(self):
        fixture = OwnerExhibitionFixture()
        value = deepcopy(fixture.value); value["exhibitionId"] = "urn:test:second"
        second = fixture.append("EXHIBITION", NAME, value); fixture.selected.append(second)
        _, source, files = self.project(fixture)
        self.assertEqual(len(self.decoded(files, "index")["resources"]), 4)
        shared = [row for row in self.decoded(files, "provenance") if row["entity"] == "urn:test:institution"]
        self.assertEqual({row["source"]["recordHash"] for row in shared}, set(fixture.selected))
        self.assertEqual(files, render(admit(source, list(reversed(fixture.selected))), self.model))
        for edit in (lambda value: value["institution"]["name"].update(value="A different declaration"),
                     lambda value: value["venue"].update(entityId="urn:test:institution"),
                     lambda value: value.update(exhibitionId="urn:test:exhibition")):
            fixture = OwnerExhibitionFixture()
            value = deepcopy(fixture.value); value["exhibitionId"] = "urn:test:second"; edit(value)
            # Event identity reuse needs distinct native payload bytes.
            value["title"]["name"]["value"] += " second"
            fixture.selected.append(fixture.append("EXHIBITION", NAME, value))
            with self.subTest(edit=edit), self.assertRaises(MuseumError):
                self.project(fixture)


if __name__ == "__main__":
    unittest.main()
