"""Concrete synthetic attribution captures; no native or institutional acceptance."""
from contextlib import redirect_stdout
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import public_attribution_capture as capture
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .independent_wire import ZERO
from .public_history_rpc import PublicRpcTransport
from .test_public_attribution_source import PublicAttributionFixture


class PublicAttributionCaptureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = PublicAttributionFixture()
        adapter = cls.fixture.source()
        cls.snapshot_raw = adapter.snapshot(); transcript = adapter.transcript()
        cls.snapshot = loads(cls.snapshot_raw, maximum=64 * 1024 * 1024)
        cls.inputs = (adapter.anchor_bytes, keccak256(adapter.anchor_bytes), capture._source().PROFILE_HASH,
            transcript, keccak256(transcript))
        cls.result = capture.replay(*cls.inputs, provenance="synthetic_fixture", disclosure="public")

    @staticmethod
    def repin(files):
        files = dict(files); manifest = loads(files["manifest.json"], maximum=1048576)
        manifest["files"] = [capture.base._ref(path, raw) for path, raw in sorted(files.items()) if path != "manifest.json"]
        files["manifest.json"] = dumps(manifest)
        return files, keccak256(files["manifest.json"])

    def test_exact_original_triplet_history_and_sanctions_are_preserved(self):
        files, report = dict(self.result.files), self.result.report
        self.assertEqual(files["source/anchor.json"], self.inputs[0])
        self.assertEqual(files["source/transcript.json"], self.inputs[3])
        self.assertEqual(files["source/snapshot.json"], self.snapshot_raw)
        for key in ("graph", "current", "history", "sanctions"):
            self.assertEqual(files["attribution/" + key + ".json"], dumps(self.snapshot[key]))
            self.assertEqual(report[key], self.snapshot[key])
        evidence = loads(files["attribution/evidence.json"], maximum=64 * 1024 * 1024)
        self.assertEqual(evidence, {key: self.snapshot[key] for key in
            ("source", "sourceReviewCommit", "sourceState", "historyCoverage", "claims", "qualification")})
        self.assertEqual(files["definitions/source-profile.json"], capture._source().PROFILE_BYTES)
        self.assertEqual(files["definitions/capture-profile.json"], capture.PROFILE_BYTES)

    def test_distinct_original_confirmation_later_sanction_and_restoration_modes_replay(self):
        outputs = {}
        for mode in ("accepted", "sanctioned", "later_sanction", "restored", "none", "platform", "imported"):
            with self.subTest(mode=mode):
                fixture = PublicAttributionFixture(mode=mode); adapter = fixture.source()
                raw = adapter.snapshot(); transcript = adapter.transcript()
                source = loads(raw, maximum=64 * 1024 * 1024)
                result = capture.replay(adapter.anchor_bytes, keccak256(adapter.anchor_bytes), self.inputs[2],
                    transcript, keccak256(transcript), provenance="synthetic_fixture", disclosure="public")
                for key in ("current", "history", "sanctions"):
                    self.assertEqual(result.report[key], source[key])
                history, sanctions, current = (result.report[key] for key in ("history", "sanctions", "current"))
                if mode in ("sanctioned", "later_sanction", "restored"):
                    original = history["originalConfirmation"]
                    self.assertEqual((original["oldState"], original["newState"]), ("2", "3"))
                    self.assertNotEqual(sanctions["originalConfirmedHash"], ZERO)
                    self.assertEqual(sanctions["originalConfirmedHash"], original["recordHash"])
                    self.assertEqual(history["confirmationArchive"]["sanctionRecordHash"], original["recordHash"])
                if mode == "later_sanction":
                    self.assertNotEqual(sanctions["latestAssociationHash"], sanctions["originalConfirmedHash"])
                if mode == "restored":
                    self.assertTrue(history["restorations"])
                    self.assertTrue(all(row["oldState"] == "4" for row in history["restorations"]))
                if mode in ("none", "platform"):
                    self.assertEqual(current["attribution"][0], "0")
                    self.assertEqual(current["platformDeclaration"][0], mode == "platform")
                    self.assertIsNone(history["originalConfirmation"])
                if mode == "imported": self.assertFalse(history["completeLocalBaseline"])
                outputs[mode] = dumps({key: result.report[key] for key in ("current", "history", "sanctions")})
        self.assertNotEqual(outputs["sanctioned"], outputs["later_sanction"])
        self.assertNotEqual(outputs["sanctioned"], outputs["restored"])
        self.assertNotEqual(outputs["none"], outputs["platform"])

    def test_coverage_and_authority_claims_are_not_promoted_by_capture(self):
        report = self.result.report
        self.assertEqual(report["provenance"], "synthetic_fixture")
        self.assertEqual(report["historyCoverage"], self.snapshot["historyCoverage"])
        self.assertFalse(report["canonicalPacketCompatible"])
        self.assertFalse(report["completeCanonicalPacket"])
        for key in ("historicalAuthorityReexecuted", "currentSignatureRevalidated", "institutionalStandingProven",
                "legalPersonhoodProven", "sourceConsensusVerified", "sourceProvenanceSelfAuthenticated",
                "runtimeAdmissionArtifactVerified", "nativeRuntimeAcceptance", "completeAttributionSourcesProven",
                "completeCanonicalPacket", "actualChainAcceptance", "endpointRetained"):
            self.assertFalse(report["claims"][key], key)

    def test_offline_exact_reconstruction_and_common_dispatch(self):
        from .package_v2 import verify_package
        with patch("socket.socket", side_effect=AssertionError("offline only")):
            self.assertEqual(capture.verify(self.result.files, self.result.manifest_hash).files, self.result.files)
            with TemporaryDirectory() as temporary:
                path = Path(temporary) / "captured"; write_tree(dict(self.result.files), path)
                self.assertEqual(verify_package(path, self.result.manifest_hash).files, self.result.files)

    def test_rehashed_sidecars_snapshot_and_extra_file_cannot_replace_replay(self):
        for path in ("attribution/graph.json", "attribution/current.json", "attribution/history.json",
                "attribution/sanctions.json", "attribution/evidence.json", "source/snapshot.json", "caller-extra.json"):
            with self.subTest(path=path):
                files = dict(self.result.files)
                value = {} if path not in files else loads(files[path], maximum=64 * 1024 * 1024)
                if isinstance(value, dict): value["callerComplete"] = True
                else: value = {"callerComplete": True, "original": value}
                files[path] = dumps(value); files, digest = self.repin(files)
                with self.assertRaisesRegex(MuseumError, "reconstruction differs"):
                    capture.verify(files, digest)

    def test_closed_manifest_mode_claims_and_external_pins_reject(self):
        for key, replacement in (("profile", "caller-profile"), ("mode", "public_personhood_capture"),
                ("version", "2"), ("extra", True), ("claims", {"actualChainAcceptance": True})):
            files = dict(self.result.files); manifest = loads(files["manifest.json"], maximum=1048576)
            manifest[key] = replacement; files["manifest.json"] = dumps(manifest)
            with self.subTest(key=key), self.assertRaisesRegex(MuseumError, "closed manifest"):
                capture.verify(files, keccak256(files["manifest.json"]))
        for index in (1, 2, 4):
            inputs = list(self.inputs); inputs[index] = keccak256(b"wrong external pin")
            with self.subTest(pin=index), self.assertRaises(MuseumError):
                capture.replay(*inputs, provenance="synthetic_fixture", disclosure="public")
        with self.assertRaisesRegex(MuseumError, "external manifest pin"):
            capture.verify(self.result.files, keccak256(b"wrong manifest"))

    def test_closed_source_runtime_and_provenance_fail_before_derivation(self):
        for mode in ("runtime", "extra", "provenance"):
            anchor = loads(self.inputs[0], maximum=1048576)
            if mode == "runtime":
                next(row for row in anchor["codePins"] if row["address"] == anchor["artistRegistry"])["runtimeHash"] = keccak256(b"wrong runtime")
            elif mode == "extra": anchor["callerComplete"] = True
            raw = dumps(anchor)
            with self.subTest(mode=mode), self.assertRaises(MuseumError):
                capture.replay(raw, keccak256(raw), self.inputs[2], self.inputs[3], self.inputs[4],
                    provenance="trusted_rpc" if mode == "provenance" else "synthetic_fixture", disclosure="public")

    def test_rehashed_transcript_requires_exact_calls_and_consistent_chain(self):
        for mode in ("missing", "extra", "chain"):
            transcript = loads(self.inputs[3], maximum=64 * 1024 * 1024)
            if mode == "missing": transcript["calls"].pop()
            elif mode == "extra": transcript["calls"].append(transcript["calls"][-1])
            else:
                row = next(row for row in transcript["calls"] if row["method"] == "eth_chainId")
                row["result"] = hex(int(row["result"], 16) + 1)
            files = dict(self.result.files); files["source/transcript.json"] = dumps(transcript)
            files, digest = self.repin(files)
            with self.subTest(mode=mode), self.assertRaises(MuseumError):
                capture.verify(files, digest)

    def test_read_only_capture_boundary_has_exact_transport_and_no_endpoint_retention(self):
        endpoint = "https://example.invalid/fixture-private-path?key=synthetic-only"
        anchor = loads(self.inputs[0], maximum=1048576)
        anchor["runtimeAdmission"]["kind"] = "externally_admitted_runtime"
        raw = dumps(anchor)
        with patch.object(PublicRpcTransport, "request", side_effect=self.fixture.request), \
                patch("socket.socket", side_effect=AssertionError("synthetic transport only")):
            result = capture.capture(raw, keccak256(raw), self.inputs[2], PublicRpcTransport(endpoint), disclosure="public")
        self.assertEqual(result.report["provenance"], "trusted_rpc")
        self.assertFalse(result.report["claims"]["actualChainAcceptance"])
        for _path, body in result.files:
            self.assertNotIn(endpoint.encode(), body)
            self.assertNotIn(b"fixture-private-path", body)
            self.assertNotIn(b"synthetic-only", body)
        with self.assertRaisesRegex(MuseumError, "explicit read-only transport"):
            capture.capture(raw, keccak256(raw), self.inputs[2], self.fixture, disclosure="public")

    def test_disclosure_preflight_precedes_all_input_and_environment_reads(self):
        with patch.object(capture, "_source", side_effect=AssertionError("source read before disclosure")):
            with self.assertRaisesRegex(MuseumError, "public disclosure"):
                capture.replay(*self.inputs, provenance="synthetic_fixture", disclosure="restricted")
            with self.assertRaisesRegex(MuseumError, "public disclosure"):
                capture.capture(*self.inputs[:3], self.fixture, disclosure="restricted")
            with self.assertRaisesRegex(MuseumError, "public disclosure"):
                capture.main(["capture", "--anchor", "unread-anchor", "--anchor-hash", self.inputs[1],
                    "--source-profile-hash", self.inputs[2], "--rpc-env", "UNREAD_ATTRIBUTION_RPC",
                    "--disclosure", "restricted", "--output", "unread-output"])

    def test_live_cli_closed_anchor_and_runtime_admission_precede_endpoint_lookup(self):
        for mode in ("extra", "synthetic"):
            anchor = loads(self.inputs[0], maximum=1048576)
            if mode == "extra":
                anchor["runtimeAdmission"]["kind"] = "externally_admitted_runtime"
                anchor["callerComplete"] = True
            raw = dumps(anchor)
            with self.subTest(mode=mode), TemporaryDirectory() as temporary:
                root = Path(temporary); path = root / "anchor.json"; path.write_bytes(raw)
                original = capture.os.environ.get
                def guarded(name, default=None):
                    if name == "ATTRIBUTION_TEST_RPC": raise AssertionError("endpoint read before closed source preflight")
                    return original(name, default)
                with patch.object(capture.os.environ, "get", side_effect=guarded), self.assertRaises(MuseumError):
                    capture.main(["capture", "--anchor", str(path), "--anchor-hash", keccak256(raw),
                        "--source-profile-hash", self.inputs[2], "--rpc-env", "ATTRIBUTION_TEST_RPC",
                        "--disclosure", "public", "--output", str(root / "out")])

    def test_regular_file_and_bounded_reads_reject_directory_empty_oversize_and_link(self):
        with TemporaryDirectory() as temporary:
            root = Path(temporary); path = root / "input.json"
            with self.assertRaises(MuseumError): capture._read_input(root, 4)
            for body in (b"", b"12345"):
                path.write_bytes(body)
                with self.assertRaises(MuseumError): capture._read_input(path, 4)
            path.write_bytes(b"1234")
            self.assertEqual(capture._read_input(path, 4), b"1234")
            with patch.object(Path, "is_symlink", return_value=True), self.assertRaises(MuseumError):
                capture._read_input(path, 4)

    def test_cli_replay_profiles_verify_and_atomic_destination(self):
        with TemporaryDirectory() as temporary:
            root = Path(temporary); anchor = root / "anchor.json"; transcript = root / "transcript.json"; output = root / "out"
            anchor.write_bytes(self.inputs[0]); transcript.write_bytes(self.inputs[3])
            args = ["replay", "--anchor", str(anchor), "--anchor-hash", self.inputs[1],
                "--source-profile-hash", self.inputs[2], "--transcript", str(transcript), "--transcript-hash", self.inputs[4],
                "--provenance", "synthetic_fixture", "--disclosure", "public", "--output", str(output)]
            stdout = io.StringIO()
            with redirect_stdout(stdout), patch("socket.socket", side_effect=AssertionError("offline only")):
                capture.main(args)
            self.assertEqual(loads(stdout.getvalue().encode())["manifestHash"], self.result.manifest_hash)
            self.assertEqual(read_tree(output), dict(self.result.files))
            with redirect_stdout(io.StringIO()), patch("socket.socket", side_effect=AssertionError("offline only")):
                capture.main(["verify", str(output), "--manifest-hash", self.result.manifest_hash])
            with self.assertRaisesRegex(MuseumError, "new directory"): capture.main(args)
            self.assertEqual(read_tree(output), dict(self.result.files))
        stdout = io.StringIO()
        with redirect_stdout(stdout): capture.main(["profiles"])
        self.assertEqual(loads(stdout.getvalue().encode()), {"captureProfileHash": capture.PROFILE_HASH, "sourceProfileHash": self.inputs[2]})


if __name__ == "__main__": unittest.main()
