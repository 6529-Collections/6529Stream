"""Synthetic supplied-data controls; never actual-chain or documentary acceptance."""
import copy
import hashlib
import inspect
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator

from . import acquisition_packet_v4 as v4
from . import acquisition_packet_v3 as v3
from . import acquisition_packet_v2 as v2
from . import genesis_dossier_profile as v1
from .test_acquisition_packet_v2 import with_owner
from tools.museum.canonical import dumps, keccak256, loads, schema_id
from tools.museum.chain_abi import encode
from tools.museum import public_conservation_source as selection
from tools.museum import public_conservation_floor_source as floor
from tools.museum.test_native_conservation_fixture import NativeConservationFixture
from tools.museum.test_public_conservation_source import A

H = lambda value: keccak256(str(value).encode("utf-8"))


def supplied(fixture=None):
    fixture = fixture or NativeConservationFixture(paid=True)
    snapshots = {k: loads(s.snapshot(), maximum=32 * 1024 * 1024) for k, s in fixture.sources().items()}
    a, identity = snapshots["selection"]["source"], snapshots["selection"]["identity"]
    state = {k: a[k] for k in ("chainId", "core", "collectionId", "tokenId", "blockHash", "blockNumber")}
    state.update(collectionSerial=identity["collectionSerial"], burned=identity["burned"], examinedAt=a["timestamp"],
        subjectId=fixture.subject("token"), collectionSubjectId=fixture.subject("collection"))
    refs = {k: dict(zip(v4.SOURCE_REF_FIELDS, (*v4.SOURCE_PROFILES[k], H("synthetic-manifest-" + k),
        s["anchorHash"], s["transcriptHash"], keccak256(dumps(s))))) for k, s in snapshots.items()}
    return snapshots, refs, state


def project(data):
    snapshots, refs, state = data
    return v4.project(snapshots["tier"], snapshots["selection"], snapshots["floor"], refs, state)


def publication(label, block="1", index="0"):
    return {"blockNumber": block, "blockHash": H("block-" + block), "transactionHash": H("tx-" + label),
        "transactionIndex": "0", "logIndex": index}


def empty_fragment(state):
    """Synthetic shape example with explicit selector-scoped and ledger-scoped absences."""
    refs = {k: dict(zip(v4.SOURCE_REF_FIELDS, (*pins, *(H(k + str(i)) for i in range(4))))) for k, pins in v4.SOURCE_PROFILES.items()}
    lane = {"status": "absent_on_bound_selector", "currentEligibility": {"checked": False, "eligible": False, "reasons": ["no_selected_head"]}}
    value = {"kind": "native_conservation", "version": "1", "sourceRefs": refs, "sourceBlockTimestamp": state["examinedAt"],
        "coreRuntimeHash": H("runtime"), "metadataHost": A(3), "conservationSelector": A(4), "schemaRegistry": A(5), "store": A(6),
        "tier": {"rawDeclaredTier": v1.ZERO, "tierBasis": "default", "effectiveTier": "MUSEUM_GRADE_LITE",
            "prospectiveSaleTier": "MUSEUM_GRADE_LITE", "declaration": None, "firstCompletedMint": {
                "tokenId": state["tokenId"], "collectionSerial": state["collectionSerial"], "recipient": A(7),
                "blockTimestamp": "1", "publication": publication("mint")},
            "completedMintCount": "1", "nextCollectionSerial": str(int(state["collectionSerial"]) + 1)},
        "scopes": {scope: {"subjectId": state["subjectId" if scope == "token" else "collectionSubjectId"],
            "artist": copy.deepcopy(lane), "estate": copy.deepcopy(lane), "lock": {"status": "unlocked"}} for scope in ("collection", "token")},
        "historicalFloor": {"kind": "universal_primary_v1", "host": A(8), "status": "none_recorded", "sourceCount": "0",
            "sourceHead": floor.empty_head({**state, "conservationFloor": A(8)}), "sources": [], "firstSale": None,
            "releases": [], "settlements": []}}
    return value


