"""Concrete synthetic personhood capture replay; no legal or chain acceptance claim."""
from contextlib import redirect_stdout
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import public_personhood_capture as capture
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .public_history_rpc import PublicRpcTransport
from .test_public_personhood_source import PublicPersonhoodFixture


class PublicPersonhoodCaptureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = PublicPersonhoodFixture()
        adapter = cls.fixture.source(); snapshot = adapter.snapshot(); transcript = adapter.transcript()
        cls.snapshot = loads(snapshot, maximum=64 * 1024 * 1024)
        cls.inputs = (adapter.anchor_bytes, keccak256(adapter.anchor_bytes), capture._source().PROFILE_HASH,
            transcript, keccak256(transcript))
        cls.result = capture.replay(*cls.inputs, provenance="synthetic_fixture", disclosure="public")

    @staticmethod
    def repin(files):
        manifest = loads(files["manifest.json"], maximum=1024 * 1024)
        manifest["files"] = [capture.base._ref(path, raw) for path, raw in sorted(files.items())
            if path != "manifest.json"]
        files["manifest.json"] = dumps(manifest)
        return keccak256(files["manifest.json"])

    def test_exact_current_native_documentary_and_identity_domains_retained(self):
        files, report = dict(self.result.files), self.result.report
        self.assertEqual(files["source/anchor.json"], self.inputs[0])
        self.assertEqual(files["source/transcript.json"], self.inputs[3])
        self.assertEqual(loads(files["source/snapshot.json"], maximum=64 * 1024 * 1024), self.snapshot)
        for name in ("graph", "current", "native", "documentary"):
            self.assertEqual(loads(files["personhood/" + name + ".json"], maximum=64 * 1024 * 1024),
                self.snapshot[name])
            self.assertEqual(report[name], self.snapshot[name])
        self.assertNotEqual(report["current"]["registrationIdentityRecordHash"],
            report["current"]["operativeIdentityRecordHash"])
        self.assertEqual(report["native"]["record"][1], self.fixture.operative)
        self.assertEqual(report["native"]["recordPreimageHex"], "0x" + self.fixture.native_preimage.hex())
        self.assertFalse(report["claims"]["legalPersonhoodProven"])
        self.assertFalse(report["claims"]["providerExecutionEstablished"])

    def test_all_current_statuses_remain_distinct_and_replayable(self):
        expected = {"none": "NONE", "waiver": "WAIVER", "resolved": "RESOLVED",
            "legacy": "UNRESOLVED", "stale_head": "STALE", "imported": "RESOLVED",
            "imported_waiver": "WAIVER"}
        for mode, status in expected.items():
            fixture = PublicPersonhoodFixture(mode=mode); adapter = fixture.source()
            adapter.snapshot(); transcript = adapter.transcript()
            result = capture.replay(adapter.anchor_bytes, keccak256(adapter.anchor_bytes), capture._source().PROFILE_HASH,
                transcript, keccak256(transcript), provenance="synthetic_fixture", disclosure="public")
            with self.subTest(mode=mode):
                self.assertEqual(result.report["current"]["status"], status)
                if mode == "none":
                    self.assertIsNone(result.report["native"])
                    self.assertIsNone(result.report["documentary"])
                elif mode in ("waiver", "imported_waiver", "legacy"):
                    self.assertIsNone(result.report["documentary"])
                else: self.assertIsNotNone(result.report["documentary"])

    def test_offline_reconstruction_and_common_dispatch(self):
        from .package_v2 import verify_package
        with patch("socket.socket", side_effect=AssertionError("offline only")):
            self.assertEqual(capture.verify(dict(self.result.files), self.result.manifest_hash).files,
                self.result.files)
            with TemporaryDirectory() as temp:
                root = Path(temp) / "personhood"; write_tree(dict(self.result.files), root)
                self.assertEqual(verify_package(root, self.result.manifest_hash).files, self.result.files)

    def test_rehashed_sidecars_and_source_bytes_cannot_replace_replay(self):
        for path in ("personhood/current.json", "personhood/native.json", "personhood/documentary.json",
                "source/snapshot.json"):
            files = dict(self.result.files); value = loads(files[path], maximum=64 * 1024 * 1024)
            if isinstance(value, dict): value["callerComplete"] = True
            else: value = {"callerComplete": True}
            files[path] = dumps(value)
            with self.subTest(path=path), self.assertRaisesRegex(MuseumError, "reconstruction differs"):
                capture.verify(files, self.repin(files))

    def test_external_pins_provenance_and_public_preflight(self):
        with self.assertRaises(MuseumError):
            capture.replay(*self.inputs, provenance="trusted_rpc", disclosure="public")
        with self.assertRaises(MuseumError):
            capture.replay(self.inputs[0], keccak256(self.inputs[0]), capture._source().PROFILE_HASH,
                self.inputs[3], self.inputs[4], provenance="synthetic_fixture", disclosure="restricted")
        for index, value in ((1, "0x" + "01" * 32), (2, "0x" + "02" * 32), (4, "0x" + "03" * 32)):
            args = list(self.inputs); args[index] = value
            with self.subTest(index=index), self.assertRaises(MuseumError):
                capture.replay(*args, provenance="synthetic_fixture", disclosure="public")

    def test_source_profile_and_runtime_pin_fail_closed_before_derived_output(self):
        fixture = PublicPersonhoodFixture(); adapter = fixture.source(); adapter.snapshot()
        transcript = adapter.transcript(); anchor = loads(adapter.anchor_bytes, maximum=65536)
        next(row for row in anchor["codePins"] if row["address"] == anchor["artistRegistry"])["runtimeHash"] = \
            "0x" + "12" * 32
        raw = dumps(anchor)
        with self.assertRaises(MuseumError):
            capture.replay(raw, keccak256(raw), capture._source().PROFILE_HASH, transcript,
                keccak256(transcript), provenance="synthetic_fixture", disclosure="public")
        with self.assertRaisesRegex(MuseumError, "source profile"):
            capture.replay(adapter.anchor_bytes, keccak256(adapter.anchor_bytes), "0x" + "34" * 32,
                transcript, keccak256(transcript), provenance="synthetic_fixture", disclosure="public")

    def test_cli_replay_verify_profiles_and_atomic_destination(self):
        with TemporaryDirectory() as temp:
            root = Path(temp); anchor = root / "anchor.json"; transcript = root / "transcript.json"
            anchor.write_bytes(self.inputs[0]); transcript.write_bytes(self.inputs[3]); output = root / "out"
            argv = ["replay", "--anchor", str(anchor), "--anchor-hash", self.inputs[1],
                "--source-profile-hash", self.inputs[2], "--transcript", str(transcript),
                "--transcript-hash", self.inputs[4], "--provenance", "synthetic_fixture",
                "--disclosure", "public", "--output", str(output)]
            stdout = io.StringIO()
            with redirect_stdout(stdout), patch("socket.socket", side_effect=AssertionError("offline only")):
                capture.main(argv)
            message = loads(stdout.getvalue().encode())
            self.assertEqual(message["manifestHash"], self.result.manifest_hash)
            self.assertEqual(read_tree(output), dict(self.result.files))
            with patch("socket.socket", side_effect=AssertionError("offline only")):
                capture.main(["verify", str(output), "--manifest-hash", self.result.manifest_hash])
            before = read_tree(output)
            with self.assertRaisesRegex(MuseumError, "new directory"):
                capture.main(argv)
            self.assertEqual(read_tree(output), before)
        stdout = io.StringIO()
        with redirect_stdout(stdout): capture.main(["profiles"])
        self.assertEqual(loads(stdout.getvalue().encode()),
            {"captureProfileHash": capture.PROFILE_HASH, "sourceProfileHash": self.inputs[2]})

    def test_capture_transport_requires_explicit_admitted_runtime_and_no_network_fallback(self):
        with patch.object(PublicRpcTransport, "request", side_effect=AssertionError("reject before RPC")), \
                self.assertRaises(MuseumError):
            capture.capture(self.inputs[0], self.inputs[1], self.inputs[2],
                PublicRpcTransport("https://example.invalid"), disclosure="public")

    def test_cli_rejects_closed_anchor_and_runtime_admission_before_endpoint_lookup(self):
        fixture = PublicPersonhoodFixture()
        for mode in ("extra", "synthetic"):
            anchor = loads(fixture.source().anchor_bytes, maximum=65536)
            if mode == "extra":
                anchor["runtimeAdmission"]["kind"] = "externally_admitted_runtime"
                anchor["callerComplete"] = True
            raw = dumps(anchor)
            with TemporaryDirectory() as temp:
                root = Path(temp); path = root / "anchor.json"; path.write_bytes(raw)
                argv = ["capture", "--anchor", str(path), "--anchor-hash", keccak256(raw),
                    "--source-profile-hash", capture._source().PROFILE_HASH,
                    "--rpc-env", "PERSONHOOD_TEST_RPC", "--disclosure", "public",
                    "--output", str(root / "out")]
                getter = capture.os.environ.get
                def guarded(name, default=None):
                    if name == "PERSONHOOD_TEST_RPC":
                        raise AssertionError("endpoint read before closed source admission")
                    return getter(name, default)
                with self.subTest(mode=mode), patch.object(capture.os.environ, "get", side_effect=guarded), \
                        self.assertRaises(MuseumError):
                    capture.main(argv)


if __name__ == "__main__": unittest.main()
