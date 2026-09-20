"""Synthetic orchestration controls, not execution of the actual-token recipe."""
from copy import deepcopy
import hashlib
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads
from . import current_token_dossier_capture as recipe
from . import native_dossier_capture as runner
from .test_native_dossier_capture import recipe as synthetic_plan


GENESIS = "0x" + "ab" * 32


class FreshChain:
    def __init__(self):
        self.account = "0x" + "01" * 20
        self.chain = "0x7a69"
        self.nonce = "0x0"
        self.block = {"hash": GENESIS, "number": "0x0", "parentHash": "0x" + "00" * 32, "transactions": []}
        self.seen = []

    def rpc(self, method, params):
        self.seen.append((method, params))
        if method == "eth_chainId": return self.chain
        if method in ("eth_getBlockByNumber", "eth_getBlockByHash"): return deepcopy(self.block)
        if method == "eth_getTransactionCount": return self.nonce
        raise AssertionError("unexpected transaction or chain operation: " + method)


def inputs():
    _, reference, plan = synthetic_plan()
    anchors = {row["id"]: row["anchor"] for row in plan["sources"]}
    metadata = anchors["metadata"]
    manifest = {"tokenDossierComposition": {"version": "1", "sourceRevision": "12" * 20}}
    raw = dumps(manifest)
    fixture = SimpleNamespace(manifest_raw=raw, manifest=manifest, dossier_source_revision="12" * 20,
        token_scope=SimpleNamespace(token_id="71", collection_id="7"),
        addresses={"StreamOwnerRecords": anchors["owner"]["host"],
            "StreamCollectionAttestations": anchors["independent_collection"]["host"],
            "StreamCollectionMetadataV1": metadata["host"], "StreamArtistOnboardingRegistry": metadata["artistRegistry"]},
        schemas=metadata["schemas"], store=metadata["store"])
    evidence = dumps({"workflow": recipe.RECIPE, "nativeInputManifestSha256": hashlib.sha256(raw).hexdigest(),
        "tokenDossierComposition": manifest["tokenDossierComposition"]})
    anchor = deepcopy(metadata)
    anchor["deploymentEvidenceHash"] = keccak256(evidence)
    pins = {pin["address"]: pin["runtimeHash"] for a in anchors.values() for pin in a.get("codePins", [])}
    anchor["codePins"] = [{"address": address, "runtimeHash": digest} for address, digest in sorted(pins.items())]
    reference["sourceAnchor"]["deploymentEvidenceHash"] = keccak256(evidence)
    reference["sourceAnchor"]["runtimePins"] = anchor["codePins"]
    base_manifest = dumps({"sourceState": reference["sourceState"]})
    return fixture, dumps(anchor), evidence, base_manifest, reference


