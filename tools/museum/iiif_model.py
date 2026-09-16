"""Versioned, deliberately finite Presentation 3 target validation.

The local schema is derived from the pinned specification; it is not an upstream
IIIF schema. Original remote contexts remain exact, with a visibly named Sound
supplement in the emitted context sequence.
"""

from decimal import Decimal
from hashlib import sha256
from pathlib import Path
import copy
import json
import re
from urllib.parse import urlsplit

from jsonschema import Draft202012Validator, validators
from lxml import etree
from pyld import jsonld
from pyld.context_resolver import ContextResolver

from .canonical import MuseumError, dumps, keccak256, loads
from .dependencies import OfflineDocuments
from .iiif_numbers import target_loads
from .iiif_pins import INDEX_SHA256, DOCUMENT_SHA256, CONTEXT_REFERENCES

CONTEXT = "http://iiif.io/api/presentation/3/context.json"
ANNO_CONTEXT = "http://www.w3.org/ns/anno.jsonld"
SOUND_CONTEXT = "urn:6529stream:museum:iiif-p3:sound-context:v1"
SOUND_BYTES = dumps({"@context": {"Sound": "http://purl.org/dc/dcmitype/Sound"}})
CONTEXT_SEQUENCE = [CONTEXT, SOUND_CONTEXT]
EXT = "urn:6529stream:museum:iiif-p3:v1:"
SOURCE = EXT + "sourceEvidence"
DIGEST = EXT + "sha256"
SIZE = EXT + "byteSize"
XSD = "http://www.w3.org/2001/XMLSchema#"
MIMES = {"Image": ["image/jpeg", "image/png", "image/webp", "image/gif", "image/tiff"],
         "Text": ["text/plain"], "Sound": ["audio/mpeg", "audio/mp4", "audio/ogg", "audio/wav"],
         "Video": ["video/mp4", "video/webm", "video/ogg"]}
RIGHTS = ["http://creativecommons.org/licenses/by/4.0/",
          "http://creativecommons.org/licenses/by-sa/4.0/",
          "http://creativecommons.org/publicdomain/zero/1.0/",
          "http://rightsstatements.org/vocab/InC/1.0/"]


def _object(properties, required=None):
    return {"type": "object", "properties": properties, "required": list(properties) if required is None else required,
            "additionalProperties": False}


def schema_document():
    text = {"type": "string", "minLength": 1, "maxLength": 65536}
    language = _object({"none": {"type": "array", "items": text, "minItems": 1, "maxItems": 128}})
    statement = _object({"label": language, "value": language})
    identifier = {"type": "string", "minLength": 1, "maxLength": 4096}
    dim = {"type": "integer", "minimum": 1, "maximum": (1 << 53) - 1}
    duration = {"type": "number", "exclusiveMinimum": 0}
    source = _object({"@type": {"const": "@json"}, "@value": {"type": "object"}})
    common = {"id": identifier, "type": {"enum": list(MIMES)}, "format": text, "label": language,
              "requiredStatement": statement, "rights": {"enum": RIGHTS}, SOURCE: source,
              DIGEST: _object({"@type": {"const": XSD + "string"}, "@value": {"type": "string", "pattern": "^[0-9a-f]{64}$"}}),
              SIZE: _object({"@type": {"const": XSD + "nonNegativeInteger"},
                             "@value": {"type": "string", "pattern": "^(0|[1-9][0-9]*)$"}})}
    body = _object(common | {"width": dim, "height": dim, "duration": duration}, list(common))
    annotation = _object({"id": identifier, "type": {"const": "Annotation"}, "motivation": {"const": "painting"},
                          "target": identifier, "body": {"$ref": "#/$defs/body"}})
    page = _object({"id": identifier, "type": {"const": "AnnotationPage"},
                    "items": {"type": "array", "items": {"$ref": "#/$defs/annotation"}, "minItems": 1, "maxItems": 1}})
    canvas = _object({"id": identifier, "type": {"const": "Canvas"}, "label": language, "width": dim, "height": dim,
                      "duration": duration, "items": {"type": "array", "items": {"$ref": "#/$defs/page"}, "minItems": 1, "maxItems": 1}},
                     ["id", "type", "label", "items"])
    return {"$schema": "https://json-schema.org/draft/2020-12/schema", "$id": EXT + "target-schema",
        **_object({"@context": {"const": CONTEXT_SEQUENCE}, "id": identifier, "type": {"const": "Manifest"},
            "label": language, "summary": language, "requiredStatement": statement, "rights": {"enum": RIGHTS},
            SOURCE: source, "items": {"type": "array", "items": {"$ref": "#/$defs/canvas"}, "minItems": 1, "maxItems": 128}}),
        "$defs": {"body": body, "annotation": annotation, "page": page, "canvas": canvas}}


