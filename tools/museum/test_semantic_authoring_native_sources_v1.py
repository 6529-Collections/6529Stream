"""Focused offline tests for the additive native authoring envelope."""

import copy
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from . import attribution_dossier
from . import package_v2
from . import semantic_authoring_capture_v1 as capture
from . import semantic_authoring_native_sources_v1 as native
from . import test_artist_attestation_source as artist_test
from .bagit import write_tree
from .canonical import MuseumError, dumps, keccak256, loads, subject_id
from .citations import canonical_citation
from .test_metadata_catalog_source import A
from .test_native_attribution_source import Fixture as SemanticFixture


def _rehash_source(files):
    value = loads(files["manifest.json"], maximum=attribution_dossier.MAX_MANIFEST)
    value["files"] = [{"path": path, "bytes": str(len(raw)), "hash": keccak256(raw)}
        for path, raw in sorted(files.items()) if path != "manifest.json"]
    files["manifest.json"] = dumps(value)
    return keccak256(files["manifest.json"])


def _rehash_package(files):
    value = loads(files["manifest.json"], maximum=attribution_dossier.MAX_MANIFEST)
    from .object_dossier import _ref
    value["files"] = [_ref(path, raw) for path, raw in sorted(files.items())
        if path != "manifest.json"]
    files["manifest.json"] = dumps(value)
    return keccak256(files["manifest.json"])


def _form(work_id):
    author = {"entityId": "urn:example:author:one", "kind": "person",
        "names": [{"value": "Source author declaration", "language": "en",
            "kind": "preferred"}]}
    return dumps({"version": "1", "purpose": "later_documentation",
        "draftId": "urn:example:draft:native-one", "workId": work_id,
        "rootKind": "token", "sourceAuthor": author,
        "sourceVersionIds": {"originalText": "urn:example:text:original",
            "title": "urn:example:text:title", "creatorCredit": None,
            "mediumDescription": None, "placeName": None, "eventAccount": None},
        "timestamp": "2026-09-22T00:00:00Z", "language": "en",
        "originalText": "Exact author supplied text.\nWhitespace remains exact.",
        "title": "A caller supplied draft title", "creatorCredit": None,
        "mediumDescription": None, "placeName": None, "eventAccount": None})


def _token_source(*, disputed=True, rotated=True):
    token_id = "71"
    token_subject = subject_id("token", "31337", A(2), "7", token_id=token_id)
    original_pair = artist_test.record_pair

    def token_pair(**kwargs):
        kwargs.setdefault("subject", token_subject)
        return original_pair(**kwargs)

    def token_anchor(value):
        value["anchorSubject"] = {"kind": "token", "subjectId": token_subject}

    with patch.object(artist_test, "record_pair", token_pair):
        fixture = SemanticFixture(mutate=token_anchor, disputed=disputed, rotated=rotated)
    semantic = fixture.semantic()
    files = attribution_dossier.build_files(semantic.artist, semantic=semantic)
    snapshot = loads(files["semantics/snapshot.json"], maximum=attribution_dossier.MAX_BYTES)
    selector = snapshot["statements"][0]["source"]
    source_hash = keccak256(files["manifest.json"])
    plan_raw = dumps({"version": "1", "kind": native.PLAN_KIND,
        "manifestHash": source_hash, "semanticSourceSelector": selector,
        "tokenId": token_id})
    draft_raw = capture.capture(_form(canonical_citation("31337", A(2), token_id)))
    return {"fixture": fixture, "files": files, "sourceHash": source_hash,
        "snapshot": snapshot, "selector": selector, "tokenId": token_id,
        "plan": plan_raw, "planHash": keccak256(plan_raw), "draft": draft_raw}


class NativeAuthoringSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.case = _token_source()
        cls.result = native.compose(cls.case["draft"], cls.case["files"],
            cls.case["sourceHash"], cls.case["plan"], cls.case["planHash"],
            disclosure="public")

    def test_complete_native_replay_binds_exact_token_subject_without_mutating_draft(self):
        result = native.verify(dict(self.result.files), self.result.manifest_hash)
        files = dict(result.files)
        self.assertEqual(files[native.DRAFT_PATH], self.case["draft"])
        self.assertIsNone(loads(files[native.DRAFT_PATH], maximum=524288)["recordBinding"])
        envelope = loads(files[native.ENVELOPE_PATH], maximum=attribution_dossier.MAX_MANIFEST)
        expected = subject_id("token", "31337", A(2), "7", token_id="71")
        self.assertEqual(envelope["subject"]["subjectId"], expected)
        self.assertEqual(envelope["subject"]["workCitation"], canonical_citation("31337", A(2), "71"))
        self.assertEqual(envelope["semanticSourceSelector"], self.case["selector"])
        self.assertEqual(envelope["draftBinding"], None)
        self.assertFalse(envelope["subject"]["tokenExistenceProven"])
        self.assertFalse(envelope["claims"]["coreTokenMembershipProven"])

    def test_disputed_and_rotated_current_state_is_retained_without_authority_promotion(self):
        envelope = loads(dict(self.result.files)[native.ENVELOPE_PATH],
            maximum=attribution_dossier.MAX_MANIFEST)
        current = envelope["originalEvidence"]["currentQualification"]
        history = envelope["originalEvidence"]["historicalAuthority"]
        self.assertEqual(current["attestationStatus"][0], "3")
        self.assertNotEqual(current["identity"][0], history["signer"])
        self.assertFalse(envelope["claims"]["currentArtistAuthorizationProven"])
        self.assertFalse(envelope["claims"]["artistConfirmationProven"])
        self.assertFalse(envelope["claims"]["sourceAuthorCorrespondenceProven"])

    def test_exact_plan_selector_token_and_draft_citation_are_required(self):
        changes = {
            "selector": lambda plan, draft: plan["semanticSourceSelector"].__setitem__(
                "recordHash", "0x" + "11" * 32),
            "token": lambda plan, draft: plan.__setitem__("tokenId", "72"),
            "citation": lambda plan, draft: draft.__setitem__("workId",
                canonical_citation("31337", A(2), "72")),
        }
        for name, change in changes.items():
            plan = loads(self.case["plan"]); draft = loads(self.case["draft"], maximum=524288)
            change(plan, draft); plan_raw, draft_raw = dumps(plan), dumps(draft)
            if name == "citation":
                draft["entities"][0]["entityId"] = draft["workId"]
                draft_raw = dumps(draft)
            with self.subTest(change=name), self.assertRaises(MuseumError):
                native.compose(draft_raw, self.case["files"], self.case["sourceHash"],
                    plan_raw, keccak256(plan_raw), disclosure="public")

    def test_collection_source_is_not_cast_as_token(self):
        fixture = SemanticFixture()
        semantic = fixture.semantic()
        files = attribution_dossier.build_files(semantic.artist, semantic=semantic)
        source_hash = keccak256(files["manifest.json"])
        snapshot = loads(files["semantics/snapshot.json"], maximum=attribution_dossier.MAX_BYTES)
        plan = dumps({"version": "1", "kind": native.PLAN_KIND,
            "manifestHash": source_hash, "semanticSourceSelector": snapshot["statements"][0]["source"],
            "tokenId": "71"})
        with self.assertRaisesRegex(MuseumError, "collection subject cannot bind"):
            native.bind(self.case["draft"], files, source_hash, plan, keccak256(plan),
                disclosure="public")

    def test_source_and_outer_derived_tampering_cannot_be_rehashed_into_validity(self):
        source = copy.deepcopy(self.case["files"])
        value = loads(source["semantics/snapshot.json"], maximum=attribution_dossier.MAX_BYTES)
        value["statements"][0]["currentQualification"]["qualification"] = "invented fresh authority"
        source["semantics/snapshot.json"] = dumps(value)
        source_hash = _rehash_source(source)
        plan = loads(self.case["plan"]); plan["manifestHash"] = source_hash
        plan_raw = dumps(plan)
        with self.assertRaisesRegex(MuseumError, "replay differs"):
            native.compose(self.case["draft"], source, source_hash, plan_raw,
                keccak256(plan_raw), disclosure="public")

        for path in (native.ENVELOPE_PATH, "report.json"):
            files = dict(self.result.files); value = loads(files[path], maximum=attribution_dossier.MAX_MANIFEST)
            value["invented"] = True; files[path] = dumps(value)
            digest = _rehash_package(files)
            with self.subTest(path=path), self.assertRaises(MuseumError):
                native.verify(files, digest)

    def test_wrong_external_pins_and_extra_files_reject(self):
        with self.assertRaisesRegex(MuseumError, "external manifest"):
            native.verify(dict(self.result.files), "0x" + "11" * 32)
        files = dict(self.result.files); files["extra.json"] = b"{}"
        with self.assertRaises(MuseumError):
            native.verify(files, _rehash_package(files))
        with self.assertRaisesRegex(MuseumError, "plan pin"):
            native.bind(self.case["draft"], self.case["files"], self.case["sourceHash"],
                self.case["plan"], "0x" + "22" * 32, disclosure="public")

    def test_public_guard_precedes_malformed_input_inspection(self):
        with self.assertRaisesRegex(MuseumError, "public disclosure required before reads"):
            native.compose(b"not json", {"not": "bytes"}, "bad", b"bad", "bad",
                disclosure="restricted")

    def test_verification_reads_only_retained_model_dependencies(self):
        repository_model = Path(native.MODEL_ROOT).resolve()
        original = Path.read_bytes

        def retained_only(path):
            resolved = path.resolve()
            if resolved == repository_model or resolved.is_relative_to(repository_model):
                raise AssertionError("repository model read during portable verify")
            return original(path)

        with patch.object(Path, "read_bytes", retained_only), \
                patch("socket.socket", side_effect=AssertionError("network forbidden")):
            self.assertEqual(native.verify(dict(self.result.files), self.result.manifest_hash),
                self.result)

    def test_cli_and_generic_dispatch_reopen_exact_package_without_network(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); draft = root / "draft.json"; plan = root / "plan.json"
            source = root / "source"; output = root / "bound"
            draft.write_bytes(self.case["draft"]); plan.write_bytes(self.case["plan"])
            write_tree(self.case["files"], source)
            argv = ["bind", "--draft", str(draft), "--source", str(source),
                "--source-manifest-hash", self.case["sourceHash"], "--plan", str(plan),
                "--plan-hash", self.case["planHash"], "--disclosure", "public",
                "--output", str(output)]
            with patch("socket.socket", side_effect=AssertionError("network forbidden")), \
                    patch("sys.stdout", new_callable=io.StringIO) as stdout:
                native.main(argv)
            result = loads(stdout.getvalue().encode(), maximum=attribution_dossier.MAX_MANIFEST)
            pin = result["manifestHash"]
            with patch("socket.socket", side_effect=AssertionError("network forbidden")):
                reopened = package_v2.verify_package(output, pin)
            self.assertEqual(reopened, native.verify(dict(reopened.files), pin))
            with self.assertRaises(SystemExit):
                native.main(argv)


if __name__ == "__main__":
    unittest.main()
