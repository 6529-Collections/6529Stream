"""One public-fixture Presentation 3 Manifest from the same PREMIS/Linked Art source.

No network media retrieval, gateway, registered record or creator/rights authority
is inferred. The plan chooses layout order and target identifiers; every content
fact and file-to-work association must be explicitly selected from source.
"""

from dataclasses import dataclass
from .canonical import MuseumError, dumps, keccak256, loads, uint
from .iiif_model import (CONTEXT_SEQUENCE, EXT, SOURCE, DIGEST, SIZE, XSD, MIMES, RIGHTS,
                         PROFILE_HASH, plain_span, http_id)
from .iiif_numbers import ExactDecimal, target_dumps
from .iiif_uri import content_uri_facts
from .premis import PremisProjection, project_premis_fixture
from .semantic_selection import select_canonical_fixture

FIELDS = {name: EXT + name for name in ("presentation-type", "mime", "content-uri", "width", "height", "duration",
    "text-canvas-width", "text-canvas-height", "attribution", "rights", "manifest-rights", "summary", "presentation-of")}


@dataclass(frozen=True)
class IIIFProjection:
    premis: PremisProjection
    manifest: bytes
    correspondence: bytes
    coverage: bytes
    provenance: bytes
    report: bytes


def project_iiif_fixture(state, selection_bytes, plan_bytes, premis_plan_bytes, iiif_plan_bytes, *,
                         iiif_plan_hash, iiif_profile, **premis_kwargs):
    premis = project_premis_fixture(state, selection_bytes, plan_bytes, premis_plan_bytes, **premis_kwargs)
    premis_plan = loads(premis_plan_bytes, maximum=524288, canonical=True)
    premis_correspondence = loads(premis.correspondence, maximum=67108864)
    premis_provenance = loads(premis.provenance, maximum=67108864)
    if keccak256(iiif_plan_bytes) != iiif_plan_hash:
        raise MuseumError("IIIF plan hash mismatch")
    plan = loads(iiif_plan_bytes, maximum=524288, canonical=True)
    if (not isinstance(plan, dict) or set(plan) != {"mode", "version", "sourceStateHash", "profileHash", "linkedArtPlanHash",
            "premisPlanHash", "iiifProfileHash", "work", "manifestId", "canvases"}
            or plan["mode"] != "synthetic_iiif_projection" or plan["version"] != "1"
            or plan["sourceStateHash"] != state.commitment or plan["profileHash"] != premis_kwargs["profile_hash"]
            or plan["linkedArtPlanHash"] != premis_kwargs["plan_hash"]
            or plan["premisPlanHash"] != premis_kwargs["premis_plan_hash"] or plan["iiifProfileHash"] != PROFILE_HASH):
        raise MuseumError("IIIF plan scope mismatch")
    canvases = plan["canvases"]
    if (not isinstance(canvases, list) or not 1 <= len(canvases) <= 128
            or any(not isinstance(c, dict) or set(c) != {"file", "canvasId", "pageId", "annotationId"}
                   or any(not isinstance(v, str) for v in c.values()) for c in canvases)):
        raise MuseumError("IIIF finite Canvas plan required")
    files = [c["file"] for c in canvases]
    if len(set(files)) != len(files) or set(files) != set(premis_plan["objects"]):
        raise MuseumError("IIIF and PREMIS must select the same distinct files")
    work = plan["work"]
    resources = {r.identifier: r for r in premis.linked_art.resources}
    sidecar = loads(premis.linked_art.sidecar, maximum=67108864)
    admitted_entities = set(resources) | {e["id"] for e in sidecar["extensionEntities"] + sidecar["externalEntities"]}
    if not isinstance(work, str) or work not in resources or loads(resources[work].content)["type"] != "PropositionalObject":
        raise MuseumError("IIIF work must join a distinct selected abstract work")
    ids = [http_id(plan["manifestId"])] + [http_id(c[k]) for c in canvases for k in ("canvasId", "pageId", "annotationId")]
    if len(ids) != len(set(ids)) or set(ids) & admitted_entities:
        raise MuseumError("IIIF target identities must remain distinct from source entities")
    policy = loads(selection_bytes, maximum=524288)
    if not set(FIELDS.values()).issubset(policy["singleValuedRelations"]):
        raise MuseumError("IIIF facts require exact single-valued conflict policy")
    selection = select_canonical_fixture(state, selection_bytes, policy_hash=premis_kwargs["selection_hash"],
                                         profile_hash=premis_kwargs["profile_hash"])
    claims = {}
    for c in selection.selected:
        value = loads(c.assertion)
        claims.setdefault((value["subject"], value["relation"]), []).append((value, c))
    work_fields = {FIELDS[k] for k in ("attribution", "summary", "manifest-rights")}
    file_fields = set(FIELDS.values()) - {FIELDS["summary"], FIELDS["manifest-rights"]}
    conflicts = [{"source": loads(c.selector), "assertion": loads(c.assertion)} for c in selection.withheld
                 if (loads(c.assertion)["subject"] == work and loads(c.assertion)["relation"] in work_fields)
                 or (loads(c.assertion)["subject"] in files and loads(c.assertion)["relation"] in file_fields)]
    if conflicts:
        raise MuseumError("IIIF conflicting selected facts: " + dumps(conflicts).decode("utf-8"))
    provenance, mapped = [], set()

    def fact(entity, field, target, *, datatype=XSD + "string", unit=None, entity_value=False):
        rows = claims.get((entity, FIELDS[field]), [])
        if not rows:
            raise MuseumError("IIIF missing admitted fact: " + entity + " " + field)
        objects = [v["object"] for v, _ in rows]
        if len({dumps(obj) for obj in objects}) != 1:
            raise MuseumError("IIIF inconsistent selected objects")
        if entity_value:
            if set(objects[0]) != {"entity"} or objects[0]["entity"] != work:
                raise MuseumError("IIIF file must explicitly identify the selected presentation work")
            value = work
            suffix = "/object/entity"
        else:
            v = objects[0].get("literal")
            if (not isinstance(v, dict) or v["datatype"] != datatype or v["unit"] != unit
                    or v["language"] is not None or v["precision"] is not None):
                raise MuseumError("IIIF exact declared literal/units required")
            value = v["lexicalValue"]
            suffix = "/object/literal/lexicalValue"
        for _, claim in rows:
            selector = loads(claim.selector)
            pointer = selector["pointer"] + suffix
            provenance.append({"entity": entity, "targetPointer": target, "source": selector, "sourcePointer": pointer,
                "issuer": claim.issuer, "basis": claim.basis, "reviewEvidence": [loads(r) for r in claim.review_evidence],
                "rule": FIELDS[field]})
            mapped.add((selector["recordHash"], pointer))
        return value

    prior_provenance = loads(premis.linked_art.provenance, maximum=67108864)
    source_records = {r.selector.record_hash: r for r in state.records}

    def source_value(selector, pointer):
        value = loads(source_records[selector["recordHash"]].payload)
        for segment in pointer.removeprefix("/").split("/"):
            segment = segment.replace("~1", "/").replace("~0", "~")
            value = value[int(segment)] if isinstance(value, list) else value[segment]
        return value

    def label(entity, target):
        content = loads(resources[entity].content)
        names = content.get("identified_by", [])
        # The initial profile has unspecified-language labels only. It never
        # changes a specified language into none, or falls back to an invented IRI title.
        if not names or any(set(n) != {"type", "content"} or n["type"] != "Name" or not n["content"] for n in names):
            raise MuseumError("IIIF explicit unspecified-language names required")
        for i, name in enumerate(names):
            proofs = [p for p in prior_provenance if p["entity"] == entity and p["targetPointer"] == f"/identified_by/{i}/content"]
            if not proofs:
                raise MuseumError("IIIF name source evidence missing")
            for p in proofs:
                language_pointer = p["sourcePointer"].rsplit("/", 1)[0] + "/language"
                if source_value(p["source"], language_pointer) is not None:
                    raise MuseumError("IIIF specified-language label mapping unsupported; source retained")
                provenance.append(p | {"targetPointer": target + "/none/" + str(i), "rule": EXT + "label"})
                provenance.append(p | {"sourcePointer": language_pointer, "targetPointer": target + "/none", "rule": EXT + "unspecified-language"})
                mapped.update(((p["source"]["recordHash"], p["sourcePointer"]), (p["source"]["recordHash"], language_pointer)))
        return {"none": [n["content"] for n in names]}

    def ownership(entity, prefix):
        attribution = fact(entity, "attribution", prefix + "/requiredStatement/value/none/0")
        rights = fact(entity, "manifest-rights" if entity == work else "rights", prefix + "/rights", datatype=XSD + "anyURI")
        if rights not in RIGHTS:
            raise MuseumError("IIIF unsupported exact rights identifier")
        return {"requiredStatement": {"label": {"none": ["Attribution"]}, "value": {"none": [plain_span(attribution)]}}, "rights": rights}

    manifest = {"@context": CONTEXT_SEQUENCE, "id": plan["manifestId"], "type": "Manifest", "label": label(work, "/label"),
        "summary": {"none": [plain_span(fact(work, "summary", "/summary/none/0"))]}, **ownership(work, ""),
        SOURCE: {"@type": "@json", "@value": {"mode": "synthetic_fixture", "workEntity": work,
            "sourceStateHash": state.commitment, "planHash": iiif_plan_hash, "iiifProfileHash": PROFILE_HASH,
            "sourceAuthorityProfileHash": premis_kwargs["profile_hash"], "selectionPolicyHash": premis_kwargs["selection_hash"]}}, "items": []}
    for p in prior_provenance:
        if p["entity"] == work and p["targetPointer"] == "/id":
            provenance.append(p | {"targetPointer": "/" + SOURCE + "/@value/workEntity", "rule": EXT + "work-identity"})
    premis_rows = {r["supplementalEntityIri"]: r for r in premis_correspondence}
    xml = premis_kwargs["premis_profile"].validate(premis.xml)
    ns = {"p": "http://www.loc.gov/premis/v3"}
    xml_facts = {o.findtext("p:objectIdentifier/p:objectIdentifierValue", namespaces=ns): {
        "digest": o.findtext("p:objectCharacteristics/p:fixity/p:messageDigest", namespaces=ns),
        "size": o.findtext("p:objectCharacteristics/p:size", namespaces=ns)} for o in xml.findall("p:object", ns)}
    correspondence = []
    uri_interpretations = {}
    for i, entry in enumerate(canvases):
        entity = entry["file"]
        prefix = f"/items/{i}/items/0/items/0/body"
        kind = fact(entity, "presentation-type", prefix + "/type")
        mime = fact(entity, "mime", prefix + "/format")
        if kind not in MIMES or mime not in MIMES[kind]:
            raise MuseumError("IIIF unsupported explicit type/MIME pair")
        uri = fact(entity, "content-uri", prefix + "/id", datatype=XSD + "anyURI")
        uri_info = content_uri_facts(uri, xml_facts[entity]["digest"])
        if uri in admitted_entities:
            raise MuseumError("IIIF content URI collides with an admitted entity identity")
        fact(entity, "presentation-of", prefix + "/" + SOURCE + "/@value/workEntity", entity_value=True)
        body = {"id": uri, "type": kind, "format": mime, "label": label(entity, prefix + "/label"),
                **ownership(entity, prefix), DIGEST: {"@type": XSD + "string", "@value": xml_facts[entity]["digest"]},
                SIZE: {"@type": XSD + "nonNegativeInteger", "@value": xml_facts[entity]["size"]}}
        dimensions = {}
        required_fields = {"Image": {"width", "height"}, "Text": {"text-canvas-width", "text-canvas-height"},
                           "Sound": {"duration"}, "Video": {"width", "height", "duration"}}[kind]
        dimension_fields = {"width", "height", "duration", "text-canvas-width", "text-canvas-height"}
        if any((entity, FIELDS[f]) in claims for f in dimension_fields - required_fields):
            raise MuseumError("IIIF conflicting or unsupported layout dimensions")
        for field in sorted(required_fields):
            target = f"/items/{i}/" + field.replace("text-canvas-", "")
            if field == "duration":
                lexical = fact(entity, field, target, datatype=XSD + "decimal", unit="s")
                numeric = ExactDecimal(lexical)
                if "." not in lexical or numeric.value <= 0:
                    raise MuseumError("IIIF positive exact fractional duration required")
            else:
                lexical = fact(entity, field, target, datatype=XSD + "positiveInteger",
                               unit="canvas-unit" if field.startswith("text-canvas-") else "px")
                numeric = uint(lexical, 256)
                if not 1 <= numeric <= (1 << 53) - 1:
                    raise MuseumError("IIIF declared dimension outside supported exact range")
            dimensions[field.replace("text-canvas-", "")] = numeric
            if not field.startswith("text-canvas-"):
                body[field] = numeric
                matching = [p for p in provenance if p["entity"] == entity and p["targetPointer"] == target]
                provenance.extend(p | {"targetPointer": prefix + "/" + field} for p in matching)
        for p in premis_provenance:
            if p["entity"] != entity:
                continue
            if p["rule"].endswith(":digest"):
                target = prefix + "/" + DIGEST + "/@value"
            elif p["rule"].endswith(":size"):
                target = prefix + "/" + SIZE + "/@value"
            elif p["rule"].endswith(":identity"):
                target = prefix + "/" + SOURCE + "/@value/fileEntity"
            else:
                continue
            provenance.append({k: v for k, v in p.items() if k != "targetXPath"} | {"targetPointer": target})
        selectors = sorted({dumps(p["source"]) for p in provenance if p["entity"] == entity})
        body[SOURCE] = {"@type": "@json", "@value": {"mode": "synthetic_fixture", "fileEntity": entity,
            "workEntity": work, "selectors": [loads(s) for s in selectors], "premisXmlHash": keccak256(premis.xml)}}
        duration = body.get("duration")
        interpretation = (kind, mime, body.get("width"), body.get("height"),
            duration.value if duration is not None else None, xml_facts[entity]["digest"], xml_facts[entity]["size"],
            body["rights"], dumps(body["requiredStatement"]))
        if uri in uri_interpretations and uri_interpretations[uri] != interpretation:
            raise MuseumError("IIIF repeated content URI has conflicting declared interpretation")
        uri_interpretations[uri] = interpretation
        canvas = {"id": entry["canvasId"], "type": "Canvas", "label": label(entity, f"/items/{i}/label"), **dimensions,
            "items": [{"id": entry["pageId"], "type": "AnnotationPage", "items": [{"id": entry["annotationId"],
                "type": "Annotation", "motivation": "painting", "target": entry["canvasId"], "body": body}]}]}
        manifest["items"].append(canvas)
        correspondence.append(premis_rows[entity] | {"workEntity": work, "iiifManifestId": plan["manifestId"],
            "iiifCanvasId": entry["canvasId"], "iiifBodyId": uri, "contentUriEvidence": uri_info,
            "sha256": xml_facts[entity]["digest"], "byteSize": xml_facts[entity]["size"], "iiifBodyPointer": prefix,
            "identityRelationship": "file entity and content URI are explicitly associated, never equated to token/work/Canvas"})
    raw = target_dumps(manifest)
    _, expanded = iiif_profile.validate(raw)
    # At this boundary the full @json selector data and Decimal values survive
    # expansion. No RDF serialization, URDNA normalization or float conversion.
    coverage = loads(premis.coverage, maximum=67108864)
    for record in coverage:
        for field in record["fields"]:
            if (record["recordHash"], field["pointer"]) in mapped:
                field.update(disposition="mapped", rule=EXT + "coverage", reason="exact source field emitted in IIIF; original retained")
    correspondence_raw, coverage_raw = dumps(correspondence), dumps(coverage)
    provenance_raw = dumps(sorted(provenance, key=dumps))
    report = dumps({"mode": "synthetic_iiif_projection", "version": "1", "sourceStateHash": state.commitment,
        "profileHash": premis_kwargs["profile_hash"], "iiifProfileHash": PROFILE_HASH, "iiifPlanHash": iiif_plan_hash,
        "premisReportHash": keccak256(premis.report), "manifestHash": keccak256(raw), "correspondenceHash": keccak256(correspondence_raw),
        "coverageHash": keccak256(coverage_raw), "provenanceHash": keccak256(provenance_raw),
        "validation": "pinned original standards, explicit named Sound supplement, finite local schema, Decimal-preserving offline expansion and shared-source recomputation",
        "expandedRootCount": str(len(expanded)), "originalSource": "all public original bytes remain in premis.linked_art.sidecar",
        "claims": {"registered": False, "authenticatedChainState": False, "mediaRetrieved": False, "fixityVerified": False,
            "formatDetected": False, "viewerInteroperability": False, "fullIiifProfile": False, "fullMuseumScope": False}})
    return IIIFProjection(premis, raw, correspondence_raw, coverage_raw, provenance_raw, report)


def verify_iiif_fixture(actual: IIIFProjection, *args, **kwargs):
    kwargs["iiif_profile"].validate(actual.manifest)
    expected = project_iiif_fixture(*args, **kwargs)
    if actual != expected:
        raise MuseumError("IIIF shared-source consistency mismatch")
    return loads(expected.report)
