"""Typed historical owner documentation with exact instruments and distinct facts.

The public entry point requires the original recorded source and external pins.
The pure admission helper also exercises explicitly synthetic original-wire
controls. Neither mode turns a token owner's statement into legal advice or an
institution's independently verified assertion.
"""
from hashlib import sha256

from .account_profile import JCS_BYTES
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .citations import canonical_citation, parse_citation
from .chain_rpc import MAX_TRANSCRIPT, ReplayTransport
from .exhibitions import _date, _iri, _reference, fields, nullable
from .independent_wire import RAW_BYTES, ZERO
from .institutional_source import InstitutionalOwnerSource, NEW_FAMILIES
from .loans import JCS_ID, selector
from .preservation_graph import CONTEXT, VALIDATION_HASH, validator
from .review import _validate
from .schemas import ADDRESS, HEX32, IRI, TEXT, UINT, arr, definitions, enum, obj

NAMES = {name: "STREAM_" + ("CITATION_RECORD" if name == "CITATION" else name) + "_V1" for name in NEW_FAMILIES}
QUALIFICATION = "Historical token-owner documentation; named institution identity, legal title, physical custody, token transfer, fulfillment and cited state are not independently established."
CLAIMS = {k: False for k in ("namedInstitutionIdentityProven", "legalTitleProven", "custodyTransferred",
    "currentOwnerProven", "tokenTransferVerified", "fulfillmentProven", "citedStateVerified",
    "institutionalConformance", "registeredExport", "cryptographicStateProof")}
REF = obj({"uri": IRI, "hash": definitions()["hashRef"]})
NAME = obj({"value": dict(TEXT, minLength=1), "language": {"type": ["string", "null"], "maxLength": 128}})
PARTY = obj({"entityId": IRI, "kind": enum("Person", "Group"), "name": NAME,
    "identity": obj({"kind": enum("address", "did", "record"), "value": TEXT}), "reference": REF})
TITLE_BINDING = obj({"instrument": REF, "custodian": PARTY,
    "transfer": obj({"chainId": UINT, "core": ADDRESS, "tokenId": UINT, "blockNumber": UINT,
        "transactionHash": HEX32, "logIndex": UINT, "from": ADDRESS, "to": ADDRESS})})


def documents():
    common = {"version": enum("1"), "recordId": IRI, "tokenId": UINT,
        "recordedDate": definitions()["date"], "supersedes": arr(HEX32, maximum=16)}
    specific = {
        "ACCESSION": {"accessionIdentifier": dict(TEXT, minLength=1), "acquiringInstitution": PARTY,
            "titleBinding": TITLE_BINDING},
        "DEACCESSION": {"reasonClass": IRI, "disposition": REF, "titleBinding": TITLE_BINDING},
        "REDEMPTION_CLAIM": {"program": HEX32, "entitlementDescription": dict(TEXT, minLength=1),
            "fulfillment": nullable(REF)},
        "CITATION": {"citedWork": dict(TEXT, maxLength=300), "citingWork": REF, "contextNote": TEXT},
    }
    return {family: {"$schema": "https://json-schema.org/draft/2020-12/schema", "title": NAMES[family],
        "description": "Prospective closed original-owner documentation. Legal title and physical custody remain distinct.",
        **obj({**common, **specific[family]})} for family in NEW_FAMILIES}


