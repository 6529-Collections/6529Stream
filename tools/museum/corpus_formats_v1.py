"""Four-format correspondence for the retained synthetic media/history corpus.

Only supported target documents are emitted. A described-only resource is not
silently promoted to a preserved PREMIS file or a IIIF painting body.
"""

from lxml import etree

from .canonical import MuseumError, dumps, keccak256, loads
from .fixtures_v2 import SCENARIOS
from .lido import _e
from .lido_model import NS, XML, PinnedLIDO, PROFILE_BYTES, PROFILE_HASH
from .same_source_format_ledger_v1 import _pointer, _target_pointer


FORMATS = ("linked-art", "premis", "iiif", "lido")
SUPPORTED_LIDO = ("photograph", "software_interactive")
QUALIFICATION = ("Synthetic source fields and target values only. LIDO describes the fixture's "
    "named work without authenticating its creator or a publisher. Described-only resources "
    "lack received bytes, size, digest, format, rights and a painting URI; PREMIS file and "
    "IIIF painting exports remain unsupported. No institutional ingest or current authority.")


def _lido(name, source, model):
    """Reuse the repository's pinned LIDO XSD and XML emitter, not a new schema."""
    work = source["workId"]
    record = "urn:6529stream:museum:synthetic-lido-record:" + keccak256(dumps(source))[2:]
    root = etree.Element("{" + NS + "}lido", nsmap={"lido": NS})
    record_node = _e(root, "lidoRecID", record, **{"{" + NS + "}type": "URI"})
    work_node = _e(root, "objectPublishedID", work, **{"{" + NS + "}type": "URI"})
    descriptive = _e(root, "descriptiveMetadata", **{"{" + XML + "}lang": source["language"]})
    classification = _e(_e(descriptive, "objectClassificationWrap"), "objectWorkTypeWrap")
    class_node = _e(_e(classification, "objectWorkType"), "term",
                    "photograph" if name == "photograph" else "interactive software")
    identification = _e(descriptive, "objectIdentificationWrap")
    title_node = _e(_e(_e(identification, "titleWrap"), "titleSet"), "appellationValue",
                    source["title"])
    note_node = _e(_e(_e(identification, "objectDescriptionWrap"), "objectDescriptionSet"),
                   "descriptiveNoteValue", source["creatorStatement"])
    admin = _e(root, "administrativeMetadata", **{"{" + XML + "}lang": source["language"]})
    wrap = _e(admin, "recordWrap")
    _e(wrap, "recordID", record, **{"{" + NS + "}type": "URI"})
    _e(_e(wrap, "recordType"), "term", "item")
    _e(_e(_e(wrap, "recordSource"), "legalBodyName"), "appellationValue",
       "Synthetic fixture generator (unverified)")
    raw = etree.tostring(root, encoding="UTF-8", xml_declaration=True)
    model.validate(raw)
    evidence = []
    for pointer, node, attribute, rule in (
        ("/workId", work_node, None, "fixture-v2:lido-work-identity"),
        ("/scenario", class_node, None, "fixture-v2:lido-work-type"),
        ("/title", title_node, None, "fixture-v2:lido-title"),
        ("/creatorStatement", note_node, None, "fixture-v2:lido-quoted-statement"),
        ("/language", descriptive, "xml:lang", "fixture-v2:lido-document-language"),
        ("/language", admin, "xml:lang", "fixture-v2:lido-document-language"),
    ):
        path = node.getroottree().getpath(node) + ("/@xml:lang" if attribute else "")
        found = root.xpath(path, namespaces={"lido": NS, "xml": XML})
        if len(found) != 1:
            raise MuseumError("synthetic LIDO target correspondence differs")
        value = str(found[0]) if attribute else found[0].text
        expected = _pointer(source, pointer)
        if value != (class_node.text if pointer == "/scenario" else expected):
            raise MuseumError("synthetic LIDO target correspondence differs")
        evidence.append({"sourcePointer": pointer, "sourceHash": keccak256(dumps(source)),
                         "targetXPath": path, "targetValue": value, "rule": rule,
                         "authority": "synthetic fixture; unauthenticated"})
    return raw, dumps(evidence), {"recordId": record, "workId": work}


