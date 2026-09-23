"""Generate the broad prospective STREAM_PREMIS_V3_PROFILE definition.

The profile is a closed crosswalk definition.  It does not perform an XML
export, prove a repository ingest, authenticate source records, or replace the
narrow recorded-file/fixity projections.
"""

import argparse
import hashlib
from pathlib import Path

import jsonschema

from tools.metadata import rights_profile
from tools.museum.canonical import MuseumError, dumps, keccak256, loads, schema_id


ROOT = Path(__file__).resolve().parents[2]
NAME = "STREAM_PREMIS_V3_PROFILE"
XSD_SHA256 = "03b8a77a20b32b882ad799e12262671d07ad18210c60233f4e613a1289491cba"
XSD_BYTES = 52845
XSD_URI = "https://www.loc.gov/standards/premis/premis.xsd"
DATA_DICTIONARY_URI = "https://www.loc.gov/standards/premis/v3/premis-3-0-datadictionary-only.pdf"
EVENT_AUTHORITY = "http://id.loc.gov/vocabulary/preservation/eventType"
AGENT_TYPE_AUTHORITY = "http://id.loc.gov/vocabulary/preservation/agentType"
AGENT_ROLE_AUTHORITY = "http://id.loc.gov/vocabulary/preservation/eventRelatedAgentRole"
RIGHTS_BASIS_AUTHORITY = "http://id.loc.gov/vocabulary/preservation/rightsBasis"
JCS = schema_id("RFC8785_JCS")

OBJECT_ROLES = (
    "SOURCE_CAPTURE", "SOURCE_MASTER", "EDIT_MASTER", "DISPLAY_DERIVATIVE", "PRINT_MASTER",
    "TOKEN_METADATA_JSON", "ONCHAIN_SCRIPT", "DEPENDENCY_SCRIPT", "IIIF_MANIFEST", "C2PA_MANIFEST",
    "ARCHIVE_PACKAGE", "ACCESSIBILITY_TRANSCRIPT",
)
EVENT_TYPES = {
    "INGEST": "ingestion", "FIXITY_CHECK": "fixity check", "REPLICATION": "replication",
    "MIGRATION": "migration", "NORMALIZATION": "normalization", "VALIDATION": "validation",
    "MEDIA_DERIVATION": "creation", "C2PA_VALIDATION": "digital signature validation",
    "SCHEMA_MIGRATION": "metadata modification", "RIGHTS_REVIEW": "policy assignment",
    "CONSERVATION_NOTE": "conservation note", "REDACTION": "redaction",
    "DEACCESSION_REFERENCE": "deaccession",
}
# Only codes confirmed from the retained primary-source review are emitted as
# controlled-vocabulary value URIs.  The profile still commits every CMC label,
# while leaving the other authority-term URI joins explicitly unresolved.
EVENT_CODES = {"INGEST": "ing", "MIGRATION": "mig", "VALIDATION": "val"}
OUTCOMES = {"SUCCESS": "success", "WARNING": "warning", "FAILED": "fail",
    "INCONCLUSIVE": "inconclusive", "SUPERSEDED": "superseded", "REDACTED": "redacted"}
LOCAL_EVENT_TYPES = {"CONSERVATION_NOTE"}
LOCAL_OUTCOMES = {"INCONCLUSIVE", "SUPERSEDED", "REDACTED"}
USES = tuple(rights_profile.USES)
STATUSES = tuple(rights_profile.STATUS)
RIGHTS_SCHEMA_BYTES = dumps(rights_profile.schema())


def _field(source, target, transform, *, cardinality="1", required=True):
    return {"sourceField": source, "targetPath": target, "transform": transform,
            "cardinality": cardinality, "required": required}


