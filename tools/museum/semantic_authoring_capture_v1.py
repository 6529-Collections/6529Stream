"""Friendly, lossless capture actions for semantic-authoring draft V1.

This module only constructs revisions of the unchanged authoring draft schema.
It does not bind a source, infer semantic relationships, authenticate an actor,
or publish a record.
"""

from copy import deepcopy

from jsonschema import FormatChecker

from . import semantic_authoring as authoring
from .canonical import MuseumError, dumps, keccak256, loads, uint
from .validation import StreamValidator


NAME = "STREAM_MUSEUM_SEMANTIC_AUTHORING_CAPTURE_V1"
MODE = "friendly_draft_capture"
FORM_VERSION = "1"
PROSE_FIELDS = (
    "originalText", "title", "creatorCredit", "mediumDescription",
    "placeName", "eventAccount",
)
REQUIRED_PROSE_FIELDS = ("originalText", "title")
OPTIONAL_PROSE_FIELDS = tuple(field for field in PROSE_FIELDS
                              if field not in REQUIRED_PROSE_FIELDS)
FORM_FIELDS = {
    "version", "purpose", "draftId", "workId", "rootKind", "sourceAuthor",
    "sourceVersionIds", "timestamp", "language", *PROSE_FIELDS,
}
REVIEW_FIELDS = {
    "reviewId", "reviewer", "targetKind", "targetId", "status",
    "reviewedAt", "rationale",
}
TARGETS = {
    "relationship": ("relationships", "relationshipId"),
    "date": ("dates", "dateId"),
    "measurement": ("measurements", "measurementId"),
    "authority_decision": ("authorityDecisions", "decisionId"),
}
PROFILE_BYTES = dumps({
    "name": NAME,
    "version": "1",
    "status": "prospective_unregistered_application_profile",
    "authoringDraftSchema": authoring.NAME,
    "authoringDraftSchemaHash": authoring.SCHEMA_HASH,
    "form": {
        "requiredProse": list(REQUIRED_PROSE_FIELDS),
        "optionalProse": list(OPTIONAL_PROSE_FIELDS),
        "sourceVersionIdentity": "caller_supplied_non_null_exactly_when_prose_is_supplied",
        "rootKinds": {"initial_submission": "abstract_work", "later_documentation": "token"},
    },
    "actions": ["capture", "confirm_exact_source_version", "append_snapshot_review"],
    "claims": {
        "publishesStreamRecord": False,
        "authenticatesHumanIdentity": False,
        "confirmsMappedEnrichment": False,
        "uploadsOrScansMedia": False,
        "establishesInstitutionalConformance": False,
    },
    "qualification": ("Plain-language capture into the unchanged offline authoring draft schema; "
                      "optional prose null means not supplied and establishes no absence claim."),
})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _need(condition, message):
    if not condition:
        raise MuseumError("semantic authoring capture " + message)


def _admit(raw, *, allow_unbound=False):
    _need(type(raw) is bytes and 0 < len(raw) <= authoring.MAX_DRAFT_BYTES,
          "draft byte bound")
    value = loads(raw, maximum=authoring.MAX_DRAFT_BYTES, canonical=True)
    errors = sorted(StreamValidator(authoring.DRAFT_SCHEMA,
                                    format_checker=FormatChecker()).iter_errors(value),
                    key=lambda error: str(error.path))
    _need(not errors, "schema validation: " + (errors[0].message if errors else ""))
    return authoring._semantic(value, allow_unbound=allow_unbound)


def _next(value, previous_raw, revised_at):
    _need(type(revised_at) is str, "revisedAt required")
    _need(authoring._timestamp(revised_at) >= authoring._timestamp(value["revisedAt"]),
          "revision time moved backward")
    revised = deepcopy(value)
    revised["revision"] = str(uint(value["revision"], 64) + 1)
    revised["previousRevisionHash"] = keccak256(previous_raw)
    revised["revisedAt"] = revised_at
    return revised


def _finish(previous_raw, revised):
    raw = dumps(revised)
    current = _admit(raw, allow_unbound=True)
    previous = _admit(previous_raw, allow_unbound=True)
    _need(current["draftId"] == previous["draftId"]
          and current["workId"] == previous["workId"]
          and current["purpose"] == previous["purpose"],
          "draft identity or purpose changed")
    _need(current["recordBinding"] == previous["recordBinding"],
          "record binding changed")
    # The public V1 transition validator provides the final check whenever the
    # revision is independently valid without an external source object.
    if previous["purpose"] == "initial_submission":
        authoring.revise_draft(previous_raw, raw)
    return raw


