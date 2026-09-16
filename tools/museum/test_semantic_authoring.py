"""Offline semantic authoring capture, revision, and evidence-binding controls."""

import copy
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .citations import canonical_citation
from .review import _selector
from .semantic_authoring import (MAX_DRAFT_BYTES, MODE, SCHEMA_HASH, bind_later_documentation,
    inspect_draft, preview, revise_draft, source_version_hash, validate_draft)


H = lambda n: "0x" + format(n, "064x")


def actor(identifier, name):
    return {"entityId": identifier, "kind": "person",
        "names": [{"value": name, "language": "en", "kind": "preferred"}]}


def source_version(text="Original e\u0301 artist text.\r\nSecond line.", status="confirmed"):
    row = {"versionId": "urn:uuid:11111111-1111-4111-8111-111111111111",
        "authorId": "urn:test:person:artist", "originalText": text, "language": "en-US",
        "status": status, "versionHash": None, "confirmation": None}
    if status == "confirmed":
        row["versionHash"] = source_version_hash(row)
        row["confirmation"] = {"confirmedBy": row["authorId"], "confirmedAt": "2026-09-15T12:00:00Z",
            "scope": "exact_source_version_only",
            "basis": "platform_draft_confirmation_not_onchain_signature"}
    return row


def fixture(*, purpose="initial_submission"):
    version = source_version()
    value = {"version": "1", "draftId": "urn:uuid:aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
        "revision": "1", "previousRevisionHash": None, "purpose": purpose,
        "workId": "urn:test:work", "recordBinding": None,
        "sourceAuthor": actor("urn:test:person:artist", "Artist Exact"),
        "mappers": [actor("urn:test:person:mapper", "Registrar Mapper")],
        "reviewers": [actor("urn:test:person:reviewer", "Curatorial Reviewer")],
        "sourceVersions": [version], "activeSourceVersionId": version["versionId"],
        "entities": [
            {"entityId": "urn:test:work", "kind": "abstract_work",
                "names": [{"value": "A  Work", "language": "en", "kind": "preferred"}]},
            {"entityId": "urn:test:event:capture", "kind": "event", "names": []},
            {"entityId": "urn:test:file:master", "kind": "digital_object",
                "names": [{"value": "Master TIFF (described)", "language": "en", "kind": "preferred"}]},
            {"entityId": "urn:test:place:milos", "kind": "place",
                "names": [{"value": "Milos", "language": "el-Latn", "kind": "preferred"}]},
        ],
        "relationships": [
            {"relationshipId": "urn:test:relation:creator", "type": "created_by",
                "subjectId": "urn:test:work", "objectId": "urn:test:person:artist", "role": "creator",
                "sourceVersionId": version["versionId"], "mappedBy": "urn:test:person:mapper",
                "rationale": "Creator credit copied from the source statement."},
            {"relationshipId": "urn:test:relation:master", "type": "represented_by",
                "subjectId": "urn:test:work", "objectId": "urn:test:file:master", "role": "master",
                "sourceVersionId": version["versionId"], "mappedBy": "urn:test:person:mapper",
                "rationale": "The statement describes this resource as a master."},
        ],
        "dates": [{"dateId": "urn:test:date:capture", "entityId": "urn:test:event:capture",
            "kind": "capture", "expression": "18 May 2026", "precision": "exact",
            "calendar": "gregorian", "timezone": "UTC", "earliest": "2026-05-18T00:00:00Z",
            "latest": "2026-05-18T00:00:00Z", "sourceVersionId": version["versionId"],
            "mappedBy": "urn:test:person:mapper"}],
        "measurements": [
            {"measurementId": "urn:test:measure:pixels", "entityId": "urn:test:file:master",
                "type": "pixel_width", "value": {"kind": "integer", "lexical": "6000"},
                "unit": "px", "precision": "exact", "sourceVersionId": version["versionId"],
                "mappedBy": "urn:test:person:mapper"},
            {"measurementId": "urn:test:measure:sheet", "entityId": "urn:test:work",
                "type": "sheet_width", "value": {"kind": "decimal", "lexical": "40.00"},
                "unit": "cm", "precision": "source_lexical", "sourceVersionId": version["versionId"],
                "mappedBy": "urn:test:person:mapper"},
            {"measurementId": "urn:test:measure:ratio", "entityId": "urn:test:work",
                "type": "image_area_width", "value": {"kind": "rational", "numerator": "16", "denominator": "9"},
                "unit": "cm", "precision": "source_lexical", "sourceVersionId": version["versionId"],
                "mappedBy": "urn:test:person:mapper"},
        ],
        "attachments": [{"attachmentId": "urn:test:attachment:master", "entityId": "urn:test:file:master",
            "role": "master", "description": "A TIFF master is described but no bytes were received.",
            "language": "en", "status": "described_only", "sourceVersionId": version["versionId"]}],
        "authorityDecisions": [{"decisionId": "urn:test:authority:no-match", "entityId": "urn:test:place:milos",
            "authority": "GETTY_TGN", "status": "no_match", "reason": "No reviewed match selected.",
            "decidedBy": "urn:test:person:mapper"}],
        "reviews": [{"reviewId": "urn:test:review:creator", "reviewerId": "urn:test:person:reviewer",
            "targetKind": "relationship", "targetId": "urn:test:relation:creator", "targetSnapshot": {},
            "targetHash": H(0), "status": "accepted",
            "reviewedAt": "2026-09-15T13:00:00Z", "rationale": "Mapping reviewed; source text unchanged."}],
        "createdAt": "2026-09-15T11:00:00Z", "revisedAt": "2026-09-15T13:00:00Z"}
    value["reviews"][0]["targetSnapshot"] = copy.deepcopy(value["relationships"][0])
    value["reviews"][0]["targetHash"] = keccak256(dumps(value["reviews"][0]["targetSnapshot"]))
    return value


