"""Closed requirement inventory for complete object-dossier assessment.

This module accounts for requirements.  It does not authenticate evidence,
register a profile, perform an institutional ingest, or establish protocol or
release conformance.  Internal source adapters may construct
``EvidenceRef`` values only after performing those domain checks.
"""
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path
import re

from .canonical import MuseumError, dumps, hex_bytes, keccak256

NAME = "STREAM_OBJECT_DOSSIER_REQUIREMENTS_V1"
ASSESSMENT_NAME = "STREAM_OBJECT_DOSSIER_REQUIREMENT_ASSESSMENT_V1"
VERSION = "1"
QUALIFICATION = ("Requirement coverage only. Even complete coverage does not establish protocol "
    "conformance, release readiness, chain consensus, institutional acceptance, source authority, "
    "or correctness of an evidence adapter beyond its separately verified inputs.")


def _row(code, home, description, applicability="all", allowed_absence="none"):
    return {"code": code, "home": home, "description": description,
        "applicability": applicability, "allowedAbsence": allowed_absence}


REQUIREMENTS = (
    _row("identity", "CMC-OBJECT-DOSSIER:intro",
        "Canonical chain, Core, token, collection, serial and qualified citation identity."),
    _row("OD-FINALITY-STATUS", "CMC-OBJECT-DOSSIER:intro",
        "Exact finality status and qualifier for the dossier source state."),
    _row("OD-CONTENT-ROOT-PROOF", "CMC-OBJECT-DOSSIER:intro",
        "Content-root proof bound to the exact token and source state."),
    _row("OD-ENTROPY-PROVENANCE", "CMC-OBJECT-DOSSIER:intro",
        "Entropy request, provider, fulfillment or recovery provenance applicable to the mint."),
    _row("OD-SCRIPT-MANIFEST", "CMC-OBJECT-DOSSIER:intro",
        "Complete collection script manifest and its exact registered interpretation.",
        "script", "work_class_non_script_only"),
    _row("OD-DEPENDENCY-MANIFEST", "CMC-OBJECT-DOSSIER:intro",
        "Complete applicable collection dependency manifest, including verified-empty accounting."),
    _row("OD-MEDIA-MANIFEST", "CMC-OBJECT-DOSSIER:intro",
        "Complete applicable collection media manifest and occurrence-preserving entries."),
    _row("OD-ARTIST-INTENT-OR-WAIVER", "CMC-OBJECT-DOSSIER:intro",
        "Exact ARTIST_INTENT record or the canonical waiver that replaces it."),
    _row("OD-INTERVIEW", "CMC-OBJECT-DOSSIER:intro",
        "Authenticated interview status: an exact present record, an explicit waiver, or authenticated absence; omission is not absence.",
        "all", "authenticated_absence_only"),
    _row("OD-RIGHTS-COLLECTION", "CMC-OBJECT-DOSSIER:intro",
        "Complete collection-scope RIGHTS_STATEMENT records and verified-empty accounting.",
        "all", "verified_empty_lane_inventory_only"),
    _row("OD-RIGHTS-TOKEN", "CMC-OBJECT-DOSSIER:intro",
        "Complete token-scope RIGHTS_STATEMENT records and verified-empty accounting.",
        "all", "verified_empty_lane_inventory_only"),
    _row("OD-C2PA", "CMC-OBJECT-DOSSIER:intro",
        "Applicable C2PA references, or an exact verified-empty inventory.",
        "all", "verified_empty_lane_inventory_only"),
    _row("OD-IIIF", "CMC-OBJECT-DOSSIER:intro",
        "Applicable IIIF manifests, or an exact verified-empty inventory.",
        "all", "verified_empty_lane_inventory_only"),
    _row("OD-SIGNIFICANT-PROPERTIES", "CMC-OBJECT-DOSSIER:intro",
        "Significant-properties records needed to preserve the work's behavior and appearance."),
    _row("OD-TOKEN-LANE-COMPLETE", "CMC-OBJECT-DOSSIER:intro",
        "Complete applicable records and attestations keyed by the exact token subject."),
    _row("OD-TOKEN-LANE-HEADS", "CMC-OBJECT-DOSSIER:intro",
        "Every token-subject record-chain head at the dossier source state."),
    _row("OD-OWNER-LANE-COMPLETE", "CMC-OBJECT-DOSSIER:intro",
        "Complete applicable owner-record history without replacing owner attribution."),
    _row("OD-OWNER-LANE-HEADS", "CMC-OBJECT-DOSSIER:intro",
        "Every applicable owner-record chain head at the dossier source state."),
    _row("OD-INDEPENDENT-LANE-COMPLETE", "CMC-OBJECT-DOSSIER:intro",
        "Complete applicable independent-lane records without authority promotion."),
    _row("OD-INDEPENDENT-LANE-HEADS", "CMC-OBJECT-DOSSIER:intro",
        "Every applicable independent-lane record-chain head at the dossier source state."),
    _row("OD-TRANSFER-PROVENANCE", "CMC-OBJECT-DOSSIER:intro; CMC-ACQUISITION-PACKET:10",
        "Full mint and Transfer-derived ownership provenance through the dossier state."),
    _row("OD-TOMBSTONE", "CMC-OBJECT-DOSSIER:intro; CMC-TOMBSTONE",
        "The canonical work-description/tombstone record, or an authenticated absent status; omission is not absence.",
        "all", "authenticated_absence_only"),
    _row("OD-SCRIPT-DRILL", "CMC-OBJECT-DOSSIER:intro; CMC-ACQUISITION-PACKET:11",
        "Latest applicable script-work preservation drill outcome, or authenticated never_drilled status.",
        "script", "work_class_non_script_or_authenticated_never_drilled_only"),
    _row("OD-ATTRIBUTION", "CMC-OBJECT-DOSSIER:intro",
        "Exact attribution state at the dossier source state."),
    _row("OD-RENDER-INVENTORY", "CMC-OBJECT-DOSSIER:intro; CMC-PACKAGING:3",
        "Finite authoritative native render inventory proving complete-plan currentness and the occurrence roster; byte availability and fixity remain separate requirements."),
    _row("OD-TOOL-SOURCE-ARCHIVE", "CMC-OBJECT-DOSSIER:1",
        "Preserved dossier/packet tool source archive under reconstruction-client discipline."),
    _row("OD-TOOL-REPRODUCIBLE-BUILD", "CMC-OBJECT-DOSSIER:1",
        "Preserved reproducible build instructions for the dossier/packet tool."),
    _row("OD-TOOL-TEST-VECTORS", "CMC-OBJECT-DOSSIER:1",
        "Preserved deterministic dossier/packet reconstruction test vectors."),
    _row("OD-TOOL-MANIFEST-PIN", "CMC-OBJECT-DOSSIER:1",
        "Exact tool archive hash recorded in streamSystemManifest and mirrored under dual-family archival rules."),
    _row("OD-PACKET-REGEN-DRILL", "CMC-OBJECT-DOSSIER:2",
        "Museum-mode and preservation drill evidence for zero-operator packet regeneration."),
    _row("OD-OPERATOR-INDEPENDENT-REGEN", "CMC-OBJECT-DOSSIER:3",
        "End-to-end chain-state regeneration and component verification without an operator database or service."),
    _row("OD-INDEPENDENT-REPOSITORY-INGESTS", "CMC-OBJECT-DOSSIER:4",
        "Hash-committed ingest reports from both a named OCFL/Fedora-class path and a named Archivematica-class AIP path."),
    _row("OD-EXTERNAL-PRACTITIONER-REVIEWS", "CMC-OBJECT-DOSSIER:4",
        "Recorded, dispositioned reviews by named registrar/collections-management and time-based-media conservation practitioners."),
    _row("PKG-BAGIT-SERIALIZATION", "CMC-PACKAGING:1",
        "RFC 8493 BagIt serialization with SHA-256 payload/tag manifests and Stream Keccak-256 payload manifest."),
    _row("PKG-REQUIRED-TAGS", "CMC-PACKAGING:2",
        "Required bag-info fields and canonical stream-manifest commitments, heads and tool reference."),
    _row("PKG-AUTHORITATIVE-RENDER-BYTES", "CMC-PACKAGING:3",
        "All authoritative render-critical payload bytes embedded in data/ and hash-bound."),
    _row("PKG-NONCRITICAL-FETCH-COMMITMENTS", "CMC-PACKAGING:3",
        "Every fetch-only non-render-critical payload is content-addressed, manifest-committed and dual-family archived.",
        "all", "verified_empty_fetch_inventory_only"),
    _row("PKG-SELF-CONTAINMENT", "CMC-PACKAGING:3",
        "Typed self-containment state agrees across bag-info, stream-manifest and acquisition packet."),
    _row("PKG-OCFL-MAPPING", "CMC-PACKAGING:4",
        "Canonical citation, version state, content, heads, fixity and supersession map exactly into one OCFL object."),
    _row("PKG-PROFILE-REGISTRATION", "CMC-PACKAGING:5",
        "Exact registered bundle schema and packaging profile bytes and hashes; local validation bytes alone do not register them."),
    _row("PKG-WORKED-EXAMPLE-VALIDATION", "CMC-PACKAGING:5",
        "Emitted bag validates against the registered element-by-element profile and worked example."),
    _row("SEM-EXPANDED-PACKAGE", "MSM-EXPORT:1; CMC-OBJECT-DOSSIER:expanded-profile",
        "Expanded semantic manifest, entity index, Linked Art resources, assertion sidecars, provenance, authority snapshots, dependency documents, coverage and validation reports."),
    _row("SEM-SOURCE-STATE", "MSM-EXPORT:2",
        "One exact semantic source state with identity, block, finality, selected records and record heads."),
    _row("SEM-DISCLOSURE-SCOPE", "MSM-EXPORT:2",
        "Package-wide authorized source and disclosure scope, including withheld-resource accounting without restricted values."),
    _row("SEM-CANONICAL-HASHING", "MSM-EXPORT:4-8;12",
        "Registered JCS and typed integer/hash rules preserve original bytes and deterministic resource identities and ordering."),
    _row("SEM-OFFLINE-DEPENDENCY-CLOSURE", "MSM-EXPORT:4;8-9",
        "Pinned schemas, contexts, crosswalks, validators and authority bytes permit bounded offline interpretation with no network resolution."),
    _row("SEM-ACYCLIC-COMMITMENTS", "MSM-EXPORT:10",
        "Semantic children, manifest and dossier commitments are acyclic and exclude the later export record from source inputs."),
    _row("SEM-OPERATOR-INDEPENDENT-REGEN", "MSM-EXPORT:11",
        "Semantic package regeneration succeeds from preserved source, dependencies, build instructions and vectors without an operator service."),
    _row("SEM-INSTITUTIONAL-VALIDATION", "CMC-OBJECT-DOSSIER:expanded-profile; MSM-CONFORMANCE:4",
        "The two repository ingests and practitioner reviews include semantic outputs, coverage/loss reports and CRM/Linked Art authority competence."),
)


