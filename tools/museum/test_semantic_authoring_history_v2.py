"""Focused concrete-source tests for portable authoring history V2."""

import copy
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from . import package_v2
from . import semantic_authoring_capture_v1 as capture
from . import semantic_authoring_history_v2 as history
from .bagit import write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .citations import canonical_citation
from .test_metadata_catalog_source import A
from .test_semantic_authoring_current_sources_v2 import general_case, owner_v4_case


def _form(work_id):
    author = {"entityId": "urn:example:history:author", "kind": "person",
        "names": [{"value": "Declared draft author", "language": "en", "kind": "preferred"}]}
    return dumps({"version": "1", "purpose": "later_documentation",
        "draftId": "urn:example:history:draft", "workId": work_id, "rootKind": "token",
        "sourceAuthor": author, "sourceVersionIds": {
            "originalText": "urn:example:history:text", "title": "urn:example:history:title",
            "creatorCredit": None, "mediumDescription": None, "placeName": None,
            "eventAccount": None}, "timestamp": "2026-09-22T00:00:00Z", "language": "en",
        "originalText": "Caller supplied source text.\nExact whitespace is retained.",
        "title": "Caller supplied title", "creatorCredit": None,
        "mediumDescription": None, "placeName": None, "eventAccount": None})


def _with_relationship(raw):
    value = loads(raw, maximum=524288)
    value["entities"].append({"entityId": "urn:example:history:document", "kind": "information_object",
        "names": [{"value": "Declared document", "language": "en", "kind": "preferred"}]})
    value["relationships"].append({"relationshipId": "urn:example:history:relationship",
        "type": "documents", "subjectId": value["workId"],
        "objectId": "urn:example:history:document", "role": None,
        "sourceVersionId": "urn:example:history:text",
        "mappedBy": value["sourceAuthor"]["entityId"], "rationale": "Initial mapping rationale"})
    result = dumps(value); history._admit(result)
    return result


def _next(raw, change, revised_at="2026-09-22T01:00:00Z"):
    value = loads(raw, maximum=524288)
    value["revision"] = str(int(value["revision"]) + 1)
    value["previousRevisionHash"] = keccak256(raw)
    value["revisedAt"] = revised_at
    change(value)
    return dumps(value)


def _rehash(files):
    value = loads(files["manifest.json"], maximum=2097152)
    from .object_dossier import _ref
    value["files"] = [_ref(path, raw) for path, raw in sorted(files.items())
        if path != "manifest.json"]
    files["manifest.json"] = dumps(value)
    return keccak256(files["manifest.json"])