def rehash_selections(value, state):
    """Keep mutated supplied selections coherent so native relational guards run."""
    anchor = {**state, "conservationSelector": value["conservationSelector"], "host": value["metadataHost"],
        "schemas": value["schemaRegistry"], "store": value["store"]}
    evidence = lambda row: v4._tuple(row["evidence"], v4.EVIDENCE_FIELDS, selection.RECORD_EVIDENCE,
        {"artist": (v4.ARTIST_FIELDS, selection.EVIDENCE)})
    for scope in value["scopes"].values():
        for origin in ("artist", "estate"):
            if scope[origin]["status"] != "selected": continue
            h = scope[origin]["selection"]
            native = (evidence(h["record"]), v4._tuple(h["association"], v4.ASSOCIATION_FIELDS, selection.ASSOCIATION),
                0 if origin == "artist" else 1, 0 if h["interviewStatus"] == "present" else 1,
                evidence(h["interview"]) if h["interview"] is not None else selection.EMPTY_RECORD,
                h["interviewReferenceHash"], int(h["interviewPayloadCorrespondence"]), h["predecessorRecordHash"],
                h["selector"], int(h["revision"]), int(h["selectedAt"]), h["catalogHash"], h["selectionHash"])
            h["selectionHash"] = selection.selection_hash(anchor, scope["subjectId"], native)


def multiple_native_lanes():
    fixture = NativeConservationFixture()
    collection_interview = fixture.append_interview(block=1)
    fixture.append_intent(block=2, interview=collection_interview)
    fixture.append_intent(origin=1, block=2, interview=collection_interview)
    token_interview = fixture.append_interview("token", block=3)
    fixture.append_intent("token", block=3, interview=token_interview)
    fixture.append_intent("token", origin=1, block=4, interview=token_interview)
    fixture.update_heads()
    data = supplied(fixture)
    return project(data), data[2]


