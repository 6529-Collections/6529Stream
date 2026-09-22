"""Bind an unchanged unbound authoring draft to exact native Artist evidence.

This additive envelope does not modify the frozen semantic-authoring draft or
its recordBinding union.  It retains and replays a complete native attribution
dossier, then records exact token-subject correspondence separately.  The
correspondence does not prove token existence, current Artist authorization,
publication permission, or source-author identity.
"""

import argparse
from dataclasses import dataclass
from pathlib import Path
from tempfile import TemporaryDirectory

from jsonschema import FormatChecker

from . import attribution_dossier
from . import object_dossier as package
from . import semantic_authoring as authoring
from .bagit import MAX_BYTES, MAX_FILES, MAX_MANIFEST, read_tree, write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, subject_id, uint
from .citations import canonical_citation
from .independent_wire import require
from .package_v2 import _dependencies
from .validation import StreamValidator


NAME = "STREAM_MUSEUM_SEMANTIC_AUTHORING_NATIVE_SOURCES_V1"
MODE = "semantic_authoring_native_source_envelope_v1"
PLAN_KIND = "native_attribution_dossier"
PLAN_PATH = "input/source-plan.json"
DRAFT_PATH = "input/draft.json"
ENVELOPE_PATH = "authoring/native-binding-envelope.json"
MAX_PLAN = 524288
MODEL_ROOT = attribution_dossier.DEFAULT_MODEL_ROOT

CLAIMS = {
    "completeNativeAttributionDossierReplayed": True,
    "modelDependencyClosureRetained": True,
    "exactWholeRecordSelection": True,
    "exactTokenSubjectCorrespondence": True,
    "canonicalTokenCitationCorrespondence": True,
    "originalDraftBytesRetained": True,
    "originalDraftSchemaUnchanged": True,
    "draftRecordBindingChanged": False,
    "tokenExistenceProven": False,
    "coreTokenMembershipProven": False,
    "sourceAuthorCorrespondenceProven": False,
    "artistConfirmationProven": False,
    "currentArtistAuthorizationProven": False,
    "publicationAuthorityGranted": False,
    "consensusOrFinalityProven": False,
    "institutionalAcceptance": False,
    "networkFetch": False,
}
QUALIFICATION = (
    "Offline additive binding of a byte-identical unbound later-documentation draft to one "
    "exact, supported whole-record occurrence in a fully replayed native Artist attribution "
    "dossier. The supplied token ID is accepted only when its canonical native subject digest "
    "and citation match the retained source and draft. The observed collection remains context "
    "and is not an input to the token-subject digest. Hash correspondence does not establish "
    "that the token exists or belongs to the Core. Historical authority and current qualification "
    "remain distinct retained evidence. The envelope does not authenticate the draft source "
    "author, infer Artist confirmation or current authorization, or grant publication authority."
)
PROFILE_BYTES = dumps({
    "name": NAME,
    "version": "1",
    "mode": MODE,
    "status": "prospective_unregistered_local_adapter",
    "source": attribution_dossier.PROFILE,
    "draftSchema": authoring.NAME,
    "draftSchemaHash": authoring.SCHEMA_HASH,
    "binding": (
        "A separate envelope around the unchanged draft. The retained draft remains unbound "
        "and recordBinding remains null."
    ),
    "selection": "One exact supported whole-record NativeAttribution selector.",
    "subject": "Chain/Core/token subject digest and canonical citation correspondence only; collection is retained context.",
    "dependencies": "Exact recorded Linked Art validation closure retained and used for offline source replay.",
    "limits": {
        "planBytes": str(MAX_PLAN),
        "draftBytes": str(authoring.MAX_DRAFT_BYTES),
        "files": str(MAX_FILES),
        "aggregateBytes": str(MAX_BYTES),
        "manifestBytes": str(MAX_MANIFEST),
    },
    "claims": CLAIMS,
    "qualification": QUALIFICATION,
})
PROFILE_HASH = keccak256(PROFILE_BYTES)


