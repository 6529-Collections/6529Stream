"""Bounded PREMIS file/fixity projection from the existing fixture authority lane.

This consumes declared preservation facts, not media bytes or chain records.
It neither performs a fixity check nor invents an event, rights or agent role.
"""

from dataclasses import dataclass
from hashlib import sha256
from pathlib import Path
import re

from lxml import etree

from .canonical import MuseumError, dumps, keccak256, loads, uint
from .dependencies import OfflineDocuments
from .projection import Projection, project_fixture
from .projection_v2 import ProjectionProfileV2
from .semantic_selection import select_canonical_fixture

NS = "http://www.loc.gov/premis/v3"
XSI = "http://www.w3.org/2001/XMLSchema-instance"
XML_SCHEMA_NS = "http://www.w3.org/2001/XMLSchema"
DATATYPE_NS = "http://www.w3.org/2001/XMLSchema#"
SCHEMA_URI = "https://www.loc.gov/standards/premis/premis.xsd"
SCHEMA_SHA256 = "03b8a77a20b32b882ad799e12262671d07ad18210c60233f4e613a1289491cba"
PREFIX = "urn:6529stream:museum:premis-file:v1:"
FIELDS = {"category": PREFIX + "category", "size": PREFIX + "byte-size",
          "digest": PREFIX + "sha256", "puid": PREFIX + "pronom-puid"}
STRING = DATATYPE_NS + "string"
MAX_XML = 4 * 1024 * 1024


def profile_document():
    return {"mode": "candidate_unregistered", "id": "STREAM_MUSEUM_PREMIS_FILE_FIXITY_V1",
        "version": "1", "sourceFamily": "STREAM_SEMANTIC_ASSERTION_V1",
        "sourceAuthority": "existing exact fixture selection, issuer and review policy",
        "sourceScope": "explicit selected supplemental digital objects; no canonical PreservationObjectRef adapter",
        "targetSchemaUri": SCHEMA_URI, "targetSchemaSha256": "0x" + SCHEMA_SHA256,
        "rules": [
            {"field": "identity", "source": "selected entity declaration id", "target": "objectIdentifier",
             "transform": "URI identifier, identical to Linked Art DigitalObject id; anchor subject stays a separate correspondence"},
            {"field": "category", "source": FIELDS["category"], "target": "object/@xsi:type",
             "sourceDatatype": STRING,
             "transform": "exact unqualified xsd:string file; D1 alone is insufficient"},
            {"field": "size", "source": FIELDS["size"], "target": "objectCharacteristics/size",
             "sourceDatatype": DATATYPE_NS + "nonNegativeInteger",
             "transform": "canonical unqualified xsd:nonNegativeInteger lexical decimal; validate uint256, reject above xs:long maximum without truncating"},
            {"field": "digest", "source": FIELDS["digest"], "target": "objectCharacteristics/fixity/messageDigest",
             "sourceDatatype": STRING,
             "transform": "exact unqualified xsd:string lowercase 64 hex SHA-256 assertion; no byte verification or event inference"},
            {"field": "puid", "source": FIELDS["puid"], "target": "objectCharacteristics/format/formatRegistry",
             "sourceDatatype": STRING,
             "transform": "exact unqualified xsd:string fmt/N or x-fmt/N PRONOM assertion; syntax only, no format detection or catalog resolution"}],
        "limits": {"objects": "512", "xmlBytes": str(MAX_XML), "xmlElements": "32768", "xmlDepth": "64"},
        "sourceCoverage": "entire selected source records, same schema inventory as Linked Art; all public originals retained",
        "xmlPolicy": "UTF-8 XML 1.0, no DTD/entities/PI/comments/external resolution, exact pinned standalone XSD",
        "consistency": "recompute both projections from same source and policy; exact generated XML/correspondence/report bytes",
        "remaining": ["canonical preservation source adapter", "events", "agents", "rights", "complete format catalog",
                      "LIDO", "IIIF", "institutional ingest", "authenticated chain state", "full Museum gates"]}


PROFILE_BYTES = dumps(profile_document())
PROFILE_HASH = keccak256(PROFILE_BYTES)


class _DenyResolver(etree.Resolver):
    def resolve(self, url, public_id, context):
        raise MuseumError("XML external resolution forbidden")


