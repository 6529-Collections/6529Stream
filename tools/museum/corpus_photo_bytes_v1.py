"""Synthetic byte-backed photograph supplement through the existing four exporters."""

from dataclasses import replace
from hashlib import sha256
from pathlib import Path
import base64

from lxml import etree

from .canonical import MuseumError, dumps, keccak256, loads
from .corpus_v2 import verify as verify_corpus
from .package import fixture_state_from_bytes
from .package_v2 import build_fixture_package
from .source import FixtureSourceAdapter
from .premis import FIELDS as PREMIS_FIELDS
from .iiif import FIELDS as IIIF_FIELDS
from .iiif_model import DIGEST, SIZE, SOURCE
from .iiif_numbers import target_loads
from .lido_model import FIELDS as LIDO_FIELDS
from .lido_model import NS as LIDO_NS
from .premis import NS as PREMIS_NS


BASE_ROOT = Path(__file__).resolve().parents[2] / "schemas/museum/multiformat/fixture"
INPUTS = ("source-state.json", "selection.json", "plan.json", "premis-plan.json",
          "iiif-plan.json", "lido-plan.json", "pins.json")
BASE_HASH = "0xae4066b47cffb0120fe904402c2a888af69a546eb3ed9b72e3e5f3508e18bc6d"
WIDTH, HEIGHT = 1200, 800
PNG_PATH = Path(__file__).resolve().parents[2] / "schemas/museum/fixtures-v2/synthetic-display-1200x800.png"
PNG_SHA256 = "0954f48e814fad4cebcab9161a134d81b6211511ccafecd4aaf0c83262be8e16"
PNG_BYTES = 3989
PNG_MIME, PNG_PUID = "image/png", "fmt/13"
BODY_RIGHTS = "http://rightsstatements.org/vocab/InC/1.0/"
MANIFEST_RIGHTS = "http://creativecommons.org/licenses/by/4.0/"
PHOTO_ONLY = "synthetic_corpus_photograph_generated_bytes_v1"


def _cid(digest):
    return "ipfs://b" + base64.b32encode(bytes.fromhex("01551220" + digest)).decode("ascii").lower().rstrip("=")


def _rewrite(value, ids):
    if type(value) is str:
        return ids.get(value, value)
    if type(value) is list:
        return [_rewrite(item, ids) for item in value]
    if type(value) is dict:
        return {key: _rewrite(item, ids) for key, item in value.items()}
    return value


def _set_literal(records, subject, relation, value):
    matches = [(document, claim) for document in records for claim in document["assertions"]
               if claim["subject"] == subject and claim["relation"] == relation]
    if len(matches) != 1 or set(matches[0][1]["object"]) != {"literal"}:
        raise MuseumError("synthetic photo expected one exact fixture assertion")
    matches[0][1]["object"]["literal"]["lexicalValue"] = value


