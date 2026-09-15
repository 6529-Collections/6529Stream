"""Faithful typed WORK to original LIDO1.1, with explicit fixture provenance."""

from dataclasses import dataclass

from lxml import etree

from .canonical import MuseumError, dumps, keccak256, loads
from .lido import _e
from .lido_model import NS, XML
from .work_lido_context import PROFILE_BYTES, PROFILE_HASH, load_context
from .work_lido_source import MAX_INVENTORY_BYTES, load_work_source

LIMIT = 4 * 1024 * 1024
TYPE, LANG, SOURCE = "{" + NS + "}type", "{" + XML + "}lang", "{" + NS + "}source"


@dataclass(frozen=True)
class WorkLidoProjection:
    xml: bytes | None
    sidecar: bytes
    coverage: bytes
    provenance: bytes
    report: bytes


def pointer(value, path):
    if not path:
        return value
    for key in path[1:].split("/"):
        key = key.replace("~1", "/").replace("~0", "~")
        value = value[int(key)] if isinstance(value, list) else value[key]
    return value


class _Evidence:
    def __init__(self, source, context, context_raw, fields, branches):
        self.raw = {"work": source.payload, "context": context_raw}
        if source.catalog is not None:
            self.raw["catalog"] = source.catalog
        self.values = {k: loads(v, maximum=32768) for k, v in self.raw.items()}
        inventory = loads(source.inventory, maximum=MAX_INVENTORY_BYTES)
        self.fields = inventory["fields"] + fields
        self.branches = inventory["branches"] + branches
        self.context = context
        self.pending, self.mapped = [], set()

    def value(self, name, path):
        return pointer(self.values[name], path)

    def proof(self, name, path):
        # A WORK author's declaration does not establish catalog authorship.
        author = self.context["sourceDeclaration"]["declaredAuthor"] if name == "work" else None
        if name == "context" and path.startswith("/statements/"):
            author = self.value(name, "/".join(path.split("/")[:3]))["authorId"]
        return {"source": name, "sourceHash": keccak256(self.raw[name]), "pointer": path,
                "exactHex": "0x" + dumps(self.value(name, path)).hex(), "declaredAuthor": author,
                "authority": "public fixture declaration only; unverified"}

    def bind(self, node, refs, rule="exact", attribute=None):
        value = node.get(attribute) if attribute else node.text
        self.pending.append((node, attribute, {"rule": rule, "targetValue": value,
            "sources": [self.proof(*ref) for ref in refs]}))
        self.mapped.update(refs)

    def emit(self, parent, tag, name, path, *, language=None, **attrs):
        node = _e(parent, tag, self.value(name, path), **attrs)
        self.bind(node, [(name, path)])
        if language:
            self.language(node, *language)
        return node

    def language(self, node, name, path):
        try:
            node.set(LANG, self.value(name, path))
        except (ValueError, UnicodeError) as exc:
            raise MuseumError("WORK LIDO XML language") from exc
        self.bind(node, [(name, path)], attribute=LANG)

    def provenance(self, reparsed):
        rows = []
        for node, attribute, row in self.pending:
            suffix = "/@xml:lang" if attribute == LANG else "/@lido:" + etree.QName(attribute).localname if attribute else ""
            path = node.getroottree().getpath(node) + suffix
            found = reparsed.xpath(path, namespaces={"lido": NS, "xml": XML})
            values = [str(x) if attribute else x.text for x in found]
            if values != [row["targetValue"]]:
                raise MuseumError("WORK LIDO final XPath/value mismatch")
            rows.append(row | {"targetXPath": path})
        return sorted(rows, key=dumps)

    def coverage(self, no_xml):
        rows = []
        for field in self.fields:
            mapped = (field["source"], field["pointer"]) in self.mapped
            reason = ("exact or explicitly transformed source emitted in XML; original retained" if mapped else
                      "applicable optional absent; no invented value" if field["presence"] == "absent" else
                      "no XML: incomplete independent LIDO context; source remains explicit absence" if no_xml else
                      "retained exact source/control/association/catalog/context evidence; not asserted as an indexed LIDO fact")
            rows.append(field | {"disposition": "mapped" if mapped else "retained", "reason": reason})
        return {"fields": rows, "branches": self.branches}