STRUCTURES = {
    "CollectionRecord": (
        _field("recordType", "object/significantProperties[STREAM_RECORD_TYPE]", "lowercase bytes32 identifier retained verbatim"),
        _field("subjectId", "object/objectIdentifier[type=6529STREAM_SUBJECT]", "lowercase bytes32 becomes identifier value"),
        _field("contentHash.algorithm", "object/objectCharacteristics/fixity/messageDigestAlgorithm", "registered HashRef algorithm identifier"),
        _field("contentHash.digest", "object/objectCharacteristics/fixity/messageDigest", "algorithm-sized digest retained exactly"),
        _field("contentHash.canonicalizationId", "object/significantProperties[STREAM_CANONICALIZATION_ID]", "lowercase bytes32 serialization identifier"),
        _field("uri", "object/storage/contentLocation[type=URI]", "exact content URI"),
        _field("schemaId", "object/significantProperties[STREAM_SCHEMA_ID]", "lowercase bytes32 schema identifier"),
        _field("signatureScheme", "object/significantProperties[STREAM_SIGNATURE_SCHEME]", "lowercase bytes32 commitment scheme identifier; never emitted as a PREMIS signature method"),
        _field("signatureHash.algorithm", "object/significantProperties[STREAM_SIGNATURE_HASH_ALGORITHM]", "registered HashRef algorithm identifier"),
        _field("signatureHash.digest", "object/significantProperties[STREAM_SIGNATURE_HASH_DIGEST]", "algorithm-sized commitment digest retained exactly; never emitted as signature bytes"),
        _field("signatureHash.canonicalizationId", "object/significantProperties[STREAM_SIGNATURE_CANONICALIZATION_ID]", "lowercase bytes32 serialization identifier"),
        _field("effectiveAt", "object/significantProperties[STREAM_EFFECTIVE_AT]", "uint64 Unix seconds retained; typed event adapters also emit eventDateTime"),
    ),
    "PreservationObjectRef": (
        _field("objectId", "object/objectIdentifier[type=6529STREAM_SUBJECT]", "canonical media subject is derived with this objectId"),
        _field("objectRole", "object/significantProperties[STREAM_OBJECT_ROLE]", "closed role label plus role-specific structural relationship"),
        _field("uri", "object/storage/contentLocation[type=URI]", "exact storage/content location URI"),
        _field("contentHash", "object/objectCharacteristics/fixity/messageDigest", "algorithm supplied by enclosing typed profile; digest retained exactly"),
        _field("mimeType", "object/objectCharacteristics/format/formatDesignation/formatName", "exact recorded MIME assertion"),
        _field("byteSize", "object/objectCharacteristics/size", "uint256 must fit PREMIS XML xs:long or export is unsupported"),
        _field("formatId", "object/significantProperties[STREAM_FORMAT_ID]", "original nonzero bytes32 retained; authenticated format resolution separately emits a PREMIS registry key or specification"),
        _field("schemaId", "object/significantProperties[STREAM_SCHEMA_ID]", "lowercase bytes32 payload-schema identifier"),
    ),
    "PreservationEventRef": (
        _field("eventId", "event/eventIdentifier[type=6529STREAM_EVENT]", "lowercase bytes32 becomes identifier value"),
        _field("eventType", "event/eventType", "closed Stream event vocabulary maps through eventTypes"),
        _field("outcome", "event/eventOutcomeInformation/eventOutcome", "closed Stream outcome maps through outcomes"),
        _field("eventURI", "event/eventDetailInformation/eventDetail", "exact evidence URI retained in structured correspondence"),
        _field("eventHash", "event/eventOutcomeInformation/eventOutcomeDetail/eventOutcomeDetailNote", "evidence hash retained with algorithm qualification from typed profile"),
        _field("eventTime", "event/eventDateTime", "uint64 Unix seconds rendered as UTC instant when in XML range"),
        _field("schemaId", "event/eventDetailInformation/eventDetail", "lowercase bytes32 event-schema identifier retained in structured correspondence"),
    ),
    "PreservationAgentRef": (
        _field("agentId", "agent/agentIdentifier[type=6529STREAM_AGENT]", "lowercase bytes32 becomes identifier value"),
        _field("agentRole", "event/linkingAgentIdentifier/linkingAgentRole", "closed typed-source role; vocabulary-qualified when mapped"),
        _field("account", "agent/agentIdentifier[type=Ethereum address]", "nonzero address only; no person or institution inference", required=False),
        _field("did", "agent/agentIdentifier[type=DID]", "exact DID URI; no DID resolution", required=False),
        _field("uri", "agent/agentIdentifier[type=URI]", "exact agent or service URI; no identity resolution", required=False),
        _field("agentHash", "agent/agentNote", "exact named-agent document hash retained in structured correspondence"),
    ),
    "PreservationRightsRef": (
        _field("rightsId", "rights/rightsStatement/rightsStatementIdentifier[type=6529STREAM_RIGHTS]", "lowercase bytes32 becomes identifier value"),
        _field("rightsBasis", "rights/rightsStatement/rightsBasis", "closed STREAM_RIGHTS_V1 basis maps through rights.bases"),
        _field("rightsURI", "rights/rightsStatement/licenseInformation/licenseDocumentationIdentifier[type=URI]", "exact rights evidence URI"),
        _field("rightsHash", "rights/rightsStatement/licenseInformation/licenseDocumentationIdentifier[type=content hash]", "exact rights evidence hash"),
        _field("validFrom", "rights/rightsStatement/licenseInformation/licenseApplicableDates/startDate", "uint64 seconds must agree with source date-only statement when both exist"),
        _field("validUntil", "rights/rightsStatement/licenseInformation/licenseApplicableDates/endDate", "zero means explicit open end; otherwise ordered uint64 seconds"),
    ),
    "FixityCheckRef": (
        _field("objectId", "event/linkingObjectIdentifier[type=6529STREAM_SUBJECT]", "must join an exported PreservationObjectRef"),
        _field("algorithm", "object/objectCharacteristics/fixity/messageDigestAlgorithm", "closed registered hash-algorithm identifier"),
        _field("digest", "object/objectCharacteristics/fixity/messageDigest", "exact digest with algorithm-specific length"),
        _field("byteSize", "object/objectCharacteristics/size", "must equal the linked object's recorded byte size"),
        _field("checkedAt", "event/eventDateTime", "uint64 Unix seconds rendered as UTC instant"),
        _field("outcome", "event/eventOutcomeInformation/eventOutcome", "closed Stream outcome mapping"),
        _field("agentId", "event/linkingAgentIdentifier[type=6529STREAM_AGENT]", "must join an exported PreservationAgentRef"),
        _field("reportURI", "event/eventOutcomeInformation/eventOutcomeDetail/eventOutcomeDetailNote", "exact report URI retained in structured correspondence"),
        _field("reportHash", "event/eventOutcomeInformation/eventOutcomeDetail/eventOutcomeDetailNote", "exact report hash retained with URI"),
    ),
}