SCHEMAS = {k: dumps(v) for k, v in documents().items()}
PROFILE_BYTES = dumps({"id": "STREAM_MUSEUM_INSTITUTIONAL_DOCUMENTATION_PROFILE_V1", "version": "1",
    "status": "prospective_unregistered_export_profile", "qualification": QUALIFICATION, "claims": CLAIMS,
    "sourceSchemas": [{"family": k, "schemaId": schema_id(NAMES[k]), "schemaHash": keccak256(v)} for k, v in SCHEMAS.items()],
    "context": CONTEXT, "validationPolicyHash": VALIDATION_HASH,
    "bounds": {"records": "64", "ownerRecords": "128", "payloadBytes": "8192", "documents": "128",
        "documentBytes": "1048576", "aggregateDocumentBytes": "16777216", "planBytes": "524288"},
    "rules": {
        "source": "Only the four closed public institutional families and their exact candidate schema/JCS bytes enter the retained source closure, including immediate predecessor reads. Original host/subject/actor/signature/history retained. V1 loan source is unchanged.",
        "identity": "Explicit statement and party IRIs; no account equivalence, kind collision, name matching or implied institution authorization.",
        "title": "Instrument commitment, specific original token Transfer coordinates including logIndex and instrument custodian. No transfer, title or custody event inferred without independent evidence.",
        "instruments": "Exact optionally supplied public instrument bytes checked with RAW_BYTES Keccak256 or SHA256; unsupported algorithms remain explicit. Hash matching proves bytes, never legal validity or signatory identity.",
        "redemption": "First accepted record for subject/program in full pinned original owner lane is operative. All lane candidates must use the exact admitted schema; later documentation never becomes a second claim. A correction does not erase the first claim.",
        "citation": "Permanent original lowercase Core/decimal token citation; fin/snap/chain qualifier namespaces are closed. Referenced state is retained, never fabricated as verified.",
        "projection": "Each record becomes a qualified LinguisticObject with exact primary text; named parties become Person/Group. Typed accession/title/transfer/custody/claim relationships stay separately attributed in Stream sidecar.",
        "coverage": "Every scalar, null, empty array and source order retained; exact original payloads, schemas and source selectors remain in package. Unprovided evidence is missing, never withheld.",
        "disclosure": "Explicit public classification only; no remote fetching or restricted instrument intake."},
    "crosswalk": [
        {"family": k, "sourceSchemaId": schema_id(NAMES[k]), "sourceSchemaHash": keccak256(v),
         "sourceSelector": "/", "subjectKind": "token", "target": "LinguisticObject/content + typed Stream dossier",
         "cardinality": "one document per selected record", "authority": "historical original token owner",
         "uncertainty": "claims remain qualified", "reverse": "exact retained original payload and coverage pointers",
         "positiveTest": "test_all_families_keep_distinct_qualified_facts", "negativeTest": "test_schema_token_and_title_transfer_mismatch_reject"}
        for k, v in SCHEMAS.items()]})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def need(condition, message):
    if not condition:
        raise MuseumError("institutional " + message)


def _party(party):
    _iri(party["entityId"]); _reference(party["reference"])
    need(not party["entityId"].casefold().startswith(("eip155:", "urn:6529stream:account:")), "party account equivalence")
    identity = party["identity"]
    if identity["kind"] == "did":
        _iri(identity["value"]); need(identity["value"].startswith("did:"), "party DID required")
    else:
        need(any(hex_bytes(identity["value"], 20 if identity["kind"] == "address" else 32)), "party identity missing")


def validate_payload(family, raw):
    need(family in SCHEMAS and type(raw) is bytes and 0 < len(raw) <= 8192, "family/payload bound")
    value = _validate(SCHEMAS[family], raw)
    need(dumps(value) == raw, "payload must be exact JCS")
    need(uint(value["tokenId"]) > 0, "token required")
    _iri(value["recordId"]); _date(value["recordedDate"])
    need(not value["recordId"].casefold().startswith(("eip155:", "urn:6529stream:account:")), "statement account equivalence")
    need(len(set(value["supersedes"])) == len(value["supersedes"])
        and all(h != ZERO for h in value["supersedes"]), "duplicate/empty supersession")
    if family in ("ACCESSION", "DEACCESSION"):
        binding = value["titleBinding"]; _reference(binding["instrument"]); _party(binding["custodian"])
        transfer = binding["transfer"]
        for key in ("chainId", "tokenId", "blockNumber", "logIndex"): uint(transfer[key])
        need(transfer["tokenId"] == value["tokenId"] and uint(transfer["chainId"]) > 0
            and any(hex_bytes(transfer["core"], 20)) and transfer["transactionHash"] != ZERO
            and transfer["from"] != transfer["to"], "title Transfer token/identity differs")
        if family == "ACCESSION":
            _party(value["acquiringInstitution"])
            need(value["acquiringInstitution"]["kind"] == "Group", "acquiring institution must be Group")
        else:
            _iri(value["reasonClass"]); _reference(value["disposition"])
    elif family == "REDEMPTION_CLAIM":
        need(value["program"] != ZERO, "empty redemption program")
        if value["fulfillment"] is not None: _reference(value["fulfillment"])
    else:
        parse_citation(value["citedWork"], require_state=True); _reference(value["citingWork"])
    return value


def _references(value, path=""):
    if isinstance(value, dict):
        if set(value) == {"uri", "hash"}:
            yield path, value
        else:
            for key, child in value.items():
                yield from _references(child, path + "/" + key.replace("~", "~0").replace("/", "~1"))
    elif isinstance(value, list):
        for i, child in enumerate(value): yield from _references(child, path + "/" + str(i))


def _evidence(reference, documents):
    h = reference["hash"]; key = keccak256(dumps(h))
    if key not in documents:
        return {"hashRefKey": key, "status": "referenced_not_supplied", "bytesVerified": False}
    raw = documents[key]
    need(h["canonicalizationId"] == RAW_BYTES and h["algorithm"] in ("1", "2"), "supplied evidence hash profile unsupported")
    digest = keccak256(raw) if h["algorithm"] == "1" else "0x" + sha256(raw).hexdigest()
    need(digest == h["digest"], "supplied evidence digest differs")
    return {"hashRefKey": key, "status": "retained_hash_verified", "bytesVerified": True}


