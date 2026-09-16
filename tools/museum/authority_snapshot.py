"""Bounded offline parsing for externally retained RDF/JSON authority snapshots.

The caller retains the exact descriptor and RDF/JSON bytes.  This module only
checks their commitments and returns facts with selectors into those bytes; it
does not fetch, normalize, reconcile, or authenticate an authority publisher.
"""

from datetime import datetime
from hashlib import sha256
import re
from urllib.parse import urlsplit

from .canonical import MuseumError, hex_bytes, keccak256, loads, schema_id, uint
from .linked_art import format_checker


RDF_TYPE = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
FOAF_FOCUS = "http://xmlns.com/foaf/0.1/focus"
RAW_BYTES = schema_id("RAW_BYTES")

SKOS = "http://www.w3.org/2004/02/skos/core#"
SKOSXL = "http://www.w3.org/2008/05/skos-xl#"
RDFS_LABEL = "http://www.w3.org/2000/01/rdf-schema#label"
DCT_MODIFIED = "http://purl.org/dc/terms/modified"
OWL_VERSION_INFO = "http://www.w3.org/2002/07/owl#versionInfo"
WIKIDATA_INSTANCE_OF = "http://www.wikidata.org/prop/direct/P31"
GVP = "http://vocab.getty.edu/ontology#"

MAX_RAW_BYTES = 1024 * 1024
MAX_SUBJECTS = 4096
MAX_TERMS = 16384

_AUTHORITIES = {
    "GETTY_TGN": ("decimal", "http://vocab.getty.edu/tgn/"),
    "GETTY_AAT": ("decimal", "http://vocab.getty.edu/aat/"),
    "GETTY_ULAN": ("decimal", "http://vocab.getty.edu/ulan/"),
    "VIAF": ("decimal", "http://viaf.org/viaf/"),
    "WIKIDATA": ("wikidata", "http://www.wikidata.org/entity/"),
}
_DIRECT_LABELS = (SKOS + "prefLabel", SKOS + "altLabel", RDFS_LABEL)
_XL_LABELS = (SKOSXL + "prefLabel", SKOSXL + "altLabel")
_LITERAL_FORM = SKOSXL + "literalForm"
_HIERARCHIES = {SKOS + "broader"} | {
    GVP + name for name in (
        "broaderPreferred", "broaderNonPreferred", "broaderGeneric",
        "broaderPartitive", "broaderInstantial", "broaderExtended",
        "broaderPreferredExtended", "broaderNonPreferredExtended",
    )
}
_REVISIONS = (DCT_MODIFIED, OWL_VERSION_INFO)
_IRI = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:[^\s]+$")
_DECIMAL_ID = re.compile(r"^[1-9][0-9]*$")
_WIKIDATA_ID = re.compile(r"^Q[1-9][0-9]*$")
_UTC = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]+)?Z$")
_FORMAT_CHECKER = format_checker()


def _need(condition, message):
    if not condition:
        raise MuseumError(message)


def canonical_authority_iri(authority, identifier):
    """Return the authority's issued canonical concept/entity IRI.

    Identifiers are accepted only in their issued form.  Document URLs,
    scheme URIs, case variants, zero, and leading-zero aliases are rejected.
    """
    _need(authority in _AUTHORITIES, "unsupported authority")
    _need(isinstance(identifier, str) and len(identifier) <= 128,
          "authority identifier shape")
    kind, prefix = _AUTHORITIES[authority]
    pattern = _WIKIDATA_ID if kind == "wikidata" else _DECIMAL_ID
    _need(pattern.fullmatch(identifier) is not None, "noncanonical authority identifier")
    return prefix + identifier


def _absolute_iri(value, message="RDF IRI shape"):
    _need(isinstance(value, str) and len(value) <= 2048
          and _IRI.fullmatch(value) is not None
          and _FORMAT_CHECKER.conforms(value, "uri"), message)
    return value


def _source_uri(value):
    _absolute_iri(value, "source URI shape")
    try:
        parsed = urlsplit(value)
        hostname = parsed.hostname
        parsed.port
    except ValueError as exc:
        raise MuseumError("source URI shape") from exc
    _need(parsed.scheme in ("http", "https") and parsed.netloc and hostname
          and parsed.username is None and parsed.password is None and not parsed.fragment,
          "source URI must be an absolute HTTP(S) documentary endpoint")


