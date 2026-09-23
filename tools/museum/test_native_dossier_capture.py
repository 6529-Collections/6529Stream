"""Capture orchestration controls using synthetic responses, never a native run.

Preflight uses real reader constructors and joins. One concrete MetadataV1
reader is exercised through a patched RpcTransport; its trusted_rpc label is
only a caller declaration under test, not evidence that these bytes came from
a chain. Wrapper tests explicitly stub the verified base and V2 assembler.
"""
from contextlib import ExitStack
from copy import deepcopy
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads
from .chain_rpc import METHODS, ReplayTransport, RpcTransport
from . import native_dossier_capture as runner
from . import object_dossier_native as native
from . import owner_catalog_source, independent_catalog_source, ownership_source, dossier_hosts_source
from .test_metadata_catalog_source import Fixture, Transport, A, H
from .test_object_dossier_native import reference


NATIVE_INPUT_SHA256 = "34" * 32
SOURCE_REVISION = "12" * 20  # Synthetic provenance string, not an accepted revision.


def _retarget(anchor, host):
    result = deepcopy(anchor)
    original = result["host"]
    result["host"] = host
    for pin in result["codePins"]:
        if pin["address"] == original:
            pin["address"] = host
            pin["runtimeHash"] = H("synthetic runtime " + host)
    return result


def recipe():
    """Constructor-valid, synthetic six-source plan; no claimed live deployment."""
    fixture = Fixture()
    metadata = deepcopy(fixture.anchor)
    ref = reference(metadata)
    common = {key: metadata[key] for key in ("chainId", "blockHash", "blockNumber", "timestamp", "stateRoot",
        "environment", "deploymentEvidenceHash", "core")}
    core_hash = next(pin["runtimeHash"] for pin in metadata["codePins"] if pin["address"] == metadata["core"])
    core_anchor = common | {"coreRuntimeHash": core_hash, "tokenId": "71", "collectionId": "7"}
    catalog_anchor = {key: deepcopy(value) for key, value in metadata.items()
        if key not in ("artistRegistry", "collectionId")}
    owner = _retarget(catalog_anchor, A(11)) | {"profile": owner_catalog_source.PROFILE, "tokenId": "71"}
    independent = _retarget(catalog_anchor, A(12)) | {"profile": independent_catalog_source.PROFILE}
    anchors = [
        ("hosts", "hosts", core_anchor | {"profile": dossier_hosts_source.PROFILE}),
        ("independent_collection", "independent", independent | {"scopeKey": "7"}),
        ("independent_deployment", "independent", independent | {"scopeKey": "0"}),
        ("metadata", "metadata", metadata),
        ("owner", "owner", owner),
        ("ownership", "ownership", core_anchor | {"profile": ownership_source.PROFILE}),
    ]
    plan = {"profile": runner.PLAN, "version": "1", "disclosure": "public", "baseManifestHash": H("stub base"),
        "sourceRevision": SOURCE_REVISION, "nativeInputManifestSha256": NATIVE_INPUT_SHA256,
        "sources": [{"id": identifier, "kind": kind, "anchor": deepcopy(anchor)} for identifier, kind, anchor in anchors]}
    return fixture, ref, plan


def _row(plan, identifier):
    return next(row for row in plan["sources"] if row["id"] == identifier)


def _sort(plan):
    plan["sources"].sort(key=lambda row: row["id"])


