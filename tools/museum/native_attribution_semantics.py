"""Exact native Artist assertion and reviewer joins under a new explicit profile."""
from .account_profile import ACCOUNT_PREFIX, ASSERTION_SCHEMA_BYTES, JCS_ID, account_iri
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_abi import decode, encode
from .chain_rpc import MAX_TRANSCRIPT, RecordingReader, ReplayTransport, RpcTransport
from .independent_source import IndependentSourceAdapter
from .independent_wire import RAW_BYTES, RECORD, ZERO, json_values, require
from .owner_catalog_source import _position
from .native_attribution_profile import CLAIMS, NAME, QUALIFICATION, NativeAttributionProfile
from .owner_notice_semantics import consistent_reads
from .recorded_semantic import resolve_pointer
from .review import BODY_SCHEMA_BYTES, REVIEW_DATATYPE, REVIEW_MAPPING_RULE, REVIEW_RELATION, _validate
from .schemas import NAMES

PROFILE = "STREAM_MUSEUM_NATIVE_ATTRIBUTION_SEMANTICS_V1"
CLASS = {1: "ARTIST_SIGNER", 3: "CURATOR_SIGNER", 4: "INSTITUTION_SIGNER",
    6: "PRESERVATION_ADMIN", 7: "METADATA_ADMIN", 8: "GLOBAL_ADMIN"}


def selector(row, host, pointer=""):
    record, receipt = row["record"], row["receipt"]
    return {"recordHash": row["recordHash"], "subjectId": record[1], "schemaId": record[4],
        "schemaHash": receipt[6], "recordType": record[0], "host": host, "recorder": receipt[1],
        "authorizationClass": CLASS[uint(receipt[2])], "recordIndex": receipt[4],
        "recordChainHash": receipt[5], "pointer": pointer}


def _assertions(snapshot):
    result = {}
    for row in snapshot["statements"]:
        if row["status"] != "supported":
            continue
        for index, value in enumerate(row["value"]["assertions"]):
            key = {**row["source"], "pointer": "/assertions/" + str(index)}
            result[dumps(key)] = (key, value, row)
    return result


def _metadata_positions(transcript, originals, host):
    """Use the already verified complete Artist history, including other voices."""
    from .artist_attestation_source import METADATA_RECORDED
    positions, seen = {}, set()
    for call in loads(transcript, maximum=MAX_TRANSCRIPT, canonical=True)["calls"]:
        if call["method"] != "eth_getTransactionReceipt":
            continue
        receipt = call["result"]
        if receipt["transactionHash"] in seen:
            continue
        seen.add(receipt["transactionHash"])
        for log in receipt["logs"]:
            if log["address"] != host or not log["topics"] or log["topics"][0] != METADATA_RECORDED:
                continue
            values = decode((RECORD, "bytes32", "bytes32", "address", "bytes32", "uint16"),
                hex_bytes(log["data"]), maximum=65536)
            original = originals.get(values[1])
            if original is None:
                continue
            record, admission = original["record"], original["receipt"]
            require(values[1] not in positions and json_values(values[0]) == record
                and values[2:5] == (admission[5], admission[1], "0x" + uint(admission[2]).to_bytes(32, "big").hex())
                and values[5] == 1 and log["topics"][1:] == ["0x" + encode(("uint256",), (uint(admission[0]),)).hex(), record[0], record[1]],
                "native attribution referenced publication differs")
            positions[values[1]] = _position(log)
    return positions