def _event_rows():
    rows = []
    for source, target in EVENT_TYPES.items():
        local = source in LOCAL_EVENT_TYPES
        code = EVENT_CODES.get(source)
        rows.append({"source": source, "target": target,
            "authority": "STREAM_PREMIS_V3_PROFILE" if local else EVENT_AUTHORITY,
            "valueUri": None if code is None else EVENT_AUTHORITY + "/" + code,
            "profileLocal": local,
            "termResolution": "profile_local" if local else
                ("official_code_verified" if code is not None else "unresolved_authority_term_uri"),
            "skosCloseMatch": None})
    return rows


def _outcome_rows():
    close = {"INCONCLUSIVE": "warning", "SUPERSEDED": "success", "REDACTED": "success"}
    rows = []
    for source, target in OUTCOMES.items():
        local = source in LOCAL_OUTCOMES
        rows.append({"source": source, "target": target, "authority": "STREAM_PREMIS_V3_PROFILE",
            "profileLocal": local, "detailRequired": local,
            "skosCloseMatch": None if not local else "urn:6529stream:premis:outcome:" + close[source]})
    return rows


def profile():
    rights_hash = keccak256(RIGHTS_SCHEMA_BYTES)
    return {
        "version": 1, "profileId": NAME, "status": "prospective_unregistered",
        "target": {"namespace": "http://www.loc.gov/premis/v3", "version": "3.0",
            "xsd": {"uri": XSD_URI, "sha256": "0x" + XSD_SHA256, "byteLength": str(XSD_BYTES)},
            "dataDictionary": DATA_DICTIONARY_URI,
            "vocabularyRetention": "No LoC vocabulary snapshot is retained in this repository; exact CMC labels are pinned here and authority URIs are references, not authenticated current vocabulary bytes."},
        "structureMappings": [{"structure": name, "fields": list(fields)} for name, fields in STRUCTURES.items()],
        "objectRoles": [{"source": role, "significantPropertyType": "6529STREAM_OBJECT_ROLE",
            "relationshipType": "derivation" if role in ("EDIT_MASTER", "DISPLAY_DERIVATIVE", "PRINT_MASTER") else "structural",
            "relationshipSubType": "urn:6529stream:premis:object-role:" + role.lower()}
            for role in OBJECT_ROLES],
        "eventTypes": _event_rows(), "outcomes": _outcome_rows(),
        "agent": {"identifierTypes": ["6529STREAM_AGENT", "Ethereum address", "DID", "URI"],
            "classes": [{"source": value, "target": value, "authority": AGENT_TYPE_AUTHORITY}
                for value in ("person", "organization", "software", "preservation service")],
            "roleAuthority": AGENT_ROLE_AUTHORITY,
            "qualification": "Identifiers and class are source claims; account, DID and URI do not establish a common legal or human identity."},
        "format": {"originalFormatIdTarget": "object/significantProperties[STREAM_FORMAT_ID]",
            "pronom": {"authenticatedPreimage": "PRONOM:<PUID>", "identifierRule": "formatId equals keccak256 UTF8 of the exact preimage",
                "targetRegistryName": "PRONOM", "targetRegistryKey": "the exact <PUID>, never its hash"},
            "streamCatalog": {"identifierRule": "formatId selects an exact registered Stream format-catalog entry",
                "pronomBranch": "entry PUID emits registryName PRONOM and the exact PUID key",
                "specificationBranch": "entry full format-specification URI+hash is retained in formatNote/correspondence without claiming PRONOM"},
            "unresolvedRule": "zero, free-form, missing-preimage or missing-catalog formatId is unsupported for render-critical or preservation-critical export"},
        "fixityAlgorithms": [{"source": source, "target": target, "profileLocal": local} for source, target, local in (
            ("SHA256", "SHA-256", False), ("SHA512", "SHA-512", False),
            ("KECCAK256", "Keccak-256", True), ("BLAKE3", "BLAKE3", True),
            ("IPFS_CID_V1", "IPFS CIDv1", True), ("ARWEAVE_TX_ID", "Arweave transaction ID", True))],
        "significantProperties": [{"source": value, "target": "object/significantProperties",
            "profileTerm": "urn:6529stream:premis:significant-property:" + value}
            for value in ("behavior", "color_profile", "dimensions", "timing", "interaction", "dependency_versions", "execution_environment")],
        "rights": {"sourceSchema": "STREAM_RIGHTS_V1", "sourceSchemaHash": rights_hash,
            "basisAuthority": RIGHTS_BASIS_AUTHORITY,
            "bases": [{"source": value, "target": value} for value in
                ("copyright", "license", "statute", "public_domain", "contract", "unspecified")],
            "uses": [{"source": use, "targetAct": use,
                "statusTarget": "rights/rightsStatement/rightsGranted/restriction",
                "conditionsTarget": "rights/rightsStatement/rightsGranted/restriction",
                "extensionTarget": "rights/rightsStatement/rightsGranted/rightsGrantedNote"} for use in USES],
            "statuses": [{"source": status, "target": status,
                "isGrant": status in ("granted", "granted_with_conditions")} for status in STATUSES],
            "licensorTarget": "rights/rightsStatement/linkingAgentIdentifier[role=rightsHolder]",
            "datesTarget": "rights/rightsStatement/rightsGranted/termOfGrant",
            "instrumentTarget": "rights/rightsStatement/licenseInformation/licenseDocumentationIdentifier",
            "qualification": "Rights statements are notice/evidence; denied and unspecified are not grants, and no legal authority or enforcement is inferred."},
        "roundTripGate": {"required": True,
            "exports": ["Stream preservation shapes to PREMIS v3", "STREAM_RIGHTS_V1 to PREMIS v3 rights", "STREAM_WORK_DESCRIPTION_V1 to LIDO"],
            "thisDefinitionImplementsExporter": False, "thisDefinitionProvesRepositoryIngest": False,
            "institutionalConformance": False},
        "canonicalization": {"name": "RFC8785_JCS", "canonicalizationId": JCS,
            "note": "Definition bytes are canonical JSON and use the registered RFC8785 canonicalization identifier."},
    }