def derive(corpus_directory, corpus_hash, base_root=BASE_ROOT, image_path=PNG_PATH):
    """Return source/plan inputs and exact bytes; no writes or network access."""
    corpus_directory, base_root = Path(corpus_directory), Path(base_root)
    verify_corpus(corpus_directory, corpus_hash)
    photo = loads((corpus_directory / "photograph/source/payload.json").read_bytes(),
                  maximum=24576, canonical=True)
    if ([row["role"] for row in photo["resources"]] !=
            ["master", "display_derivative", "reference_print", "reference_print"]
            or any(row["presence"] != "described_only" for row in photo["resources"])):
        raise MuseumError("synthetic photo original resources changed")
    display = photo["resources"][1]
    dims = {row["scope"]: row for row in display["dimensions"]}
    if (set(dims) != {"pixel_width", "pixel_height"} or
            dims["pixel_width"]["value"] != str(WIDTH) or
            dims["pixel_height"]["value"] != str(HEIGHT)):
        raise MuseumError("synthetic PNG and declared display dimensions differ")
    originals = {name: (base_root / name).read_bytes() for name in INPUTS}
    if keccak256(dumps({name: keccak256(raw) for name, raw in originals.items()})) != BASE_HASH:
        raise MuseumError("synthetic four-format base fixture changed")
    state = fixture_state_from_bytes(originals["source-state.json"])
    ids = {"urn:fixture:work": photo["workId"], "urn:fixture:photo": display["id"],
           "urn:fixture:visual": photo["contentId"]}
    image = Path(image_path).read_bytes()
    digest = sha256(image).hexdigest()
    if len(image) != PNG_BYTES or digest != PNG_SHA256:
        raise MuseumError("synthetic display PNG input pin differs")
    parsed = [_rewrite(loads(record.payload, maximum=24576, canonical=True), ids)
              for record in state.records]
    file_id, work_id = display["id"], photo["workId"]
    facts = ((PREMIS_FIELDS["size"], str(len(image))),
             (PREMIS_FIELDS["digest"], digest), (PREMIS_FIELDS["puid"], PNG_PUID),
             (IIIF_FIELDS["mime"], PNG_MIME), (IIIF_FIELDS["content-uri"], _cid(digest)),
             (IIIF_FIELDS["width"], str(WIDTH)), (IIIF_FIELDS["height"], str(HEIGHT)))
    for relation, value in facts:
        _set_literal(parsed, file_id, relation, value)
    _set_literal(parsed, file_id, IIIF_FIELDS["rights"], BODY_RIGHTS)
    _set_literal(parsed, work_id, IIIF_FIELDS["manifest-rights"], MANIFEST_RIGHTS)
    _set_literal(parsed, work_id, LIDO_FIELDS["work-type"], "photograph")
    _set_literal(parsed, work_id, LIDO_FIELDS["medium"], "synthetic PNG display derivative")
    _set_literal(parsed, work_id, LIDO_FIELDS["edition"],
                 "Two reference prints described; edition unverified")
    _set_literal(parsed, "urn:fixture:creation", LIDO_FIELDS["creation-display"],
                 photo["events"][0]["dateExpression"])
    _set_literal(parsed, work_id, IIIF_FIELDS["summary"], photo["creatorStatement"])
    attribution = "Synthetic fixture maker claim; authority unverified"
    _set_literal(parsed, work_id, IIIF_FIELDS["attribution"], attribution)
    _set_literal(parsed, work_id, LIDO_FIELDS["credit-line"], attribution)
    _set_literal(parsed, file_id, IIIF_FIELDS["attribution"],
                 "Synthetic display derivative; media and maker claims unverified")
    names = [entity for document in parsed for entity in document["entities"]]
    work_names = [entity for entity in names if entity["id"] == work_id]
    file_names = [entity for entity in names if entity["id"] == file_id]
    if len(work_names) != 1 or len(file_names) != 1:
        raise MuseumError("synthetic photo entity declarations differ")
    work_names[0]["names"][0]["value"] = photo["title"]
    file_names[0]["names"][0]["value"] = "Synthetic PNG display derivative"
    records = [replace(record, payload=dumps(document), payload_hash=keccak256(dumps(document)))
               for record, document in zip(state.records, parsed)]
    derived = FixtureSourceAdapter(PHOTO_ONLY, tuple(records)).snapshot()
    selection = _rewrite(loads(originals["selection.json"], maximum=1048576), ids)
    selection["sourceStateHash"] = derived.commitment
    selection_raw = dumps(selection)
    plan = _rewrite(loads(originals["plan.json"], maximum=1048576), ids)
    plan["sourceStateHash"] = derived.commitment
    plan["selectionPolicyHash"] = keccak256(selection_raw)
    plan_raw = dumps(plan)
    premis = _rewrite(loads(originals["premis-plan.json"], maximum=1048576), ids)
    premis["sourceStateHash"] = derived.commitment
    premis["linkedArtPlanHash"] = keccak256(plan_raw)
    premis["objects"] = [file_id]
    premis_raw = dumps(premis)
    iiif = _rewrite(loads(originals["iiif-plan.json"], maximum=1048576), ids)
    iiif["sourceStateHash"] = derived.commitment
    iiif["linkedArtPlanHash"] = keccak256(plan_raw)
    iiif["premisPlanHash"] = keccak256(premis_raw)
    iiif["canvases"] = [row for row in iiif["canvases"] if row["file"] == file_id]
    iiif_raw = dumps(iiif)
    lido = _rewrite(loads(originals["lido-plan.json"], maximum=1048576), ids)
    lido["sourceStateHash"] = derived.commitment
    lido["linkedArtPlanHash"] = keccak256(plan_raw)
    lido["premisPlanHash"] = keccak256(premis_raw)
    lido["iiifPlanHash"] = keccak256(iiif_raw)
    lido["recordId"] = "https://example.org/lido/fixture/corpus-photo-byte-backed"
    lido_raw = dumps(lido)
    from .package import fixture_state_bytes
    derived_inputs = (derived, selection_raw, plan_raw, premis_raw, iiif_raw, lido_raw)
    raw_inputs = (fixture_state_bytes(derived), *derived_inputs[1:])
    pins = loads(originals["pins.json"], maximum=1048576) | {
        "selection_hash": keccak256(selection_raw), "plan_hash": keccak256(plan_raw),
        "premis_plan_hash": keccak256(premis_raw), "iiif_plan_hash": keccak256(iiif_raw),
        "lido_plan_hash": keccak256(lido_raw)}
    return originals, derived_inputs, raw_inputs, pins, image, {"workId": work_id,
        "fileId": file_id, "visualContentId": photo["contentId"], "sha256": "0x" + digest,
        "size": str(len(image)), "mime": PNG_MIME, "puid": PNG_PUID, "uri": _cid(digest),
        "bodyRights": BODY_RIGHTS, "manifestRights": MANIFEST_RIGHTS,
        "prints": [row["id"] for row in photo["resources"][2:]]}


