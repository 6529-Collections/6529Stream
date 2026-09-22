"""Focused tests for friendly semantic-authoring capture actions."""

import copy
import unittest

from .canonical import MuseumError, dumps, keccak256, loads
from .semantic_authoring import (inspect_draft, preview, revise_draft,
                                  source_version_hash)
from .semantic_authoring_capture_v1 import (PROSE_FIELDS, capture, confirm,
                                             PROFILE_BYTES, PROFILE_HASH, review)
from .test_semantic_authoring import fixture as rich_fixture


def actor(identifier="urn:test:person:artist", name="Artist Name"):
    return {"entityId": identifier, "kind": "person",
            "names": [{"value": name, "language": "en", "kind": "preferred"}]}


def form(*, purpose="initial_submission"):
    later = purpose == "later_documentation"
    return {
        "version": "1",
        "purpose": purpose,
        "draftId": "urn:uuid:11111111-1111-4111-8111-111111111111",
        "workId": ("eip155:31337/erc721:0x0000000000000000000000000000000000000002/41"
                   if later else "urn:test:work:one"),
        "rootKind": "token" if later else "abstract_work",
        "sourceAuthor": actor(),
        "sourceVersionIds": {field: "urn:test:source:" + field for field in PROSE_FIELDS},
        "timestamp": "2026-09-22T10:00:00Z",
        "language": "en",
        "originalText": "Line one.\r\nExact e\u0301 text.",
        "title": "  A title with spaces  ",
        "creatorCredit": "Artist Name with Studio B",
        "mediumDescription": "Browser work; described HTML and JS only.",
        "placeName": "Milos / Μήλος",
        "eventAccount": "Completed in several sessions; no event inferred.",
    }