SCHEMA_BYTES = dumps(schema_document())


def profile_document():
    return {"mode": "candidate_unregistered", "id": "STREAM_MUSEUM_IIIF_P3_CORRESPONDENCE_V1", "version": "1",
        "sourceFamily": "STREAM_SEMANTIC_ASSERTION_V1", "sourceAuthority": "exact public fixture selection and review; no chain authority",
        "targetSchemaHash": keccak256(SCHEMA_BYTES), "originalDependencyIndexSha256": "0x" + INDEX_SHA256,
        "targetValidation": "local finite schema derived from pinned Presentation 3 specification, plus exact shared-source recomputation",
        "interpretation": {"version": "1", "rule": "explicit second context, Sound term supplement",
            "sources": {uri: "0x" + DOCUMENT_SHA256[uri] for uri in (CONTEXT, ANNO_CONTEXT)},
            "guard": "original @context is object; Sound absent; Audio exactly dctypes:Sound; originals remain unchanged",
            "supplementUri": SOUND_CONTEXT, "supplementHash": keccak256(SOUND_BYTES), "emittedContextSequence": CONTEXT_SEQUENCE,
            "basis": "Presentation 3 section 3.2 Sound and exact v3 audio cookbook example; source bytes never modified",
            "contextReferences": "all scoped references enumerated independently; pinned semantic cycle is not a hash-DAG edge"},
        "targetEncoding": "sorted keys, ordered arrays, exact decimal lexicals and integers, UTF-8; NOT RFC8785",
        "sourceValues": "positive decimal duration requires explicit decimal point; exact source lexical emitted; no inferred dimensions or MIME",
        "sourceRules": [
            {"field": name, "relation": EXT + name, "datatype": XSD + datatype, "unit": unit, "target": target}
            for name, datatype, unit, target in (
                ("presentation-type", "string", None, "body.type"), ("mime", "string", None, "body.format"),
                ("content-uri", "anyURI", None, "body.id"), ("rights", "anyURI", None, "same entity rights"),
                ("manifest-rights", "anyURI", None, "generated Manifest JSON only; separate from underlying work/file rights"),
                ("attribution", "string", None, "same entity requiredStatement"), ("summary", "string", None, "work summary"),
                ("width", "positiveInteger", "px", "body/Canvas width"), ("height", "positiveInteger", "px", "body/Canvas height"),
                ("duration", "decimal", "s", "body/Canvas duration"),
                ("text-canvas-width", "positiveInteger", "canvas-unit", "Text Canvas width only"),
                ("text-canvas-height", "positiveInteger", "canvas-unit", "Text Canvas height only"))],
        "sourceEntityRule": {"relation": EXT + "presentation-of", "object": "exact selected abstract work IRI"},
        "text": "unqualified plaintext and names with unspecified language map to none; HTML fields escape into XML 1.0 span with CR character references",
        "mediaTypes": MIMES, "rightsIdentifiers": RIGHTS,
        "paintingUriProfile": ["canonical CIDv1 raw SHA-256 lower-base32 IPFS, matching declared PREMIS digest", "canonical Arweave transaction id; no raw digest equivalence"],
        "layouts": "one full-file Canvas per selected file, explicit pixel/duration extent; Text has separate declared canvas layout",
        "identityReuse": "painting URI differs from admitted entity IRIs; repeated content URI requires matching type/MIME/extent/digest/size/rights/attribution, with source lexicals retained",
        "bounds": {"canvases": "128", "dimension": str((1 << 53) - 1), "decimalLexicalCharacters": "128", "jsonBytes": "16777216"},
        "preservation": "entire Linked Art/PREMIS source inventory and exact public source bytes retained; output validation does not establish fixity",
        "remaining": ["registered canonical media references", "viewer and gateway interoperability", "availability", "byte fixity verification",
            "additional languages and URI codecs", "segments and supplementing annotations", "services and interactive works", "LIDO and institutional ingest", "full Museum gates"]}


