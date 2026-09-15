"""Pinned, offline LIDO 1.1 schema validation for a public fixture profile."""

from hashlib import sha256
from pathlib import Path
from urllib.parse import urljoin

from lxml import etree

from .canonical import MuseumError, dumps, keccak256, loads
from .dependencies import OfflineDocuments
from .lido_pins import DOCUMENT_SHA256, INDEX_SHA256, SCHEMA_REFERENCES
from .premis import _xml

NS = "http://www.lido-schema.org"
XML = "http://www.w3.org/XML/1998/namespace"
XS = "http://www.w3.org/2001/XMLSchema"
SCHEMA_URI = "https://lido-schema.org/schema/v1.1/lido-v1.1.xsd"
PREFIX = "urn:6529stream:museum:lido-work:v1:"
FIELDS = {name: PREFIX + name for name in (
    "work-type", "medium", "edition", "credit-line", "creation-event", "event-type", "creator", "creation-display", "document-language")}


def profile_document():
    return {"id": "STREAM_MUSEUM_LIDO_WORK_CORRESPONDENCE_V1", "version": "1",
        "mode": "candidate_unregistered", "sourceFamily": "STREAM_SEMANTIC_ASSERTION_V1",
        "sourceAuthority": "exact selected public fixture issuer, selector and review provenance",
        "originalDependencyIndexSha256": "0x" + INDEX_SHA256,
        "originalSchema": {"uri": SCHEMA_URI, "sha256": "0x" + DOCUMENT_SHA256[SCHEMA_URI]},
        "schemaResolution": {
            "policy": "original bytes; exact ordered include/import closure; no network or filesystem fallback",
            "hashGraph": "flat immutable documents; cyclic schema references recorded and checked separately",
            "xmlNamespace": "original first import is 2001/03/xml.xsd; libxml2 skips the later 2001/xml.xsd namespace imports; both documents remain pinned and checked",
            "upstreamDoctype": "trusted exact 2001/03/xml.xsd retains its original DOCTYPE; DTD loading is disabled"},
        "rules": [{"relation": relation, "field": field,
            "sourceValue": "exact entity reference" if field in ("creation-event", "creator") else "unqualified xsd:string lexical",
            "authority": "selected assertion, never derived from signer identity"} for field, relation in FIELDS.items()],
        "identities": "LIDO record, original source selectors, work, creator, event, digital files and IIIF targets stay distinct",
        "sourceRecordIds": {"prefix": PREFIX + "source-record:",
            "preimage": "Keccak256 of canonical Stream JSON object with selector (complete original snake_case RecordSelector), payloadHash, authorityEvidenceHash (Keccak256 of exact immutable fixture evidence bytes)",
            "meaning": "derived identifier for an exact public source record; not an onchain registration or a work identity",
            "recordSource": "selected locally declared Person/Group corresponding to each original fixture issuer; never inferred to be creator or custodian"},
        "titles": "original selected declaration names and order; original null language remains independently retained",
        "documentLanguage": "mandatory separate selected assertion covering every emitted language-bearing text in both LIDO wrappers; first profile supports explicit und only, never supplies it when absent or overrides separately specified language; original name.language null remains retained; original XSD rejects empty xml:lang",
        "dates": "explicit creation event and date-display statement only; no inferred indexed time bounds",
        "controlledTerms": "event-type creation, role creator and recordType item are explicit finite profile terms; work type/medium/edition/date remain source strings; no external terminology service admission claimed",
        "resources": "same selected IIIF/PREMIS files, original content identifiers, declared MIME, extent, rights and credit",
        "rights": "work, file and metadata rights remain separate; no LIDO-record license inferred from a Manifest license",
        "sourceCoverage": "entire schema-derived prior inventory and original bytes retained",
        "xmlPolicy": "UTF-8 XML1.0, 4MiB, depth64/elements32768; no instance DTD/entity/PI/comment/external resolution",
        "remaining": ["registered WORK_DESCRIPTION/LIDO profile and actual record adapter", "indexed dates and broader work descriptions",
            "additional languages and qualified creator attributions", "actual media/fixity/rights authority", "institutional ingest", "full Museum scope"]}


