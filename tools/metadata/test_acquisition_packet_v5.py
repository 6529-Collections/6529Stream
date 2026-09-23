"""Actual synthetic capture fragments plus explicitly supplied remaining packet fields."""
import copy
import unittest
from unittest.mock import patch
from jsonschema import Draft202012Validator

from . import acquisition_packet_v5 as v5
from . import acquisition_packet_v4 as v4
from .test_acquisition_packet_v4 import rehash_selections
from tools.museum.canonical import MuseumError, dumps, keccak256, loads
from tools.museum.direct_conservation_fixture import DirectConservationFixture
from tools.museum import acquisition_direct_conservation as assembly_module

H = lambda value: keccak256(str(value).encode())


def assembled(fixture=None):
    values = (fixture or DirectConservationFixture()).packages()
    return assembly_module.compose(*sum(([dict(value.files), value.manifest_hash] for value in values), []), disclosure="public")


def supplied(assembly=None):
    """Full synthetic shape; remaining references/denominators are supplied, not authenticated."""
    assembly = assembly or assembled(); files = dict(assembly.files)
    read = lambda path: loads(files[path], maximum=v5.MAX_BYTES)
    ctx = read("packet/conservation-context.json")
    direct = read("direct-assembly/packet/native-direct-floor.json")
    personhood = read("direct-assembly/packet/native-personhood.json")
    selected = read("captures/selection/source/snapshot.json")
    value = copy.deepcopy(v4.v1.examples()["acquisition-packet.json"])
    state = copy.deepcopy(ctx["sourceState"])
    value.update(schema=v5.PACKET, version=5, sourceState=state, subjectId=state["subjectId"])
    value["erc721Identity"] = {"core": state["core"], "collectionId": state["collectionId"],
        "globalTokenId": state["tokenId"], "catalogNumber": state["tokenId"], "collectionSerial": state["collectionSerial"]}
    value["contentRootProof"]["subjectId"] = state["subjectId"]
    value["conservation"] = {"kind": "native_direct_conservation", "context": ctx, "floor": direct}
    value["attribution"]["personhood"] = personhood
    attribution = value["attribution"]; current = selected["currentAssociation"]
    states = {"1": "claimed", "2": "artist_accepted", "3": "artist_sanctioned", "4": "disputed", "5": "revoked"}
    if current["attribution"][0] not in states:
        raise MuseumError("synthetic V5 helper has no authenticated platform attribution evidence")
    attribution["state"] = states[current["attribution"][0]]
    attribution["artistId"] = None if personhood["current"]["artistId"] == v5.ZERO else personhood["current"]["artistId"]
    attribution["bindingGeneration"] = current["attribution"][1]
    def legacy_record(label, family, schema, *, scope="collection"):
        return {"recordHash": H("synthetic-supplied-" + label), "host": ctx["metadataHost"],
            "subjectId": state["collectionSubjectId" if scope == "collection" else "subjectId"], "subjectKind": scope,
            "recordType": H(family), "schemaId": H(schema), "signer": current["binding"][1],
            "authorityClass": "1", "recordedBlock": "1"}
    if attribution["state"] in ("artist_accepted", "artist_sanctioned"):
        attribution["binding"] = {"status": "present", "record": legacy_record("binding", "ARTIST_BINDING", "SYNTHETIC_BINDING")}
    if attribution["state"] == "artist_sanctioned":
        attribution["sanction"] = {"status": "present", "record": legacy_record("sanction", "ARTIST_SANCTION", "SYNTHETIC_SANCTION")}
    observation = attribution["attestation"]
    observation.update(host=personhood["sourceBindings"]["currentAttribution"], collectionId=state["collectionId"],
        observedBlock=state["blockNumber"], observedBlockHash=state["blockHash"])
    rights_path = "direct-assembly/provider-binding/rights-assembly/captures/rights/rights/packet-fragment.json"
    value["rights"] = read(rights_path)
    value["rights"]["selectionEvidence"]["uri"] = v5.RIGHTS_SNAPSHOT_URI
    value["tombstone"]["record"] = legacy_record("tombstone", "WORK_DESCRIPTION", "STREAM_WORK_DESCRIPTION_V1", scope="token")
    leaf = value["entropy"]["leaf"]; leaf["tokenId"] = state["tokenId"]
    value["entropy"]["leafHash"] = v4.v1._entropy_hash(leaf)
    for index, event in enumerate(value["entropy"]["events"]):
        event.update(tokenId=state["tokenId"], blockNumber=state["blockNumber"], logIndex=str(100 + index))
    mint = next(row["completedMint"] for row in assembly.report["tierJoin"]["directTokens"] if row["tokenId"] == state["tokenId"])
    transfer = {"from": v5.ZERO_ADDRESS, "to": mint["recipient"],
        **{key: mint["publication"][key] for key in ("blockNumber", "transactionHash", "logIndex")}}
    owner = value["ownershipProvenance"]
    owner.update(core=state["core"], tokenId=state["tokenId"], transfers=[transfer], currentOwner=transfer["to"])
    if state["burned"]:
        owner["transfers"].append({"from": transfer["to"], "to": v5.ZERO_ADDRESS,
            "blockNumber": state["blockNumber"], "transactionHash": H("synthetic-burn"), "logIndex": "200"})
        owner["currentOwner"] = v5.ZERO_ADDRESS
    value["platformSustainability"]["stateExport"].update(exportedAt=state["examinedAt"], ageSeconds="0")
    heads = {}
    for scope in ctx["scopes"].values():
        for origin in ("artist", "estate"):
            if scope[origin]["status"] != "selected": continue
            selection = scope[origin]["selection"]
            for row in (selection["record"], selection["interview"]):
                if row is None: continue
                original, evidence = row["original"], row["evidence"]
                key = ("metadata", original["host"], state["collectionId"], original["recordType"])
                count = str(int(evidence["recordIndex"]) + 1)
                if key not in heads or int(heads[key]["count"]) < int(count):
                    heads[key] = dict(zip(("lane", "host", "scopeKey", "recordType"), key), count=count, headHash=evidence["recordChainHash"])
    g = personhood["general"]
    if g:
        receipt = g["authority"]["receipt"]
        key = ("general", personhood["original"]["summary"][9][5], g["attestation"][1], g["attestation"][3])
        count = max(int(receipt[4]) + 1, int(g["recorderHistory"]["eventCount"]))
        digest = receipt[5] if count == int(receipt[4]) + 1 else H("explicitly-supplied-later-General-chain-head")
        heads[key] = dict(zip(("lane", "host", "scopeKey", "recordType"), key), count=str(count), headHash=digest)
    if not heads:
        key = ("metadata", ctx["metadataHost"], state["collectionId"], H("SYNTHETIC_CITATION_FAMILY"))
        heads[key] = dict(zip(("lane", "host", "scopeKey", "recordType"), key), count="1", headHash=H("supplied-citation-head"))
    value["recordChainHeads"] = [heads[key] for key in sorted(heads)]
    work = f"eip155:{state['chainId']}/erc721:{state['core']}/{state['tokenId']}"
    digest = value["recordChainHeads"][0]["headHash"]
    value["citation"] = {"work": work, "qualified": work + "@chain:" + digest, "qualifier": {"kind": "chain", "hash": digest}}
    return value


