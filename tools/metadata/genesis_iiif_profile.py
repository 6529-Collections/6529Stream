"""Canonical archival IIIF core; supplied media joins are not chain authentication.

The old correspondence exporter and its URI/number profile are unchanged. This
new schema covers the CMC-IIIF archival core, allows Presentation 3 extensions,
and keeps operational service manifests outside the permanence claim.
"""
import argparse
import base64
import json
import math
from pathlib import Path
import re
from urllib.parse import urlsplit

from jsonschema import Draft202012Validator, FormatChecker, ValidationError
import rfc8785

from tools.museum.canonical import MuseumError, _pairs, dumps, schema_id, subject_id, uint
from tools.museum.iiif_pins import DOCUMENT_SHA256, INDEX_SHA256

ROOT = Path(__file__).resolve().parents[2]
NAME = "STREAM_IIIF_P3_MIN_V1"
CONTEXT = "http://iiif.io/api/presentation/3/context.json"
MEDIA_TERM = "urn:6529stream:iiif:committed-media:v1"
MAX_BYTES = 16 * 1024 * 1024
HEX = {"type": "string", "pattern": r"^0x[0-9a-f]{64}$", "minLength": 66, "maxLength": 66}
URI = {"type": "string", "format": "uri", "maxLength": 4096}
UINT = {"type": "string", "pattern": r"^(0|[1-9][0-9]*)$", "maxLength": 78}
ADDRESS = {"type": "string", "pattern": r"^0x[0-9a-f]{40}$", "minLength": 42, "maxLength": 42}


def obj(properties, required=None):
    # Extensions are expressly permitted by CMC-IIIF rule2.
    return {"type": "object", "properties": properties,
            "required": list(properties) if required is None else required}


def arr(items, minimum=1):
    return {"type": "array", "items": items, "minItems": minimum, "maxItems": 4096}


