"""Portable history for unchanged unbound drafts and current source evidence.

Every revision remains an unchanged semantic-authoring V1 later-documentation
draft with ``recordBinding: null``.  A separate immutable supplemental binding
is reconstructed from a complete General or canonical V4 source package on
every opening.  This module does not publish records or turn draft actors,
confirmations, or reviews into source authority.
"""

import argparse
from copy import deepcopy
from pathlib import Path

from jsonschema import FormatChecker

from . import object_dossier as package
from . import semantic_authoring as authoring
from . import semantic_authoring_capture_v1 as capture
from . import semantic_authoring_current_sources_v2 as sources
from .bagit import MAX_BYTES, MAX_FILES, MAX_MANIFEST, read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .independent_wire import require
from .validation import StreamValidator


NAME = "STREAM_MUSEUM_SEMANTIC_AUTHORING_HISTORY_V2"
MODE = "semantic_authoring_history_v2"
MAX_REVISIONS = 32
PLAN_PATH = "inputs/source-plan.json"
FORM_PATH = "inputs/capture-form.json"
BINDING_PATH = "authoring/source-binding.json"
INDEX_PATH = "authoring/revision-index.json"

CLAIMS = {
    "allRevisionsRetained": True,
    "contiguousRevisionLineageChecked": True,
    "concreteSourceReplayedOnEveryOpen": True,
    "supplementalSourceBindingImmutable": True,
    "originalAuthoringSchemaUnchanged": True,
    "draftRecordBindingChanged": False,
    "confirmationScopeExpanded": False,
    "sourceAuthorAuthenticatedBySource": False,
    "mapperOrReviewerAuthenticated": False,
    "publicationAuthorized": False,
    "recordPublished": False,
    "profileRegistered": False,
    "tokenExistenceProven": False,
    "currentOwnerProven": False,
    "legalTitleProven": False,
    "consensusOrFinalityProven": False,
    "institutionalAcceptance": False,
    "networkFetch": False,
}
QUALIFICATION = (
    "Portable offline revision history around the unchanged semantic-authoring V1 draft. "
    "Every draft remains later-documentation with recordBinding null; exact current General "
    "or canonical V4 evidence is replayed into a separate immutable supplemental binding. "
    "Confirmation covers one exact source-version text only. Reviews remain attributed draft "
    "reviews of exact snapshots and may become historical after a later edit. Source evidence "
    "does not authenticate the draft source author, mapper, or reviewer, and does not grant "
    "publication authority, establish ownership or legal title, or prove consensus/finality."
)
PROFILE_BYTES = dumps({
    "name": NAME,
    "version": "2",
    "mode": MODE,
    "status": "prospective_unregistered_local_adapter",
    "draftSchema": authoring.NAME,
    "draftSchemaHash": authoring.SCHEMA_HASH,
    "sourceProfileHash": sources.PROFILE_HASH,
    "captureProfileHash": capture.PROFILE_HASH,
    "history": {
        "maximumRevisions": str(MAX_REVISIONS),
        "firstRevision": "1",
        "lineage": "contiguous revision and exact previousRevisionHash",
        "binding": "immutable supplemental source binding outside every retained draft",
        "transitionRules": "copied bounded append-only V1 identity, confirmation, and review invariants",
    },
    "limits": {"files": str(MAX_FILES), "aggregateBytes": str(MAX_BYTES),
        "manifestBytes": str(MAX_MANIFEST), "draftBytes": str(authoring.MAX_DRAFT_BYTES)},
    "claims": CLAIMS,
    "qualification": QUALIFICATION,
})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == "public", "authoring history public disclosure required before reads")


def _path(index, kind="drafts"):
    return kind + "/revision-" + str(index).zfill(4) + ".json"


def _admit(raw):
    require(type(raw) is bytes and 0 < len(raw) <= authoring.MAX_DRAFT_BYTES,
        "authoring history draft byte bound")
    value = loads(raw, maximum=authoring.MAX_DRAFT_BYTES, canonical=True)
    errors = sorted(StreamValidator(authoring.DRAFT_SCHEMA,
        format_checker=FormatChecker()).iter_errors(value), key=lambda error: str(error.path))
    require(not errors, "authoring history draft schema: " + (errors[0].message if errors else ""))
    value = authoring._semantic(value, allow_unbound=True)
    require(value["purpose"] == "later_documentation" and value["recordBinding"] is None,
        "authoring history requires unchanged unbound later-documentation drafts")
    return value