def _hash(value, label):
    if not isinstance(value, str) or not re.fullmatch(r"0x[0-9a-f]{64}", value):
        raise MuseumError(label + " must be a canonical 32-byte hash")
    if not any(hex_bytes(value, 32)):
        raise MuseumError(label + " must be nonzero")
    return value


def _validate_requirements():
    codes = set()
    for row in REQUIREMENTS:
        if (type(row) is not dict
                or set(row) != {"code", "home", "description", "applicability", "allowedAbsence"}
                or not all(isinstance(row[name], str) and row[name] for name in row)
                or not re.fullmatch(r"(?:identity|(?:OD|PKG|SEM)-[A-Z0-9-]+)", row["code"])
                or row["applicability"] not in ("all", "script")
                or row["allowedAbsence"] not in ("none", "work_class_non_script_only",
                    "work_class_non_script_or_authenticated_never_drilled_only",
                    "authenticated_absence_only", "verified_empty_lane_inventory_only",
                    "verified_empty_fetch_inventory_only")
                or (row["applicability"] == "script") != (row["allowedAbsence"] in (
                    "work_class_non_script_only",
                    "work_class_non_script_or_authenticated_never_drilled_only"))
                or row["code"] in codes):
            raise MuseumError("invalid or duplicate object-dossier requirement")
        codes.add(row["code"])
    return codes