class SemanticAuthoringHistoryV2Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.case = general_case()
        cls.form = _form(cls.case["citation"])
        cls.draft = capture.capture(cls.form)
        cls.result = history.start_from_form(cls.form, cls.case["files"], cls.case["source_hash"],
            cls.case["plan_raw"], cls.case["plan_hash"], disclosure="public")

    def test_plain_language_capture_replays_source_and_retains_unbound_draft(self):
        result = history.verify(dict(self.result.files), self.result.manifest_hash)
        files = dict(result.files); draft = loads(files[history._path(1)], maximum=524288)
        self.assertEqual(files[history.FORM_PATH], self.form)
        self.assertEqual(files[history._path(1)], self.draft)
        self.assertIsNone(draft["recordBinding"])
        binding = loads(files[history.BINDING_PATH], maximum=history.MAX_BYTES)
        self.assertEqual(binding["binding"]["subject"]["workCitation"], self.case["citation"])
        self.assertEqual(result.report["sourceKind"], "general_semantic_dossier")
        self.assertFalse(binding["binding"]["claims"]["sourceAuthorCorrespondenceProven"])
        self.assertTrue(binding["immutableAcrossHistory"])

    def test_disputed_operator_source_remains_separate_from_draft_confirmation(self):
        binding = loads(dict(self.result.files)[history.BINDING_PATH], maximum=history.MAX_BYTES)["binding"]
        self.assertEqual(binding["originalEvidence"]["authority"]["verificationClass"], "OPERATOR_ASSERTED")
        self.assertTrue(binding["selection"]["withheld"])
        self.assertFalse(binding["claims"]["currentAuthorityProven"])
        self.assertFalse(history.CLAIMS["sourceAuthorAuthenticatedBySource"])

    def test_confirmation_is_exact_and_confirmed_text_cannot_change(self):
        confirmed = history.confirm(dict(self.result.files), self.result.manifest_hash,
            "urn:example:history:text", confirmed_by="urn:example:history:author",
            confirmed_at="2026-09-22T00:30:00Z", revised_at="2026-09-22T01:00:00Z",
            disclosure="public")
        latest = dict(confirmed.files)[history._path(2)]
        value = loads(latest, maximum=524288)
        self.assertEqual(value["sourceVersions"][0]["confirmation"]["scope"],
            "exact_source_version_only")
        changed = _next(latest, lambda v: v["sourceVersions"][0].__setitem__(
            "originalText", "changed after confirmation"), "2026-09-22T02:00:00Z")
        with self.assertRaisesRegex(MuseumError, "confirmed source version"):
            history._transition(latest, changed)

    def test_review_targets_exact_snapshot_and_later_edit_makes_it_historical(self):
        first = _with_relationship(self.draft)
        package = history.start(first, self.case["files"], self.case["source_hash"],
            self.case["plan_raw"], self.case["plan_hash"], disclosure="public")
        reviewer = {"entityId": "urn:example:history:reviewer", "kind": "person",
            "names": [{"value": "Declared reviewer", "language": "en", "kind": "preferred"}]}
        review = {"reviewId": "urn:example:history:review", "reviewer": reviewer,
            "targetKind": "relationship", "targetId": "urn:example:history:relationship",
            "status": "accepted", "reviewedAt": "2026-09-22T00:30:00Z",
            "rationale": "Review of this exact snapshot"}
        reviewed = history.review(dict(package.files), package.manifest_hash, review,
            revised_at="2026-09-22T01:00:00Z", disclosure="public")
        second = dict(reviewed.files)[history._path(2)]
        third = _next(second, lambda value: value["relationships"][0].__setitem__(
            "rationale", "Later edited rationale"), "2026-09-22T02:00:00Z")
        final = history.revise(dict(reviewed.files), reviewed.manifest_hash, third,
            disclosure="public")
        preview = loads(dict(final.files)[history._path(3, "previews")], maximum=524288)
        self.assertEqual(preview["reviewDispositions"][0]["application"], "historical_target")

    def test_append_only_actor_entity_and_lineage_rules_apply_to_unbound_drafts(self):
        changes = {
            "actor": lambda value: value["mappers"].clear(),
            "entity": lambda value: value["entities"][0].__setitem__("kind", "physical_object"),
            "lineage": lambda value: value.__setitem__("previousRevisionHash", "0x" + "11" * 32),
        }
        for name, change in changes.items():
            with self.subTest(change=name), self.assertRaises(MuseumError):
                history._transition(self.draft, _next(self.draft, change))

    def test_same_title_different_token_citation_does_not_bind(self):
        draft = loads(self.draft, maximum=524288)
        draft["workId"] = canonical_citation("31337", A(2), "42")
        draft["entities"][0]["entityId"] = draft["workId"]
        with self.assertRaisesRegex(MuseumError, "source work citation differs"):
            history.start(dumps(draft), self.case["files"], self.case["source_hash"],
                self.case["plan_raw"], self.case["plan_hash"], disclosure="public")

    def test_complete_v4_owner_occurrence_can_anchor_same_unbound_history(self):
        case = owner_v4_case(); form = _form(case["citation"])
        with patch("socket.socket", side_effect=AssertionError("network forbidden")):
            result = history.start_from_form(form, case["files"], case["source_hash"],
                case["plan_raw"], case["plan_hash"], disclosure="public")
        binding = loads(dict(result.files)[history.BINDING_PATH], maximum=history.MAX_BYTES)["binding"]
        self.assertEqual(binding["sourceKind"], "canonical_object_dossier_v4")
        self.assertEqual(result.report["sourceKind"], "canonical_object_dossier_v4")
        self.assertEqual(binding["originalEvidence"]["family"], "LOAN")
        self.assertEqual(binding["originalEvidence"]["currentness"]["status"], "historical_original")
        self.assertFalse(binding["claims"]["currentAuthorityProven"])

    def test_rehashed_outer_source_and_derived_bytes_cannot_bypass_reconstruction(self):
        files = dict(self.result.files)
        source_path = next(path for path in files if path.startswith("source/")
            and path.endswith("semantics/snapshot.json"))
        value = loads(files[source_path], maximum=history.MAX_BYTES)
        value["invented"] = True; files[source_path] = dumps(value)
        with self.assertRaises(MuseumError): history.verify(files, _rehash(files))
        for path in (history.BINDING_PATH, "report.json"):
            files = dict(self.result.files); value = loads(files[path], maximum=history.MAX_BYTES)
            value["invented"] = True; files[path] = dumps(value)
            with self.subTest(path=path), self.assertRaises(MuseumError):
                history.verify(files, _rehash(files))
        files = dict(self.result.files); form = loads(files[history.FORM_PATH], maximum=524288)
        form["originalText"] = "Coherently rehashed replacement form text"
        files[history.FORM_PATH] = dumps(form)
        manifest = loads(files["manifest.json"], maximum=history.MAX_MANIFEST)
        manifest["captureFormHash"] = keccak256(files[history.FORM_PATH])
        files["manifest.json"] = dumps(manifest)
        with self.assertRaisesRegex(MuseumError, "capture form differs"):
            history.verify(files, _rehash(files))

    def test_public_preflight_and_revision_bound_precede_input_replay(self):
        class Exploding(dict):
            def __len__(self): raise AssertionError("source read")
        with self.assertRaisesRegex(MuseumError, "public disclosure"):
            history.compose([], Exploding(), None, None, None, disclosure="restricted")
        with self.assertRaisesRegex(MuseumError, "revision count bound"):
            history.compose([self.draft] * 33, Exploding(), None, None, None, disclosure="public")

    def test_capture_cli_generic_dispatch_and_no_overwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); form = root / "form.json"; plan = root / "plan.json"
            source = root / "source"; output = root / "history"
            form.write_bytes(self.form); plan.write_bytes(self.case["plan_raw"])
            write_tree(self.case["files"], source)
            argv = ["capture", "--form", str(form), "--form-hash", keccak256(self.form),
                "--source", str(source), "--source-hash", self.case["source_hash"],
                "--plan", str(plan), "--plan-hash", self.case["plan_hash"],
                "--disclosure", "public", "--output", str(output)]
            with patch("socket.socket", side_effect=AssertionError("network forbidden")), \
                    patch("sys.stdout", new_callable=io.StringIO) as stdout:
                history.main(argv)
            pin = loads(stdout.getvalue().encode(), maximum=history.MAX_MANIFEST)["manifestHash"]
            with patch("socket.socket", side_effect=AssertionError("network forbidden")):
                checked = package_v2.verify_package(output, pin)
            self.assertEqual(checked, history.verify(dict(checked.files), pin))
            with self.assertRaises(SystemExit): history.main(argv)


if __name__ == "__main__":
    unittest.main()
