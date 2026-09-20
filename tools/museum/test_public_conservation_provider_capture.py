"""Concrete synthetic-source replay; no live chain or native execution."""
from contextlib import redirect_stdout
from copy import deepcopy
import http.client
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import traceback
import unittest
from unittest.mock import patch

from . import public_conservation_provider_capture as capture
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .public_history_rpc import PublicRpcTransport
from .test_public_conservation_provider_source import PublicConservationProviderFixture


class PublicConservationProviderCaptureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = PublicConservationProviderFixture()
        source = cls.fixture.source(); snapshot = source.snapshot()
        cls.snapshot = loads(snapshot, maximum=64 * 1024 * 1024)
        cls.inputs = (source.anchor_bytes, keccak256(source.anchor_bytes), capture._source().PROFILE_HASH,
            source.transcript(), keccak256(source.transcript()))
        cls.result = capture.replay(*cls.inputs, provenance="synthetic_fixture", disclosure="public")

    @staticmethod
    def repin(files):
        manifest = loads(files["manifest.json"], maximum=1024 * 1024)
        manifest["files"] = [capture.base._ref(p, b) for p, b in sorted(files.items()) if p != "manifest.json"]
        files["manifest.json"] = dumps(manifest)
        return keccak256(files["manifest.json"])

    def test_exact_original_configuration_gas_and_qualified_provider_report(self):
        files = dict(self.result.files); report = self.result.report
        self.assertEqual(files["source/anchor.json"], self.inputs[0])
        self.assertEqual(files["source/transcript.json"], self.inputs[3])
        self.assertEqual(loads(files["source/snapshot.json"], maximum=64 * 1024 * 1024), self.snapshot)
        for name, keys in (("configuration", ("configuration", "configurationHash", "dependencies")),
                ("gas", ("originalGas", "currentGas")),
                ("evidence", ("source", "sourceReviewCommit", "sourceState", "registrationEvents", "historyCoverage", "claims", "qualification"))):
            self.assertEqual(loads(files["provider/" + name + ".json"], maximum=64 * 1024 * 1024),
                {key: self.snapshot[key] for key in keys})
        for key in ("configuration", "configurationHash", "dependencies", "originalGas", "currentGas", "sourceState", "historyCoverage"):
            self.assertEqual(report[key], self.snapshot[key])
        self.assertEqual(report["registrationEventCount"], str(len(self.snapshot["registrationEvents"])))
        self.assertNotIn("item13", report); self.assertNotIn("items", report)
        self.assertEqual(report["provenance"], "synthetic_fixture")
        for key in ("providerFloorBindingEstablished", "paidSaleAcceptanceEstablished", "canonicalPacketCompatible", "completeCanonicalPacket"):
            self.assertFalse(report[key])
        for key in ("legacyProviderCompatibility", "runtimeAdmissionArtifactVerified", "nativeRuntimeAcceptance", "personhoodProven",
                "sourceConsensusVerified", "actualChainAcceptance"):
            self.assertFalse(report["claims"][key])
        self.assertNotIn("tokenId", loads(self.inputs[0]))

    def test_offline_reconstruction_and_common_dispatch(self):
        from .package_v2 import verify_package
        with patch("socket.socket", side_effect=AssertionError("offline only")):
            self.assertEqual(capture.verify(dict(self.result.files), self.result.manifest_hash).files, self.result.files)
            with TemporaryDirectory() as temp:
                root = Path(temp) / "capture"; write_tree(dict(self.result.files), root)
                self.assertEqual(verify_package(root, self.result.manifest_hash).files, self.result.files)

    def replay_fixture(self, **kwargs):
        fixture = PublicConservationProviderFixture(**kwargs); source = fixture.source()
        snapshot = loads(source.snapshot(), maximum=64 * 1024 * 1024); transcript = source.transcript()
        result = capture.replay(source.anchor_bytes, keccak256(source.anchor_bytes), capture._source().PROFILE_HASH,
            transcript, keccak256(transcript), provenance="synthetic_fixture", disclosure="public")
        return result, snapshot, transcript

    def test_original_configuration_and_gas_survive_raised_current_values(self):
        result, snapshot, _ = self.replay_fixture(raised=True)
        self.assertEqual(snapshot["configuration"], self.snapshot["configuration"])
        self.assertEqual(snapshot["configurationHash"], self.snapshot["configurationHash"])
        self.assertEqual(snapshot["originalGas"], self.snapshot["originalGas"])
        self.assertNotEqual(snapshot["currentGas"], self.snapshot["currentGas"])
        self.assertEqual(loads(dict(result.files)["provider/gas.json"]),
            {"originalGas": snapshot["originalGas"], "currentGas": snapshot["currentGas"]})
        files = dict(result.files)
        files["provider/gas.json"] = dumps({"originalGas": snapshot["currentGas"], "currentGas": snapshot["currentGas"]})
        with self.assertRaisesRegex(MuseumError, "reconstruction differs"): capture.verify(files, self.repin(files))

    def test_unused_targets_and_optional_reference_remain_exact_source_facts(self):
        for mode in ("absent", "zero"):
            result, snapshot, transcript = self.replay_fixture(unused_targets=mode, zero_executor=True)
            self.assertEqual(loads(dict(result.files)["provider/configuration.json"], maximum=64 * 1024 * 1024),
                {key: snapshot[key] for key in ("configuration", "configurationHash", "dependencies")})
            probes = {call["params"][0] for call in loads(transcript, maximum=64 * 1024 * 1024)["calls"]
                if call["method"] == "eth_getCode"}
            self.assertFalse(set(snapshot["configuration"][0][5:7]) & probes)
        result, snapshot, transcript = self.replay_fixture(optional_reference=True)
        self.assertEqual(loads(dict(result.files)["provider/configuration.json"], maximum=64 * 1024 * 1024)["configuration"],
            snapshot["configuration"])
        self.assertIn(snapshot["configuration"][0][9], {call["params"][0] for call in
            loads(transcript, maximum=64 * 1024 * 1024)["calls"] if call["method"] == "eth_getCode"})

    def test_runtime_admission_provenance_cannot_be_relabelled_before_reads(self):
        fixture = PublicConservationProviderFixture(); raw = dumps(fixture.a)
        with patch.object(PublicRpcTransport, "request", side_effect=AssertionError("must reject before RPC")), \
                self.assertRaises(MuseumError):
            capture.capture(raw, keccak256(raw), capture._source().PROFILE_HASH,
                PublicRpcTransport("https://example.invalid"), disclosure="public")
        with self.assertRaises(MuseumError):
            capture.replay(*self.inputs, provenance="trusted_rpc", disclosure="public")
        getter = capture.os.environ.get
        def guarded(name, default=None):
            if name == "PUBLIC_CONSERVATION_PROVIDER_TEST_RPC": raise AssertionError("must reject before endpoint lookup")
            return getter(name, default)
        with TemporaryDirectory() as temp:
            root = Path(temp); anchor = root / "anchor.json"; anchor.write_bytes(raw); output = root / "out"
            with patch("sys.argv", self.argv(anchor, output)), patch.object(capture.os.environ, "get",
                    side_effect=guarded), self.assertRaisesRegex(MuseumError, "runtime admission"):
                capture.main()
            self.assertFalse(output.exists())

    def test_external_anchor_profile_transcript_and_manifest_pins_required(self):
        for index in (1, 2, 4):
            args = list(self.inputs); args[index] = "0x" + "ff" * 32
            with self.subTest(index=index), self.assertRaises(MuseumError):
                capture.replay(*args, provenance="synthetic_fixture", disclosure="public")
        with self.assertRaisesRegex(MuseumError, "manifest pin"):
            capture.verify(dict(self.result.files), "0x" + "ff" * 32)
        for provenance in (None, "actual_chain", ""):
            with self.assertRaisesRegex(MuseumError, "explicit provenance"):
                capture.replay(*self.inputs, provenance=provenance, disclosure="public")

    def test_rehashed_derived_files_profiles_and_snapshot_must_reconstruct(self):
        for name in ("source/snapshot.json", "provider/evidence.json", "provider/configuration.json",
                "provider/gas.json",
                "capture/report.json", "definitions/source-profile.json",
                "definitions/history-profile.json", "definitions/rpc-profile.json", "definitions/capture-profile.json"):
            files = dict(self.result.files); files[name] += b"\n"
            with self.subTest(name=name), self.assertRaisesRegex(MuseumError, "reconstruction differs"):
                capture.verify(files, self.repin(files))
        files = dict(self.result.files); report = loads(files["capture/report.json"], maximum=1024 * 1024)
        report["paidSaleAcceptanceEstablished"] = True
        report.update(canonicalPacketCompatible=True, completeCanonicalPacket=True)
        files["capture/report.json"] = dumps(report)
        with self.assertRaisesRegex(MuseumError, "reconstruction differs"): capture.verify(files, self.repin(files))

    def test_closed_manifest_provenance_and_exact_file_inventory(self):
        for change in (lambda v: v.update(provenance="trusted_rpc"), lambda v: v.update(extra=True),
                lambda v: v.update(mode="public_native_history_capture"),
                lambda v: v["claims"].update(paidSaleAcceptanceEstablished=True),
                lambda v: v.update(profileHash="0x" + "ff" * 32)):
            files = dict(self.result.files); manifest = loads(files["manifest.json"], maximum=1024 * 1024)
            change(manifest); files["manifest.json"] = dumps(manifest)
            with self.assertRaises(MuseumError): capture.verify(files, keccak256(files["manifest.json"]))
        for missing in (True, False):
            files = dict(self.result.files)
            if missing: del files["source/transcript.json"]
            else: files["unexpected.json"] = b"{}"
            with self.assertRaises(MuseumError): capture.verify(files, self.repin(files))
        files = dict(self.result.files); files["../outside"] = b"x"
        with self.assertRaises(MuseumError): capture.verify(files, self.result.manifest_hash)

    def test_rehashed_transcript_narrowed_range_omission_and_extra_call_fail(self):
        for change in ("range", "omit", "extra"):
            files = dict(self.result.files); transcript = loads(files["source/transcript.json"], maximum=64 * 1024 * 1024)
            if change == "omit": transcript["calls"].pop()
            elif change == "extra": transcript["calls"].append(deepcopy(transcript["calls"][0]))
            else:
                found = False
                for row in transcript["calls"]:
                    if row["method"] == "eth_getLogs":
                        row["params"][0]["fromBlock"] = "0x1"; found = True; break
                self.assertTrue(found)
            files["source/transcript.json"] = dumps(transcript)
            with self.subTest(change=change), self.assertRaises(MuseumError): capture.verify(files, self.repin(files))

    def test_live_transport_boundary_and_endpoint_omission(self):
        fixture = PublicConservationProviderFixture(); raw = self.admitted_anchor(fixture)
        endpoint = "https://example.invalid/private-provider-test-key"
        with patch.object(PublicRpcTransport, "request", side_effect=fixture.request), \
                patch("socket.socket", side_effect=AssertionError("synthetic transport only")):
            result = capture.capture(raw, keccak256(raw), capture._source().PROFILE_HASH,
                PublicRpcTransport(endpoint), disclosure="public")
        self.assertEqual(result.report["provenance"], "trusted_rpc")
        self.assertFalse(result.report["claims"]["sourceProvenanceSelfAuthenticated"])
        self.assertNotIn(endpoint.encode(), b"".join(raw for _, raw in result.files))
        self.assertEqual(capture.verify(dict(result.files), result.manifest_hash).files, result.files)
        with patch.object(fixture, "request", side_effect=AssertionError("rejected before reads")):
            for disclosure in ("private", "public"):
                with self.assertRaises(MuseumError):
                    capture.capture(raw, keccak256(raw), capture._source().PROFILE_HASH, fixture, disclosure=disclosure)
            with self.assertRaisesRegex(MuseumError, "public disclosure"):
                capture.replay(*self.inputs, provenance="synthetic_fixture", disclosure="private")

    @staticmethod
    def admitted_anchor(fixture):
        value = deepcopy(fixture.a)
        value["runtimeAdmission"]["kind"] = "externally_admitted_runtime"
        return dumps(value)

    def argv(self, anchor, output, command="capture", **changes):
        args = {"anchor": str(anchor), "anchor-hash": self.inputs[1], "source-profile-hash": self.inputs[2],
            "disclosure": "public", "output": str(output)}
        if command == "capture": args["rpc-env"] = "PUBLIC_CONSERVATION_PROVIDER_TEST_RPC"
        args.update(changes)
        return ["public_conservation_provider_capture", command, *[x for key, value in args.items() for x in ("--" + key, value)]]

    def test_cli_preflight_rejects_before_endpoint_reads_and_publication(self):
        getter = capture.os.environ.get
        def guarded(name, default=None):
            if name == "PUBLIC_CONSERVATION_PROVIDER_TEST_RPC": raise AssertionError("endpoint read during failed preflight")
            return getter(name, default)
        with TemporaryDirectory() as temp:
            root = Path(temp); anchor = root / "anchor.json"; raw = self.inputs[0]; anchor.write_bytes(raw)
            output = root / "out"; existing = root / "existing"; existing.mkdir()
            bad = root / "bad.json"; wrong = dumps(loads(raw) | {"tokenId": "1"}); bad.write_bytes(wrong)
            large = root / "large.json"; large.write_bytes(b" " * 65537)
            cases = [self.argv(root / "missing", output, disclosure="private"), self.argv(anchor, existing),
                self.argv(anchor, output, **{"anchor-hash": "0x" + "ff" * 32}),
                self.argv(anchor, output, **{"source-profile-hash": "0x" + "ff" * 32}),
                self.argv(anchor, output, **{"rpc-env": "https://invalid/key"}),
                self.argv(bad, output, **{"anchor-hash": keccak256(wrong)}),
                self.argv(large, output, **{"anchor-hash": keccak256(large.read_bytes())})]
            for args in cases:
                with self.subTest(args=args), patch("sys.argv", args), \
                        patch.object(capture.os.environ, "get", side_effect=guarded), self.assertRaises(MuseumError): capture.main()
            self.assertFalse(output.exists())
            with self.assertRaisesRegex(MuseumError, "regular file"): capture._read_input(existing, 65536)

    def test_cli_replay_verify_profiles_and_no_overwrite_are_offline(self):
        with TemporaryDirectory() as temp:
            root = Path(temp); anchor = root / "anchor.json"; anchor.write_bytes(self.inputs[0])
            transcript = root / "transcript.json"; transcript.write_bytes(self.inputs[3]); output = root / "out"
            args = self.argv(anchor, output, "replay", transcript=str(transcript),
                **{"transcript-hash": self.inputs[4], "provenance": "synthetic_fixture"})
            stdout = io.StringIO()
            with patch("sys.argv", args), redirect_stdout(stdout), patch("socket.socket", side_effect=AssertionError("offline only")):
                capture.main()
            message = loads(stdout.getvalue().encode()); before = read_tree(output)
            self.assertEqual(message["manifestHash"], self.result.manifest_hash)
            self.assertEqual(message["configurationHash"], self.snapshot["configurationHash"])
            self.assertFalse(message["canonicalPacketCompatible"])
            with patch("sys.argv", ["public_conservation_provider_capture", "verify", str(output), "--manifest-hash", message["manifestHash"]]), \
                    redirect_stdout(io.StringIO()), patch("socket.socket", side_effect=AssertionError("offline only")):
                capture.main()
            with patch("sys.argv", args), self.assertRaisesRegex(MuseumError, "new directory"): capture.main()
            self.assertEqual(read_tree(output), before)
        output = io.StringIO()
        with patch("sys.argv", ["public_conservation_provider_capture", "profiles"]), redirect_stdout(output), \
                patch("socket.socket", side_effect=AssertionError("offline only")):
            capture.main()
        self.assertEqual(loads(output.getvalue().encode()), {"captureProfileHash": capture.PROFILE_HASH, "sourceProfileHash": self.inputs[2]})

    def test_cli_mock_live_capture_and_failed_query_publish_atomically(self):
        with TemporaryDirectory() as temp:
            root = Path(temp); anchor = root / "anchor.json"; fixture = PublicConservationProviderFixture()
            raw = self.admitted_anchor(fixture); anchor.write_bytes(raw)
            output = root / "out"; stdout = io.StringIO()
            with patch("sys.argv", self.argv(anchor, output, **{"anchor-hash": keccak256(raw)})), redirect_stdout(stdout), \
                    patch.dict(capture.os.environ, {"PUBLIC_CONSERVATION_PROVIDER_TEST_RPC": "https://example.invalid"}), \
                    patch.object(PublicRpcTransport, "request", side_effect=fixture.request), \
                    patch("socket.socket", side_effect=AssertionError("synthetic only")):
                capture.main()
            message = loads(stdout.getvalue().encode()); files = read_tree(output)
            self.assertEqual(message["manifestHash"], keccak256(files["manifest.json"]))
            self.assertEqual(message["provenance"], "trusted_rpc")
            failed = root / "failed"
            with patch("sys.argv", self.argv(anchor, failed, **{"anchor-hash": keccak256(raw)})), \
                    patch.dict(capture.os.environ, {"PUBLIC_CONSERVATION_PROVIDER_TEST_RPC": "https://example.invalid"}), \
                    patch.object(PublicRpcTransport, "request", side_effect=MuseumError("historical provider unavailable")), \
                    self.assertRaisesRegex(MuseumError, "provider unavailable"):
                capture.main()
            self.assertFalse(failed.exists())

    def test_transport_failure_traceback_does_not_disclose_endpoint_or_remote_message(self):
        secret = "private-provider-credential-in-url-or-server-line"
        with TemporaryDirectory() as temp:
            root = Path(temp); anchor = root / "anchor.json"; raw = self.admitted_anchor(self.fixture)
            anchor.write_bytes(raw); output = root / "out"
            with patch("sys.argv", self.argv(anchor, output, **{"anchor-hash": keccak256(raw)})), \
                    patch.dict(capture.os.environ, {"PUBLIC_CONSERVATION_PROVIDER_TEST_RPC": "https://example.invalid/" + secret}), \
                    patch("urllib.request.build_opener") as opener:
                opener.return_value.open.side_effect = http.client.InvalidURL(secret)
                try: capture.main()
                except MuseumError as exc: rendered = "".join(traceback.format_exception(exc))
                else: self.fail("expected sanitized transport failure")
            self.assertNotIn(secret, rendered)
            self.assertIn("public RPC transport failed", rendered)
            self.assertFalse(output.exists())


if __name__ == "__main__": unittest.main()
