"""Closed 29-name CMC genesis inventory and prospective ordered publication inputs.

No RPC, signing or mutation of existing definitions. Schema/example validation is
not protocol, authority, broad exporter or institutional conformance evidence.
"""
import argparse
from dataclasses import dataclass
from hashlib import sha256
from pathlib import Path
import re

from jsonschema import Draft202012Validator, FormatChecker, ValidationError

from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .independent_wire import RAW_DEFINITION
from .publication import PublicationPlan, ZERO

ROOT = Path(__file__).resolve().parents[2]
RAW = schema_id("RAW_BYTES")
JCS = schema_id("RFC8785_JCS")
BASE = "schemas/museum/genesis/"
GENERIC_SCOPE = "Local JSON Schema shape; source authority, chain joins and full family conformance require the named typed interpreter and authenticated source."


@dataclass(frozen=True)
class Entry:
    name: str
    path: str
    interpreter: str
    examples: tuple[str, ...]
    canonicalization: str = JCS
    scope: str = GENERIC_SCOPE
    related: tuple[str, ...] = ()


def museum(name, directory, interpreter, example):
    return Entry("STREAM_" + name + "_V1", "schemas/museum/" + directory + "/STREAM_" + name + "_V1.json",
                 "tools/museum/" + interpreter + ".py", (example,))


def record(name, interpreter, example, *, canonicalization=RAW, scope=GENERIC_SCOPE, related=()):
    return Entry("STREAM_" + name, "schemas/records/STREAM_" + name + ".json",
                 "tools/metadata/" + interpreter + ".py", (example,), canonicalization, scope, related)


