"""Prospective complete LIDO/BagIt definition data and separate worked-file checks.

Existing implementation profiles and exports are retained byte-for-byte. A JSON
Schema check of these definition data is not a check of XML, bag bytes, source
authority, registration, institutional ingest, or full dossier conformance.
"""

import argparse
from hashlib import sha256
from pathlib import Path

import jsonschema

from tools.museum import bagit, ocfl
from tools.museum.canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from tools.museum.lido_model import PinnedLIDO, PROFILE_BYTES as XSD_PROFILE, PROFILE_HASH as XSD_HASH
from tools.museum.work_lido import WorkLidoProjection, verify_work_lido_fixture
from tools.museum.work_lido_context import PROFILE_BYTES as LIDO_IMPLEMENTATION, PROFILE_HASH as LIDO_HASH
from tools.museum.work_lido_source import WORK_SCHEMA_HASH, WORK_PROFILE_HASH


ROOT = Path(__file__).resolve().parents[2]
LIDO = "STREAM_LIDO_PROFILE_V1"
BAGIT = "STREAM_BAGIT_PROFILE_V1"
NAMES = (LIDO, BAGIT)
MAX_PROFILE_BYTES = 262144
MAX_EXAMPLE_FILES = 64
STATUS = "prospective_unregistered"
CLAIMS = {"registered": False, "sourceAuthorityVerified": False,
    "institutionalIngest": False, "fullDossierConformance": False}
QUALIFICATION = (
    "Complete prospective profile-definition data with an explicitly limited implementation witness. "
    "Definition validation does not validate XML or bag bytes. Worked-file verification is a separate "
    "offline operation over exact retained files; neither operation establishes source authority, "
    "schema registration, institutional ingest or full dossier conformance."
)
LIDO_FILES = ("catalog.json", "context.json", "coverage.json", "profile.json",
    "provenance.json", "record.xml", "report.json", "sidecar.json", "work.json")
OCFL_CREATED = "2026-09-15T00:00:00Z"
OCFL_MESSAGE = "Retained synthetic worked bag; no institutional ingest claim"


def _rule(identifier, source, target, meaning, *, implemented=True):
    return {"id": identifier, "source": source, "target": target,
        "requirement": meaning, "implementation": "supported" if implemented else "not_implemented"}