class SemanticAuthoringCaptureV1Test(unittest.TestCase):
    def test_capture_preserves_every_plain_text_field_and_durable_id(self):
        source = form()
        raw = capture(dumps(source))
        value = inspect_draft(raw)
        self.assertEqual(value["draftId"], source["draftId"])
        self.assertEqual(value["workId"], source["workId"])
        by_id = {row["versionId"]: row for row in value["sourceVersions"]}
        for field in PROSE_FIELDS:
            row = by_id[source["sourceVersionIds"][field]]
            self.assertEqual(row["originalText"], source[field])
            self.assertEqual(row["status"], "draft")
            self.assertIsNone(row["confirmation"])
        self.assertEqual(value["entities"][0]["names"][0]["value"], source["title"])
        self.assertEqual(value["activeSourceVersionId"], source["sourceVersionIds"]["originalText"])

    def test_capture_does_not_invent_mapping_authority_transport_or_publication(self):
        value = inspect_draft(capture(dumps(form())))
        self.assertIsNone(value["recordBinding"])
        for field in ("relationships", "dates", "measurements", "attachments",
                      "authorityDecisions", "reviews"):
            self.assertEqual(value[field], [])
        wire = dumps(value)
        for forbidden in (b"chainId", b"schemaId", b"signature", b"receipt",
                          b"uploadUrl", b"publicationHash", b"authorityMatch"):
            self.assertNotIn(forbidden, wire)

    def test_optional_prose_null_is_not_invented_or_emitted_as_absence(self):
        source = form()
        for field in ("creatorCredit", "mediumDescription", "placeName", "eventAccount"):
            source[field] = None
            source["sourceVersionIds"][field] = None
        value = inspect_draft(capture(dumps(source)))
        self.assertEqual([row["versionId"] for row in value["sourceVersions"]],
                         [source["sourceVersionIds"]["originalText"],
                          source["sourceVersionIds"]["title"]])
        wire = dumps(value)
        for field in ("creatorCredit", "mediumDescription", "placeName", "eventAccount"):
            self.assertNotIn(field.encode("utf-8"), wire)
        self.assertEqual(keccak256(PROFILE_BYTES), PROFILE_HASH)

    def test_later_capture_is_unbound_structure_for_concrete_source_adapter(self):
        raw = capture(dumps(form(purpose="later_documentation")))
        value = loads(raw, maximum=524288, canonical=True)
        self.assertEqual(value["entities"][0]["kind"], "token")
        self.assertIsNone(value["recordBinding"])
        with self.assertRaisesRegex(MuseumError, "binding missing"):
            inspect_draft(raw)
        bad = form(purpose="later_documentation")
        bad["rootKind"] = "abstract_work"
        with self.assertRaisesRegex(MuseumError, "root kind"):
            capture(dumps(bad))

    def test_confirmation_is_exact_source_only_and_new_revision(self):
        first = capture(dumps(form()))
        version_id = form()["sourceVersionIds"]["originalText"]
        second = confirm(first, version_id,
            confirmed_by=form()["sourceAuthor"]["entityId"],
            confirmed_at="2026-09-22T10:05:00Z", revised_at="2026-09-22T10:06:00Z")
        value = inspect_draft(second)
        version = next(row for row in value["sourceVersions"] if row["versionId"] == version_id)
        self.assertEqual(value["revision"], "2")
        self.assertEqual(value["previousRevisionHash"], keccak256(first))
        self.assertEqual(version["versionHash"], source_version_hash(version))
        self.assertEqual(version["confirmation"], {
            "confirmedBy": form()["sourceAuthor"]["entityId"],
            "confirmedAt": "2026-09-22T10:05:00Z",
            "scope": "exact_source_version_only",
            "basis": "platform_draft_confirmation_not_onchain_signature",
        })
        self.assertFalse(preview(second)["claims"]["signaturePresent"])
        with self.assertRaisesRegex(MuseumError, "already confirmed"):
            confirm(second, version_id, confirmed_by=form()["sourceAuthor"]["entityId"],
                    confirmed_at="2026-09-22T10:07:00Z", revised_at="2026-09-22T10:08:00Z")

    def test_confirmation_cannot_be_attributed_to_mapper_or_future_time(self):
        raw = capture(dumps(form()))
        version_id = form()["sourceVersionIds"]["title"]
        with self.assertRaisesRegex(MuseumError, "source author"):
            confirm(raw, version_id, confirmed_by="urn:test:person:mapper",
                    confirmed_at="2026-09-22T10:05:00Z", revised_at="2026-09-22T10:06:00Z")
        with self.assertRaisesRegex(MuseumError, "follows revision"):
            confirm(raw, version_id, confirmed_by=form()["sourceAuthor"]["entityId"],
                    confirmed_at="2026-09-22T10:07:00Z", revised_at="2026-09-22T10:06:00Z")

    def test_review_snapshots_current_target_and_becomes_historical_after_edit(self):
        first = dumps(rich_fixture())
        request = {
            "reviewId": "urn:test:review:second",
            "reviewer": actor("urn:test:person:second-reviewer", "Second Reviewer"),
            "targetKind": "relationship",
            "targetId": "urn:test:relation:creator",
            "status": "accepted",
            "reviewedAt": "2026-09-15T13:05:00Z",
            "rationale": "Reviewed the exact current relationship.",
        }
        second = review(first, request, revised_at="2026-09-15T13:06:00Z")
        admitted = inspect_draft(second)
        saved = next(row for row in admitted["reviews"] if row["reviewId"] == request["reviewId"])
        target = next(row for row in admitted["relationships"] if row["relationshipId"] == request["targetId"])
        self.assertEqual(saved["targetSnapshot"], target)
        self.assertEqual(saved["targetHash"], keccak256(dumps(target)))

        third = copy.deepcopy(admitted)
        third["revision"] = "3"
        third["previousRevisionHash"] = keccak256(second)
        third["revisedAt"] = "2026-09-15T13:07:00Z"
        target = next(row for row in third["relationships"] if row["relationshipId"] == request["targetId"])
        target["rationale"] += " Later mapper edit."
        third_raw = dumps(third)
        revise_draft(second, third_raw)
        statuses = {row["reviewId"]: row["application"] for row in preview(third_raw)["reviewDispositions"]}
        self.assertEqual(statuses[request["reviewId"]], "historical_target")

    def test_review_requires_explicit_current_target_and_consistent_actor(self):
        raw = dumps(rich_fixture())
        request = {
            "reviewId": "urn:test:review:new",
            "reviewer": actor("urn:test:person:reviewer", "Conflicting Reviewer Name"),
            "targetKind": "relationship",
            "targetId": "urn:test:relation:creator",
            "status": "changes_requested",
            "reviewedAt": "2026-09-15T13:05:00Z",
            "rationale": "Needs a correction.",
        }
        with self.assertRaisesRegex(MuseumError, "conflicting reviewer"):
            review(raw, request, revised_at="2026-09-15T13:06:00Z")
        request["reviewer"] = actor("urn:test:person:new-reviewer", "New Reviewer")
        request["targetId"] = "urn:test:relation:absent"
        with self.assertRaisesRegex(MuseumError, "target missing"):
            review(raw, request, revised_at="2026-09-15T13:06:00Z")

    def test_form_is_closed_and_identity_collisions_reject(self):
        cases = []
        value = form(); value["chainId"] = "1"; cases.append(value)
        value = form(); value["sourceVersionIds"]["title"] = value["sourceVersionIds"]["originalText"]; cases.append(value)
        value = form(); value["sourceAuthor"]["entityId"] = value["workId"]; cases.append(value)
        value = form(); value["eventAccount"] = ""; cases.append(value)
        for value in cases:
            with self.subTest(value=value), self.assertRaises(MuseumError):
                capture(dumps(value))

    def test_malformed_container_values_raise_museum_error(self):
        value = form(); value["sourceVersionIds"]["title"] = ["not", "an", "iri"]
        with self.assertRaises(MuseumError):
            capture(dumps(value))
        request = {
            "reviewId": "urn:test:review:bad",
            "reviewer": actor("urn:test:person:new-reviewer", "New Reviewer"),
            "targetKind": ["relationship"],
            "targetId": "urn:test:relation:creator",
            "status": "accepted",
            "reviewedAt": "2026-09-15T13:05:00Z",
            "rationale": "Malformed target kind must not leak TypeError.",
        }
        with self.assertRaises(MuseumError):
            review(dumps(rich_fixture()), request, revised_at="2026-09-15T13:06:00Z")


if __name__ == "__main__":
    unittest.main()