EX = BASE + "examples/"
RE = "schemas/records/examples/"
ENTRIES = (
    museum("ACCESSION", "institutional", "institutional", EX + "accession.json"),
    museum("CONDITION_REPORT", "condition", "condition", EX + "condition.json"),
    museum("EXHIBITION", "exhibition", "exhibitions", EX + "exhibition.json"),
    museum("LOAN", "loan", "loans", "test/fixtures/metadata/current-owner-museum/loan-template.json"),
    museum("DEACCESSION", "institutional", "institutional", EX + "deaccession.json"),
    museum("CITATION_RECORD", "institutional", "institutional", EX + "citation.json"),
    museum("VALUATION", "valuation", "valuations", "test/fixtures/metadata/current-owner-museum/valuation.json"),
    record("STEWARD_DESIGNATION_V1", "owner_notice_profile", RE + "owner-notice/steward-institution.json"),
    record("RECOVERY_RESPONSE_V1", "owner_notice_profile", RE + "owner-notice/recovery-acknowledged.json"),
    museum("REDEMPTION_CLAIM", "institutional", "institutional", EX + "redemption_claim.json"),
    record("ARTIST_INTENT_V1", "conservation_profile", RE + "conservation/intent-present.json"),
    record("ARTIST_INTENT_WAIVER_V1", "conservation_profile", RE + "conservation/intent-waiver.json"),
    record("ARTIST_INTERVIEW_V1", "conservation_profile", RE + "conservation/interview-vmq.json"),
    record("MASTER_WAIVER_V1", "genesis_preservation_profile", RE + "genesis-preservation/master-waiver.json", canonicalization=JCS),
    record("IDENTITY_NOTARIZATION_V1", "identity_notarization_profile", RE + "identity-notarization/notarization.json"),
    record("OBJECT_DOSSIER_V1", "genesis_dossier_profile", RE + "genesis-dossier/object-dossier.json", canonicalization=JCS,
           scope="Broad manifest structural and internal joins only; chain regeneration, original bytes, complete source capture and institutional acceptance are separate.",
           related=("schemas/museum/object-dossier/assembly-schema.json",)),
    record("ACQUISITION_PACKET_V1", "genesis_dossier_profile", RE + "genesis-dossier/acquisition-packet.json", canonicalization=JCS),
    record("RIGHTS_V1", "rights_profile", "test/fixtures/metadata/rights-complete-v1.json",
           scope="Definition generator and generic JSON Schema shape here; cross-field/context interpretation lives in the separately identified Solidity sources and is not executed by this catalog."),
    record("PREMIS_V3_PROFILE", "genesis_premis_profile", RE + "genesis-premis/premis-v3-profile.json", canonicalization=JCS,
           scope="Complete profile-definition field/vocabulary crosswalk checks; broad PREMIS emission and institutional round-trip acceptance remain separate.",
           related=("schemas/museum/premis/profile.json", "schemas/museum/premis-fixity/profile.json")),
    record("REFERENCE_RENDER_V1", "genesis_preservation_profile", RE + "genesis-preservation/reference-render.json", canonicalization=JCS,
           related=("schemas/records/STREAM_NATIVE_REFERENCE_RENDER_V1.json",
                    "schemas/records/STREAM_NATIVE_REFERENCE_RENDER_JSON_PROFILE_V1.json")),
    record("METRIC_SSIM_V1", "genesis_preservation_profile", RE + "genesis-preservation/metric-ssim.json", canonicalization=JCS),
    record("IIIF_P3_MIN_V1", "genesis_iiif_profile", RE + "genesis-iiif/archival-manifest.json", canonicalization=JCS,
           scope="Archival core and supplied depicted-media joins; no retrieval, byte fixity, service availability, viewer or general extension-conformance claim.",
           related=("schemas/museum/iiif/profile.json",)),
    record("WORK_DESCRIPTION_V1", "work_profile", "test/fixtures/metadata/work-complete-v1.json"),
    Entry("STREAM_MUSEUM_SEMANTIC_PROFILE_V1", "schemas/museum/STREAM_MUSEUM_SEMANTIC_PROFILE_V1.json", "tools/museum/account_profile.py", (EX + "semantic-profile.json",)),
    Entry("STREAM_SEMANTIC_ASSERTION_V1", "schemas/museum/STREAM_SEMANTIC_ASSERTION_V1.json", "tools/museum/schema_inventory.py", (EX + "semantic-assertion.json",)),
    Entry("STREAM_SEMANTIC_EXPORT_V1", "schemas/museum/STREAM_SEMANTIC_EXPORT_V1.json", "tools/museum/validation.py", (EX + "semantic-export.json",), scope="Original V1 shape example is explicitly incomplete/not_evaluated; later exporter versions retain distinct names and meanings."),
    record("LIDO_PROFILE_V1", "genesis_packaging_profile", RE + "genesis-packaging/lido-profile.json", canonicalization=JCS,
           scope="Broad profile-definition crosswalk and separately replayed worked export; institutional acceptance remains separate.",
           related=("schemas/museum/lido/profile.json", "schemas/museum/work-lido/profile.json")),
    record("BAGIT_PROFILE_V1", "genesis_packaging_profile", RE + "genesis-packaging/bagit-profile.json", canonicalization=JCS,
           scope="Complete packaging definition; worked bag transport is separate. OCFL direct chain-head fixity supplement remains an explicit implementation gap.",
           related=("schemas/museum/bagit/profile.json",)),
    record("COLLECTION_IDENTITY_V1", "collection_identity_profile", RE + "collection-identity/artist-bound.json", canonicalization=JCS,
           scope="Five-string uint256 identity shape and exact supplied Core/AA context join. Current renderer emission remains a separate integration gap."),
)
NAMES = tuple(e.name for e in ENTRIES)


def normative_names(root=ROOT):
    text = (root / "docs/collection-metadata-contract.md").read_text(encoding="utf-8")
    start = text.index("| `STREAM_ACCESSION_V1`")
    end = text.index("| `STREAM_COLLECTION_IDENTITY_V1`", start)
    return tuple(re.findall(r"\| `(STREAM_[A-Z0-9_]+)`", text[start:text.index("\n", end)]))


def commitment(root, path):
    raw = (root / path).read_bytes()
    return {"path": path, "byteLength": str(len(raw)), "keccak256": keccak256(raw),
            "sha256": "0x" + sha256(raw).hexdigest()}


