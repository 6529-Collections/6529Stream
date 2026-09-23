"""Typed source replay and join controls; all constructed sources are synthetic."""
from copy import deepcopy
from pathlib import Path
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads, subject_id
from .citations import canonical_citation
from . import object_dossier_native as native
from .test_owner_catalog_source import Fixture as OwnerFixture
from .test_ownership_source import OwnershipFixture
from . import test_independent_catalog_source as independent_tests


def reference(a, *, token="71", collection="1", serial="1"):
    state = {k: a[k] for k in ("chainId", "core", "blockNumber", "blockHash")}
    state.update(tokenId=a.get("tokenId", token), collectionId=a.get("collectionId", collection), collectionSerial=serial)
    state["subjectId"] = subject_id("token", state["chainId"], state["core"], state["collectionId"], token_id=state["tokenId"])
    state["canonicalCitation"] = canonical_citation(state["chainId"], state["core"], state["tokenId"],
                                                    {"kind": "chain", "hash": state["blockHash"]})
    pins = {p["address"]: p["runtimeHash"] for p in a.get("codePins", [])}
    return {"sourceState": state, "sourceAnchor": {**{k: a[k] for k in
        ("timestamp", "stateRoot", "environment", "deploymentEvidenceHash")},
        "coreRuntimeHash": a.get("coreRuntimeHash", pins.get(state["core"])),
        "runtimePins": a.get("codePins", [{"address": state["core"], "runtimeHash": a.get("coreRuntimeHash")}])},
        "coreFacts": {"lifecycle": "2", "burned": False, "owner": "0x" + f"{2:040x}"}, "rpcReadPins": []}


def bundle(kind, source, *, identifier="source"):
    snapshot = source.snapshot()
    files = {identifier + "/anchor.json": source.anchor_bytes,
             identifier + "/transcript.json": source.transcript(), identifier + "/snapshot.json": snapshot}
    row = {"id": identifier, "kind": kind, "provenance": source.provenance}
    for label in ("anchor", "transcript", "snapshot"):
        row[label + "Path"] = identifier + "/" + label + ".json"
        row[label + "Hash"] = keccak256(files[row[label + "Path"]])
    return row, files


def envelope(ref, rows):
    return dumps({"profile": native.PROFILE, "version": "1", "disclosure": "public",
                  "sourceState": ref["sourceState"], "sources": rows})


def admit(ref, rows, files):
    raw = envelope(ref, rows)
    with patch("socket.socket", side_effect=AssertionError("offline source joins")):
        return loads(native.admit(raw, keccak256(raw), files, ref), maximum=16 * 1024 * 1024, canonical=True)