def _transition(previous_raw, revised_raw):
    """Apply the frozen V1 append-only rules without fabricating recordBinding."""
    previous, revised = _admit(previous_raw), _admit(revised_raw)
    require(revised["draftId"] == previous["draftId"]
        and revised["workId"] == previous["workId"]
        and revised["purpose"] == previous["purpose"],
        "authoring history draft identity/purpose changed")
    require(uint(revised["revision"], 64) == uint(previous["revision"], 64) + 1
        and revised["previousRevisionHash"] == keccak256(previous_raw),
        "authoring history revision lineage differs")
    require(revised["createdAt"] == previous["createdAt"]
        and revised["sourceAuthor"] == previous["sourceAuthor"],
        "authoring history creator/source author changed")
    require(authoring._timestamp(revised["revisedAt"])
        >= authoring._timestamp(previous["revisedAt"]),
        "authoring history revision time moved backward")
    require(revised["recordBinding"] is None,
        "authoring history draft binding changed")
    for collection in ("mappers", "reviewers"):
        old = {row["entityId"]: row for row in previous[collection]}
        new = {row["entityId"]: row for row in revised[collection]}
        require(set(old) <= set(new), "authoring history " + collection + " stable identity removed")
        require(all(old[identifier]["kind"] == new[identifier]["kind"] for identifier in old),
            "authoring history " + collection + " actor kind changed")
    before_confirmed = [row for row in previous["sourceVersions"] if row["status"] == "confirmed"]
    after = {row["versionId"]: row for row in revised["sourceVersions"]}
    require(all(after.get(row["versionId"]) == row for row in before_confirmed),
        "authoring history confirmed source version changed or disappeared")
    for collection, key, invariant in (
        ("entities", "entityId", ("kind",)),
        ("relationships", "relationshipId", ("type", "subjectId", "objectId")),
        ("dates", "dateId", ("entityId", "kind")),
        ("measurements", "measurementId", ("entityId", "type")),
        ("attachments", "attachmentId", ("entityId", "role")),
        ("authorityDecisions", "decisionId", ("entityId", "authority", "status")),
        ("reviews", "reviewId", ("reviewerId", "targetKind", "targetId", "targetSnapshot",
            "targetHash", "status", "reviewedAt", "rationale")),
    ):
        old = {row[key]: row for row in previous[collection]}
        new = {row[key]: row for row in revised[collection]}
        require(set(old) <= set(new), "authoring history " + collection + " stable identity removed")
        require(all(all(old[identifier][field] == new[identifier][field] for field in invariant)
            for identifier in old), "authoring history " + collection + " stable identity retargeted")
    return revised


def _preview(raw, value, binding_hash):
    targets = {"relationship": ("relationships", "relationshipId"),
        "date": ("dates", "dateId"), "measurement": ("measurements", "measurementId"),
        "authority_decision": ("authorityDecisions", "decisionId")}
    reviews = []
    for row in value["reviews"]:
        collection, key = targets[row["targetKind"]]
        current = next(item for item in value[collection] if item[key] == row["targetId"])
        reviews.append({"reviewId": row["reviewId"], "targetId": row["targetId"],
            "status": row["status"], "application": "current_target"
                if keccak256(dumps(current)) == row["targetHash"] else "historical_target"})
    return dumps({"mode": MODE, "draftHash": keccak256(raw),
        "draftSchemaHash": authoring.SCHEMA_HASH, "supplementalSourceBindingHash": binding_hash,
        "draftId": value["draftId"], "revision": value["revision"],
        "purpose": value["purpose"], "recordBinding": None,
        "sourceVersions": deepcopy(value["sourceVersions"]), "reviewDispositions": reviews,
        "counts": {key: len(value[key]) for key in ("entities", "relationships", "dates",
            "measurements", "attachments", "authorityDecisions", "reviews")},
        "claims": CLAIMS, "qualification": QUALIFICATION})