class PlanPreflightTests(unittest.TestCase):
    def assert_rejected_before_rpc(self, plan, *, raw=None, pin=None, native_pin=NATIVE_INPUT_SHA256, pattern=None):
        _, ref, _ = recipe()
        raw = dumps(plan) if raw is None else raw
        pin = keccak256(raw) if pin is None else pin
        transport = RpcTransport("https://capture-fixture.invalid/rpc")
        # The V1 base is outside this unit boundary; all source constructors and
        # native joins remain real, as does the capture ordering being checked.
        with patch.object(runner, "_reference", return_value=(ref, native_pin)), \
                patch.object(RpcTransport, "request", side_effect=AssertionError("preflight attempted RPC")) as rpc, \
                patch.object(runner.assembly, "assemble", side_effect=AssertionError("preflight reached assembly")) as assemble, \
                patch("socket.socket", side_effect=AssertionError("preflight attempted network")):
            with self.assertRaisesRegex(MuseumError, pattern or ".+"):
                runner.capture(raw, pin, {}, transport)
        rpc.assert_not_called()
        assemble.assert_not_called()

    def test_six_source_recipe_validates_real_constructors_without_rpc(self):
        _, ref, plan = recipe()
        raw = dumps(plan)
        with patch.object(RpcTransport, "request", side_effect=AssertionError("preflight RPC")), \
                patch.object(ReplayTransport, "request", side_effect=AssertionError("preflight replay")), \
                patch("socket.socket", side_effect=AssertionError("preflight network")):
            self.assertEqual(runner._read_plan(raw, keccak256(raw)), plan)
            runner._preflight(plan, ref, NATIVE_INPUT_SHA256)
        self.assertEqual({row["kind"] for row in plan["sources"]}, set(native.KINDS))

    def test_wrong_external_pin_and_noncanonical_bytes_reject_before_rpc(self):
        _, _, plan = recipe()
        self.assert_rejected_before_rpc(plan, pin=H("wrong"), pattern="external commitment")
        self.assert_rejected_before_rpc(plan, raw=b" " + dumps(plan), pattern="canonical")
        self.assert_rejected_before_rpc(plan, raw=b"{}", pattern="closed shape")

    def test_closed_plan_source_and_anchor_shapes_reject_endpoints(self):
        for location in ("plan", "source", "anchor"):
            for field, value in (("endpoint", "https://private-fixture.invalid/secret"), ("complete", True)):
                _, _, plan = recipe()
                target = plan if location == "plan" else plan["sources"][0] if location == "source" else plan["sources"][0]["anchor"]
                target[field] = value
                with self.subTest(location=location, field=field): self.assert_rejected_before_rpc(plan)

    def test_public_disclosure_versions_and_provenance_pins_are_strict(self):
        for key, value in (("disclosure", "restricted"), ("disclosure", None), ("version", 1), ("version", True),
                ("profile", "unknown"), ("sourceRevision", "AB" * 20), ("sourceRevision", "12" * 19),
                ("nativeInputManifestSha256", "0x" + NATIVE_INPUT_SHA256), ("nativeInputManifestSha256", None)):
            _, _, plan = recipe(); plan[key] = value
            with self.subTest(key=key, value=value): self.assert_rejected_before_rpc(plan)

    def test_source_ids_kinds_and_count_are_bounded(self):
        for change in ("few", "many", "duplicate-id", "unsorted", "path-id", "unknown-kind", "null-anchor"):
            _, _, plan = recipe()
            if change == "few": plan["sources"].pop()
            elif change == "many": plan["sources"] *= native.MAX_SOURCES
            elif change == "duplicate-id": plan["sources"][1]["id"] = plan["sources"][0]["id"]
            elif change == "unsorted": plan["sources"].reverse()
            elif change == "path-id": plan["sources"][0]["id"] = "../escape"
            elif change == "unknown-kind": plan["sources"][0]["kind"] = "operator_complete"
            else: plan["sources"][0]["anchor"] = None
            with self.subTest(change=change): self.assert_rejected_before_rpc(plan)

    def test_each_reader_kind_is_required_even_when_six_sources_remain(self):
        _, _, plan = recipe()
        replacement = deepcopy(_row(plan, "owner"))
        replacement.update(id="extra_owner", anchor=_retarget(replacement["anchor"], A(21)))
        plan["sources"] = [row for row in plan["sources"] if row["kind"] != "hosts"] + [replacement]
        _sort(plan)
        self.assert_rejected_before_rpc(plan, pattern="missing required reader kind")

    def test_every_independent_host_requires_both_deployment_and_collection_scope(self):
        for change in ("missing-zero", "missing-collection", "second-unpaired-host"):
            _, _, plan = recipe()
            if change == "second-unpaired-host":
                extra = deepcopy(_row(plan, "independent_deployment"))
                extra.update(id="independent_second_zero", anchor=_retarget(extra["anchor"], A(22)))
                plan["sources"].append(extra)
            else:
                missing = "independent_deployment" if change == "missing-zero" else "independent_collection"
                plan["sources"] = [row for row in plan["sources"] if row["id"] != missing]
                extra = deepcopy(_row(plan, "owner"))
                extra.update(id="extra_owner", anchor=_retarget(extra["anchor"], A(21)))
                plan["sources"].append(extra)
            _sort(plan)
            with self.subTest(change=change): self.assert_rejected_before_rpc(plan, pattern="both independent scopes")
        _, ref, plan = recipe()
        for scope in ("0", "7"):
            extra = deepcopy(_row(plan, "independent_collection"))
            extra.update(id="independent_second_" + scope, anchor=_retarget(extra["anchor"], A(22)) | {"scopeKey": scope})
            plan["sources"].append(extra)
        _sort(plan)
        runner._preflight(plan, ref, NATIVE_INPUT_SHA256)

    def test_duplicate_logical_scope_cannot_be_hidden_by_another_id(self):
        for kind in native.KINDS:
            _, _, plan = recipe()
            duplicate = deepcopy(next(row for row in plan["sources"] if row["kind"] == kind))
            duplicate["id"] = "zz_duplicate"
            plan["sources"].append(duplicate); _sort(plan)
            with self.subTest(kind=kind): self.assert_rejected_before_rpc(plan, pattern="duplicate logical source")

    def test_all_common_block_deployment_and_core_identity_joins_precede_rpc(self):
        for key, value in (("blockHash", H("other-block")), ("blockNumber", "10"), ("timestamp", "113"),
                ("stateRoot", H("other-state")), ("deploymentEvidenceHash", H("other-deployment")),
                ("environment", "public_chain"), ("chainId", "1")):
            _, _, plan = recipe(); _row(plan, "metadata")["anchor"][key] = value
            with self.subTest(key=key): self.assert_rejected_before_rpc(plan, pattern="native common")
        for identifier, field, value in (("owner", "tokenId", "72"), ("ownership", "collectionId", "8"),
                ("hosts", "tokenId", "72"), ("metadata", "collectionId", "8"),
                ("independent_collection", "scopeKey", "8")):
            _, _, plan = recipe(); _row(plan, identifier)["anchor"][field] = value
            with self.subTest(identifier=identifier): self.assert_rejected_before_rpc(plan, pattern="native")

    def test_core_and_shared_dependency_pins_cannot_conflict(self):
        for change in ("core", "schema", "missing", "core-reader", "between-sources"):
            _, _, plan = recipe(); anchor = _row(plan, "metadata")["anchor"]
            if change in ("core", "schema"):
                address = anchor["core" if change == "core" else "schemas"]
                next(pin for pin in anchor["codePins"] if pin["address"] == address)["runtimeHash"] = H("wrong")
            elif change == "missing": anchor["codePins"].pop()
            elif change == "core-reader": _row(plan, "ownership")["anchor"]["coreRuntimeHash"] = H("wrong")
            else:
                for identifier, digest in (("independent_collection", H("one")), ("independent_deployment", H("two"))):
                    _row(plan, identifier)["anchor"]["codePins"].append({"address": A(99), "runtimeHash": digest})
            with self.subTest(change=change): self.assert_rejected_before_rpc(plan)

    def test_retained_native_input_manifest_must_match_before_rpc(self):
        _, _, plan = recipe()
        self.assert_rejected_before_rpc(plan, native_pin="56" * 32, pattern="original native-input manifest differs")

    def test_complete_history_block_bound_is_checked_before_rpc(self):
        for block in (runner.MAX_BLOCKS - 1, runner.MAX_BLOCKS):
            _, ref, plan = recipe()
            ref["sourceState"]["blockNumber"] = str(block)
            for row in plan["sources"]:
                row["anchor"]["blockNumber"] = str(block)
            raw = dumps(plan)
            with patch.object(RpcTransport, "request", side_effect=AssertionError("bounded preflight RPC")), \
                    patch.object(ReplayTransport, "request", side_effect=AssertionError("bounded preflight replay")), \
                    patch("socket.socket", side_effect=AssertionError("bounded preflight network")):
                if block == runner.MAX_BLOCKS - 1:
                    runner._preflight(plan, ref, NATIVE_INPUT_SHA256)
                else:
                    with patch.object(runner, "_reference", return_value=(ref, NATIVE_INPUT_SHA256)), \
                            self.assertRaisesRegex(MuseumError, "complete-history bound"):
                        runner.capture(raw, keccak256(raw), {}, RpcTransport("https://capture-fixture.invalid"))