class NativeJoinTests(unittest.TestCase):
    def test_owner_complete_replay_keeps_all_occurrences_and_broad_gates_unresolved(self):
        source = OwnerFixture().source(); ref = reference(source.a); row, files = bundle("owner", source)
        result = admit(ref, [row], files)
        self.assertEqual(result["checks"][0]["status"], "synthetic_only")
        self.assertEqual(len(result["occurrences"]), 4)
        self.assertEqual(len(result["laneWitnesses"]), 11)
        self.assertEqual({o["subjectRelation"] for o in result["occurrences"]}, {"exact_token"})
        self.assertEqual(sorted(o["index"] for o in result["occurrences"]), ["0", "0", "1", "2"])
        self.assertEqual(len({o["originalSelector"] for o in result["occurrences"]}), 4)
        self.assertTrue(all(r["status"] == "unresolved" for r in result["requirements"]))
        self.assertFalse(result["claims"]["globalApplicableHostsComplete"])
        self.assertIn("registered_host_roster_missing", result["unresolved"])
        self.assertEqual(row["snapshotHash"], keccak256(files[row["snapshotPath"]]))

    def test_independent_whole_lanes_and_foreign_subject_context_are_retained(self):
        independent_tests.IndependentCatalogSourceTests.setUpClass(); case = independent_tests.IndependentCatalogSourceTests()
        source, _ = case.adapter(); ref = reference(source.a, token="1")
        row, files = bundle("independent", source)
        result = admit(ref, [row], files)
        original = loads(source.snapshot(), maximum=16 * 1024 * 1024)
        self.assertEqual(len(result["occurrences"]), len(original["records"]))
        self.assertEqual([h["originalLane"] for h in result["laneWitnesses"]], original["lanes"])
        self.assertTrue(any(o["subjectRelation"] != "exact_token" for o in result["occurrences"]))
        self.assertEqual(len(result["laneWitnesses"]), 8)

    def test_ownership_observed_serial_must_equal_verified_reference(self):
        source = OwnershipFixture().source(); ref = reference(source.a, serial="2"); row, files = bundle("ownership", source)
        result = admit(ref, [row], files)
        self.assertEqual(result["checks"][0]["kind"], "ownership")
        self.assertIn("covering_protocol_event_archive_missing", result["unresolved"])
        ref["sourceState"]["collectionSerial"] = "3"
        with self.assertRaisesRegex(MuseumError, "collection serial"): admit(ref, [row], files)

    def test_metadata_catalogue_replays_without_deducing_token_preimages(self):
        from .test_metadata_catalog_source import Fixture
        source = Fixture().source(); ref = reference(source.a); row, files = bundle("metadata", source)
        result = admit(ref, [row], files)
        original = loads(source.snapshot(), maximum=16 * 1024 * 1024)
        self.assertEqual(len(result["occurrences"]), len(original["records"]))
        self.assertEqual([r["originalLane"] for r in result["laneWitnesses"]], original["lanes"])
        self.assertEqual(result["scopeCoverage"][0]["status"], "synthetic_only")
        self.assertFalse(result["claims"]["completeCanonicalData"])

    def test_registered_roster_replay_retains_missing_applicable_scopes(self):
        from .test_dossier_hosts_source import Fixture
        source = Fixture().source(); ref = reference(source.a, serial="3")
        row, files = bundle("hosts", source)
        result = admit(ref, [row], files)
        self.assertEqual(result["checks"][0]["status"], "synthetic_only")
        self.assertIn("host_inventory_not_exhaustive", result["unresolved"])
        self.assertTrue(any(r["status"] == "missing_source" for r in result["scopeCoverage"]))
        self.assertTrue(any(r["scopeKey"] == "0" for r in result["scopeCoverage"]))

    def test_source_blocks_core_runtime_and_deployment_anchor_cannot_be_mixed(self):
        source = OwnerFixture().source(); row, files = bundle("owner", source)
        changes = [("sourceState", "blockNumber", "3"), ("sourceState", "blockHash", "0x" + "98" * 32),
                   ("sourceAnchor", "timestamp", "103"), ("sourceAnchor", "stateRoot", "0x" + "98" * 32),
                   ("sourceAnchor", "deploymentEvidenceHash", "0x" + "98" * 32),
                   ("sourceAnchor", "coreRuntimeHash", "0x" + "98" * 32),
                   ("sourceAnchor", "environment", "public_chain")]
        for section, key, value in changes:
            ref = reference(source.a); ref[section][key] = value
            with self.subTest(key=key), self.assertRaises(MuseumError): admit(ref, [row], files)

    def test_replay_detects_rehashed_snapshot_flags_and_provenance_promotion(self):
        source = OwnerFixture().source(); row, files = bundle("owner", source); ref = reference(source.a)
        snapshot = loads(files[row["snapshotPath"]], maximum=16 * 1024 * 1024)
        snapshot["claims"]["actualChainAcceptance"] = True
        changed = dict(files); changed[row["snapshotPath"]] = dumps(snapshot)
        changed_row = dict(row, snapshotHash=keccak256(changed[row["snapshotPath"]]))
        with self.assertRaisesRegex(MuseumError, "replay differs"): admit(ref, [changed_row], changed)
        with self.assertRaisesRegex(MuseumError, "replay differs"): admit(ref, [dict(row, provenance="trusted_rpc")], files)

    def test_shared_runtime_conflict_and_duplicate_logical_source_reject(self):
        source = OwnerFixture().source(); ref = reference(source.a)
        pins = {source.a["schemas"]: "0x" + "98" * 32}
        with self.assertRaisesRegex(MuseumError, "runtime conflict"):
            native._join_anchor("owner", source.a, ref, pins)
        first, files = bundle("owner", source, identifier="a")
        second, more = bundle("owner", source, identifier="b")
        with self.assertRaisesRegex(MuseumError, "duplicate logical source"): admit(ref, [first, second], files | more)

    def test_verified_original_runtime_pins_and_observed_chunk_code_are_joined(self):
        source = OwnerFixture().source(); row, files = bundle("owner", source); ref = reference(source.a)
        ref["sourceAnchor"]["runtimePins"] = deepcopy(ref["sourceAnchor"]["runtimePins"])
        ref["sourceAnchor"]["runtimePins"][2]["runtimeHash"] = "0x" + "98" * 32
        with self.assertRaisesRegex(MuseumError, "runtime conflict"): admit(ref, [row], files)
        ref = reference(source.a)
        dependency_addresses = {p["address"] for p in source.a["codePins"]}
        observed = next(r for r in source.reader.rows if r["method"] == "eth_getCode" and r["params"][0] not in dependency_addresses)
        ref["sourceAnchor"]["runtimePins"] = ref["sourceAnchor"]["runtimePins"] + [
            {"address": observed["params"][0], "runtimeHash": "0x" + "98" * 32}]
        with self.assertRaisesRegex(MuseumError, "observed shared runtime conflict"): admit(ref, [row], files)

    def test_original_rpc_results_and_core_lifecycle_cannot_be_contradicted(self):
        source = OwnerFixture().source(); row, files = bundle("owner", source); ref = reference(source.a)
        query = next(r for r in source.reader.rows if r["method"] == "eth_call")
        ref["rpcReadPins"] = [{"requestHash": keccak256(dumps([query["method"], query["params"]])),
                               "resultHash": keccak256(dumps("0x"))}]
        with self.assertRaisesRegex(MuseumError, "conflicting results"): admit(ref, [row], files)
        source = OwnershipFixture(burned=True).source(); row, files = bundle("ownership", source)
        ref = reference(source.a, serial="2")
        with self.assertRaisesRegex(MuseumError, "lifecycle/owner"): admit(ref, [row], files)
        ref["coreFacts"] = {"lifecycle": "3", "burned": True, "owner": "0x" + "00" * 20}
        self.assertEqual(admit(ref, [row], files)["checks"][0]["status"], "synthetic_only")

    def test_unrelated_collection_scope_and_false_token_subject_reject(self):
        independent_tests.IndependentCatalogSourceTests.setUpClass(); source, _ = independent_tests.IndependentCatalogSourceTests().adapter()
        row, files = bundle("independent", source); ref = reference(source.a, collection="2")
        with self.assertRaisesRegex(MuseumError, "unrelated independent scope"): admit(ref, [row], files)
        source = OwnerFixture().source(); row, files = bundle("owner", source); ref = reference(source.a)
        ref["sourceState"]["subjectId"] = "0x" + "98" * 32
        with self.assertRaisesRegex(MuseumError, "subject differs"): admit(ref, [row], files)

    def test_no_sources_retains_missing_denominators_and_never_absence(self):
        ref = reference(OwnerFixture().source().a)
        result = admit(ref, [], {})
        self.assertEqual(result["checks"], [])
        self.assertEqual(result["occurrences"], [])
        self.assertIn("owner_source_missing", result["unresolved"])
        self.assertEqual(len(result["requirements"]), 7)
        self.assertTrue(all(r["status"] == "unresolved" for r in result["requirements"]))

    def test_closed_envelope_disclosure_paths_file_set_and_external_hash(self):
        source = OwnerFixture().source(); row, files = bundle("owner", source); ref = reference(source.a)
        raw = envelope(ref, [row]); value = loads(raw, maximum=2 * 1024 * 1024)
        for key, item in (("complete", True), ("disclosure", "restricted")):
            changed = dumps(value | {key: item})
            with self.subTest(key=key), self.assertRaises(MuseumError): native.admit(changed, keccak256(changed), files, ref)
        with self.assertRaisesRegex(MuseumError, "external commitment"): native.admit(raw, "0x" + "98" * 32, files, ref)
        with self.assertRaises(MuseumError): native.admit(raw, keccak256(raw), files | {"extra": b"unused"}, ref)
        with self.assertRaises(MuseumError): native.admit(raw, keccak256(raw), {"../bad": b"unsafe"}, ref)
        with self.assertRaises(MuseumError): admit(ref, [dict(row, kind="operator_complete")], files)

    def test_roster_unsupported_and_missing_scopes_are_not_dropped(self):
        # Scope planner unit vector; not an admitted source or native positive.
        a = OwnerFixture().source().a; state = reference(a)["sourceState"]
        hosts = [{"host": a["host"], "kind": "owner", "core": None, "resolution": "unsupported_registered_version",
                  "scopes": ["71"], "supported": False, "runtimeMatches": True, "status": "DEPRECATED"},
                 {"host": a["schemas"], "kind": "independent", "core": a["core"], "resolution": "verified_within_current_registry",
                  "scopes": ["0", "1"], "supported": True, "runtimeMatches": True, "status": "INCIDENT_REVOKED"}]
        roster = {"kind": "hosts", "anchor": {"core": a["core"], "tokenId": "71"}, "snapshot": {"hosts": hosts},
                  "provenance": "trusted_rpc", "input": {"id": "roster"}}
        coverage, _ = native._coverage([roster], state)
        self.assertEqual([r["status"] for r in coverage], ["unsupported_host", "missing_source", "missing_source"])
        self.assertEqual([r["scopeKey"] for r in coverage], ["71", "0", "1"])

    def test_profile_bytes_are_deterministic(self):
        native.definitions(Path(__file__).resolve().parents[2] / "schemas/museum/object-dossier", check=True)


if __name__ == "__main__": unittest.main()