def schema():
    language = {"type": "object", "minProperties": 1,
        "propertyNames": {"pattern": r"^(none|[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*)$"},
        "additionalProperties": arr({"type": "string"})}
    hash_ref = {**obj({"algorithm": {"enum": ["keccak256", "sha256", "sha512", "blake3"]},
                        "digest": {"type": "string", "pattern": r"^0x[0-9a-f]+$"}}),
                "additionalProperties": False}
    identity = {"chainId": UINT, "core": ADDRESS, "collectionId": UINT, "tokenId": UINT}
    source = {"oneOf": [
        {**obj({"kind": {"const": "MediaManifest"}, "scope": {"enum": ["collection", "token"]},
            **identity, "sourceRecordHash": HEX,
            "field": {"enum": ["imageHash", "animationHash", "contentHash", "manifestHash", "alternatesHash"]}}), "additionalProperties": False},
        {**obj({"kind": {"const": "token_media"}, "scope": {"const": "token"},
            **identity, "leafHash": HEX, "contentRootHash": HEX,
            "field": {"enum": ["imageHash", "animationHash", "contentHash"]}}), "additionalProperties": False}]}
    binding = {**obj({"source": source, "subjectId": HEX, "contentHash": hash_ref}), "additionalProperties": False}
    extent = {"width": {"type": "integer", "minimum": 1, "maximum": 9007199254740991},
              "height": {"type": "integer", "minimum": 1, "maximum": 9007199254740991},
              "duration": {"type": "number", "exclusiveMinimum": 0}}
    content = obj({"id": {**URI, "pattern": r"^(ipfs|ar)://"},
        "type": {"enum": ["Image", "Video", "Sound", "Text", "Dataset", "Model"]},
        "format": {"type": "string", "pattern": r"^[a-z0-9.+-]+/[a-z0-9.+-]+$"},
        MEDIA_TERM: binding, **extent}, ["id", "type", "format", MEDIA_TERM])
    # Inline resources are excluded: even a Text resource has committed bytes.
    content["not"] = {"anyOf": [{"required": ["value"]}, {"required": ["chars"]}]}
    body = {"oneOf": [{"$ref": "#/$defs/content"},
        obj({"type": {"const": "Choice"}, "items": arr({"$ref": "#/$defs/content"})})]}
    annotation = obj({"id": URI, "type": {"const": "Annotation"},
        "motivation": {"const": "painting"}, "target": {"oneOf": [URI,
            obj({"type": {"const": "SpecificResource"}, "source": URI}, ["type", "source"])]},
        "body": {"oneOf": [body, arr(body)]}})
    page = obj({"id": URI, "type": {"const": "AnnotationPage"}, "items": arr(annotation)})
    canvas = obj({"id": URI, "type": {"const": "Canvas"}, "items": arr(page), **extent},
                 ["id", "type", "items"])
    canvas["anyOf"] = [{"required": ["width", "height"]}, {"required": ["duration"]}]
    canvas["dependentRequired"] = {"width": ["height"], "height": ["width"]}
    return {"$schema": "https://json-schema.org/draft/2020-12/schema", "title": NAME,
        "$id": "urn:6529stream:schema:" + NAME, "$defs": {"content": content},
        **obj({"@context": {"oneOf": [{"const": CONTEXT},
                   {"type": "array", "contains": {"const": CONTEXT}, "minItems": 1,
                    "items": {"type": ["string", "object"]}}]},
            "id": {**URI, "pattern": r"^https?://[^/\s]+(?:/.*)?$"}, "type": {"const": "Manifest"}, "label": language, "summary": language,
            "requiredStatement": obj({"label": language, "value": language}),
            "rights": {**URI, "pattern": r"^https?://(?:creativecommons\.org/(?:licenses|publicdomain)/|rightsstatements\.org/vocab/)[^\s?#]+/$"},
            "items": arr(canvas)}),
        "x-stream-schema-id": schema_id(NAME), "x-stream-document-status": "candidate_unregistered",
        "x-stream-profile": {
            "standard": "IIIF Presentation 3.0", "specificationSha256": "0x" + DOCUMENT_SHA256["https://iiif.io/api/presentation/3.0/"],
            "dependencyIndexSha256": "0x" + INDEX_SHA256,
            "mediaBindingTerm": MEDIA_TERM,
            "sourceJoin": "Each painting resource binds an exact MediaManifest record/field or token-content leaf/root/field, with chain/Core/collection/token scope and derived subject. One identity per Canvas; supplied expected media set must equal the depicted set.",
            "extensions": "Additional Presentation 3 fields, services, selectors and supplementary annotation pages are allowed; core fields remain mandatory.",
            "canvasExtent": "Canvas has paired width/height and/or duration; dimensions declared by painting content must also be declared on Canvas. Different image/Canvas dimensions may represent scaling and are not forced equal.",
            "permanence": "Hash-committed archival manifest and content-addressed painting resources only; HTTPS image/tile services are operational.",
            "serviceCompanion": "A separate supersedable IIIF_SERVICE_MANIFEST references the archival manifest hash; never replaces it or becomes a finality input.",
            "lineage": "Revision requires a new hash-bound record and supersession; registry/record-chain authorization checked by authenticated source consumers.",
            "validation": "Schema plus local structural/media joins; no resource retrieval, byte fixity, availability, viewer interoperability, general IIIF extension validation or institutional ingest claim.",
            "rightsCore": "Creative Commons and RightsStatements identifiers only; extension-defined rights vocabularies require a future explicit interpretation.",
            "limits": {"manifestBytes": str(MAX_BYTES), "jsonDepth": "64", "jsonNodes": "200000"}}}


SCHEMA_BYTES = dumps(schema())


def _walk(value, depth=0, count=None):
    count = [0] if count is None else count
    count[0] += 1
    if depth > 64 or count[0] > 200000:
        raise MuseumError("IIIF structure limit")
    if type(value) is float and not math.isfinite(value):
        raise MuseumError("nonfinite IIIF number")
    if type(value) is int and abs(value) > 9007199254740991:
        raise MuseumError("IIIF I-JSON integer overflow")
    if isinstance(value, str):
        value.encode("utf-8")
        if re.search(r"<\s*(script|iframe|object|embed)\b|\bon\w+\s*=|(?:javascript|vbscript):", value, re.I):
            raise MuseumError("embedded executable content")
    if isinstance(value, dict):
        for key, child in value.items():
            _walk(key, depth + 1, count); _walk(child, depth + 1, count)
    elif isinstance(value, list):
        for child in value:
            _walk(child, depth + 1, count)


