"""Selected historical owner exhibition statements, with their own authority.

The original independent exhibition profile and genesis schema stay unchanged.
This reader retains only explicit public exhibition selections and their bounded
immediate predecessors; neither selection nor projection proves a complete lane.
"""
from .account_profile import JCS_BYTES, JCS_ID
from .canonical import MuseumError, dumps, hex_bytes, keccak256, schema_id, subject_id, uint
from .exhibitions import NAME, SCHEMA_BYTES, _date, _instant, _iri, _reference, fields
from .independent_wire import RAW_BYTES, ZERO, json_values
from .owner_record_source import OwnerRecordSource
from .preservation_graph import CONTEXT, VALIDATION_HASH, validator
from .review import _validate

SOURCE_PROFILE = "STREAM_MUSEUM_OWNER_EXHIBITION_SOURCE_V1"
MODE = "recorded_owner_exhibition_projection"
FAMILY = schema_id("EXHIBITION")
SCHEMA_HASH = keccak256(SCHEMA_BYTES)
MAX_RECORDS = 64
RULE = "urn:6529stream:museum:owner-exhibition:v1:"
QUALIFICATION = (
    "Historical token-owner exhibition statement. The accepted owner receipt is separate from "
    "the named institution and does not establish occurrence, dates, institutional identity, "
    "display permission, custody or legal title. Same-block Core mapping existence establishes "
    "the permanent token/collection correspondence, not a proved token lifecycle. Selected "
    "receipts and immediate predecessors do not establish complete exhibition history."
)
CLAIMS = {"historicalPerformanceProven": False, "historicalTimeProven": False,
    "namedInstitutionIdentityProven": False, "displayAuthorized": False,
    "custodyTransferred": False, "legalTitleProven": False, "rightsGranted": False,
    "currentOwnerProven": False, "tokenLifecycleProven": False, "fullLaneHistory": False,
    "institutionalConformance": False, "linkedArtApiConformance": False,
    "registeredExport": False, "referenceBytesRetrieved": False,
    "actualChainAcceptance": False, "consensusProof": False}
PROFILE_BYTES = dumps({"id": "STREAM_MUSEUM_OWNER_EXHIBITION_PROFILE_V1", "version": "1",
    "status": "prospective_unregistered_export_profile", "sourceProfile": SOURCE_PROFILE,
    "sourceSchemaId": schema_id(NAME), "sourceSchemaHash": SCHEMA_HASH, "sourceFamily": FAMILY,
    "validationPolicyHash": VALIDATION_HASH, "context": CONTEXT,
    "bounds": {"selectedRecords": str(MAX_RECORDS), "capturedRecords": "128", "payloadBytes": "8192"},
    "qualification": QUALIFICATION, "claims": CLAIMS,
    "rules": {
        "authority": "Exact original OwnerRecords EXHIBITION receipts, direct or relayed, retain owner at publication. No independent class5, Artist authority or present owner is substituted.",
        "definitions": "Unchanged STREAM_EXHIBITION_V1 and RFC8785_JCS bytes must equal their original receipt commitments and registered definitions. No same-name schema substitution.",
        "scope": "Token subject only. Exact same-block tokenCollectionIdentity supplies collectionId and serial; burned historical tokens remain readable. Mapping existence is not a lifecycle proof.",
        "publicClosure": "Every captured selection and immediate predecessor must contain bounded embedded Keccak JCS under the exact public exhibition schema. Foreign or opaque predecessors reject capture before any package is published.",
        "selection": "Public projection requires a nonempty unique selection equal to the captured record set and its external snapshot pin. Immediate predecessors remain retention-only; no current or full-lane assertion follows.",
        "identity": "Original exhibition/institution/venue IRIs remain separate from owner accounts. Unique event IDs; shared institution or venue IDs require same kind and byte-identical whole declaration, retaining every source provenance.",
        "status": "Only completed statements with explicit title, institution and venue names produce Activity. Planned/cancelled/unknown remain nonperformed sidecars; missing names remain unsupported.",
        "institution": "Named institution becomes Group participant, never inferred organizer, legal owner or custodian. Address/DID/record identity is an attributed claim, not Group equivalence.",
        "dates": "Original expressions, precision, calendars and timezones remain intact. Only explicit Gregorian UTC bounds become TimeSpan bounds; publication time never becomes an exhibition date.",
        "references": "All original URI/HashRef pairs and Artist intent references remain exact commitments. No documents are fetched and no referenced authority or display permission is inferred.",
        "coverage": "Every selected source scalar, null and empty collection remains in the sidecar and source-pointer coverage. Each graph scalar retains its original owner selector and mapping rule."}})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def need(condition, message):
    if not condition:
        raise MuseumError("owner exhibition " + message)