def _local_references(value):
    if isinstance(value, dict):
        for key, child in value.items():
            if key in ("$ref", "$dynamicRef") and (not isinstance(child, str) or not child.startswith("#")):
                raise MuseumError("genesis schemas must not resolve external references")
            _local_references(child)
    elif isinstance(value, list):
        for child in value:
            _local_references(child)


def expected_schema_bytes(entry):
    """Join the document to the actual interpreter's closed definition bytes."""
    from tools.metadata import (collection_identity_profile, conservation_profile,
        genesis_iiif_profile, genesis_packaging_profile, genesis_premis_profile,
        genesis_preservation_profile, identity_notarization_profile, owner_notice_profile,
        rights_profile, work_profile)
    from . import condition, exhibitions, institutional, loans, schemas, valuations
    name = entry.name
    fixed = {condition.NAME: condition.SCHEMA_BYTES, exhibitions.NAME: exhibitions.SCHEMA_BYTES,
        loans.NAME: loans.SCHEMA_BYTES, valuations.NAME: valuations.SCHEMA_BYTES,
        "STREAM_IDENTITY_NOTARIZATION_V1": identity_notarization_profile.SCHEMA_BYTES,
        "STREAM_COLLECTION_IDENTITY_V1": dumps(collection_identity_profile.schema()),
        "STREAM_RIGHTS_V1": dumps(rights_profile.schema()),
        "STREAM_WORK_DESCRIPTION_V1": dumps(work_profile.schema()),
        "STREAM_IIIF_P3_MIN_V1": genesis_iiif_profile.SCHEMA_BYTES,
        "STREAM_PREMIS_V3_PROFILE": genesis_premis_profile.SCHEMA_BYTES}
    fixed.update({institutional.NAMES[k]: raw for k, raw in institutional.SCHEMAS.items()})
    fixed.update({n: dumps(value) for n, value in schemas.schemas().items()})
    fixed.update(genesis_preservation_profile.SCHEMA_BYTES)
    fixed.update(genesis_packaging_profile.SCHEMA_BYTES)
    for n in ("STREAM_STEWARD_DESIGNATION_V1", "STREAM_RECOVERY_RESPONSE_V1"):
        fixed[n] = dumps(owner_notice_profile.schema(n))
    for n in ("STREAM_ARTIST_INTENT_V1", "STREAM_ARTIST_INTENT_WAIVER_V1", "STREAM_ARTIST_INTERVIEW_V1"):
        fixed[n] = dumps(conservation_profile.schema(n))
    if name in ("STREAM_OBJECT_DOSSIER_V1", "STREAM_ACQUISITION_PACKET_V1"):
        from tools.metadata.genesis_dossier_profile import documents
        return documents()[name]
    return fixed[name]