def lido_rules():
    """Complete WORK field/branch crosswalk; array indices retain source order."""
    return [
        _rule("title", ["work:/title"], ["lido:objectIdentificationWrap/lido:titleWrap/lido:titleSet[@lido:type='work-title']/lido:appellationValue"], "Emit exact full-form title, never a token display-name substitute."),
        _rule("alternate-titles", ["work:/alternateTitles/*"], ["lido:titleSet[@lido:type='alternate-title']/lido:appellationValue"], "Emit every ordered occurrence, including duplicate title values."),
        _rule("named-creator", ["work:/creator/kind", "work:/creator/name"], ["lido:eventActor/lido:actorInRole/lido:actor/lido:nameActorSet/lido:appellationValue"], "Named-creator branch emits original name as a claim, not verified personhood."),
        _rule("artist-creator", ["work:/creator/artistId", "context:/statements/*/value"], ["lido:actor/lido:actorID[@lido:type='STREAM_ARTIST_ID']", "lido:actor/lido:nameActorSet/lido:appellationValue"], "Artist branch retains stable artistId and requires independently declared artistName bound to that ID and exact association; no address/name-to-person inference."),
        _rule("creator-association", ["work:/creator/association/bindingHash", "work:/creator/association/bindingGeneration"], ["sidecar.json", "coverage.json", "provenance.json"], "Retain exact historical association; do not reinterpret it as current authority or flatten it into the creator's name."),
        _rule("creation-date", ["work:/creation/kind", "work:/creation/date"], ["lido:eventDate/lido:displayDate", "lido:eventDate/lido:date/lido:earliestDate", "lido:eventDate/lido:date/lido:latestDate"], "Exact date branch emits the same original Gregorian lexical date in both indexed bounds."),
        _rule("creation-range", ["work:/creation/start", "work:/creation/end"], ["lido:eventDate/lido:displayDate", "lido:eventDate/lido:date/lido:earliestDate", "lido:eventDate/lido:date/lido:latestDate"], "Inclusive range emits exact start/end, with display start + ' / ' + end; never infer a single creation instant."),
        _rule("medium", ["work:/medium"], ["lido:objectMaterialsTechWrap/lido:objectMaterialsTechSet/lido:displayMaterialsTech"], "Preserve exact authored medium statement."),
        _rule("format-kind", ["work:/format/kind"], ["lido:objectDescriptionSet[@lido:type='format-declaration-kind']/lido:descriptiveNoteValue"], "Distinguish nondigital, PRONOM and catalog declarations; no file-format detection or media resource inferred."),
        _rule("format-pronom", ["work:/format/puid", "work:/format/mapping/puid"], ["lido:objectDescriptionSet[@lido:type='PRONOM-PUID']/lido:descriptiveNoteValue"], "Emit the exact directly declared or catalog-selected PRONOM PUID."),
        _rule("format-specification", ["work:/format/mapping/specification/uri", "work:/format/mapping/specification/hash/digest"], ["lido:objectDescriptionSet[@lido:type='format-specification-uri']/lido:descriptiveNoteValue", "lido:objectDescriptionSet[@lido:type='format-specification-keccak256-RAW_BYTES']/lido:descriptiveNoteValue"], "Emit exact selected full-specification locator and digest; no retrieval, media type or fixity event inferred."),
        _rule("format-witness", ["work:/format/formatId", "work:/format/catalog/*", "work:/format/mapping/kind", "work:/format/mapping/specification/hash/algorithm", "work:/format/mapping/specification/hash/canonicalizationId", "catalog:*"], ["sidecar.json", "coverage.json", "provenance.json"], "Retain complete catalog and exact selected mapping, schema/profile pins and unselected entries; verify equality before export, never infer catalog authorship or registration."),
        _rule("dimensionless", ["work:/measurements/kind"], ["lido:objectMeasurementsSet/lido:displayObjectMeasurements"], "dimensionless_generative is an explicit authored value, not omitted measurement data. The measured branch discriminator remains in source evidence."),
        _rule("pixels", ["work:/measurements/pixels/width", "work:/measurements/pixels/height", "work:/measurements/pixels/unit"], ["lido:objectMeasurements/lido:measurementsSet/lido:measurementType", "lido:measurementUnit", "lido:measurementValue"], "Emit exact decimal-string pixel width and height with their declared unit, without float conversion."),
        _rule("aspect-ratio", ["work:/measurements/aspectRatio/numerator", "work:/measurements/aspectRatio/denominator"], ["lido:objectMeasurementsSet/lido:displayObjectMeasurements"], "Display 'aspect ratio: numerator/denominator' preserving unreduced exact integers; do not force a decimal-index value."),
        _rule("duration", ["work:/measurements/durationSeconds/numerator", "work:/measurements/durationSeconds/denominator"], ["lido:objectMeasurementsSet/lido:displayObjectMeasurements"], "Display 'duration in seconds: numerator/denominator' with no rounding or fraction reduction."),
        _rule("edition-unique", ["work:/edition/kind"], ["lido:displayStateEditionWrap/lido:displayEdition"], "Unique branch emits explicit 'unique'; other branch discriminators remain in exact source evidence."),
        _rule("edition-serial", ["work:/edition/number", "work:/edition/total"], ["lido:displayStateEditionWrap/lido:displayEdition"], "Emit exact decimal number + ' / ' + total, preserving uint256 precision."),
        _rule("edition-open", ["work:/edition/statement"], ["lido:displayStateEditionWrap/lido:displayEdition"], "Open-series branch emits original statement without manufacturing a total."),
        _rule("credit-line", ["work:/creditLine"], ["lido:administrativeMetadata/lido:rightsWorkWrap/lido:rightsWorkSet/lido:creditLine"], "Preserve credit text without inferring a rights license or ownership."),
        _rule("inscription", ["work:/inscription"], ["lido:inscriptionsWrap/lido:inscriptions/lido:inscriptionDescription/lido:descriptiveNoteValue"], "Preserve optional inscription/signature description; this is not a signature verification."),
        _rule("language-variants", ["work:/languageVariants/*/field", "work:/languageVariants/*/alternateTitleIndex", "work:/languageVariants/*/language", "work:/languageVariants/*/value"], ["mapped title/creator/medium/credit/inscription elements", "@xml:lang", "sidecar.json"], "Emit each variant at its exact field or alternate-title occurrence with its own unchanged language tag. Preserve targeting controls; no normalization or inferred language."),
        _rule("creator-authority-references", ["work:/authorityReferences/*/authority", "work:/authorityReferences/*/identifier", "work:/authorityReferences/*/role"], ["lido:actor/lido:actorID[@lido:type]"], "Creator ULAN, VIAF and Wikidata identifiers remain typed claims. The role selects this mapping and never proves identity reconciliation."),
        _rule("medium-technique-authority-references", ["work:/authorityReferences/*/authority", "work:/authorityReferences/*/identifier", "work:/authorityReferences/*/role"], ["lido:materialsTech/lido:termMaterialsTech[@lido:type]/lido:conceptID[@lido:type]"], "Getty AAT medium/technique entries retain exact identifier, authority and role without treating the controlled term as separately authenticated."),
        _rule("description-absence", ["work:/form", "work:/absence/reason", "work:/absence/date"], ["lido:titleSet[@lido:type='catalogue-work-label']/lido:appellationValue", "lido:objectDescriptionSet[@lido:type='description-absence-reason']", "lido:objectDescriptionSet[@lido:type='description-absence-date']"], "Explicit absence emits XML only with separate work label, object type, document language and publisher; otherwise account for absence with no XML. Never invent missing creator, dates, medium, edition or credit."),
        _rule("source-control", ["work:/version", "work:/form", "work:/profileHash", "work:/subjectId", "work:/predecessor"], ["sidecar.json", "coverage.json", "provenance.json"], "Retain exact source, subject, interpretation and supersession controls; they are not direct descriptive assertions."),
        _rule("context-record-work", ["context:/recordId", "context:/workId"], ["lido:lidoRecID", "lido:objectPublishedID", "lido:recordWrap/lido:recordID"], "Keep work identity, record identity and declaration identity distinct; supplied URI validity does not authenticate them."),
        _rule("context-language-type", ["context:/statements/*"], ["lido:descriptiveMetadata/@xml:lang", "lido:administrativeMetadata/@xml:lang", "lido:objectWorkType/lido:term"], "Exactly declared documentLanguage and objectWorkType are required; context text keeps its own language, and controlled labels use en."),
        _rule("context-publisher", ["context:/statements/*"], ["lido:recordSource/lido:legalBodyID", "lido:recordSource/lido:legalBodyName/lido:appellationValue"], "The separate exportPublisher declaration identifies the export publisher, not an inferred creator, owner or institution with verified standing."),
        _rule("context-provenance", ["context:/sourceDeclaration/*", "context:/mode", "context:/version", "context:/subjectId", "context:/workPayloadHash", "context:/statements/*"], ["lido:recordInfoSet[@lido:type='public-fixture-source-declaration']/lido:recordInfoID", "sidecar.json", "coverage.json", "provenance.json"], "Retain every statement's declared author and exact context hash; reject conflicting/inactive statements. A public fixture declaration is not authenticated record authority."),
        _rule("complete-accounting", ["work:*", "catalog:*", "context:*"], ["sidecar.json", "coverage.json", "provenance.json"], "Every present node and applicable absent optional has a disposition and exact canonical source bytes. Final indexed XPath targets must resolve to original values; all source bytes survive separately."),
        _rule("xml-validation", ["complete mapped output"], ["LIDO 1.1 original XSD closure"], "Validate exact UTF-8 XML1.0 with pinned original offline dependencies; illegal XML characters reject rather than strip or replace. Full round trip preserves original source and distinction between absence and an absent field."),
    ]