class FreshChainTests(unittest.TestCase):
    def test_only_explicit_loopback_port_without_credentials_is_accepted(self):
        self.assertEqual(recipe.local_endpoint("http://127.0.0.1:8545"), "http://127.0.0.1:8545")
        for endpoint in ("http://localhost:8545", "http://127.0.0.1", "https://127.0.0.1:8545",
                "http://127.0.0.1:8545/rpc", "http://user:secret@127.0.0.1:8545", "http://127.0.0.1:8545?secret=x",
                "http://127.0.0.1:8545#x", "http://example.org:8545", "http://127.0.0.1:99999", None):
            with self.subTest(endpoint=endpoint), self.assertRaises(MuseumError): recipe.local_endpoint(endpoint)

    def test_fresh_genesis_admission_is_read_only_and_pins_the_deployer_nonce(self):
        fixture = FreshChain()
        recipe.bind_fresh_chain(fixture, GENESIS)
        self.assertEqual(fixture.coordinated_genesis_hash, GENESIS)
        self.assertEqual(fixture.seen[-1], ("eth_getTransactionCount", [fixture.account,
            {"blockHash": GENESIS, "requireCanonical": True}]))
        self.assertTrue(all(method.startswith("eth_get") or method == "eth_chainId" for method, _ in fixture.seen))

    def test_wrong_chain_history_genesis_or_used_deployer_reject_before_mutation(self):
        for change in ("chain", "hash", "height", "parent", "transactions", "nonce"):
            fixture = FreshChain()
            if change == "chain": fixture.chain = "0x1"
            elif change == "hash": fixture.block["hash"] = "0x" + "cd" * 32
            elif change == "height": fixture.block["number"] = "0x1"
            elif change == "parent": fixture.block["parentHash"] = GENESIS
            elif change == "transactions": fixture.block["transactions"] = [GENESIS]
            else: fixture.nonce = "0x1"
            with self.subTest(change=change), self.assertRaises(MuseumError): recipe.bind_fresh_chain(fixture, GENESIS)
            self.assertFalse(hasattr(fixture, "coordinated_genesis_hash"))

    def test_changed_genesis_between_reads_is_rejected(self):
        fixture = FreshChain(); original = fixture.rpc
        def request(method, params):
            block = original(method, params)
            if method == "eth_getBlockByHash": block["extraData"] = "0x00"
            return block
        fixture.rpc = request
        with self.assertRaisesRegex(MuseumError, "changed during admission"):
            recipe.bind_fresh_chain(fixture, GENESIS)

    def test_unadmitted_build_stops_before_existing_recipe(self):
        fixture = object.__new__(recipe.CurrentTokenDossierFixture)
        with patch.object(recipe.CurrentTokenFixture, "build_media", side_effect=AssertionError("must not build")), \
                self.assertRaisesRegex(MuseumError, "fresh-chain admission"):
            fixture.build_media()

    def test_bad_manifest_or_revision_stops_before_even_the_account_read(self):
        valid = {"products": {"StreamOwnerRecords": {}},
                 "tokenDossierComposition": {"version": "1", "sourceRevision": "12" * 20,
                    "claims": {"compilerMetadataSourceCorrespondence": True}, "joinedCaptureStatus": "not_run"}}
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "manifest.json"
            for change in ("hash", "revision", "version", "owner", "stale-source", "capture-status"):
                value = deepcopy(valid)
                if change == "version": value["tokenDossierComposition"]["version"] = "0"
                if change == "owner": value["products"] = {}
                if change == "stale-source": value["tokenDossierComposition"]["claims"]["compilerMetadataSourceCorrespondence"] = False
                if change == "capture-status": value["tokenDossierComposition"]["joinedCaptureStatus"] = "accepted"
                raw = dumps(value); path.write_bytes(raw)
                pin = "00" * 32 if change == "hash" else hashlib.sha256(raw).hexdigest()
                revision = "34" * 20 if change == "revision" else "12" * 20
                with self.subTest(change=change), \
                        patch.object(recipe.CurrentTokenFixture, "__init__", side_effect=AssertionError("must not read accounts")), \
                        self.assertRaises(MuseumError):
                    recipe.CurrentTokenDossierFixture(path, "http://127.0.0.1:8545",
                        expected_manifest_sha256=pin, source_revision=revision)