def select(snapshot, policy_raw, policy_hash):
    """Select attributed assertions; independent human review is never inferred."""
    require(keccak256(policy_raw) == policy_hash, "native attribution external selection pin differs")
    policy = loads(policy_raw, maximum=524288, canonical=True)
    require(type(policy) is dict and set(policy) == {"profile", "sourceSnapshotHash", "sourceAuthoritySet",
        "reviewerAuthoritySet", "singleValuedRelations", "allowSelfReview", "independentHumanReviewRequired"}
        and policy["profile"] == PROFILE and policy["sourceSnapshotHash"] == keccak256(dumps(snapshot))
        and type(policy["allowSelfReview"]) is bool and type(policy["independentHumanReviewRequired"]) is bool,
        "native attribution selection shape/source")
    require(not policy["independentHumanReviewRequired"], "independent human review unavailable")
    for name in ("sourceAuthoritySet", "reviewerAuthoritySet", "singleValuedRelations"):
        values = policy[name]
        require(type(values) is list and len(values) <= 512 and len({dumps(v) for v in values}) == len(values),
            "native attribution selection duplicate/bound")
    require(all(type(v) is str for v in policy["singleValuedRelations"]), "native attribution relation shape")
    assertions = _assertions(snapshot)
    sources, reviewers = {}, {}
    for name, target in (("sourceAuthoritySet", sources), ("reviewerAuthoritySet", reviewers)):
        for value in policy[name]:
            key = dumps(value)
            require(key in assertions, "native attribution selected original selector absent")
            target[key] = assertions[key]
    dispositions, review_rows, diagnostics = {key: [] for key in sources}, [], []
    for key, (reference, review, row) in reviewers.items():
        require(review["relation"] == REVIEW_RELATION and review["mappingRule"] == REVIEW_MAPPING_RULE
            and review["origin"] == "direct_statement", "native attribution selected review type")
        literal = review["object"].get("literal")
        require(type(literal) is dict and literal["datatype"] == REVIEW_DATATYPE
            and all(literal[name] is None for name in ("language", "unit", "precision")), "native attribution review literal")
        body = _validate(BODY_SCHEMA_BYTES, literal["lexicalValue"].encode("utf-8"))
        original_key = dumps(body["assertionRecord"])
        require(original_key in assertions, "native attribution review original unavailable")
        original_selector, original, original_row = assertions[original_key]
        require(body["assertionRevisionHash"] == keccak256(dumps(original))
            and body["profileHash"] == original_row["value"]["profileHash"]
            and body["mappingRule"] == original["mappingRule"] and review["subject"] == original["id"],
            "native attribution review revision/profile/rule differs")
        require(tuple(map(uint, original_row["publicationPosition"])) < tuple(map(uint, row["publicationPosition"])),
            "native attribution review does not follow original")
        old, new = original_row["historicalAuthority"], row["historicalAuthority"]
        same_artist = old["artistId"] == new["artistId"]
        same_account = old["signer"] == new["signer"]
        self_review = same_artist or same_account
        resolved = {"reviewRecord": reference, "assertionRecord": original_selector,
            "assertionRevisionHash": body["assertionRevisionHash"], "profileHash": body["profileHash"],
            "mappingRule": body["mappingRule"], "reviewer": review["assertingAgent"],
            "reviewedAt": review["createdAt"], "selfReview": self_review,
            "sameArtistIdentity": same_artist, "sameSigningAccount": same_account,
            "independentHumanReviewProven": False, "disposition": body["disposition"],
            "historicalAuthority": new, "currentQualification": row["currentQualification"]}
        # A backlink is not approval. If supplied it must agree with the reviewer's own original statement.
        for backlink in original["reviewEvidence"]:
            if backlink["reviewRecord"] == reference:
                require(all(backlink[name] == resolved[name] for name in backlink), "native attribution forged reviewer backlink")
        review_rows.append(resolved)
        if original_key not in sources:
            diagnostics.append({"source": reference, "reason": "review_target_unselected"})
        elif not self_review:
            diagnostics.append({"source": reference, "reason": "distinct_protocol_identities_do_not_establish_qualified_review"})
        elif not policy["allowSelfReview"]:
            diagnostics.append({"source": reference, "reason": "SELF_review_not_enabled"})
        elif review["reviewStatus"] in ("disputed", "withdrawn"):
            diagnostics.append({"source": reference, "reason": "review_revision_disputed_or_withdrawn"})
        else:
            dispositions[original_key].append(resolved)
    selected, withheld = [], []
    for key, (reference, assertion, row) in sorted(sources.items()):
        reviews = dispositions[key]
        reasons = []
        direct = assertion["origin"] == "direct_statement"
        if assertion["reviewStatus"] in ("disputed", "withdrawn"):
            reasons.append("selected_original_revision_disputed_or_withdrawn")
        if not direct:
            if not any(r["disposition"] == "reviewed" for r in reviews): reasons.append("mapping_requires_selected_SELF_confirmation")
            if any(r["disposition"] == "rejected" for r in reviews): reasons.append("selected_SELF_review_rejected")
        result = {"source": reference, "assertion": assertion, "historicalAuthority": row["historicalAuthority"],
            "currentQualification": row["currentQualification"], "basis": "historical_native_direct_statement" if direct else "explicit_artist_SELF_confirmation",
            "reviews": reviews, "reasons": reasons}
        (withheld if reasons else selected).append(result)
    groups = {}
    for row in selected:
        assertion = row["assertion"]
        if assertion["relation"] in policy["singleValuedRelations"]:
            groups.setdefault((assertion["subject"], assertion["relation"]), []).append(row)
    conflicted = set()
    for group in groups.values():
        if len({dumps(row["assertion"]["object"]) for row in group}) > 1:
            for row in group:
                row["reasons"].append("conflicting_selected_source_values"); conflicted.add(dumps(row["source"]))
    withheld.extend(row for row in selected if dumps(row["source"]) in conflicted)
    selected = [row for row in selected if dumps(row["source"]) not in conflicted]
    return {"profile": PROFILE, "policyHash": policy_hash, "selected": selected, "withheld": withheld,
        "reviews": review_rows, "diagnostics": diagnostics, "claims": CLAIMS, "qualification": QUALIFICATION}