@dataclass(frozen=True)
class NativeBinding:
    envelope: bytes
    value: dict
    report: dict

    @property
    def envelope_hash(self):
        return keccak256(self.envelope)


def _public(disclosure):
    require(disclosure == "public", "native authoring public disclosure required before reads")


def _pin(raw, digest, maximum, label):
    require(type(raw) is bytes and 0 < len(raw) <= maximum
        and any(hex_bytes(digest, 32)) and keccak256(raw) == digest,
        "native authoring " + label + " pin/bound differs")


def _plan(raw, expected_hash, source_manifest_hash):
    _pin(raw, expected_hash, MAX_PLAN, "plan")
    value = loads(raw, maximum=MAX_PLAN, canonical=True)
    require(type(value) is dict and set(value) == {
        "version", "kind", "manifestHash", "semanticSourceSelector", "tokenId"
    } and value["version"] == "1" and value["kind"] == PLAN_KIND
        and value["manifestHash"] == source_manifest_hash,
        "native authoring closed plan/source differs")
    require(type(value["semanticSourceSelector"]) is dict
        and value["semanticSourceSelector"].get("pointer") == "",
        "native authoring whole-record semantic selector required")
    require(uint(value["tokenId"]) > 0,
        "native authoring nonzero canonical uint256 tokenId required")
    return value


def _draft(raw):
    require(type(raw) is bytes and 0 < len(raw) <= authoring.MAX_DRAFT_BYTES,
        "native authoring draft byte bound")
    value = loads(raw, maximum=authoring.MAX_DRAFT_BYTES, canonical=True)
    errors = sorted(StreamValidator(authoring.DRAFT_SCHEMA,
        format_checker=FormatChecker()).iter_errors(value), key=lambda error: str(error.path))
    require(not errors, "native authoring draft schema: " + (errors[0].message if errors else ""))
    value = authoring._semantic(value, allow_unbound=True)
    require(value["purpose"] == "later_documentation"
        and value["recordBinding"] is None,
        "native authoring requires unchanged unbound later-documentation draft")
    return value


def _source(files, expected_hash, plan, model_root):
    require(type(files) is dict and 0 < len(files) <= MAX_FILES
        and all(type(path) is str and type(raw) is bytes for path, raw in files.items())
        and sum(map(len, files.values())) <= MAX_BYTES,
        "native authoring source package bound")
    originals = dict(files)
    report = attribution_dossier.verify_files(originals, expected_hash, model_root=model_root)
    require(plan["manifestHash"] == expected_hash,
        "native authoring plan source manifest differs")
    require("semantics/snapshot.json" in originals and "dossier.json" in originals,
        "native authoring semantic source component required")
    semantic = loads(originals["semantics/snapshot.json"], maximum=attribution_dossier.MAX_BYTES,
        canonical=True)
    dossier = loads(originals["dossier.json"], maximum=attribution_dossier.MAX_BYTES,
        canonical=True)
    require(dossier.get("semanticEvidence") == semantic,
        "native authoring retained semantic dossier differs")
    matches = [row for row in semantic.get("statements", [])
        if row.get("source") == plan["semanticSourceSelector"]]
    require(len(matches) == 1,
        "native authoring exact semantic source occurrence missing or duplicate")
    row = matches[0]
    require(row.get("status") == "supported" and row.get("reasonCode") is None
        and row.get("value") is not None,
        "native authoring selected semantic source is unsupported")
    attestations = dossier.get("nativeArtistEvidence", {}).get("attestations", [])
    evidence = [item for item in attestations
        if item.get("metadataRecordHash") == row["source"]["recordHash"]]
    require(len(evidence) == 1 and evidence[0].get("attestationRecordHash") == row.get("nativeEvidenceRecordHash")
        and evidence[0].get("metadataOriginal") == row.get("original")
        and evidence[0].get("historicalAuthority") == row.get("historicalAuthority")
        and evidence[0].get("current") == row.get("currentQualification"),
        "native authoring semantic/native Artist evidence differs")
    original = row["original"]
    subject_kind = original.get("subjectKind")
    if subject_kind == "collection":
        require(False, "native authoring collection subject cannot bind a token draft")
    if subject_kind != "host_admitted_token_subject":
        require(False, "native authoring media or unsupported subject cannot bind a token draft")
    state = semantic.get("sourceState")
    require(type(state) is dict and all(key in state for key in ("chainId", "core", "collectionId")),
        "native authoring source state identity missing")
    token_id = plan["tokenId"]
    digest = subject_id("token", state["chainId"], state["core"], state["collectionId"],
        token_id=token_id)
    require(digest == row["source"]["subjectId"]
        and digest == original["record"][1],
        "native authoring token subject digest differs")
    citation = canonical_citation(state["chainId"], state["core"], token_id)
    return originals, report, semantic, row, evidence[0], citation


