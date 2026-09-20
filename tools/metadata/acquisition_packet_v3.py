"""Additive packet V3: optional examination captures, supplied-data checks only."""
import argparse
import copy

from jsonschema.exceptions import ValidationError

from . import acquisition_packet_v2 as v2
from . import genesis_dossier_profile as v1
from tools.museum.canonical import MuseumError, dumps, keccak256, uint

ROOT, MAX_BYTES = v2.ROOT, v2.MAX_BYTES
PACKET = "STREAM_ACQUISITION_PACKET_V3"
CONDITION_REPORTS = "STREAM_ACQUISITION_CONDITION_REPORTS_V3"
BASE_COMMIT = "60a38477c7f0fdd88db4d35bd97efb20edb69515"
V2_PACKET_SCHEMA_HASH = "0xfda1ee532ac701b3030a79f7a3c628a26bb9d2243459d03b850d245ab8c2bd89"
V2_LEGAL_INSTRUMENT_SCHEMA_HASH = "0x84066512aed266d3951177120d7eb8e1142b11e338232dc947ddee33aee448ef"
AUTHORITY_PROFILE_BYTES, AUTHORITY_PROFILE_HASH = v2.PROFILE_BYTES, v2.PROFILE_HASH
QUALIFICATION = (
    "Prospective unregistered packet V3. Only packet identity and the minimum examinationCaptures "
    "cardinality change from V2. A present condition record may explicitly carry zero optional captures. "
    "Validation checks supplied shape and internal joins; it does not select a latest report, prove "
    "record absence or capture completeness, authenticate records, verify an examination, or establish "
    "actual-chain acceptance or complete packet conformance. Native owner authority retains its exact V2 meaning.")
RULES = [
    "Numeric packet version3 selects STREAM_ACQUISITION_PACKET_V3; V1 and V2 bytes and validators remain unchanged.",
    "Only condition.present.examinationCaptures changes minItems from1 to0; its required field, maximum, order and exact reference shape remain unchanged. Empty captures never mean none_recorded.",
    "The exact item15 fragment is {owner,independent}, preserving both lane branches and original classed record references. Native owner authority remains limited to accession/title-binding roles.",
    "The fragment checks supplied source context and lane/type only. Neither schema nor validator establishes latest selection, native absence, payload interpretation, retrieved capture bytes or examination truth. Unsupported selected originals cannot be replaced with older supported records under this schema.",
]


def definitions():
    """Preserve every V2 definition except packet identity and optional captures."""
    definitions_ = copy.deepcopy(v2.definitions())
    definitions_["packet"]["properties"]["schema"] = {"const": PACKET}
    definitions_["packet"]["properties"]["version"] = {"const": 3}
    present = next(row for row in definitions_["condition"]["oneOf"]
        if row["properties"]["status"] == {"const": "present"})
    present["properties"]["examinationCaptures"]["minItems"] = 0
    return definitions_


def _schema(name, packet):
    definitions_ = definitions()
    root = v1.ref("packet") if packet else definitions_["packet"]["properties"]["conditionReports"]
    pending = [row["$ref"].split("/")[-1] for row in v1._walk(root) if "$ref" in row]
    selected = {}
    while pending:
        key = pending.pop()
        if key in selected: continue
        selected[key] = definitions_[key]
        pending.extend(row["$ref"].split("/")[-1] for row in v1._walk(definitions_[key]) if "$ref" in row)
    return {"$schema": "https://json-schema.org/draft/2020-12/schema", "$id": "urn:6529stream:schema:" + name,
        "title": name, "description": QUALIFICATION, **copy.deepcopy(root), "$defs": selected,
        "x-stream-base-packet": {"name": v2.PACKET, "hash": V2_PACKET_SCHEMA_HASH, "sourceCommit": BASE_COMMIT},
        "x-stream-native-owner-authority-profile": {"name": v2.PROFILE, "hash": AUTHORITY_PROFILE_HASH},
        "x-stream-constraints": [*v1.CONSTRAINTS,
            *(rule.removeprefix("Packet version is numeric2. ") for rule in v2.RULES), *RULES],
        **({"x-stream-CMC-ACQUISITION-PACKET": v1.PACKET_REQUIREMENTS} if packet else {})}


PACKET_SCHEMA_BYTES = dumps(_schema(PACKET, True))
PACKET_SCHEMA_HASH = keccak256(PACKET_SCHEMA_BYTES)
CONDITION_REPORTS_SCHEMA_BYTES = dumps(_schema(CONDITION_REPORTS, False))
CONDITION_REPORTS_SCHEMA_HASH = keccak256(CONDITION_REPORTS_SCHEMA_BYTES)


def documents():
    return {PACKET: PACKET_SCHEMA_BYTES, CONDITION_REPORTS: CONDITION_REPORTS_SCHEMA_BYTES}


def validate(raw):
    """Validate supplied V3 packet data using the unchanged V1/V2 semantic joins."""
    try:
        value = v2._parse(raw, PACKET_SCHEMA_BYTES)
        v1._packet(value)
        v2._record_context(value, value["sourceState"], value["ownershipProvenance"], value["recordChainHeads"])
        for binding in value["ownershipProvenance"]["titleBindings"]:
            if "authority" in binding["record"]:
                hop = value["ownershipProvenance"]["transfers"][uint(binding["transferIndex"])]
                v1.need(v2._before(hop, binding["record"]["authority"]["publication"]),
                    "native owner title transfer must precede publication")
        return value
    except (ValidationError, MuseumError, ValueError, TypeError, KeyError, IndexError, RecursionError) as exc:
        if isinstance(exc, v1.DossierError): raise
        raise v1.DossierError(str(exc)) from exc


def validate_condition_reports(raw, source_state):
    """Validate exact supplied item15; no selection or history input is present."""
    try:
        v2._source_context(source_state)
        value = v2._parse(raw, CONDITION_REPORTS_SCHEMA_BYTES)
        v1._record_context(value, source_state)
        for lane, family in (("owner", "CONDITION_REPORT"), ("independent", "INDEPENDENT_CONDITION")):
            condition = value[lane]
            if condition["status"] == "present":
                v1.need(v1._kind(condition["record"], family), "condition lane/type")
        return value
    except (ValidationError, MuseumError, ValueError, TypeError, KeyError, IndexError, RecursionError) as exc:
        if isinstance(exc, v1.DossierError): raise
        raise v1.DossierError(str(exc)) from exc


def outputs():
    return {"schemas/records/" + name + ".json": raw for name, raw in documents().items()}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    original = {v1.PACKET: v2.V1_PACKET_SCHEMA_HASH, v1.OBJECT: v2.V1_OBJECT_SCHEMA_HASH,
        v2.PACKET: V2_PACKET_SCHEMA_HASH, v2.LEGAL_INSTRUMENT: V2_LEGAL_INSTRUMENT_SCHEMA_HASH}
    for name, expected in original.items():
        v1.need(keccak256((ROOT / "schemas/records" / (name + ".json")).read_bytes()) == expected,
            "original schema bytes differ: " + name)
    v1.need(keccak256((ROOT / "schemas/records/profiles" / (v2.PROFILE + ".json")).read_bytes())
        == AUTHORITY_PROFILE_HASH, "original native authority profile differs")
    for path, raw in outputs().items():
        destination = ROOT / path
        if args.check: v1.need(destination.is_file() and destination.read_bytes() == raw, "generated bytes differ: " + path)
        else: destination.parent.mkdir(parents=True, exist_ok=True); destination.write_bytes(raw)
    print("Additive packet V3 and condition fragment definitions match; supplied joins only.")


if __name__ == "__main__": main()
