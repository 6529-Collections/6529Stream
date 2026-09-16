"""Focused offline token-fixture scope encoding controls."""
import base64
from copy import deepcopy
import hashlib
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .chain_abi import calldata, encode
from .citations import canonical_citation
from .current_media_inputs import image_bytes, media_description
from .independent_wire import ZERO
from .semantic_export import MANIFEST_PATH
from .token_fixture import (BUY_SIGNATURE, SALE_AUTHORIZATION, SALE_EVENT, TOOL_SNAPSHOT_FILES,
    TRANSFER_EVENT, _authorization_id, _export_scope, _mint_evidence,
    _safe_approved_signatures, _sale_digest, _wire_subject, read, rebuild)
from .token_media_inputs import token_scope

ROOT = Path(__file__).resolve().parents[2] / "schemas/museum/independent-source/local-fixture"
TOKEN_FIXTURE = Path(__file__).resolve().parents[2] / "schemas/museum/dossier/token-local-fixture"
TOKEN_FIXTURE_HASH = "0x62ad190d7baa57290c72d22a98fb2249bc043b632597fc4454e77178af883425"
EXPORT_HASH = "0x7fb4f5dda86886a7b7752ec1bd6174fd1cdf0647c7773a780f8b13c2924241b6"
BAG_HASH = "0xa5b26d213c405e04fb75d65d8bc457fd5bb1644c152025bf1cffd84a9ce36153"
OCFL_HASH = "0x2756be5dee9edc9a7a75aacd4e83aab6df15551d4c77e66247a214b43b08a766"


class TokenFixtureScopeTests(unittest.TestCase):
    def test_wire_subject_uses_exact_protocol_string_form_seen_in_retained_capture(self):
        capture = loads((ROOT / "source-capture.json").read_bytes(), maximum=67108864,
            canonical=True)
        row, = [row for row in capture["records"] if row["subject"][0] == "1"]
        anchor = loads((ROOT / "anchor.json").read_bytes(), maximum=524288, canonical=True)
        scope = token_scope(anchor["chainId"], anchor["core"], row["subject"][1],
            row["subject"][2])
        self.assertEqual(row["subject"], ["1", "1", "71", ZERO])
        self.assertEqual(_wire_subject(scope), row["subject"])

    def test_export_scope_requires_exact_chain_qualified_token_citation(self):
        scope = token_scope("31337", "0x" + "11" * 20, "1", "9")
        head = {"subjectId": scope.subject_id, "recordChainHash": "0x" + "22" * 32}
        source = {"chainId": scope.chain_id, "core": scope.core,
            "collectionId": scope.collection_id, "tokenId": scope.token_id,
            "anchorSubject": scope.anchor_subject, "recordHeads": [head],
            "canonicalCitation": canonical_citation(scope.chain_id, scope.core, scope.token_id,
                {"kind": "chain", "hash": head["recordChainHash"]})}
        package = SimpleNamespace(files=((MANIFEST_PATH, dumps({"sourceState": source})),))
        self.assertEqual(_export_scope(package, scope), source)
        altered = deepcopy(source); altered["canonicalCitation"] = canonical_citation(
            scope.chain_id, scope.core, scope.token_id)
        package = SimpleNamespace(files=((MANIFEST_PATH, dumps({"sourceState": altered})),))
        with self.assertRaisesRegex(MuseumError, "exact token scope"):
            _export_scope(package, scope)


