"""Transport-double Registry bridge checks; no native, RPC or EVM acceptance."""
import argparse
from copy import deepcopy
import hashlib
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

from . import current_owner_registry_capture as bridge
from . import genesis_registry_coverage_v1 as coverage
from .canonical import MuseumError, dumps, keccak256, loads
from .public_history_rpc import PublicRecordingReader, PublicRpcTransport
from .test_genesis_registry_source_v1 import GenesisRegistryFixture, Transport, H, A


class RegistryBridgeTests(unittest.TestCase):
    def setUp(self):
        self.f = GenesisRegistryFixture()
        self.f.call(self.f.core, "tokenCollectionIdentity(uint256)",
            ("bool", "uint256", "uint256", "bool"), (True, 71, 4, False), ("uint256",), (19,))
        self.common = {key: self.f.anchor[key] for key in bridge.COMMON}
        self.artifacts = {str(i): {"address": row["address"], "runtimeHash": row["runtimeHash"]}
            for i, row in enumerate(self.f.anchor["codePins"])}
        self.raw_bridge = b"independently admitted runtime/source correspondence; deployment build is separate"
        self.bridge_hash = keccak256(self.raw_bridge)

    def project(self, common=None, artifacts=None):
        transport = Transport(self.f)
        reader = PublicRecordingReader(transport, self.common["blockHash"])
        result = bridge.discover_anchor(common or self.common, self.artifacts if artifacts is None else artifacts,
            reader, self.bridge_hash, 19)
        return result, reader, transport

    def test_exact_closed_projection_keeps_original_admission_registry_and_same_block(self):
        (raw, collection), reader, transport = self.project()
        actual = loads(raw)
        self.assertEqual(set(actual), set(bridge.COMMON) | {"profile", "coreRuntimeHash", "codePins", "runtimeAdmission"})
        self.assertEqual({key: actual[key] for key in bridge.COMMON}, self.common)
        self.assertEqual(collection, "71")
        self.assertEqual(actual["profile"], bridge.PROFILE)
        self.assertNotIn("collectionId", actual)
        self.assertNotIn("tokenId", actual)
        self.assertEqual(actual["runtimeAdmission"], {"sourceCommit": bridge.SOURCE_REVISION,
            "kind": "externally_admitted_runtime", "artifactHash": self.bridge_hash})
        self.assertEqual({row["address"] for row in actual["codePins"]},
            {self.f.core, self.f.metadata, self.f.module_registry, self.f.schemas, self.f.store, self.f.governance})
        self.assertEqual(len(transport.calls), 5)
        self.assertTrue(all(method == "eth_call" and params[1] == self.f.block_ref
            for method, params in transport.calls))
        # No latest block/current ModuleRegistry getter or observed-code self-admission occurs.
        self.assertEqual(len(loads(reader.transcript())["calls"]), 5)

    def test_missing_duplicate_or_wrong_original_runtime_refuses(self):
        artifacts = deepcopy(self.artifacts)
        del artifacts["2"]  # Original pointer admission registry, not Core's current registry.
        artifacts["replacement"] = {"address": A(90), "runtimeHash": H("new module registry")}
        with self.assertRaisesRegex(MuseumError, "one original deployment runtime"):
            self.project(artifacts=artifacts)
        artifacts = deepcopy(self.artifacts); artifacts["duplicate"] = artifacts["1"]
        with self.assertRaisesRegex(MuseumError, "one original deployment runtime"):
            self.project(artifacts=artifacts)
        artifacts = deepcopy(self.artifacts); artifacts["1"]["runtimeHash"] = H("foreign code")
        with self.assertRaisesRegex(MuseumError, "pointer/deployment runtime"):
            self.project(artifacts=artifacts)

    def test_changed_block_nonlocal_source_or_absent_token_refuses(self):
        for key, value, message in (("blockHash", H("later block"), "discovery block"),
                ("chainId", "1", "local chain"), ("environment", "public_chain", "local chain")):
            with self.subTest(key=key), self.assertRaisesRegex(MuseumError, message):
                self.project(common=self.common | {key: value})
        self.f.call(self.f.core, "tokenCollectionIdentity(uint256)",
            ("bool", "uint256", "uint256", "bool"), (False, 0, 0, False), ("uint256",), (19,))
        with self.assertRaisesRegex(MuseumError, "token identity absent"):
            self.project()

    def test_partial_fixed_plan_still_replays_all_fifty_one_true_outcomes(self):
        self.f.install_document(20, exists=False)
        self.f.install_document(21, status=1)
        self.f.install_document(22, content=b"original conflicting bytes")
        (raw, _), _, _ = self.project()
        transport = PublicRpcTransport("http://127.0.0.1:1")
        with patch.object(PublicRpcTransport, "request", side_effect=self.f.request), \
                patch("socket.socket", side_effect=AssertionError("no actual network")):
            source = bridge.GenesisRegistrySource(raw, transport, plan_files=dict(self.f.plan.files),
                plan_hash=self.f.plan.manifest_hash, provenance="trusted_rpc")
            snapshot = source.snapshot(); transcript = source.transcript()
        result = coverage.assemble(dict(self.f.plan.files), self.f.plan.manifest_hash,
            raw, keccak256(raw), transcript, keccak256(transcript), provenance="trusted_rpc", disclosure="public")
        self.assertEqual(dict(result.files)["source/snapshot.json"], snapshot)
        self.assertEqual(len(loads(snapshot, maximum=16 * 1024 * 1024)["documents"]), 51)
        self.assertEqual(result.report["nativeSource"]["coverage"]["outcomes"],
            {"absent": "1", "active": "48", "deprecated": "1", "archived": "0", "conflict": "1"})
        self.assertFalse(result.report["nativeSource"]["coverage"]["allPlanDocumentsCurrentlyEligible"])
        self.assertEqual(coverage.verify(dict(result.files), result.manifest_hash), result)

    def capture_inputs(self):
        manifest_raw = b"native-manifest-double"
        evidence = dumps({"artifacts": self.artifacts,
            "nativeInputManifestSha256": hashlib.sha256(manifest_raw).hexdigest()})
        common = self.common | {"deploymentEvidenceHash": keccak256(evidence)}
        account_raw = dumps({**common, "profile": "verified-account-double"})
        owner_anchor = {**common, "records": [{"recordHash": H("owner record"), "tokenId": "19"}]}
        owner_raw = dumps(owner_anchor)
        empty_transcript = dumps({"version": 1, "calls": []})
        snapshot = b"concretely-verified-owner-double"
        owner_inputs = {"anchor.json": owner_raw, "transcript.json": empty_transcript,
            "deployment-evidence.json": evidence}
        pins = {"anchorHash": keccak256(owner_raw), "transcriptHash": keccak256(empty_transcript),
            "sourceHash": keccak256(snapshot)}
        account_files = {"inputs/anchor.json": account_raw, "inputs/transcript.json": empty_transcript,
            "inputs/deployment-evidence.json": evidence}
        fixture = SimpleNamespace(registry_bridge=(self.raw_bridge, self.bridge_hash),
            endpoint="http://127.0.0.1:1", manifest_raw=manifest_raw, token_id=19)
        owner = SimpleNamespace(a=owner_anchor, snapshot=Mock(return_value=snapshot))
        return fixture, (owner_inputs, pins, {}, {}, {}), account_files, owner

    def test_orchestration_uses_verified_sources_and_publishes_separate_original_coverage(self):
        fixture, captured, account_files, owner = self.capture_inputs()
        account_hash = H("original recorded account")
        with tempfile.TemporaryDirectory() as tmp, \
                patch.object(bridge, "verify_recorded_package", return_value=SimpleNamespace(files=tuple(account_files.items()))) as verify_account, \
                patch.object(bridge, "OwnerRecordSource", return_value=owner) as verify_owner, \
                patch.object(PublicRpcTransport, "request", side_effect=self.f.request), \
                patch("socket.socket", side_effect=AssertionError("no actual network")):
            output = Path(tmp)
            sentinel = output / "owner-anchor.json"; sentinel.write_bytes(captured[0]["anchor.json"])
            report = bridge.capture_registry(fixture, output, account_hash, captured)
            verify_account.assert_called_once_with(output / "package", account_hash)
            self.assertEqual(verify_owner.call_count, 1); owner.snapshot.assert_called_once_with()
            self.assertEqual(sentinel.read_bytes(), captured[0]["anchor.json"])
            self.assertEqual((output / "registry-runtime-bridge.bin").read_bytes(), self.raw_bridge)
            self.assertEqual(report["readerSourceRevision"], bridge.SOURCE_REVISION)
            self.assertEqual(report["sourceJoin"]["sourceState"]["collectionId"], "71")
            self.assertEqual(report["sourceJoin"]["sourceState"]["tokenId"], "19")
            self.assertEqual(len(report["sourceJoin"]["sources"]), 4)
            self.assertFalse(report["runtimeBridgeSemanticsVerified"])
            self.assertFalse(report["registrationPerformed"])
            self.assertEqual(report["coverage"]["outcomes"]["active"], "51")
            self.assertEqual(loads((output / "registry-capture.json").read_bytes()), report)

    def test_owner_account_or_native_build_mismatch_fails_before_reads_or_output(self):
        for mutation in ("common", "snapshot", "manifest", "token"):
            fixture, captured, account_files, owner = self.capture_inputs()
            if mutation == "common": owner.a["stateRoot"] = H("different state")
            elif mutation == "snapshot": owner.snapshot.return_value = b"different owner source"
            elif mutation == "manifest": fixture.manifest_raw = b"different build"
            else: fixture.token_id = 20
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as tmp, \
                    patch.object(bridge, "verify_recorded_package", return_value=SimpleNamespace(files=tuple(account_files.items()))), \
                    patch.object(bridge, "OwnerRecordSource", return_value=owner), \
                    patch.object(PublicRpcTransport, "request", side_effect=AssertionError("no reads")):
                with self.assertRaises(MuseumError):
                    bridge.capture_registry(fixture, Path(tmp), H("account"), captured)
                self.assertEqual(list(Path(tmp).iterdir()), [])