def build(files, model_root):
    """Add a format-local ledger to the already replayed V3 semantic package."""
    model = PinnedLIDO(model_root, PROFILE_BYTES, profile_hash=PROFILE_HASH)
    output = {"definitions/lido-profile.json": PROFILE_BYTES}
    index = loads(files["semantic/entity-index.json"], maximum=65536, canonical=True)
    rows = []
    for name in SCENARIOS:
        source_path = "input/corpus/" + name + "/source/payload.json"
        source_raw = files[source_path]
        source = loads(source_raw, maximum=24576, canonical=True)
        if any(resource["presence"] != "described_only" for resource in source["resources"]):
            raise MuseumError("synthetic format support assumes described-only resources")
        source_hash = keccak256(source_raw)
        coverage = loads(files["semantic/" + name + "/coverage.json"], maximum=65536, canonical=True)
        linked_proofs = loads(files["semantic/" + name + "/provenance.json"],
                              maximum=65536, canonical=True)
        entities = {row["id"]: row["path"] for row in index if row["scenario"] == name}
        proofs = {fmt: {} for fmt in FORMATS}
        for proof in linked_proofs:
            if "targetPath" in proof:
                continue  # Typed extension is not a Linked Art resource.
            path = entities[proof["entity"]]
            target, normalized = _target_pointer(loads(files[path], canonical=True), proof["targetPointer"])
            proofs["linked-art"].setdefault(proof["sourcePointer"], []).append({
                "path": path, "pointer": normalized, "value": target,
                "rule": proof["rule"]})
        lido_identity = None
        if name in SUPPORTED_LIDO:
            raw, provenance, lido_identity = _lido(name, source, model)
            path = "formats/" + name + "/lido.xml"
            output[path] = raw
            output["formats/" + name + "/lido-provenance.json"] = provenance
            for proof in loads(provenance, canonical=True):
                proofs["lido"].setdefault(proof["sourcePointer"], []).append({
                    "path": path, "xpath": proof["targetXPath"],
                    "value": proof["targetValue"], "rule": proof["rule"]})
        fields, comparisons = [], []
        for field in coverage:
            pointer = field["pointer"]
            cells = {fmt: {"disposition": "mapped" if proofs[fmt].get(pointer) else
                        "retained_stream_only", "targets": proofs[fmt].get(pointer, [])}
                     for fmt in FORMATS}
            fields.append({"sourcePointer": pointer, "presence": field["presence"],
                           "exactHex": field["exactHex"], "formats": cells})
            represented = {fmt: cells[fmt]["targets"] for fmt in FORMATS if cells[fmt]["targets"]}
            if len(represented) >= 2:
                values = {fmt: [row["value"] for row in targets]
                          for fmt, targets in represented.items()}
                original = _pointer(source, pointer)
                equal = all(value == original for targets in values.values() for value in targets)
                comparisons.append({"sourcePointer": pointer, "exactHex": field["exactHex"],
                    "formats": sorted(represented), "status": "exact_lexical" if equal else
                    "different_target_representations", "targetValues": values,
                    "qualification": "Same original field; target equality does not establish source authority."})
        rows.append({"scenario": name, "sourcePath": source_path, "sourceHash": source_hash,
                     "fields": fields, "comparisons": comparisons,
                     "identities": {"work": source["workId"],
                         "linkedArtEntities": sorted(entities), "lido": lido_identity},
                     "support": {"linked-art": "projected" if entities else "no_supported_entities",
                         "premis": "unsupported_described_only_no_file_fixity",
                         "iiif": "unsupported_no_painting_uri_mime_rights_or_received_media",
                         "lido": "projected" if lido_identity else "unsupported_bounded_work_profile"}})
    ledger = dumps({"version": "1",
        "formats": list(FORMATS), "scenarios": rows, "qualification": QUALIFICATION,
        "claims": {"syntheticOnly": True, "fullFourFormatParity": False,
                   "authenticatedAuthority": False, "institutionalAcceptance": False}})
    if len(ledger) > 2 * 1024 * 1024:
        raise MuseumError("synthetic format ledger bound")
    output["formats/field-correspondence.json"] = ledger
    return output