_CODES = _validate_requirements()
REQUIREMENTS_BYTES = dumps({"name": NAME, "version": VERSION,
    "requirements": list(REQUIREMENTS), "qualification": QUALIFICATION})
REQUIREMENTS_HASH = keccak256(REQUIREMENTS_BYTES)


@dataclass(frozen=True)
class EvidenceRef:
    """A reference created by an internal adapter after evidence verification."""

    source: str
    content_hash: str
    selector: str


def _refs(value, code):
    if type(value) is not tuple or not value:
        raise MuseumError("verified evidence must be a nonempty tuple: " + code)
    result, unique = [], set()
    for ref in value:
        if type(ref) is not EvidenceRef:
            raise MuseumError("verified evidence reference type differs: " + code)
        try:
            selector_length = len(ref.selector.encode("utf-8")) if isinstance(ref.selector, str) else 0
        except UnicodeEncodeError:
            selector_length = 0
        source_ok = isinstance(ref.source, str) and (
            re.fullmatch(r"[A-Za-z][A-Za-z0-9+.-]*:[^\s]{1,2040}", ref.source) is not None
            or (len(ref.source) <= 2048
                and re.fullmatch(r"[A-Za-z0-9._-]+(?:/[A-Za-z0-9._-]+)*", ref.source) is not None
                and all(part not in (".", "..") for part in ref.source.split("/"))))
        if (not source_ok
                or not 0 < selector_length <= 4096):
            raise MuseumError("verified evidence reference fields differ: " + code)
        key = (ref.source, _hash(ref.content_hash, "verified evidence hash"), ref.selector)
        if key in unique:
            raise MuseumError("duplicate verified evidence reference: " + code)
        unique.add(key)
        result.append({"source": key[0], "contentHash": key[1], "selector": key[2]})
    return sorted(result, key=lambda row: (row["contentHash"], row["source"], row["selector"]))