def _declarations(value, identities):
    for identifier, kind, declaration in (
        (value["exhibitionId"], "Activity", value),
        (value["institution"]["entityId"], "Group", value["institution"]),
        (value["venue"]["entityId"], "Place", value["venue"]),
    ):
        _iri(identifier)
        need(not identifier.casefold().startswith(("urn:6529stream:account:", "eip155:")),
             "account equivalence is not an exhibition identity")
        exact = (kind, dumps(declaration))
        need(identifier not in identities or (kind != "Activity" and identities[identifier] == exact),
             "conflicting entity identity declaration or repeated event")
        identities[identifier] = exact


def validate_payload(raw):
    """Validate the unchanged closed public schema and source-authored semantics."""
    need(type(raw) is bytes and 0 < len(raw) <= 8192, "public payload byte bound")
    value = _validate(SCHEMA_BYTES, raw)
    subject = value["subject"]
    need(subject["kind"] == "token" and uint(subject["tokenId"]) > 0
        and uint(subject["collectionId"]) > 0, "token subject required")
    _declarations(value, {})
    identity = value["institution"]["identity"]
    if identity["kind"] in ("address", "record"):
        need(any(hex_bytes(identity["value"], 20 if identity["kind"] == "address" else 32)),
             "institution identity commitment missing")
    else:
        _iri(identity["value"])
        need(identity["value"].startswith("did:"), "institution DID required")
    for reference in (value["institution"]["reference"], value["venue"]["location"],
            value["title"]["reference"], *value["catalogues"], *value["wallLabels"]):
        _reference(reference)
    for parameter in value["displayParameters"]:
        _iri(parameter["parameter"])
        _reference(parameter["reference"])
    if value["artistIntent"] is not None:
        need(value["artistIntent"]["recordHash"] != ZERO, "Artist intent record commitment missing")
        _reference(value["artistIntent"]["reference"])
    bounds = [_date(value[name]) for name in ("opening", "closing")]
    if all(bounds) and value["opening"]["earliest"] is not None and value["closing"]["latest"] is not None:
        need(_instant(value["opening"]["earliest"]) <= _instant(value["closing"]["latest"]),
             "closing precedes opening")
    return value, bounds


