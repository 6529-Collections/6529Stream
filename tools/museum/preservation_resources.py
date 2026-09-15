"""Canonical preservation objects and explicitly linked historical rights statements."""
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
import re

from lxml import etree
from .canonical import MuseumError, dumps, keccak256, loads, schema_id, subject_id, uint
from .premis import NS, XSI, _element
from .recorded_fixity import _xml_text as _validate_xml_text
from .recorded_semantic import RecordedSemanticSource, JCS_ID
from .review import _validate
from .schemas import HEX32, IRI, TEXT, UINT, arr, enum, obj
from .metadata_rights_source import MetadataRightsSource, SCHEMA_BYTES as RIGHTS_SCHEMA, PROFILE_BYTES as RIGHTS_PROFILE

MODE = "recorded_account_preservation_resources_projection"
OBJECT_NAME = "STREAM_MUSEUM_PRESERVATION_OBJECT_V1"
RIGHT_NAME = "STREAM_MUSEUM_PRESERVATION_RIGHTS_LINK_V1"
ZERO = "0x" + "00" * 32
ROLES = ("SOURCE_CAPTURE", "SOURCE_MASTER", "EDIT_MASTER", "DISPLAY_DERIVATIVE", "PRINT_MASTER",
    "TOKEN_METADATA_JSON", "ONCHAIN_SCRIPT", "DEPENDENCY_SCRIPT", "IIIF_MANIFEST", "C2PA_MANIFEST", "ARCHIVE_PACKAGE", "ACCESSIBILITY_TRANSCRIPT")
ROLE_IDS = {schema_id(role): role for role in ROLES}
FAMILY = schema_id("INDEPENDENT_SEMANTIC_ASSERTION")
MAX_OBJECTS = 128
MAX_RIGHTS = 128
TIME = dict(UINT, maxLength=20, **{"x-stream-unsigned-bits": 64})


