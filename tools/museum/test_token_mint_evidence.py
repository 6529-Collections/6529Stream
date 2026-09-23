"""Pure extractor controls; synthetic mutations never establish chain acceptance.

The actual retained-byte case checks extraction only. It does not repeat the
containing fixture's expensive replay or obtain any new chain evidence.
"""
from copy import deepcopy
import hashlib
from pathlib import Path
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .chain_abi import decode, encode
from .citations import canonical_citation
from .object_dossier_native import reference_from_originals
from .token_fixture import SALE_AUTHORIZATION, read
from .token_media_inputs import token_scope
from . import test_token_fixture as retained_tests
from .test_object_dossier_native import reference
from . import token_mint_evidence as mint


def fixture():
    originals, result, short_anchor, _ = retained_tests.TokenFixtureMintEvidenceTests().fixture()
    evidence = loads(originals["deployment-evidence.json"], maximum=67108864, canonical=True)
    native = loads(originals["native-inputs.json"], canonical=True)
    runtime = keccak256(b"synthetic runtime")
    for name, address in (("StreamCore", short_anchor["core"]),
                          ("StreamEntropyCoordinator", evidence["tokenMint"]["coordinatorAtMint"])):
        product = {"source": "synthetic/" + name + ".sol", "artifact": "synthetic/" + name + ".json",
                   "sha256": "55" * 32, "origin": "synthetic_fixture"}
        native["products"][name] = product
        evidence["artifacts"][name] = product | {"address": address, "runtimeHash": runtime}
    evidence["artifacts"]["StreamFixedPriceSaleAdapter"]["runtimeHash"] = runtime
    originals["native-inputs.json"] = dumps(native)
    evidence["nativeInputManifestSha256"] = hashlib.sha256(originals["native-inputs.json"]).hexdigest()
    receipt = evidence["tokenMint"]["receipt"]
    common = {k: receipt[k] for k in ("transactionHash", "transactionIndex", "blockHash", "blockNumber")}
    word = lambda n: "0x" + n.to_bytes(32, "big").hex()
    registered = common | {"removed": False, "address": short_anchor["core"], "logIndex": "0x0",
        "topics": [mint.REGISTERED_EVENT, word(7), word(1)],
        "data": "0x" + encode(("uint16", "uint256"), (1, 1)).hex()}
    entropy = common | {"removed": False, "address": evidence["tokenMint"]["coordinatorAtMint"],
        "logIndex": "0x1", "topics": [mint.ENTROPY_REGISTERED_EVENT, word(1), word(7)],
        "data": schema_id("local token media capture actual mint")}
    receipt["logs"][0]["logIndex"] = "0x2"
    receipt["logs"][1]["logIndex"] = "0x3"
    receipt["logs"] = [registered, entropy] + receipt["logs"]
    originals["deployment-evidence.json"] = dumps(evidence)
    anchor = short_anchor | {"chainId": "31337", "timestamp": "2000000000",
        "stateRoot": schema_id("synthetic state root"), "environment": "local_evm_fixture",
        "deploymentEvidenceHash": keccak256(originals["deployment-evidence.json"]),
        "codePins": [{"address": short_anchor["core"], "runtimeHash": runtime}]}
    originals["anchor.json"] = dumps(anchor)
    ref = reference(anchor, token=result["tokenId"])
    ref["coreFacts"]["owner"] = evidence["tokenMint"]["buyer"]
    return ref, originals


def mutate(ref, originals, change):
    evidence = loads(originals["deployment-evidence.json"], maximum=67108864, canonical=True)
    change(evidence)
    originals["deployment-evidence.json"] = dumps(evidence)
    ref["sourceAnchor"]["deploymentEvidenceHash"] = keccak256(originals["deployment-evidence.json"])
    anchor = loads(originals["anchor.json"], canonical=True)
    anchor["deploymentEvidenceHash"] = ref["sourceAnchor"]["deploymentEvidenceHash"]
    originals["anchor.json"] = dumps(anchor)


