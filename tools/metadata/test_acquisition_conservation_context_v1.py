"""Two-source synthetic conservation context; no floor adaptation or chain acceptance."""
import copy
import unittest
from unittest.mock import patch

from jsonschema import Draft202012Validator

from . import acquisition_conservation_context_v1 as context
from . import acquisition_packet_v4 as v4
from .test_acquisition_packet_v4 import rehash_selections
from tools.museum.canonical import MuseumError, dumps, keccak256, loads, subject_id
from tools.museum.test_native_conservation_fixture import NativeConservationFixture, TOKEN, COLLECTION, K
from tools.museum.test_public_conservation_source import A


def supplied(fixture=None):
    fixture = fixture or NativeConservationFixture()
    snapshots = {role: loads(reader.snapshot(), maximum=32 * 1024 * 1024) for role, reader in
        (("tier", fixture.tier_source()), ("selection", fixture.selection_source()))}
    a, identity = snapshots["selection"]["source"], snapshots["selection"]["identity"]
    state = {key: a[key] for key in ("chainId", "core", "collectionId", "tokenId", "blockHash", "blockNumber")}
    state.update(collectionSerial=identity["collectionSerial"], burned=identity["burned"], examinedAt=a["timestamp"],
        subjectId=subject_id("token", a["chainId"], a["core"], a["collectionId"], token_id=a["tokenId"]),
        collectionSubjectId=subject_id("collection", a["chainId"], a["core"], a["collectionId"]))
    refs = {role: dict(zip(context.SOURCE_REF_FIELDS, (*context.SOURCE_PROFILES[role], K("synthetic-capture-" + role),
        row["anchorHash"], row["transcriptHash"], keccak256(dumps(row))))) for role, row in snapshots.items()}
    return snapshots, refs, state


def project(data):
    snapshots, refs, state = data
    return context.semanticProjection(snapshots["tier"], snapshots["selection"], refs, state)


def repin(data, role):
    data[1][role]["snapshotHash"] = keccak256(dumps(data[0][role]))


def all_lanes():
    fixture = NativeConservationFixture()
    interview = fixture.append_interview(block=1, catalog=True)
    fixture.append_intent(block=2, interview=interview)
    fixture.append_intent(origin=1, block=2, interview=interview)
    interview = fixture.append_interview("token", block=3)
    fixture.append_intent("token", block=3, interview=interview)
    fixture.append_intent("token", origin=1, block=4, interview=interview)
    fixture.update_heads()
    return supplied(fixture)


class AcquisitionConservationContextTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = supplied(); cls.value = project(cls.data)

    def fresh(self): return copy.deepcopy(self.value)

    def reject(self, value, message=None):
        with self.assertRaises(MuseumError) as caught: context.validate(dumps(value))
        if message: self.assertIn(message, str(caught.exception))

    def test_two_real_sources_project_without_floor_or_v4_projector(self):
        before = copy.deepcopy(self.data)
        with patch.object(v4, "project", side_effect=AssertionError("no floor projector")), patch("socket.socket", side_effect=AssertionError("offline only")):
            value = project(self.data)
            self.assertEqual(context.validate(dumps(value)), value)
        self.assertEqual(self.data, before)
        self.assertEqual(set(value["sourceRefs"]), {"tier", "selection"})
        self.assertNotIn("historicalFloor", value)
        self.assertEqual(set(value["scopes"]), {"collection", "token"})
        self.assertEqual(value["tier"]["effectiveTier"], "MUSEUM_GRADE_LITE")
        self.assertEqual(value["scopes"]["collection"]["artist"]["status"], "selected")
        self.assertEqual(value["scopes"]["token"]["estate"]["status"], "absent_on_bound_selector")
        self.assertIn("No floor, full acquisition packet or complete item13", value["qualification"])

    def test_default_declared_and_burned_completed_target(self):
        declared = project(supplied(NativeConservationFixture(paid=True, late_declaration=True)))
        self.assertEqual((declared["tier"]["tierBasis"], declared["tier"]["effectiveTier"]), ("declared", "MUSEUM_GRADE"))
        self.assertIsNotNone(declared["tier"]["declaration"]["facadePublication"])
        fixture = NativeConservationFixture()
        fixture.add(fixture.core, "tokenCollectionIdentity(uint256)", ("uint256",), (TOKEN,),
            ("bool", "uint256", "uint256", "bool"), (True, COLLECTION, 3, True))
        fixture.add(fixture.core, "tokenLifecycle(uint256)", ("uint256",), (TOKEN,), ("uint8",), (3,))
        value = project(supplied(fixture))
        self.assertTrue(value["sourceState"]["burned"])
        self.assertEqual(value["tier"]["completedMintCount"], "1")
        wrong = self.fresh(); wrong["tier"].update(completedMintCount="0", firstCompletedMint=None, tierBasis="not_yet_effective", effectiveTier=None)
        self.reject(wrong, "requires completed mint")

    def test_all_four_lanes_preserve_metadata_and_artist_authority(self):
        value = project(all_lanes())
        for scope in value["scopes"].values():
            for origin, authority in (("artist", "1"), ("estate", "3")):
                h = scope[origin]["selection"]
                self.assertEqual(h["record"]["original"]["metadataAuthorityClass"], "1")
                self.assertEqual(h["record"]["evidence"]["artist"]["authorityClass"], authority)
        artist, estate = (value["scopes"]["collection"][origin]["selection"] for origin in ("artist", "estate"))
        self.assertEqual(estate["interview"], artist["interview"])
        self.assertEqual(estate["interview"]["evidence"]["artist"]["authorityClass"], "1")
        self.assertEqual(estate["catalogs"][0], estate["catalogs"][1])
        estate["catalogs"].pop(); self.reject(value, "ordered catalog hash")

    def test_selected_waiver_and_current_lock_keep_separate_meanings(self):
        fixture = NativeConservationFixture(); fixture.append_waiver(block=2); fixture.update_heads(); fixture.lock_artist(block=3)
        value = project(supplied(fixture)); scope = value["scopes"]["collection"]
        self.assertEqual(scope["artist"]["selection"]["record"]["evidence"]["recordKind"], "1")
        self.assertEqual(scope["lock"]["status"], "locked")
        scope["artist"]["selection"]["currentEligibility"] = {"checked": False, "eligible": False, "reasons": ["current_association_differs"]}
        self.assertEqual(context.validate(dumps(value)), value)
        scope["lock"]["recordHash"] = K("other head"); self.reject(value, "intent lock")

    def test_original_authority_scope_and_consuming_eligibility_cannot_be_promoted(self):
        changes = [lambda h: h["record"]["original"].update(metadataAuthorityClass="3"),
            lambda h: h["record"]["evidence"]["artist"].update(authorityClass="3"),
            lambda h: h["record"]["evidence"]["artist"].update(signer=A(999)),
            lambda h: h["record"]["original"].update(subjectId=K("foreign subject")),
            lambda h: h["currentEligibility"].update(checked=False)]
        for index, change in enumerate(changes):
            value = self.fresh(); change(value["scopes"]["collection"]["artist"]["selection"])
            with self.subTest(index=index): self.reject(value)
        value = self.fresh(); value["scopes"]["token"]["estate"]["currentEligibility"]["eligible"] = True
        self.reject(value, "absent selector eligibility")

    def test_source_pairs_profiles_snapshot_pins_and_shared_context_fail_closed(self):
        for role in context.SOURCE_PROFILES:
            for key in context.SOURCE_REF_FIELDS:
                data = copy.deepcopy(self.data); data[1][role][key] = v4.ZERO
                with self.subTest(role=role, key=key), self.assertRaises(MuseumError): project(data)
            for key in ("profile", "profileHash", "sourceReviewCommit"):
                data = copy.deepcopy(self.data); data[0][role][key] = "foreign"; repin(data, role)
                with self.subTest(role=role, key=key), self.assertRaises(MuseumError): project(data)
        data = copy.deepcopy(self.data); data[1]["floor"] = copy.deepcopy(data[1]["tier"])
        with self.assertRaisesRegex(MuseumError, "exact source pair"): project(data)
        for key, replacement in (("blockHash", K("new source block")), ("collectionId", "2"), ("timestamp", "999"), ("environment", "public_chain")):
            data = copy.deepcopy(self.data); data[0]["tier"]["sourceState"][key] = replacement; repin(data, "tier")
            with self.subTest(key=key), self.assertRaisesRegex(MuseumError, "snapshot source"): project(data)

    def test_completed_target_must_join_both_snapshot_observations(self):
        for change in (lambda s: s["identity"].update(lifecycle="1"), lambda s: s["identity"].update(burned=True),
                lambda s: s["identity"].update(collectionSerial="999")):
            data = copy.deepcopy(self.data); change(data[0]["selection"]); repin(data, "selection")
            with self.assertRaisesRegex(MuseumError, "completed token identity"): project(data)
        for field in ("allocations", "completedMints"):
            data = copy.deepcopy(self.data); data[0]["tier"][field] = []; repin(data, "tier")
            with self.subTest(field=field), self.assertRaisesRegex(MuseumError, "target completion"): project(data)
        data = copy.deepcopy(self.data); allocation = next(a for a in data[0]["tier"]["allocations"] if a["tokenId"] == str(TOKEN))
        allocation.update(status="burned", lifecycle="3"); allocation["identity"][3] = True; repin(data, "tier")
        with self.assertRaisesRegex(MuseumError, "tier/selection target identity"): project(data)
        data = copy.deepcopy(self.data); data[0]["tier"]["sourceState"]["coreRuntimeHash"] = K("different runtime"); repin(data, "tier")
        with self.assertRaisesRegex(MuseumError, "shared Core runtime"): project(data)

    def test_projection_does_not_discard_partial_empty_or_duplicate_originals(self):
        changes = [lambda s: s["scopes"]["token"]["origins"]["estate"]["current"][0].__setitem__(2, K("partial head")),
            lambda s: s["scopes"]["collection"]["origins"]["artist"]["current"][4].__setitem__(2, K("partial interview")),
            lambda s: s["scopes"]["token"]["lock"].__setitem__(6, K("partial lock")),
            lambda s: s["records"].append(copy.deepcopy(s["records"][0])),
            lambda s: s["scopes"]["collection"]["origins"]["artist"]["current"].__setitem__(2, "1")]
        for index, change in enumerate(changes):
            data = copy.deepcopy(self.data); change(data[0]["selection"]); repin(data, "selection")
            with self.subTest(index=index), self.assertRaises(MuseumError): project(data)

    def test_shared_metadata_indices_are_not_split_by_origin_or_subject(self):
        value = project(all_lanes()); state = value["sourceState"]
        heads = [scope[origin]["selection"] for scope in value["scopes"].values() for origin in ("artist", "estate")]
        self.assertEqual([h["record"]["evidence"]["recordIndex"] for h in heads], ["1", "2", "3", "4"])
        heads[2]["record"]["evidence"]["recordIndex"] = "1"; rehash_selections(value, state)
        self.reject(value, "metadata record index collision")
        value = project(all_lanes()); a = value["scopes"]["collection"]["estate"]["selection"]["record"]["evidence"]
        b = value["scopes"]["token"]["artist"]["selection"]["record"]["evidence"]
        a["recordIndex"], b["recordIndex"] = b["recordIndex"], a["recordIndex"]
        rehash_selections(value, value["sourceState"]); self.reject(value, "metadata record index publication order")

    def test_selection_hash_catalog_order_and_self_predecessor(self):
        value = self.fresh(); h = value["scopes"]["collection"]["artist"]["selection"]
        h["selectionHash"] = K("different selection"); self.reject(value, "selection hash")
        value = self.fresh(); h = value["scopes"]["collection"]["artist"]["selection"]
        h.update(revision="2", predecessorRecordHash=h["record"]["evidence"]["recordHash"])
        rehash_selections(value, value["sourceState"]); self.reject(value, "self predecessor")
        h["predecessorRecordHash"] = K("separate historical predecessor")
        rehash_selections(value, value["sourceState"])
        self.assertEqual(context.validate(dumps(value)), value)

    def test_publication_slots_dates_and_examination_time_are_separate(self):
        value = self.fresh(); value["sourceState"]["examinedAt"] = str(int(value["sourceBlockTimestamp"]) + 10)
        self.assertEqual(context.validate(dumps(value)), value)
        value["sourceState"]["examinedAt"] = "1"; self.reject(value, "timestamp after examination")
        edits = [lambda h: h["publication"].update(blockHash=self.value["sourceState"]["blockHash"]),
            lambda h: h["record"]["original"]["publication"].update(**h["publication"]),
            lambda h: h["publication"].update(blockNumber="999")]
        for edit in edits:
            value = self.fresh(); edit(value["scopes"]["collection"]["artist"]["selection"]); self.reject(value)

    def test_exact_reachable_definitions_and_old_bytes_unchanged(self):
        original, selected = v4.definitions(), context.definitions()
        for key in set(selected) - {"context"}: self.assertEqual(selected[key], original[key])
        self.assertTrue({"nativeTier", "nativeScope", "nativeSelection", "sourceState"}.issubset(selected))
        self.assertFalse({"packet", "conservation", "legacyConservation", "nativeHistoricalFloor", "nativeSettlementReceipt"} & set(selected))
        Draft202012Validator.check_schema(loads(context.SCHEMA_BYTES, maximum=context.MAX_BYTES))
        self.assertEqual(context.documents(), {context.NAME: context.SCHEMA_BYTES})
        self.assertEqual((context.ROOT / "schemas/records" / (context.NAME + ".json")).read_bytes(), context.SCHEMA_BYTES)
        self.assertEqual(keccak256(v4.PACKET_SCHEMA_BYTES), "0xbf70e9aa8f0d96855dbb2660a7cf87130d09baa0bb25fb4bb2ffd0f6103a051a")
        self.assertEqual(keccak256(v4.CONSERVATION_SCHEMA_BYTES), "0x35a7c99465ca6997901b8d401d2ae49dce3490b7bf9f6b1debbe0b8960c90f3b")
        for edit in (lambda v: v.update(version="1"), lambda v: v.update(historicalFloor={}),
                lambda v: v["tier"].update(completedMintCount=str(1 << 256))):
            value = self.fresh(); edit(value); self.reject(value)


if __name__ == "__main__": unittest.main()