def _binding(draft_raw, source_files, source_manifest_hash, plan_raw, plan_hash,
             disclosure, model_root):
    _public(disclosure)
    plan = _plan(plan_raw, plan_hash, source_manifest_hash)
    draft = _draft(draft_raw)
    originals, source_report, semantic, row, evidence, citation = _source(
        source_files, source_manifest_hash, plan, Path(model_root).resolve())
    require(draft["workId"] == citation,
        "native authoring draft work citation differs from exact token subject")
    state = semantic["sourceState"]
    envelope = {
        "profile": NAME,
        "profileHash": PROFILE_HASH,
        "version": "1",
        "kind": "native_attribution_token_binding",
        "disclosure": disclosure,
        "draftHash": keccak256(draft_raw),
        "sourceManifestHash": source_manifest_hash,
        "sourcePlanHash": plan_hash,
        "sourcePlan": plan,
        "semanticSnapshotHash": keccak256(originals["semantics/snapshot.json"]),
        "sourceStateHash": keccak256(dumps(state)),
        "semanticSourceSelector": row["source"],
        "subject": {
            "kind": "token",
            "subjectId": row["source"]["subjectId"],
            "chainId": state["chainId"],
            "core": state["core"],
            "collectionId": state["collectionId"],
            "collectionContextInSubjectDigest": False,
            "tokenId": plan["tokenId"],
            "workCitation": citation,
            "correspondence": "native_subject_hash_and_canonical_citation",
            "tokenExistenceProven": False,
            "coreTokenMembershipProven": False,
        },
        "originalEvidence": {
            "metadataRecordHash": evidence["metadataRecordHash"],
            "attestationRecordHash": evidence["attestationRecordHash"],
            "metadataOriginalHash": keccak256(dumps(evidence["metadataOriginal"])),
            "metadataReceiptHash": keccak256(dumps(evidence["metadataOriginal"]["receipt"])),
            "payloadHash": evidence["metadataOriginal"]["record"][2][1],
            "signatureHash": keccak256(hex_bytes(evidence["signatureHex"])),
            "recordPreimageHash": keccak256(hex_bytes(evidence["recordPreimageHex"])),
            "historicalAuthority": evidence["historicalAuthority"],
            "currentQualification": evidence["current"],
            "semanticSnapshot": package._ref("source/semantics/snapshot.json",
                originals["semantics/snapshot.json"]),
            "artistSnapshot": package._ref("source/artist/snapshot.json",
                originals["artist/snapshot.json"]),
            "dossier": package._ref("source/dossier.json", originals["dossier.json"]),
        },
        "draftBinding": None,
        "claims": CLAIMS,
        "qualification": QUALIFICATION,
    }
    raw = dumps(envelope)
    report = {
        "profile": NAME,
        "profileHash": PROFILE_HASH,
        "mode": MODE,
        "status": "bound_native_subject_correspondence",
        "sourceProfile": attribution_dossier.PROFILE,
        "sourceProvenance": source_report["provenance"],
        "draftId": draft["draftId"],
        "workId": draft["workId"],
        "tokenId": plan["tokenId"],
        "subjectId": row["source"]["subjectId"],
        "sourceRecordStatus": row["status"],
        "currentQualificationRetained": True,
        "claims": CLAIMS,
        "qualification": QUALIFICATION,
    }
    return NativeBinding(raw, envelope, report)