def _compose(revisions, source_files, source_hash, plan_raw, plan_hash, capture_form_raw,
             disclosure):
    _public(disclosure)
    require(type(revisions) in (list, tuple) and 1 <= len(revisions) <= MAX_REVISIONS,
        "authoring history revision count bound")
    require(type(source_files) is dict and 0 < len(source_files) <= MAX_FILES
        and all(type(path) is str and type(raw) is bytes for path, raw in source_files.items())
        and sum(map(len, source_files.values())) <= MAX_BYTES,
        "authoring history source package bound")
    package._bounded(source_files)
    evidence = sources.admit(dict(source_files), source_hash, plan_raw, plan_hash,
        disclosure=disclosure)
    require(type(evidence.binding) is dict and type(evidence.report) is dict,
        "authoring history concrete source evidence differs")
    binding_raw = dumps(evidence.binding)
    binding_hash = keccak256(binding_raw)
    values = [_admit(raw) for raw in revisions]
    first = values[0]
    require(first["revision"] == "1" and first["previousRevisionHash"] is None,
        "authoring history must begin at original revision one")
    require(evidence.binding.get("subject", {}).get("workCitation") == first["workId"],
        "authoring history source work citation differs")
    for before, after in zip(revisions, revisions[1:]):
        _transition(before, after)
    output = {"source/" + path: raw for path, raw in source_files.items()}
    output[PLAN_PATH] = plan_raw
    if capture_form_raw is not None:
        require(type(capture_form_raw) is bytes
            and capture.capture(capture_form_raw) == revisions[0],
            "authoring history capture form differs from original revision")
        output[FORM_PATH] = capture_form_raw
    rows = []
    for number, (raw, value) in enumerate(zip(revisions, values), 1):
        draft_path, preview_path = _path(number), _path(number, "previews")
        preview = _preview(raw, value, binding_hash)
        output[draft_path], output[preview_path] = raw, preview
        rows.append({"revision": str(number), "draft": package._ref(draft_path, raw),
            "preview": package._ref(preview_path, preview),
            "previousRevisionHash": value["previousRevisionHash"]})
    output[INDEX_PATH] = dumps({"mode": MODE, "draftId": first["draftId"],
        "workId": first["workId"], "purpose": first["purpose"], "revisions": rows,
        "latestRevision": str(len(rows)), "historyPruned": False})
    output[BINDING_PATH] = dumps({"binding": evidence.binding, "bindingHash": binding_hash,
        "source": evidence.report, "immutableAcrossHistory": True,
        "draftRecordBinding": None, "sourceAuthorCorrespondenceInferred": False,
        "publicationAuthorityInferred": False})
    report = {"profile": NAME, "profileHash": PROFILE_HASH, "mode": MODE,
        "draftId": first["draftId"], "workId": first["workId"],
        "revisionCount": str(len(rows)), "latestDraftHash": keccak256(revisions[-1]),
        "sourceKind": evidence.report["sourceKind"], "sourceEvidenceReplayed": True,
        "captureFormRetained": capture_form_raw is not None,
        "sourceBindingHash": binding_hash, "claims": CLAIMS, "qualification": QUALIFICATION}
    output.update({"definitions/profile.json": PROFILE_BYTES,
        "definitions/draft-schema.json": authoring.SCHEMA_BYTES,
        "definitions/source-profile.json": sources.PROFILE_BYTES,
        "definitions/capture-profile.json": capture.PROFILE_BYTES,
        "report.json": dumps(report)})
    package._bounded(output)
    manifest = dumps({"mode": MODE, "profile": NAME, "version": "2",
        "profileHash": PROFILE_HASH, "disclosure": disclosure,
        "revisionCount": str(len(rows)), "sourceManifestHash": source_hash,
        "sourcePlanHash": plan_hash, "sourceBindingHash": binding_hash,
        "captureFormHash": None if capture_form_raw is None else keccak256(capture_form_raw),
        "files": [package._ref(path, raw) for path, raw in sorted(output.items())],
        "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(manifest) <= MAX_MANIFEST, "authoring history manifest byte bound")
    output["manifest.json"] = manifest
    package._bounded(output)
    return package.Assembly(tuple(sorted(output.items())), manifest, report)


def compose(revisions, source_files, source_hash, plan_raw, plan_hash, *,
            capture_form_raw=None, disclosure):
    try:
        return _compose(revisions, source_files, source_hash, plan_raw, plan_hash,
            capture_form_raw, disclosure)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, OSError, RecursionError) as exc:
        raise MuseumError("malformed authoring history input") from exc


def start(draft_raw, source_files, source_hash, plan_raw, plan_hash, *,
          capture_form_raw=None, disclosure):
    return compose([draft_raw], source_files, source_hash, plan_raw, plan_hash,
        capture_form_raw=capture_form_raw, disclosure=disclosure)


def start_from_form(form_raw, source_files, source_hash, plan_raw, plan_hash, *, disclosure):
    _public(disclosure)
    return start(capture.capture(form_raw), source_files, source_hash, plan_raw, plan_hash,
        capture_form_raw=form_raw, disclosure=disclosure)


def _inputs(files, manifest):
    return ({path.removeprefix("source/"): raw for path, raw in files.items()
        if path.startswith("source/")}, manifest["sourceManifestHash"],
        files[PLAN_PATH], manifest["sourcePlanHash"], files.get(FORM_PATH))


def verify(files, expected_hash):
    try:
        files = dict(files)
        package._bounded(files)
        raw = files.get("manifest.json", b"")
        require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
            "authoring history external manifest differs")
        manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
        require(type(manifest) is dict and set(manifest) == {"mode", "profile", "version",
            "profileHash", "disclosure", "revisionCount", "sourceManifestHash",
            "sourcePlanHash", "sourceBindingHash", "captureFormHash", "files", "claims",
            "qualification"}
            and manifest["mode"] == MODE and manifest["profile"] == NAME
            and manifest["version"] == "2" and manifest["profileHash"] == PROFILE_HASH
            and manifest["claims"] == CLAIMS and manifest["qualification"] == QUALIFICATION,
            "authoring history closed manifest differs")
        _public(manifest["disclosure"])
        count = uint(manifest["revisionCount"], 16)
        require(1 <= count <= MAX_REVISIONS, "authoring history revision count bound")
        require(manifest["files"] == [package._ref(path, body) for path, body in sorted(files.items())
            if path != "manifest.json"], "authoring history file commitments differ")
        require(files.get("definitions/profile.json") == PROFILE_BYTES
            and files.get("definitions/draft-schema.json") == authoring.SCHEMA_BYTES
            and files.get("definitions/source-profile.json") == sources.PROFILE_BYTES
            and files.get("definitions/capture-profile.json") == capture.PROFILE_BYTES,
            "authoring history retained definitions differ")
        form = files.get(FORM_PATH)
        require(manifest["captureFormHash"] == (None if form is None else keccak256(form)),
            "authoring history capture form commitment differs")
        source_files, source_hash, plan_raw, plan_hash, form = _inputs(files, manifest)
        result = compose([files[_path(index)] for index in range(1, count + 1)],
            source_files, source_hash, plan_raw, plan_hash, capture_form_raw=form,
            disclosure=manifest["disclosure"])
        require(result.report["sourceBindingHash"] == manifest["sourceBindingHash"]
            and dict(result.files) == files,
            "authoring history full reconstruction differs")
        return result
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, OSError, RecursionError) as exc:
        raise MuseumError("malformed authoring history package") from exc