def _controlled(parent, tag, value, **attrs):
    return _e(parent, tag, value, **{LANG: "en", **attrs})


def _text_group(evidence, parent, wrapper, tag, source_path, language, variants, *, kind=None):
    group = _e(parent, wrapper, **({TYPE: kind} if kind else {}))
    evidence.emit(group, tag, "work", source_path, language=language)
    for index, variant in variants:
        prefix = "/languageVariants/" + str(index)
        evidence.emit(group, tag, "work", prefix + "/value", language=("work", prefix + "/language"))
    return group


def _variants(value, field, index=None):
    return [(i, v) for i, v in enumerate(value["languageVariants"])
            if v["field"] == field and (index is None or v.get("alternateTitleIndex") == str(index))]


def _full(e, descriptive, identification, language, statements):
    v = e.values["work"]
    titles = _e(identification, "titleWrap")
    _text_group(e, titles, "titleSet", "appellationValue", "/title", language, _variants(v, "title"), kind="work-title")
    for i in range(len(v["alternateTitles"])):
        _text_group(e, titles, "titleSet", "appellationValue", "/alternateTitles/" + str(i), language,
                    _variants(v, "alternateTitle", i), kind="alternate-title")
    if "inscription" in v:
        ins = _e(_e(identification, "inscriptionsWrap"), "inscriptions")
        _text_group(e, ins, "inscriptionDescription", "descriptiveNoteValue", "/inscription", language,
                    _variants(v, "inscription"))
    edition = _e(identification, "displayStateEditionWrap")
    if v["edition"]["kind"] == "open_series":
        e.emit(edition, "displayEdition", "work", "/edition/statement", language=language)
    else:
        paths = ["/edition/kind"] if v["edition"]["kind"] == "unique" else ["/edition/number", "/edition/total"]
        text = "unique" if len(paths) == 1 else v["edition"]["number"] + " / " + v["edition"]["total"]
        node = _controlled(edition, "displayEdition", text)
        e.bind(node, [("work", p) for p in paths], "unique literal" if len(paths) == 1 else "serial number + ' / ' + total")

    # Descriptive format facts never imply a media resource, fetched specification,
    # MIME identification, license, or a preservation fixity check.
    descriptions = _e(identification, "objectDescriptionWrap")
    def note(path, kind):
        group = _e(descriptions, "objectDescriptionSet", **{TYPE: kind})
        e.emit(group, "descriptiveNoteValue", "work", path, **{LANG: "en"})
    note("/format/kind", "format-declaration-kind")
    if v["format"]["kind"] == "pronom":
        note("/format/puid", "PRONOM-PUID")
    elif v["format"]["kind"] == "catalog":
        mapping = v["format"]["mapping"]
        base = "/format/mapping"
        if mapping["kind"] == "pronom":
            note(base + "/puid", "PRONOM-PUID")
        else:
            note(base + "/specification/uri", "format-specification-uri")
            note(base + "/specification/hash/digest", "format-specification-keccak256-RAW_BYTES")

    measures = _e(_e(identification, "objectMeasurementsWrap"), "objectMeasurementsSet")
    m = v["measurements"]
    if m["kind"] == "dimensionless_generative":
        e.emit(measures, "displayObjectMeasurements", "work", "/measurements/kind", **{LANG: "en"})
    else:
        # Original XSD explicitly recommends display for fractions. Do not put
        # an unreduced rational into a decimal-index field or round it.
        for key, label in (("aspectRatio", "aspect ratio"), ("durationSeconds", "duration in seconds")):
            if key in m:
                paths = ["/measurements/" + key + "/" + p for p in ("numerator", "denominator")]
                text = label + ": " + m[key]["numerator"] + "/" + m[key]["denominator"]
                node = _controlled(measures, "displayObjectMeasurements", text)
                e.bind(node, [("work", p) for p in paths], label + ": exact numerator + '/' + denominator")
        if "pixels" in m:
            indexed = _e(measures, "objectMeasurements")
            for key in ("width", "height"):
                row = _e(indexed, "measurementsSet")
                _controlled(row, "measurementType", key)
                e.emit(row, "measurementUnit", "work", "/measurements/pixels/unit", **{LANG: "en"})
                e.emit(row, "measurementValue", "work", "/measurements/pixels/" + key)

    materials = _e(identification, "objectMaterialsTechWrap")
    medium = _text_group(e, materials, "objectMaterialsTechSet", "displayMaterialsTech", "/medium", language, _variants(v, "medium"))
    material_refs = [(i, r) for i, r in enumerate(v["authorityReferences"]) if r["role"] in ("medium", "technique")]
    if material_refs:
        tech = _e(medium, "materialsTech")
        for i, ref in material_refs:
            prefix = "/authorityReferences/" + str(i)
            term = _e(tech, "termMaterialsTech", **{TYPE: ref["role"]})
            e.bind(term, [("work", prefix + "/role")], attribute=TYPE)
            node = e.emit(term, "conceptID", "work", prefix + "/identifier", **{TYPE: ref["authority"]})
            e.bind(node, [("work", prefix + "/authority")], attribute=TYPE)

    event = _e(_e(_e(descriptive, "eventWrap"), "eventSet"), "event")
    _controlled(_e(event, "eventType"), "term", "creation")
    role = _e(_e(event, "eventActor"), "actorInRole")
    actor = _e(role, "actor")
    if v["creator"]["kind"] == "artist":
        e.emit(actor, "actorID", "work", "/creator/artistId", **{TYPE: "STREAM_ARTIST_ID"})
    for i, ref in enumerate(v["authorityReferences"]):
        if ref["role"] == "creator":
            prefix = "/authorityReferences/" + str(i)
            node = e.emit(actor, "actorID", "work", prefix + "/identifier", **{TYPE: ref["authority"]})
            e.bind(node, [("work", prefix + "/authority")], attribute=TYPE)
    if v["creator"]["kind"] == "named":
        _text_group(e, actor, "nameActorSet", "appellationValue", "/creator/name", language, _variants(v, "creatorName"))
    else:
        _, prefix = statements["artistName"]
        group = _e(actor, "nameActorSet")
        e.emit(group, "appellationValue", "context", prefix + "/value", language=("context", prefix + "/language"))
    _controlled(_e(role, "roleActor"), "term", "creator")
    date = _e(event, "eventDate")
    c = v["creation"]
    paths = ["/creation/date", "/creation/date"] if c["kind"] == "date" else ["/creation/start", "/creation/end"]
    node = _e(date, "displayDate", e.value("work", paths[0]) if c["kind"] == "date" else c["start"] + " / " + c["end"])
    e.bind(node, [("work", p) for p in dict.fromkeys(paths)], "exact" if c["kind"] == "date" else "inclusive start + ' / ' + end")
    indexed = _e(date, "date")
    for tag, path in zip(("earliestDate", "latestDate"), paths):
        e.emit(indexed, tag, "work", path, **{TYPE: "exact"})