def bind(draft_raw, source_files, source_manifest_hash, plan_raw, plan_hash, *, disclosure,
         model_root=MODEL_ROOT):
    """Replay source evidence and create the additive native binding envelope."""
    try:
        return _binding(draft_raw, source_files, source_manifest_hash,
            plan_raw, plan_hash, disclosure, model_root)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError("malformed native authoring binding input") from exc


def validate(draft_raw, envelope_raw, source_files, source_manifest_hash, *, disclosure,
             model_root=MODEL_ROOT):
    """Rebuild and compare an envelope from its retained closed source plan."""
    try:
        _public(disclosure)
        require(type(envelope_raw) is bytes and 0 < len(envelope_raw) <= MAX_MANIFEST,
            "native authoring envelope byte bound")
        value = loads(envelope_raw, maximum=MAX_MANIFEST, canonical=True)
        require(type(value) is dict and value.get("profile") == NAME
            and value.get("profileHash") == PROFILE_HASH and value.get("disclosure") == disclosure
            and type(value.get("sourcePlan")) is dict,
            "native authoring envelope profile/plan differs")
        plan_raw = dumps(value["sourcePlan"])
        expected = bind(draft_raw, source_files, source_manifest_hash, plan_raw,
            value.get("sourcePlanHash"), disclosure=disclosure, model_root=model_root)
        require(expected.envelope == envelope_raw,
            "native authoring envelope does not reconstruct")
        return expected
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError("malformed native authoring envelope") from exc


def compose(draft_raw, source_files, source_manifest_hash, plan_raw, plan_hash, *, disclosure,
            model_root=MODEL_ROOT):
    """Build a portable package retaining the draft, plan, envelope, and source."""
    binding = bind(draft_raw, source_files, source_manifest_hash, plan_raw, plan_hash,
        disclosure=disclosure, model_root=model_root)
    originals = dict(source_files)
    output = {"source/" + path: raw for path, raw in originals.items()}
    output.update(_dependencies(Path(model_root).resolve(), recorded=True))
    output.update({
        DRAFT_PATH: draft_raw,
        PLAN_PATH: plan_raw,
        ENVELOPE_PATH: binding.envelope,
        "definitions/profile.json": PROFILE_BYTES,
        "definitions/draft-schema.json": authoring.SCHEMA_BYTES,
        "report.json": dumps(binding.report),
    })
    package._bounded(output)
    manifest = dumps({
        "mode": MODE,
        "profile": NAME,
        "version": "1",
        "profileHash": PROFILE_HASH,
        "disclosure": disclosure,
        "draftHash": keccak256(draft_raw),
        "sourceManifestHash": source_manifest_hash,
        "sourcePlanHash": plan_hash,
        "envelopeHash": binding.envelope_hash,
        "files": [package._ref(path, raw) for path, raw in sorted(output.items())],
        "claims": CLAIMS,
        "qualification": QUALIFICATION,
    })
    require(len(manifest) <= MAX_MANIFEST, "native authoring manifest byte bound")
    output["manifest.json"] = manifest
    package._bounded(output)
    return package.Assembly(tuple(sorted(output.items())), manifest, binding.report)