def _cid(address):
    alphabet58 = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

    def radix(text, alphabet):
        number = 0
        for character in text:
            if character not in alphabet:
                raise MuseumError("invalid CID base encoding")
            number = number * len(alphabet) + alphabet.index(character)
        raw = number.to_bytes((number.bit_length() + 7) // 8, "big")
        return bytes(len(text) - len(text.lstrip(alphabet[0]))) + raw

    if address.startswith("Qm"):
        raw = radix(address, alphabet58)
        if len(raw) != 34 or raw[:2] != bytes((0x12, 0x20)):
            raise MuseumError("invalid CIDv0 multihash")
        return
    if address.startswith("b"):
        text = address[1:]
        try:
            raw = base64.b32decode(text.upper() + "=" * ((-len(text)) % 8))
        except ValueError as exc:
            raise MuseumError("invalid CID base32") from exc
        if base64.b32encode(raw).decode().lower().rstrip("=") != text:
            raise MuseumError("noncanonical CID base32")
    elif address.startswith("z"):
        raw = radix(address[1:], alphabet58)
    elif address.startswith("k"):
        raw = radix(address[1:], "0123456789abcdefghijklmnopqrstuvwxyz")
    else:
        raise MuseumError("unsupported CID multibase")
    offset = 0

    def varint():
        nonlocal offset
        value, shift = 0, 0
        while offset < len(raw) and shift < 64:
            byte = raw[offset]; offset += 1
            value |= (byte & 127) << shift
            if byte < 128:
                if shift and byte == 0:
                    raise MuseumError("noncanonical CID varint")
                if value >= 1 << 64:
                    raise MuseumError("CID varint overflow")
                return value
            shift += 7
        raise MuseumError("truncated CID varint")

    if varint() != 1 or varint() == 0:
        raise MuseumError("invalid CID version or codec")
    varint()  # Multihash code is preserved, not restricted to raw SHA-256.
    length = varint()
    if not 1 <= length <= 128 or len(raw) - offset != length:
        raise MuseumError("invalid CID multihash length")


def _content_uri(value):
    """Validate the archival scheme/address syntax, without digest equivalence.

    CID codecs, multihashes and paths are not constrained to the old raw-SHA256
    exporter. Validity/availability of an address is an external byte-level check.
    """
    if not isinstance(value, str) or re.search(r"[\s\\\x00-\x1f]", value):
        raise MuseumError("invalid archival content URI")
    parsed = urlsplit(value)
    if parsed.scheme not in ("ipfs", "ar") or not parsed.netloc or parsed.query or parsed.fragment:
        raise MuseumError("content-addressed painting URI required")
    if parsed.scheme == "ipfs":
        # CMC leaves CID codec selection open. Recognize canonical CIDv0 and
        # CIDv1 base32/base58/base36 lexical forms; do not silently claim a
        # raw-file digest match for a DAG CID or a path.
        if not re.fullmatch(r"Qm[1-9A-HJ-NP-Za-km-z]{44}|b[a-z2-7]+|z[1-9A-HJ-NP-Za-km-z]+|k[0-9a-z]+", parsed.netloc):
            raise MuseumError("unsupported CID lexical form")
        _cid(parsed.netloc)
    else:
        if not re.fullmatch(r"[A-Za-z0-9_-]{43}", parsed.netloc):
            raise MuseumError("invalid Arweave transaction identifier")
        decoded = base64.urlsafe_b64decode(parsed.netloc + "=")
        if base64.urlsafe_b64encode(decoded).decode().rstrip("=") != parsed.netloc:
            raise MuseumError("noncanonical Arweave transaction identifier")
    if any(part in (".", "..") for part in parsed.path.split("/")) or "%" in parsed.path:
        raise MuseumError("ambiguous content URI path")


def validate(raw, *, expected_media=None):
    """Validate an original RFC8785 manifest; optional media are supplied facts.

    expected_media is the complete list of exact MEDIA_TERM binding objects for
    the requested depicted objects. It confers no chain or recorder authority.
    """
    if type(raw) is not bytes or not 0 < len(raw) <= MAX_BYTES:
        raise MuseumError("IIIF manifest byte limit")
    try:
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=_pairs,
                           parse_constant=lambda _: (_ for _ in ()).throw(MuseumError("invalid number")))
        _walk(value)
        if rfc8785.dumps(value) != raw:
            raise MuseumError("IIIF manifest must be original RFC8785 bytes")
        Draft202012Validator(schema(), format_checker=FormatChecker()).validate(value)
    except (UnicodeError, ValueError, RecursionError) as exc:
        raise MuseumError("invalid canonical archival IIIF manifest") from exc
    except ValidationError as exc:
        raise MuseumError("archival IIIF schema mismatch") from exc
    identifiers = set()
    bindings = {}
    if not urlsplit(value["id"]).hostname:
        raise MuseumError("Manifest HTTP(S) authority required")
    for canvas in value["items"]:
        canvas_bindings = set()
        for node in [canvas, *canvas["items"]]:
            if node["id"] in identifiers:
                raise MuseumError("duplicate Canvas/AnnotationPage identity")
            identifiers.add(node["id"])
        for page in canvas["items"]:
            for annotation in page["items"]:
                if annotation["id"] in identifiers:
                    raise MuseumError("duplicate annotation identity")
                identifiers.add(annotation["id"])
                target = annotation["target"]
                target = target if isinstance(target, str) else target["source"]
                if target.split("#", 1)[0] != canvas["id"]:
                    raise MuseumError("painting target differs from its Canvas")
                bodies = annotation["body"] if isinstance(annotation["body"], list) else [annotation["body"]]
                for body in bodies:
                    for resource in body["items"] if body["type"] == "Choice" else [body]:
                        if any(field in resource and field not in canvas for field in ("width", "height", "duration")):
                            raise MuseumError("painting dimensions require matching Canvas dimensions")
                        _content_uri(resource["id"])
                        if resource["format"] in ("text/html", "application/javascript", "text/javascript", "application/wasm"):
                            raise MuseumError("executable painting resource")
                        binding = resource[MEDIA_TERM]
                        source = binding["source"]
                        for name in ("chainId", "collectionId", "tokenId"):
                            uint(source[name])
                        if source["chainId"] == "0" or source["collectionId"] == "0" or int(source["core"], 16) == 0:
                            raise MuseumError("zero media source identity")
                        if (source["scope"] == "collection") != (source["tokenId"] == "0"):
                            raise MuseumError("media source scope/token mismatch")
                        expected_subject = subject_id(source["scope"], source["chainId"], source["core"],
                            source["collectionId"], token_id=source["tokenId"])
                        if binding["subjectId"] != expected_subject:
                            raise MuseumError("media subject derivation mismatch")
                        for field in ("sourceRecordHash",) if source["kind"] == "MediaManifest" else ("leafHash", "contentRootHash"):
                            if int(source[field], 16) == 0:
                                raise MuseumError("missing native commitment selector")
                        digest = binding["contentHash"]["digest"]
                        length = 128 if binding["contentHash"]["algorithm"] == "sha512" else 64
                        if not re.fullmatch("0x[0-9a-f]{" + str(length) + "}", digest) or int(digest, 16) == 0:
                            raise MuseumError("invalid committed media digest")
                        if int(binding["subjectId"], 16) == 0:
                            raise MuseumError("missing media identity")
                        key = dumps(source)
                        canvas_bindings.add(key)
                        if key in bindings and bindings[key] != binding:
                            raise MuseumError("conflicting committed media binding")
                        bindings[key] = binding
        if len(canvas_bindings) != 1:
            raise MuseumError("one depicted media identity required per Canvas")
    if expected_media is not None:
        if not isinstance(expected_media, list) or len({dumps(x) for x in expected_media}) != len(expected_media):
            raise MuseumError("invalid supplied media set")
        if {dumps(x) for x in expected_media} != {dumps(x) for x in bindings.values()}:
            raise MuseumError("depicted media differs from complete supplied commitments")
    return value