def revise(previous_files, previous_hash, revised_raw, *, disclosure):
    _public(disclosure)
    previous = verify(previous_files, previous_hash)
    return _append(previous, revised_raw, disclosure)


def _append(previous, revised_raw, disclosure):
    files = dict(previous.files)
    manifest = loads(previous.manifest, maximum=MAX_MANIFEST, canonical=True)
    count = uint(manifest["revisionCount"], 16)
    source_files, source_hash, plan_raw, plan_hash, form = _inputs(files, manifest)
    return compose([files[_path(index)] for index in range(1, count + 1)] + [revised_raw],
        source_files, source_hash, plan_raw, plan_hash, capture_form_raw=form,
        disclosure=disclosure)


def confirm(previous_files, previous_hash, version_id, *, confirmed_by, confirmed_at,
            revised_at, disclosure):
    _public(disclosure)
    previous = verify(previous_files, previous_hash)
    latest = dict(previous.files)[_path(uint(previous.report["revisionCount"], 16))]
    revised = capture.confirm(latest, version_id, confirmed_by=confirmed_by,
        confirmed_at=confirmed_at, revised_at=revised_at)
    return _append(previous, revised, disclosure)


def review(previous_files, previous_hash, review_value, *, revised_at, disclosure):
    _public(disclosure)
    previous = verify(previous_files, previous_hash)
    latest = dict(previous.files)[_path(uint(previous.report["revisionCount"], 16))]
    revised = capture.review(latest, review_value, revised_at=revised_at)
    return _append(previous, revised, disclosure)