def build_four_format(corpus_directory, corpus_hash, model_root, base_root=BASE_ROOT,
                      image_path=PNG_PATH):
    originals, derived, raw, pins, image, identity = derive(
        corpus_directory, corpus_hash, base_root, image_path)
    result = build_fixture_package(*derived, root=model_root, **pins)
    return originals, raw, pins, image, identity, result


def correspondence(corpus_files, four_files, identity, image):
    """Bind one byte-backed display file without conflating it with two prints."""
    if sha256(image).hexdigest() != identity["sha256"][2:] or str(len(image)) != identity["size"]:
        raise MuseumError("synthetic display byte fixity differs")
    source = loads(corpus_files["input/corpus/photograph/source/payload.json"],
                   maximum=24576, canonical=True)
    if (source["workId"] != identity["workId"] or source["contentId"] != identity["visualContentId"]
            or source["resources"][1]["id"] != identity["fileId"]
            or [row["id"] for row in source["resources"][2:]] != identity["prints"]):
        raise MuseumError("synthetic photo exact source identity differs")
    index = loads(corpus_files["semantic/entity-index.json"], maximum=65536, canonical=True)
    corpus = {row["id"]: row for row in index if row["scenario"] == "photograph"}
    expected = {identity["visualContentId"], identity["fileId"], *identity["prints"]}
    if not expected.issubset(corpus) or len(identity["prints"]) != 2:
        raise MuseumError("synthetic photo/two-print corpus identity differs")
    entities = loads(four_files["linked-art/entity-index.json"], maximum=65536, canonical=True)
    projected = {row["id"]: row for row in entities if row["kind"] == "linked_art"}
    if not {identity["workId"], identity["fileId"], identity["visualContentId"]}.issubset(projected):
        raise MuseumError("synthetic four-format work/file/content identity differs")
    premis = loads(four_files["premis/correspondence.json"], maximum=65536, canonical=True)
    iiif = loads(four_files["iiif/correspondence.json"], maximum=65536, canonical=True)
    lido = loads(four_files["lido/correspondence.json"], maximum=65536, canonical=True)
    if (len(premis) != 1 or premis[0]["linkedArtId"] != identity["fileId"]
            or len(iiif) != 1 or iiif[0]["linkedArtId"] != identity["fileId"]
            or iiif[0]["workEntity"] != identity["workId"]
            or lido["workId"] != identity["workId"]
            or len(lido["files"]) != 1 or lido["files"][0]["lidoResourceId"] != identity["fileId"]):
        raise MuseumError("synthetic photo four-format correspondence differs")
    manifest = target_loads(four_files["iiif/manifest.json"])
    body = manifest["items"][0]["items"][0]["items"][0]["body"]
    if (body["id"] != identity["uri"] or body["format"] != identity["mime"]
            or body["width"] != WIDTH or body["height"] != HEIGHT
            or body["rights"] != identity["bodyRights"]
            or manifest["rights"] != identity["manifestRights"]
            or body[DIGEST]["@value"] != identity["sha256"][2:]
            or body[SIZE]["@value"] != identity["size"]
            or body[SOURCE]["@value"]["fileEntity"] != identity["fileId"]):
        raise MuseumError("synthetic photo IIIF body identity differs")
    premis_xml = etree.fromstring(four_files["premis/premis.xml"])
    lido_xml = etree.fromstring(four_files["lido/lido.xml"])
    premis_xpath = "/premis:premis/premis:object[1]/premis:objectIdentifier/premis:objectIdentifierValue"
    lido_xpath = "//lido:resourceSet[1]/lido:resourceID"
    if (premis_xml.xpath(premis_xpath + "/text()", namespaces={"premis": PREMIS_NS}) != [identity["fileId"]]
            or lido_xml.xpath(lido_xpath + "/text()", namespaces={"lido": LIDO_NS}) != [identity["fileId"]]):
        raise MuseumError("synthetic photo exported file identifiers differ")
    linked_path = projected[identity["fileId"]]["path"]
    if loads(four_files[linked_path], canonical=True)["id"] != identity["fileId"]:
        raise MuseumError("synthetic photo Linked Art file identifier differs")
    mappings = [{"sourcePointer": "/resources/1/id", "exactHex": "0x" + dumps(identity["fileId"]).hex(),
        "supplementalBasis": "Same explicit file IRI in generated fixture assertions and original source; not a received original master.",
        "targets": {"linked-art": {"path": linked_path, "pointer": "/id"},
            "premis": {"path": "premis/premis.xml", "xpath": premis_xpath},
            "iiif": {"path": "iiif/manifest.json", "pointer": "/items/0/items/0/items/0/body/" + SOURCE + "/@value/fileEntity"},
            "lido": {"path": "lido/lido.xml", "xpath": lido_xpath}}}]
    for i, (field, expected) in enumerate((("width", WIDTH), ("height", HEIGHT))):
        pointer = "/resources/1/dimensions/" + str(i) + "/value"
        if source["resources"][1]["dimensions"][i]["value"] != str(expected):
            raise MuseumError("synthetic photo source dimension differs")
        mappings.append({"sourcePointer": pointer, "exactHex": "0x" + dumps(str(expected)).hex(),
            "supplementalBasis": "Source display dimensions agree with generated PNG IHDR and explicit synthetic IIIF assertion.",
            "targets": {"iiif": {"path": "iiif/manifest.json",
                "pointer": "/items/0/items/0/items/0/body/" + field}}})
    return dumps({"mode": PHOTO_ONLY, "source": {
        "path": "input/corpus/photograph/source/payload.json",
        "hash": keccak256(corpus_files["input/corpus/photograph/source/payload.json"]),
        "workPointer": "/workId", "visualContentPointer": "/contentId",
        "filePointer": "/resources/1/id", "printPointers": ["/resources/2/id", "/resources/3/id"],
        "widthPointer": "/resources/1/dimensions/0/value",
        "heightPointer": "/resources/1/dimensions/1/value"},
        "retainedMedia": {"path": "media/synthetic-display.png", "sha256": identity["sha256"],
                          "bytes": identity["size"], "mime": identity["mime"],
                          "puidDeclaration": identity["puid"], "canonicalUri": identity["uri"],
                          "bodyRightsDeclaration": identity["bodyRights"],
                          "manifestRightsDeclaration": identity["manifestRights"]},
        "identities": {"work": identity["workId"], "visualContent": identity["visualContentId"],
            "displayFile": identity["fileId"], "describedOnlyPrints": identity["prints"],
            "lidoRecord": lido["lidoRecordId"], "iiifManifest": manifest["id"]},
        "sourceFieldMappings": mappings,
        "formatEvidence": {"linkedArt": linked_path,
            "premis": "premis/premis.xml", "iiif": "iiif/manifest.json", "lido": "lido/lido.xml"},
        "qualification": "Deterministic synthetic PNG display derivative only. Original master and two physical prints remain described-only. Additional rights and attribution are synthetic fixture assertions, not original artist authorization; no chain or institution authenticated."})