def example():
    h = lambda n: "0x" + format(n, "064x")
    canvas = "https://example.invalid/archival/canvas/1"
    return {"@context": CONTEXT, "id": "https://example.invalid/archival/manifest/1", "type": "Manifest",
        "label": {"en": ["Synthetic archival image"]}, "summary": {"en": ["Supplied commitments; no chain or byte-authenticity claim."]},
        "requiredStatement": {"label": {"en": ["Attribution"]}, "value": {"en": ["Synthetic named artist"]}},
        "rights": "http://rightsstatements.org/vocab/InC/1.0/",
        "items": [{"id": canvas, "type": "Canvas", "width": 1024, "height": 768,
            "items": [{"id": canvas + "/page", "type": "AnnotationPage", "items": [{
                "id": canvas + "/annotation", "type": "Annotation", "motivation": "painting", "target": canvas,
                "body": {"id": "ar://" + base64.urlsafe_b64encode(bytes(range(32))).decode().rstrip("="),
                    "type": "Image", "format": "image/png", "width": 1024, "height": 768,
                    MEDIA_TERM: {"source": {"kind": "token_media", "scope": "token", "chainId": "31337",
                        "core": "0x" + "22" * 20, "collectionId": "1", "tokenId": "41", "leafHash": h(1),
                        "contentRootHash": h(2), "field": "imageHash"},
                        "subjectId": subject_id("token", "31337", "0x" + "22" * 20, "1", token_id="41"),
                        "contentHash": {"algorithm": "sha256", "digest": h(3)}}}}]}]}]}


def outputs():
    return {"schemas/records/" + NAME + ".json": SCHEMA_BYTES,
        "schemas/records/examples/genesis-iiif/archival-manifest.json": dumps(example())}


def main():
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    validate(dumps(example()))
    for name, raw in outputs().items():
        path = ROOT / name
        if args.check:
            if not path.exists() or path.read_bytes() != raw:
                raise SystemExit("stale genesis IIIF document: " + name)
        else:
            path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(raw)
    print("Genesis archival IIIF schema and worked manifest match.")


if __name__ == "__main__":
    main()