def _xml(raw):
    if type(raw) is not bytes or not raw or len(raw) > MAX_XML:
        raise MuseumError("XML byte limit")
    # Decode first: XML 1.0 Unicode and attribute/text values are never trimmed
    # or normalized by application code. Disallow XML's external/DTD surface.
    try:
        text = raw.decode("utf-8")
        if "<!DOCTYPE" in text or "<!ENTITY" in text:
            raise MuseumError("XML DTD/entities forbidden")
        parser = etree.XMLParser(resolve_entities=False, load_dtd=False, no_network=True,
                                 huge_tree=False, remove_blank_text=False)
        parser.resolvers.add(_DenyResolver())
        root = etree.fromstring(raw, parser)
    except (ValueError, UnicodeError, etree.XMLSyntaxError) as exc:
        raise MuseumError("invalid XML") from exc
    if root.getroottree().docinfo.doctype:
        raise MuseumError("XML DTD forbidden")
    if root.getroottree().docinfo.xml_version != "1.0":
        raise MuseumError("XML version must be 1.0")
    if root.getroottree().docinfo.encoding.upper().replace("-", "") != "UTF8":
        raise MuseumError("XML encoding must be UTF-8")
    count = 0
    stack = [(root, 0)]
    while stack:
        element, depth = stack.pop()
        count += 1
        if count > 32768 or depth > 64:
            raise MuseumError("XML structural limit")
        if not isinstance(element.tag, str):
            raise MuseumError("XML comments/processing instructions forbidden")
        stack.extend((child, depth + 1) for child in element)
    # Siblings outside the root are not traversed above.
    if root.getprevious() is not None or root.getnext() is not None:
        raise MuseumError("XML outside-root nodes forbidden")
    return root


class PinnedPremis:
    def __init__(self, root: Path, profile_bytes: bytes, *, profile_hash: str):
        if profile_bytes != PROFILE_BYTES or keccak256(profile_bytes) != profile_hash:
            raise MuseumError("PREMIS profile mismatch")
        index = loads((root / "premis/dependency-index.json").read_bytes(), canonical=True)
        documents = OfflineDocuments(root, index)
        if len(index["documents"]) != 1:
            raise MuseumError("PREMIS closure must be the single pinned schema")
        raw = documents.load(SCHEMA_URI)
        if sha256(raw).hexdigest() != SCHEMA_SHA256:
            raise MuseumError("PREMIS original schema mismatch")
        # The original has comments, so its trusted parser differs from the
        # untrusted instance parser. No parser has a network/file fallback.
        parser = etree.XMLParser(resolve_entities=False, load_dtd=False, no_network=True)
        parser.resolvers.add(_DenyResolver())
        schema = etree.fromstring(raw, parser)
        if schema.xpath("//xs:import | //xs:include | //xs:redefine", namespaces={"xs": XML_SCHEMA_NS}):
            raise MuseumError("PREMIS unexpected schema dependency")
        self._schema = etree.XMLSchema(schema)

    def validate(self, raw: bytes):
        root = _xml(raw)
        if root.tag != "{" + NS + "}premis":
            raise MuseumError("PREMIS root required")
        if not self._schema.validate(root):
            raise MuseumError("PREMIS XSD validation failed")
        return root


@dataclass(frozen=True)
class PremisProjection:
    linked_art: Projection
    xml: bytes
    correspondence: bytes
    coverage: bytes
    provenance: bytes
    report: bytes


def _element(parent, name, text=None, **attributes):
    result = etree.SubElement(parent, "{" + NS + "}" + name, **attributes)
    if text is not None:
        result.text = text
    return result