PROFILE_BYTES = dumps(profile_document())
PROFILE_HASH = keccak256(PROFILE_BYTES)


def plain_span(text):
    """Preserve every plaintext code point through IIIF's HTML-enabled fields."""
    if not isinstance(text, str) or not text:
        raise MuseumError("IIIF nonempty plaintext required")
    if any(not (ord(c) in (9, 10, 13) or 0x20 <= ord(c) <= 0xD7FF or 0xE000 <= ord(c) <= 0xFFFD
                or 0x10000 <= ord(c) <= 0x10FFFF) for c in text):
        raise MuseumError("IIIF plaintext is not XML 1.0 representable")
    return "<span>" + text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\r", "&#13;") + "</span>"


def span_text(text):
    if not isinstance(text, str) or not text.startswith("<span>") or not text.endswith("</span>"):
        raise MuseumError("IIIF plaintext span required")
    try:
        element = etree.fromstring(text.encode("utf-8"), etree.XMLParser(resolve_entities=False, load_dtd=False, no_network=True))
        if element.tag != "span" or element.attrib or len(element) or element.tail or element.getnext() is not None:
            raise MuseumError("IIIF plaintext span has unexpected structure")
        value = element.text or ""
        if plain_span(value) != text:
            raise MuseumError("IIIF plaintext span is not the exact profile encoding")
        return value
    except (UnicodeError, etree.XMLSyntaxError) as exc:
        raise MuseumError("IIIF invalid plaintext span") from exc


def http_id(value):
    if not isinstance(value, str) or not value or any(ord(c) <= 32 or ord(c) >= 127 for c in value):
        raise MuseumError("IIIF identifier requires an ASCII HTTP(S) URI")
    try:
        parsed = urlsplit(value)
        from rfc3986_validator import validate_rfc3986
        match = validate_rfc3986(value, rule="URI")
        if (not match or match.end() != len(value) or parsed.scheme not in ("http", "https")
                or not parsed.hostname or parsed.username is not None or parsed.password is not None or parsed.fragment):
            raise MuseumError("IIIF profile identifier invalid or fragmented")
        _ = parsed.port
    except ValueError as exc:
        raise MuseumError("IIIF identifier port invalid") from exc
    return value


def context_references(value):
    result = set()
    if isinstance(value, dict):
        for key, item in value.items():
            if key in ("@context", "@import"):
                if isinstance(item, str): result.add(item)
                elif isinstance(item, list): result.update(v for v in item if isinstance(v, str))
            result.update(context_references(item))
    elif isinstance(value, list):
        for item in value: result.update(context_references(item))
    return sorted(result)


def check_original_context(uri, raw, document):
    if sha256(raw).hexdigest() != DOCUMENT_SHA256.get(uri):
        raise MuseumError("IIIF original context hash mismatch")
    if document != json.loads(raw):
        raise MuseumError("IIIF original context object differs from pinned bytes")
    if uri in (CONTEXT, ANNO_CONTEXT):
        context = document.get("@context")
        if not isinstance(context, dict) or "Sound" in context or context.get("Audio") != "dctypes:Sound":
            raise MuseumError("IIIF Sound interpretation guard mismatch")
    return copy.deepcopy(document)


