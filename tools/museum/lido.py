"""Same-source LIDO work description and explicit media correspondence.

The record is a public fixture projection. Source issuers are not inferred to
be creators, custodians or museums. Original statements remain in the sidecar.
"""

from dataclasses import dataclass

from lxml import etree

from .canonical import MuseumError, dumps, keccak256, loads
from .iiif import IIIFProjection, project_iiif_fixture
from .iiif_model import SOURCE, span_text
from .iiif_numbers import target_loads
from .lido_model import FIELDS, NS, XML, PREFIX, PROFILE_HASH
from .linked_art import format_checker
from .semantic_selection import select_canonical_fixture

STRING = "http://www.w3.org/2001/XMLSchema#string"


@dataclass(frozen=True)
class LIDOProjection:
    iiif: IIIFProjection
    xml: bytes
    correspondence: bytes
    coverage: bytes
    provenance: bytes
    report: bytes


def source_record_id(record):
    return PREFIX + "source-record:" + keccak256(dumps({"selector": record.selector.__dict__,
        "payloadHash": record.payload_hash, "authorityEvidenceHash": keccak256(record.authority_evidence)}))


def _e(parent, name, text=None, **attributes):
    try:
        node = etree.SubElement(parent, "{" + NS + "}" + name, **attributes)
        if text is not None:
            node.text = text
    except (ValueError, UnicodeError) as exc:
        raise MuseumError("LIDO text is not representable in XML1.0") from exc
    return node


class _Evidence:
    def __init__(self, state, selection, entity_rows, prior):
        self.records = {r.selector.record_hash: r for r in state.records}
        self.entities = {}
        for row in entity_rows:
            self.entities[self.value(row, row["pointer"])["id"]] = row
        self.claims = {}
        for c in selection.selected:
            value = loads(c.assertion)
            self.claims.setdefault((value["subject"], value["relation"]), []).append((value, c))
        self.selection, self.prior = selection, prior
        self.pending_provenance, self.mapped = [], set()

    def value(self, row, pointer):
        value = loads(self.records[row["recordHash"]].payload)
        for part in pointer.removeprefix("/").split("/"):
            part = part.replace("~1", "/").replace("~0", "~")
            value = value[int(part)] if isinstance(value, list) else value[part]
        return value

    def entity(self, identifier, kinds):
        row = self.entities.get(identifier)
        if row is None:
            raise MuseumError("LIDO selected local entity declaration required")
        value = self.value(row, row["pointer"])
        if value["kind"] not in kinds:
            raise MuseumError("LIDO entity kind mismatch")
        return value

    def conflict(self, identifier, fields):
        rows = [{"source": loads(c.selector), "assertion": loads(c.assertion)} for c in self.selection.withheld
                if loads(c.assertion)["subject"] == identifier and loads(c.assertion)["relation"] in {FIELDS[f] for f in fields}]
        if rows:
            raise MuseumError("LIDO conflicting selected facts: " + dumps(rows).decode())

    def fact(self, identifier, field, entity=False):
        rows = self.claims.get((identifier, FIELDS[field]), [])
        if not rows:
            raise MuseumError("LIDO missing selected fact: " + field)
        objects = [v["object"] for v, _ in rows]
        if len({dumps(v) for v in objects}) != 1:
            raise MuseumError("LIDO inconsistent selected objects")
        if entity:
            if set(objects[0]) != {"entity"}:
                raise MuseumError("LIDO exact entity reference required")
            value, suffix = objects[0]["entity"], "/object/entity"
        else:
            lit = objects[0].get("literal")
            if (not isinstance(lit, dict) or lit["datatype"] != STRING or lit["language"] is not None
                    or lit["unit"] is not None or lit["precision"] is not None):
                raise MuseumError("LIDO unqualified exact string required")
            value, suffix = lit["lexicalValue"], "/object/literal/lexicalValue"
        if not value:
            raise MuseumError("LIDO empty fact unsupported")
        proofs = []
        for _, c in rows:
            row = loads(c.selector)
            proofs.append({"entity": identifier, "source": row, "sourcePointer": row["pointer"] + suffix,
                "issuer": c.issuer, "basis": c.basis, "reviewEvidence": [loads(r) for r in c.review_evidence], "rule": FIELDS[field]})
        return value, proofs

    def proof(self, node, rows, attribute=None):
        for row in rows:
            issuer = loads(self.records[row["source"]["recordHash"]].authority_evidence)["agentIri"]
            self.pending_provenance.append((node, attribute,
                {k: v for k, v in row.items() if k != "targetPointer"} | {"issuer": issuer}))
            self.mapped.add((row["source"]["recordHash"], row["sourcePointer"]))

    def provenance(self):
        # Paths are stable only after every later same-named sibling exists.
        return [row | {"targetXPath": node.getroottree().getpath(node) + ("/@" + attr if attr else "")}
                for node, attr, row in self.pending_provenance]

    def emit(self, parent, tag, fact, **attributes):
        value, proofs = fact
        node = _e(parent, tag, value, **attributes)
        self.proof(node, proofs)
        return node

    def identity(self, node, identifier):
        row = self.entities[identifier]
        issuer = loads(self.records[row["recordHash"]].authority_evidence)["agentIri"]
        self.proof(node, [{"entity": identifier, "source": row, "sourcePointer": row["pointer"] + "/id",
            "issuer": issuer, "rule": PREFIX + "identity"}])

    def names(self, parent, wrapper, identifier):
        declaration = self.entity(identifier, {"person", "group", "abstract_work", "digital_object"})
        row = self.entities[identifier]
        names = [(i, n) for i, n in enumerate(declaration["names"]) if n["kind"] != "identifier"]
        if not names:
            raise MuseumError("LIDO explicit source names required")
        for i, name in names:
            if not name["value"]:
                raise MuseumError("LIDO empty source name unsupported")
            if name["language"] not in (None, "und"):
                raise MuseumError("LIDO document-language contradicts specified source name language")
            node = _e(_e(parent, wrapper), "appellationValue", name["value"])
            self.proof(node, [{"entity": identifier, "source": row, "sourcePointer": row["pointer"] + f"/names/{i}/value",
                "issuer": declaration["declaringAgent"], "rule": PREFIX + "name"}])