def bagit_rules():
    return [
        _rule("declaration", ["BagIt version and encoding"], ["bagit.txt"], "RFC8493 BagIt1.0; exact UTF-8 tag declaration, LF termination."),
        _rule("payload-sha256", ["every payload file including fetch declarations"], ["manifest-sha256.txt"], "SHA-256 lowercase hex over original bytes; complete path inventory under data/."),
        _rule("payload-keccak", ["same complete payload inventory"], ["manifest-keccak256.txt"], "Additional Stream Keccak-256 manifest over the same exact bytes and paths."),
        _rule("tag-sha256", ["every tag file except the tag manifest itself"], ["tagmanifest-sha256.txt"], "SHA-256 over exact tag bytes, including both payload manifests and optional fetch.txt; no self-hash cycle."),
        _rule("external-identifier", ["canonical qualified citation"], ["bag-info.txt:External-Identifier", "OCFL inventory.id"], "Use exact canonical work citation with typed fin/snap/chain state qualifier; retain object identity across later versions."),
        _rule("bagging-date", ["packaging date"], ["bag-info.txt:Bagging-Date"], "Exact Gregorian YYYY-MM-DD; not a source-publication or acquisition timestamp."),
        _rule("payload-oxum", ["every payload size and occurrence"], ["bag-info.txt:Payload-Oxum"], "Decimal total bytes + '.' + file count, including declared fetch payloads."),
        _rule("schema-identity", ["bundle schema ID and exact bytes hash"], ["bag-info.txt:Stream-Schema-Id", "bag-info.txt:Stream-Schema-Hash", "stream-manifest.json:input.schema"], "Embed the exact selected schema and record its ID, path and hash; a schema ID alone does not prove registration."),
        _rule("bundle-manifest", ["dossier/export manifest and its hash"], ["data/", "stream-manifest.json:input.bundleManifest", "OCFL version content/state"], "Embed exact dossier/export manifest; canonical RFC8785 stream-manifest commits its hash and path."),
        _rule("record-chain-heads", ["all required record-chain heads at packaging state"], ["stream-manifest.json:input.recordChainHeads"], "Retain every declared scope/head in canonical order; complete source inventory and authority require independent authenticated evidence."),
        _rule("tool-reference", ["packaging tool name/version/source hash"], ["stream-manifest.json:input.tool"], "Retain tool reference; a declared hash does not by itself prove preservation or reproducible execution."),
        _rule("render-critical", ["all OBJECT_DOSSIER_V1 render-critical bytes"], ["data/", "payload manifests"], "All authoritative render-critical occurrences must be embedded. Fetch-only packaging is forbidden even if mirror evidence exists."),
        _rule("fetch", ["optional non-render-critical payloads"], ["fetch.txt", "payload manifests", "stream-manifest.json:input.payloads"], "Only content-addressed ipfs:// or ar:// with exact byte size, SHA-256/Keccak commitments and two distinct archive-family evidence references; no network fetch or archival authority inferred."),
        _rule("self-containment", ["whether any fetch entry exists"], ["bag-info.txt:Stream-Self-Containment", "stream-manifest.json:selfContainment", "acquisition packet item16"], "self_contained exactly when all referenced payloads are embedded; otherwise fetch_dependent. Bag transport does not itself build the acquisition packet."),
        _rule("profile-reference", ["unchanged existing implementation profile"], ["stream-bagit-profile.json", "stream-manifest.json:profileHash"], "Retain original implementation-profile bytes/hash. They are distinct from this prospective canonical JSON Schema and complete profile-definition data."),
        _rule("ocfl-version", ["one complete bag and each superseding export"], ["OCFL1.1 object", "immutable versions", "version content and inventory digests"], "One stable object ID; each successor retains complete exact bag payload and tags in a new immutable version with explicit predecessor and increasing creation time. Incomplete fetch bags must be hydrated first."),
        _rule("ocfl-heads-supplement", ["record-chain heads"], ["OCFL inventory fixity supplement"], "CMC-PACKAGING4 requires this mapping. Existing OCFL code preserves heads inside retained stream-manifest content but has only SHA-512 byte fixity; that is not a separate heads supplement.", implemented=False),
        _rule("state-export-token-data", ["optional attested STATE_EXPORT tokenData payloads"], ["ordinary data/ files and payload manifests"], "When present verify bytes against token-data leaf hashes. Omission of this optional convenience is not a fetch dependency. Transport alone does not authenticate export leaves."),
        _rule("expanded-semantics", ["required semantic manifest/resources/assertions/provenance/interpretation documents/authority snapshots"], ["embedded semantic packages under data/"], "Expanded Museum packages preserve required exact components, acyclic commitments and package-wide public disclosure. The base worked bag does not demonstrate this expanded scope."),
        _rule("institutional-gate", ["named repository ingest and practitioner review"], ["separately hash-committed institutional evidence"], "Worked example validation is necessary but insufficient; no schema, XML, bag or OCFL transport check substitutes for the institutional gate.", implemented=False),
    ]


