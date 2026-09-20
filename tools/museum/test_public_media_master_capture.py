"""Concrete synthetic media-master capture and exact offline reconstruction controls."""
from contextlib import redirect_stdout
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import public_media_master_capture as capture
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .independent_wire import ZERO
from .public_history_rpc import PublicRpcTransport
from .test_public_media_master_source import PublicMediaMasterFixture


class PublicMediaMasterCaptureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = PublicMediaMasterFixture()
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

    def test_exact_source_originals_native_definitions_and_derivatives(self):
        files=dict(self.result.files)
        self.assertEqual(files["source/anchor.json"],self.inputs[0])
        self.assertEqual(files["source/transcript.json"],self.inputs[3])
        self.assertEqual(files["source/snapshot.json"],self.snapshot_raw)
        for key in ("mediaContext","slots","manifests","manifestSelections","records","coverage","historicalCandidates"):
            self.assertEqual(files["media-master/"+key+".json"],dumps(self.snapshot[key]))
        self.assertEqual(files["media-master/evidence.json"],dumps({key:self.snapshot[key] for key in
            ("source","sourceReviewCommit","sourceState","binding","currentAssociation","historyCoverage","claims","qualification")}))
        for name,raw in capture._source().DEFINITIONS.items():self.assertEqual(files["definitions/native/"+name+".json"],raw)

    def test_all_modes_keep_recorded_status_separate_from_current_and_historical(self):
        for mode in ("present","waived","empty","absent","replaced","manifest_changed"):
            with self.subTest(mode=mode):
                result=PublicMediaMasterFixture(mode).media_capture()
                snapshot=loads(dict(result.files)["source/snapshot.json"],maximum=64*1024*1024)
                self.assertEqual(result.report["slots"],snapshot["slots"])
                self.assertEqual(result.report["historicalCandidates"],snapshot["historicalCandidates"])
                self.assertEqual(capture.verify(result.files,result.manifest_hash).files,result.files)
                if mode=="empty":self.assertEqual(snapshot["historicalCandidates"][0]["scope"],"source_block_only")
                if mode=="waived":self.assertEqual(snapshot["coverage"],[])
                if mode=="replaced":self.assertEqual(len(snapshot["historicalCandidates"]),2)
                if mode=="manifest_changed":self.assertIn("historical_manifest",snapshot["slots"]["1"]["currentEligibility"]["reasons"])

    def test_source_and_archive_claims_remain_qualified(self):
        report=self.result.report
        self.assertEqual(report["provenance"],"synthetic_fixture")
        self.assertFalse(report["canonicalPacketCompatible"])
        self.assertFalse(report["completeCanonicalPacket"])
        for key in ("currentArchiveLivenessChecked","archiveRetrievalProven","institutionalStandingProven",
                "sourceProvenanceSelfAuthenticated","sourceConsensusVerified","actualChainAcceptance",
                "canonicalPacketCompatible","completeCanonicalPacket","endpointRetained"):
            self.assertFalse(report["claims"][key],key)
        self.assertEqual(report["historyCoverage"],self.snapshot["historyCoverage"])

    def test_offline_exact_reconstruction_and_common_dispatch(self):
        from .package_v2 import verify_package
        with patch("socket.socket", side_effect=AssertionError("offline only")):
            self.assertEqual(capture.verify(self.result.files, self.result.manifest_hash).files, self.result.files)
            with TemporaryDirectory() as temporary:
                path = Path(temporary) / "captured"; write_tree(dict(self.result.files), path)
                self.assertEqual(verify_package(path, self.result.manifest_hash).files, self.result.files)

    def test_rehashed_sidecars_snapshot_and_extra_file_cannot_replace_replay(self):
        for path in ("media-master/mediaContext.json", "media-master/slots.json", "media-master/manifestSelections.json",
                "media-master/coverage.json", "media-master/evidence.json", "source/snapshot.json", "definitions/native/"+capture._source().MASTER_NAME+".json", "caller-extra.json"):
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
                    "--source-profile-hash", self.inputs[2], "--rpc-env", "UNREAD_MEDIA_MASTER_RPC",
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
                    if name == "MEDIA_MASTER_TEST_RPC": raise AssertionError("endpoint read before closed source preflight")
                    return original(name, default)
                with patch.object(capture.os.environ, "get", side_effect=guarded), self.assertRaises(MuseumError):
                    capture.main(["capture", "--anchor", str(path), "--anchor-hash", keccak256(raw),
                        "--source-profile-hash", self.inputs[2], "--rpc-env", "MEDIA_MASTER_TEST_RPC",
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