def project_lido_fixture(state, selection_bytes, plan_bytes, premis_plan_bytes, iiif_plan_bytes, lido_plan_bytes, *,
                         lido_plan_hash, lido_profile, **iiif_kwargs):
    iiif = project_iiif_fixture(state, selection_bytes, plan_bytes, premis_plan_bytes, iiif_plan_bytes, **iiif_kwargs)
    if keccak256(lido_plan_bytes) != lido_plan_hash:
        raise MuseumError("LIDO plan hash mismatch")
    plan = loads(lido_plan_bytes, maximum=524288, canonical=True)
    expected = {"mode": "synthetic_lido_projection", "version": "1", "sourceStateHash": state.commitment,
        "profileHash": iiif_kwargs["profile_hash"], "linkedArtPlanHash": iiif_kwargs["plan_hash"],
        "premisPlanHash": iiif_kwargs["premis_plan_hash"], "iiifPlanHash": iiif_kwargs["iiif_plan_hash"], "lidoProfileHash": PROFILE_HASH}
    if not isinstance(plan, dict) or set(plan) != set(expected) | {"recordId"} or any(plan[k] != v for k, v in expected.items()):
        raise MuseumError("LIDO plan scope mismatch")
    record_id = plan["recordId"]
    if not isinstance(record_id, str) or not format_checker().conforms(record_id, "uri"):
        raise MuseumError("LIDO record URI required")
    manifest = target_loads(iiif.manifest)
    work = manifest[SOURCE]["@value"]["workEntity"]
    linked = iiif.premis.linked_art
    sidecar = loads(linked.sidecar, maximum=67108864)
    entities = {r.identifier for r in linked.resources} | {e["id"] for e in sidecar["extensionEntities"] + sidecar["externalEntities"]}
    target_ids = {manifest["id"]}
    for c in manifest["items"]:
        page, annotation = c["items"][0], c["items"][0]["items"][0]
        target_ids.update((c["id"], page["id"], annotation["id"], annotation["body"]["id"]))
    if record_id in entities | target_ids | {source_record_id(r) for r in state.records}:
        raise MuseumError("LIDO record ID aliases an existing source or presentation identity")
    policy = loads(selection_bytes, maximum=524288)
    if not set(FIELDS.values()).issubset(policy["singleValuedRelations"]):
        raise MuseumError("LIDO single-valued conflict policy required")
    selection = select_canonical_fixture(state, selection_bytes, policy_hash=iiif_kwargs["selection_hash"], profile_hash=iiif_kwargs["profile_hash"])
    la_plan = loads(plan_bytes, maximum=524288)
    evidence = _Evidence(state, selection, la_plan["entityAuthoritySet"], loads(iiif.provenance, maximum=67108864))
    evidence.entity(work, {"abstract_work"})
    evidence.conflict(work, {"work-type", "medium", "edition", "credit-line", "creation-event", "document-language"})
    language = evidence.fact(work, "document-language")
    if language[0] != "und":
        raise MuseumError("LIDO explicit und document-language required; no default or inferred language")
    event, event_proofs = evidence.fact(work, "creation-event", entity=True)
    evidence.entity(event, {"event"})
    evidence.conflict(event, {"event-type", "creator", "creation-display"})
    event_type = evidence.fact(event, "event-type")
    if event_type[0] != "creation":
        raise MuseumError("LIDO explicit creation event required")
    creator, creator_proofs = evidence.fact(event, "creator", entity=True)
    evidence.entity(creator, {"person", "group"})
    credit = evidence.fact(work, "credit-line")
    if credit[0] != span_text(manifest["requiredStatement"]["value"]["none"][0]):
        raise MuseumError("LIDO credit line and explicit IIIF work attribution disagree: " + dumps({
            "creditLine": credit[0], "creditEvidence": credit[1],
            "workAttribution": span_text(manifest["requiredStatement"]["value"]["none"][0]),
            "attributionEvidence": [p for p in evidence.prior if p["targetPointer"] == "/requiredStatement/value/none/0"]}).decode())

    root = etree.Element("{" + NS + "}lido", nsmap={"lido": NS})
    _e(root, "lidoRecID", record_id, **{"{" + NS + "}type": "URI"})
    node = _e(root, "objectPublishedID", work, **{"{" + NS + "}type": "URI"}); evidence.identity(node, work)
    descriptive = _e(root, "descriptiveMetadata", **{"{" + XML + "}lang": language[0]})
    evidence.proof(descriptive, language[1], "xml:lang")
    classification = _e(_e(descriptive, "objectClassificationWrap"), "objectWorkTypeWrap")
    evidence.emit(_e(classification, "objectWorkType"), "term", evidence.fact(work, "work-type"))
    identification = _e(descriptive, "objectIdentificationWrap")
    evidence.names(_e(identification, "titleWrap"), "titleSet", work)
    evidence.emit(_e(identification, "displayStateEditionWrap"), "displayEdition", evidence.fact(work, "edition"))
    description = _e(_e(identification, "objectDescriptionWrap"), "objectDescriptionSet")
    node = _e(description, "descriptiveNoteValue", span_text(manifest["summary"]["none"][0]))
    evidence.proof(node, [p for p in evidence.prior if p["targetPointer"] == "/summary/none/0"])
    medium = _e(_e(identification, "objectMaterialsTechWrap"), "objectMaterialsTechSet")
    evidence.emit(medium, "displayMaterialsTech", evidence.fact(work, "medium"))
    event_node = _e(_e(_e(descriptive, "eventWrap"), "eventSet"), "event")
    node = _e(event_node, "eventID", event, **{"{" + NS + "}type": "URI"})
    evidence.identity(node, event); evidence.proof(node, event_proofs)
    evidence.emit(_e(event_node, "eventType"), "term", event_type)
    actor_role = _e(_e(event_node, "eventActor"), "actorInRole")
    actor = _e(actor_role, "actor")
    node = _e(actor, "actorID", creator, **{"{" + NS + "}type": "URI"})
    evidence.identity(node, creator); evidence.proof(node, creator_proofs)
    evidence.names(actor, "nameActorSet", creator)
    _e(_e(actor_role, "roleActor"), "term", "creator")
    evidence.emit(_e(event_node, "eventDate"), "displayDate", evidence.fact(event, "creation-display"))

    admin = _e(root, "administrativeMetadata", **{"{" + XML + "}lang": language[0]})
    evidence.proof(admin, language[1], "xml:lang")
    evidence.emit(_e(_e(admin, "rightsWorkWrap"), "rightsWorkSet"), "creditLine", credit)
    record_wrap = _e(admin, "recordWrap")
    selected_hashes = {loads(c.selector)["recordHash"] for c in selection.selected} | {r["recordHash"] for r in la_plan["entityAuthoritySet"]}
    source_rows, issuers = [], set()
    for record in sorted((r for r in state.records if r.selector.record_hash in selected_hashes), key=lambda r: source_record_id(r)):
        issuer = loads(record.authority_evidence)["agentIri"]
        evidence.entity(issuer, {"person", "group"})
        rid = source_record_id(record)
        _e(record_wrap, "recordID", rid, **{"{" + NS + "}type": "URI"})
        source_rows.append({"lidoRecordId": rid, "selector": record.selector.__dict__, "payloadHash": record.payload_hash,
            "authorityEvidenceHash": keccak256(record.authority_evidence), "issuer": issuer})
        issuers.add(issuer)
    _e(_e(record_wrap, "recordType"), "term", "item")
    for issuer in sorted(issuers):
        provider = _e(record_wrap, "recordSource")
        node = _e(provider, "legalBodyID", issuer, **{"{" + NS + "}type": "URI"}); evidence.identity(node, issuer)
        evidence.names(provider, "legalBodyName", issuer)
    resources = _e(admin, "resourceWrap")
    correspondence = loads(iiif.correspondence, maximum=67108864)
    resource_nodes = []
    for i, (canvas, row) in enumerate(zip(manifest["items"], correspondence)):
        body = canvas["items"][0]["items"][0]["body"]
        identifier = row["linkedArtId"]; prefix = row["iiifBodyPointer"]
        resource = _e(resources, "resourceSet", **{"{" + NS + "}sortorder": str(i + 1)})
        node = _e(resource, "resourceID", identifier, **{"{" + NS + "}type": "URI"}); evidence.identity(node, identifier)
        representation = _e(resource, "resourceRepresentation")
        link = _e(representation, "linkResource", body["id"], **{"{" + NS + "}formatResource": body["format"]})
        evidence.proof(link, [p for p in evidence.prior if p["targetPointer"] == prefix + "/id"])
        evidence.proof(link, [p for p in evidence.prior if p["targetPointer"] == prefix + "/format"], "lido:formatResource")
        for field in ("width", "height", "duration"):
            if field not in body:
                continue  # Text canvas layout is not a file measurement.
            proofs = [p for p in evidence.prior if p["targetPointer"] == prefix + "/" + field]
            values = {evidence.value(p["source"], p["sourcePointer"]) for p in proofs}
            if len(values) != 1:
                raise MuseumError("LIDO original extent evidence missing or inconsistent")
            measure = _e(representation, "resourceMeasurementsSet")
            _e(measure, "measurementType", field)
            _e(measure, "measurementUnit", "s" if field == "duration" else "px")
            node = _e(measure, "measurementValue", values.pop()); evidence.proof(node, proofs)
        node = _e(_e(resource, "resourceType"), "term", body["type"])
        evidence.proof(node, [p for p in evidence.prior if p["targetPointer"] == prefix + "/type"])
        for j, label in enumerate(body["label"]["none"]):
            node = _e(resource, "resourceDescription", label)
            evidence.proof(node, [p for p in evidence.prior if p["targetPointer"] == prefix + "/label/none/" + str(j)])
        rights = _e(resource, "rightsResource")
        node = _e(_e(rights, "rightsType"), "conceptID", body["rights"], **{"{" + NS + "}type": "URI"})
        evidence.proof(node, [p for p in evidence.prior if p["targetPointer"] == prefix + "/rights"])
        node = _e(rights, "creditLine", span_text(body["requiredStatement"]["value"]["none"][0]))
        evidence.proof(node, [p for p in evidence.prior if p["targetPointer"] == prefix + "/requiredStatement/value/none/0"])
        row.update(lidoRecordId=record_id, lidoWorkId=work, lidoResourceId=identifier)
        resource_nodes.append((row, resource))
    for row, resource in resource_nodes:
        row["lidoResourceXPath"] = resource.getroottree().getpath(resource)
    raw = etree.tostring(root, encoding="UTF-8", xml_declaration=True)
    lido_profile.validate(raw)
    coverage = loads(iiif.coverage, maximum=67108864)
    for record in coverage:
        for field in record["fields"]:
            if (record["recordHash"], field["pointer"]) in evidence.mapped:
                field.update(disposition="mapped", rule=PREFIX + "coverage", reason="exact source field emitted in LIDO; original retained")
    corresponding = dumps({"lidoRecordId": record_id, "workId": work, "creatorId": creator, "creationEventId": event,
        "sourceRecords": source_rows, "files": correspondence})
    coverage_raw, provenance = dumps(coverage), dumps(sorted(evidence.provenance(), key=dumps))
    report = dumps({"mode": "synthetic_lido_projection", "version": "1", "sourceStateHash": state.commitment,
        "profileHash": iiif_kwargs["profile_hash"], "lidoProfileHash": PROFILE_HASH, "lidoPlanHash": lido_plan_hash,
        "iiifReportHash": keccak256(iiif.report), "xmlHash": keccak256(raw), "correspondenceHash": keccak256(corresponding),
        "coverageHash": keccak256(coverage_raw), "provenanceHash": keccak256(provenance),
        "schemaWarnings": list(lido_profile.schema_warnings), "originalSource": "all original public bytes in iiif.premis.linked_art.sidecar",
        "claims": {"registered": False, "authenticatedChainState": False, "creatorTruthVerified": False,
            "mediaRetrieved": False, "fixityVerified": False, "rightsAuthorityVerified": False,
            "institutionalIngest": False, "fullWorkDescriptionCrosswalk": False, "fullMuseumScope": False}})
    return LIDOProjection(iiif, raw, corresponding, coverage_raw, provenance, report)


def verify_lido_fixture(actual, *args, **kwargs):
    kwargs["lido_profile"].validate(actual.xml)
    expected = project_lido_fixture(*args, **kwargs)
    if actual != expected:
        raise MuseumError("LIDO shared-source consistency mismatch")
    return loads(expected.report)