def _closed(properties):
    return {"type": "object", "properties": properties, "required": list(properties), "additionalProperties": False}


def _fixed(name):
    if name not in NAMES:
        raise MuseumError("unknown genesis packaging definition")
    lido = name == LIDO
    return {"name": name, "version": "1", "kind": "lido_crosswalk_profile" if lido else "bagit_packaging_profile",
        "status": STATUS, "qualification": QUALIFICATION, "claims": CLAIMS,
        "normativeHomes": ["CMC-TOMBSTONE:4", "CMC-PREMIS-PROFILE:2"] if lido else ["CMC-PACKAGING:1-6", "MSM-EXPORT"],
        "source": {"name": "STREAM_WORK_DESCRIPTION_V1", "schemaHash": WORK_SCHEMA_HASH, "interpretationHash": WORK_PROFILE_HASH}
            if lido else {"bundleKinds": ["OBJECT_DOSSIER_V1", "STATE_EXPORT"], "serialization": "RFC8493 BagIt1.0"},
        "target": {"format": "LIDO1.1", **loads(LIDO_IMPLEMENTATION)["schema"]} if lido else
            {"format": "BagIt1.0", "repositoryMapping": "OCFL1.1", "payloadDigests": ["sha256", "keccak256"], "tagDigest": "sha256"},
        "elementRules": lido_rules() if lido else bagit_rules(),
        "implementation": {"profilePath": "schemas/museum/work-lido/profile.json" if lido else "schemas/museum/bagit/profile.json",
            "profileHash": LIDO_HASH if lido else bagit.PROFILE_HASH,
            "profileBytesUnchanged": True,
            "scope": "Complete typed WORK mapping with synthetic source/context declarations" if lido else
                "Exact bounded transport over explicitly admitted inputs; no complete-source-inventory inference",
            "remaining": loads(LIDO_IMPLEMENTATION)["remaining"] if lido else
                ["authenticated complete dossier/export sources", "OCFL record-chain-head fixity supplement",
                 "expanded semantic-package admission", "institutional ingest and practitioner review", "registration"]}}


