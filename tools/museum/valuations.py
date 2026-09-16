"""Typed historical owner valuations and explicitly qualified loan-reference joins."""
from .account_profile import JCS_BYTES
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .exhibitions import fields, nullable, _date, _iri, _reference
from .independent_wire import RAW_BYTES
from .loans import documents as loan_documents, selector, admit as admit_loans
from .owner_record_source import OwnerRecordSource
from .preservation_graph import CONTEXT, VALIDATION_HASH, validator
from .review import _validate
from .schemas import HEX32, IRI, TEXT, UINT, arr, definitions, enum, obj

NAME = "STREAM_VALUATION_V1"
JCS_ID = schema_id("RFC8785_JCS")
MODE = "recorded_owner_valuation_projection"
RULE = "urn:6529stream:museum:owner-valuation:v1:"
QUALIFICATION = "Historical token-owner valuation documentation; monetary accuracy, professional identity, countersignatures, legal operativeness and insurance coverage are not independently established."
CLAIMS = {"monetaryAccuracyProven": False, "professionalIdentityProven": False,
    "countersigned": False, "legalOperativenessProven": False, "insuranceCoverageProven": False,
    "currentOwnerProven": False, "instrumentBytesRetrieved": False,
    "institutionalConformance": False, "registeredExport": False}


def documents():
    ref = obj({"uri": IRI, "hash": definitions()["hashRef"]})
    party = loan_documents()["properties"]["lender"]
    name = obj({"value": dict(TEXT, minLength=1), "language": {"type": ["string", "null"], "maxLength": 128}})
    currency = obj({"kind": enum("ISO4217", "other"), "code": dict(TEXT, minLength=1, maxLength=64),
        "reference": nullable(ref)})
    amount = {"type": "string", "pattern": r"^-?(0|[1-9][0-9]*)(\.[0-9]{1,18})?$", "maxLength": 100}
    return {"$schema": "https://json-schema.org/draft/2020-12/schema", "title": NAME,
        "description": "Historical valuation documentation. Confidential instruments expose no figure; source roles are assertions, not countersignatures.",
        **obj({"version": enum("1"), "valuationId": IRI, "tokenId": UINT,
            "status": enum("asserted", "withdrawn"), "title": nullable(name),
            "scope": obj({"kind": enum("object", "loan"), "loanId": nullable(IRI)}),
            "basis": enum("appraisal", "book_value", "insurance", "other"), "basisReference": nullable(ref),
            "effectiveDate": definitions()["date"], "amount": nullable(amount), "currency": nullable(currency),
            "confidential": {"type": "boolean"}, "instrument": ref,
            "issuer": nullable(party), "appraiser": nullable(party),
            "supersedes": arr(HEX32, maximum=16), "references": arr(ref, maximum=16),
            "countersignatures": arr(obj({"role": enum("appraiser", "insurer", "lender", "borrower", "other"),
                "attestor": party["properties"]["identity"], "recordHash": HEX32, "reference": ref}), maximum=16)})}