def admit(source, selected, *, documents=None):
    """Pure original-wire controls; project_institutional enforces recorded provenance."""
    documents = {} if documents is None else documents
    need(isinstance(documents, dict) and len(documents) <= 128
        and all(type(v) is bytes and 0 < len(v) <= 1048576 for v in documents.values())
        and sum(map(len, documents.values())) <= 16777216, "public evidence bounds")
    for key in documents: need(any(hex_bytes(key, 32)), "document key")
    need(isinstance(selected, list) and len(selected) <= 64, "selection bound")
    seen, ids, rows, used = set(), {}, [], set()
    first_claims = {}
    # Every record in a selected redemption lane is interpreted, including
    # records omitted from the projection plan. Unsupported historical schema
    # cannot silently make a later claim look first.
    for token, lane in source.redemption_lanes.items():
        for digest in lane["records"]:
            row = source.records[digest]
            value = _admit_row(source, row, "REDEMPTION_CLAIM")
            first_claims.setdefault((token, value["program"]), digest)
    for digest in selected:
        need(any(hex_bytes(digest, 32)) and digest not in seen, "duplicate/invalid selected record"); seen.add(digest)
        need(digest in source.records, "selected original record missing")
        row = source.records[digest]
        family = next((k for k in NEW_FAMILIES if schema_id(k) == row["record"][0]), None)
        need(family is not None, "unsupported selected family")
        value = _admit_row(source, row, family)
        declarations = [(value["recordId"], "LinguisticObject", value)]
        for party in ([value["acquiringInstitution"]] if family == "ACCESSION" else []) + ([value["titleBinding"]["custodian"]] if family in ("ACCESSION", "DEACCESSION") else []):
            declarations.append((party["entityId"], party["kind"], party))
        for identifier, kind, declaration in declarations:
            exact = (kind, dumps(declaration))
            need(identifier not in ids or (kind != "LinguisticObject" and ids[identifier] == exact), "conflicting selected identity")
            ids[identifier] = exact
        references = []
        for path, reference in _references(value):
            evidence = _evidence(reference, documents); used.add(evidence["hashRefKey"])
            references.append({"sourcePath": path, "reference": reference, **evidence})
        supplements = []
        for prior in value["supersedes"]:
            other = source.records.get(prior)
            if other is None:
                supplements.append({"recordHash": prior, "status": "referenced_not_selected"}); continue
            need(other["record"][0:2] == row["record"][0:2]
                and uint(other["receipt"][3]) < uint(row["receipt"][3]), "supersession must name earlier same-subject family")
            supplements.append({"recordHash": prior, "status": "earlier_documentation", "source": selector(source, other)})
        primacy = None
        if family == "REDEMPTION_CLAIM":
            first = first_claims[(value["tokenId"], value["program"])]
            primacy = {"operativeClaim": first, "disposition": "operative_claim" if first == digest else "supplemental_documentation",
                "lane": source.redemption_lanes[value["tokenId"]], "fulfillmentProven": False}
        rows.append({"family": family, "source": selector(source, row), "authority": row["authority"],
            "citation": canonical_citation(source.a["chainId"], source.a["core"], value["tokenId"]),
            "value": value, "references": references, "supersession": supplements, "primacy": primacy})
    need(set(documents) <= used, "unreferenced evidence supplied")
    return sorted(rows, key=lambda row: row["source"]["recordHash"])


def _admit_row(source, row, family):
    r, t = row["record"], row["receipt"]
    need(r[0] == schema_id(family) and r[2] == schema_id(NAMES[family]) and r[3][2] == JCS_ID
        and source.documents[r[2]][1] == SCHEMAS[family] and source.documents[r[2]][2][3][3] == JCS_ID
        and source.documents[JCS_ID][1] == JCS_BYTES and source.documents[JCS_ID][2][3][3] == RAW_BYTES,
        "exact original family/schema/JCS required")
    value = validate_payload(family, hex_bytes(row["payloadHex"]))
    need(value["tokenId"] == t[0], "original token subject differs")
    if family in ("ACCESSION", "DEACCESSION"):
        transfer = value["titleBinding"]["transfer"]
        need(transfer["chainId"] == source.a["chainId"] and transfer["core"] == source.a["core"]
            and uint(transfer["blockNumber"]) <= uint(source.a["blockNumber"]), "title Transfer original chain/Core/block differs")
    if family == "CITATION":
        citation = parse_citation(value["citedWork"], require_state=True)
        need(all(citation[k] == v for k, v in (("chainId", source.a["chainId"]), ("core", source.a["core"]), ("tokenId", t[0]))),
            "cited work original token differs")
    return value