def _worked_schema(name):
    h = {"type": "string", "pattern": r"^0x[0-9a-f]{64}(?![\s\S])", "not": {"const": bagit.ZERO}}
    row = _closed({"path": {"type": "string", "minLength": 1, "maxLength": 1024},
        "bytes": {"type": "string", "pattern": r"^(?:0|[1-9][0-9]{0,19})(?![\s\S])"},
        "sha256": h, "keccak256": h})
    fields = {"sourceDirectory": {"const": "schemas/museum/work-lido/complete" if name == LIDO else "schemas/museum/bagit/worked-bag"},
        "provenance": {"const": "synthetic_fixture"}, "commitment": h,
        "files": {"type": "array", "minItems": 1, "maxItems": MAX_EXAMPLE_FILES, "items": row}}
    if name == BAGIT:
        fields["ocfl"] = _closed({"created": {"const": OCFL_CREATED}, "message": {"const": OCFL_MESSAGE}, "inventoryHash": h})
    return _closed(fields)


def schema(name):
    """The schema validates complete definition data, never XML or a bag envelope."""
    return {"$schema": "https://json-schema.org/draft/2020-12/schema", "title": name,
        "description": QUALIFICATION,
        **_closed({**{key: {"const": value} for key, value in _fixed(name).items()},
            "workedExample": _worked_schema(name)})}