SCHEMA_BYTES = dumps(documents())
PROFILE_BYTES = dumps({"id": "STREAM_MUSEUM_OWNER_VALUATION_PROFILE_V1", "version": "1",
    "status": "prospective_unregistered_export_profile", "sourceSchemaId": schema_id(NAME),
    "sourceSchemaHash": keccak256(SCHEMA_BYTES), "validationPolicyHash": VALIDATION_HASH,
    "context": CONTEXT, "claims": CLAIMS, "qualification": QUALIFICATION,
    "bounds": {"valuations": "64", "loans": "64", "ownerRecords": "128", "historyAncestorBlocks": "256"},
    "rules": {
        "source": "Exact original OwnerRecords VALUATION receipt and embedded registered schema/JCS. Prior schema meanings and loan v1 output stay unchanged; unknown registered valuation definitions are unsupported.",
        "money": "Appraisal, book value and insurance bases remain distinct. Currency and amount are literal source strings, including scale and sign; no conversion, rounding, catalog validation or current-price assertion.",
        "confidential": "A confidential valuation must omit its figure. Only the declared instrument URI/HashRef and public descriptive fields are exported; sealed bytes are neither accepted nor fetched.",
        "roles": "The receipt authenticates its historical token-owner account only. Named issuer/appraiser identities and cited countersignature records remain separate assertions with unverified countersignature disposition.",
        "semantic": "Explicit valuation document identity/title becomes LinguisticObject. Explicit named Person/Group declarations emit with role sidecars. Structured monetary fields remain Stream extensions; no appraisal Activity or MonetaryAmount class is fabricated outside the pinned model.",
        "loan": "Exact selected original LOAN insurance reference joins same-token typed valuation bytes. Optional complete valuation-lane plus canonical-header-linked receipts proves publication order and explicit supersession references before the loan, including same-block transaction/log order.",
        "selection": "The loan's owner explicitly selected its reference. An ordered unsuperseded reference is only that documented selection under this profile. No universal latest choice across bases, inferred effective-date priority, professional assent or legal operativeness follows.",
        "unknownHistory": "Opaque registered records in the complete lane prevent an unsuperseded conclusion. Bounds or missing receipt evidence never produce partial completeness.",
        "reconstruction": "Literal original loan package, source captures, exact profile and selection inputs are retained and reconstructed offline. No network during verification."},
    "crosswalk": [
        {"rule": RULE + "document", "source": "/valuationId,/title", "target": "LinguisticObject /id,/_label,/identified_by",
            "cardinality": "one per selected explicitly named valuation document", "authority": "original historical owner receipt",
            "uncertainty": "document statement, not performed appraisal", "reverse": "dossier retains exact typed payload and record selector"},
        {"rule": RULE + "named-party", "source": "/issuer,/appraiser", "target": "Person or Group and named-role sidecar",
            "cardinality": "each complete explicit named declaration; identical shared declarations may reuse identity",
            "authority": "owner's named-party assertion", "uncertainty": "no identity, signer or professional equivalence",
            "reverse": "whole declaration and source role retained"},
        {"rule": RULE + "money", "source": "/basis,/amount,/currency,/confidential,/instrument,/effectiveDate", "target": "typed Stream dossier",
            "cardinality": "exactly one field set per supported record", "authority": "original owner statement",
            "uncertainty": "no financial, insurance or temporal truth promotion", "reverse": "literal values, native effectiveAt and source selectors retained"},
        {"rule": RULE + "loan-selection", "source": "original LOAN insurance reference plus optional complete valuation lane and receipt positions",
            "target": "loan-insurance correspondence sidecar", "cardinality": "one result per selected original loan",
            "authority": "owner selection; retained RPC/header/receipt consistency for order", "uncertainty": "legal operativeness and countersignature unproven",
            "reverse": "reference, exact source records, superseding statements and ordered receipt coordinates retained"}]})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def need(ok, message):
    if not ok: raise MuseumError("valuation " + message)


def identity(value):
    if value["kind"] in ("address", "record"):
        need(any(hex_bytes(value["value"], 20 if value["kind"] == "address" else 32)), "empty named identity")
    else:
        _iri(value["value"]); need(value["value"].startswith("did:"), "named DID required")


def admit(source, selected):
    """Pure admission, also usable for explicitly synthetic wire controls."""
    need(isinstance(selected, list) and len(selected) <= 64, "selection bound")
    seen, identities, rows = set(), {}, []
    for h in selected:
        need(hex_bytes(h, 32) != bytes(32) and h not in seen and h in source.records, "missing/duplicate selection")
        seen.add(h); saved = source.records[h]; r, t = saved["record"], saved["receipt"]
        need(r[0] == schema_id("VALUATION"), "original family differs")
        row = {"source": selector(source, saved), "authority": saved["authority"], "value": None,
            "reasonCode": "registered_valuation_definition_unsupported"}
        if (r[2] != schema_id(NAME) or r[3][2] != JCS_ID or source.documents[r[2]][1] != SCHEMA_BYTES
            or source.documents[r[2]][2][3][3] != JCS_ID or source.documents[JCS_ID][1] != JCS_BYTES
            or source.documents[JCS_ID][2][3][3] != RAW_BYTES):
            rows.append(row); continue
        value = _validate(SCHEMA_BYTES, hex_bytes(saved["payloadHex"]))
        need(value["tokenId"] == t[0] and uint(value["tokenId"]) > 0, "token subject differs")
        _iri(value["valuationId"]); need(value["valuationId"] not in identities, "document identity reused")
        identities[value["valuationId"]] = ("LinguisticObject", dumps(value))
        scope = value["scope"]
        need((scope["kind"] == "object") == (scope["loanId"] is None), "scope/loan reference differs")
        if scope["loanId"] is not None: _iri(scope["loanId"])
        _date(value["effectiveDate"]); _reference(value["instrument"])
        need(not value["confidential"] or value["amount"] is None, "confidential figure forbidden")
        need(value["amount"] is None or value["currency"] is not None, "amount currency missing")
        if value["currency"] is not None:
            currency = value["currency"]
            if currency["kind"] == "ISO4217":
                need(len(currency["code"]) == 3 and all("A" <= c <= "Z" for c in currency["code"]), "ISO currency shape")
            if currency["reference"] is not None: _reference(currency["reference"])
        if value["basisReference"] is not None: _reference(value["basisReference"])
        for ref in value["references"]: _reference(ref)
        need(len(set(value["supersedes"])) == len(value["supersedes"])
            and all(hex_bytes(x, 32) != bytes(32) and x != h for x in value["supersedes"]), "supersession reference differs")
        for role in ("issuer", "appraiser"):
            party = value[role]
            if party is None: continue
            _iri(party["entityId"]); _reference(party["reference"]); identity(party["identity"])
            need(not party["entityId"].casefold().startswith(("urn:6529stream:account:", "eip155:")), "named account equivalence")
            exact = (party["kind"], dumps(party))
            need(party["entityId"] not in identities or identities[party["entityId"]] == exact, "conflicting/cross-kind party")
            identities[party["entityId"]] = exact
        counters = set()
        for counter in value["countersignatures"]:
            identity(counter["attestor"]); _reference(counter["reference"])
            need(hex_bytes(counter["recordHash"], 32) != bytes(32) and counter["recordHash"] not in counters, "countersignature reference differs")
            counters.add(counter["recordHash"])
        row.update(value=value, reasonCode=None, nativeEffectiveAt=str(r[6]))
        rows.append(row)
    return sorted(rows, key=lambda r: r["source"]["recordHash"])