def render(rows, model):
    files, index, provenance, coverage, dossiers = {}, [], [], [], []
    def emit(resource, row, pointers):
        raw = dumps(resource); expanded = model.validate_and_expand(raw)
        key = keccak256(resource["id"].encode())[2:]; path = "institutional/resources/" + key + ".json"
        if path in files: need(files[path] == raw, "conflicting resource output")
        else:
            files[path] = raw; files["institutional/expanded/" + key + ".json"] = expanded.expanded_bytes
            index.append({"id": resource["id"], "type": resource["type"], "path": path})
        provenance.extend({"entity": resource["id"], "path": p, "value": v, "source": row["source"],
            "sourcePaths": pointers, "rule": "urn:6529stream:museum:institutional:v1:documented-statement"} for p, v in fields(resource))
    for row in rows:
        value, family = row["value"], row["family"]
        primary = {"ACCESSION": "accessionIdentifier", "DEACCESSION": "reasonClass", "REDEMPTION_CLAIM": "entitlementDescription", "CITATION": "contextNote"}[family]
        emit({"@context": CONTEXT, "id": value["recordId"], "type": "LinguisticObject", "_label": family + " owner documentation", "content": value[primary],
            "referred_to_by": [{"type": "LinguisticObject", "content": QUALIFICATION}]}, row, ["/recordId", "/" + primary])
        for key in ("acquiringInstitution", "titleBinding/custodian"):
            party = value.get(key) if "/" not in key else value.get("titleBinding", {}).get("custodian")
            if party is None: continue
            emit({"@context": CONTEXT, "id": party["entityId"], "type": party["kind"], "_label": party["name"]["value"],
                "identified_by": [{"type": "Name", "content": party["name"]["value"]}],
                "referred_to_by": [{"type": "LinguisticObject", "content": QUALIFICATION}]}, row, ["/" + key])
        coverage.extend({"source": row["source"], "sourcePath": p, "value": v,
            "disposition": "retained_stream_only", "reason": "complete_original_documentation"} for p, v in fields(value))
        dossiers.append({**row, "qualification": QUALIFICATION})
    values = {"index": {"resources": sorted(index, key=lambda v: v["id"])}, "dossiers": dossiers,
        "coverage": coverage, "provenance": provenance, "report": {"profileHash": PROFILE_HASH,
        "status": "complete_selected_documentation" if rows else "no_selected_records", "claims": CLAIMS,
        "qualification": QUALIFICATION, "missingPublicEvidence": [{"source": row["source"], "sourcePath": ref["sourcePath"]}
            for row in rows for ref in row["references"] if not ref["bytesVerified"]]}}
    files.update({"institutional/" + k + ".json": dumps(v) for k, v in values.items()})
    return files


def project_institutional(source, plan_bytes, *, source_hash, plan_hash, profile_hash, model, documents=None):
    need(type(source) is InstitutionalOwnerSource and source.provenance == "trusted_rpc", "concrete recorded institutional source required")
    need(profile_hash == PROFILE_HASH and keccak256(plan_bytes) == plan_hash, "external profile/plan pin differs")
    plan = loads(plan_bytes, maximum=524288, canonical=True)
    need(isinstance(plan, dict) and set(plan) == {"version", "ownerSourceHash", "records"} and plan["version"] == "1"
        and plan["ownerSourceHash"] == source_hash and keccak256(source.snapshot()) == source_hash, "source-bound plan differs")
    # Public adapter objects contain nested mutable views. Rebuild from the
    # committed original evidence so edits to those views cannot forge output
    # under an unchanged source pin or alter first-claim primacy.
    committed = loads(source.snapshot(), maximum=MAX_TRANSCRIPT, canonical=True)
    need(keccak256(source.anchor_bytes) == committed["anchorHash"], "original source anchor changed")
    frozen = InstitutionalOwnerSource(source.anchor_bytes,
        ReplayTransport(source.reader.transcript(), committed["transcriptHash"]), provenance="trusted_rpc")
    need(keccak256(frozen.snapshot()) == source_hash, "original source reconstruction differs")
    return render(admit(frozen, plan["records"], documents=documents), model)


def main():
    import argparse
    from pathlib import Path
    p = argparse.ArgumentParser(description="Generate/check prospective institutional documents; no registration.")
    p.add_argument("--check", action="store_true"); args = p.parse_args()
    root = Path(__file__).resolve().parents[2] / "schemas/museum/institutional"
    for name, raw in [(NAMES[k] + ".json", v) for k, v in SCHEMAS.items()] + [("profile.json", PROFILE_BYTES)]:
        path = root / name
        if args.check: need(path.is_file() and path.read_bytes() == raw, "definition differs")
        else: root.mkdir(parents=True, exist_ok=True); path.write_bytes(raw)
    print(PROFILE_HASH)


if __name__ == "__main__": main()