def _supplied(value, code):
    if type(value) is not tuple or not value:
        raise MuseumError("supplied hashes must be a nonempty tuple: " + code)
    result = tuple(_hash(item, "supplied content hash") for item in value)
    if result != tuple(sorted(set(result))):
        raise MuseumError("supplied hashes must be sorted and unique: " + code)
    return list(result)


def _mapping(value, label):
    if not isinstance(value, Mapping):
        raise MuseumError(label + " must be a mapping")
    if any(type(code) is not str or code not in _CODES for code in value):
        raise MuseumError(label + " contains an unknown requirement code")
    return value


def assess(work_class, verified, supplied):
    """Return deterministic requirement coverage from typed internal evidence.

    ``supplied`` content is explicitly unverified and never contributes to
    completion.  An unknown work class leaves script-conditional applicability
    unresolved even when a related artifact happens to be present.
    """
    if type(work_class) is not str or work_class not in ("unknown", "script", "non_script"):
        raise MuseumError("work_class must be unknown, script or non_script")
    verified = _mapping(verified, "verified evidence")
    supplied = _mapping(supplied, "supplied evidence")
    if set(verified) & set(supplied):
        raise MuseumError("verified and supplied requirement keys overlap")
    verified_rows = {code: _refs(value, code) for code, value in verified.items()}
    supplied_rows = {code: _supplied(value, code) for code, value in supplied.items()}
    counts = {"total": len(REQUIREMENTS), "applicable": 0, "unresolvedApplicability": 0,
        "verified": 0, "suppliedUnverified": 0, "missing": 0, "notApplicable": 0}
    results, complete = [], True
    for requirement in REQUIREMENTS:
        code = requirement["code"]
        if requirement["applicability"] == "all":
            applicability = "applicable"; counts["applicable"] += 1
        elif work_class == "script":
            applicability = "applicable"; counts["applicable"] += 1
        elif work_class == "non_script":
            applicability = "not_applicable"
        else:
            applicability = "unresolved"; counts["unresolvedApplicability"] += 1; complete = False
        if applicability == "not_applicable":
            state = "not_applicable"
        elif code in verified_rows:
            state = "verified"
        elif code in supplied_rows:
            state = "supplied_unverified"
        else:
            state = "missing"
        counts[{"verified": "verified", "supplied_unverified": "suppliedUnverified",
            "missing": "missing", "not_applicable": "notApplicable"}[state]] += 1
        if applicability == "applicable" and state != "verified":
            complete = False
        results.append({"code": code, "home": requirement["home"],
            "description": requirement["description"],
            "applicability": applicability, "allowedAbsence": requirement["allowedAbsence"],
            "state": state, "evidenceRefs": verified_rows.get(code, []),
            "suppliedHashes": supplied_rows.get(code, [])})
    return {"name": ASSESSMENT_NAME, "version": VERSION, "requirementsHash": REQUIREMENTS_HASH,
        "workClass": work_class, "complete": complete, "conformanceClaimed": False,
        "releaseReadinessClaimed": False, "counts": counts, "results": results,
        "qualification": QUALIFICATION}


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    path = Path(__file__).resolve().parents[2] / "schemas/museum/object-dossier/requirements.json"
    if args.check:
        if not path.exists() or path.read_bytes() != REQUIREMENTS_BYTES:
            raise MuseumError("stale object-dossier requirements file")
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(REQUIREMENTS_BYTES)
    print(REQUIREMENTS_HASH)


if __name__ == "__main__":
    main()