def schemas():
    return {name: schema(name) for name in NAMES}


SCHEMA_BYTES = {name: dumps(value) for name, value in schemas().items()}
SCHEMA_HASHES = {name: keccak256(raw) for name, raw in SCHEMA_BYTES.items()}


def validate_profile(name, raw):
    """Validate canonical complete definition data only; return no runtime success claim."""
    if type(raw) is not bytes or not 0 < len(raw) <= MAX_PROFILE_BYTES:
        raise MuseumError("genesis packaging profile byte bound")
    value = loads(raw, maximum=MAX_PROFILE_BYTES, canonical=True)
    try:
        jsonschema.Draft202012Validator(schema(name)).validate(value)
    except jsonschema.ValidationError as exc:
        raise MuseumError("genesis packaging profile definition differs") from exc
    rows = value["workedExample"]["files"]
    paths = [row["path"] for row in rows]
    bagit._paths(paths)
    if paths != sorted(paths) or len(set(paths)) != len(paths):
        raise MuseumError("worked example file inventory order or duplicate")
    if sum(uint(row["bytes"], 64) for row in rows) > bagit.MAX_BYTES:
        raise MuseumError("worked example aggregate byte bound")
    return value


def _check_files(value, files):
    if type(files) is not dict or len(files) > MAX_EXAMPLE_FILES:
        raise MuseumError("worked example file mapping required")
    bagit._paths(files)
    rows = value["workedExample"]["files"]
    if set(files) != {row["path"] for row in rows}:
        raise MuseumError("worked example exact file inventory differs")
    for row in rows:
        raw = files[row["path"]]
        if (type(raw) is not bytes or len(raw) != uint(row["bytes"], 64)
                or "0x" + sha256(raw).hexdigest() != row["sha256"] or keccak256(raw) != row["keccak256"]):
            raise MuseumError("worked example original file bytes differ")


def verify_worked_example(name, raw, files, *, expected_hash):
    """Verify exact admitted fixture bytes separately from profile-definition shape."""
    if type(raw) is not bytes or not 0 < len(raw) <= MAX_PROFILE_BYTES:
        raise MuseumError("genesis packaging profile byte bound")
    if not any(hex_bytes(expected_hash, 32)) or keccak256(raw) != expected_hash:
        raise MuseumError("external worked profile hash differs")
    value = validate_profile(name, raw)
    _check_files(value, files)
    worked = value["workedExample"]
    if name == LIDO:
        if set(files) != set(LIDO_FILES) or files["profile.json"] != LIDO_IMPLEMENTATION:
            raise MuseumError("complete LIDO worked files/profile differ")
        if keccak256(files["report.json"]) != worked["commitment"]:
            raise MuseumError("worked LIDO report commitment differs")
        model = PinnedLIDO(ROOT / "schemas/museum", XSD_PROFILE, profile_hash=XSD_HASH)
        actual = WorkLidoProjection(files["record.xml"], files["sidecar.json"], files["coverage.json"],
            files["provenance.json"], files["report.json"])
        work = loads(files["work.json"], maximum=8192)
        report = verify_work_lido_fixture(actual, files["work.json"], files["context.json"],
            expected_subject_id=work["subjectId"], context_hash=keccak256(files["context.json"]),
            profile_bytes=LIDO_IMPLEMENTATION, profile_hash=LIDO_HASH, lido_schema=model,
            catalog_bytes=files["catalog.json"])
        if report["sourceForm"] != "full" or report["outcome"] != "lido_xml":
            raise MuseumError("worked LIDO example must be complete tombstone XML")
        checks = ["exact_original_files", "complete_WORK_and_context_replay", "original_offline_LIDO_XSD",
            "exact_XML_sidecar_coverage_provenance_and_report"]
    else:
        bag = bagit.verify_bag_files(files, worked["commitment"])
        b = loads(bag.manifest, maximum=bagit.MAX_MANIFEST, canonical=True)
        if b["input"]["sourceMode"] != "synthetic_fixture" or b["selfContainment"] != "self_contained":
            raise MuseumError("worked bag must remain a self-contained synthetic fixture")
        version = ocfl.build_version(bag, created=worked["ocfl"]["created"], message=worked["ocfl"]["message"])
        if version.inventory_hash != worked["ocfl"]["inventoryHash"]:
            raise MuseumError("worked OCFL inventory differs")
        ocfl.verify_object_files(version.files, version.inventory_hash)
        checks = ["exact_original_files", "BagIt_payload_and_tag_fixity", "complete_bag_OCFL_transport"]
    return {"profileDefinitionHash": keccak256(raw), "schemaHash": SCHEMA_HASHES[name],
        "mode": "verified_synthetic_worked_example", "checks": checks, "claims": dict(CLAIMS),
        "qualification": QUALIFICATION}