def project_work_lido_fixture(payload, context_bytes, *, expected_subject_id, context_hash,
                              profile_bytes, profile_hash, lido_schema, catalog_bytes=None):
    if profile_bytes != PROFILE_BYTES or profile_hash != PROFILE_HASH:
        raise MuseumError("WORK LIDO mapping profile mismatch")
    source = load_work_source(payload, expected_subject_id=expected_subject_id, catalog=catalog_bytes)
    context, statements, fields, branches = load_context(context_bytes, expected_hash=context_hash, source=source)
    e = _Evidence(source, context, context_bytes, fields, branches)
    required = {"documentLanguage", "objectWorkType", "exportPublisher"}
    if source.form == "description_absent":
        required.add("workLabel")
    elif e.values["work"]["creator"]["kind"] == "artist":
        required.add("artistName")
    missing = sorted(required - set(statements))
    if missing and source.form == "full":
        raise MuseumError("WORK LIDO missing explicit context: " + ", ".join(missing))
    xml, provenance = None, []
    if not missing:
        language = ("context", statements["documentLanguage"][1] + "/value")
        root = etree.Element("{" + NS + "}lido", nsmap={"lido": NS})
        e.emit(root, "lidoRecID", "context", "/recordId", **{TYPE: "URI"})
        e.emit(root, "objectPublishedID", "context", "/workId", **{TYPE: "URI"})
        descriptive = _e(root, "descriptiveMetadata"); e.language(descriptive, *language)
        classification = _e(_e(descriptive, "objectClassificationWrap"), "objectWorkTypeWrap")
        _, kind = statements["objectWorkType"]
        e.emit(_e(classification, "objectWorkType"), "term", "context", kind + "/value", language=("context", kind + "/language"))
        identification = _e(descriptive, "objectIdentificationWrap")
        if source.form == "full":
            _full(e, descriptive, identification, language, statements)
        else:
            _, label = statements["workLabel"]
            title = _e(_e(identification, "titleWrap"), "titleSet", **{TYPE: "catalogue-work-label"})
            e.emit(title, "appellationValue", "context", label + "/value", language=("context", label + "/language"))
            descriptions = _e(identification, "objectDescriptionWrap")
            for field in ("reason", "date"):
                note = _e(descriptions, "objectDescriptionSet", **{TYPE: "description-absence-" + field})
                e.emit(note, "descriptiveNoteValue", "work", "/absence/" + field, language=language)
        admin = _e(root, "administrativeMetadata"); e.language(admin, *language)
        if source.form == "full":
            rights = _e(_e(admin, "rightsWorkWrap"), "rightsWorkSet")
            e.emit(rights, "creditLine", "work", "/creditLine", language=language)
            for i, _ in _variants(e.values["work"], "creditLine"):
                prefix = "/languageVariants/" + str(i)
                e.emit(rights, "creditLine", "work", prefix + "/value", language=("work", prefix + "/language"))
        records = _e(admin, "recordWrap")
        e.emit(records, "recordID", "context", "/recordId", **{TYPE: "URI"})
        _controlled(_e(records, "recordType"), "term", "item")
        publisher = _e(records, "recordSource")
        _, prefix = statements["exportPublisher"]
        e.emit(publisher, "legalBodyID", "context", prefix + "/id", **{TYPE: "URI"})
        e.emit(_e(publisher, "legalBodyName"), "appellationValue", "context", prefix + "/name", language=("context", prefix + "/language"))
        info = _e(records, "recordInfoSet", **{TYPE: "public-fixture-source-declaration"})
        e.emit(info, "recordInfoID", "context", "/sourceDeclaration/id", **{TYPE: "URI"})
        xml = etree.tostring(root, encoding="UTF-8", xml_declaration=True)
        reparsed = lido_schema.validate(xml)
        provenance = e.provenance(reparsed)
    sidecar = dumps({"mode": "public_fixture_work_lido", "sources": [
        {"name": name, "hash": keccak256(raw), "originalHex": "0x" + raw.hex()} for name, raw in sorted(e.raw.items())]})
    coverage, provenance_raw = dumps(e.coverage(bool(missing))), dumps(provenance)
    report = dumps({"mode": "public_fixture_work_lido", "version": "1", "profileHash": PROFILE_HASH,
        "subjectId": source.subject_id, "workPayloadHash": source.payload_hash, "contextHash": context_hash,
        "sourceForm": source.form, "outcome": "accounted_absence_no_xml" if missing else "lido_xml",
        "missingContext": missing, "xmlHash": None if xml is None else keccak256(xml),
        "sidecarHash": keccak256(sidecar), "coverageHash": keccak256(coverage), "provenanceHash": keccak256(provenance_raw),
        "schemaWarnings": list(lido_schema.schema_warnings),
        "claims": {"registered": False, "authenticatedRecordAuthority": False, "currentSelection": False,
            "creatorAuthorityVerified": False, "catalogRegistered": False, "mediaRetrieved": False,
            "fixityVerified": False, "rightsLicenseInferred": False, "institutionalIngest": False, "fullMuseumScope": False}})
    if any(len(raw) > LIMIT for raw in (xml or b"", sidecar, coverage, provenance_raw, report)):
        raise MuseumError("WORK LIDO output bound")
    return WorkLidoProjection(xml, sidecar, coverage, provenance_raw, report)


def verify_work_lido_fixture(actual, *args, **kwargs):
    expected = project_work_lido_fixture(*args, **kwargs)
    if actual != expected:
        raise MuseumError("WORK LIDO source-to-output consistency mismatch")
    return loads(expected.report)