class ConcreteSyntheticReaderTests(unittest.TestCase):
    def test_real_metadata_reader_capture_and_replay_with_synthetic_rpc_responses(self):
        fixture = Fixture(); original = fixture.source(); synthetic_raw = original.snapshot()
        self.assertEqual(loads(synthetic_raw, maximum=runner.MAX_BYTES)["mode"], "synthetic_fixture")
        ref = reference(fixture.anchor)
        plan = {"sources": [{"id": "metadata_fixture", "kind": "metadata", "anchor": fixture.anchor}]}
        endpoint = "https://synthetic-token@capture-fixture.invalid/rpc"
        transport = RpcTransport(endpoint)
        fixture_transport = Transport(fixture.responses)
        with patch.object(RpcTransport, "request", side_effect=fixture_transport.request) as requests, \
                patch("socket.socket", side_effect=AssertionError("synthetic RPC attempted network")):
            raw, digest, files = runner._capture_sources(plan, ref, transport)
        self.assertGreater(requests.call_count, 20)
        envelope = loads(raw, maximum=runner.MAX_MANIFEST, canonical=True)
        self.assertEqual(digest, keccak256(raw))
        self.assertEqual(envelope["sourceState"], ref["sourceState"])
        row, = envelope["sources"]
        self.assertEqual(row["provenance"], "trusted_rpc")
        for label in ("anchor", "snapshot", "transcript"):
            self.assertEqual(row[label + "Hash"], keccak256(files[row[label + "Path"]]))
        captured = loads(files[row["snapshotPath"]], maximum=runner.MAX_BYTES, canonical=True)
        self.assertEqual(captured["mode"], "caller_admitted_rpc_metadata_catalogue")
        self.assertTrue(captured["provenanceDeclaredByCaller"])
        self.assertFalse(captured["claims"]["actualChainAcceptance"])
        # The original fixture provenance is retained in this independent value.
        # Only the expressly exercised caller declaration changes in the output.
        expected = loads(synthetic_raw, maximum=runner.MAX_BYTES, canonical=True)
        expected["mode"] = "caller_admitted_rpc_metadata_catalogue"
        self.assertEqual(captured, expected)
        self.assertEqual(files[row["transcriptPath"]], original.transcript())
        for request in loads(files[row["transcriptPath"]], maximum=runner.MAX_BYTES)["calls"]:
            self.assertIn(request["method"], METHODS)
            if request["method"] in ("eth_call", "eth_getCode"):
                self.assertEqual(request["params"][1], {"blockHash": fixture.anchor["blockHash"], "requireCanonical": True})
        self.assertNotIn(endpoint.encode(), raw + b"".join(files.values()))
        with patch.object(RpcTransport, "request", side_effect=AssertionError("offline replay used RPC")), \
                patch("socket.socket", side_effect=AssertionError("offline replay used network")):
            joined = loads(native.admit(raw, digest, files, ref), maximum=runner.MAX_BYTES, canonical=True)
        self.assertEqual(len(joined["occurrences"]), len(fixture.rows))
        self.assertFalse(joined["claims"]["actualChainAcceptance"])
        self.assertFalse(joined["claims"]["fullObjectDossierConformance"])

    def test_concrete_reader_rejects_corrupted_rpc_bytes(self):
        fixture = Fixture()
        fixture.put("eth_getCode", [A(30), fixture.block_ref], "0x00626164")
        plan = {"sources": [{"id": "metadata_fixture", "kind": "metadata", "anchor": fixture.anchor}]}
        with patch.object(RpcTransport, "request", side_effect=Transport(fixture.responses).request), \
                patch("socket.socket", side_effect=AssertionError("synthetic RPC attempted network")), \
                self.assertRaisesRegex(MuseumError, "SSTORE2"):
            runner._capture_sources(plan, reference(fixture.anchor), RpcTransport("https://capture-fixture.invalid"))

    def test_capture_transport_requires_actual_rpc_class(self):
        _, ref, plan = recipe(); empty = dumps({"version": 1, "calls": []})
        for transport in (Transport({}), ReplayTransport(empty, keccak256(empty))):
            with self.subTest(transport=type(transport).__name__), self.assertRaisesRegex(MuseumError, "read-only RPC transport"):
                runner._capture_sources(plan, ref, transport)