def _utc(value):
    _need(isinstance(value, str) and len(value) <= 64 and _UTC.fullmatch(value),
          "retrieval time must be UTC")
    try:
        datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError as exc:
        raise MuseumError("invalid retrieval time") from exc


def _descriptor(descriptor_bytes, descriptor_hash):
    _need(type(descriptor_bytes) is bytes and 0 < len(descriptor_bytes) <= 65536,
          "descriptor byte bound")
    hex_bytes(descriptor_hash, 32)
    _need(keccak256(descriptor_bytes) == descriptor_hash, "descriptor hash differs")
    value = loads(descriptor_bytes, maximum=65536)
    required = {"version", "authority", "identifier", "canonicalIri", "sourceUri",
                "retrievedAt", "contentHash", "byteLength", "mediaType",
                "attribution", "reuseTerms"}
    _need(isinstance(value, dict) and set(value) == required, "closed snapshot descriptor")
    _need(value["version"] == "1", "unsupported snapshot descriptor version")
    expected = canonical_authority_iri(value["authority"], value["identifier"])
    _need(value["canonicalIri"] == expected, "canonical authority IRI differs")
    _source_uri(value["sourceUri"])
    _utc(value["retrievedAt"])
    _need(value["mediaType"] == "application/rdf+json", "snapshot media type differs")
    for key in ("attribution", "reuseTerms"):
        _need(isinstance(value[key], str) and 0 < len(value[key]) <= 16384
              and value[key].strip(), key + " missing")
    content_hash = value["contentHash"]
    _need(isinstance(content_hash, dict)
          and set(content_hash) == {"algorithm", "digest", "canonicalizationId"},
          "closed snapshot content hash")
    _need(content_hash["algorithm"] in ("1", "2"), "snapshot hash algorithm")
    hex_bytes(content_hash["digest"], 32)
    _need(content_hash["canonicalizationId"] == RAW_BYTES,
          "snapshot content is not committed as raw bytes")
    _need(uint(value["byteLength"]) <= MAX_RAW_BYTES, "snapshot byte bound")
    return value


def _pointer(*parts):
    def escape(value):
        return str(value).replace("~", "~0").replace("/", "~1")
    return "".join("/" + escape(part) for part in parts)


def _subject(value):
    if isinstance(value, str) and value.startswith("_:"):
        _need(2 < len(value) <= 2048 and not any(c.isspace() for c in value),
              "blank-node subject shape")
        return
    _absolute_iri(value, "RDF subject shape")


def _term(value):
    _need(isinstance(value, dict) and "type" in value and "value" in value,
          "RDF term shape")
    kind = value["type"]
    _need(kind in ("uri", "bnode", "literal"), "unsupported RDF term type")
    allowed = {"type", "value"} | ({"lang", "datatype"} if kind == "literal" else set())
    _need(set(value) <= allowed, "unsupported RDF term member")
    if kind == "uri":
        _absolute_iri(value["value"], "RDF URI term shape")
    elif kind == "bnode":
        _need(isinstance(value["value"], str) and value["value"].startswith("_:")
              and 2 < len(value["value"]) <= 2048
              and not any(c.isspace() for c in value["value"]), "RDF blank-node term shape")
    else:
        _need(isinstance(value["value"], str), "RDF literal lexical form")
        _need(not ("lang" in value and "datatype" in value),
              "RDF literal cannot have language and datatype")
        if "lang" in value:
            _need(isinstance(value["lang"], str) and 0 < len(value["lang"]) <= 255
                  and not any(c.isspace() for c in value["lang"]), "RDF language shape")
        if "datatype" in value:
            _absolute_iri(value["datatype"], "RDF datatype shape")