def project_premis_fixture(state, selection_bytes, plan_bytes, premis_plan_bytes, *, selection_hash,
                          plan_hash, premis_plan_hash, profile_hash, linked_art_profile, premis_profile):
    if not isinstance(linked_art_profile, ProjectionProfileV2):
        raise MuseumError("PREMIS correspondence requires the accepted v2 profile")
    linked = project_fixture(state, selection_bytes, plan_bytes, selection_hash=selection_hash,
        plan_hash=plan_hash, profile_hash=profile_hash, profile=linked_art_profile)
    if keccak256(premis_plan_bytes) != premis_plan_hash:
        raise MuseumError("PREMIS plan hash mismatch")
    plan = loads(premis_plan_bytes, maximum=524288, canonical=True)
    if (not isinstance(plan, dict) or set(plan) != {"mode", "version", "sourceStateHash", "profileHash",
            "linkedArtPlanHash", "premisProfileHash", "objects"}
            or plan["mode"] != "synthetic_premis_file_projection" or plan["version"] != "1"
            or plan["sourceStateHash"] != state.commitment or plan["profileHash"] != profile_hash
            or plan["linkedArtPlanHash"] != plan_hash or plan["premisProfileHash"] != PROFILE_HASH):
        raise MuseumError("PREMIS plan scope mismatch")
    targets = plan["objects"]
    if (not isinstance(targets, list) or not 1 <= len(targets) <= 512
            or any(not isinstance(v, str) for v in targets) or len(set(targets)) != len(targets)):
        raise MuseumError("PREMIS object selection invalid")
    policy = loads(selection_bytes)
    if not set(FIELDS.values()).issubset(policy["singleValuedRelations"]):
        raise MuseumError("PREMIS facts require single-valued conflict policy")
    selection = select_canonical_fixture(state, selection_bytes, policy_hash=selection_hash, profile_hash=profile_hash)
    resources = {r.identifier: r for r in linked.resources}
    source_provenance = loads(linked.provenance, maximum=67108864)
    claims = {}
    for claim in selection.selected:
        value = loads(claim.assertion)
        claims.setdefault((value["subject"], value["relation"]), []).append((value, claim))
    withheld = [{"selector": loads(c.selector), "assertion": loads(c.assertion)} for c in selection.withheld
                if loads(c.assertion)["subject"] in targets and loads(c.assertion)["relation"] in FIELDS.values()]
    if withheld:
        raise MuseumError("PREMIS conflicting selected facts: " + dumps(withheld).decode("utf-8"))
    root = etree.Element("{" + NS + "}premis", nsmap={"premis": NS, "xsi": XSI}, version="3.0")
    correspondence, provenance, mapped = [], [], set()
    for ordinal, identifier in enumerate(sorted(targets), 1):
        resource = resources.get(identifier)
        if resource is None or loads(resource.content)["type"] != "DigitalObject":
            raise MuseumError("PREMIS file must join a selected Linked Art digital object")
        values, evidence = {}, {}
        for field, relation in FIELDS.items():
            rows = claims.get((identifier, relation), [])
            if not rows:
                raise MuseumError("PREMIS missing admitted fact: " + identifier + " " + relation)
            literals = [v["object"].get("literal") for v, _ in rows]
            datatype = DATATYPE_NS + "nonNegativeInteger" if field == "size" else STRING
            if any(not isinstance(v, dict) or v["datatype"] != datatype or any(v[k] is not None for k in
                    ("language", "unit", "precision")) for v in literals):
                raise MuseumError("PREMIS exact unqualified literal required")
            if len({dumps(v) for v in literals}) != 1:
                raise MuseumError("PREMIS selected literal inconsistency")
            values[field] = literals[0]["lexicalValue"]
            evidence[field] = rows
        if values["category"] != "file":
            raise MuseumError("PREMIS explicit file category required")
        size = uint(values["size"], 256)
        if size > (1 << 63) - 1:
            raise MuseumError("PREMIS xs:long size overflow; original source unchanged")
        if re.fullmatch(r"[0-9a-f]{64}", values["digest"]) is None:
            raise MuseumError("PREMIS SHA-256 lexical value invalid")
        if re.fullmatch(r"(?:x-)?fmt/[1-9][0-9]*", values["puid"]) is None:
            raise MuseumError("PREMIS PRONOM PUID syntax invalid")
        obj = _element(root, "object", **{"{" + XSI + "}type": "premis:file"})
        ident = _element(obj, "objectIdentifier")
        _element(ident, "objectIdentifierType", "URI")
        _element(ident, "objectIdentifierValue", identifier)
        chars = _element(obj, "objectCharacteristics")
        fixity = _element(chars, "fixity")
        _element(fixity, "messageDigestAlgorithm", "SHA-256")
        _element(fixity, "messageDigest", values["digest"])
        _element(chars, "size", values["size"])
        registry = _element(_element(chars, "format"), "formatRegistry")
        _element(registry, "formatRegistryName", "PRONOM")
        _element(registry, "formatRegistryKey", values["puid"])
        paths = {"category": "/@xsi:type", "size": "/premis:objectCharacteristics/premis:size",
            "digest": "/premis:objectCharacteristics/premis:fixity/premis:messageDigest",
            "puid": "/premis:objectCharacteristics/premis:format/premis:formatRegistry/premis:formatRegistryKey"}
        object_path = "/premis:premis/premis:object[" + str(ordinal) + "]"
        for field, rows in evidence.items():
            for value, claim in rows:
                selector = loads(claim.selector)
                source_pointer = selector["pointer"] + "/object/literal/lexicalValue"
                provenance.append({"entity": identifier, "targetXPath": object_path + paths[field],
                    "source": selector, "sourcePointer": source_pointer, "issuer": claim.issuer,
                    "basis": claim.basis, "reviewEvidence": [loads(r) for r in claim.review_evidence],
                    "rule": PREFIX + field})
                mapped.add((selector["recordHash"], source_pointer))
        identity_evidence = [p for p in source_provenance if p["entity"] == identifier and p["targetPointer"] == "/id"]
        if not identity_evidence:
            raise MuseumError("PREMIS identity declaration provenance missing")
        for p in identity_evidence:
            provenance.append({"entity": identifier, "targetXPath": object_path + "/premis:objectIdentifier/premis:objectIdentifierValue",
                "source": p["source"], "sourcePointer": p["sourcePointer"], "basis": "same selected declaration as Linked Art",
                "rule": PREFIX + "identity"})
            mapped.add((p["source"]["recordHash"], p["sourcePointer"]))
        content = loads(resource.content)
        correspondence.append({"supplementalEntityIri": identifier, "linkedArtId": identifier,
            "linkedArtContentHash": keccak256(resource.content), "premisIdentifier": {"type": "URI", "value": identifier},
            "premisXPath": object_path, "declarationEvidence": identity_evidence,
            "sourceAnchors": sorted({p["source"]["subjectId"] for p in identity_evidence}),
            "anchorRelationship": "declared about this Stream subject; not identity equivalence",
            "contentRelations": {k: content[k] for k in ("digitally_carries", "digitally_shows", "about") if k in content},
            "retainedRelations": [r for r in loads(linked.sidecar, maximum=67108864)["selectedClaims"]
                                  if r["assertion"]["subject"] == identifier and "entity" in r["assertion"]["object"]]})
    raw = etree.tostring(root, encoding="UTF-8", xml_declaration=True)
    premis_profile.validate(raw)
    coverage = loads(linked.coverage, maximum=67108864)
    for record in coverage:
        for field in record["fields"]:
            if (record["recordHash"], field["pointer"]) in mapped:
                field.update(disposition="mapped", rule=PREFIX + "coverage", reason="exact source field emitted in PREMIS; original retained")
        # Existing full inventory is retained verbatim in extent and exact bytes.
        # verify_coverage is performed by project_fixture against the source;
        # here only dispositions for additional emitted fields change.
    correspondence_raw, coverage_raw = dumps(correspondence), dumps(coverage)
    provenance_raw = dumps(sorted(provenance, key=dumps))
    report = dumps({"mode": "synthetic_premis_file_projection", "version": "1", "sourceStateHash": state.commitment,
        "profileHash": profile_hash, "premisProfileHash": PROFILE_HASH, "premisPlanHash": premis_plan_hash,
        "selectionPolicyHash": selection_hash, "linkedArtReportHash": keccak256(linked.report),
        "schemaSha256": "0x" + SCHEMA_SHA256, "xmlHash": keccak256(raw), "correspondenceHash": keccak256(correspondence_raw),
        "coverageHash": keccak256(coverage_raw), "provenanceHash": keccak256(provenance_raw),
        "validation": "pinned PREMIS 3 XSD and exact shared-source projection consistency",
        "sourcePreservation": "complete public source/schema/authority bytes in linkedArt.sidecar",
        "profileDerivedValues": {"objectIdentifierType": "URI", "messageDigestAlgorithm": "SHA-256", "formatRegistryName": "PRONOM"},
        "claims": {"registered": False, "authenticatedChainState": False, "bytesFixityVerified": False,
            "formatIdentified": False, "fullPremisCrosswalk": False, "fullMuseumScope": False}})
    return PremisProjection(linked, raw, correspondence_raw, coverage_raw, provenance_raw, report)


def verify_premis_fixture(actual: PremisProjection, *args, **kwargs):
    """Recompute from the caller's trusted source/policy; XSD validity is insufficient."""
    kwargs["premis_profile"].validate(actual.xml)
    expected = project_premis_fixture(*args, **kwargs)
    if actual != expected:
        raise MuseumError("cross-format source consistency mismatch")
    return loads(expected.report)


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Generate/check the candidate PREMIS file profile")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    path = Path(__file__).resolve().parents[2] / "schemas/museum/premis/profile.json"
    if args.check:
        if path.read_bytes() != PROFILE_BYTES:
            raise MuseumError("PREMIS profile bytes differ")
    else:
        path.write_bytes(PROFILE_BYTES)
    PinnedPremis(path.parents[1], PROFILE_BYTES, profile_hash=PROFILE_HASH)
    print("candidate_unregistered", PROFILE_HASH, len(PROFILE_BYTES))


if __name__ == "__main__":
    main()