class StubbedAssemblyBoundaryTests(unittest.TestCase):
    """Plan/result wrapper tests with explicitly inert base and assembler doubles."""
    def setUp(self):
        _, self.ref, self.plan = recipe()
        self.raw = dumps(self.plan); self.pin = keccak256(self.raw)
        self.base_files = {"unchanged.bin": b"synthetic stub base"}
        source_files, rows = {}, []
        for item in self.plan["sources"]:
            row = {"id": item["id"], "kind": item["kind"], "provenance": "trusted_rpc"}
            for label, content in (("anchor", dumps(item["anchor"])), ("snapshot", b"synthetic stub snapshot"),
                                   ("transcript", b"synthetic stub transcript")):
                path = item["id"] + "/" + label + ".json"; source_files[path] = content
                row[label + "Path"] = path; row[label + "Hash"] = keccak256(content)
            rows.append(row)
        envelope = dumps({"profile": native.PROFILE, "version": "1", "disclosure": "public",
            "sourceState": self.ref["sourceState"], "sources": rows})
        self.inputs = (envelope, keccak256(envelope), source_files)
        manifest = dumps({"nativeInputsHash": self.inputs[1], "fixture": "inert assembler boundary"})
        files = {"base/" + p: b for p, b in self.base_files.items()}
        files.update({"native/data/" + p: b for p, b in source_files.items()})
        files.update({"native/inputs.json": envelope, "manifest.json": manifest})
        report = {"scopeCoverage": [{"status": "verified_within_registered_roster"}],
                  "claims": {"actualChainAcceptance": False, "fullObjectDossierConformance": False}}
        self.result = runner.base.Assembly(tuple(sorted(files.items())), manifest, report)

    def context(self):
        stack = ExitStack()
        stack.enter_context(patch.object(runner, "_reference", return_value=(self.ref, NATIVE_INPUT_SHA256)))
        stack.enter_context(patch.object(runner, "_capture_sources", return_value=self.inputs))
        def assemble(base_files, expected_hash, inputs):
            self.assertEqual(base_files, self.base_files)
            self.assertEqual(expected_hash, self.plan["baseManifestHash"])
            self.assertEqual(inputs, self.inputs)
            return self.result
        def verify(files, expected_hash):
            if files != dict(self.result.files) or expected_hash != self.result.manifest_hash:
                raise MuseumError("stub assembler original bytes/pin differ")
            return self.result
        stack.enter_context(patch.object(runner.assembly, "assemble", side_effect=assemble))
        stack.enter_context(patch.object(runner.assembly, "verify", side_effect=verify))
        stack.enter_context(patch.object(RpcTransport, "request", side_effect=AssertionError("stub boundary RPC")))
        stack.enter_context(patch("socket.socket", side_effect=AssertionError("stub boundary network")))
        return stack

    def output(self):
        return runner.capture(self.raw, self.pin, self.base_files, RpcTransport("https://capture-fixture.invalid"))

    def test_capture_and_verify_reconstruct_exact_wrapper_and_retain_all_bytes(self):
        with self.context():
            output = self.output()
            value = runner.verify(output, keccak256(output["result.json"]))
        self.assertEqual(output["plan.json"], self.raw)
        self.assertEqual({p[9:]: b for p, b in output.items() if p.startswith("assembly/")}, dict(self.result.files))
        self.assertEqual(value["sourceCount"], "6")
        self.assertEqual(value["planHash"], self.pin)
        self.assertEqual(value["sourceRevision"], SOURCE_REVISION)
        self.assertEqual(value["nativeInputManifestSha256"], NATIVE_INPUT_SHA256)
        for claim in ("sourceRevisionAuthenticated", "actualNativeCaptureAcceptance", "fullObjectDossierConformance", "globalApplicableHostsComplete", "consensusProof"):
            self.assertFalse(value["claims"][claim])

    def test_external_result_pin_closed_shape_and_outer_inventory_reject(self):
        with self.context(): output = self.output()
        with patch.object(runner.assembly, "verify", side_effect=AssertionError("must reject before assembler")):
            with self.assertRaisesRegex(MuseumError, "external commitment"):
                runner.verify(output, H("wrong"))
            changed = deepcopy(output); result = loads(changed["result.json"]); result["endpoint"] = "private"
            changed["result.json"] = dumps(result)
            with self.assertRaisesRegex(MuseumError, "closed shape"):
                runner.verify(changed, keccak256(changed["result.json"]))
            for changed in (output | {"extra.bin": b"unexpected"}, {k: v for k, v in output.items() if k != "plan.json"}):
                with self.assertRaisesRegex(MuseumError, "inventory differs"):
                    runner.verify(changed, keccak256(changed["result.json"]))

    def test_rehashed_claims_counts_profiles_and_provenance_cannot_change_result(self):
        with self.context():
            output = self.output()
            for field, value in (("sourceCount", "7"), ("profile", "accepted"), ("version", "2"),
                    ("sourceRevision", "ab" * 20), ("nativeInputManifestSha256", "56" * 32),
                    ("nativeInputsHash", H("different")), ("qualification", "fully verified")):
                changed = deepcopy(output); result = loads(changed["result.json"]); result[field] = value
                changed["result.json"] = dumps(result)
                with self.subTest(field=field), self.assertRaisesRegex(MuseumError, "reconstruction differs"):
                    runner.verify(changed, keccak256(changed["result.json"]))
            for claim in ("actualNativeCaptureAcceptance", "sourceRevisionAuthenticated", "fullObjectDossierConformance"):
                changed = deepcopy(output); result = loads(changed["result.json"]); result["claims"][claim] = True
                changed["result.json"] = dumps(result)
                with self.subTest(claim=claim), self.assertRaisesRegex(MuseumError, "reconstruction differs"):
                    runner.verify(changed, keccak256(changed["result.json"]))

    def test_rehashed_plan_and_assembly_changes_do_not_survive_wrapper_replay(self):
        with self.context():
            output = self.output()
            changed = dict(output); changed["assembly/base/unchanged.bin"] = b"edited"
            with self.assertRaisesRegex(MuseumError, "original bytes/pin"):
                runner.verify(changed, keccak256(changed["result.json"]))
            changed = dict(output); plan = deepcopy(self.plan); plan["sources"][0]["id"] = "host_changed"
            changed["plan.json"] = dumps(plan)
            result = loads(changed["result.json"]); result["planHash"] = keccak256(changed["plan.json"])
            changed["result.json"] = dumps(result)
            with self.assertRaisesRegex(MuseumError, "source plan/provenance differs"):
                runner.verify(changed, keccak256(changed["result.json"]))

    def test_missing_supported_scope_and_synthetic_only_assembly_refuse(self):
        for status in ("missing_source", "synthetic_only"):
            changed = runner.base.Assembly(self.result.files, self.result.manifest, {"scopeCoverage": [{"status": status}]})
            with self.subTest(status=status), self.assertRaisesRegex(MuseumError, "omits a supported"):
                runner._complete_plan_sources(self.plan, changed)
        files = dict(self.result.files); envelope = loads(files["native/inputs.json"])
        envelope["sources"][0]["provenance"] = "synthetic_fixture"
        files["native/inputs.json"] = dumps(envelope)
        changed = runner.base.Assembly(tuple(files.items()), self.result.manifest, self.result.report)
        with self.assertRaisesRegex(MuseumError, "source plan/provenance differs"):
            runner._complete_plan_sources(self.plan, changed)


