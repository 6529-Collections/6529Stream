"""Concrete General-to-General semantic review capture, separate from direct V1."""
from copy import deepcopy
from .account_profile import ACCOUNT_PREFIX, JCS_ID, account_iri
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_rpc import MAX_TRANSCRIPT, RecordingReader, ReplayTransport, RpcTransport
from .general_attestation_source import CURATORIAL, ESTATE, INSTITUTIONAL
from .general_attestation_source_v2 import GeneralAttestationSourceV2, MAX_PAYLOAD
from .general_publication_v1 import GeneralPublicationAdapterV1
from .general_review_profile_v1 import (ASSERTION_NAME, ASSERTION_SCHEMA_BYTES, BODY_SCHEMA_BYTES,
    CLAIMS, GeneralSemanticReviewProfileV1, PROFILE_SCHEMA_NAME, QUALIFICATION,
    REVIEW_DATATYPE, REVIEW_MAPPING_RULE, REVIEW_RELATION)
from .general_semantic_source_v1 import COMMON, GeneralSemanticSourceV1, _authority, _consistent, selector
from .independent_wire import ZERO, require
from .recorded_semantic import resolve_pointer
from .review import _validate

NAME = "STREAM_MUSEUM_GENERAL_SEMANTIC_SOURCE_V2"
PROFILE_BYTES = dumps({"name": NAME, "version": "2", "interpretation": GeneralSemanticReviewProfileV1.name,
    "source": "Complete concrete General V2 catalogues, native hashes, retained signatures, original operator grants and exact publication adapter.",
    "scope": "General-to-General documentary and review references. Other profiles remain original unsupported rows; no implicit V1 review upgrade.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)

# Validate the envelope and each original assertion separately. Together these
# are the exact registered schema, but a malformed unselected assertion cannot
# veto another authenticated assertion in the same original record.
_schema = loads(ASSERTION_SCHEMA_BYTES, maximum=MAX_PAYLOAD)
_outer = deepcopy(_schema)
_outer["properties"]["assertions"]["items"] = {"type": "string"}
ENVELOPE_SCHEMA_BYTES = dumps(_outer)
ONE_ASSERTION_SCHEMA_BYTES = dumps({"$schema": _schema["$schema"], "$defs": _schema["$defs"],
    **_schema["$defs"]["assertion"]})


def _diagnostic(row, reason, diagnostics, index=None):
    reference = row["source"] if index is None else {**row["source"], "pointer": "/assertions/" + str(index)}
    diagnostics.append({"source": reference, "reason": reason,
        "scope": "record" if index is None else "assertion"})
    if index is None: row.update(status="semantic_invalid", reasonCode=reason)
    else: row["ineligibleAssertionIndices"].append(index)


def admission(row, anchor):
    """Exact historical principal and scope, independent of asserted display labels."""
    source, authority = row["source"], row["authority"]
    return {"principal": authority["assertingAccount"], "collectionId": anchor["collectionId"],
        "subjectId": source["subjectId"], "recordType": source["recordType"],
        "verificationClass": source["verificationClass"], "authorityQualification": source["authorityQualification"],
        "grantRevision": authority["grantRevision"]}


class GeneralSemanticSourceV2:
    _read, _block = GeneralSemanticSourceV1._read, GeneralSemanticSourceV1._block
    _chunk, _document = GeneralSemanticSourceV1._chunk, GeneralSemanticSourceV1._document
    _definitions = GeneralSemanticSourceV1._definitions

    def __init__(self, general, publications, transport, *, profile=None):
        require(type(general) is GeneralAttestationSourceV2 and type(publications) is GeneralPublicationAdapterV1
            and publications.source is general, "exact concrete General source/publication pair required")
        require(publications.provenance == general.provenance, "General review provenance differs")
        require(general.provenance != "trusted_rpc" or type(transport) in (RpcTransport, ReplayTransport),
            "synthetic General semantics cannot authenticate state")
        self.general, self.publications = general, publications
        self.a, self.pins, self.anchor_bytes = general.a, dict(general.pins), general.anchor_bytes
        self.provenance = general.provenance
        self.profile = profile or GeneralSemanticReviewProfileV1()
        require(type(self.profile) is GeneralSemanticReviewProfileV1, "exact General review profile required")
        self.reader = RecordingReader(transport, self.a["blockHash"])
        self.documents, self.document_stack, self.chunks = {}, set(), {}
        self.document_bytes, self._started, self._snapshot = 0, False, None

    def transcript(self):
        require(self._snapshot is not None, "General review snapshot required")
        return self.reader.transcript()

    def snapshot(self):
        if self._snapshot is not None: return self._snapshot
        require(not self._started, "failed General review capture cannot resume")
        self._started = True
        try: return self._capture()
        except MuseumError: raise
        except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
            raise MuseumError("malformed General review evidence") from exc

    def _capture(self):
        original_raw, publication_raw = self.general.snapshot(), self.publications.snapshot()
        original = loads(original_raw, maximum=MAX_TRANSCRIPT, canonical=True)
        published = loads(publication_raw, maximum=MAX_TRANSCRIPT, canonical=True)
        originals = {r["recordHash"]: r for r in original["records"]}
        positions = {r["recordHash"]: r for r in published["publications"]}
        grants = {r["recordHash"]: r for r in published["curatorGrants"]}
        self._block()
        for key in ("schemas", "store"):
            code = hex_bytes(self.reader.code(self.a[key]))
            require(0 < len(code) <= 24576 and keccak256(code) == self.pins[self.a[key]], "General review runtime differs")
        statements, semantic_diagnostics, checked = [], [], False
        for native in original["records"]:
            value, receipt = native["value"], native["receipt"]
            row = {"source": selector(native, self.a), "original": native, "authority": _authority(native, self.a),
                "publication": positions[native["recordHash"]], "grantEvidence": grants.get(native["recordHash"]),
                "status": "unsupported", "reasonCode": "family_schema_or_profile_unsupported", "value": None,
                "sourceRecords": [], "ineligibleAssertionIndices": []}
            statements.append(row)
            if value[3] not in (INSTITUTIONAL, ESTATE, CURATORIAL) or value[5] != schema_id(ASSERTION_NAME) or value[6] != JCS_ID:
                continue
            payload = hex_bytes(native["payloadHex"])
            try:
                parsed = loads(payload, maximum=MAX_PAYLOAD, canonical=True)
                require(type(parsed) is dict, "General semantic envelope must be an object")
            except MuseumError as exc:
                _diagnostic(row, str(exc), semantic_diagnostics); continue
            if parsed.get("profileHash") != self.profile.profile_hash: continue
            # This is external interpretation-document authentication, not a
            # semantic opinion from the record writer: failures remain fatal.
            if not checked: self._definitions(); checked = True
            require(receipt[11] == keccak256(ASSERTION_SCHEMA_BYTES)
                and receipt[12] == keccak256(self.profile.documents["RFC8785_JCS"][1]) and receipt[13] == ZERO,
                "General review original definition commitments differ")
            try:
                envelope = deepcopy(parsed)
                if type(envelope.get("assertions")) is list:
                    envelope["assertions"] = ["" for _ in envelope["assertions"]]
                _validate(ENVELOPE_SCHEMA_BYTES, dumps(envelope))
                subject = native["subject"]
                require(type(subject) is list and len(subject) == 4 and uint(subject[0], 8) in (0, 1, 2), "General semantic subject missing")
                require(parsed["profileSchemaId"] == schema_id(PROFILE_SCHEMA_NAME)
                    and parsed["anchorSubject"] == {"kind": ("collection", "token", "media")[uint(subject[0])], "subjectId": value[2]},
                    "General review enclosing subject/profile differs")
                issuer = account_iri(self.a["chainId"], receipt[0])
                require(all(e["declaringAgent"] == issuer and not e["id"].casefold().startswith(ACCOUNT_PREFIX)
                    for e in parsed["entities"]), "General declaring account impersonation")
                references = [*parsed["sourceRecords"], *(r for e in parsed["entities"] for r in e["sourceRecords"])]
                for reference in references:
                    key = reference["recordHash"]; previous = originals.get(key)
                    require(previous is not None and reference == selector(previous, self.a, reference["pointer"]), "General documentary selector differs")
                    require(tuple(map(uint, positions[key]["publicationPosition"])) < tuple(map(uint, row["publication"]["publicationPosition"])),
                        "General documentary source must precede publication")
                    resolve_pointer(hex_bytes(previous["payloadHex"]), reference["pointer"])
                    row["sourceRecords"].append({"source": reference, "publication": positions[key], "payloadHash": previous["value"][8]})
            except MuseumError as exc:
                row["value"] = parsed
                _diagnostic(row, str(exc), semantic_diagnostics); continue
            row.update(status="supported", reasonCode=None, value=parsed)
            ids = {}
            for index, assertion in enumerate(parsed["assertions"]):
                try:
                    _validate(ONE_ASSERTION_SCHEMA_BYTES, dumps(assertion))
                    require(assertion["assertingAgent"] == issuer, "General asserting account impersonation")
                    ids.setdefault(assertion["id"], []).append(index)
                    for evidence in assertion["evidence"]:
                        require(evidence["basis"] == "documentary_evidence" and evidence["selectorType"] in ("whole_document", "json_pointer")
                            and (evidence["selectorType"] != "whole_document" or evidence["selector"] == ""), "General evidence basis/selector unsupported")
                        matches = [originals[r["recordHash"]] for r in parsed["sourceRecords"]
                            if evidence["source"] == {"algorithm": "1", "digest": originals[r["recordHash"]]["value"][8],
                                "canonicalizationId": originals[r["recordHash"]]["value"][6]}]
                        require(matches, "General evidence is not an exact referenced payload")
                        for previous in matches: resolve_pointer(hex_bytes(previous["payloadHex"]), evidence["selector"])
                except MuseumError as exc:
                    _diagnostic(row, str(exc), semantic_diagnostics, index)
            for duplicates in ids.values():
                if len(duplicates) > 1:
                    for index in duplicates:
                        if index not in row["ineligibleAssertionIndices"]:
                            _diagnostic(row, "duplicate General assertion ID", semantic_diagnostics, index)
        assertions = {}
        for row in statements:
            if row["status"] != "supported": continue
            for index, assertion in enumerate(row["value"]["assertions"]):
                if index in row["ineligibleAssertionIndices"]: continue
                ref = {**row["source"], "pointer": "/assertions/" + str(index)}
                assertions[dumps(ref)] = (ref, assertion, row)
        # Native receipts, headers and registered definitions above remain fatal.
        # Semantic review failures cannot let an unselected account veto others.
        reviews, invalid, dependencies = [], {}, {}
        for ref, assertion, row in assertions.values():
            if assertion["relation"] != REVIEW_RELATION: continue
            try:
                require(assertion["origin"] == "direct_statement" and assertion["mappingRule"] == REVIEW_MAPPING_RULE,
                    "General review statement type differs")
                literal = assertion["object"].get("literal")
                require(type(literal) is dict and literal["datatype"] == REVIEW_DATATYPE
                    and all(literal[k] is None for k in ("language", "unit", "precision")), "General review literal type differs")
                body = _validate(BODY_SCHEMA_BYTES, literal["lexicalValue"].encode("utf-8"))
                target = assertions.get(dumps(body["assertionRecord"]))
                require(target is not None, "General review target absent or unsupported")
                target_ref, target_assertion, target_row = target
                require(body["assertionRevisionHash"] == keccak256(dumps(target_assertion))
                    and body["profileHash"] == target_row["value"]["profileHash"]
                    and body["mappingRule"] == target_assertion["mappingRule"]
                    and body["targetAuthority"] == admission(target_row, self.a)
                    and assertion["subject"] == target_assertion["id"], "General review exact target binding differs")
                require(row["original"]["subject"] == target_row["original"]["subject"]
                    and row["original"]["value"][1] == target_row["original"]["value"][1],
                    "General review own native subject scope differs from target")
                require(tuple(map(uint, target_row["publication"]["publicationPosition"])) < tuple(map(uint, row["publication"]["publicationPosition"])),
                    "General review must follow original publication")
                reviews.append({"source": ref, "target": target_ref, "body": body,
                    "reviewer": row["authority"]["assertingAccount"], "reviewedAt": assertion["createdAt"],
                    "reviewStatus": assertion["reviewStatus"], "authority": admission(row, self.a),
                    "selfReview": row["authority"]["assertingAccount"] == target_row["authority"]["assertingAccount"],
                    "publication": row["publication"]})
                dependencies.setdefault(dumps(target_ref), set()).add(dumps(ref))
            except MuseumError as exc:
                invalid[dumps(ref)] = str(exc)
        for ref, assertion, row in assertions.values():
            for backlink in assertion["reviewEvidence"]:
                try:
                    matches = [r for r in reviews if r["source"] == backlink["reviewRecord"] and r["target"] == backlink["assertionRecord"]]
                    require(len(matches) == 1, "General review backlink unavailable")
                    r = matches[0]
                    require(backlink == {"reviewRecord": r["source"], **{k: r["body"][k] for k in
                        ("assertionRecord", "assertionRevisionHash", "profileHash", "mappingRule", "targetAuthority")},
                        "reviewer": r["reviewer"], "reviewedAt": r["reviewedAt"], "selfReview": r["selfReview"]},
                        "General review backlink differs from original")
                    review_row = assertions[dumps(r["source"])][2]
                    require(tuple(map(uint, review_row["publication"]["publicationPosition"])) < tuple(map(uint, row["publication"]["publicationPosition"]))
                        and review_row["original"]["subject"] == row["original"]["subject"],
                        "General review backlink must follow review in the same native subject scope")
                    dependencies.setdefault(dumps(r["source"]), set()).add(dumps(ref))
                except MuseumError as exc:
                    invalid[dumps(ref)] = str(exc)
        # A review of an ineligible target, or a backlink to an ineligible
        # review, cannot become eligible through a dependent later statement.
        pending = list(invalid)
        while pending:
            key = pending.pop()
            for dependent in dependencies.get(key, ()):
                if dependent not in invalid:
                    invalid[dependent] = "referenced General review/assertion is semantically ineligible"
                    pending.append(dependent)
        diagnostics = semantic_diagnostics + [{"source": assertions[key][0], "reason": invalid[key], "scope": "assertion"}
            for key in sorted(invalid)]
        reviews = [r for r in reviews if dumps(r["source"]) not in invalid]
        self._block()
        if type(self.reader.transport) is ReplayTransport: self.reader.transport.finish()
        _consistent([self.general.transcript(), self.publications.reader.transcript(), self.reader.transcript()], self.pins)
        result = dumps({"profile": NAME, "profileHash": PROFILE_HASH, "version": "2", "provenance": self.provenance,
            "interpretationProfileHash": self.profile.profile_hash, "interpretationDocumentsChecked": checked,
            "sourceState": {k: self.a[k] for k in COMMON}, "host": self.a["host"], "anchorHash": keccak256(self.anchor_bytes),
            "generalSourceHash": keccak256(original_raw), "publicationHash": keccak256(publication_raw),
            "transcriptHash": keccak256(self.reader.transcript()), "statements": statements, "reviews": reviews, "ineligibleAssertions": diagnostics,
            "catalogue": original["catalogue"], "lanes": original["lanes"],
            "documents": [{"documentId": key, "rawViewHex": "0x" + view.hex(), "payloadHex": "0x" + raw.hex()}
                for key, (view, raw, _) in sorted(self.documents.items())], "claims": CLAIMS, "qualification": QUALIFICATION})
        require(len(result) <= MAX_TRANSCRIPT, "General semantic output bound")
        self._snapshot = result; return result