def _existing(path, maximum):
    if not path.is_file() or path.stat().st_size > maximum:
        raise MuseumError("retained worked artifact byte bound")
    with path.open("rb") as handle:
        raw = handle.read(maximum + 1)
    if len(raw) > maximum:
        raise MuseumError("retained worked artifact changed beyond bound")
    return raw


def example_files(name):
    """Read only the pre-existing, explicitly named local worked artifacts."""
    if name == LIDO:
        directory = ROOT / "schemas/museum/work-lido/complete"
        files = {filename: _existing(directory / filename, 4194304) for filename in LIDO_FILES if filename != "profile.json"}
        files["profile.json"] = _existing(directory.parent / "profile.json", MAX_PROFILE_BYTES)
        if files["profile.json"] != LIDO_IMPLEMENTATION:
            raise MuseumError("retained LIDO implementation profile changed")
        return files
    if name == BAGIT:
        if _existing(ROOT / "schemas/museum/bagit/profile.json", MAX_PROFILE_BYTES) != bagit.PROFILE_BYTES:
            raise MuseumError("retained BagIt implementation profile changed")
        return bagit.read_tree(ROOT / "schemas/museum/bagit/worked-bag")
    raise MuseumError("unknown genesis packaging definition")


def example(name, files):
    fixed = _fixed(name)
    rows = [{"path": path, "bytes": str(len(raw)), "sha256": "0x" + sha256(raw).hexdigest(),
        "keccak256": keccak256(raw)} for path, raw in sorted(files.items())]
    worked = {"sourceDirectory": "schemas/museum/work-lido/complete" if name == LIDO else "schemas/museum/bagit/worked-bag",
        "provenance": "synthetic_fixture", "files": rows,
        "commitment": keccak256(files["report.json"] if name == LIDO else files["stream-manifest.json"])}
    if name == BAGIT:
        version = ocfl.build_version(bagit.verify_bag_files(files, worked["commitment"]),
            created=OCFL_CREATED, message=OCFL_MESSAGE)
        worked["ocfl"] = {"created": OCFL_CREATED, "message": OCFL_MESSAGE, "inventoryHash": version.inventory_hash}
    return {**fixed, "workedExample": worked}


def outputs():
    result = {f"schemas/records/{name}.json": raw for name, raw in SCHEMA_BYTES.items()}
    for name, short in ((LIDO, "lido"), (BAGIT, "bagit")):
        files = example_files(name)
        raw = dumps(example(name, files))
        verify_worked_example(name, raw, files, expected_hash=keccak256(raw))
        result[f"schemas/records/examples/genesis-packaging/{short}-profile.json"] = raw
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    for relative, raw in outputs().items():
        path = ROOT / relative
        if args.check:
            if not path.is_file() or path.read_bytes() != raw:
                raise SystemExit("genesis packaging generated bytes differ: " + relative)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
    for name, digest in SCHEMA_HASHES.items():
        print(name, digest)


if __name__ == "__main__":
    main()
