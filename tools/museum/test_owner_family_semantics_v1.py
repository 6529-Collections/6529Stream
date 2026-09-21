"""Focused synthetic controls for owner_family_semantics_v1."""
import copy
import unittest

from tools.metadata import owner_notice_profile as notice

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, subject_id
from .citations import canonical_citation
from .chain_abi import encode
from .independent_wire import ZERO
from .owner_catalog_source import native_hash
from .owner_family_semantics_v1 import (FAMILIES, FAMILY_TYPES, PROFILE_HASH, SCHEMA_NAMES,
    UNKNOWN_FAMILY, annotate, definitions, interpret, interpret_all)
from .test_condition import condition as condition_sample
from .test_exhibitions import exhibition as exhibition_sample
from .test_institutional import payload as institutional_sample
from .test_loans import loan as loan_sample
from .test_preservation_resources import A, H
from .test_valuations import valuation as valuation_sample


def state():
    return {"chainId": "31337", "core": A(2), "collectionId": "1", "tokenId": "41",
        "host": A(1), "subjectId": subject_id("token", "31337", A(2), "0", token_id="41"),
        "blockNumber": "20", "blockHash": H(21), "timestamp": "1790000000"}


def samples(source_state=None):
    """One exact payload per family for source/integration fixtures."""
    source_state = state() if source_state is None else source_state
    condition = condition_sample()
    condition["workCitation"] = canonical_citation(source_state["chainId"], source_state["core"],
        source_state["tokenId"], {"kind": "fin", "hash": H(10)})
    exhibition = exhibition_sample()
    exhibition["subject"] = {"kind": "token", "collectionId": source_state.get("collectionId", "1"),
        "tokenId": source_state["tokenId"]}
    notices = notice.examples()
    steward = copy.deepcopy(notices["steward-institution.json"]); steward["subjectId"] = source_state["subjectId"]
    recovery = copy.deepcopy(notices["recovery-acknowledged.json"]); recovery["subjectId"] = source_state["subjectId"]
    anchor = {"chainId": source_state["chainId"], "core": source_state["core"],
        "blockNumber": source_state["blockNumber"]}
    return {"ACCESSION": institutional_sample("ACCESSION", anchor=anchor),
        "CONDITION_REPORT": condition, "EXHIBITION": exhibition, "LOAN": loan_sample(),
        "DEACCESSION": institutional_sample("DEACCESSION", anchor=anchor),
        "CITATION": institutional_sample("CITATION", anchor=anchor), "VALUATION": valuation_sample(),
        "STEWARD_DESIGNATION": steward, "RECOVERY_RESPONSE": recovery,
        "REDEMPTION_CLAIM": institutional_sample("REDEMPTION_CLAIM", anchor=anchor)}


def original(family, value, defs, source_state=None, *, index=0, schema_name=None,
        algorithm=1, payload=None, record_type=None):
    source_state = state() if source_state is None else source_state
    payload = dumps(value) if payload is None else payload
    schema = defs.document(schema_name or SCHEMA_NAMES[family])
    jcs = defs.document("RFC8785_JCS")
    digest = hex_bytes(keccak256(payload))
    record = (record_type or FAMILY_TYPES[family], source_state["subjectId"], schema["documentId"],
        (algorithm, digest, jcs["documentId"]), "ipfs://synthetic-owner-record", payload, 1)
    bundle = encode(("bytes32", "address", "bytes32"),
        (schema_id("DIRECT"), A(9), keccak256(payload)))
    receipt = (41, A(9), 100, index, ZERO, False, ZERO, 0, 0, schema["contentHash"],
        jcs["contentHash"], schema_id("DIRECT"), keccak256(bundle))
    digest = native_hash(int(source_state["chainId"]), source_state["host"], source_state["core"], record, receipt)
    def value_of(item):
        if type(item) is bytes: return "0x" + item.hex()
        if type(item) is tuple: return [value_of(child) for child in item]
        if type(item) is int: return str(item)
        return item
    return {"recordHash": digest, "record": value_of(record), "receipt": value_of(receipt),
        "signatureBundleHex": "0x" + bundle.hex(), "signaturePointer": A(20 + index),
        "payloadCorrespondence": "embedded_keccak256_verified",
        "publication": {"blockNumber": "1", "transactionIndex": "0", "logIndex": str(index)},
        "authority": {"mode": "historical_native_owner_receipt", "owner": A(9),
            "currentOwnerProven": False, "legalTitleProven": False}}