class RegistryBridgeCliTests(unittest.TestCase):
    def test_opt_in_requires_both_external_inputs_and_exact_pin_before_process(self):
        parser = argparse.ArgumentParser(); bridge.configure_parser(parser)
        args = parser.parse_args([]); bridge.prepare_arguments(args)
        self.assertIsNone(args.registry_bridge)
        fixture = SimpleNamespace(); bridge.configure_fixture(fixture, args)
        self.assertIsNone(fixture.registry_bridge)
        for values in (["--registry-runtime-bridge", "missing"],
                ["--registry-runtime-bridge-hash", H("external")]):
            with self.assertRaisesRegex(MuseumError, "requires file and external hash"):
                bridge.prepare_arguments(parser.parse_args(values))
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "runtime-source-admission.json"; raw = b"original externally reviewed bytes"
            path.write_bytes(raw)
            args = parser.parse_args(["--registry-runtime-bridge", str(path),
                "--registry-runtime-bridge-hash", keccak256(raw)])
            bridge.prepare_arguments(args); self.assertEqual(args.registry_bridge, (raw, keccak256(raw)))
            args.registry_runtime_bridge_hash = H("wrong")
            with self.assertRaisesRegex(MuseumError, "commitment differs"):
                bridge.prepare_arguments(args)

    def test_bridge_cannot_be_empty_oversized_or_have_zero_admission(self):
        for raw, pin in ((b"", H("empty")), (b"x" * (bridge.MAX_BRIDGE + 1), H("large")),
                (b"x", "0x" + "00" * 32)):
            with self.assertRaises(MuseumError): bridge.bridge_bytes(raw, pin)


if __name__ == "__main__":
    unittest.main()
