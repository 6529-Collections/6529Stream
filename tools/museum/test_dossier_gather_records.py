"""Synthetic native-reader and pure extraction controls; no chain acceptance.

Reader fixtures exercise actual ABI/replay code using fabricated responses.
Typed-only vectors exercise the post-replay extractor boundary, not source
admission or registration, which belongs to the containing gather package.
"""
from copy import deepcopy
from hashlib import sha256
import unittest
from unittest.mock import patch

from . import dossier_gather_records as gather
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, record_chain, schema_id, subject_id
from .chain_rpc import ReplayTransport
from .independent_wire import json_values, ZERO
from .test_metadata_catalog_source import Fixture as MetadataFixture, A, H
from .test_owner_catalog_source import Fixture as OwnerFixture, record_pair


def reference(anchor, *, collection="7", token="71", serial="2", core=None):
    core = core or anchor["core"]
    pins = anchor.get("codePins", [{"address": core, "runtimeHash": anchor.get("coreRuntimeHash", H("code"))}])
    runtime = next(p["runtimeHash"] for p in pins if p["address"] == core)
    state = {"chainId": anchor["chainId"], "core": core, "collectionId": collection, "tokenId": token,
        "collectionSerial": serial, "subjectId": subject_id("token", anchor["chainId"], core, collection, token_id=token),
        "blockNumber": anchor["blockNumber"], "blockHash": anchor["blockHash"],
        "canonicalCitation": f"eip155:{anchor['chainId']}/erc721:{core}/{token}@chain:{H('citation')}"}
    return {"sourceState": state, "sourceAnchor": {**{k: anchor[k] for k in
        ("timestamp", "stateRoot", "environment", "deploymentEvidenceHash")}, "coreRuntimeHash": runtime,
        "runtimePins": pins}, "coreFacts": {"lifecycle": "2", "burned": False, "owner": A(8)}, "rpcReadPins": []}


def captured(identifier, kind, source):
    raw = source.snapshot()
    return {"id": identifier, "kind": kind, "anchor": source.anchor_bytes, "snapshot": raw,
        "provenance": source.provenance}


def typed_owner(family, schema, value, anchor):
    """Post-replay synthetic wire vector with exact original hash commitments."""
    from . import owner_catalog_source as owner
    payload = dumps(value)
    _, record, receipt, bundle = record_pair(record_type=schema_id(family), payload=payload)
    record, receipt = list(record), list(receipt)
    record[1] = subject_id("token", anchor["chainId"], anchor["core"], "0", token_id="71")
    record[2] = schema_id("STREAM_" + family + "_V1")
    record[3] = (1, hex_bytes(keccak256(payload)), gather.JCS_ID)
    receipt[9], receipt[10] = keccak256(schema), gather.JCS_HASH
    digest = owner.native_hash(int(anchor["chainId"]), anchor["host"], anchor["core"], record, receipt)
    receipt[4] = record_chain("31337", A(1), "71", record[0], ZERO, digest, "0")
    return {"id": family.lower(), "kind": "owner", "anchor": deepcopy(anchor), "provenance": "synthetic_fixture",
        "snapshot": {"records": [{"recordHash": digest, "record": json_values(record), "receipt": json_values(receipt),
            "signatureBundleHex": "0x" + bundle.hex(), "payloadCorrespondence": "embedded_keccak256_verified",
            "publication": None}], "lanes": [{"recordType": record[0], "count": "1", "head": receipt[4], "records": [digest]}]}}


class GatherRecordsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Complete concrete captures are shared read-only among extraction tests.
        fixture = MetadataFixture()
        cls.metadata_anchor = fixture.anchor
        cls.metadata = captured("metadata", "metadata", fixture.source())
        owner = OwnerFixture()
        cls.owner_anchor = owner.anchor
        cls.owner = captured("owner", "owner", owner.source())

    def test_full_mixed_subject_occurrences_original_order_bytes_and_empty_head(self):
        item = deepcopy(self.metadata)
        files, report = gather.extract(reference(self.metadata_anchor), [item])
        originals = loads(item["snapshot"], maximum=gather.MAX_BYTES)["records"]
        self.assertEqual(len(report["records"]), len(originals))
        self.assertEqual({r["subjectRelation"] for r in report["records"]},
            {"exact_token", "collection_context", "other_subject_context"})
        by_hash = {r["recordHash"]: r for r in originals}
        for row in report["records"]:
            original = by_hash[row["recordHash"]]
            self.assertEqual(loads(files[row["envelopePath"]]), original)
            self.assertEqual(files[row["payloadPath"]], hex_bytes(original["payloadHex"]))
            self.assertEqual(row["historicalAuthority"]["recorder"], original["receipt"][1])
        work = next(h for h in report["heads"] if h["recordType"] == schema_id("WORK_DESCRIPTION"))
        self.assertEqual(work["count"], "4")
        self.assertEqual([loads(files[p])["receipt"][4] for p in work["recordEnvelopePaths"]], ["0", "1", "2", "3"])
        self.assertTrue(any(h["count"] == "0" and h["headHash"] == ZERO for h in report["heads"]))
        paths = [r["payloadPath"] for r in report["records"]]
        self.assertEqual(len(paths), len(set(paths)))
        self.assertGreater(len(paths), len({files[p] for p in paths}))
        self.assertTrue(all(r["interpretation"]["status"] == "unsupported" for r in report["records"]))
        self.assertFalse(report["claims"]["actualChainAcceptance"])
        self.assertFalse(report["claims"]["currentRecordSelectionDerived"])

    def test_owner_keccak_sha_empty_opaque_and_original_signature_forms(self):
        files, report = gather.extract(reference(self.owner_anchor), [self.owner])
        originals = loads(self.owner["snapshot"], maximum=gather.MAX_BYTES)["records"]
        self.assertEqual(len(report["records"]), 4)
        self.assertEqual(len(report["heads"]), 11)  # Ten native families plus admitted type.
        self.assertIn(b"", [files[r["payloadPath"]] for r in report["records"]])
        self.assertIn("opaque_algorithm_commitment", [r["payloadCorrespondence"] for r in report["records"]])
        for row in report["records"]:
            original = next(r for r in originals if r["recordHash"] == row["recordHash"])
            self.assertEqual(files[row["payloadPath"]], hex_bytes(original["record"][5]))
            self.assertEqual(files[row["signatureBundlePath"]], hex_bytes(original["signatureBundleHex"]))
            self.assertNotIn("legalTitleProven", row["historicalAuthority"])
        self.assertEqual(report["typedHistoricalFacts"], [])

    def test_independent_complete_eight_lanes_original_documents_and_bundles(self):
        from .test_independent_catalog_source import IndependentCatalogSourceTests
        IndependentCatalogSourceTests.setUpClass()
        harness = IndependentCatalogSourceTests()
        source, _ = harness.adapter()
        item = captured("independent", "independent", source)
        a = loads(item["anchor"])
        files, report = gather.extract(reference(a, collection="1", token="41"), [item])
        snap = loads(item["snapshot"], maximum=gather.MAX_BYTES)
        self.assertEqual(len(report["heads"]), 8)
        self.assertEqual(len(report["records"]), len(snap["records"]))
        self.assertTrue(all(r["historicalAuthority"]["authorizationClass"] == "5" for r in report["records"]))
        self.assertTrue(all(r["signatureBundlePath"] in files for r in report["records"]))
        self.assertEqual(sum(path.endswith("/documents/0000/payload.bin") for path in files), 1)

    def test_general_v2_full_payload_chunks_native_proof_and_replay(self):
        from .test_general_attestation_source_v2 import Fixture
        from .general_attestation_source_v2 import GeneralAttestationSourceV2
        f = Fixture(generic_payload_bytes=24576)
        source = f.reader()
        item = captured("general", "general", source)
        with patch("socket.socket", side_effect=AssertionError("network disabled")):
            replay = GeneralAttestationSourceV2(source.anchor_bytes,
                ReplayTransport(source.transcript(), keccak256(source.transcript())))
            again = captured("general", "general", replay)
            files, report = gather.extract(reference(f.anchor, collection=f.anchor["collectionId"]), [again])
        self.assertEqual(again["snapshot"], item["snapshot"])
        self.assertEqual(len(report["heads"]), 4)
        large = next(r for r in report["records"] if len(files[r["payloadPath"]]) == 24576)
        self.assertEqual(len(large["payloadChunks"]), 3)
        self.assertEqual(b"".join(files[c["path"]] for c in large["payloadChunks"]), files[large["payloadPath"]])
        self.assertTrue(any(files[r["nativeArtistEvidencePath"]] for r in report["records"]))
        for row in report["records"]:
            self.assertEqual(row["historicalAuthority"]["verificationClass"],
                loads(files[row["envelopePath"]], maximum=gather.MAX_BYTES)["receipt"][1])

    def test_render_inventory_keeps_all_descriptors_without_inventing_object_bytes(self):
        from .test_object_inventory_source import Fixture
        f = Fixture(); source = f.source()
        item = captured("inventory", "inventory", source)
        snap = loads(item["snapshot"], maximum=gather.MAX_BYTES)
        admitted = f.anchor | {"environment": "local_evm_fixture", "deploymentEvidenceHash": H("synthetic inventory")}
        files, report = gather.extract(reference(admitted, collection="1", core=snap["core"]), [item])
        gathered = report["renderInventories"][0]
        self.assertEqual(len(gathered["items"]), sum(len(s["items"]) for s in snap["segments"]))
        for row in gathered["items"]:
            self.assertEqual(loads(files[row["descriptorPath"]]), row["descriptor"])
            self.assertEqual(row["referencedObjectBytes"], "not_captured_by_inventory_reader")
        self.assertEqual(gathered["tokens"], snap["tokens"])
        self.assertNotIn("collectionSerial", gathered["tokens"][0])

    def test_ownership_original_transfers_burn_and_no_inferred_title(self):
        from .test_ownership_source import OwnershipFixture
        f = OwnershipFixture(burned=True); source = f.source()
        item = captured("ownership", "ownership", source)
        ref = reference(f.a, collection="6")
        ref["coreFacts"] = {"lifecycle": "3", "burned": True, "owner": "0x" + "00" * 20}
        files, report = gather.extract(ref, [item])
        ownership = report["ownership"][0]
        self.assertEqual([t["transition"]["kind"] for t in ownership["transitions"]], ["mint", "transfer", "burn"])
        self.assertEqual(files[ownership["transferEventsPath"]], loads(item["snapshot"])["tokenTransferJsonl"].encode())
        self.assertTrue(all(t["matchingTitleBindingStatements"] == [] for t in ownership["transitions"]))
        self.assertFalse(report["claims"]["legalTitleProven"])

    def test_typed_rights_checks_exact_original_definition_and_keeps_historical_grants(self):
        from tools.metadata import rights_profile
        from .metadata_rights_source import SCHEMA_BYTES, SCHEMA_NAME, PROFILE_HASH
        item = deepcopy(self.metadata); snap = loads(item["snapshot"], maximum=gather.MAX_BYTES)
        row = deepcopy(snap["records"][0]); value = deepcopy(rights_profile.examples()[0])
        value["subjectId"] = row["record"][1]
        value["profileHash"] = PROFILE_HASH
        raw = dumps(value)
        row["record"][0] = schema_id("RIGHTS_STATEMENT")
        row["record"][2] = ["1", keccak256(raw), gather.JCS_ID]
        row["record"][4] = schema_id(SCHEMA_NAME)
        row["receipt"][6:8] = [keccak256(SCHEMA_BYTES), gather.JCS_HASH]
        row["payloadHex"] = "0x" + raw.hex()
        wire = gather._wire("metadata", row)
        interpretation, _ = gather._interpret("metadata", wire, reference(self.metadata_anchor)["sourceState"], "collection_context")
        self.assertEqual(interpretation["status"], "typed_historical")
        self.assertEqual(interpretation["value"]["grants"], value["grants"])
        self.assertEqual(interpretation["currentSelection"], "not_derived")
        self.assertEqual(gather._interpret("metadata", wire, {}, "other_subject_context")[0]["status"],
            "typed_historical")  # Meaning does not make an off-target occurrence applicable.
        for field in ("schemaHash", "canonicalizationHash"):
            bad = deepcopy(wire); bad[field] = H("unsupported")
            self.assertEqual(gather._interpret("metadata", bad, {}, "collection_context")[0]["status"], "unsupported")
        bad = deepcopy(wire); bad["payload"] += b" "
        with self.assertRaisesRegex(MuseumError, "digest differs"):
            gather._interpret("metadata", bad, {}, "collection_context")
        value["grants"].pop("print")
        bad = deepcopy(wire); bad["payload"] = dumps(value); bad["content"][1] = keccak256(bad["payload"])
        self.assertEqual(gather._interpret("metadata", bad, {}, "collection_context")[0]["status"], "invalid")

    def test_typed_owner_accession_condition_and_unsupported_definition(self):
        from . import institutional, condition
        from .test_institutional import payload
        from .test_condition import condition as condition_value
        accession = payload("ACCESSION", anchor=self.owner_anchor)
        accession["tokenId"] = accession["titleBinding"]["transfer"]["tokenId"] = "71"
        a = typed_owner("ACCESSION", institutional.SCHEMAS["ACCESSION"], accession, self.owner_anchor)
        condition_payload = condition_value(); condition_payload["tokenId"] = "71"
        condition_payload["workCitation"] = reference(self.owner_anchor)["sourceState"]["canonicalCitation"]
        c = typed_owner("CONDITION_REPORT", condition.SCHEMA_BYTES, condition_payload, self.owner_anchor)
        files, report = gather.extract(reference(self.owner_anchor), [a, c])
        self.assertEqual({r["kind"] for r in report["typedHistoricalFacts"]}, {"accession", "condition"})
        for row in report["typedHistoricalFacts"]:
            self.assertIn(row["schemaPath"], files)
            self.assertIn(row["canonicalizationPath"], files)
        bad = deepcopy(a); bad["snapshot"]["records"][0]["receipt"][9] = H("different same-name definition")
        _, changed = gather.extract(reference(self.owner_anchor), [bad])
        self.assertEqual(changed["typedHistoricalFacts"], [])
        self.assertEqual(changed["records"][0]["interpretation"]["reason"], "original_schema_commitment_unsupported")
        future = deepcopy(accession)
        future["titleBinding"]["transfer"]["blockNumber"] = str(int(self.owner_anchor["blockNumber"]) + 1)
        future_source = typed_owner("ACCESSION", institutional.SCHEMAS["ACCESSION"], future, self.owner_anchor)
        _, rejected = gather.extract(reference(self.owner_anchor), [future_source])
        self.assertEqual(rejected["typedHistoricalFacts"], [])
        self.assertEqual(rejected["records"][0]["interpretation"]["status"], "invalid")
        self.assertIn("after source block", rejected["records"][0]["interpretation"]["detail"])

    def test_title_statement_crosslink_requires_exact_transfer_not_just_transaction(self):
        from . import institutional
        from .test_institutional import payload
        from .test_ownership_source import OwnershipFixture
        f = OwnershipFixture(); ownership = captured("ownership", "ownership", f.source())
        snapshot = loads(ownership["snapshot"])
        hop = snapshot["transitions"][1]
        a = f.a | {"host": A(1)}
        value = payload("ACCESSION", anchor=a)
        value["tokenId"] = "71"
        value["titleBinding"]["transfer"] = {"chainId": a["chainId"], "core": a["core"], "tokenId": "71",
            **{k: hop[k] for k in ("transactionHash", "blockNumber", "logIndex", "from", "to")}}
        owner = typed_owner("ACCESSION", institutional.SCHEMAS["ACCESSION"], value, a)
        owner["snapshot"]["records"][0]["publication"] = {"transactionHash": hop["transactionHash"]}
        _, result = gather.extract(reference(f.a, collection="6"), [ownership, owner])
        joined = result["ownership"][0]["transitions"][1]
        self.assertEqual(len(joined["matchingTitleBindingStatements"]), 1)
        self.assertEqual(joined["sameTransactionOwnerRecords"], joined["matchingTitleBindingStatements"])
        value["titleBinding"]["transfer"]["logIndex"] = "99"
        mismatching = typed_owner("ACCESSION", institutional.SCHEMAS["ACCESSION"], value, a)
        mismatching["snapshot"]["records"][0]["publication"] = {"transactionHash": hop["transactionHash"]}
        _, result = gather.extract(reference(f.a, collection="6"), [ownership, mismatching])
        joined = result["ownership"][0]["transitions"][1]
        self.assertEqual(joined["matchingTitleBindingStatements"], [])
        self.assertEqual(len(joined["sameTransactionOwnerRecords"]), 1)
        self.assertFalse(result["claims"]["legalTitleProven"])

    def test_deterministic_paths_inventory_and_input_order_without_mutation(self):
        items = [deepcopy(self.metadata), {"id": "citation", "kind": "citation", "anchor": {}, "snapshot": {},
            "provenance": "synthetic_fixture"}]
        saved = deepcopy(items)
        first = gather.extract(reference(self.metadata_anchor), items)
        second = gather.extract(reference(self.metadata_anchor), list(reversed(items)))
        self.assertEqual(first, second); self.assertEqual(items, saved)
        files, report = first
        for row in report["fileInventory"]:
            self.assertEqual(row["bytes"], str(len(files[row["path"]])))
            self.assertEqual(row["sha256"], "0x" + sha256(files[row["path"]]).hexdigest())
        self.assertEqual(report["sources"][0]["disposition"], "handled_by_parent")

    def test_orphan_missing_index_and_head_mutations_fail_closed(self):
        for mutate in (lambda s: s["records"].pop(), lambda s: s["records"][0]["receipt"].__setitem__(4, "99"),
                       lambda s: s["lanes"][0].__setitem__("chainHash", H("wrong"))):
            bad = deepcopy(self.metadata); bad["snapshot"] = loads(bad["snapshot"], maximum=gather.MAX_BYTES)
            mutate(bad["snapshot"])
            with self.assertRaises(MuseumError):
                gather.extract(reference(self.metadata_anchor), [bad])

    def test_bounds_bad_ids_unknown_fields_and_duplicate_sources(self):
        ref = reference(self.metadata_anchor)
        for change in ({"id": "../traversal"}, {"kind": "unknown"}, {"provenance": "actual_chain"}, {"extra": True}):
            with self.assertRaises(MuseumError):
                gather.extract(ref, [self.metadata | change])
        with self.assertRaises(MuseumError):
            gather.extract(ref, [self.metadata, self.metadata])
        with patch.object(gather, "MAX_FILES", 1), self.assertRaisesRegex(MuseumError, "aggregate bound"):
            gather.extract(ref, [self.metadata])


if __name__ == "__main__":
    unittest.main()