def schema():
    # The registered schema document itself commits the complete crosswalk.
    # The const also makes the definition closed at every nested level.
    value = profile()
    return {"$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "urn:6529stream:schema:" + NAME, "title": NAME,
        "type": "object", "const": value,
        "x-stream-document-status": "prospective_unregistered"}


SCHEMA_BYTES = dumps(schema())
PROFILE = profile()
EXAMPLE_BYTES = dumps(PROFILE)
PROFILE_HASH = keccak256(EXAMPLE_BYTES)


def _local_xsd():
    directory = ROOT / "schemas/museum/premis/chunks" / XSD_SHA256
    paths = sorted(directory.glob("*.bin"))
    if [path.name for path in paths] != [f"{i:06d}.bin" for i in range(7)]:
        raise MuseumError("PREMIS pinned XSD chunks missing")
    raw = b"".join(path.read_bytes() for path in paths)
    if len(raw) != XSD_BYTES or hashlib.sha256(raw).hexdigest() != XSD_SHA256:
        raise MuseumError("PREMIS pinned XSD differs")
    return raw


def validate(raw):
    if type(raw) is not bytes or not 0 < len(raw) <= 524288:
        raise MuseumError("PREMIS profile document bound")
    value = loads(raw, maximum=524288, canonical=True)
    try:
        jsonschema.Draft202012Validator(schema()).validate(value)
    except jsonschema.ValidationError as exc:
        raise MuseumError("PREMIS profile schema differs") from exc
    if dumps(value) != raw:
        raise MuseumError("PREMIS profile must be exact canonical JSON")
    if value != PROFILE:
        raise MuseumError("PREMIS profile field/unit crosswalk differs")
    _local_xsd()
    return value


def documents():
    return {NAME: SCHEMA_BYTES}


def example():
    return PROFILE


def outputs():
    validate(EXAMPLE_BYTES)
    return {"schemas/records/STREAM_PREMIS_V3_PROFILE.json": SCHEMA_BYTES,
        "schemas/records/examples/genesis-premis/premis-v3-profile.json": EXAMPLE_BYTES}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    for relative, raw in outputs().items():
        path = ROOT / relative
        if args.check:
            if not path.is_file() or path.read_bytes() != raw:
                raise SystemExit("genesis PREMIS definition differs: " + relative)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
    print("genesis PREMIS definition exact")


if __name__ == "__main__":
    main()