PROFILE_BYTES = dumps(profile_document())
PROFILE_HASH = keccak256(PROFILE_BYTES)


def schema_references(uri, tree):
    result = []
    for node in tree:
        if isinstance(node.tag, str) and node.tag in {"{" + XS + "}" + k for k in ("include", "import", "redefine")}:
            location = node.get("schemaLocation")
            result.append({"kind": etree.QName(node).localname, "namespace": node.get("namespace"),
                "schemaLocation": location, "resolvedUri": urljoin(uri, location) if location else None})
    return result


class _PinnedResolver(etree.Resolver):
    def __init__(self, documents):
        super().__init__()
        self.documents = documents

    def resolve(self, url, public_id, context):
        if url not in SCHEMA_REFERENCES:
            raise MuseumError("LIDO unpinned schema resolution")
        return self.resolve_string(self.documents.load(url), context, base_url=url)


class PinnedLIDO:
    def __init__(self, root: Path, profile_bytes: bytes, *, profile_hash: str):
        if profile_bytes != PROFILE_BYTES or keccak256(profile_bytes) != profile_hash:
            raise MuseumError("LIDO profile mismatch")
        raw_index = (root / "lido/dependency-index.json").read_bytes()
        if sha256(raw_index).hexdigest() != INDEX_SHA256:
            raise MuseumError("LIDO dependency inventory mismatch")
        index = loads(raw_index, maximum=524288, canonical=True)
        if index["schemaReferences"] != SCHEMA_REFERENCES:
            raise MuseumError("LIDO schema reference inventory mismatch")
        self.documents = OfflineDocuments(root, index)
        if {r["sourceUri"] for r in index["documents"]} != set(DOCUMENT_SHA256):
            raise MuseumError("LIDO dependency closure mismatch")
        parser = etree.XMLParser(resolve_entities=False, load_dtd=False, no_network=True)
        parser.resolvers.add(_PinnedResolver(self.documents))
        trees = {}
        for uri, digest in DOCUMENT_SHA256.items():
            raw = self.documents.load(uri)
            if sha256(raw).hexdigest() != digest:
                raise MuseumError("LIDO original dependency mismatch")
            if uri in SCHEMA_REFERENCES:
                tree = etree.fromstring(raw, parser, base_url=uri)
                if tree.tag != "{" + XS + "}schema" or schema_references(uri, tree) != SCHEMA_REFERENCES[uri]:
                    raise MuseumError("LIDO original schema references mismatch")
                trees[uri] = tree
        if any(ref["resolvedUri"] not in trees for refs in SCHEMA_REFERENCES.values() for ref in refs):
            raise MuseumError("LIDO unresolved original schema reference")
        self._schema = etree.XMLSchema(trees[SCHEMA_URI])
        self.schema_warnings = tuple(entry.message for entry in self._schema.error_log)

    def validate(self, raw):
        root = _xml(raw)
        if root.tag != "{" + NS + "}lido":
            raise MuseumError("LIDO single-record root required")
        if not self._schema.validate(root):
            raise MuseumError("LIDO original XSD validation failed")
        return root


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2] / "schemas/museum"
    path = root / "lido/profile.json"
    if args.check:
        if path.read_bytes() != PROFILE_BYTES:
            raise MuseumError("LIDO generated profile differs")
    else:
        path.write_bytes(PROFILE_BYTES)
    model = PinnedLIDO(root, PROFILE_BYTES, profile_hash=PROFILE_HASH)
    print("LIDO profile", PROFILE_HASH, "original schema closure validated; duplicate-namespace warnings", len(model.schema_warnings))


if __name__ == "__main__":
    main()