class AcquisitionPacketV4Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = supplied()
        cls.fragment = project(cls.data)
        cls.late_data = supplied(NativeConservationFixture(paid=True, late_declaration=True))

    def reject(self, value, reason=None, state=None):
        state = state or self.data[2]
        with self.assertRaisesRegex(v1.DossierError, reason or "."):
            v4.validate_conservation(dumps(value), state)

    def test_concrete_three_reader_projection_preserves_authority_and_native_receipts(self):
        value = project(self.data)
        self.assertEqual(v4.validate_conservation(dumps(value), self.data[2]), value)
        native = value["scopes"]["collection"]["artist"]["selection"]["record"]
        self.assertEqual(native["original"]["metadataAuthorityClass"], "1")
        self.assertEqual(native["evidence"]["artist"]["authorityClass"], "1")
        self.assertEqual(value["historicalFloor"]["kind"], "universal_primary_v1")
        self.assertEqual(value["historicalFloor"]["firstSale"]["effectiveTier"], schema_id("MUSEUM_GRADE_LITE"))
        self.assertNotIn("tierRecord", value["tier"])
        self.assertLess(len(dumps(value)), v4.MAX_BYTES)

    def test_late_declaration_keeps_original_lite_first_sale(self):
        value = project(self.late_data)
        self.assertEqual(value["tier"]["effectiveTier"], "MUSEUM_GRADE")
        self.assertEqual(value["historicalFloor"]["firstSale"]["effectiveTier"], schema_id("MUSEUM_GRADE_LITE"))
        wrong = copy.deepcopy(value)
        wrong["tier"]["declaration"]["publication"]["blockNumber"] = "0"
        wrong["tier"]["declaration"]["publication"]["blockHash"] = H("genesis")
        self.reject(wrong, "native first-sale historical tier|timestamp|mapping", self.late_data[2])

    def test_default_requires_completed_mint_and_effective_tier_is_not_prospective(self):
        value = copy.deepcopy(self.fragment)
        for edits in ({"completedMintCount": "0", "firstCompletedMint": None}, {"effectiveTier": "MUSEUM_GRADE"},
                {"tierBasis": "declared"}, {"prospectiveSaleTier": "CONSERVATION_WAIVED"}):
            wrong = copy.deepcopy(value); wrong["tier"].update(edits); self.reject(wrong)
        wrong = copy.deepcopy(value); wrong["tier"]["nextCollectionSerial"] = "1"; self.reject(wrong)

    def test_completed_target_and_count_fit_the_native_serial_high_water(self):
        # Coherent nonfirst target: the first and target completions fit serials1..3.
        value = copy.deepcopy(self.fragment)
        value["tier"]["firstCompletedMint"].update(tokenId="40", collectionSerial="1")
        value["tier"]["completedMintCount"] = "2"
        self.assertEqual(v4.validate_conservation(dumps(value), self.data[2]), value)
        state = copy.deepcopy(self.data[2]); state["collectionSerial"] = "999"
        self.reject(value, "target serial exceeds allocation high-water", state)

        # Target remains the first; a second completion cannot fit above serial3
        # when the allocation high-water is still4.
        value = copy.deepcopy(self.fragment); value["tier"]["completedMintCount"] = "2"
        self.reject(value, "count exceeds remaining serial slots")
        value["tier"]["nextCollectionSerial"] = "5"
        self.assertEqual(v4.validate_conservation(dumps(value), self.data[2]), value)

        # All serial bounds fit, but distinct completed first/target tokens need2.
        value = copy.deepcopy(self.fragment)
        value["tier"]["firstCompletedMint"].update(tokenId="40", collectionSerial="2")
        self.reject(value, "nonfirst target requires two completed mints")
        value["tier"]["completedMintCount"] = "2"
        self.assertEqual(v4.validate_conservation(dumps(value), self.data[2]), value)

    def test_source_pins_snapshot_context_and_unknown_families_fail_closed(self):
        for key in ("captureProfileHash", "sourceProfileHash"):
            wrong = copy.deepcopy(self.fragment); wrong["sourceRefs"]["floor"][key] = H("wrong"); self.reject(wrong)
        wrong = copy.deepcopy(self.fragment); wrong["historicalFloor"]["kind"] = "direct_primary_v1"; self.reject(wrong)
        wrong = copy.deepcopy(self.fragment); wrong["kind"] = "legacy_projection"; self.reject(wrong)
        for role in self.data[0]:
            data = copy.deepcopy(self.data); data[0][role]["anchorHash"] = H("wrong")
            with self.assertRaisesRegex(v1.DossierError, "snapshot pin"): project(data)
        data = copy.deepcopy(self.data); data[0]["floor"]["sourceState"]["core"] = A(999)
        with self.assertRaisesRegex(v1.DossierError, "snapshot source context"): project(data)
        data = copy.deepcopy(self.data); data[0]["selection"]["identity"]["collectionSerial"] = "999"
        data[1]["selection"]["snapshotHash"] = keccak256(dumps(data[0]["selection"]))
        with self.assertRaisesRegex(v1.DossierError, "token snapshot identity"): project(data)

    def test_exact_receipt_hashes_source_head_and_result_sale_preimages(self):
        edits = [lambda f: f["firstSale"].update(receiptHash=H("bad")),
            lambda f: f["firstSale"]["facts"].update(identityRecordHash=H("changed")),
            lambda f: f["releases"][0]["context"].update(sourceContextHash=H("changed")),
            lambda f: f["settlements"][0]["result"].update(amount="999"),
            lambda f: f["settlements"][0]["sale"].update(amount="999"),
            lambda f: f.update(sourceHead=H("changed")), lambda f: f["sources"][0].update(predecessor="1")]
        for edit in edits:
            value = copy.deepcopy(self.fragment); edit(value["historicalFloor"]); self.reject(value)

    def test_rehashed_wrong_collection_or_zero_paid_time_still_reject(self):
        for field, replacement in (("collectionId", "999"), ("recordedAt", "0")):
            value = copy.deepcopy(self.fragment); f = value["historicalFloor"]; row = f["firstSale"]; row[field] = replacement
            native = v4._tuple(row, v4.FIRST_FIELDS, floor.FIRST, {"facts": (v4.COLLECTION_FIELDS, floor.COLLECTION_FACTS)})
            row["receiptHash"] = floor.receipt_hash({**self.data[2], "conservationFloor": f["host"]}, floor.FIRST_DOMAIN, floor.FIRST, native)
            self.reject(value, "scope/hash/time")

    def test_current_authority_absence_and_lock_do_not_promote_evidence(self):
        for edit in (lambda h: h["record"]["original"].update(metadataAuthorityClass="3"),
                lambda h: h["record"]["evidence"]["artist"].update(authorityClass="3"),
                lambda h: h["record"]["evidence"]["artist"].update(signer=A(999)),
                lambda h: h["currentEligibility"].update(eligible=True, checked=False),
                lambda h: h["record"]["original"].update(subjectId=H("foreign"))):
            value = copy.deepcopy(self.fragment); edit(value["scopes"]["collection"]["artist"]["selection"]); self.reject(value)
        value = copy.deepcopy(self.fragment)
        value["scopes"]["collection"]["artist"]["selection"]["currentEligibility"] = {
            "checked": False, "eligible": False, "reasons": ["current_association_differs"]}
        self.assertEqual(v4.validate_conservation(dumps(value), self.data[2]), value)
        value["scopes"]["token"]["estate"]["currentEligibility"]["eligible"] = True
        self.reject(value, "absent selector eligibility")

    def test_original_publication_dates_hashes_and_occupied_slots_are_joined(self):
        edits = [lambda h: h["publication"].update(blockNumber="999"),
            lambda h: h["publication"].update(blockHash=self.data[2]["blockHash"]),
            lambda h: h["record"]["original"]["publication"].update(**h["publication"]),
            lambda h: h.update(selectionHash=H("bad")), lambda h: h.update(selectedAt="999999")]
        for edit in edits:
            value = copy.deepcopy(self.fragment); edit(value["scopes"]["collection"]["artist"]["selection"]); self.reject(value)
        value = copy.deepcopy(self.fragment); value["sourceBlockTimestamp"] = str(int(self.data[2]["examinedAt"]) + 1)
        self.reject(value, "source timestamp")
        later = copy.deepcopy(self.data[2]); later["examinedAt"] = str(int(later["examinedAt"]) + 100)
        self.assertEqual(v4.validate_conservation(dumps(self.fragment), later), self.fragment)

    def test_estate_parent_can_keep_artist_interview_and_ordered_duplicate_catalog_pins(self):
        fixture = NativeConservationFixture()
        interview = fixture.append_interview(origin=0, block=1, catalog=True)
        fixture.append_intent(origin=1, block=2, interview=interview); fixture.update_heads()
        value = project(supplied(fixture)); h = value["scopes"]["collection"]["estate"]["selection"]
        self.assertEqual(h["record"]["evidence"]["artist"]["authorityClass"], "3")
        self.assertEqual(h["interview"]["evidence"]["artist"]["authorityClass"], "1")
        self.assertEqual(len(h["catalogs"]), 2); self.assertEqual(h["catalogs"][0], h["catalogs"][1])
        h["catalogs"].pop()
        self.reject(value, "ordered catalog hash", supplied(fixture)[2])

    def test_native_metadata_indices_span_subjects_origins_and_keep_repeated_interviews(self):
        value, state = multiple_native_lanes()
        heads = [scope[origin]["selection"] for scope in value["scopes"].values() for origin in ("artist", "estate")]
        self.assertEqual([h["record"]["evidence"]["recordIndex"] for h in heads], ["1", "2", "3", "4"])
        self.assertEqual(heads[0]["interview"], heads[1]["interview"])
        self.assertEqual(heads[2]["interview"], heads[3]["interview"])
        self.assertNotEqual(heads[0]["record"]["original"]["subjectId"], heads[2]["record"]["original"]["subjectId"])
        self.assertEqual(v4.validate_conservation(dumps(value), state), value)

        for scope, origin in (("collection", "estate"), ("token", "artist")):
            wrong = copy.deepcopy(value)
            wrong["scopes"][scope][origin]["selection"]["record"]["evidence"]["recordIndex"] = "1"
            rehash_selections(wrong, state)
            self.reject(wrong, "metadata record index collision", state)

        wrong = copy.deepcopy(value)
        a = wrong["scopes"]["collection"]["estate"]["selection"]["record"]["evidence"]
        b = wrong["scopes"]["token"]["artist"]["selection"]["record"]["evidence"]
        a["recordIndex"], b["recordIndex"] = b["recordIndex"], a["recordIndex"]
        rehash_selections(wrong, state)
        self.reject(wrong, "metadata record index publication order differs", state)

        # Gaps do not assert that selected references exhaust their native lanes.
        value["scopes"]["token"]["estate"]["selection"]["record"]["evidence"]["recordIndex"] = "8"
        rehash_selections(value, state)
        self.assertEqual(v4.validate_conservation(dumps(value), state), value)

    def test_native_selection_cannot_reselect_its_own_original(self):
        value = copy.deepcopy(self.fragment)
        h = value["scopes"]["collection"]["artist"]["selection"]
        h.update(revision="2", predecessorRecordHash=h["record"]["evidence"]["recordHash"])
        rehash_selections(value, self.data[2])
        self.reject(value, "selection self predecessor")
        h["predecessorRecordHash"] = H("different historical predecessor")
        rehash_selections(value, self.data[2])
        self.assertEqual(v4.validate_conservation(dumps(value), self.data[2]), value)

    def test_full_packet_requires_exact_metadata_head_for_native_conservation(self):
        packet = copy.deepcopy(v1.examples()["acquisition-packet.json"]); packet.update(schema=v4.PACKET, version=4)
        state = packet["sourceState"]; c = packet["conservation"] = empty_fragment(state)
        mint = c["tier"]["firstCompletedMint"]; transfer = packet["ownershipProvenance"]["transfers"][0]
        mint.update(recipient=transfer["to"], blockTimestamp="800")
        mint["publication"].update({k: transfer[k] for k in ("blockNumber", "transactionHash", "logIndex")})
        mint["publication"]["blockHash"] = H("block-" + transfer["blockNumber"])
        # Explicit supplied shape fixture: native authority/byte commitments stay opaque.
        lane = c["scopes"]["collection"]["artist"] = copy.deepcopy(self.fragment["scopes"]["collection"]["artist"])
        h = lane["selection"]; e, original = h["record"]["evidence"], h["record"]["original"]
        e.update(recordIndex="0", recordedAt="900"); e["artist"]["signedAt"] = "900"
        original.update(host=c["metadataHost"], subjectId=state["collectionSubjectId"], publication=publication("record", "90", "0"))
        h.update(selectedAt="900", publication=publication("record", "90", "2"))
        rehash_selections(c, state)
        head = {"lane": "metadata", "host": original["host"], "scopeKey": state["collectionId"],
            "recordType": original["recordType"], "headHash": e["recordChainHash"], "count": "1"}
        packet["recordChainHeads"].append(head); packet["recordChainHeads"].sort(key=v1._head_key)
        self.assertEqual(v4.validate(dumps(packet)), packet)
        index = packet["recordChainHeads"].index(head)
        for edit, error in ((lambda p: p["recordChainHeads"].pop(index), "matching record head missing"),
                (lambda p: p["recordChainHeads"][index].update(host=A(999)), "matching record head missing"),
                (lambda p: p["recordChainHeads"][index].update(lane="general"), "matching record head missing"),
                (lambda p: p["recordChainHeads"][index].update(recordType=H("other family")), "matching record head missing"),
                (lambda p: p["recordChainHeads"][index].update(count="0", headHash=v1.ZERO), "index exceeds supplied head count"),
                (lambda p: p["recordChainHeads"][index].update(headHash=H("wrong head")), "last receipt chain differs")):
            wrong = copy.deepcopy(packet); edit(wrong); wrong["recordChainHeads"].sort(key=v1._head_key)
            with self.assertRaisesRegex(v1.DossierError, error): v4.validate(dumps(wrong))
        wrong = copy.deepcopy(packet)
        wrong["conservation"]["scopes"]["collection"]["artist"]["selection"]["record"]["evidence"]["recordIndex"] = "1"
        rehash_selections(wrong["conservation"], state)
        with self.assertRaisesRegex(v1.DossierError, "index exceeds supplied head count"): v4.validate(dumps(wrong))
        # A selected historical record may precede the declared current head.
        head.update(count="2", headHash=H("later unselected native head"))
        self.assertEqual(v4.validate(dumps(packet)), packet)
        self.assertEqual(v4.validate_conservation(dumps(c), state), c)

    def test_full_native_packet_and_legacy_owner_semantics(self):
        value = copy.deepcopy(v1.examples()["acquisition-packet.json"]); value.update(schema=v4.PACKET, version=4)
        value["conservation"] = empty_fragment(value["sourceState"])
        mint = value["conservation"]["tier"]["firstCompletedMint"]; transfer = value["ownershipProvenance"]["transfers"][0]
        mint["recipient"] = transfer["to"]
        mint["publication"].update({k: transfer[k] for k in ("blockNumber", "transactionHash", "logIndex")})
        mint["publication"]["blockHash"] = H("block-" + transfer["blockNumber"])
        self.assertEqual(v4.validate(dumps(value)), value)
        for edit in (lambda v: v["erc721Identity"].update(collectionSerial="99"),
                lambda v: v["rights"]["effectiveGrants"].update(exhibition="granted"),
                lambda v: v["entropy"].update(leafHash=H("bad")),
                lambda v: v["platformSustainability"]["stateExport"].update(ageSeconds="999")):
            wrong = copy.deepcopy(value); edit(wrong)
            with self.assertRaises(v1.DossierError): v4.validate(dumps(wrong))
        for scheme in ("DIRECT", "EIP712", "ERC1271"):
            value = with_owner(scheme=scheme, title=True); value.update(schema=v4.PACKET, version=4)
            self.assertEqual(v4.validate(dumps(value)), value)
            value["legalInstrument"]["accession"]["authority"]["receipt"]["owner"] = A(999)
            with self.assertRaises(v1.DossierError): v4.validate(dumps(value))

    def test_curated_exact_artist_intent_requires_current_eligibility_without_precedence(self):
        value = copy.deepcopy(self.fragment)
        h = value["scopes"]["collection"]["artist"]["selection"]
        record = copy.deepcopy(v1.examples()["acquisition-packet.json"]["tombstone"]["record"])
        record["recordType"] = schema_id("INSTITUTIONAL_VERIFICATION")
        curated = {"attestation": record, "artistIntentRecordHash": h["record"]["evidence"]["recordHash"]}
        v4._curated(curated, value)
        h["currentEligibility"] = {"checked": False, "eligible": False, "reasons": ["current_association_differs"]}
        with self.assertRaisesRegex(v1.DossierError, "eligible Artist intent"): v4._curated(curated, value)
        curated["artistIntentRecordHash"] = H("missing")
        with self.assertRaisesRegex(v1.DossierError, "missing/ambiguous"): v4._curated(curated, value)

    def test_each_later_settlement_obeys_tier_at_its_own_publication(self):
        value = project(self.late_data); f = value["historicalFloor"]
        later = copy.deepcopy(f["settlements"][0]); result = later["result"]
        result["executionId"] = H("later-execution")
        key = keccak256(encode(("bytes32", "uint256", "address", "address", "bytes32"),
            (floor.KEY_DOMAIN, int(self.late_data[2]["chainId"]), later["recorder"], later["saleAdapter"], result["executionId"])))
        later["settlementKey"] = result["settlementKey"] = key
        later["resultHash"] = keccak256(encode((floor.RESULT,), (v4._tuple(result, v4.RESULT_FIELDS, floor.RESULT),)))
        later["publication"]["logIndex"] = "9"  # Same transaction, strictly after the declaration and facade.
        later["receiptHash"] = floor.receipt_hash({**self.late_data[2], "conservationFloor": f["host"]}, floor.SETTLEMENT_DOMAIN,
            floor.SETTLEMENT, v4._tuple(later, v4.SETTLEMENT_FIELDS, floor.SETTLEMENT))
        f["settlements"].append(later)
        self.reject(value, "settlement historical tier", self.late_data[2])

    def test_full_packet_cross_owner_conservation_coordinates_and_time(self):
        packet = with_owner(title=True); packet.update(schema=v4.PACKET, version=4)
        c = packet["conservation"] = empty_fragment(packet["sourceState"])
        authority = packet["legalInstrument"]["accession"]["authority"]
        transfer = authority["ownerState"]["transfer"]; mint = c["tier"]["firstCompletedMint"]
        mint.update(recipient=transfer["to"], blockTimestamp="800", publication={k: transfer[k] for k in v4.PUBLICATION_FIELDS})
        self.assertEqual(v4.validate(dumps(packet)), packet)
        wrong = copy.deepcopy(packet); wrong["conservation"]["sourceBlockTimestamp"] = "999"
        with self.assertRaisesRegex(v1.DossierError, "source timestamp differs"): v4.validate(dumps(wrong))
        wrong = copy.deepcopy(packet); wrong["conservation"]["tier"]["firstCompletedMint"]["publication"]["blockHash"] = H("contradiction")
        with self.assertRaisesRegex(v1.DossierError, "block mapping differs"): v4.validate(dumps(wrong))
        wrong = copy.deepcopy(packet); wrong["conservation"]["tier"]["firstCompletedMint"]["publication"]["transactionHash"] = H("contradiction")
        with self.assertRaisesRegex(v1.DossierError, "transaction mapping differs"): v4.validate(dumps(wrong))
        wrong = copy.deepcopy(packet); wrong["conservation"]["tier"]["firstCompletedMint"]["blockTimestamp"] = "950"
        with self.assertRaisesRegex(v1.DossierError, "timestamp regresses"): v4.validate(dumps(wrong))
        wrong = copy.deepcopy(packet); wrong["conservation"]["tier"]["firstCompletedMint"]["recipient"] = A(999)
        with self.assertRaisesRegex(v1.DossierError, "event slot differs"): v4.validate(dumps(wrong))

    def test_native_lock_binds_exact_artist_head_with_currentness_separate(self):
        fixture = NativeConservationFixture(); fixture.lock_artist(block=3); fixture.update_heads()
        data = supplied(fixture); value = project(data)
        self.assertEqual(value["scopes"]["collection"]["lock"]["status"], "locked")
        for edits in ({"recordHash": H("foreign")}, {"generation": "2"}, {"lockedAt": "1"}, {"locker": v1.ZERO_ADDRESS}):
            wrong = copy.deepcopy(value); wrong["scopes"]["collection"]["lock"].update(edits)
            self.reject(wrong, "intent lock", data[2])
        value["scopes"]["collection"]["artist"]["selection"]["currentEligibility"] = {
            "checked": False, "eligible": False, "reasons": ["current_association_differs"]}
        self.assertEqual(v4.validate_conservation(dumps(value), data[2]), value)

    def test_later_settlement_can_reuse_original_release_without_new_receipt(self):
        value = copy.deepcopy(self.fragment); f = value["historicalFloor"]
        later = copy.deepcopy(f["settlements"][0]); result = later["result"]
        result["executionId"] = H("reused-release-execution")
        key = keccak256(encode(("bytes32", "uint256", "address", "address", "bytes32"),
            (floor.KEY_DOMAIN, int(self.data[2]["chainId"]), later["recorder"], later["saleAdapter"], result["executionId"])))
        later["settlementKey"] = result["settlementKey"] = key
        later["resultHash"] = keccak256(encode((floor.RESULT,), (v4._tuple(result, v4.RESULT_FIELDS, floor.RESULT),)))
        later["publication"]["logIndex"] = str(int(later["publication"]["logIndex"]) + 5)
        later["receiptHash"] = floor.receipt_hash({**self.data[2], "conservationFloor": f["host"]}, floor.SETTLEMENT_DOMAIN,
            floor.SETTLEMENT, v4._tuple(later, v4.SETTLEMENT_FIELDS, floor.SETTLEMENT))
        f["settlements"].append(later)
        self.assertEqual(v4.validate_conservation(dumps(value), self.data[2]), value)
        f["releases"].append(copy.deepcopy(f["releases"][0]))
        self.reject(value, "duplicate/order")

    def test_closed_shape_bounds_versions_and_generated_schemas(self):
        for raw in v4.documents().values(): Draft202012Validator.check_schema(loads(raw, maximum=v4.MAX_BYTES))
        for edits in ({"version": 1}, {"sourceVerified": True}, {"tierRecord": None}):
            wrong = copy.deepcopy(self.fragment); wrong.update(edits); self.reject(wrong)
        for raw in (dumps(self.fragment) + b"\n", b" " * (v4.MAX_BYTES + 1)):
            with self.assertRaises(v1.DossierError): v4.validate_conservation(raw, self.data[2])
        for path, raw in v4.outputs().items(): self.assertEqual((v4.ROOT / path).read_bytes(), raw)

    def test_old_generated_bytes_and_v4_nonconservation_semantics_are_frozen(self):
        for module in (v1, v2, v3):
            for name, raw in module.documents().items():
                path = v4.ROOT / "schemas/records" / ("profiles/" if name == v2.PROFILE else "") / (name + ".json")
                self.assertEqual(path.read_bytes(), raw)
        for module, expected in ((v1, "234e0cb71450e6402e34e6273daa5e355edd5606ecf331e4915b52390fd82d01"),
                (v2, "a694e1c71d4bf3437a68f7fa11d8b186c35b5f2aa1ddbcbafaa2c8003d0e15d4")):
            self.assertEqual(hashlib.sha256(Path(module.__file__).read_bytes().replace(b"\r\n", b"\n")).hexdigest(), expected)
        original = inspect.getsource(v1._packet)
        start = original.index('            intent = value["conservation"]["artistIntent"]')
        end = original.index('    if value["legalInstrument"]', start)
        expected = original[:start] + '            _curated(curated, value["conservation"])\n    _conservation(value["conservation"], s, value)\n' + original[end:]
        self.assertEqual(inspect.getsource(v4._packet), expected)


if __name__ == "__main__": unittest.main()
