"""Additive citation vocabulary; syntax and PID metadata never authenticate source state."""
import re

from .canonical import MuseumError, dumps, hex_bytes, keccak256, uint

PROFILE = "STREAM_CANONICAL_CITATION_PROFILE_V2"
SCHEMA_NAME = "STREAM_CANONICAL_CITATION_V2"
PATTERN_TEXT = (r"eip155:(0|[1-9][0-9]*)/erc721:(0x[0-9a-f]{40})/"
                r"(0|[1-9][0-9]*)(?:@(fin|snap|chain|rec):(0x[0-9a-f]{64}))?")
PATTERN = re.compile(PATTERN_TEXT)
SCHEMA_BYTES = dumps({"$schema": "https://json-schema.org/draft/2020-12/schema",
    "$id": "urn:6529stream:schema:" + SCHEMA_NAME, "title": SCHEMA_NAME,
    "type": "string", "maxLength": 300, "pattern": "^(?:" + PATTERN_TEXT + r")(?![\s\S])",
    "x-stream-semantic-validation": "Nonzero chain/Core/token and qualifier hash; uint256 decimal bounds; V2 parser required."})
SCHEMA_HASH = keccak256(SCHEMA_BYTES)
PROFILE_BYTES = dumps({"name": PROFILE, "version": "2", "status": "prospective_unregistered_profile",
    "schema": {"name": SCHEMA_NAME, "hash": SCHEMA_HASH},
    "identity": "The original eip155 chain/Core/global token triple is permanent, including burned works and successor routes.",
    "qualifiers": {"fin": "Original native finality record hash",
        "snap": "Native snapshot manifest content hash",
        "chain": "Native record-chain head; retain the exact host, scope and record type beside the citation",
        "rec": "Executed native recovery manifest content hash; retain original finality, recovery ID, scope and route hash separately"},
    "recovery": "Scheduled, prepared, vetoed, cancelled and unexecuted recovery cannot supply a rec qualifier. A later route mismatch does not rewrite an executed historical record.",
    "compatibility": "V1 remains closed to fin/snap/chain. Existing schemas, receipts, profile hashes and historical citations are not rewritten or retrospectively registered.",
    "persistentIdentifiers": {"meaning": "A DOI or ARK identifies the same original work or exact cited state; never substitute a successor address.",
        "dataCiteField": "alternateIdentifiers[].alternateIdentifier",
        "dataCiteTypeField": "alternateIdentifiers[].alternateIdentifierType",
        "typeValue": "CAIP-19 Stream citation",
        "guidance": "Copy the entire canonical citation, including any state qualifier. This is a metadata fragment, not a complete DataCite deposit or evidence of PID registration/resolution.",
        "reference": "https://schema.datacite.org/meta/kernel-4.6/"},
    "qualification": "Parsing and metadata crosswalks establish syntax only. Native source correspondence, consensus, authority and institutional acceptance require separate evidence."})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def parse_citation(value, *, require_state=False):
    match = PATTERN.fullmatch(value) if type(value) is str and len(value) <= 300 else None
    if match is None:
        raise MuseumError("V2 citation requires canonical original token and typed qualifier")
    chain, core, token, kind, digest = match.groups()
    if uint(chain) == 0 or uint(token) == 0 or not any(hex_bytes(core, 20)):
        raise MuseumError("V2 citation nonzero chain/Core/token required")
    if require_state and kind is None:
        raise MuseumError("V2 citation record-state qualifier required")
    if kind is not None and not any(hex_bytes(digest, 32)):
        raise MuseumError("V2 citation state hash is empty")
    return {"chainId": chain, "core": core, "tokenId": token,
            "qualifier": None if kind is None else {"kind": kind, "hash": digest}}


def canonical_citation(chain_id, core, token_id, qualifier=None):
    suffix = ""
    if qualifier is not None:
        if type(qualifier) is not dict or set(qualifier) != {"kind", "hash"} or not all(
                type(qualifier[k]) is str for k in qualifier):
            raise MuseumError("V2 citation qualifier shape")
        suffix = "@" + qualifier["kind"] + ":" + qualifier["hash"]
    result = f"eip155:{chain_id}/erc721:{core}/{token_id}{suffix}"
    parse_citation(result)
    return result


def persistent_identifier_crosswalk(citation, *, identifier, identifier_type):
    """Preserve the exact cited state in an offline DOI/ARK metadata fragment."""
    parsed = parse_citation(citation)
    if (identifier_type not in ("DOI", "ARK") or type(identifier) is not str
            or not 1 <= len(identifier.encode("utf-8")) <= 2048
            or any(ord(c) < 33 or ord(c) == 127 for c in identifier)):
        raise MuseumError("citation persistent identifier shape")
    return {"profileHash": PROFILE_HASH, "identifier": identifier,
        "identifierType": identifier_type, "originalWorkCitation": canonical_citation(
            parsed["chainId"], parsed["core"], parsed["tokenId"]), "citedState": citation,
        "dataCiteMetadataFragment": {"alternateIdentifiers": [{"alternateIdentifier": citation,
            "alternateIdentifierType": "CAIP-19 Stream citation"}]},
        "claims": {"sourceStateAuthenticated": False, "identifierRegistered": False,
            "identifierResolved": False, "completeDataCiteRecord": False}}