def verify(files, expected_hash):
    """Verify and fully rebuild a portable native authoring binding package."""
    try:
        files = dict(files)
        package._bounded(files)
        raw = files.get("manifest.json", b"")
        require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
            "native authoring external manifest differs")
        manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
        require(type(manifest) is dict and set(manifest) == {
            "mode", "profile", "version", "profileHash", "disclosure", "draftHash",
            "sourceManifestHash", "sourcePlanHash", "envelopeHash", "files", "claims",
            "qualification"
        } and manifest["mode"] == MODE and manifest["profile"] == NAME
            and manifest["version"] == "1" and manifest["profileHash"] == PROFILE_HASH
            and manifest["claims"] == CLAIMS and manifest["qualification"] == QUALIFICATION,
            "native authoring closed manifest differs")
        _public(manifest["disclosure"])
        require(manifest["files"] == [package._ref(path, body) for path, body in sorted(files.items())
            if path != "manifest.json"], "native authoring file commitments differ")
        require(files.get("definitions/profile.json") == PROFILE_BYTES
            and files.get("definitions/draft-schema.json") == authoring.SCHEMA_BYTES,
            "native authoring retained definitions differ")
        source_files = {path.removeprefix("source/"): body for path, body in files.items()
            if path.startswith("source/")}
        draft_raw, plan_raw, envelope_raw = files[DRAFT_PATH], files[PLAN_PATH], files[ENVELOPE_PATH]
        require(manifest["draftHash"] == keccak256(draft_raw)
            and manifest["sourcePlanHash"] == keccak256(plan_raw)
            and manifest["envelopeHash"] == keccak256(envelope_raw),
            "native authoring retained input hash differs")
        dependencies = {path.removeprefix("dependencies/"): body for path, body in files.items()
            if path.startswith("dependencies/")}
        with TemporaryDirectory(prefix="stream-native-authoring-model-") as temporary:
            root = Path(temporary) / "model"
            write_tree(dependencies, root)
            validate(draft_raw, envelope_raw, source_files, manifest["sourceManifestHash"],
                disclosure=manifest["disclosure"], model_root=root)
            result = compose(draft_raw, source_files, manifest["sourceManifestHash"], plan_raw,
                manifest["sourcePlanHash"], disclosure=manifest["disclosure"], model_root=root)
        require(dict(result.files) == files, "native authoring full reconstruction differs")
        return result
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError("malformed native authoring package") from exc


def _read(path, maximum, expected_hash=None):
    require(not path.is_symlink() and not (hasattr(path, "is_junction") and path.is_junction())
        and path.is_file(), "native authoring input must be regular file")
    with path.open("rb") as handle:
        raw = handle.read(maximum + 1)
    require(0 < len(raw) <= maximum, "native authoring input byte bound")
    if expected_hash is not None:
        _pin(raw, expected_hash, maximum, "input")
    return raw


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    bind_cmd = commands.add_parser("bind")
    bind_cmd.add_argument("--draft", type=Path, required=True)
    bind_cmd.add_argument("--source", type=Path, required=True)
    bind_cmd.add_argument("--source-manifest-hash", required=True)
    bind_cmd.add_argument("--plan", type=Path, required=True)
    bind_cmd.add_argument("--plan-hash", required=True)
    bind_cmd.add_argument("--disclosure", required=True)
    bind_cmd.add_argument("--output", type=Path, required=True)
    verify_cmd = commands.add_parser("verify")
    verify_cmd.add_argument("directory", type=Path)
    verify_cmd.add_argument("--manifest-hash", required=True)
    commands.add_parser("profiles")
    args = parser.parse_args(argv)
    try:
        if args.command == "profiles":
            print(dumps({"profile": NAME, "profileHash": PROFILE_HASH,
                "mode": MODE, "draftSchemaHash": authoring.SCHEMA_HASH}).decode("utf-8"))
            return
        if args.command == "verify":
            result = verify(read_tree(args.directory), args.manifest_hash)
        else:
            _public(args.disclosure)
            from .repository_exchange import _destination, _publish
            sources = [args.draft, args.source, args.plan]
            _destination(args.output, sources)
            draft_raw = _read(args.draft, authoring.MAX_DRAFT_BYTES)
            plan_raw = _read(args.plan, MAX_PLAN, args.plan_hash)
            result = compose(draft_raw, read_tree(args.source), args.source_manifest_hash,
                plan_raw, args.plan_hash, disclosure=args.disclosure)
            _publish(dict(result.files), args.output, sources)
        print(dumps({"manifestHash": result.manifest_hash, "report": result.report}).decode("utf-8"))
    except MuseumError as exc:
        parser.exit(2, str(exc) + "\n")


if __name__ == "__main__":
    main()