class CliBoundaryTests(unittest.TestCase):
    def test_check_plan_is_offline_and_does_not_require_rpc_configuration(self):
        _, ref, plan = recipe(); raw = dumps(plan)
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "plan.json"; path.write_bytes(raw)
            argv = ["native-capture", "check-plan", "--plan", str(path), "--plan-hash", keccak256(raw), "--base", temporary]
            stdout = io.StringIO()
            with patch("sys.argv", argv), patch.object(runner, "read_tree", return_value={}), \
                    patch.object(runner, "_reference", return_value=(ref, NATIVE_INPUT_SHA256)), \
                    patch.object(RpcTransport, "request", side_effect=AssertionError("check-plan RPC")), \
                    patch("socket.socket", side_effect=AssertionError("check-plan network")), patch("sys.stdout", stdout):
                runner.main()
            result = loads(stdout.getvalue().strip().encode(), canonical=True)
            self.assertEqual(result, {"planHash": keccak256(raw), "sourceCount": "6", "offlinePlanValid": True, "rpcAvailabilityChecked": False})

    def test_plan_file_must_be_regular_and_bounded(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "plan.json"; path.write_bytes(b"123")
            with patch.object(runner, "MAX_MANIFEST", 2), self.assertRaisesRegex(MuseumError, "file bound"):
                runner._bounded_read(path)
            with patch.object(Path, "is_symlink", return_value=True), self.assertRaisesRegex(MuseumError, "regular file"):
                runner._bounded_read(path)
            with self.assertRaisesRegex(MuseumError, "regular file"):
                runner._bounded_read(Path(temporary))


if __name__ == "__main__":
    unittest.main()
