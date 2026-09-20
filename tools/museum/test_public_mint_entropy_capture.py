"""Concrete public mint/entropy package replay and capture-boundary tests."""
from contextlib import redirect_stdout
from copy import deepcopy
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import public_mint_entropy_capture as capture
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .public_history_rpc import PublicRpcTransport
from .test_public_mint_entropy_source import PublicMintEntropyFixture


class PublicMintEntropyCaptureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inputs, cls.packages = {}, {}
        for kind, fixture in (("late", PublicMintEntropyFixture(recovery=True, late=True)),
                ("registered", PublicMintEntropyFixture(status=3))):
            source = fixture.source(); source.snapshot()
            args = (source.anchor_bytes, keccak256(source.anchor_bytes), capture._source().PROFILE_HASH,
                source.transcript(), keccak256(source.transcript()))
            cls.inputs[kind] = args
            cls.packages[kind] = capture.replay(*args, provenance="synthetic_fixture", disclosure="public")

    @staticmethod
    def repin(files):
        value = loads(files["manifest.json"], maximum=1024 * 1024)
        value["files"] = [capture.base._ref(p, b) for p, b in sorted(files.items()) if p != "manifest.json"]
        files["manifest.json"] = dumps(value)
        return keccak256(files["manifest.json"])

    def test_concrete_offline_replay_dispatch_and_active_attempt_preserved(self):
        from .package_v2 import verify_package
        with patch("socket.socket", side_effect=AssertionError("offline replay")):
            for result in self.packages.values():
                self.assertEqual(capture.verify(dict(result.files), result.manifest_hash).files, result.files)
                with TemporaryDirectory() as temp:
                    output = Path(temp) / "capture"; write_tree(dict(result.files), output)
                    self.assertEqual(verify_package(output, result.manifest_hash).files, result.files)
        files = dict(self.packages["late"].files)
        packet = loads(files["entropy/packet-fragment.json"])
        observation = loads(files["entropy/request-history-observation.json"])
        self.assertEqual(packet["leaf"]["requestAttempt"], "1")
        self.assertEqual(observation["observedRequestCount"], "2")
        self.assertEqual(observation["observedMaximumAttempt"], "2")
        self.assertFalse(observation["lifetimeAttemptHighWaterProven"])
        self.assertEqual(keccak256(files["entropy/leaf-preimage.bin"]), packet["leafHash"])
        self.assertEqual(len(packet["events"]), 3)
        self.assertTrue(self.packages["late"].report["terminalEligible"])
        self.assertFalse(self.packages["registered"].report["terminalEligible"])
        self.assertIn("not FINALIZED", self.packages["registered"].report["remaining"][0])

    def test_mocked_live_transport_replays_and_omits_endpoint(self):
        fixture = PublicMintEntropyFixture(recovery=True, late=True)
        endpoint = "https://example.invalid/private-test-credential"
        raw = dumps(fixture.a)
        with patch.object(PublicRpcTransport, "request", side_effect=fixture.request), \
                patch("socket.socket", side_effect=AssertionError("synthetic fixture only")):
            result = capture.capture(raw, keccak256(raw), capture._source().PROFILE_HASH,
                PublicRpcTransport(endpoint), disclosure="public")
        self.assertEqual(result.report["provenance"], "trusted_rpc")
        self.assertFalse(result.report["claims"]["sourceProvenanceSelfAuthenticated"])
        self.assertFalse(result.report["claims"]["actualChainAcceptance"])
        self.assertNotIn(endpoint.encode(), b"".join(raw for _, raw in result.files))
        self.assertEqual(capture.verify(dict(result.files), result.manifest_hash).files, result.files)

    def test_external_anchor_profile_transcript_and_manifest_pins_required(self):
        for index in (1, 2, 4):
            args = list(self.inputs["late"]); args[index] = "0x" + "ff" * 32
            with self.subTest(index=index), self.assertRaises(MuseumError):
                capture.replay(*args, provenance="synthetic_fixture", disclosure="public")
        with self.assertRaisesRegex(MuseumError, "manifest pin"):
            capture.verify(dict(self.packages["late"].files), "0x" + "ff" * 32)

    def test_rehashed_derived_outputs_profiles_and_snapshot_cannot_replace_reconstruction(self):
        result = self.packages["late"]
        for target in ("source/snapshot.json", "mint/evidence.json", "mint/transfers.jsonl", "entropy/packet-fragment.json",
                "entropy/leaf-preimage.bin", "entropy/request-history-observation.json", "capture/report.json",
                "definitions/source-profile.json", "definitions/history-profile.json", "definitions/rpc-profile.json",
                "definitions/capture-profile.json"):
            files = dict(result.files); files[target] += b"\n"
            with self.subTest(target=target), self.assertRaisesRegex(MuseumError, "reconstruction differs"):
                capture.verify(files, self.repin(files))

    def test_manifest_provenance_claims_scope_and_inventory_are_closed(self):
        result = self.packages["late"]
        for mutate in (lambda v: v.update(provenance="trusted_rpc"), lambda v: v.update(extra=True),
                lambda v: v.update(mode="public_native_history_capture"),
                lambda v: v["claims"].update(lifetimeAttemptHighWaterProven=True)):
            files = dict(result.files); value = loads(files["manifest.json"], maximum=1024 * 1024)
            mutate(value); files["manifest.json"] = dumps(value)
            with self.assertRaises(MuseumError): capture.verify(files, keccak256(files["manifest.json"]))
        for missing in (True, False):
            files = dict(result.files)
            if missing: del files["source/transcript.json"]
            else: files["extra.txt"] = b"unaccepted"
            with self.assertRaises(MuseumError): capture.verify(files, self.repin(files))

    def test_rehashed_transcript_omissions_narrowed_range_and_extra_calls_fail(self):
        from .mint_entropy_source import REQUESTED
        result = self.packages["late"]
        for change in ("request", "range", "extra"):
            files = dict(result.files); value = loads(files["source/transcript.json"], maximum=64 * 1024 * 1024)
            if change == "extra": value["calls"].append(deepcopy(value["calls"][0]))
            else:
                for row in value["calls"]:
                    if row["method"] != "eth_getLogs": continue
                    if change == "range": row["params"][0]["fromBlock"] = "0x1"; break
                    hits = row.get("result", [])
                    if any(log["topics"][0] == REQUESTED for log in hits):
                        row["result"] = [log for log in hits if log["topics"][0] != REQUESTED]; break
            files["source/transcript.json"] = dumps(value)
            with self.subTest(change=change), self.assertRaises(MuseumError): capture.verify(files, self.repin(files))

    def test_capture_refuses_nonpublic_and_arbitrary_trusted_transport_before_reads(self):
        fixture = PublicMintEntropyFixture(); raw = dumps(fixture.a)
        for disclosure in ("private", "public"):
            with self.assertRaises(MuseumError):
                capture.capture(raw, keccak256(raw), capture._source().PROFILE_HASH, fixture, disclosure=disclosure)
        self.assertEqual(fixture.requested, [])

    def argv(self, anchor, output, **changes):
        args = {"anchor": str(anchor), "anchor-hash": self.inputs["late"][1], "source-profile-hash": self.inputs["late"][2],
            "rpc-env": "PUBLIC_ENTROPY_TEST_RPC", "disclosure": "public", "output": str(output)} | changes
        return ["public_mint_entropy_capture", "capture", *[x for k, v in args.items() for x in ("--" + k, v)]]

    def test_cli_disclosure_output_and_closed_anchor_checked_before_endpoint_reads(self):
        getter = capture.os.environ.get
        def guarded(name, default=None):
            if name == "PUBLIC_ENTROPY_TEST_RPC": raise AssertionError("endpoint read during failed preflight")
            return getter(name, default)
        with TemporaryDirectory() as temp:
            root = Path(temp); anchor = root / "anchor.json"; raw = self.inputs["late"][0]; anchor.write_bytes(raw)
            output = root / "out"; existing = root / "existing"; existing.mkdir()
            bad_anchor = root / "bad-anchor.json"; changed = dumps(loads(raw) | {"requestKeys": []}); bad_anchor.write_bytes(changed)
            cases = [self.argv(root / "missing", output, disclosure="private"), self.argv(anchor, existing),
                self.argv(anchor, output, **{"anchor-hash": "0x" + "ff" * 32}),
                self.argv(anchor, output, **{"rpc-env": "https://invalid/key"}),
                self.argv(bad_anchor, output, **{"anchor-hash": keccak256(changed)})]
            for args in cases:
                with patch("sys.argv", args), patch.object(capture.os.environ, "get", side_effect=guarded), \
                        self.assertRaises(MuseumError): capture.main()
            self.assertFalse(output.exists())

    def test_cli_mock_capture_publish_offline_verify_and_no_overwrite(self):
        with TemporaryDirectory() as temp:
            root = Path(temp); anchor = root / "anchor.json"; anchor.write_bytes(self.inputs["late"][0]); output = root / "out"
            fixture = PublicMintEntropyFixture(recovery=True, late=True); stdout = io.StringIO()
            with patch("sys.argv", self.argv(anchor, output)), redirect_stdout(stdout), \
                    patch.dict(capture.os.environ, {"PUBLIC_ENTROPY_TEST_RPC": "https://example.invalid"}), \
                    patch.object(PublicRpcTransport, "request", side_effect=fixture.request), \
                    patch("socket.socket", side_effect=AssertionError("no actual network")):
                capture.main()
            message = loads(stdout.getvalue().encode()); before = read_tree(output)
            self.assertEqual(message["manifestHash"], keccak256(before["manifest.json"]))
            self.assertEqual(message["observedStatus"], "FINALIZED")
            with patch("sys.argv", ["public_mint_entropy_capture", "verify", str(output), "--manifest-hash", message["manifestHash"]]), \
                    redirect_stdout(io.StringIO()), patch("socket.socket", side_effect=AssertionError("offline replay")):
                capture.main()
            with patch("sys.argv", self.argv(anchor, output)), self.assertRaisesRegex(MuseumError, "new directory"):
                capture.main()
            self.assertEqual(read_tree(output), before)

    def test_failed_live_query_publishes_no_directory(self):
        with TemporaryDirectory() as temp:
            root = Path(temp); anchor = root / "anchor.json"; anchor.write_bytes(self.inputs["late"][0]); output = root / "out"
            with patch("sys.argv", self.argv(anchor, output)), \
                    patch.dict(capture.os.environ, {"PUBLIC_ENTROPY_TEST_RPC": "https://example.invalid"}), \
                    patch.object(PublicRpcTransport, "request", side_effect=MuseumError("historical provider unavailable")), \
                    self.assertRaisesRegex(MuseumError, "provider unavailable"):
                capture.main()
            self.assertFalse(output.exists())


if __name__ == "__main__": unittest.main()