class SourceFreezeTests(unittest.TestCase):
    def test_original_authority_publications_finish_before_native_hook(self):
        fixture = object.__new__(recipe.CurrentTokenDossierFixture)
        order = []
        fixture.publish_native_dossier_records = lambda: order.append("native")
        with patch.object(recipe.CurrentTokenFixture, "after_media_publications", side_effect=lambda: order.append("original")):
            fixture.after_media_publications()
        self.assertEqual(order, ["original", "native"])

    def test_new_evidence_hash_and_code_pins_share_the_original_final_block(self):
        source, raw_anchor, evidence, _, _ = inputs()
        original_anchor = loads(raw_anchor)
        fixture = object.__new__(recipe.CurrentTokenDossierFixture)
        fixture.__dict__.update(source.__dict__)
        fixture.coordinated_genesis_hash = GENESIS
        fixture.native_dossier_records = {"recordHashes": {"owner": "0x" + "01" * 32}}
        fixture.capture_code_addresses = lambda: sorted(row["address"] for row in original_anchor["codePins"])
        calls = []
        def rpc(method, params):
            calls.append((method, params))
            if method == "eth_getCode": return "0x6000"
            if method == "eth_getBlockByNumber": return {"hash": original_anchor["blockHash"]}
            raise AssertionError("unplanned freeze method")
        fixture.rpc = rpc
        with patch.object(recipe, "bind_fresh_chain") as admission, \
                patch.object(recipe.CurrentTokenFixture, "build_media", return_value=(raw_anchor, evidence)):
            updated_anchor, updated_evidence = fixture.build_media()
        admission.assert_called_once_with(fixture, GENESIS)
        a, e = loads(updated_anchor), loads(updated_evidence)
        self.assertEqual(e["workflow"], recipe.RECIPE)
        self.assertEqual(e["tokenDossierRecords"], fixture.native_dossier_records)
        self.assertEqual(e["coordinatedGenesisHash"], GENESIS)
        self.assertEqual(a["deploymentEvidenceHash"], keccak256(updated_evidence))
        self.assertNotEqual(a["deploymentEvidenceHash"], original_anchor["deploymentEvidenceHash"])
        for key in ("chainId", "core", "blockHash", "blockNumber", "stateRoot", "timestamp"):
            self.assertEqual(a[key], original_anchor[key])
        for method, params in calls:
            if method == "eth_getCode":
                self.assertEqual(params[1], {"blockHash": a["blockHash"], "requireCanonical": True})

    def test_freeze_rejects_advanced_tip_and_history_beyond_reader_bound(self):
        source, raw_anchor, evidence, _, _ = inputs()
        for change in ("tip", "bound"):
            fixture = object.__new__(recipe.CurrentTokenDossierFixture)
            fixture.__dict__.update(source.__dict__)
            fixture.coordinated_genesis_hash = GENESIS
            fixture.native_dossier_records = {}
            fixture.capture_code_addresses = lambda: []
            fixture.rpc = lambda method, params: {"hash": GENESIS}
            anchor = loads(raw_anchor)
            if change == "bound": anchor["blockNumber"] = str(recipe.MAX_BLOCKS)
            with self.subTest(change=change), patch.object(recipe, "bind_fresh_chain"), \
                    patch.object(recipe.CurrentTokenFixture, "build_media", return_value=(dumps(anchor), evidence)), \
                    self.assertRaisesRegex(MuseumError, "source changed|history source bound"):
                fixture.build_media()


class PlanConstructionTests(unittest.TestCase):
    def test_six_anchors_preserve_final_deployment_and_pass_real_reader_preflight_without_rpc(self):
        fixture, anchor, evidence, manifest, reference = inputs()
        with patch("socket.socket", side_effect=AssertionError("offline plan builder")):
            raw = recipe.make_plan(fixture, anchor, evidence, manifest)
            plan = runner._read_plan(raw, keccak256(raw))
            runner._preflight(plan, reference, hashlib.sha256(fixture.manifest_raw).hexdigest())
        self.assertEqual(len(plan["sources"]), 6)
        self.assertEqual(plan["baseManifestHash"], keccak256(manifest))
        self.assertEqual({r["anchor"]["scopeKey"] for r in plan["sources"] if r["kind"] == "independent"}, {"0", "7"})
        for row in plan["sources"]:
            self.assertEqual(row["anchor"]["deploymentEvidenceHash"], keccak256(evidence))
            self.assertEqual(row["anchor"]["blockHash"], reference["sourceState"]["blockHash"])

    def test_altered_originals_or_base_identity_cannot_generate_a_joinable_plan(self):
        for change in ("evidence", "native-manifest", "workflow", "composition", "block", "token", "collection"):
            fixture, anchor, evidence, manifest, _ = inputs()
            if change == "evidence": evidence = b"{}"
            elif change in ("native-manifest", "workflow", "composition"):
                value = loads(evidence)
                key = {"native-manifest": "nativeInputManifestSha256", "workflow": "workflow", "composition": "tokenDossierComposition"}[change]
                value[key] = "different"
                evidence = dumps(value); a = loads(anchor); a["deploymentEvidenceHash"] = keccak256(evidence); anchor = dumps(a)
            else:
                value = loads(manifest)
                value["sourceState"][{"block": "blockHash", "token": "tokenId", "collection": "collectionId"}[change]] = "0"
                manifest = dumps(value)
            with self.subTest(change=change), self.assertRaisesRegex(MuseumError, "dossier plan"):
                recipe.make_plan(fixture, anchor, evidence, manifest)

    def test_missing_or_duplicate_original_runtime_pin_fails(self):
        for change in ("missing", "duplicate"):
            fixture, anchor, evidence, manifest, _ = inputs(); value = loads(anchor)
            if change == "missing":
                value["codePins"] = [p for p in value["codePins"] if p["address"] != fixture.addresses["StreamOwnerRecords"]]
            else: value["codePins"].append(value["codePins"][0])
            with self.subTest(change=change), self.assertRaisesRegex(MuseumError, "runtime pin"):
                recipe.make_plan(fixture, dumps(value), evidence, manifest)