class NativeAttributionSemanticSource:
    _read = IndependentSourceAdapter._read
    _block = IndependentSourceAdapter._block
    _chunk = IndependentSourceAdapter._chunk
    _document = IndependentSourceAdapter._document

    def __init__(self, artist, transport, *, profile=None):
        from .artist_attestation_source import ArtistAttestationSource
        require(type(artist) is ArtistAttestationSource, "concrete native Artist source required")
        require(artist.provenance != "trusted_rpc" or type(transport) in (RpcTransport, ReplayTransport),
            "synthetic semantic transport cannot become trusted")
        self.artist, self.catalogue = artist, artist.metadata_catalog
        self.a, self.pins, self.anchor_bytes = self.catalogue.a, self.catalogue.pins, self.catalogue.anchor_bytes
        self.provenance = artist.provenance
        self.profile = profile or NativeAttributionProfile()
        require(type(self.profile) is NativeAttributionProfile, "exact native attribution profile required")
        self.reader = RecordingReader(transport, self.a["blockHash"])
        self.documents, self.document_stack, self.chunks = {}, set(), {}
        self.document_bytes, self._started, self._snapshot = 0, False, None

    def transcript(self):
        require(self._snapshot is not None, "native attribution snapshot required")
        return self.reader.transcript()

    def snapshot(self):
        if self._snapshot is not None: return self._snapshot
        require(not self._started, "failed native attribution semantics cannot resume")
        self._started = True
        try: return self._capture()
        except MuseumError: raise
        except (ValueError, TypeError, IndexError, KeyError, OverflowError) as exc:
            raise MuseumError("malformed native attribution semantic evidence") from exc

    def _capture(self):
        raw_artist = self.artist.snapshot()
        artist = loads(raw_artist, maximum=MAX_TRANSCRIPT, canonical=True)
        catalogue = loads(self.catalogue.snapshot(), maximum=MAX_TRANSCRIPT, canonical=True)
        originals = {row["recordHash"]: row for row in catalogue["records"]}
        positions = _metadata_positions(self.artist.transcript(), originals, self.a["host"])
        self._block()
        for name in ("schemas", "store"):
            require(keccak256(hex_bytes(self.reader.code(self.a[name]))) == self.pins[self.a[name]], "native attribution runtime differs")
        rows, documents_checked = [], False
        for native in artist["attestations"]:
            original = native["metadataOriginal"]
            record, receipt = original["record"], original["receipt"]
            row = {"source": selector(original, self.a["host"]), "original": original,
                "nativeEvidenceRecordHash": native["attestationRecordHash"], "historicalAuthority": native["historicalAuthority"],
                "currentQualification": native["current"], "status": "unsupported", "reasonCode": "source_schema_or_profile_unsupported",
                "payloadHex": original["payloadHex"], "value": None,
                "publicationPosition": [native["metadataPublicationPosition"][key]
                    for key in ("blockNumber", "transactionIndex", "logIndex")]}
            rows.append(row)
            if record[0] != schema_id("ARTIST_SEMANTIC_ASSERTION") or record[4] != schema_id(NAMES[1]) or record[2][2] != JCS_ID:
                continue
            payload = hex_bytes(original["payloadHex"])
            value = _validate(ASSERTION_SCHEMA_BYTES, payload)
            if value["profileHash"] != self.profile.profile_hash:
                continue
            if not documents_checked:
                for name, (kind, raw) in self.profile.documents.items():
                    identifier = schema_id(name); self._document(identifier, kind)
                    _, actual, view = self.documents[identifier]
                    require(actual == raw and view[3][2] == keccak256(raw)
                        and view[3][3] == (RAW_BYTES if identifier == JCS_ID else JCS_ID) and view[3][4] == ZERO,
                        "native attribution registered schema/profile bytes differ")
                documents_checked = True
            require(receipt[6] == keccak256(ASSERTION_SCHEMA_BYTES)
                and receipt[7] == keccak256(self.profile.documents["RFC8785_JCS"][1]), "native attribution receipt definition differs")
            require(value["profileSchemaId"] == schema_id(NAMES[0]) and value["anchorSubject"] == {
                "kind": "collection" if original["subjectKind"] == "collection" else "token", "subjectId": record[1]},
                "native attribution semantic subject/profile differs")
            issuer = account_iri(self.a["chainId"], native["historicalAuthority"]["signer"])
            require(issuer == account_iri(self.a["chainId"], receipt[1]), "native attribution original recorder differs")
            priors = []
            for reference in [*value["sourceRecords"], *(s for entity in value["entities"] for s in entity["sourceRecords"])]:
                previous = originals.get(reference["recordHash"])
                require(previous is not None and reference == selector(previous, self.a["host"], reference["pointer"]),
                    "native attribution original source selector differs")
                require(previous["recordHash"] in positions and positions[previous["recordHash"]] < positions[original["recordHash"]],
                    "native attribution evidence must precede publication")
                resolve_pointer(hex_bytes(previous["payloadHex"]), reference["pointer"])
            for reference in value["sourceRecords"]:
                priors.append(originals[reference["recordHash"]])
            require(all(entity["declaringAgent"] == issuer and not entity["id"].casefold().startswith(ACCOUNT_PREFIX)
                for entity in value["entities"]), "native attribution declaring signer impersonation")
            require(all(assertion["assertingAgent"] == issuer for assertion in value["assertions"]),
                "native attribution asserting signer impersonation")
            for assertion in value["assertions"]:
                for evidence in assertion["evidence"]:
                    matches = [p for p in priors if evidence["source"] == {"algorithm": "1",
                        "digest": keccak256(hex_bytes(p["payloadHex"])), "canonicalizationId": p["record"][2][2]}]
                    require(matches, "native attribution evidence hash is not a referenced original")
                    require(evidence["selectorType"] in ("json_pointer", "whole_document")
                        and (evidence["selectorType"] != "whole_document" or evidence["selector"] == ""),
                        "native attribution evidence selector unsupported")
                    for previous in matches:
                        resolve_pointer(hex_bytes(previous["payloadHex"]), evidence["selector"])
                    if evidence["basis"] == "own_signed_statement":
                        require(all(p["receipt"][1] == receipt[1] and p["receipt"][2] == "1" for p in matches),
                            "native attribution own statement has another signer")
            require(len({assertion["id"] for assertion in value["assertions"]}) == len(value["assertions"]),
                "native attribution duplicate assertion ID")
            row.update(status="supported", reasonCode=None, value=value)
        self._block()
        if type(self.reader.transport) is ReplayTransport: self.reader.transport.finish()
        transcript = self.reader.transcript()
        consistent_reads([self.catalogue.transcript(), self.artist.transcript(), transcript])
        self._snapshot = dumps({"profile": PROFILE, "version": "1", "interpretationProfileHash": self.profile.profile_hash,
            "artistSourceHash": keccak256(raw_artist), "metadataCatalogueHash": keccak256(self.catalogue.snapshot()),
            "transcriptHash": keccak256(transcript), "sourceState": artist["sourceState"], "statements": rows,
            "documents": [{"documentId": key, "rawViewHex": "0x" + raw.hex(), "payloadHex": "0x" + payload.hex()}
                for key, (raw, payload, _) in sorted(self.documents.items())],
            "claims": CLAIMS, "qualification": QUALIFICATION})
        return self._snapshot