class MintEvidenceTests(unittest.TestCase):
    def test_exact_original_bytes_ordered_events_and_explicit_entropy_gaps(self):
        ref, originals = fixture()
        before = deepcopy((ref, originals))
        with patch("socket.socket", side_effect=AssertionError("pure extractor used network")):
            files, report = mint.extract(ref, originals)
        self.assertEqual((ref, originals), before)
        self.assertEqual(mint.extract(ref, dict(reversed(list(originals.items())))), (files, report))
        evidence = loads(originals["deployment-evidence.json"], maximum=67108864, canonical=True)
        source = evidence["tokenMint"]
        self.assertEqual(files[report["mint"]["transaction"]["calldataPath"]], bytes.fromhex(source["transaction"]["input"][2:]))
        self.assertEqual(files[report["mint"]["tokenData"]["path"]], bytes.fromhex(source["tokenData"][2:]))
        self.assertEqual(loads(files[report["mint"]["receipt"]["path"]], canonical=True), source["receipt"])
        self.assertEqual(list(report["mint"]["logs"]), ["registered", "entropyRegistered", "transfer", "sale"])
        self.assertEqual([r["logIndex"] for r in report["mint"]["logs"].values()], ["0x0", "0x1", "0x2", "0x3"])
        self.assertEqual(report["mint"]["paidAuthorization"]["price"], source["price"])
        self.assertEqual(report["mint"]["mintCommitment"], schema_id("local token media capture actual mint"))
        self.assertTrue(all(set(r) == set(mint.LOG_FIELDS) for r in report["mint"]["logs"].values()))
        self.assertFalse(any(report["claims"].values()))
        self.assertEqual(set(report["fieldGaps"]), {"entropyStatus", "seed", "provider", "providerEpoch",
            "requestKey", "requestAttempt", "requestedFinalizedEvents", "coordinatorSourceBlockRuntime", "saleSourceBlockRuntime"})
        self.assertEqual(report["fileInventory"], [mint._file(p, b) for p, b in sorted(files.items())])
        self.assertTrue(all(path.startswith("mint/originals/") for path in files))
        self.assertTrue(all("path" not in descriptor and descriptor["originalName"] == name
                            for name, descriptor in report["originals"].items()))
        self.assertEqual(report["mint"]["identityObservation"], "original_mint_transaction")
        self.assertEqual(report["sourceBlockViews"]["observation"], "source_block")

    def reject(self, change, message):
        ref, originals = fixture()
        mutate(ref, originals, change)
        with self.assertRaisesRegex(MuseumError, message):
            mint.extract(ref, originals)

    def test_duplicate_event_with_valid_renumbered_receipt_rejected(self):
        def change(e):
            logs = e["tokenMint"]["receipt"]["logs"]
            logs.insert(1, deepcopy(logs[0]))
            for i, row in enumerate(logs): row["logIndex"] = hex(i)
        self.reject(change, "Core registration event count")

    def test_valid_coordinate_event_reordering_rejected(self):
        def change(e):
            logs = e["tokenMint"]["receipt"]["logs"]
            logs[0], logs[1] = logs[1], logs[0]
            for i, row in enumerate(logs): row["logIndex"] = hex(i)
        self.reject(change, "native event sequence")

    def test_missing_or_repeated_log_index_rejected_in_all_receipt_logs(self):
        for index in ("0x2", "0x4", "0x01"):
            with self.subTest(index=index):
                self.reject(lambda e: e["tokenMint"]["receipt"]["logs"][1].update(logIndex=index),
                            "log order/gap/duplicate|log index differs")

    def test_removed_and_foreign_transaction_even_unknown_logs_rejected(self):
        for change in ({"removed": True}, {"blockHash": schema_id("foreign")},
                       {"transactionHash": schema_id("foreign")}, {"transactionIndex": "0x1"}):
            with self.subTest(change=change):
                def mutate_unknown(e):
                    logs = e["tokenMint"]["receipt"]["logs"]
                    unknown = deepcopy(logs[-1])
                    unknown.update(logIndex="0x4", topics=[schema_id("uninterpreted event")], **change)
                    logs.append(unknown)
                self.reject(mutate_unknown, "log coordinates")

    def test_registration_wrong_emitter_scope_serial_schema_and_commitment_rejected(self):
        cases = [
            (0, {"address": "0x" + "99" * 20}, "Core registration event count"),
            (1, {"address": "0x" + "99" * 20}, "entropy registration event count"),
            (0, {"data": "0x" + encode(("uint16", "uint256"), (1, 2)).hex()}, "registration identity"),
            (0, {"data": "0x" + encode(("uint16", "uint256"), (2, 1)).hex()}, "registration identity"),
            (1, {"data": schema_id("wrong commitment")}, "entropy registration identity/commitment")]
        for i, change, error in cases:
            with self.subTest(change=change):
                self.reject(lambda e: e["tokenMint"]["receipt"]["logs"][i].update(change), error)
        def scope(e):
            e["tokenMint"]["receipt"]["logs"][1]["topics"][2] = "0x" + (8).to_bytes(32, "big").hex()
        self.reject(scope, "entropy registration identity/commitment")

    def test_paid_calldata_data_signatures_and_value_are_bound(self):
        def args_change(position, value):
            def change(e):
                tx = e["tokenMint"]["transaction"]
                args = list(decode((SALE_AUTHORIZATION, "bytes", "bytes", "bytes"), bytes.fromhex(tx["input"][10:])))
                args[position] = value
                tx["input"] = tx["input"][:10] + encode((SALE_AUTHORIZATION, "bytes", "bytes", "bytes"), args).hex()
            return change
        self.reject(args_change(1, b"altered"), "token data differs")
        self.reject(args_change(2, b""), "authorization/calldata differs")
        self.reject(args_change(3, b""), "authorization/calldata differs")
        self.reject(lambda e: e["tokenMint"]["transaction"].update(value="0x1"), "authorization/calldata differs")

    def test_rehashed_same_source_views_must_agree_with_reference_and_calldata(self):
        for name, kind, value in (("ownerOf", "address", "0x" + "99" * 20),
            ("tokenLifecycle", "uint8", 3), ("coordinatorAtMint", "address", "0x" + "99" * 20),
            ("tokenData", "bytes", b"different")):
            with self.subTest(name=name):
                self.reject(lambda e: e["tokenSourceBlockViews"][name].update(
                    result="0x" + encode((kind,), (value,)).hex()), "source-block Core/reference/calldata")
        self.reject(lambda e: e["tokenSourceBlockViews"]["tokenData"].update(blockHash=schema_id("other block")),
                    "source view query differs")

    def test_current_owner_is_separate_from_original_recipient(self):
        ref, originals = fixture()
        owner = "0x" + "99" * 20
        ref["coreFacts"]["owner"] = owner
        mutate(ref, originals, lambda e: e["tokenSourceBlockViews"]["ownerOf"].update(
            result="0x" + encode(("address",), (owner,)).hex()))
        _, report = mint.extract(ref, originals)
        self.assertEqual(report["sourceBlockViews"]["decoded"]["ownerOf"], [owner])
        self.assertNotEqual(report["mint"]["initialRecipient"], owner)

    def test_external_deployment_reference_and_product_provenance_pins(self):
        ref, originals = fixture()
        ref["sourceAnchor"]["deploymentEvidenceHash"] = schema_id("wrong")
        with self.assertRaisesRegex(MuseumError, "source/reference differs"):
            mint.extract(ref, originals)
        self.reject(lambda e: e["artifacts"]["StreamEntropyCoordinator"].update(sha256="00" * 32),
                    "product provenance differs")
        self.reject(lambda e: e["artifacts"]["StreamCore"].update(runtimeHash=schema_id("other code")),
                    "Core product/reference differs")

    def test_receipt_cannot_be_future_or_other_hash_at_source_height(self):
        for number in ("0x66", "0x65"):
            def change(e):
                original = e["tokenMint"]
                original["transaction"]["blockNumber"] = number
                original["receipt"]["blockNumber"] = number
                for row in original["receipt"]["logs"]: row["blockNumber"] = number
            with self.subTest(number=number):
                self.reject(change, "receipt/source block differs")

    def test_bounds_and_malformed_input_are_refusals(self):
        ref, originals = fixture()
        with patch.object(mint, "MAX_BYTES", 1):
            with self.assertRaisesRegex(MuseumError, "original input bound"):
                mint.extract(ref, originals)
        with patch.object(mint, "MAX_RECEIPT_BYTES", 1):
            with self.assertRaisesRegex(MuseumError, "receipt byte bound"):
                mint.extract(ref, originals)
        with self.assertRaises(MuseumError): mint.extract(ref, {})
        with self.assertRaises(MuseumError): mint.extract(ref, originals | {"untyped": "not bytes"})

    def test_actual_retained_mint_bytes_extract_offline_without_replaying_or_promoting(self):
        directory = Path(__file__).resolve().parents[2] / "schemas/museum/dossier/token-local-fixture"
        with patch("socket.socket", side_effect=AssertionError("actual retained extraction used network")):
            originals, manifest = read(directory, "0x62ad190d7baa57290c72d22a98fb2249bc043b632597fc4454e77178af883425")
            a = loads(originals["anchor.json"], maximum=524288, canonical=True)
            e = loads(originals["deployment-evidence.json"], maximum=67108864, canonical=True)
            scope = token_scope(a["chainId"], a["core"], e["tokenMint"]["collectionId"], manifest["tokenId"])
            state = {k: a[k] for k in ("chainId", "core", "blockNumber", "blockHash")}
            state.update(tokenId=manifest["tokenId"], collectionId=scope.collection_id,
                collectionSerial=e["tokenMint"]["collectionSerial"], subjectId=scope.subject_id,
                canonicalCitation=canonical_citation(a["chainId"], a["core"], manifest["tokenId"],
                    {"kind": "chain", "hash": schema_id("test-only citation qualifier")}))
            ref = reference_from_originals(state, originals)
            files, report = mint.extract(ref, originals)
        self.assertEqual([r["logIndex"] for r in report["mint"]["logs"].values()], ["0x4", "0x5", "0x6", "0xa"])
        self.assertEqual(report["mint"]["identity"]["tokenId"], "1")
        self.assertEqual(len(loads(files[report["mint"]["receipt"]["allLogsPath"]], canonical=True)), 13)
        self.assertEqual(report["mint"]["tokenData"]["keccak256"], e["tokenMint"]["tokenDataHash"])
        self.assertFalse(report["claims"]["actualChainAcceptance"])
        self.assertFalse(report["claims"]["containingFixtureReplayPerformed"])


if __name__ == "__main__":
    unittest.main()