def _triples(graph):
    _need(isinstance(graph, dict) and 0 < len(graph) <= MAX_SUBJECTS,
          "RDF subject bound")
    rows = []
    for subject, predicates in graph.items():
        _subject(subject)
        _need(isinstance(predicates, dict), "RDF predicate map shape")
        for predicate, terms in predicates.items():
            _absolute_iri(predicate, "RDF predicate shape")
            _need(isinstance(terms, list) and terms, "RDF predicate values shape")
            for index, term in enumerate(terms):
                _term(term)
                rows.append({"subject": subject, "predicate": predicate, "object": term,
                             "sourcePointer": _pointer(subject, predicate, index)})
                _need(len(rows) <= MAX_TERMS, "RDF term bound")
    return rows


def _facts(triples, subjects, predicates, *, uri_object=False):
    rows = [row for row in triples
            if row["subject"] in subjects and row["predicate"] in predicates]
    if uri_object:
        _need(all(row["object"]["type"] == "uri" for row in rows),
              "authority relation object must be an IRI")
    return rows


def _labels(graph, triples, canonical_iri):
    labels = []
    direct = _facts(triples, {canonical_iri}, set(_DIRECT_LABELS))
    _need(all(row["object"]["type"] == "literal" for row in direct),
          "authority label must be a literal")
    labels.extend({"value": row["object"]["value"],
                   "language": row["object"].get("lang"),
                   "sourcePointer": row["sourcePointer"]} for row in direct)
    links = _facts(triples, {canonical_iri}, set(_XL_LABELS))
    _need(all(row["object"]["type"] in ("uri", "bnode") for row in links),
          "SKOS-XL label link must identify a node")
    by_subject = {}
    for row in triples:
        by_subject.setdefault(row["subject"], []).append(row)
    for link in links:
        forms = [row for row in by_subject.get(link["object"]["value"], [])
                 if row["predicate"] == _LITERAL_FORM]
        _need(all(row["object"]["type"] == "literal" for row in forms),
              "SKOS-XL literal form must be a literal")
        labels.extend({"value": row["object"]["value"],
                       "language": row["object"].get("lang"),
                       "sourcePointer": row["sourcePointer"]} for row in forms)
    return labels


def parse_snapshot(descriptor_bytes, raw, *, descriptor_hash):
    """Verify and parse one retained RDF/JSON authority snapshot offline."""
    descriptor = _descriptor(descriptor_bytes, descriptor_hash)
    _need(type(raw) is bytes and 0 < len(raw) <= MAX_RAW_BYTES, "snapshot byte bound")
    _need(uint(descriptor["byteLength"]) == len(raw), "snapshot byte length differs")
    content_hash = descriptor["contentHash"]
    digest = (keccak256(raw) if content_hash["algorithm"] == "1"
              else "0x" + sha256(raw).hexdigest())
    _need(digest == content_hash["digest"], "snapshot content hash differs")

    graph = loads(raw, maximum=MAX_RAW_BYTES)
    canonical_iri = descriptor["canonicalIri"]
    _need(isinstance(graph, dict) and canonical_iri in graph,
          "canonical authority subject missing")
    triples = _triples(graph)

    focus_rows = _facts(triples, {canonical_iri}, {FOAF_FOCUS}, uri_object=True)
    _need(len(focus_rows) <= 1, "conflicting authority focus")
    focus_iri = focus_rows[0]["object"]["value"] if focus_rows else None
    _need(focus_iri is None or focus_iri != canonical_iri,
          "authority concept and focus must remain distinct")
    subjects = {canonical_iri} | ({focus_iri} if focus_iri is not None else set())
    type_facts = _facts(triples, subjects, {RDF_TYPE, WIKIDATA_INSTANCE_OF}, uri_object=True)
    hierarchy_facts = _facts(triples, {canonical_iri}, _HIERARCHIES, uri_object=True)
    revisions = _facts(triples, {canonical_iri}, set(_REVISIONS))

    return {"authority": descriptor["authority"], "identifier": descriptor["identifier"],
            "canonicalIri": canonical_iri, "focusIri": focus_iri,
            "labels": _labels(graph, triples, canonical_iri),
            "typeFacts": type_facts, "hierarchyFacts": hierarchy_facts,
            "revisions": revisions, "triples": triples,
            "descriptorHash": descriptor_hash, "contentHash": content_hash,
            "descriptor": descriptor}