def supplied():
    defs = definitions(); source_state = state(); values = samples(source_state)
    rows = [original(family, values[family], defs, source_state, index=index)
        for index, family in enumerate(FAMILIES)]
    lanes = [{"recordType": FAMILY_TYPES[family], "count": "1", "head": H(index + 100),
        "records": [rows[index]["recordHash"]], "state": "complete_history", "latestByAuthor": []}
        for index, family in enumerate(FAMILIES)]
    return rows, source_state, defs, lanes


class OwnerFamilySemantics(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows, cls.state, cls.defs, cls.lanes = supplied()

    def test_all_ten_exact_definitions_and_meanings(self):
        meanings = interpret_all(copy.deepcopy(self.rows), self.state, self.defs)
        result = annotate(meanings, copy.deepcopy(self.lanes))
        self.assertEqual([row["family"] for row in result["rows"]], list(FAMILIES))
        self.assertTrue(all(row["status"] == "typed" for row in result["rows"]))
        self.assertTrue(all(row["semanticBytesHex"].startswith("0x7b") for row in result["rows"]))
        self.assertTrue(all(row["relations"] and row["leaves"] for row in result["rows"]))
        for row in result["rows"]:
            for leaf in row["leaves"]:
                self.assertTrue(any(leaf["jsonPointer"] == relation["sourcePointer"]
                    or leaf["jsonPointer"].startswith(relation["sourcePointer"] + "/")
                    for relation in row["relations"]))
        self.assertFalse(any(result["claims"][key] for key in ("currentOwnerProven", "legalTitleProven",
            "custodyTransferred", "activityPerformed", "noticeTransitionProven")))
        self.assertEqual(len(PROFILE_HASH), 66)

    def test_wrong_schema_and_canonicalizer_are_opaque_but_payload_corruption_rejects(self):
        row = copy.deepcopy(self.rows[0]); row["record"][2] = self.defs.document("STREAM_LOAN_V1")["documentId"]
        row["receipt"][9] = self.defs.document("STREAM_LOAN_V1")["contentHash"]
        self._reseal(row)
        self.assertEqual(interpret(row, self.state, self.defs)["reason"],
            "exact_family_schema_definition_not_retained")
        row = copy.deepcopy(self.rows[0]); row["record"][3][2] = schema_id("RAW_BYTES"); self._reseal(row)
        self.assertEqual(interpret(row, self.state, self.defs)["reason"],
            "exact_payload_canonicalization_definition_not_retained")
        row = copy.deepcopy(self.rows[0]); row["record"][5] += "00"; self._reseal(row)
        with self.assertRaisesRegex(MuseumError, "digest differs"):
            interpret(row, self.state, self.defs)

    def test_cross_subject_and_subtle_semantic_invalidity_become_opaque_or_reject(self):
        row = copy.deepcopy(self.rows[2]); value = loads(hex_bytes(row["record"][5]))
        value["subject"]["collectionId"] = "2"; self._payload(row, value)
        result = interpret(row, self.state, self.defs)
        self.assertEqual((result["status"], result["reason"]), ("opaque", "typed_payload_semantics_invalid"))
        row = copy.deepcopy(self.rows[6]); value = loads(hex_bytes(row["record"][5]))
        value.update(confidential=True); self._payload(row, value)
        self.assertEqual(interpret(row, self.state, self.defs)["status"], "opaque")
        row = copy.deepcopy(self.rows[0]); row["record"][1] = H(999); self._reseal(row)
        with self.assertRaisesRegex(MuseumError, "subject differs"):
            interpret(row, self.state, self.defs)

    def test_notice_is_typed_document_but_not_specialized_state(self):
        steward = interpret(copy.deepcopy(self.rows[7]), self.state, self.defs)
        response = interpret(copy.deepcopy(self.rows[8]), self.state, self.defs)
        self.assertEqual(steward["ownerMeaning"]["specializedState"], "unknown_without_notice_evidence")
        self.assertFalse(steward["ownerMeaning"]["noticeStandingProven"])
        self.assertFalse(response["ownerMeaning"]["scheduledProven"])
        self.assertFalse(response["ownerMeaning"]["vetoAuthorityGranted"])

    def test_redemption_opaque_before_first_is_unresolved_but_after_first_does_not_erase_it(self):
        typed = copy.deepcopy(self.rows[9])
        unknown = original("REDEMPTION_CLAIM", {"opaque": True}, self.defs, self.state,
            index=11, schema_name="STREAM_VALUATION_V1")
        first = interpret(typed, self.state, self.defs)
        opaque = interpret(unknown, self.state, self.defs)
        lane = lambda order: [{"recordType": FAMILY_TYPES["REDEMPTION_CLAIM"], "count": "2",
            "head": H(1), "records": [row["recordHash"] for row in order], "state": "complete_history"}]
        before = annotate([copy.deepcopy(opaque), copy.deepcopy(first)], lane([opaque, first]))
        self.assertEqual(before["rows"][1]["ownerMeaning"]["programPrimacy"],
            "unresolved_due_to_earlier_opaque")
        after = annotate([copy.deepcopy(first), copy.deepcopy(opaque)], lane([first, opaque]))
        self.assertEqual(after["rows"][0]["ownerMeaning"]["programPrimacy"], "first_supported_candidate")

    def test_loan_present_link_mismatch_makes_only_loan_opaque(self):
        rows = copy.deepcopy(self.rows)
        loan = rows[3]; value = loads(hex_bytes(loan["record"][5])); target = rows[6]
        value["insuranceValuation"] = {"recordHash": target["recordHash"], "uri": "https://example.invalid/v",
            "hash": {"algorithm": target["record"][3][0], "digest": target["record"][3][1],
                "canonicalizationId": target["record"][3][2]}}
        self._payload(loan, value)
        meanings = interpret_all(rows, self.state, self.defs)
        self.assertEqual(meanings[3]["status"], "typed")
        target["record"][0] = FAMILY_TYPES["CONDITION_REPORT"]; self._reseal(target)
        value["insuranceValuation"]["recordHash"] = target["recordHash"]
        self._payload(loan, value)
        meanings = interpret_all(rows, self.state, self.defs)
        self.assertEqual((meanings[3]["status"], meanings[3]["reason"]),
            ("opaque", "linked_original_record_correspondence_invalid"))
        self.assertEqual(meanings[6]["status"], "opaque")

    def test_lane_type_duplicate_and_forged_definitions_reject(self):
        meanings = interpret_all(copy.deepcopy(self.rows), self.state, self.defs)
        lanes = copy.deepcopy(self.lanes); lanes[0]["recordType"] = FAMILY_TYPES["LOAN"]
        with self.assertRaisesRegex(MuseumError, "record type"):
            annotate(meanings, lanes)
        lanes = copy.deepcopy(self.lanes); lanes[1]["records"] = lanes[0]["records"]
        with self.assertRaises(MuseumError): annotate(meanings, lanes)
        from .owner_family_semantics_v1 import DefinitionSet
        docs = list(self.defs.documents); row = list(docs[1]); row[4] += b" "; row[2] = keccak256(row[4]); docs[1] = tuple(row)
        forged = DefinitionSet(self.defs.plan_hash, tuple(docs), self.defs.report)
        with self.assertRaises(MuseumError): interpret(copy.deepcopy(self.rows[0]), self.state, forged)

    def _payload(self, row, value):
        raw = dumps(value); row["record"][5] = "0x" + raw.hex(); row["record"][3][1] = keccak256(raw); self._reseal(row)

    def _reseal(self, row):
        r, t = row["record"], row["receipt"]
        bundle = encode(("bytes32", "address", "bytes32"),
            (schema_id("DIRECT"), t[1], keccak256(hex_bytes(r[5]))))
        row["signatureBundleHex"] = "0x" + bundle.hex(); t[12] = keccak256(bundle)
        record = (r[0], r[1], r[2], (int(r[3][0]), hex_bytes(r[3][1]), r[3][2]), r[4], hex_bytes(r[5]), int(r[6]))
        receipt = tuple(int(v) if i in (0, 2, 3, 7, 8) else v for i, v in enumerate(t))
        row["recordHash"] = native_hash(int(self.state["chainId"]), self.state["host"], self.state["core"], record, receipt)


if __name__ == "__main__":
    unittest.main()
