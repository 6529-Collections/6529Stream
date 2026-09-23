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

from . import public_condition_capture as capture
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .public_history_rpc import PublicRpcTransport
from .test_public_condition_source import PublicConditionFixture


class PublicConditionCaptureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = PublicConditionFixture()
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

    def test_exact_catalogue_lanes_originals_selections_and_partial_nineteen_item_report(self):
        files = dict(self.result.files); report = self.result.report
        self.assertEqual(files["source/anchor.json"], self.inputs[0])
        self.assertEqual(files["source/transcript.json"], self.inputs[3])
        self.assertEqual(loads(files["source/snapshot.json"], maximum=64 * 1024 * 1024), self.snapshot)
        evidence = loads(files["condition/evidence.json"], maximum=64 * 1024 * 1024)
        for key in ("sourceState", "binding", "sourceReviewCommit", "coreSourceReviewCommit", "historyCoverage", "claims", "qualification"):
            self.assertEqual(evidence[key], self.snapshot[key])
        self.assertEqual(loads(files["condition/original-records.json"], maximum=64 * 1024 * 1024), self.snapshot["records"])
        for key in ("catalogue", "lanes", "documents", "selections"):
            self.assertEqual(loads(files["condition/" + key + ".json"], maximum=64 * 1024 * 1024), self.snapshot[key])
        self.assertEqual([row["item"] for row in report["items"]], [str(i) for i in range(1, 20)])
        self.assertEqual([row["status"] for row in report["items"]], ["partial" if i == 15 else "unresolved" for i in range(1, 20)])
        self.assertFalse(any(row["canonicalPacketCompatible"] for row in report["items"]))
        self.assertFalse(report["canonicalPacketCompatible"])
        self.assertFalse(report["completeCanonicalPacket"])
        self.assertEqual(report["item15"]["missingJoins"], capture.MISSING_JOINS)
        self.assertEqual(report["provenance"], "synthetic_fixture")
        for key in ("examinationStateProven", "finalityRouteProven", "fixityCoverageProven", "renderAcceptanceProven",
                "captureFixityProven", "examinerIdentityProven", "sourceConsensusVerified", "actualChainAcceptance"):
            self.assertFalse(report["claims"][key])
        self.assertEqual(set(self.snapshot["selections"]), {"owner", "independent"})
        self.assertEqual(report["laneStatuses"], {lane: row["status"] for lane, row in self.snapshot["selections"].items()})
        self.assertEqual(report["laneStatuses"], {"owner": "present", "independent": "present"})
        for selected in self.snapshot["selections"].values():
            self.assertIsNotNone(selected["selected"])
            self.assertIsNotNone(selected["interpretation"]["value"])
        self.assertEqual(self.snapshot["selections"]["owner"]["interpretation"]["value"]["captures"], [])
        self.assertTrue(any(not row["matchesToken"] for row in self.snapshot["records"]))
        self.assertTrue(any(int(row["replacesSourceId"]) > 0 for row in self.snapshot["catalogue"]["sources"]))

    def test_offline_reconstruction_and_common_dispatch(self):
        from .package_v2 import verify_package
        with patch("socket.socket", side_effect=AssertionError("offline only")):
            self.assertEqual(capture.verify(dict(self.result.files), self.result.manifest_hash).files, self.result.files)
            with TemporaryDirectory() as temp:
                root = Path(temp) / "capture"; write_tree(dict(self.result.files), root)
                self.assertEqual(verify_package(root, self.result.manifest_hash).files, self.result.files)

    def test_empty_canonical_lanes_keep_scoped_absence_and_incomplete_item(self):
        source = PublicConditionFixture(empty=True).source(); snapshot = source.snapshot()
        transcript = source.transcript()
        result = capture.replay(source.anchor_bytes, keccak256(source.anchor_bytes), capture._source().PROFILE_HASH,
            transcript, keccak256(transcript), provenance="synthetic_fixture", disclosure="public")
        original = loads(snapshot, maximum=64 * 1024 * 1024)
        self.assertEqual(original["records"], [])
        self.assertEqual(loads(dict(result.files)["condition/selections.json"], maximum=64 * 1024 * 1024), original["selections"])
        self.assertEqual(result.report["laneStatuses"], {"owner": "none_recorded", "independent": "none_recorded"})
        for row in original["selections"].values(): self.assertIsNone(row["selected"])
        self.assertEqual(result.report["item15"]["status"], "partial")
        self.assertEqual(result.report["item15"]["missingJoins"], capture.MISSING_JOINS)
        self.assertFalse(result.report["claims"]["examinationStateProven"])
        self.assertFalse(result.report["canonicalPacketCompatible"])

    def test_unsupported_or_malformed_newest_retained_without_older_fallback(self):
        for mode in ("unsupported_newest", "malformed_newest"):
            with self.subTest(mode=mode):
                source = PublicConditionFixture(**{mode: True}).source(); snapshot = source.snapshot()
                transcript = source.transcript()
                result = capture.replay(source.anchor_bytes, keccak256(source.anchor_bytes), capture._source().PROFILE_HASH,
                    transcript, keccak256(transcript), provenance="synthetic_fixture", disclosure="public")
                original = loads(snapshot, maximum=64 * 1024 * 1024)
                files = dict(result.files); selected = loads(files["condition/selections.json"], maximum=64 * 1024 * 1024)
                self.assertEqual(selected, original["selections"])
                unresolved = [row for row in selected.values() if row["status"] == "selected_unresolved"]
                self.assertTrue(unresolved)
                for row in unresolved:
                    self.assertIsNotNone(row["selected"])
                    if row["interpretation"] is not None:
                        self.assertIsNone(row["interpretation"]["value"])
                        self.assertTrue(row["interpretation"]["reasonCode"])
                self.assertEqual(loads(files["condition/original-records.json"], maximum=64 * 1024 * 1024), original["records"])
                lane = next(lane for lane, row in selected.items() if row["status"] == "selected_unresolved")
                selected[lane] = {"status": "none_recorded", "selected": None, "interpretation": None}
                files["condition/selections.json"] = dumps(selected)
                with self.assertRaisesRegex(MuseumError, "reconstruction differs"): capture.verify(files, self.repin(files))

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
        for name in ("source/snapshot.json", "condition/evidence.json", "condition/original-records.json",
                "condition/catalogue.json", "condition/lanes.json", "condition/documents.json", "condition/selections.json",
                "capture/report.json", "definitions/source-profile.json",
                "definitions/history-profile.json", "definitions/rpc-profile.json", "definitions/capture-profile.json"):
            files = dict(self.result.files); files[name] += b"\n"
            with self.subTest(name=name), self.assertRaisesRegex(MuseumError, "reconstruction differs"):
                capture.verify(files, self.repin(files))
        files = dict(self.result.files); report = loads(files["capture/report.json"], maximum=1024 * 1024)
        report["item15"].update(status="complete", canonicalPacketCompatible=True)
        report.update(canonicalPacketCompatible=True, completeCanonicalPacket=True)
        files["capture/report.json"] = dumps(report)
        with self.assertRaisesRegex(MuseumError, "reconstruction differs"): capture.verify(files, self.repin(files))

    def test_closed_manifest_provenance_and_exact_file_inventory(self):
        for change in (lambda v: v.update(provenance="trusted_rpc"), lambda v: v.update(extra=True),
                lambda v: v.update(mode="public_native_history_capture"),
                lambda v: v["claims"].update(examinationStateProven=True),
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
        fixture = PublicConditionFixture(); raw = dumps(fixture.a)
        endpoint = "https://example.invalid/private-condition-test-key"
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

    def argv(self, anchor, output, command="capture", **changes):
        args = {"anchor": str(anchor), "anchor-hash": self.inputs[1], "source-profile-hash": self.inputs[2],
            "disclosure": "public", "output": str(output)}
        if command == "capture": args["rpc-env"] = "PUBLIC_CONDITION_TEST_RPC"
        args.update(changes)
        return ["public_condition_capture", command, *[x for key, value in args.items() for x in ("--" + key, value)]]

    def test_cli_preflight_rejects_before_endpoint_reads_and_publication(self):
        getter = capture.os.environ.get
        def guarded(name, default=None):
            if name == "PUBLIC_CONDITION_TEST_RPC": raise AssertionError("endpoint read during failed preflight")
            return getter(name, default)
        with TemporaryDirectory() as temp:
            root = Path(temp); anchor = root / "anchor.json"; raw = self.inputs[0]; anchor.write_bytes(raw)
            output = root / "out"; existing = root / "existing"; existing.mkdir()
            bad = root / "bad.json"; wrong = dumps(loads(raw) | {"selectedRevisions": []}); bad.write_bytes(wrong)
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
            self.assertEqual(message["item15Status"], "partial")
            self.assertFalse(message["canonicalPacketCompatible"])
            with patch("sys.argv", ["public_condition_capture", "verify", str(output), "--manifest-hash", message["manifestHash"]]), \
                    redirect_stdout(io.StringIO()), patch("socket.socket", side_effect=AssertionError("offline only")):
                capture.main()
            with patch("sys.argv", args), self.assertRaisesRegex(MuseumError, "new directory"): capture.main()
            self.assertEqual(read_tree(output), before)
        output = io.StringIO()
        with patch("sys.argv", ["public_condition_capture", "profiles"]), redirect_stdout(output), \
                patch("socket.socket", side_effect=AssertionError("offline only")):
            capture.main()
        self.assertEqual(loads(output.getvalue().encode()), {"captureProfileHash": capture.PROFILE_HASH, "sourceProfileHash": self.inputs[2]})

    def test_cli_mock_live_capture_and_failed_query_publish_atomically(self):
        with TemporaryDirectory() as temp:
            root = Path(temp); anchor = root / "anchor.json"; anchor.write_bytes(self.inputs[0])
            fixture = PublicConditionFixture(); output = root / "out"; stdout = io.StringIO()
            with patch("sys.argv", self.argv(anchor, output)), redirect_stdout(stdout), \
                    patch.dict(capture.os.environ, {"PUBLIC_CONDITION_TEST_RPC": "https://example.invalid"}), \
                    patch.object(PublicRpcTransport, "request", side_effect=fixture.request), \
                    patch("socket.socket", side_effect=AssertionError("synthetic only")):
                capture.main()
            message = loads(stdout.getvalue().encode()); files = read_tree(output)
            self.assertEqual(message["manifestHash"], keccak256(files["manifest.json"]))
            self.assertEqual(message["provenance"], "trusted_rpc")
            failed = root / "failed"
            with patch("sys.argv", self.argv(anchor, failed)), \
                    patch.dict(capture.os.environ, {"PUBLIC_CONDITION_TEST_RPC": "https://example.invalid"}), \
                    patch.object(PublicRpcTransport, "request", side_effect=MuseumError("historical provider unavailable")), \
                    self.assertRaisesRegex(MuseumError, "provider unavailable"):
                capture.main()
            self.assertFalse(failed.exists())

    def test_transport_failure_traceback_does_not_disclose_endpoint_or_remote_message(self):
        secret = "private-condition-credential-in-url-or-server-line"
        with TemporaryDirectory() as temp:
            root = Path(temp); anchor = root / "anchor.json"; anchor.write_bytes(self.inputs[0]); output = root / "out"
            with patch("sys.argv", self.argv(anchor, output)), \
                    patch.dict(capture.os.environ, {"PUBLIC_CONDITION_TEST_RPC": "https://example.invalid/" + secret}), \
                    patch("urllib.request.build_opener") as opener:
                opener.return_value.open.side_effect = http.client.InvalidURL(secret)
                try: capture.main()
                except MuseumError as exc: rendered = "".join(traceback.format_exception(exc))
                else: self.fail("expected sanitized transport failure")
            self.assertNotIn(secret, rendered)
            self.assertIn("public RPC transport failed", rendered)
            self.assertFalse(output.exists())


if __name__ == "__main__": unittest.main()
