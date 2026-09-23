"""Concrete public-source reconstruction, CLI preflight and atomic output controls."""
from contextlib import redirect_stdout
from copy import deepcopy
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import public_history_capture as capture
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .public_history_rpc import PublicRpcTransport
from .test_public_ownership_source import PublicOwnershipFixture
from .test_public_rights_source import PublicRightsFixture


class PublicHistoryCaptureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inputs, cls.packages = {}, {}
        for kind, fixture in (("ownership", PublicOwnershipFixture()), ("rights", PublicRightsFixture(token=True))):
            source = fixture.source(); source.snapshot()
            args = (kind, source.anchor_bytes, keccak256(source.anchor_bytes), capture._sources()[kind][2],
                source.transcript(), keccak256(source.transcript()))
            cls.inputs[kind] = args
            cls.packages[kind] = capture.replay(*args, provenance="synthetic_fixture", disclosure="public")

    @staticmethod
    def repin(files):
        value = loads(files["manifest.json"], maximum=1024 * 1024)
        value["files"] = [capture.base._ref(p, b) for p, b in sorted(files.items()) if p != "manifest.json"]
        files["manifest.json"] = dumps(value)
        return keccak256(files["manifest.json"])

    def test_both_kinds_exact_offline_reconstruction_and_closed_dispatch(self):
        from .package_v2 import verify_package
        with patch("socket.socket", side_effect=AssertionError("offline means no network")):
            for kind, result in self.packages.items():
                with self.subTest(kind=kind):
                    self.assertEqual(capture.verify(dict(result.files), result.manifest_hash).files, result.files)
                    with TemporaryDirectory() as temp:
                        output = Path(temp) / "capture"
                        write_tree(dict(result.files), output)
                        self.assertEqual(verify_package(output, result.manifest_hash).files, result.files)
        rights = dict(self.packages["rights"].files)
        fragment = loads(rights["rights/packet-fragment.json"])
        self.assertEqual(fragment["selectionEvidence"]["uri"], "source/snapshot.json")
        self.assertEqual(fragment["selectionEvidence"]["hash"]["digest"], keccak256(rights["source/snapshot.json"]))
        self.assertEqual(fragment["effectiveGrants"]["reproduction"], "unspecified")
        ownership = dict(self.packages["ownership"].files)
        self.assertEqual(len(ownership["ownership/transfers.jsonl"].splitlines()), 3)
        for result in self.packages.values():
            self.assertFalse(result.report["claims"]["actualChainAcceptance"])
            self.assertTrue(result.report["claims"]["providerLogCompletenessTrusted"])

    def test_real_transport_class_with_mocked_io_replays_before_return_and_omits_endpoint(self):
        for kind, fixture in (("ownership", PublicOwnershipFixture()), ("rights", PublicRightsFixture(token=True))):
            endpoint = "https://example.invalid/private-test-token"
            with patch.object(PublicRpcTransport, "request", side_effect=fixture.request), \
                    patch("socket.socket", side_effect=AssertionError("synthetic endpoint only")):
                raw = dumps(fixture.a)
                result = capture.capture(kind, raw, keccak256(raw), capture._sources()[kind][2],
                    PublicRpcTransport(endpoint), disclosure="public")
            self.assertEqual(result.report["provenance"], "trusted_rpc")
            self.assertFalse(result.report["claims"]["sourceProvenanceSelfAuthenticated"])
            self.assertFalse(result.report["claims"]["actualChainAcceptance"])
            self.assertNotIn(endpoint.encode(), b"".join(b for _, b in result.files))
            self.assertEqual(capture.verify(dict(result.files), result.manifest_hash).files, result.files)

    def test_wrong_external_anchor_profile_transcript_manifest_pins_fail(self):
        args = self.inputs["ownership"]
        for index in (2, 3, 5):
            changed = list(args); changed[index] = "0x" + "ff" * 32
            with self.subTest(index=index), self.assertRaises(MuseumError):
                capture.replay(*changed, provenance="synthetic_fixture", disclosure="public")
        result = self.packages["ownership"]
        with self.assertRaisesRegex(MuseumError, "manifest pin"):
            capture.verify(dict(result.files), "0x" + "ff" * 32)

    def test_repinned_derived_snapshot_report_and_profile_tamper_fail_reconstruction(self):
        for kind, result in self.packages.items():
            original = dict(result.files)
            targets = ["source/snapshot.json", "capture/report.json", "definitions/source-profile.json",
                "definitions/history-profile.json", "definitions/rpc-profile.json", "definitions/capture-profile.json",
                "ownership/transfers.jsonl" if kind == "ownership" else "rights/packet-fragment.json"]
            for target in targets:
                files = dict(original)
                files[target] += b"\n"
                with self.subTest(kind=kind, target=target), self.assertRaisesRegex(MuseumError, "reconstruction differs"):
                    capture.verify(files, self.repin(files))

    def test_repinned_manifest_semantics_provenance_and_inventory_fail(self):
        result = self.packages["ownership"]
        for mutation in (lambda v: v.update(kind="rights"), lambda v: v.update(provenance="trusted_rpc"),
                lambda v: v.update(profileHash="0x" + "11" * 32), lambda v: v.update(extra="unaccepted"),
                lambda v: v["claims"].update(actualChainAcceptance=True)):
            files = dict(result.files); value = loads(files["manifest.json"], maximum=1024 * 1024)
            mutation(value); files["manifest.json"] = dumps(value)
            with self.assertRaises(MuseumError): capture.verify(files, keccak256(files["manifest.json"]))
        for missing in (False, True):
            files = dict(result.files)
            if missing: del files["source/transcript.json"]
            else: files["unlisted.txt"] = b"unaccepted"
            with self.subTest(missing=missing), self.assertRaises(MuseumError):
                capture.verify(files, self.repin(files))

    def test_repinned_transcript_cannot_hide_mint_or_mutate_canonical_mapping(self):
        original = dict(self.packages["ownership"].files)
        for mutate in ("mint", "header", "unconsumed"):
            files = dict(original); transcript = loads(files["source/transcript.json"], maximum=64 * 1024 * 1024)
            if mutate == "unconsumed": transcript["calls"].append(deepcopy(transcript["calls"][0]))
            else:
                for row in transcript["calls"]:
                    if mutate == "mint" and row["method"] == "eth_getLogs" and row["result"]:
                        row["result"].pop(0); break
                    if mutate == "header" and row["method"] == "eth_getBlockByNumber":
                        row["result"]["stateRoot"] = "0x" + "ab" * 32; break
            files["source/transcript.json"] = dumps(transcript)
            with self.subTest(mutate=mutate), self.assertRaises(MuseumError): capture.verify(files, self.repin(files))

    def test_disclosure_and_exact_transport_admission_precede_reads(self):
        f = PublicOwnershipFixture(); raw = dumps(f.a); profile = capture._sources()["ownership"][2]
        with self.assertRaisesRegex(MuseumError, "public disclosure"):
            capture.capture("ownership", raw, keccak256(raw), profile, f, disclosure="private")
        with self.assertRaisesRegex(MuseumError, "explicit read-only transport"):
            capture.capture("ownership", raw, keccak256(raw), profile, f, disclosure="public")
        self.assertEqual(f.requested, [])

    def arguments(self, anchor, output, **changes):
        options = {"kind": "ownership", "anchor": str(anchor), "anchor-hash": self.inputs["ownership"][2],
            "source-profile-hash": self.inputs["ownership"][3], "rpc-env": "MUSEUM_PUBLIC_TEST_RPC",
            "disclosure": "public", "output": str(output)} | changes
        return ["public_history_capture", "capture", *[s for k, v in options.items() for s in ("--" + k, v)]]

    def endpoint_guard(self):
        original = capture.os.environ.get
        def guarded(name, default=None):
            if name == "MUSEUM_PUBLIC_TEST_RPC": raise AssertionError("no endpoint read")
            return original(name, default)
        return patch.object(capture.os.environ, "get", side_effect=guarded)

    def test_cli_invalid_disclosure_output_and_pin_fail_before_endpoint_access(self):
        with TemporaryDirectory() as temp:
            root = Path(temp); anchor = root / "anchor.json"; anchor.write_bytes(self.inputs["ownership"][1])
            existing = root / "existing"; existing.mkdir(); (existing / "keep").write_bytes(b"original")
            cases = [self.arguments(root / "missing", root / "out", disclosure="private"),
                self.arguments(anchor, existing), self.arguments(anchor, root / "out", **{"anchor-hash": "0x" + "11" * 32}),
                self.arguments(anchor, root / "out", **{"rpc-env": "https://secret.invalid/key"})]
            for args in cases:
                with patch("sys.argv", args), self.endpoint_guard(), \
                        patch.object(PublicRpcTransport, "request", side_effect=AssertionError("no RPC")), self.assertRaises(MuseumError):
                    capture.main()
            self.assertEqual((existing / "keep").read_bytes(), b"original")
            self.assertFalse((root / "out").exists())

    def test_cli_closed_anchor_schema_fails_before_endpoint_access(self):
        with TemporaryDirectory() as temp:
            root = Path(temp); anchor = root / "anchor.json"
            value = loads(self.inputs["ownership"][1]); value["startBlock"] = "9000000"; raw = dumps(value)
            anchor.write_bytes(raw)
            with patch("sys.argv", self.arguments(anchor, root / "out", **{"anchor-hash": keccak256(raw)})), \
                    self.endpoint_guard(), \
                    self.assertRaisesRegex(MuseumError, "shape/profile"):
                capture.main()

    def test_cli_mocked_live_capture_atomic_publish_then_offline_verify(self):
        with TemporaryDirectory() as temp:
            root = Path(temp); anchor = root / "anchor.json"; anchor.write_bytes(self.inputs["ownership"][1])
            output = root / "capture"; stdout = io.StringIO(); fixture = PublicOwnershipFixture()
            with patch("sys.argv", self.arguments(anchor, output)), redirect_stdout(stdout), \
                    patch.dict(capture.os.environ, {"MUSEUM_PUBLIC_TEST_RPC": "https://example.invalid/local-test"}), \
                    patch.object(PublicRpcTransport, "request", side_effect=fixture.request), \
                    patch("socket.socket", side_effect=AssertionError("no actual network")):
                capture.main()
            message = loads(stdout.getvalue().encode()); files = read_tree(output)
            self.assertEqual(message["manifestHash"], keccak256(files["manifest.json"]))
            self.assertEqual(message["provenance"], "trusted_rpc")
            self.assertFalse(message["sourceConsensusVerified"])
            with patch("sys.argv", ["public_history_capture", "verify", str(output), "--manifest-hash", message["manifestHash"]]), \
                    redirect_stdout(io.StringIO()), patch("socket.socket", side_effect=AssertionError("offline verification")):
                capture.main()
            before = read_tree(output)
            with patch("sys.argv", self.arguments(anchor, output)), self.assertRaisesRegex(MuseumError, "new directory"):
                capture.main()
            self.assertEqual(read_tree(output), before)

    def test_cli_output_created_during_capture_remains_untouched(self):
        with TemporaryDirectory() as temp:
            root = Path(temp); anchor = root / "anchor.json"; anchor.write_bytes(self.inputs["ownership"][1]); output = root / "out"
            def raced(*args, **kwargs):
                output.mkdir(); (output / "keep").write_bytes(b"race-owner")
                return self.packages["ownership"]
            with patch("sys.argv", self.arguments(anchor, output)), \
                    patch.dict(capture.os.environ, {"MUSEUM_PUBLIC_TEST_RPC": "https://example.invalid"}), \
                    patch.object(capture, "capture", side_effect=raced), self.assertRaisesRegex(MuseumError, "new directory"):
                capture.main()
            self.assertEqual({p.name: p.read_bytes() for p in output.iterdir()}, {"keep": b"race-owner"})


if __name__ == "__main__": unittest.main()