def validate_example(entry, schema, raw):
    """Always shape-check; named semantic interpreters are separately exercised."""
    if entry.interpreter.endswith("genesis_iiif_profile.py"):
        from tools.metadata.genesis_iiif_profile import validate
        # IIIF permits ordinary I-JSON fractional duration. The Stream record
        # loader deliberately rejects floats and must not narrow that profile.
        value = validate(raw)
    else:
        value = loads(raw, maximum=16 * 1024 * 1024, canonical=True)
    try:
        Draft202012Validator(schema, format_checker=FormatChecker()).validate(value)
    except ValidationError as exc:
        raise MuseumError(entry.name + " example shape failed at " + "/".join(str(x) for x in exc.absolute_path)
                          + " (" + str(exc.validator) + ")") from None
    if entry.interpreter.endswith("genesis_preservation_profile.py"):
        from tools.metadata.genesis_preservation_profile import validate
        validate(entry.name, raw)
    elif entry.interpreter.endswith("collection_identity_profile.py"):
        from tools.metadata.collection_identity_profile import validate_bytes
        validate_bytes(raw, canonical=True)
    elif entry.interpreter.endswith("genesis_iiif_profile.py"):
        pass  # Already checked original IIIF bytes above.
    elif entry.interpreter.endswith("genesis_dossier_profile.py"):
        from tools.metadata.genesis_dossier_profile import validate
        validate(entry.name, raw)
    elif entry.interpreter.endswith("genesis_premis_profile.py"):
        from tools.metadata.genesis_premis_profile import validate
        validate(raw)
    elif entry.interpreter.endswith("genesis_packaging_profile.py"):
        from tools.metadata.genesis_packaging_profile import validate_profile
        validate_profile(entry.name, raw)
    elif entry.interpreter.endswith("institutional.py"):
        from .institutional import validate_payload, NAMES as families
        validate_payload(next(k for k, v in families.items() if v == entry.name), raw)
    elif entry.interpreter.endswith("condition.py"):
        from .condition import admit_payload
        admit_payload(raw, kind="condition")
    elif entry.interpreter.endswith("owner_notice_profile.py"):
        from tools.metadata.owner_notice_profile import validate
        validate(raw, entry.name)
    elif entry.interpreter.endswith("conservation_profile.py"):
        from tools.metadata.conservation_profile import validate
        validate(raw, entry.name)
    elif entry.interpreter.endswith("identity_notarization_profile.py"):
        from tools.metadata.identity_notarization_profile import validate
        validate(raw, artist_id=value["artistId"], operative_identity_record_hash=value["operativeIdentityRecordHash"])
    elif entry.interpreter.endswith("rights_profile.py"):
        # rights_profile owns the canonical definition; the typed Solidity
        # interpreter enforces its cross-field and authenticated context rules.
        # Do not invent a Python semantic validator that the module lacks.
        pass
    elif entry.interpreter.endswith("work_profile.py"):
        from tools.metadata.work_profile import validate_payload
        validate_payload(raw, catalog_bytes=(ROOT / "test/fixtures/metadata/work-catalog-v1.json").read_bytes())
    return value


def support_documents(root=ROOT):
    """Existing required companion declarations, without replacing any bytes."""
    from tools.metadata import (conservation_profile, identity_notarization_profile,
        owner_notice_profile, rights_profile, work_profile)
    expected_profiles = {"RIGHTS": rights_profile.profile(), "WORK_DESCRIPTION": work_profile.profile(),
        "WORK_FORMAT_CATALOG": work_profile.catalog_profile(), "IDENTITY_NOTARIZATION": identity_notarization_profile.profile()}
    for short in ("STEWARD_DESIGNATION", "RECOVERY_RESPONSE"):
        expected_profiles[short] = owner_notice_profile.profile("STREAM_" + short + "_V1")
    for short in ("ARTIST_INTENT", "ARTIST_INTENT_WAIVER", "ARTIST_INTERVIEW", "CONSERVATION_FORMAT_CATALOG"):
        expected_profiles[short] = conservation_profile.profile("STREAM_" + short + "_V1")
    rows = [("RAW_BYTES", "CANONICALIZATION", RAW, BASE + "RAW_BYTES.json", RAW_DEFINITION),
            ("RFC8785_JCS", "CANONICALIZATION", RAW, "schemas/museum/account-profile/RFC8785_JCS.json", None)]
    typed = ("RIGHTS", "WORK_DESCRIPTION", "STEWARD_DESIGNATION", "RECOVERY_RESPONSE",
             "ARTIST_INTENT", "ARTIST_INTENT_WAIVER", "ARTIST_INTERVIEW", "IDENTITY_NOTARIZATION",
             "WORK_FORMAT_CATALOG", "CONSERVATION_FORMAT_CATALOG")
    for short in typed:
        name = "STREAM_" + short + "_JSON_PROFILE_V1"
        rows.append((name, "CATALOG", RAW, "schemas/records/" + name + ".json", dumps(expected_profiles[short])))
    for short in ("WORK_FORMAT_CATALOG", "CONSERVATION_FORMAT_CATALOG"):
        name = "STREAM_" + short + "_V1"
        expected = work_profile.catalog_schema() if short == "WORK_FORMAT_CATALOG" else conservation_profile.schema(name)
        rows.append((name, "SCHEMA", RAW, "schemas/records/" + name + ".json", dumps(expected)))
    # Actual account-profile declarations: the two canonical schema copies are
    # already in ENTRIES and must be byte-identical, never registered twice.
    from .account_profile import AccountProjectionProfile, JCS_BYTES
    if (root / "schemas/museum/account-profile/RFC8785_JCS.json").read_bytes() != JCS_BYTES:
        raise MuseumError("RFC8785 definition differs from actual consumer pin")
    profile = AccountProjectionProfile(root / "schemas/museum")
    kinds = ("SCHEMA", "CANONICALIZATION", "CATALOG", "DEPENDENCY")
    for name, (kind, raw) in sorted(profile.documents.items()):
        if name in NAMES:
            entry = next(e for e in ENTRIES if e.name == name)
            if (root / entry.path).read_bytes() != raw:
                raise MuseumError("same-name schema byte collision: " + name)
        elif name != "RFC8785_JCS":
            rows.append((name, kinds[kind], JCS, "schemas/museum/account-profile/" + name + ".json", raw))
    result = []
    for name, kind, canon, path, expected in rows:
        raw = RAW_DEFINITION if name == "RAW_BYTES" else (root / path).read_bytes()
        if expected is not None and raw != expected:
            raise MuseumError("support definition differs: " + name)
        result.append((name, kind, canon, path, raw))
    return result