class OwnerExhibitionSource(OwnerRecordSource):
    """Exact selected public owner lane; original base source semantics are intact."""

    profile = SOURCE_PROFILE
    families = (FAMILY,)

    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        super().__init__(anchor_bytes, transport, provenance=provenance)
        self.collection_identities = {}

    def _identity(self, token):
        token = str(uint(str(token)))
        if token not in self.collection_identities:
            _, values = self._read(self.a["core"], "tokenCollectionIdentity(uint256)",
                ("uint256",), (uint(token),), ("bool", "uint256", "uint256", "bool"))
            exists, collection, serial, burned = values
            need(exists and collection > 0 and serial > 0, "permanent token collection identity missing")
            self.collection_identities[token] = {"mappingExists": exists, "collectionId": str(collection),
                "collectionSerial": str(serial), "burned": burned,
                "subjectId": subject_id("token", self.a["chainId"], self.a["core"], str(collection), token_id=token)}
        return self.collection_identities[token]

    def _public_record(self, record, receipt):
        record, receipt = json_values(record), json_values(receipt)
        need(record[0] == FAMILY and record[2] == schema_id(NAME)
            and receipt[9] == SCHEMA_HASH and receipt[10] == keccak256(JCS_BYTES)
            and record[3][0] == "1" and record[3][2] == JCS_ID,
            "exact public EXHIBITION/schema/JCS required")
        raw = hex_bytes(record[5])
        need(keccak256(raw) == record[3][1], "embedded payload commitment differs")
        value, bounds = validate_payload(raw)
        identity = self._identity(receipt[0])
        need(value["subject"]["tokenId"] == receipt[0]
            and value["subject"]["collectionId"] == identity["collectionId"]
            and record[1] == identity["subjectId"], "original token/collection subject differs")
        return value, bounds, identity

    def _definitions(self):
        self._document(schema_id(NAME), 0, SCHEMA_HASH)
        self._document(JCS_ID, 1, keccak256(JCS_BYTES))
        _, schema, schema_view = self.documents[schema_id(NAME)]
        _, canonical, canonical_view = self.documents[JCS_ID]
        need(schema == SCHEMA_BYTES and schema_view[3][3] == JCS_ID
            and canonical == JCS_BYTES and canonical_view[3][3] == RAW_BYTES,
            "exact registered exhibition schema/JCS bytes required")

    def _validate_predecessor(self, record, receipt):
        # The base authenticates its native hash, token/family and immediate index.
        # Reject nonpublic payloads before a successful snapshot can be retained.
        self._public_record(record, receipt)
        self._definitions()

    def _capture_extra(self, records):
        for row in records.values():
            self._public_record(row["record"], row["receipt"])
        if records:
            self._definitions()
        return {"collectionIdentities": dict(sorted(self.collection_identities.items(), key=lambda row: uint(row[0]))),
            "selectedPublicExhibitionRecords": str(len(records)),
            "immediatePredecessors": "public_schema_checked_retention_only",
            "qualification": QUALIFICATION}


def selector(source, saved):
    record, receipt = saved["record"], saved["receipt"]
    return {"host": source.a["host"], "recordHash": saved["recordHash"], "subjectId": record[1],
        "schemaId": record[2], "schemaHash": receipt[9], "recordType": record[0], "owner": receipt[1],
        "recordIndex": receipt[3], "recordChainHash": receipt[4], "pointer": ""}


def admit(source, selected):
    """Pure admission over a captured source; synthetic wire controls remain explicit."""
    need(type(selected) is list and len(selected) <= MAX_RECORDS, "selected record bound")
    rows, seen, identities = [], set(), {}
    for digest in selected:
        need(any(hex_bytes(digest, 32)) and digest not in seen, "duplicate/invalid selected record")
        seen.add(digest)
        need(digest in source.records, "selected owner exhibition record missing")
        saved = source.records[digest]
        value, bounds, identity = source._public_record(saved["record"], saved["receipt"])
        _declarations(value, identities)
        rows.append({"source": selector(source, saved), "original": saved, "authority": saved["authority"],
            "value": value, "datesSupported": bounds, "collectionIdentity": identity})
    return sorted(rows, key=lambda row: row["source"]["recordHash"])