def loan_joins(source, loans, valuations, history=None):
    lookup = {r["source"]["recordHash"]: r for r in valuations}; result = []
    for loan in loans:
        v = loan["value"]; ref = v["insuranceValuation"]; h = loan["source"]["recordHash"]
        row = {"loan": loan["source"], "loanId": v["loanId"], "reference": ref,
            "status": "unsupported", "reasonCode": "insurance_reference_missing", "legalOperativenessProven": False,
            "countersigned": False, "publicationOrderChecked": False, "fullValuationLaneChecked": False}
        result.append(row)
        if ref is None: continue
        target = lookup.get(ref["recordHash"])
        if target is None or target["value"] is None:
            row["reasonCode"] = "selected_typed_valuation_missing"; continue
        value = target["value"]
        need(value["tokenId"] == v["tokenId"], "loan valuation token differs")
        row.update(valuation=target["source"], basis=value["basis"], scope=value["scope"],
            nativeEffectiveAt=target["nativeEffectiveAt"], effectiveDate=value["effectiveDate"], reasonCode="publication_order_evidence_missing")
        if value["scope"]["kind"] == "loan" and value["scope"]["loanId"] != v["loanId"]:
            row["reasonCode"] = "valuation_declares_another_loan"; continue
        if history is None: continue
        positions = history["positions"]; lane = history["lanes"].get(v["tokenId"])
        need(lane is not None and h in positions and ref["recordHash"] in positions, "loan history evidence missing")
        position = lambda record: tuple(uint(positions[record][k]) for k in ("blockNumber", "transactionIndex", "logIndex"))
        row.update(publicationOrderChecked=True, fullValuationLaneChecked=True,
            loanPosition=positions[h], valuationPosition=positions[ref["recordHash"]])
        if position(ref["recordHash"]) >= position(h):
            row["reasonCode"] = "valuation_not_published_before_loan"; continue
        prior = [x for x in lane["records"] if position(x) < position(h)]
        unknown = [x for x in prior if x not in lookup or lookup[x]["value"] is None]
        if unknown:
            row.update(reasonCode="prior_valuation_semantics_unsupported", unsupportedRecords=unknown); continue
        superseding = [x for x in prior if ref["recordHash"] in lookup[x]["value"]["supersedes"]]
        row.update(supersedingStatements=superseding,
            declaredEffectiveAtNoLaterThanLoan=uint(target["nativeEffectiveAt"]) <= uint(source.records[h]["receipt"][2]))
        if any(position(x) <= position(ref["recordHash"]) for x in superseding):
            row["reasonCode"] = "supersession_reference_precedes_target"
        elif superseding: row["reasonCode"] = "explicit_superseding_statement_before_loan"
        elif value["status"] == "withdrawn": row["reasonCode"] = "selected_valuation_withdrawn"
        else: row.update(status="ordered_selected_unsuperseded_reference", reasonCode=None)
    return result