class TokenFixtureMintEvidenceTests(unittest.TestCase):
    def fixture(self):
        png = image_bytes(); token_id = 7
        core, sale = "0x" + "11" * 20, "0x" + "12" * 20
        buyer, artist, platform = ("0x" + value * 20 for value in ("13", "14", "15"))
        wallet = "0x" + "16" * 20; profile = "0x" + "21" * 32
        safe_accounts = {artist: ["0x" + "31" * 20, "0x" + "32" * 20],
            platform: ["0x" + "33" * 20, "0x" + "34" * 20]}
        composition = {"joinedCompositionPreviouslyAccepted": False}
        sale_product = {"source": "smart-contracts/domains/mint/StreamFixedPriceSaleAdapter.sol",
            "artifact": "retained/StreamFixedPriceSaleAdapter.json", "sha256": "55" * 32,
            "origin": "accepted_mint_graph"}
        native_raw = dumps({"tokenComposition": composition,
            "products": {"StreamFixedPriceSaleAdapter": sale_product}})
        native_hash = hashlib.sha256(native_raw).hexdigest()
        authorization = (1, "0x" + "41" * 32, buyer, buyer, artist, profile,
            "0x" + "42" * 32, keccak256(png),
            schema_id("local token media capture actual mint"), "0x" + "43" * 32,
            10**16, schema_id("local token media capture sale"), 2000000000, 1)
        digest = _sale_digest(sale, authorization)
        authorization_id = _authorization_id(sale, artist, authorization[11])
        operation_root = "0x" + "44" * 32
        signatures = {safe: b"" for safe in safe_accounts}
        stub = {"safeAccounts": safe_accounts}
        for safe in signatures: signatures[safe] = _safe_approved_signatures(stub, safe)
        args = encode((SALE_AUTHORIZATION, "bytes", "bytes", "bytes"),
            (authorization, png, signatures[platform], signatures[artist]))
        tx_hash, tx_block = "0x" + "51" * 32, "0x" + "52" * 32
        common = {"transactionHash": tx_hash, "transactionIndex": "0x0",
            "blockHash": tx_block, "blockNumber": "0x64", "removed": False}
        sale_log = common | {"address": sale,
            "topics": [SALE_EVENT, authorization_id, operation_root,
                "0x" + token_id.to_bytes(32, "big").hex()],
            "data": "0x" + encode(("bytes32", "bytes32", "address", "uint256"),
                (digest, profile, wallet, 10**16)).hex(), "logIndex": "0x1"}
        transfer = common | {"address": core,
            "topics": [TRANSFER_EVENT, ZERO,
                "0x" + (bytes(12) + bytes.fromhex(buyer[2:])).hex(),
                "0x" + token_id.to_bytes(32, "big").hex()],
            "data": "0x", "logIndex": "0x0"}
        transaction = {"hash": tx_hash, "from": buyer, "to": sale,
            "value": hex(10**16), "input": calldata(BUY_SIGNATURE)[:10] + args.hex(),
            "blockHash": tx_block, "blockNumber": "0x64", "transactionIndex": "0x0"}
        receipt = {"transactionHash": tx_hash, "from": buyer, "to": sale,
            "status": "0x1", "blockHash": tx_block, "blockNumber": "0x64",
            "transactionIndex": "0x0", "logs": [transfer, sale_log]}
        metadata = {"image": media_description(png)["uri"], "token_id": token_id,
            "collection_id": 1, "collection_serial": 1,
            "token_data_base64": base64.b64encode(png).decode()}
        uri = "data:application/json;base64," + base64.b64encode(dumps(metadata)).decode()
        source_block = "0x" + "53" * 32
        view_values = {"ownerOf": (("address",), (buyer,)),
            "tokenCollectionIdentity": (("bool", "uint256", "uint256", "bool"),
                (True, 1, 1, False)), "tokenLifecycle": (("uint8",), (2,)),
            "tokenData": (("bytes",), (png,)),
            "coordinatorAtMint": (("address",), ("0x" + "17" * 20,)),
            "tokenURI": (("string",), (uri,))}
        views = {}
        for name, (kinds, values) in view_values.items():
            views[name] = {"to": core, "data": calldata(name + "(uint256)",
                ("uint256",), (token_id,)), "result": "0x" + encode(kinds, values).hex(),
                "blockHash": source_block}
        mint = {"transaction": transaction, "receipt": receipt, "transactionHash": tx_hash,
            "tokenId": str(token_id), "owner": buyer, "buyer": buyer, "artist": artist,
            "platform": platform, "collectionId": "1", "collectionSerial": "1",
            "tokenLifecycle": "2", "tokenData": "0x" + png.hex(),
            "tokenDataBytes": str(len(png)), "tokenDataHash": keccak256(png),
            "tokenDataSha256": hashlib.sha256(png).hexdigest(), "operationRootUsed": True,
            "authorizationUsed": True, "developmentEntropyOnly": True,
            "price": str(10**16), "profileId": profile, "wallet": wallet,
            "saleAuthorizationDigest": digest, "authorizationId": authorization_id,
            "operationRoot": operation_root, "coordinatorAtMint": "0x" + "17" * 20}
        evidence = {"kind": "local_evm_fixture", "nativeInputManifestSha256": native_hash,
            "nativeComposition": composition, "media": media_description(png),
            "artifacts": {"StreamFixedPriceSaleAdapter": sale_product | {"address": sale}},
            "safeAccounts": safe_accounts, "tokenMint": mint, "tokenSourceBlockViews": views}
        files = {"native-inputs.json": native_raw,
            "deployment-evidence.json": dumps(evidence)}
        result = {"nativeInputManifestSha256": native_hash, "tokenId": str(token_id)}
        anchor = {"core": core, "blockHash": source_block, "blockNumber": "101"}
        return files, result, anchor, png

    def test_exact_paid_sale_calldata_events_and_core_transfer_join(self):
        files, result, anchor, png = self.fixture()
        _, mint, _ = _mint_evidence(files, result, anchor, png)
        self.assertEqual(mint["tokenId"], result["tokenId"])

    def mutate_evidence(self, files, change):
        evidence = loads(files["deployment-evidence.json"], maximum=67108864,
            canonical=True)
        change(evidence)
        files["deployment-evidence.json"] = dumps(evidence)

    def test_unrelated_successful_payment_cannot_count_as_the_mint(self):
        files, result, anchor, png = self.fixture()
        def change(evidence):
            mint = evidence["tokenMint"]
            mint["transaction"]["to"] = mint["buyer"]
            mint["receipt"]["to"] = mint["buyer"]
            mint["transaction"]["input"] = "0x"
            mint["receipt"]["logs"] = []
        self.mutate_evidence(files, change)
        with self.assertRaisesRegex(MuseumError, "transaction/receipt differs"):
            _mint_evidence(files, result, anchor, png)

    def test_rehashed_native_manifest_must_match_retained_composition(self):
        files, result, anchor, png = self.fixture()
        old = loads(files["native-inputs.json"], canonical=True)
        native = dumps(old | {"tokenComposition": {"joinedCompositionPreviouslyAccepted": True}})
        pin = hashlib.sha256(native).hexdigest(); files["native-inputs.json"] = native
        result["nativeInputManifestSha256"] = pin
        self.mutate_evidence(files, lambda evidence: evidence.update(
            nativeInputManifestSha256=pin))
        with self.assertRaisesRegex(MuseumError, "deployment/native manifest"):
            _mint_evidence(files, result, anchor, png)

    def test_changed_calldata_or_settlement_event_is_rejected(self):
        files, result, anchor, png = self.fixture()
        self.mutate_evidence(files, lambda evidence: evidence["tokenMint"]["transaction"].update(
            input="0xdeadbeef"))
        with self.assertRaisesRegex(MuseumError, "calldata selector"):
            _mint_evidence(files, result, anchor, png)
        files, result, anchor, png = self.fixture()
        def change(evidence):
            sale = evidence["tokenMint"]["receipt"]["logs"][1]
            values = list(encode(("bytes32", "bytes32", "address", "uint256"),
                (evidence["tokenMint"]["saleAuthorizationDigest"],
                 evidence["tokenMint"]["profileId"], evidence["tokenMint"]["wallet"], 1)))
            sale["data"] = "0x" + bytes(values).hex()
        self.mutate_evidence(files, change)
        with self.assertRaisesRegex(MuseumError, "NativeSaleSettled values"):
            _mint_evidence(files, result, anchor, png)


class ActualTokenFixtureReplayTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.files, cls.retained = read(TOKEN_FIXTURE, TOKEN_FIXTURE_HASH)
        # Replay must consume the captured inert source snapshot and use no network.
        with patch("socket.socket", side_effect=AssertionError("token replay used a network")), \
                patch("tools.museum.dossier._source_snapshot",
                      side_effect=AssertionError("token replay regenerated dossier source")):
            cls.export, cls.bag, cls.ocfl, cls.report = rebuild(cls.files)

    def test_actual_token_capture_rebuilds_all_exact_package_pins_offline(self):
        self.assertEqual(self.export.manifest_hash, EXPORT_HASH)
        self.assertEqual(self.bag.manifest_hash, BAG_HASH)
        self.assertEqual(self.ocfl.inventory_hash, OCFL_HASH)
        self.assertEqual(len(self.bag.files), 510)
        self.assertEqual(len(self.ocfl.files), 485)
        self.assertEqual(self.report["tokenId"], "1")
        self.assertTrue(self.report["trustedRpcReplay"])
        self.assertTrue(self.report["syntheticAuthoritySnapshot"])
        self.assertFalse(self.report["consensusProof"])
        self.assertFalse(self.report["fullObjectDossierConformance"])

    def test_all_actual_source_records_share_the_exact_minted_token_subject(self):
        capture = loads(self.files["source-capture.json"], maximum=67108864,
            canonical=True)
        self.assertEqual(len(capture["records"]), 15)
        self.assertEqual({tuple(row["subject"]) for row in capture["records"]},
            {("1", "1", "1", ZERO)})
        self.assertEqual(capture["lanes"][0]["count"], "15")
        self.assertEqual(self.report["subjectId"],
            "0x2f4ce6f76fb30d506d480e39202ed6fbf92f5721a6c98fa85af9b9b38a6d5331")

    def test_rebuilt_bag_uses_original_inert_dossier_tool_snapshot(self):
        bag_files = dict(self.bag.files)
        for retained_path in TOOL_SNAPSHOT_FILES:
            bag_path = retained_path[len("dossier-bag/"):]
            self.assertEqual(bag_files[bag_path], self.files[retained_path])

    def test_external_pin_and_original_media_bytes_are_mandatory(self):
        with self.assertRaisesRegex(MuseumError, "external pin differs"):
            read(TOKEN_FIXTURE, "0x" + "ff" * 32)
        altered = dict(self.files); altered["test-image.png"] = b"changed"
        with self.assertRaisesRegex(MuseumError, "original test image differs"):
            rebuild(altered)

    def test_rehashed_foreign_token_subject_is_rejected_before_projection(self):
        altered = dict(self.files)
        capture = loads(altered["source-capture.json"], maximum=67108864,
            canonical=True)
        capture["records"][0]["subject"][2] = "2"
        altered["source-capture.json"] = dumps(capture)
        with self.assertRaisesRegex(MuseumError, "exact token subject"):
            rebuild(altered)


if __name__ == "__main__": unittest.main()