class AcquisitionPacketV5Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.assembly = assembled(); cls.value = supplied(cls.assembly)

    def fresh(self): return copy.deepcopy(self.value)
    def reject(self, value, text=None):
        with self.assertRaises(MuseumError) as caught: v5.validate(dumps(value))
        if text: self.assertIn(text, str(caught.exception))

    def test_complete_shape_and_exact_native_fragments_offline(self):
        with patch("socket.socket", side_effect=AssertionError("offline")), patch.object(v4, "_packet", side_effect=AssertionError("version local")):
            self.assertEqual(v5.validate(dumps(self.value)), self.value)
        files = dict(self.assembly.files)
        self.assertEqual(dumps(self.value["attribution"]["personhood"]), files["direct-assembly/packet/native-personhood.json"])
        self.assertEqual(dumps(self.value["conservation"]["floor"]), files["direct-assembly/packet/native-direct-floor.json"])
        self.assertEqual(set(self.value), set(v4.definitions()["packet"]["required"]))

    def test_scope_and_native_authority_are_not_legacy_projections(self):
        p = self.value["attribution"]["personhood"]
        self.assertNotEqual(p["general"]["attestation"][1], self.value["sourceState"]["collectionId"])
        self.assertEqual(p["general"]["authority"]["kind"], "native_general_receipt")
        self.assertNotEqual(p["identities"]["currentRegistration"], p["identities"]["currentOperative"])
        old = self.fresh(); old.update(schema=v4.PACKET, version=4)
        with self.assertRaises(MuseumError): v4.validate(dumps(old))

    def test_all_required_groups_and_closed_native_boundaries(self):
        for field in v4.definitions()["packet"]["required"]:
            with self.subTest(field=field):
                value = self.fresh(); del value[field]; self.reject(value)
        value = self.fresh(); value["conservation"]["kind"] = "native_conservation"; self.reject(value)
        value = self.fresh(); value["conservation"]["floor"]["floor"]["settlements"] = []; self.reject(value)
        value = self.fresh(); value["attribution"]["personhood"]["general"]["authority"]["authorityClass"] = "1"; self.reject(value)

    def test_independent_general_collection_exact_head_required(self):
        value = self.fresh(); head = next(h for h in value["recordChainHeads"] if h["lane"] == "general")
        head["scopeKey"] = value["sourceState"]["collectionId"]; value["recordChainHeads"].sort(key=v4.v1._head_key)
        self.reject(value, "General matching head missing")
        for field, bad in (("count", "0"), ("headHash", H("different-head"))):
            value = self.fresh(); head = next(h for h in value["recordChainHeads"] if h["lane"] == "general")
            if field == "count": head.update(count="0", headHash=v5.ZERO)
            else: head[field] = bad
            cited = next(h["headHash"] for h in value["recordChainHeads"] if h["lane"] == "metadata")
            value["citation"]["qualifier"]["hash"] = cited
            value["citation"]["qualified"] = value["citation"]["work"] + "@chain:" + cited
            self.reject(value, "General head/count")
        value = self.fresh(); head = copy.deepcopy(value["recordChainHeads"][0]); head.update(host="0x" + "67" * 20, scopeKey="8")
        value["recordChainHeads"].append(head); value["recordChainHeads"].sort(key=v4.v1._head_key)
        self.reject(value, "native lane scope")

    def test_native_general_cannot_escape_as_numeric_legacy_reference(self):
        value = self.fresh(); p = value["attribution"]["personhood"]; record = value["attribution"]["binding"]["record"]
        record.update(host=p["original"]["summary"][9][5], recordHash=p["general"]["recordHash"])
        self.reject(value, "General cannot be relabeled")
        value = self.fresh(); value["attribution"]["personhood"]["general"]["authority"]["receipt"][1] = "2"
        self.reject(value, "General original receipt fields")

    def test_selected_metadata_head_count_chain_and_authority(self):
        value = self.fresh(); value["recordChainHeads"] = [h for h in value["recordChainHeads"] if h["lane"] != "metadata"]
        self.reject(value, "metadata matching record head")
        value = self.fresh(); head = next(h for h in value["recordChainHeads"] if h["lane"] == "metadata")
        head.update(count="0", headHash=v5.ZERO); self.reject(value, "metadata record index exceeds")
        value = self.fresh(); ctx = value["conservation"]["context"]; selected = ctx["scopes"]["collection"]["artist"]["selection"]
        selected["record"]["original"]["metadataAuthorityClass"] = "3"
        self.reject(value)
        value = self.fresh(); ctx = value["conservation"]["context"]; selected = ctx["scopes"]["collection"]["artist"]["selection"]
        selected["record"]["evidence"]["recordChainHash"] = H("coherent-false-chain")
        rehash_selections(ctx, value["sourceState"])
        head = next(h for h in value["recordChainHeads"] if h["recordType"] == selected["record"]["original"]["recordType"])
        head["headHash"] = selected["record"]["evidence"]["recordChainHash"]
        v5.context.validate(dumps(ctx))
        self.reject(value, "Metadata supplied chain step")

    def test_source_time_core_and_runtime_conflicts(self):
        value = self.fresh(); value["conservation"]["context"]["sourceState"]["examinedAt"] = str(int(value["sourceState"]["examinedAt"]) + 1)
        self.reject(value, "context source differs")
        value = self.fresh(); p = value["attribution"]["personhood"]; p["sourceState"]["timestamp"] = str(int(p["sourceState"]["timestamp"]) + 1)
        v5.personhood.validate(dumps(p)); self.reject(value, "source contexts differ")
        value = self.fresh(); value["conservation"]["context"]["coreRuntimeHash"] = H("different-current-core")
        self.reject(value, "runtime commitments differ")
        value = self.fresh(); value["sourceState"]["core"] = "0x" + "88" * 20
        self.reject(value, "token subject join")

    def test_registration_identity_not_operative_and_current_artist_generation(self):
        self.assertEqual(v5.validate(dumps(self.value)), self.value)
        for field, bad in (("artistId", H("foreign-artist")), ("bindingGeneration", "2")):
            value = self.fresh(); value["attribution"][field] = bad
            self.reject(value, "current Artist identity/generation")
        value = self.fresh(); ctx = value["conservation"]["context"]
        selection = ctx["scopes"]["collection"]["artist"]["selection"]
        selection["association"]["identityRecordHash"] = value["attribution"]["personhood"]["current"]["operativeIdentityRecordHash"]
        rehash_selections(ctx, value["sourceState"])
        v5.context.validate(dumps(ctx)); self.reject(value, "eligible selection/current Artist")

    def test_shared_native_publication_slot_conflict_after_fragment_validation(self):
        value = self.fresh(); p = value["attribution"]["personhood"]
        p["original"]["statementRetention"]["publication"] = copy.deepcopy(value["conservation"]["floor"]["binding"]["publication"])
        v5.personhood.validate(dumps(p))
        self.reject(value, "native event slot differs")

    def test_direct_target_identity_and_completed_mint_chronology(self):
        value = self.fresh(); identity = value["conservation"]["floor"]["floor"]["directSales"][0]["originalSale"]["tokenIdentity"]
        identity["collectionSerial"] = "4"
        v5.direct.validate(dumps(value["conservation"]["floor"]))
        self.reject(value, "DIRECT target identity differs")
        value = self.fresh(); transfer = value["ownershipProvenance"]["transfers"][0]
        transfer["logIndex"] = "999"; self.reject(value, "completed mint must precede")
        value = self.fresh(); transfer = value["ownershipProvenance"]["transfers"][0]
        transfer["to"] = "0x" + "77" * 20; value["ownershipProvenance"]["currentOwner"] = transfer["to"]
        self.reject(value, "native transfer occupied event slot")
        value = self.fresh(); value["ownershipProvenance"]["currentOwner"] = "0x" + "77" * 20
        self.reject(value, "current owner/burn join")

    def test_rights_relative_uri_exception_is_one_exact_location(self):
        value = self.fresh(); value["rights"]["selectionEvidence"]["uri"] += "/../other"
        self.reject(value, "reference URI")
        value = self.fresh(); value["finality"]["evidence"]["uri"] = v5.RIGHTS_SNAPSHOT_URI
        self.reject(value, "reference URI")
        value = self.fresh(); value["rights"]["selectionEvidence"]["hash"]["digest"] = "0x00"
        self.reject(value, "fixed HashRef digest length")

    def test_source_pins_and_significant_native_hashes_fail_closed(self):
        for role in ("tier", "selection"):
            value = self.fresh(); value["conservation"]["context"]["sourceRefs"][role]["sourceProfileHash"] = H("unknown-profile")
            self.reject(value)
        for field in ("documentaryHash", "moduleIdentityHash"):
            value = self.fresh(); value["attribution"]["personhood"]["general"][field] = H("bad-native-hash")
            self.reject(value)
        value = self.fresh(); value["conservation"]["floor"]["floor"]["directSales"][0]["receipt"][5] = H("bad-original-hash")
        self.reject(value)

    def test_unchanged_other_packet_joins_remain_enforced(self):
        mutations = [
            (lambda v: v["rights"].update(completeness="absent"), "rights precedence"),
            (lambda v: v["entropy"].update(leafHash=H("false-entropy")), "entropy leaf"),
            (lambda v: v["preservation"].update(coverage="covered"), "covered requires cycle"),
            (lambda v: v["tombstone"]["record"].update(schemaId=H("foreign-schema")), "tombstone schema"),
            (lambda v: v["platformSustainability"]["stateExport"].update(ageSeconds="1"), "state export age"),
            (lambda v: v["erc721Identity"].update(catalogNumber="999"), "ERC721 identity"),
            (lambda v: v["attribution"]["attestation"].update(nativeStatus="1", statusLabel="CURRENT"), "attestation original record"),
        ]
        for mutate, expected in mutations:
            with self.subTest(expected=expected):
                value = self.fresh(); mutate(value); self.reject(value, expected)

    def test_exact_schema_and_old_definitions_unchanged(self):
        Draft202012Validator.check_schema(loads(v5.PACKET_SCHEMA_BYTES, maximum=v5.MAX_BYTES))
        self.assertEqual(v5.PACKET_SCHEMA_HASH, keccak256(v5.PACKET_SCHEMA_BYTES))
        for module in (v4.v1, v4.v2, v4.v3, v4):
            for name, raw in module.documents().items():
                folder = "profiles/" if name == v4.v2.PROFILE else ""
                self.assertEqual((v5.ROOT / "schemas/records" / (folder + name + ".json")).read_bytes(), raw)
        self.assertEqual(v4.PACKET_SCHEMA_HASH, "0xbf70e9aa8f0d96855dbb2660a7cf87130d09baa0bb25fb4bb2ffd0f6103a051a")

    def test_fixed_erc20_and_auction_native_products(self):
        for product in (v5.direct.source.ERC20, v5.direct.source.AUCTION):
            with self.subTest(product=product):
                value = supplied(assembled(DirectConservationFixture(product=product)))
                self.assertEqual(v5.validate(dumps(value)), value)

    def test_later_examination_preserves_source_block_time(self):
        value = self.fresh(); source = value["sourceState"]
        source["examinedAt"] = str(int(source["examinedAt"]) + 10)
        value["conservation"]["context"]["sourceState"] = copy.deepcopy(source)
        value["platformSustainability"]["stateExport"]["ageSeconds"] = "10"
        self.assertEqual(v5.validate(dumps(value)), value)

    def test_exact_metadata_alias_preserves_recorder_not_artist_authority(self):
        value = self.fresh(); row = value["conservation"]["context"]["scopes"]["collection"]["artist"]["selection"]["record"]
        original, evidence = row["original"], row["evidence"]
        alias = {"recordHash": evidence["recordHash"], "host": original["host"], "subjectId": original["subjectId"],
            "subjectKind": "collection", "recordType": original["recordType"], "schemaId": original["schemaId"],
            "signer": evidence["recorder"], "authorityClass": original["metadataAuthorityClass"],
            "recordedBlock": original["publication"]["blockNumber"]}
        # The original generic binding slot does not itself authenticate binding semantics.
        value["attribution"]["binding"]["record"] = alias
        self.assertEqual(v5.validate(dumps(value)), value)
        for field, bad in (("authorityClass", "3"), ("signer", "0x" + "66" * 20), ("recordType", H("another-type")),
                ("schemaId", H("another-schema")), ("recordedBlock", "2")):
            with self.subTest(field=field):
                changed = copy.deepcopy(value); changed["attribution"]["binding"]["record"][field] = bad
                self.reject(changed, "Metadata legacy alias differs")

    def test_personhood_statuses_preserve_original_and_current_scope(self):
        for mode, status in (("none", "NONE"), ("waiver", "WAIVER"), ("legacy", "UNRESOLVED"),
                ("stale_head", "STALE"), ("other_recorder", "RESOLVED"), ("imported", "RESOLVED"), ("imported_waiver", "WAIVER")):
            with self.subTest(mode=mode):
                value = supplied(assembled(DirectConservationFixture(personhood_mode=mode)))
                self.assertEqual(v5.validate(dumps(value))["attribution"]["personhood"]["current"]["status"], status)
                if mode == "stale_head":
                    head = next(h for h in value["recordChainHeads"] if h["lane"] == "general")
                    head.update(count="1", headHash=value["attribution"]["personhood"]["general"]["authority"]["receipt"][5])
                    value["citation"]["qualifier"]["hash"] = head["headHash"]
                    value["citation"]["qualified"] = value["citation"]["work"] + "@chain:" + head["headHash"]
                    self.reject(value, "General head/count differs")


if __name__ == "__main__": unittest.main()