class PositiveRecipeCoverageTests(unittest.TestCase):
    def setUp(self):
        self.fixture = inputs()[0]
        self.fixture.native_dossier_records = {"recordHashes": {k: "0x" + b * 64 for k, b in
            (("owner", "a"), ("metadata", "b"), ("independent", "c"))}}
        rows = [("owner", "StreamOwnerRecords", "71"), ("metadata", "StreamCollectionMetadataV1", "7"),
                ("independent", "StreamCollectionAttestations", "0"), ("independent", "StreamCollectionAttestations", "7")]
        self.report = {"occurrences": [{"host": self.fixture.addresses[name], "scopeKey": scope,
            "recordHash": self.fixture.native_dossier_records["recordHashes"][kind] if scope != "7" or kind != "independent" else "0x" + "d" * 64}
            for kind, name, scope in rows], "scopeCoverage": [{"host": self.fixture.addresses[name], "scopeKey": scope,
                "status": "verified_within_registered_roster"} for _, name, scope in rows],
            "checks": [{"kind": kind, "status": "verified_within_source_profile"} for kind in runner.native.KINDS]}

    def test_original_publication_hashes_and_both_independent_scopes_are_required(self):
        recipe.require_recipe_coverage(self.fixture, {"assembly/native/joins.json": dumps(self.report)})
        for index in range(4):
            report = deepcopy(self.report); report["occurrences"].pop(index)
            with self.subTest(index=index), self.assertRaisesRegex(MuseumError, "publication occurrence"):
                recipe.require_recipe_coverage(self.fixture, {"assembly/native/joins.json": dumps(report)})

    def test_registered_scope_and_source_status_cannot_be_replaced_with_synthetic_or_outside_roster(self):
        for field, index, status in (("scopeCoverage", 0, "verified_host_outside_observed_roster"),
                ("scopeCoverage", 2, "missing_source"), ("checks", 4, "synthetic_only")):
            report = deepcopy(self.report); report[field][index]["status"] = status
            with self.subTest(field=field, status=status), self.assertRaises(MuseumError):
                recipe.require_recipe_coverage(self.fixture, {"assembly/native/joins.json": dumps(report)})

    def test_same_hash_under_other_host_or_scope_is_not_the_original_receipt(self):
        for key, value in (("host", "0x" + "ff" * 20), ("scopeKey", "8"), ("recordHash", "0x" + "ef" * 32)):
            report = deepcopy(self.report); report["occurrences"][0][key] = value
            with self.subTest(key=key), self.assertRaisesRegex(MuseumError, "publication occurrence"):
                recipe.require_recipe_coverage(self.fixture, {"assembly/native/joins.json": dumps(report)})


if __name__ == "__main__":
    unittest.main()