def later_fixture(citation):
    value = fixture(purpose="later_documentation")
    value["workId"] = citation
    value["entities"].insert(0, {"entityId": citation, "kind": "token", "names": []})
    return value


class SemanticAuthoringTest(unittest.TestCase):
    def test_exact_text_names_repeated_roles_dates_measurements_and_no_match(self):
        value = fixture()
        raw = dumps(value)
        admitted = validate_draft(raw)
        self.assertEqual(admitted, value)
        self.assertEqual(admitted["sourceVersions"][0]["originalText"], "Original e\u0301 artist text.\r\nSecond line.")
        self.assertEqual(admitted["entities"][3]["names"][0]["language"], "el-Latn")
        self.assertEqual([r["role"] for r in admitted["relationships"]], ["creator", "master"])
        self.assertEqual(admitted["measurements"][1]["value"]["lexical"], "40.00")
        self.assertEqual(admitted["measurements"][2]["value"],
            {"kind": "rational", "numerator": "16", "denominator": "9"})
        self.assertEqual(admitted["authorityDecisions"][0]["status"], "no_match")

    def test_closed_schema_rejects_invented_transport_and_ingest_fields(self):
        changes = (
            lambda v: v.update(signature=H(1)),
            lambda v: v.update(chainId="1"),
            lambda v: v["attachments"][0].update(uploadUrl="https://example.test/master.tif"),
            lambda v: v["attachments"][0].update(scanStatus="clean"),
            lambda v: v["attachments"][0].update(status="ingested"),
            lambda v: v["recordBinding"].update(title="A Work") if v["recordBinding"] else v.update(recordBinding={"title": "A Work"}),
        )
        for change in changes:
            value = fixture(); change(value)
            with self.subTest(value=value), self.assertRaises(MuseumError): inspect_draft(dumps(value))

    def test_attribution_roles_allow_exact_same_actor_and_reject_conflicts(self):
        for field in ("mappers", "reviewers"):
            value = fixture(); value[field][0] = copy.deepcopy(value["sourceAuthor"])
            if field == "mappers":
                for collection in ("relationships", "dates", "measurements"):
                    for row in value[collection]: row["mappedBy"] = value["sourceAuthor"]["entityId"]
                value["authorityDecisions"][0]["decidedBy"] = value["sourceAuthor"]["entityId"]
                value["reviews"][0]["targetSnapshot"] = copy.deepcopy(value["relationships"][0])
                value["reviews"][0]["targetHash"] = keccak256(dumps(value["reviews"][0]["targetSnapshot"]))
            else:
                value["reviews"][0]["reviewerId"] = value["sourceAuthor"]["entityId"]
            self.assertEqual(inspect_draft(dumps(value))[field][0], value["sourceAuthor"])
            value = fixture(); value[field][0]["entityId"] = value["sourceAuthor"]["entityId"]
            with self.subTest(field=field), self.assertRaisesRegex(MuseumError, "conflicting actor"):
                inspect_draft(dumps(value))
        value = fixture(); value["mappers"][0] = copy.deepcopy(value["sourceAuthor"])
        for collection in ("relationships", "dates", "measurements"):
            for row in value[collection]: row["mappedBy"] = value["sourceAuthor"]["entityId"]
        value["authorityDecisions"][0]["decidedBy"] = value["sourceAuthor"]["entityId"]
        value["reviews"][0]["targetSnapshot"] = copy.deepcopy(value["relationships"][0])
        value["reviews"][0]["targetHash"] = keccak256(dumps(value["reviews"][0]["targetSnapshot"]))
        self.assertTrue(inspect_draft(dumps(value)))

    def test_confirmed_source_hash_and_scope_are_exact(self):
        for change in (
            lambda v: v["sourceVersions"][0].update(originalText=v["sourceVersions"][0]["originalText"] + " "),
            lambda v: v["sourceVersions"][0]["confirmation"].update(scope="source_and_mapping"),
            lambda v: v["sourceVersions"][0]["confirmation"].update(confirmedBy="urn:test:person:mapper"),
            lambda v: v["sourceVersions"][0].update(versionHash=H(9)),
        ):
            value = fixture(); change(value)
            with self.assertRaises(MuseumError): inspect_draft(dumps(value))
        unconfirmed = fixture(); unconfirmed["sourceVersions"] = [source_version(status="draft")]
        unconfirmed["activeSourceVersionId"] = unconfirmed["sourceVersions"][0]["versionId"]
        self.assertIsNone(inspect_draft(dumps(unconfirmed))["sourceVersions"][0]["versionHash"])

    def test_exact_numeric_lexicals_never_round_or_overflow(self):
        bad = (
            {"kind": "integer", "lexical": "06000"},
            {"kind": "integer", "lexical": str(1 << 256)},
            {"kind": "decimal", "lexical": "4e1"},
            {"kind": "decimal", "lexical": "40"},
            {"kind": "rational", "numerator": "16", "denominator": "0"},
        )
        for exact in bad:
            value = fixture(); value["measurements"][0]["value"] = exact
            with self.subTest(exact=exact), self.assertRaises(MuseumError): inspect_draft(dumps(value))
        value = fixture(); value["measurements"][0]["value"] = 6000
        with self.assertRaises(MuseumError): inspect_draft(dumps(value))

    def test_measurement_types_have_closed_compatible_units(self):
        incompatible = (("pixel_width", "cm"), ("file_size", "px"), ("duration", "B"),
            ("sheet_height", "s"), ("image_area_width", "px"))
        for measurement_type, unit in incompatible:
            value = fixture(); value["measurements"][0].update(type=measurement_type, unit=unit)
            with self.subTest(measurement_type=measurement_type, unit=unit), self.assertRaisesRegex(MuseumError, "type/unit"):
                inspect_draft(dumps(value))

    def test_review_retains_exact_snapshot_and_becomes_historical_after_edit(self):
        value = fixture()
        value["relationships"][0]["rationale"] += " Edited after review."
        self.assertEqual(preview(dumps(value))["reviewDispositions"][0]["application"], "historical_target")
        previous = fixture(); previous_raw = dumps(previous)
        revised = copy.deepcopy(previous)
        revised.update(revision="2", previousRevisionHash=keccak256(previous_raw), revisedAt="2026-09-16T09:00:00Z")
        revised["relationships"][0]["rationale"] += " Legitimate correction with historical review retained."
        self.assertEqual(revise_draft(previous_raw, dumps(revised)), revised)
        revised["reviews"][0]["targetSnapshot"] = copy.deepcopy(revised["relationships"][0])
        revised["reviews"][0]["targetHash"] = keccak256(dumps(revised["reviews"][0]["targetSnapshot"]))
        with self.assertRaisesRegex(MuseumError, "reviews stable identity retargeted"):
            revise_draft(previous_raw, dumps(revised))
        bad = fixture(); bad["reviews"][0]["targetHash"] = H(9)
        with self.assertRaisesRegex(MuseumError, "snapshot/hash"):
            inspect_draft(dumps(bad))

    def test_revision_preserves_confirmed_versions_binding_and_typed_identities(self):
        previous = fixture(); previous_raw = dumps(previous)
        revised = copy.deepcopy(previous)
        revised.update(revision="2", previousRevisionHash=keccak256(previous_raw), revisedAt="2026-09-16T09:00:00Z")
        revised["entities"][0]["names"].append({"value": "Une œuvre", "language": "fr", "kind": "alternate"})
        revised_raw = dumps(revised)
        self.assertEqual(revise_draft(previous_raw, revised_raw), revised)
        for change in (
            lambda v: v["sourceVersions"][0].update(originalText="rewritten"),
            lambda v: v["entities"][0].update(kind="place"),
            lambda v: v["relationships"][0].update(objectId="urn:test:file:master"),
            lambda v: v["attachments"].clear(),
            lambda v: v.update(previousRevisionHash=H(99)),
            lambda v: v.update(revisedAt="2026-09-15T12:59:59Z"),
        ):
            bad = copy.deepcopy(revised); change(bad)
            with self.assertRaises(MuseumError): revise_draft(previous_raw, dumps(bad))

    def test_revision_preserves_actor_kind_and_authority_decision_scope(self):
        previous = fixture(); previous_raw = dumps(previous)
        changes = (
            lambda v: v["mappers"][0].update(kind="group"),
            lambda v: v["reviewers"][0].update(kind="group"),
            lambda v: v["authorityDecisions"][0].update(entityId="urn:test:file:master"),
            lambda v: v["authorityDecisions"][0].update(authority="GETTY_AAT"),
        )
        for change in changes:
            revised = copy.deepcopy(previous)
            revised.update(revision="2", previousRevisionHash=keccak256(previous_raw), revisedAt="2026-09-16T09:00:00Z")
            change(revised)
            with self.subTest(revised=revised), self.assertRaises(MuseumError): revise_draft(previous_raw, dumps(revised))

    def test_authoring_limit_accepts_more_than_record_payload_and_rejects_oversize(self):
        value = fixture()
        value["entities"].extend({"entityId": f"urn:test:entity:large:{index}", "kind": "information_object",
            "names": [{"value": "x" * 1000, "language": "en", "kind": "preferred"}]}
            for index in range(30))
        raw = dumps(value)
        self.assertGreater(len(raw), 24576)
        self.assertEqual(inspect_draft(raw)["draftId"], value["draftId"])
        with self.assertRaisesRegex(MuseumError, "byte bound"):
            inspect_draft(b" " * (MAX_DRAFT_BYTES + 1))

    def test_preview_is_explicitly_draft_and_claims_no_transport_or_media_evidence(self):
        value = preview(dumps(fixture()))
        self.assertEqual(value["mode"], MODE)
        self.assertEqual(value["schemaHash"], SCHEMA_HASH)
        self.assertEqual(value["sourceVersions"][0]["originalText"], fixture()["sourceVersions"][0]["originalText"])
        self.assertFalse(value["claims"]["recordedStreamDossier"])
        self.assertFalse(value["claims"]["signaturePresent"])
        self.assertFalse(value["claims"]["mediaIngested"])
        self.assertNotIn("uploadUrl", value["sourceVersions"])
        self.assertEqual(value["reviewDispositions"][0]["application"], "current_target")

    def test_later_recorded_binding_uses_frozen_state_and_exact_external_pin(self):
        from .test_recorded_account import load_source
        source = load_source()
        capture = loads(source.capture_bytes, maximum=67108864)
        token_hash = next(row["recordHash"] for row in capture["records"] if row["subject"][0] == "1")
        token_record = next(row for row in source.state.records if row.selector.record_hash == token_hash)
        selection = _selector(token_record, "")
        citation = canonical_citation(source.anchor["chainId"], source.anchor["core"], "71")
        unbound = dumps(later_fixture(citation))
        with self.assertRaisesRegex(MuseumError, "binding missing"): inspect_draft(unbound)
        bound = bind_later_documentation(unbound, source, selection, source_hash=source.state.commitment)
        self.assertEqual(validate_draft(bound, source=source, source_hash=source.state.commitment)["recordBinding"]["recordSelector"], selection)
        with self.assertRaises(MuseumError): validate_draft(bound)
        with self.assertRaises(MuseumError): bind_later_documentation(unbound, source, selection, source_hash=H(99))
        with self.assertRaisesRegex(MuseumError, "token subject"):
            bind_later_documentation(unbound, source, _selector(source.state.records[0], ""), source_hash=source.state.commitment)
        unrelated = later_fixture(canonical_citation(source.anchor["chainId"], source.anchor["core"], "72"))
        with self.assertRaisesRegex(MuseumError, "work citation"):
            bind_later_documentation(dumps(unrelated), source, selection, source_hash=source.state.commitment)
        source.records = {"malicious": source.state.records[0]}
        source.positions = {"malicious": (0,)}
        self.assertTrue(validate_draft(bound, source=source, source_hash=source.state.commitment))

    def test_later_owner_binding_replays_original_anchor_and_transcript(self):
        from .test_condition import ConditionOwnerFixture
        fixture_source = ConditionOwnerFixture()
        source, _, _ = fixture_source.replay()
        pin = keccak256(source.snapshot())
        selected = fixture_source.lanes[(41, schema_id("CONDITION_REPORT"))][0]
        citation = canonical_citation(source.a["chainId"], source.a["core"], "41")
        unbound = dumps(later_fixture(citation))
        bound = bind_later_documentation(unbound, source, selected, source_hash=pin)
        binding = validate_draft(bound, source=source, source_hash=pin)["recordBinding"]
        self.assertEqual(binding["kind"], "owner_record_source")
        self.assertEqual(binding["recordHash"], selected)
        source.records[selected]["record"][1] = H(123)
        self.assertTrue(validate_draft(bound, source=source, source_hash=pin))

    def test_cli_validates_and_previews_initial_canonical_draft(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / "draft.json"; path.write_bytes(dumps(fixture()))
            for command in ("validate", "preview"):
                result = subprocess.run([sys.executable, "-m", "tools.museum.semantic_authoring", command, str(path)],
                    cwd=Path(__file__).resolve().parents[2], check=True, capture_output=True)
                output = loads(result.stdout.strip(), maximum=524288)
                self.assertEqual(output["mode"], MODE)
            oversized = Path(root) / "oversized.json"
            oversized.write_bytes(b" " * (MAX_DRAFT_BYTES + 1))
            result = subprocess.run([sys.executable, "-m", "tools.museum.semantic_authoring", "validate", str(oversized)],
                cwd=Path(__file__).resolve().parents[2], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(b"draft file byte bound", result.stderr)


if __name__ == "__main__":
    unittest.main()