def documents():
    records = {OBJECT_NAME: obj({"version": enum("1"), "collectionId": UINT,
        "object": obj({"objectId": HEX32, "objectRole": HEX32, "uri": IRI, "contentHash": HEX32,
            "mimeType": dict(TEXT, maxLength=255), "byteSize": UINT, "formatId": HEX32, "schemaId": HEX32}),
        "hashAlgorithm": enum("SHA256", "KECCAK256"),
        "format": {"oneOf": [obj({"kind": enum("pronom"), "puid": dict(TEXT, maxLength=64)}), obj({"kind": enum("unavailable")})]},
        "significantProperties": arr(obj({"type": IRI, "value": TEXT}), 0, 32),
        "relationships": arr(obj({"type": enum("structural", "derivation"), "subtype": IRI, "objectId": HEX32}), 0, 32)}),
        RIGHT_NAME: obj({"version": enum("1"), "metadataRecordHash": HEX32,
            "rights": obj({"rightsId": HEX32, "rightsBasis": HEX32, "rightsURI": IRI, "rightsHash": HEX32,
                "validFrom": TIME, "validUntil": TIME}), "objectIds": arr(HEX32, 1, 128)})}
    return {name: dumps(schema | {"$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "urn:6529stream:schema:" + name, "x-stream-document-status": "prospective_schema_requires_actual_registration"})
        for name, schema in records.items()}


SCHEMAS = documents()
PROFILE_BYTES = dumps({"id": "STREAM_MUSEUM_PRESERVATION_RESOURCES_V1", "version": "1", "mode": MODE,
    "status": "prospective_unregistered_export_profile", "sourceSchemas": {k: keccak256(v) for k, v in SCHEMAS.items()},
    "rightsSchemaHash": keccak256(RIGHTS_SCHEMA), "rightsProfileHash": keccak256(RIGHTS_PROFILE),
    "objects": "Original media subject derivation: chain/Core/collection/original objectId. The subject identifier is distinct from original objectId and media URI.",
    "hashes": "Explicit SHA256 or KECCAK256 raw content commitments; no byte measurement or fixity-event inference.",
    "formats": "Nonzero PRONOM:<PUID> formatId with exact syntax and recorded MIME; no format detection. Other catalog mappings are explicitly unsupported in this version.",
    "roles": ROLE_IDS, "relationships": "Only recorded structural/derivation links to selected objects, never a guessed master/derivative link.",
    "rights": "Actual pinned Metadata class7/8 original RIGHTS_STATEMENT receipt plus exact STREAM_RIGHTS_V1 semantic schema/profile. Independent link publications cannot themselves grant rights.",
    "basis": {v: v for v in ("copyright", "license", "statute", "public_domain", "contract", "unspecified")},
    "statuses": {"granted": "granted", "granted_with_conditions": "granted_with_conditions", "denied": "denied", "unspecified": "unspecified"},
    "dates": "Original Gregorian grant dates remain date-only; separately explicit PreservationRightsRef Unix seconds render in correspondence and must agree with their dates. Null end remains explicit open end.",
    "selection": "Exact selected historical rows only, no current token-over-collection precedence or supersession inferred; both may be exported separately.",
    "claims": "No legal ownership, licensor identity, rights enforcement, document availability, complete current inventory, format detection or institutional acceptance.",
    "limits": {"objects": str(MAX_OBJECTS), "rights": str(MAX_RIGHTS), "propertiesPerObject": "32", "relationshipsPerObject": "32"}})
PROFILE_HASH = keccak256(PROFILE_BYTES)


@dataclass(frozen=True)
class ResourceProjection:
    xml: bytes | None
    report: bytes
    correspondence: bytes
    provenance: bytes


def need(condition, message):
    if not condition: raise MuseumError("preservation resources " + message)


def _text(value):
    _validate_xml_text(value)
    return value


def _read(source, selector, name):
    record = source.record(selector)
    need(selector["pointer"] == "" and record.disclosure == "public" and record.schema == SCHEMAS[name]
        and record.selector.schema_id == schema_id(name) and record.selector.record_type == FAMILY
        and source.canonicalizations[record.selector.record_hash] == JCS_ID, "exact public schema/family/JCS required")
    return record, _validate(record.schema, record.payload)


def admit_objects(source, selectors):
    rows, seen = [], set()
    for selector in selectors:
        record, value = _read(source, selector, OBJECT_NAME)
        ref = value["object"]
        need(uint(value["collectionId"]) > 0 and ref["objectId"] != ZERO and ref["contentHash"] != ZERO,
            "object identity/content commitment missing")
        sid = subject_id("media", source.anchor["chainId"], source.anchor["core"], value["collectionId"], object_id=ref["objectId"])
        need(sid == record.selector.subject_id and sid not in seen, "canonical object subject differs or repeats")
        seen.add(sid)
        need(re.fullmatch(r"[A-Za-z0-9!#$&^_.+\-]+/[A-Za-z0-9!#$&^_.+\-]+", ref["mimeType"]) is not None,
            "explicit MIME grammar")
        if value["format"]["kind"] == "pronom":
            puid = value["format"]["puid"]
            need(re.fullmatch(r"(?:x-)?fmt/[1-9][0-9]*", puid) is not None and ref["formatId"] == schema_id("PRONOM:" + puid),
                "PRONOM format identity differs")
        need(len({dumps(v) for v in value["significantProperties"]}) == len(value["significantProperties"]), "duplicate significant property")
        need(len({dumps(v) for v in value["relationships"]}) == len(value["relationships"]), "duplicate relationship")
        for link in value["relationships"]: need(link["objectId"] not in (ZERO, ref["objectId"]), "invalid self/zero relationship")
        rows.append({"selector": selector, "record": record, "value": value, "subject": sid})
    return rows


def admit_rights(source, selectors, rights_source, objects):
    rows, seen = [], set()
    by_id = {(r["value"]["collectionId"], r["value"]["object"]["objectId"]): r for r in objects}
    for selector in selectors:
        record, link = _read(source, selector, RIGHT_NAME)
        ref = link["rights"]
        need(rights_source is not None and link["metadataRecordHash"] in rights_source.records, "selected Metadata RIGHTS receipt missing")
        saved = rights_source.records[link["metadataRecordHash"]]
        statement = saved["value"]
        need(record.selector.subject_id == statement["subjectId"] and ref["rightsId"] != ZERO and ref["rightsId"] not in seen,
            "rights subject/identity differs or repeats")
        seen.add(ref["rightsId"])
        need(ref["rightsHash"] == keccak256(bytes.fromhex(saved["payloadHex"][2:]))
            and ref["rightsURI"] == saved["record"][3] and ref["rightsBasis"] == schema_id(statement["basis"]),
            "rights reference/basis differs from actual statement")
        need(len(set(link["objectIds"])) == len(link["objectIds"]) and ZERO not in link["objectIds"], "duplicate/zero rights object")
        targets = []
        for object_id in link["objectIds"]:
            key = (saved["selection"]["collectionId"], object_id)
            need(key in by_id, "rights linked object not selected in original collection")
            targets.append(by_id[key]["subject"])
        start, end = uint(ref["validFrom"], 64), uint(ref["validUntil"], 64)
        need(end == 0 or end >= start, "rights reference time order")
        # Date-only rights do not supply a clock time. The independent link must
        # explicitly supply its own seconds and cannot contradict the source date.
        dates = statement["effectiveDates"]
        if 0 < start <= 253402300799:
            need(_instant(start)[:10] == dates["start"], "rights reference start date differs")
        if 0 < end <= 253402300799:
            need(dates["end"] is not None and _instant(end)[:10] == dates["end"], "rights reference end date differs")
        need((end == 0) == (dates["end"] is None), "rights open end differs")
        rows.append({"selector": selector, "record": record, "link": link, "saved": saved, "targets": targets})
    return rows


def _instant(seconds):
    return (datetime(1970, 1, 1, tzinfo=timezone.utc) + timedelta(seconds=seconds)).isoformat().replace("+00:00", "Z")


def _id(parent, element, kind, value):
    node = _element(parent, element)
    _element(node, element + "Type", kind); _element(node, element + "Value", value)
    return node


def render(objects, rights_rows, schema):
    issues, maps, provenance = [], [], []
    root = etree.Element("{" + NS + "}premis", nsmap={"premis": NS, "xsi": XSI}, version="3.0")
    lookup = {(r["value"]["collectionId"], r["value"]["object"]["objectId"]): r["subject"] for r in objects}
    if not objects: issues.append({"reasonCode": "no_selected_preservation_objects"})
    for row in sorted(objects, key=lambda r: r["subject"]):
        value, sid = row["value"], row["subject"]; ref = value["object"]
        provenance.append({"kind": "object", "source": row["selector"], "typedObject": value,
            "authority": loads(row["record"].authority_evidence)})
        reasons = []
        if ref["objectRole"] not in ROLE_IDS: reasons.append("unsupported_object_role")
        if value["format"]["kind"] != "pronom": reasons.append("registered_format_mapping_unavailable")
        if uint(ref["byteSize"]) > (1 << 63) - 1: reasons.append("premis_size_outside_xs_long")
        for relation in value["relationships"]:
            if (value["collectionId"], relation["objectId"]) not in lookup: reasons.append("related_object_not_selected")
        if reasons:
            issues += [{"objectSubject": sid, "reasonCode": reason} for reason in reasons]; continue
        node = _element(root, "object", **{"{" + XSI + "}type": "premis:file"})
        _id(node, "objectIdentifier", "6529STREAM_SUBJECT", sid)
        role = _element(node, "significantProperties")
        _element(role, "significantPropertiesType", "6529STREAM_OBJECT_ROLE")
        _element(role, "significantPropertiesValue", ROLE_IDS[ref["objectRole"]])
        for prop in value["significantProperties"]:
            p = _element(node, "significantProperties"); _element(p, "significantPropertiesType", _text(prop["type"]))
            _element(p, "significantPropertiesValue", _text(prop["value"]))
        ch = _element(node, "objectCharacteristics"); fixity = _element(ch, "fixity")
        _element(fixity, "messageDigestAlgorithm", "SHA-256" if value["hashAlgorithm"] == "SHA256" else "Keccak-256")
        _element(fixity, "messageDigest", ref["contentHash"][2:]); _element(ch, "size", ref["byteSize"])
        fmt = _element(ch, "format"); designation = _element(fmt, "formatDesignation")
        _element(designation, "formatName", ref["mimeType"])
        registry = _element(fmt, "formatRegistry"); _element(registry, "formatRegistryName", "PRONOM")
        _element(registry, "formatRegistryKey", value["format"]["puid"])
        _element(fmt, "formatNote", "Recorded format assertion; format detection and media availability are not proven.")
        storage = _element(node, "storage"); _id(storage, "contentLocation", "URI", _text(ref["uri"]))
        for relation in value["relationships"]:
            rel = _element(node, "relationship"); _element(rel, "relationshipType", relation["type"])
            _element(rel, "relationshipSubType", _text(relation["subtype"]))
            _id(rel, "relatedObjectIdentifier", "6529STREAM_SUBJECT", lookup[(value["collectionId"], relation["objectId"])])
        maps.append({"kind": "object", "source": row["selector"], "objectId": ref["objectId"], "subjectId": sid,
            "schemaId": ref["schemaId"], "objectRole": ref["objectRole"], "hashAlgorithm": value["hashAlgorithm"],
            "formatId": ref["formatId"], "uri": ref["uri"], "target": "objectIdentifier[type=6529STREAM_SUBJECT]"})
    agents, right_nodes = {}, []
    for row in sorted(rights_rows, key=lambda r: r["link"]["rights"]["rightsId"]):
        ref, saved = row["link"]["rights"], row["saved"]; statement = saved["value"]
        provenance.append({"kind": "rights", "source": row["selector"], "independentLink": row["link"],
            "linkAuthority": loads(row["record"].authority_evidence), "metadataReceipt": saved})
        if not 0 < uint(ref["validFrom"], 64) <= 253402300799 or uint(ref["validUntil"], 64) > 253402300799:
            issues.append({"rightsId": ref["rightsId"], "reasonCode": "rights_reference_timestamp_unavailable"}); continue
        iri = "urn:6529stream:preservation:rights:" + ref["rightsId"]
        identity = statement["licensor"]["identity"]
        holder = "urn:6529stream:reported-licensor:" + keccak256(dumps({
            "recordHash": saved["recordHash"], "identity": identity}))
        agents[holder] = identity
        node = etree.Element("{" + NS + "}rightsStatement")
        _id(node, "rightsStatementIdentifier", "URI", iri)
        _element(node, "rightsBasis", statement["basis"])
        license_info = _element(node, "licenseInformation")
        _id(license_info, "licenseDocumentationIdentifier", "URI", _text(ref["rightsURI"]))
        _id(license_info, "licenseDocumentationIdentifier", "Keccak-256 recorded rights payload", ref["rightsHash"])
        if statement["instrument"] is not None:
            instrument = statement["instrument"]
            _id(license_info, "licenseDocumentationIdentifier", "URI", _text(instrument["uri"]))
            _id(license_info, "licenseDocumentationIdentifier", "Keccak-256 RAW_BYTES", instrument["hash"]["digest"])
        _element(license_info, "licenseNote", dumps({"originalBasis": statement["basis"], "licensor": statement["licensor"],
            "rightsRef": ref, "predecessor": statement["predecessor"], "qualification": "Recorded notice/evidence; legal authority and current selection not established."}).decode())
        dates = _element(license_info, "licenseApplicableDates"); _element(dates, "startDate", statement["effectiveDates"]["start"])
        if statement["effectiveDates"]["end"] is not None: _element(dates, "endDate", statement["effectiveDates"]["end"])
        for use, grant in statement["grants"].items():
            g = _element(node, "rightsGranted"); _element(g, "act", use)
            _element(g, "restriction", grant["status"])
            if grant["conditions"] is not None: _element(g, "restriction", dumps(grant["conditions"]).decode())
            term = _element(g, "termOfGrant"); _element(term, "startDate", statement["effectiveDates"]["start"])
            if statement["effectiveDates"]["end"] is not None: _element(term, "endDate", statement["effectiveDates"]["end"])
            _element(g, "rightsGrantedNote", dumps({"originalStatus": grant["status"], "extension": grant["extension"],
                "qualification": "Explicit reported status; denied and unspecified are not grants."}).decode())
        for target in row["targets"]: _id(node, "linkingObjectIdentifier", "6529STREAM_SUBJECT", target)
        link = _id(node, "linkingAgentIdentifier", "URI", holder); _element(link, "linkingAgentRole", "rightsHolder")
        right_nodes.append(node)
        maps.append({"kind": "rights", "source": row["selector"], "metadataRecordHash": saved["recordHash"],
            "rightsId": ref["rightsId"], "rightsStatementIdentifier": iri, "scope": saved["selection"],
            "rightsHolder": holder, "validFrom": ref["validFrom"], "validUntil": ref["validUntil"],
            "effectiveDates": statement["effectiveDates"], "objects": row["targets"], "grants": statement["grants"]})
    if issues: return None, issues, maps, provenance
    for holder, identity in sorted(agents.items()):
        a = _element(root, "agent"); _id(a, "agentIdentifier", "URI", holder)
        if identity["kind"] == "artist": _id(a, "agentIdentifier", "6529STREAM_ARTIST", identity["artistId"])
        elif identity["kind"] == "address": _id(a, "agentIdentifier", "Ethereum address", identity["address"])
        else: _element(a, "agentName", _text(identity["name"]))
        _element(a, "agentNote", dumps({"originalIdentity": identity, "qualification": "Named licensor assertion; no legal identity or ownership proof."}).decode())
    if right_nodes:
        rights_node = _element(root, "rights")
        for node in right_nodes: rights_node.append(node)
    xml = etree.tostring(root, encoding="UTF-8", xml_declaration=True); schema.validate(xml)
    return xml, [], maps, provenance


def project_resources(source, plan_bytes, *, plan_hash, profile_hash, rights_source, rights_source_hash, premis_schema):
    need(type(source) is RecordedSemanticSource and source.state.mode == "recorded_state", "verified recorded source required")
    need(all(r.disclosure == "public" for r in source.state.records), "restricted source unsupported")
    need(keccak256(plan_bytes) == plan_hash and profile_hash == PROFILE_HASH, "external plan/profile differs")
    plan = loads(plan_bytes, maximum=524288, canonical=True)
    need(isinstance(plan, dict) and set(plan) == {"mode", "version", "sourceStateHash", "accountProfileHash", "resourceProfileHash", "rightsSourceHash", "objects", "rights"}
        and plan["mode"] == MODE and plan["version"] == "1" and plan["sourceStateHash"] == source.state.commitment
        and plan["accountProfileHash"] == source.profile_hash and plan["resourceProfileHash"] == PROFILE_HASH
        and plan["rightsSourceHash"] == rights_source_hash, "plan scope differs")
    for key, maximum in (("objects", MAX_OBJECTS), ("rights", MAX_RIGHTS)):
        need(isinstance(plan[key], list) and len(plan[key]) <= maximum and len({dumps(v) for v in plan[key]}) == len(plan[key]), "selection count/duplicates")
    if rights_source is not None:
        need(type(rights_source) is MetadataRightsSource and rights_source.provenance == "trusted_rpc"
            and keccak256(rights_source.snapshot()) == rights_source_hash, "actual Metadata rights source required")
        need(all(rights_source.a[k] == source.anchor[k] for k in ("chainId", "blockHash", "core")), "independent/Metadata source anchor differs")
    else: need(rights_source_hash is None and not plan["rights"], "missing Metadata rights source")
    objects = admit_objects(source, plan["objects"])
    rows = admit_rights(source, plan["rights"], rights_source, objects)
    xml, issues, maps, provenance = render(objects, rows, premis_schema)
    report = dumps({"mode": MODE, "version": "1", "status": "supported" if xml else "unsupported", "issues": issues,
        "sourceStateHash": source.state.commitment, "planHash": plan_hash, "resourceProfileHash": PROFILE_HASH,
        "rightsSourceHash": rights_source_hash, "xmlHash": None if xml is None else keccak256(xml),
        "objectCount": str(len(objects)), "rightsCount": str(len(rows)),
        "claims": {"canonicalSubjectDerivationChecked": True, "selectedHistoricalRightsReceiptsChecked": rights_source is not None,
            "independentLinksAreRightsGrants": False, "currentRightsSelection": False, "bytesFixityVerified": False,
            "legalOwnershipProven": False, "formatIdentified": False, "fullPremisCrosswalk": False, "institutionalAcceptance": False}})
    return ResourceProjection(xml, report, dumps(maps), dumps(provenance))