def render(rows, model):
    files, resources, provenance, sidecar, coverage, dispositions = {}, [], [], [], [], []

    def named(identifier, kind, name):
        return {"@context": CONTEXT, "id": identifier, "type": kind, "_label": name["value"],
            "identified_by": [{"type": "Name", "content": name["value"]}],
            "referred_to_by": [{"type": "LinguisticObject", "content": QUALIFICATION}]}

    def emit(value, row, rule, source_paths):
        raw = dumps(value)
        result = model.validate_and_expand(raw)
        key = keccak256(value["id"].encode("utf-8"))[2:]
        path = "exhibitions/resources/" + key + ".json"
        if path in files:
            need(files[path] == raw, "conflicting shared resource output")
        else:
            files[path] = raw
            files["exhibitions/expanded/" + key + ".json"] = result.expanded_bytes
            resources.append({"id": value["id"], "type": value["type"], "path": path})
        for pointer, scalar in fields(value):
            provenance.append({"entity": value["id"], "path": pointer, "value": scalar,
                "source": row["source"], "sourcePaths": source_paths, "rule": RULE + rule,
                "qualification": QUALIFICATION})

    for row in rows:
        value, source = row["value"], row["source"]
        sidecar.append({"source": source, "sourcePayloadHash": row["original"]["record"][3][1],
            "authority": row["authority"], "original": row["original"], "exhibition": value,
            "collectionIdentity": row["collectionIdentity"], "qualification": QUALIFICATION,
            "referenceStatus": "described_only; original commitments retained, bytes not retrieved",
            "institutionIdentity": "owner-attributed claim; address/DID/record is not verified Group equivalence"})
        coverage.extend({"source": source, "sourcePath": pointer, "value": scalar,
            "disposition": "retained_stream_only", "sidecarRecord": str(len(sidecar) - 1)}
            for pointer, scalar in fields(value))
        missing = [name + "_name_not_recorded" for name, declaration in (
            ("title", value["title"]), ("institution", value["institution"]), ("venue", value["venue"]))
            if declaration["name"] is None]
        disposition = "nonperformed_source" if value["status"] != "completed" else "unsupported" if missing else "activity"
        dispositions.append({"source": source, "exhibitionId": value["exhibitionId"],
            "sourceStatus": value["status"], "disposition": disposition, "reasons": missing})
        if disposition != "activity":
            continue
        institution = named(value["institution"]["entityId"], "Group", value["institution"]["name"])
        venue = named(value["venue"]["entityId"], "Place", value["venue"]["name"])
        event = named(value["exhibitionId"], "Activity", value["title"]["name"])
        event["participant"] = [{"id": institution["id"], "type": "Group"}]
        event["took_place_at"] = [{"id": venue["id"], "type": "Place"}]
        span = {"type": "TimeSpan", "identified_by": [{"type": "Name",
            "content": value["opening"]["expression"] + " / " + value["closing"]["expression"]}]}
        for index, name, targets in ((0, "opening", ("begin_of_the_begin", "end_of_the_begin")),
                (1, "closing", ("begin_of_the_end", "end_of_the_end"))):
            date = value[name]
            if row["datesSupported"][index] and date["earliest"] is not None:
                span[targets[0]], span[targets[1]] = date["earliest"], date["latest"]
        event["timespan"] = span
        emit(institution, row, "entity", ["/institution"])
        emit(venue, row, "entity", ["/venue"])
        emit(event, row, "activity", ["/exhibitionId", "/status", "/title", "/institution",
            "/venue", "/opening", "/closing"])
    status = "unsupported" if not rows else "incomplete" if any(
        row["disposition"] == "unsupported" for row in dispositions) else "complete_with_stream_extensions"
    files["exhibitions/index.json"] = dumps({"resources": sorted(resources, key=lambda row: row["id"])})
    files["exhibitions/sidecar.json"] = dumps(sidecar)
    files["exhibitions/coverage.json"] = dumps(coverage)
    files["exhibitions/provenance.json"] = dumps(provenance)
    files["exhibitions/report.json"] = dumps({"mode": MODE, "version": "1", "profileHash": PROFILE_HASH,
        "validationPolicyHash": VALIDATION_HASH, "status": status,
        "reasonCode": "no_selected_owner_exhibition_records" if not rows else None,
        "dispositions": dispositions, "activities": str(sum(row["disposition"] == "activity" for row in dispositions)),
        "sourceValuesRetained": str(len(coverage)), "claims": CLAIMS, "qualification": QUALIFICATION})
    return files


def project_owner_exhibitions(source, selected, *, source_hash, profile_hash, model):
    need(type(source) is OwnerExhibitionSource and source.provenance == "trusted_rpc",
         "concrete recorded owner exhibition source required")
    need(profile_hash == PROFILE_HASH, "external profile pin differs")
    need(type(selected) is list and 0 < len(selected) <= MAX_RECORDS,
         "nonempty selected record bound")
    need(keccak256(source.snapshot()) == source_hash, "external owner snapshot pin differs")
    rows = admit(source, selected)
    need(set(selected) == set(source.records), "selected records must equal captured public records")
    return render(rows, model)