def _read(path, maximum, expected_hash=None):
    require(not path.is_symlink() and not (hasattr(path, "is_junction") and path.is_junction())
        and path.is_file(), "authoring history input must be regular file")
    with path.open("rb") as handle:
        raw = handle.read(maximum + 1)
    require(0 < len(raw) <= maximum, "authoring history input byte bound")
    if expected_hash is not None:
        require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
            "authoring history input pin differs")
    return raw


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    bind_cmd = commands.add_parser("bind")
    bind_cmd.add_argument("--draft", type=Path, required=True)
    bind_cmd.add_argument("--source", type=Path, required=True)
    bind_cmd.add_argument("--source-hash", required=True)
    bind_cmd.add_argument("--plan", type=Path, required=True)
    bind_cmd.add_argument("--plan-hash", required=True)
    capture_cmd = commands.add_parser("capture")
    capture_cmd.add_argument("--form", type=Path, required=True)
    capture_cmd.add_argument("--form-hash", required=True)
    capture_cmd.add_argument("--source", type=Path, required=True)
    capture_cmd.add_argument("--source-hash", required=True)
    capture_cmd.add_argument("--plan", type=Path, required=True)
    capture_cmd.add_argument("--plan-hash", required=True)
    for name in ("revise", "confirm", "review"):
        command = commands.add_parser(name)
        command.add_argument("--package", type=Path, required=True)
        command.add_argument("--package-hash", required=True)
    commands.choices["revise"].add_argument("--draft", type=Path, required=True)
    command = commands.choices["confirm"]
    command.add_argument("--version-id", required=True)
    command.add_argument("--confirmed-by", required=True)
    command.add_argument("--confirmed-at", required=True)
    command.add_argument("--revised-at", required=True)
    command = commands.choices["review"]
    command.add_argument("--review", type=Path, required=True)
    command.add_argument("--review-hash", required=True)
    command.add_argument("--revised-at", required=True)
    for name in ("bind", "capture", "revise", "confirm", "review"):
        command = commands.choices[name]
        command.add_argument("--disclosure", required=True)
        command.add_argument("--output", type=Path, required=True)
    verify_cmd = commands.add_parser("verify")
    verify_cmd.add_argument("directory", type=Path)
    verify_cmd.add_argument("--manifest-hash", required=True)
    commands.add_parser("profiles")
    args = parser.parse_args(argv)
    try:
        if args.command == "profiles":
            print(dumps({"profile": NAME, "profileHash": PROFILE_HASH, "mode": MODE,
                "draftSchemaHash": authoring.SCHEMA_HASH,
                "sourceProfileHash": sources.PROFILE_HASH}).decode("utf-8"))
            return
        if args.command == "verify":
            result = verify(read_tree(args.directory), args.manifest_hash)
        else:
            _public(args.disclosure)
            from .repository_exchange import _destination, _publish
            if args.command in ("bind", "capture"):
                first = args.draft if args.command == "bind" else args.form
                input_paths = [first, args.source, args.plan]
                _destination(args.output, input_paths)
                plan_raw = _read(args.plan, authoring.MAX_DRAFT_BYTES, args.plan_hash)
                if args.command == "bind":
                    result = start(_read(args.draft, authoring.MAX_DRAFT_BYTES),
                        read_tree(args.source), args.source_hash, plan_raw, args.plan_hash,
                        disclosure=args.disclosure)
                else:
                    result = start_from_form(_read(args.form, authoring.MAX_DRAFT_BYTES,
                        args.form_hash), read_tree(args.source), args.source_hash,
                        plan_raw, args.plan_hash, disclosure=args.disclosure)
            else:
                input_paths = [args.package]
                if args.command == "revise": input_paths.append(args.draft)
                if args.command == "review": input_paths.append(args.review)
                _destination(args.output, input_paths)
                files = read_tree(args.package)
                if args.command == "revise":
                    result = revise(files, args.package_hash,
                        _read(args.draft, authoring.MAX_DRAFT_BYTES), disclosure=args.disclosure)
                elif args.command == "confirm":
                    result = confirm(files, args.package_hash, args.version_id,
                        confirmed_by=args.confirmed_by, confirmed_at=args.confirmed_at,
                        revised_at=args.revised_at, disclosure=args.disclosure)
                else:
                    review_value = loads(_read(args.review, authoring.MAX_DRAFT_BYTES,
                        args.review_hash), maximum=authoring.MAX_DRAFT_BYTES, canonical=True)
                    result = review(files, args.package_hash, review_value,
                        revised_at=args.revised_at, disclosure=args.disclosure)
            _publish(dict(result.files), args.output, input_paths)
        print(dumps({"manifestHash": result.manifest_hash, "report": result.report}).decode("utf-8"))
    except MuseumError as exc:
        parser.exit(2, str(exc) + "\n")


if __name__ == "__main__":
    main()
