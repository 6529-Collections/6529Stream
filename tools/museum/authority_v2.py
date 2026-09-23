"""Versioned typed authority assertions with exact declaration references."""
from copy import deepcopy

from . import authority as v1
from .canonical import dumps, keccak256, loads
from .schemas import HEX32, definitions, enum, obj

NAME = "STREAM_MUSEUM_AUTHORITY_ALIGNMENT_BODY_V2"
PROFILE = "STREAM_MUSEUM_AUTHORITY_RECONCILIATION_V2"
RELATION = "urn:6529stream:authority-alignment:v2"
DATATYPE = "urn:6529stream:datatype:authority-alignment:v2"
RULE = "urn:6529stream:museum:mapping:authority-alignment-v2"
DECLARATION_REF = obj({"selector": definitions()["selector"], "declarationHash": HEX32})
BODY_SCHEMA = deepcopy(v1.BODY_SCHEMA)
BODY_SCHEMA["title"] = NAME
BODY_SCHEMA["properties"]["declaration"] = {"oneOf": [
    obj({"scope": enum("same_record"), "pointer": {"type": "string", "pattern": "^/entities/(0|[1-9][0-9]*)$"}}),
    obj({"scope": enum("prior_record"), **DECLARATION_REF["properties"]})]}
BODY_SCHEMA["required"].append("declaration")
BODY_SCHEMA_BYTES = dumps(BODY_SCHEMA)
BODY_SCHEMA_HASH = keccak256(BODY_SCHEMA_BYTES)
profile = loads(v1.PROFILE_BYTES, canonical=True)
profile.update(id=PROFILE, version="2", supersedesProfileHash=v1.PROFILE_HASH,
    bodySchemaHash=BODY_SCHEMA_HASH, relation=RELATION, datatype=DATATYPE, mappingRule=RULE)
for row in profile["crosswalk"]:
    row.update(sourceSchema=NAME, sourceSchemaHash=BODY_SCHEMA_HASH, recordedDeclarationSupport=True)
profile["policy"]["declarations"] = (
    "Bind same-record declarations without circular hashes or prior-record exact selectors/hashes. "
    "Prior declarations must precede the assertion, have the same account, identity and kind, and be cited in sourceRecords. "
    "A continued declaration requires an explicit exact predecessor, stable identity/kind/account and at most eight links. "
    "Dossier reuse follows only this explicit lineage; competing selected branches remain ambiguous.")
profile["policy"]["registration"] = "The typed account profile retains this complete definition and its dependency closure; per-capture registration is verified separately."
PROFILE_BYTES = dumps(profile)
PROFILE_HASH = keccak256(PROFILE_BYTES)


def alignment_literal(body):
    raw = dumps(body); v1._validate(BODY_SCHEMA, raw, 8192)
    return {"lexicalValue": raw.decode(), "datatype": DATATYPE, "language": None, "unit": None, "precision": None}


def _body(assertion):
    v1._validate(v1.ASSERTION_SCHEMA, dumps(assertion), 24576)
    v1.need(assertion["relation"] == RELATION and assertion["mappingRule"] == RULE, "alignment v2 relation/rule differs")
    literal = assertion["object"].get("literal")
    v1.need(isinstance(literal, dict) and literal["datatype"] == DATATYPE
        and all(literal[key] is None for key in ("language", "unit", "precision")), "alignment v2 literal differs")
    body = v1._validate(BODY_SCHEMA, literal["lexicalValue"].encode(), 8192)
    # Reuse unchanged v1 assertion consistency checks without reinterpreting v1 bytes.
    old = deepcopy(assertion); original = deepcopy(body); original.pop("declaration")
    old.update(relation=v1.RELATION, mappingRule=v1.RULE)
    old["object"] = {"literal": v1.alignment_literal(original)}
    v1._body(old)
    return body


def main():
    import argparse
    from pathlib import Path
    p = argparse.ArgumentParser(description=__doc__); p.add_argument("--check", action="store_true"); args = p.parse_args()
    target = Path(__file__).resolve().parents[2] / "schemas/museum/authority-v2"
    for name, raw in ((NAME, BODY_SCHEMA_BYTES), ("profile", PROFILE_BYTES)):
        path = target / (name + ".json")
        if args.check: v1.need(path.read_bytes() == raw, "v2 generated definition differs")
        else: target.mkdir(parents=True, exist_ok=True); path.write_bytes(raw)
    print(PROFILE_HASH)


if __name__ == "__main__": main()