def _plan_row(name, kind, canon, path, raw):
    plan = PublicationPlan(name, kind, canon, ZERO, "", raw)
    return {"sourcePath": path, **plan.metadata(), "encoding": "RFC8785_JSON",
            "chunks": [{"index": str(i), "offset": str(i * 8192), "byteLength": str(len(chunk)),
                        "keccak256": keccak256(chunk)} for i, chunk in enumerate(plan.chunks)],
            "dependsOn": [] if name == "RAW_BYTES" else [canon]}


def build(root=ROOT, *, require_complete=False):
    if NAMES != normative_names(root) or len(NAMES) != len(set(NAMES)) or len(NAMES) != 29:
        raise MuseumError("genesis name set/order differs from canonical CMC table")
    catalog, schemas, missing = [], [], []
    for entry in ENTRIES:
        available = (root / entry.path).is_file()
        row = {"name": entry.name, "schemaId": schema_id(entry.name), "sourcePath": entry.path,
               "interpreter": entry.interpreter, "validationScope": entry.scope,
               "interpreterRole": "definition_generator_only" if entry.name == "STREAM_RIGHTS_V1" else "local_definition_and_interpretation",
               "registryCanonicalizationId": entry.canonicalization,
               "registrationEvidence": {"status": "not_observed", "chainId": None, "registry": None, "blockHash": None},
               "relatedDefinitionsNotSubstitutes": [commitment(root, p) for p in entry.related if (root / p).is_file()],
               "examples": [], "definitionStatus": "missing"}
        if entry.name == "STREAM_RIGHTS_V1":
            row["nativeInterpreterSources"] = [commitment(root, path) for path in (
                "smart-contracts/domains/records/StreamRightsRecordJson.sol",
                "smart-contracts/domains/records/StreamRightsRecordReads.sol")]
        if available:
            raw = (root / entry.path).read_bytes()
            schema = loads(raw, maximum=524288, canonical=True)
            if schema.get("$schema") != "https://json-schema.org/draft/2020-12/schema" or schema.get("title") != entry.name:
                raise MuseumError("canonical name must identify its JSON Schema: " + entry.name)
            if "$id" in schema and schema["$id"] != "urn:6529stream:schema:" + entry.name:
                raise MuseumError("conflicting embedded schema identity: " + entry.name)
            if raw != expected_schema_bytes(entry):
                raise MuseumError("schema bytes differ from interpreter definition: " + entry.name)
            _local_references(schema); Draft202012Validator.check_schema(schema)
            if not (root / entry.interpreter).is_file():
                raise MuseumError("missing interpreter: " + entry.name)
            row.update(definitionStatus="canonical_schema_present", definition=commitment(root, entry.path),
                       interpreterSource=commitment(root, entry.interpreter))
            for example_path in entry.examples:
                if not (root / example_path).is_file():
                    missing.append(entry.name + ": example " + example_path); continue
                validate_example(entry, schema, (root / example_path).read_bytes())
                row["examples"].append({**commitment(root, example_path), "provenance": "synthetic_or_supplied_worked_definition",
                    "result": "shape_and_available_local_constraints_pass", "chainAuthority": False, "institutionalAcceptance": False})
            schemas.append(_plan_row(entry.name, "SCHEMA", entry.canonicalization, entry.path, raw))
        else:
            missing.append(entry.name + ": canonical JSON Schema missing")
        catalog.append(row)
    if require_complete and missing:
        raise MuseumError("incomplete canonical genesis source set: " + "; ".join(missing))
    support = [_plan_row(*row) for row in support_documents(root)]
    # RAW then JCS bootstrap, then canonical schemas, then companion definitions.
    ordered = support[:2] + schemas + support[2:]
    ids = [row["documentId"] for row in ordered]
    if len(ids) != len(set(ids)):
        raise MuseumError("same-ID publication collision")
    seen = set()
    for row in ordered:
        if set(row["dependsOn"]) - seen:
            raise MuseumError("canonicalization dependency order")
        seen.add(row["documentId"])
    common = {"version": "1", "mode": "prospective_unregistered", "canonicalNameCount": "29",
        "sourceSetComplete": not missing, "missing": missing,
        "claims": {"registered": False, "deploymentAdmission": False, "fullFamilyConformance": False,
                   "institutionalAcceptance": False, "liveReadiness": False}}
    catalog_doc = {**common, "normativeSource": commitment(root, "docs/collection-metadata-contract.md"),
                   "entries": catalog}
    plan_doc = {**common, "catalogHash": keccak256(dumps(catalog_doc)), "documents": ordered,
        "recipe": {"chunkBytes": "8192", "maximumChunks": "64", "maximumDocumentBytes": "524288",
            "publication": "Publish each exact ordered chunk through the selected StreamContentAddressedStore, then the original SchemaRegistry registrationTransition and class-1 Safe-scheduled Executor registerDocument.",
            "existingId": "Read original document kind, bytes/hash, canonicalization, predecessor and chunks. Reuse only an exact match; a different existing meaning blocks admission and requires an explicitly new version.",
            "readback": "Verify document, documentBytes, total length and every ordered store chunk against this plan at the selected receipt block. Preserve tx/block/registry/Store identities as new evidence.",
            "limits": "Chunking applies to registry documents, not a widening of record payload limits. Synthetic genesis fixture admissions do not prove these canonical definitions were admitted.",
            "observedAdmissions": [], "registrationPerformedByGenerator": False}}
    return {BASE + "catalog.json": dumps(catalog_doc), BASE + "admission-plan.json": dumps(plan_doc),
            BASE + "RAW_BYTES.json": RAW_DEFINITION,
            BASE + "example-index.json": dumps({**common, "examples": [{"schema": row["name"], **ex}
                for row in catalog for ex in row["examples"]]})}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--require-complete", action="store_true")
    args = parser.parse_args()
    try:
        outputs = build(require_complete=args.require_complete)
    except MuseumError as exc:
        raise SystemExit(str(exc)) from None
    for name, raw in outputs.items():
        path = ROOT / name
        if args.check:
            if not path.is_file() or path.read_bytes() != raw:
                raise SystemExit("stale genesis catalog artifact: " + name)
        else:
            path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(raw)
    print("Genesis source inventory and prospective ordered document plan match.")


if __name__ == "__main__":
    main()