class PinnedIIIF:
    def __init__(self, root: Path, profile_bytes: bytes, *, profile_hash: str):
        if profile_bytes != PROFILE_BYTES or keccak256(profile_bytes) != profile_hash:
            raise MuseumError("IIIF profile mismatch")
        raw_index = (root / "iiif/dependency-index.json").read_bytes()
        if sha256(raw_index).hexdigest() != INDEX_SHA256:
            raise MuseumError("IIIF dependency inventory mismatch")
        index = loads(raw_index, canonical=True)
        self.documents = OfflineDocuments(root, index)
        if {r["sourceUri"] for r in index["documents"]} != set(DOCUMENT_SHA256):
            raise MuseumError("IIIF dependency closure mismatch")
        self.contexts = {}
        for uri, digest in DOCUMENT_SHA256.items():
            raw = self.documents.load(uri)
            if sha256(raw).hexdigest() != digest:
                raise MuseumError("IIIF original dependency mismatch")
            if uri in CONTEXT_REFERENCES:
                doc = self.documents.jsonld_loader(uri)["document"]
                if context_references(doc) != CONTEXT_REFERENCES[uri]:
                    raise MuseumError("IIIF scoped context closure mismatch")
                self.contexts[uri] = check_original_context(uri, raw, doc)
        if any(ref not in self.contexts for refs in CONTEXT_REFERENCES.values() for ref in refs):
            raise MuseumError("IIIF unresolved scoped context")
        if (root / "iiif/sound-context.json").read_bytes() != SOUND_BYTES:
            raise MuseumError("IIIF named Sound supplement mismatch")
        self.contexts[SOUND_CONTEXT] = loads(SOUND_BYTES)
        if (root / "iiif/target.schema.json").read_bytes() != SCHEMA_BYTES:
            raise MuseumError("IIIF local target schema mismatch")
        schema = schema_document()
        Draft202012Validator.check_schema(schema)
        checker = Draft202012Validator.TYPE_CHECKER.redefine("number", lambda _, v: type(v) in (int, Decimal))
        self.validator = validators.extend(Draft202012Validator, type_checker=checker)(schema)

    def loader(self, uri, options=None):
        if uri not in self.contexts:
            raise MuseumError("IIIF offline context unavailable")
        return {"contextUrl": None, "documentUrl": uri, "document": copy.deepcopy(self.contexts[uri])}

    def validate(self, raw):
        value = target_loads(raw)
        if not self.validator.is_valid(value):
            raise MuseumError("IIIF local target schema validation failed")
        ids = [http_id(value["id"])]
        for resource in [value] + [c["items"][0]["items"][0]["body"] for c in value["items"]]:
            for v in resource["requiredStatement"]["value"]["none"]: span_text(v)
        for v in value["summary"]["none"]: span_text(v)
        for c in value["items"]:
            page, annotation = c["items"][0], c["items"][0]["items"][0]
            ids.extend(http_id(v["id"]) for v in (c, page, annotation))
            if annotation["target"] != c["id"]:
                raise MuseumError("IIIF annotation target differs from Canvas")
            body = annotation["body"]
            kind = body["type"]
            if body["format"] not in MIMES[kind]:
                raise MuseumError("IIIF unsupported explicit type/MIME pair")
            expected = {"Image": {"width", "height"}, "Text": set(), "Sound": {"duration"},
                        "Video": {"width", "height", "duration"}}[kind]
            present = set(body) & {"width", "height", "duration"}
            canvas_expected = expected if kind != "Text" else {"width", "height"}
            if present != expected or set(c) & {"width", "height", "duration"} != canvas_expected:
                raise MuseumError("IIIF full-file spatial/temporal extent mismatch")
            if any(body[k] != c[k] for k in expected):
                raise MuseumError("IIIF Canvas would resize or trim declared full-file extent")
            if "duration" in expected and (type(body["duration"]) is not Decimal or type(c["duration"]) is not Decimal):
                raise MuseumError("IIIF duration must have an explicit fractional token")
            from .iiif_uri import content_uri_facts
            content_uri_facts(body["id"], body[DIGEST]["@value"])
        if len(ids) != len(set(ids)):
            raise MuseumError("IIIF structural identifiers collide")
        # Expansion preserves Decimal values in memory. This does not perform
        # RDF normalization or serialize them through a binary floating type.
        try:
            expanded = jsonld.expand(value, {"documentLoader": self.loader, "base": "", "processingMode": "json-ld-1.1",
                "contextResolver": ContextResolver({}, self.loader, max_context_urls=16)})
        except Exception as exc:
            raise MuseumError("IIIF interpreted offline JSON-LD expansion failed") from exc
        return value, expanded


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Generate/check candidate IIIF model and complete offline closure")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2] / "schemas/museum"
    for name, raw in (("profile.json", PROFILE_BYTES), ("target.schema.json", SCHEMA_BYTES), ("sound-context.json", SOUND_BYTES)):
        path = root / "iiif" / name
        if args.check:
            if path.read_bytes() != raw: raise MuseumError("IIIF generated document mismatch")
        else: path.write_bytes(raw)
    PinnedIIIF(root, PROFILE_BYTES, profile_hash=PROFILE_HASH)
    print("candidate_unregistered", PROFILE_HASH)


if __name__ == "__main__":
    main()