def capture(form_raw):
    """Create revision one from a closed, plain-language canonical form."""
    _need(type(form_raw) is bytes and 0 < len(form_raw) <= authoring.MAX_DRAFT_BYTES,
          "form byte bound")
    form = loads(form_raw, maximum=authoring.MAX_DRAFT_BYTES, canonical=True)
    _need(isinstance(form, dict) and set(form) == FORM_FIELDS,
          "form fields")
    _need(form["version"] == FORM_VERSION,
          "form version")
    _need(form["purpose"] in ("initial_submission", "later_documentation"),
          "purpose")
    expected_kind = "abstract_work" if form["purpose"] == "initial_submission" else "token"
    _need(form["rootKind"] == expected_kind, "root kind differs from purpose")
    _need(isinstance(form["sourceVersionIds"], dict)
          and set(form["sourceVersionIds"]) == set(PROSE_FIELDS),
          "source version identity fields")
    supplied_ids = []
    for field in REQUIRED_PROSE_FIELDS:
        _need(isinstance(form[field], str) and len(form[field]) > 0,
              field + " text required")
    for field in OPTIONAL_PROSE_FIELDS:
        _need(form[field] is None or isinstance(form[field], str) and len(form[field]) > 0,
              field + " must be nonempty text or null")
    for field in PROSE_FIELDS:
        identifier = form["sourceVersionIds"][field]
        if form[field] is None:
            _need(identifier is None, field + " null prose requires null source version identity")
        else:
            _need(isinstance(identifier, str), field + " source version identity required")
            supplied_ids.append(identifier)
    _need(len(set(supplied_ids)) == len(supplied_ids),
          "duplicate source version identity")

    author = deepcopy(form["sourceAuthor"])
    versions = [{
        "versionId": form["sourceVersionIds"][field],
        "authorId": author.get("entityId") if isinstance(author, dict) else None,
        "originalText": form[field],
        "language": form["language"],
        "status": "draft",
        "versionHash": None,
        "confirmation": None,
    } for field in PROSE_FIELDS if form[field] is not None]
    value = {
        "version": "1",
        "draftId": form["draftId"],
        "revision": "1",
        "previousRevisionHash": None,
        "purpose": form["purpose"],
        "workId": form["workId"],
        "recordBinding": None,
        "sourceAuthor": author,
        "mappers": [deepcopy(author)],
        "reviewers": [],
        "sourceVersions": versions,
        "activeSourceVersionId": form["sourceVersionIds"]["originalText"],
        "entities": [{
            "entityId": form["workId"],
            "kind": form["rootKind"],
            "names": [{"value": form["title"], "language": form["language"],
                       "kind": "preferred"}],
        }],
        "relationships": [],
        "dates": [],
        "measurements": [],
        "attachments": [],
        "authorityDecisions": [],
        "reviews": [],
        "createdAt": form["timestamp"],
        "revisedAt": form["timestamp"],
    }
    raw = dumps(value)
    _admit(raw, allow_unbound=True)
    return raw


def confirm(raw, version_id, *, confirmed_by, confirmed_at, revised_at):
    """Confirm one exact prose source-version in a new draft revision."""
    value = _admit(raw, allow_unbound=True)
    matches = [row for row in value["sourceVersions"] if row["versionId"] == version_id]
    _need(len(matches) == 1, "source version missing")
    _need(matches[0]["status"] == "draft", "source version already confirmed")
    _need(confirmed_by == value["sourceAuthor"]["entityId"],
          "confirmation must be by source author")
    _need(authoring._timestamp(confirmed_at) <= authoring._timestamp(revised_at),
          "confirmation follows revision")
    revised = _next(value, raw, revised_at)
    version = next(row for row in revised["sourceVersions"] if row["versionId"] == version_id)
    version["status"] = "confirmed"
    version["versionHash"] = authoring.source_version_hash(version)
    version["confirmation"] = {
        "confirmedBy": confirmed_by,
        "confirmedAt": confirmed_at,
        "scope": "exact_source_version_only",
        "basis": "platform_draft_confirmation_not_onchain_signature",
    }
    return _finish(raw, revised)


def review(raw, review, *, revised_at):
    """Append an explicitly attributed review of the current exact target."""
    value = _admit(raw, allow_unbound=True)
    _need(isinstance(review, dict) and set(review) == REVIEW_FIELDS,
          "review fields")
    _need(isinstance(review["targetKind"], str) and review["targetKind"] in TARGETS,
          "review target kind")
    collection, key = TARGETS[review["targetKind"]]
    matches = [row for row in value[collection] if row[key] == review["targetId"]]
    _need(len(matches) == 1, "review target missing")
    _need(review["status"] in ("accepted", "changes_requested"), "review status")
    _need(authoring._timestamp(review["reviewedAt"]) <= authoring._timestamp(revised_at),
          "review follows revision")

    reviewer = review["reviewer"]
    _need(isinstance(reviewer, dict), "reviewer declaration")
    declarations = [value["sourceAuthor"], *value["mappers"], *value["reviewers"]]
    same = [row for row in declarations if row.get("entityId") == reviewer.get("entityId")]
    _need(not same or all(row == reviewer for row in same),
          "conflicting reviewer declaration")
    _need(all(row["reviewId"] != review["reviewId"] for row in value["reviews"]),
          "duplicate review identity")

    revised = _next(value, raw, revised_at)
    if not any(row["entityId"] == reviewer.get("entityId") for row in revised["reviewers"]):
        revised["reviewers"].append(deepcopy(reviewer))
    snapshot = deepcopy(matches[0])
    revised["reviews"].append({
        "reviewId": review["reviewId"],
        "reviewerId": reviewer.get("entityId"),
        "targetKind": review["targetKind"],
        "targetId": review["targetId"],
        "targetSnapshot": snapshot,
        "targetHash": keccak256(dumps(snapshot)),
        "status": review["status"],
        "reviewedAt": review["reviewedAt"],
        "rationale": review["rationale"],
    })
    return _finish(raw, revised)