def render(rows, joins, model, missing_source=False):
    files, index, provenance, coverage, dossiers, roles, dispositions = {}, [], [], [], [], [], []
    def emit(resource, row, paths):
        raw = dumps(resource); expanded = model.validate_and_expand(raw); key = keccak256(resource["id"].encode())[2:]
        path = "valuations/resources/" + key + ".json"
        if path in files: need(files[path] == raw, "resource identity conflict")
        else:
            files[path] = raw; files["valuations/expanded/" + key + ".json"] = expanded.expanded_bytes
            index.append({"id": resource["id"], "type": resource["type"], "path": path})
        provenance.extend({"entity": resource["id"], "path": p, "value": v, "source": row["source"],
            "sourcePaths": paths, "rule": RULE + ("document" if resource["type"] == "LinguisticObject" else "named-party"),
            "qualification": QUALIFICATION} for p, v in fields(resource))
    def named(identifier, kind, name):
        return {"@context": CONTEXT, "id": identifier, "type": kind, "_label": name["value"],
            "identified_by": [{"type": "Name", "content": name["value"]}],
            "referred_to_by": [{"type": "LinguisticObject", "content": QUALIFICATION}]}
    for row in rows:
        v = row["value"]; missing = []
        if v is None:
            dispositions.append({"source": row["source"], "status": "unsupported", "reasonCode": row["reasonCode"]}); continue
        dossier = {"source": row["source"], "authority": row["authority"], "valuation": v,
            "nativeEffectiveAt": row["nativeEffectiveAt"], "qualification": QUALIFICATION,
            "countersignatures": [{"reference": c, "status": "unverified_reference", "reasonCode": "selected_general_attestation_evidence_missing"} for c in v["countersignatures"]]}
        dossiers.append(dossier)
        coverage.extend({"source": row["source"], "sourcePath": p, "value": x, "disposition": "retained_with_source"} for p, x in fields(v))
        if v["title"] is None: missing.append("document_title_missing")
        else: emit(named(v["valuationId"], "LinguisticObject", v["title"]), row, ["/valuationId", "/title"])
        for role in ("issuer", "appraiser"):
            party = v[role]
            if party is None: missing.append(role + "_not_recorded"); continue
            roles.append({"document": v["valuationId"], "party": party, "role": role, "source": row["source"],
                "namedIdentityProven": False, "countersigned": False})
            if party["name"] is not None: emit(named(party["entityId"], party["kind"], party["name"]), row, ["/" + role])
        dispositions.append({"source": row["source"], "status": "typed_dossier", "reasonCode": None,
            "missingFacts": missing, "basis": v["basis"], "confidential": v["confidential"]})
    status = "unsupported" if missing_source or not rows else "partial" if any(r["status"] == "unsupported" for r in dispositions) else "typed_dossiers_with_stream_extensions"
    for name, value in {"index": {"resources": sorted(index, key=lambda r: r["id"])}, "dossiers": dossiers,
        "coverage": coverage, "provenance": provenance, "named-roles": roles, "loan-insurance": joins,
        "report": {"mode": MODE, "version": "1", "profileHash": PROFILE_HASH, "status": status,
            "reasonCode": "owner_source_missing" if missing_source else "no_selected_valuations" if not rows else None,
            "dispositions": dispositions, "claims": CLAIMS, "qualification": QUALIFICATION}}.items():
        files["valuations/" + name + ".json"] = dumps(value)
    return files


def project_valuations(source, plan_bytes, *, plan_hash, profile_hash, source_hash, model, history=None):
    need(profile_hash == PROFILE_HASH and keccak256(plan_bytes) == plan_hash, "external profile/plan differs")
    plan = loads(plan_bytes, maximum=524288, canonical=True)
    need(isinstance(plan, dict) and set(plan) == {"version", "ownerSourceHash", "records", "loans"}
        and plan["version"] == "1" and plan["ownerSourceHash"] == source_hash, "source-bound plan differs")
    if source is None:
        need(source_hash is None and plan["records"] == [] and plan["loans"] == [] and history is None, "selected facts require owner source")
        return render([], [], model, True)
    need(type(source) is OwnerRecordSource and source.provenance == "trusted_rpc", "concrete recorded owner source required")
    need(keccak256(source.snapshot()) == source_hash, "owner source snapshot differs")
    rows = admit(source, plan["records"]); loans = admit_loans(source, plan["loans"])
    if history is not None:
        from .valuation_history import ValuationHistory
        need(type(history) is ValuationHistory and history.source is source and history.provenance == "trusted_rpc", "concrete recorded history required")
        need(history.hints["loans"] == plan["loans"], "history loan selection differs")
        evidence = history.capture()
        required = {h for lane in evidence["lanes"].values() for h in lane["records"]}
        need(required <= set(plan["records"]), "complete history requires every valuation semantic input")
    else: evidence = None
    return render(rows, loan_joins(source, loans, rows, evidence), model)


def main():
    import argparse
    from pathlib import Path
    p = argparse.ArgumentParser(description="Generate/check prospective valuation definitions; no registration.")
    p.add_argument("--check", action="store_true"); args = p.parse_args()
    root = Path(__file__).resolve().parents[2] / "schemas/museum/valuation"
    for name, raw in ((NAME + ".json", SCHEMA_BYTES), ("profile.json", PROFILE_BYTES)):
        path = root / name
        if args.check: need(path.is_file() and path.read_bytes() == raw, "definition differs")
        else: root.mkdir(parents=True, exist_ok=True); path.write_bytes(raw)
    print(PROFILE_HASH)


if __name__ == "__main__": main()
