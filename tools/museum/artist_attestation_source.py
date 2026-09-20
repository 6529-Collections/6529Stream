"""Historical Artist op24 evidence behind a complete native Metadata catalogue.

The scope is every class-1 receipt backlink in one supplied Metadata collection.
This is neither a global Artist history nor an institutional notarization reader.
Original signatures/authority are retained from native receipts and immutable
operation evidence; current identity/attribution observations never replace them.
"""
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_abi import calldata, decode, encode
from .chain_history import scan_history
from .chain_rpc import MAX_TRANSCRIPT, RecordingReader, ReplayTransport, RpcTransport, quantity
from .independent_wire import RECORD, ZERO, ZERO_ADDRESS, json_values, require
from .metadata_catalog_source import MetadataCatalogSource, MAX_RECORDS
from .owner_catalog_source import _position, _location

PROFILE = "STREAM_MUSEUM_ARTIST_ATTESTATION_SOURCE_V1"
SOURCE_REVISION = "62dc299082db8168071ef4c9b0e6307adf313d7f"
MAX_ABI, MAX_SNAPSHOT, MAX_ARCHIVE_BYTES = 65536, 67108864, 24575
PUBLICATION = ("address", "address", "uint256", "bytes32", "bytes32", "bytes32", "bytes32", "uint16", "bytes32", "bytes32", "uint64", "bytes32")
PUBLICATION_NAMES = ("metadataHost", "recorder", "collectionId", "subjectId", "recordType", "schemaId", "canonicalizationId",
    "payloadAlgorithm", "payloadHash", "uriHash", "effectiveAt", "candidateRecordHash")
EVIDENCE = ("bytes32", "bytes32", "bytes32", "uint64", "address", "uint8", "uint32", "uint64", "bytes32")
PUBLICATION_RECORD = (PUBLICATION, EVIDENCE, "bytes32")
ATTESTATION = ("uint256", "uint8", "bytes32", "bytes32", "bytes32", "bytes32", "string")
ATTESTATION_RECORD = ("bytes32", "bytes32", "bytes32", "bytes32", "uint64", "uint64", "address")
BINDING = ("bytes32", "address", "bytes32", "bytes32", "uint64", "uint8", "uint8", "uint8", "address", "bool")
IDENTITY = ("address", "uint8", "uint8", "uint64", "uint64", "bytes32", "string", "string", "uint256")
AUTHORIZATION, PROOF, AUTHORITY = ("uint256", "uint64", "bytes"), ("address", "bytes32", "bool"), ("bytes32", "address", "uint8", "uint8")
SNAPSHOT = ("bytes32", "uint64", "bytes32", "bytes32")
ARCHIVE = ("uint16", "bytes32", "uint16", "address", "bytes32", (SNAPSHOT,) * 7, (SNAPSHOT,) * 7, "bytes")
ORDINARY_PAYLOAD = (BINDING, ATTESTATION, AUTHORIZATION, "bytes", PROOF, AUTHORIZATION, AUTHORITY, PUBLICATION, "bytes32")
FACT = ("address", "bytes32", "bytes32", "bytes32")
ASSOCIATION = ("bytes32", "bytes32", "uint64", "bytes32", FACT)
SUBJECT = ("uint8", "uint256", "bytes32", "address")
GRANT = ("bytes32", "address", "uint256", "uint32", "uint64", "uint64", "uint64", "bytes32")
DELEGATION = (GRANT, "address", "uint256", "uint256", "bool", "bytes32")
ADMISSION = (AUTHORITY, "address", "uint256", "uint64", "bytes32", "bytes32", FACT)
AUTHENTICATED_PAYLOAD = (BINDING, ATTESTATION, AUTHORIZATION, AUTHORIZATION, PROOF, "bytes", SUBJECT, "bool", ADMISSION, DELEGATION, "bytes")
SUITE = ("address", "address", ("address",) * 7, "address", "address", "address", "address", "address", "address", "bytes32", "address")
CAUSE_FACTS = ("bytes32", "uint8", "bytes32", "address", "bytes32", "bytes32", "uint64", "address", "uint8", "uint8",
    "bytes32", "bytes32", "bytes32", "bytes32", "bytes32")
CAUSE = ("bytes32", CAUSE_FACTS)
DOMAINS = tuple(schema_id("domain:" + name) for name in ("binding_lifecycle", "collaborator_lifecycle", "identity_authority",
    "acceptance_lifecycle", "attribution_lifecycle", "payout_lifecycle", "consent_finality"))
PUBLICATION_SCHEMA = schema_id("6529STREAM_ARTIST_RECORD_PUBLICATION_V1")
ATTESTED = schema_id("ArtistAttestationRecorded(uint16,uint256,uint8,address,bytes32,bytes32,bytes32,bytes32,bytes32,uint8,uint256,uint64,bytes32)")
REGISTERED = schema_id("ArtistIdentityRegistered(uint16,bytes32,address,bytes32,string,uint256)")
ARCHIVED = schema_id("ArtistArchiveEvidenceAppendedV2(bytes32,uint64,bytes32,address,uint256)")
CONSUMED = schema_id("ArtistRecordAuthorizationConsumed(bytes32,bytes32,address,address)")
DELEGATED = schema_id("ArtistAttestationDelegation(uint16,bytes32,bytes32,bytes32,address)")
GRANTED = schema_id("ArtistDelegationGranted(uint16,bytes32,address,uint256,uint32,uint64,uint64,uint64,bytes32,uint256,bytes32)")
METADATA_RECORDED = schema_id("CollectionRecordRecorded(uint256,bytes32,bytes32,(bytes32,bytes32,(uint16,bytes,bytes32),string,bytes32,bytes32,(uint16,bytes,bytes32),uint64),bytes32,bytes32,address,bytes32,uint16)")
TYPE_HASH = schema_id("StreamArtistAttestation(address core,uint256 collectionId,uint8 subjectKind,bytes32 subjectId,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,bytes32 statementURIHash,uint256 nonce,uint64 signedAt)")
CLAIMS = {"completeSuppliedMetadataArtistBacklinks": True, "historicalNativeAuthorityCorrespondenceChecked": True,
    "originalStatementSignatureAndIdentityBytesRetained": True, "originalOp24PreimagesChecked": True,
    "currentObservationsSeparated": True, "currentPermissionsRevalidated": False,
    "currentSignatureRevalidation": False, "reviewerIndependenceProven": False, "humanIdentityProven": False,
    "institutionalAffiliationProven": False, "semanticPayloadValidation": False,
    "globalArtistHistoryComplete": False, "actualChainAcceptance": False, "consensusProof": False,
    "fullObjectDossierConformance": False}
QUALIFICATION = ("Every class-1 Artist authorization backlink in one complete admitted Metadata collection is joined to original native "
    "publication, owner, archive and identity evidence. The caller admits runtime/source provenance; replay does not authenticate RPC origin or consensus. "
    "Current rotation, attribution, identity and contest observations remain separate. Names do not establish people; stable artist IDs do not establish "
    "independent reviewers. General institutional/notarization evidence is not_captured_by_artist_overlay.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "sourceRevision": SOURCE_REVISION,
    "status": "prospective_unregistered_read_profile", "scope": "all class-1 receipt backlinks in the supplied complete Metadata collection",
    "bounds": {"records": str(MAX_RECORDS), "abiBytes": str(MAX_ABI), "archiveBytes": str(MAX_ARCHIVE_BYTES),
        "snapshotBytes": str(MAX_SNAPSHOT), "transcriptBytes": str(MAX_TRANSCRIPT), "historyBlocks": "4096"},
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _hash(kinds, values):
    return keccak256(encode(kinds, values))


def attestation_preimage(chain, registry, core, terms, artist, signer, authority_class, nonce, signed_at):
    kinds = ("bytes32", "uint256", "address", "address", "uint256", "uint8", "bytes32", "bytes32", "bytes32",
        "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64")
    return encode(kinds, (schema_id("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"), chain, registry, core,
        *terms[:6], keccak256(terms[6].encode("utf-8")), artist, signer, authority_class, nonce, signed_at))


def signed_preimage(chain, registry, core, terms, nonce, signed_at):
    body = encode(("bytes32", "address", "uint256", "uint8", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint256", "uint64"),
        (TYPE_HASH, core, *terms[:6], keccak256(terms[6].encode("utf-8")), nonce, signed_at))
    domain = _hash(("bytes32", "bytes32", "bytes32", "uint256", "address"),
        (schema_id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
         schema_id("6529StreamArtistRegistry"), schema_id("1"), chain, registry))
    return body, domain, keccak256(b"\x19\x01" + hex_bytes(domain) + hex_bytes(keccak256(body)))


def _consistent(*raws):
    observed = {}
    for raw in raws:
        for row in loads(raw, maximum=MAX_TRANSCRIPT, canonical=True)["calls"]:
            key, value = dumps([row["method"], row["params"]]), keccak256(dumps(row["result"]))
            require(key not in observed or observed[key] == value, "Artist joined transcripts contradict the same read")
            observed[key] = value


class ArtistAttestationSource:
    def __init__(self, metadata_catalog, transport):
        require(type(metadata_catalog) is MetadataCatalogSource, "Artist evidence requires concrete Metadata catalogue")
        self.metadata_catalog, self.provenance = metadata_catalog, metadata_catalog.provenance
        require(self.provenance != "trusted_rpc" or type(transport) in (RpcTransport, ReplayTransport), "Artist evidence provenance")
        self.anchor_bytes, self.a, self.pins = metadata_catalog.anchor_bytes, metadata_catalog.a, metadata_catalog.pins
        self.reader = RecordingReader(transport, self.a["blockHash"])
        self._started, self._snapshot, self._archive_cache = False, None, {}

    def transcript(self):
        return self.reader.transcript()

    def _read(self, target, signature, outputs, kinds=(), values=()):
        return decode(outputs, hex_bytes(self.reader.call(target, calldata(signature, kinds, values))), maximum=MAX_ABI)

    def _pin(self, target):
        require(target in self.pins, "Artist missing explicit runtime pin")
        raw = hex_bytes(self.reader.code(target))
        require(0 < len(raw) <= 24576 and keccak256(raw) == self.pins[target], "Artist runtime pin differs")

    def snapshot(self):
        if self._snapshot is not None:
            return self._snapshot
        require(not self._started, "failed Artist evidence capture cannot resume")
        self._started = True
        try:
            self._snapshot = self._capture()
        except MuseumError:
            raise
        except (KeyError, ValueError, TypeError, IndexError, OverflowError) as exc:
            raise MuseumError("malformed Artist attestation evidence") from exc
        return self._snapshot

    def _suite(self):
        a = self.a; registry = a["artistRegistry"]
        coordinator, = self._read(registry, "operationCoordinator()", ("address",))
        self._pin(coordinator)
        suite, = self._read(coordinator, "suiteConfiguration()", (SUITE,))
        require(suite[0] == registry and suite[3] == a["core"], "Artist suite source identity differs")
        targets = (*suite[2], suite[0], suite[1], *suite[3:9], suite[10])
        require(len(set(targets)) == 16 and coordinator not in targets and suite[9] != ZERO, "Artist immutable suite target set")
        for target in targets:
            self._pin(target)
        require(self._read(coordinator, "deploymentChainId()", ("uint256",)) == (uint(a["chainId"]),), "Artist suite chain differs")
        for target in (registry, *suite[2]):
            for getter, expected in (("core", suite[3]), ("mintManager", suite[4]), ("operationCoordinator", coordinator)):
                require(self._read(target, getter + "()", ("address",)) == (expected,), "Artist immutable owner deployment differs")
        for index, owner in enumerate(suite[2]):
            for getter, expected in (("artistRegistry", registry), ("archiveV2", suite[1])):
                require(self._read(owner, getter + "()", ("address",)) == (expected,), "Artist owner/registry/archive binding differs")
            require(self._read(owner, "deploymentChainId()", ("uint256",)) == (uint(a["chainId"]),)
                and self._read(owner, "domainId()", ("bytes32",)) == (DOMAINS[index],), "Artist owner domain differs")
        for getter, expected in (("artistRegistry", registry), ("operationCoordinator", coordinator)):
            require(self._read(suite[1], getter + "()", ("address",)) == (expected,), "Artist archive deployment differs")
        configuration, = self._read(coordinator, "configurationHash()", ("bytes32",))
        require(configuration != ZERO, "Artist empty immutable configuration")
        return coordinator, suite, configuration

    def _events(self, history, selected, suite):
        attested, registered, consumed, published, archives = {}, {}, {}, {}, {}
        for log in history["logs"]:
            topics = log["topics"]
            if not topics:
                continue
            if log["address"] == self.a["host"] and topics[0] == CONSUMED:
                require(len(topics) == 4, "Artist Metadata consumption topics")
                if topics[2] in selected:
                    require(topics[2] not in consumed, "Artist duplicate Metadata consumption")
                    decode(("address",), hex_bytes(log["data"]))
                    consumed[topics[2]] = log
            elif log["address"] == self.a["host"] and topics[0] == METADATA_RECORDED:
                require(len(topics) == 4, "Artist Metadata publication topics")
                values = decode((RECORD, "bytes32", "bytes32", "address", "bytes32", "uint16"), hex_bytes(log["data"]), maximum=MAX_ABI)
                if values[1] in selected:
                    require(values[1] not in published, "Artist duplicate Metadata publication")
                    published[values[1]] = (values, log)
            elif log["address"] == suite[2][4] and topics[0] == ATTESTED:
                require(len(topics) == 4, "Artist attestation event topics")
                values = decode(("uint16", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint8", "uint256", "uint64", "bytes32"),
                    hex_bytes(log["data"]), maximum=MAX_ABI)
                if values[-1] in {row["receipt"][8] for row in selected.values()}:
                    require(values[-1] not in attested, "Artist duplicate original attestation")
                    attested[values[-1]] = (values, log)
            elif log["address"] == suite[2][2] and topics[0] == REGISTERED:
                require(len(topics) == 3, "Artist registration topics")
                require(topics[1] not in registered, "Artist duplicate native registration")
                registered[topics[1]] = log
            elif log["address"] == suite[1] and topics[0] == ARCHIVED:
                require(len(topics) == 4, "Artist archive event topics")
                archives.setdefault(log["transactionHash"], []).append(log)
        require(set(consumed) == set(published) == set(selected), "Artist complete Metadata publication receipts missing")
        require(len(attested) == len(selected), "Artist historical attestation receipts missing")
        return attested, registered, consumed, published, archives

    def _archive(self, event, candidates, coordinator, suite, configuration):
        matches = []
        for log in candidates:
            if _position(log) <= _position(event):
                continue
            key = log["topics"][1]
            version, = decode(("uint64",), hex_bytes(log["topics"][2]))
            if version != 1:
                continue
            if key not in self._archive_cache:
                raw, = self._read(suite[1], "artistEvidenceBytesV2(bytes32,uint64)", ("bytes",), ("bytes32", "uint64"), (key, 1))
                require(0 < len(raw) <= MAX_ARCHIVE_BYTES, "Artist immutable archive bound")
                meta = self._read(suite[1], "artistEvidenceMetadataV2(bytes32,uint64)", ("bytes32", "address", "uint32", "uint64"),
                    ("bytes32", "uint64"), (key, 1))
                pointer, size = decode(("address", "uint256"), hex_bytes(log["data"]))
                require(meta == (keccak256(raw), pointer, len(raw), quantity(log["blockNumber"])) and size == len(raw)
                    and log["topics"][3] == keccak256(raw) and pointer != ZERO_ADDRESS
                    and hex_bytes(self.reader.code(pointer)) == b"\x00" + raw, "Artist original archive receipt/carrier differs")
                self._archive_cache[key] = (raw, meta)
            raw, meta = self._archive_cache[key]
            # Other operations can share a receipt. Only op24 and this exact record
            # select a payload; unrelated archives never substitute for it.
            if len(raw) < 160 or int.from_bytes(raw[64:96], "big") != 24 or raw[128:160] != hex_bytes(event["_record"]):
                continue
            outer = decode(ARCHIVE, raw, maximum=MAX_ARCHIVE_BYTES)
            require(outer[0:3] == (1, configuration, 24) and outer[3] != ZERO_ADDRESS
                and key == _hash(("bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"),
                    (schema_id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), uint(self.a["chainId"]), suite[0], coordinator, 24, outer[3], outer[4])),
                "Artist archived op24 identity/configuration differs")
            for index in range(7):
                before, after = outer[5][index], outer[6][index]
                if index in (0, 1, 2, 4):
                    require(before[0] == after[0] == DOMAINS[index], "Artist archive owner snapshot domain")
                else:
                    require(before == after == (ZERO, 0, ZERO, ZERO), "Artist archive untouched owner snapshot")
            matches.append((outer, {"evidenceId": key, "version": "1", "metadata": json_values(meta),
                "bytesHex": "0x" + raw.hex(), "event": log}))
        require(len(matches) == 1, "Artist exact original op24 archive missing/duplicate")
        return matches[0]

    def _operation_payload(self, outer, terms, publication, evidence, host_code, signature, nonce, signed_at, timestamp,
                           association, history, suite, event):
        decoded = []
        for name, shape in (("original_publication", ORDINARY_PAYLOAD), ("authenticated_attestation", AUTHENTICATED_PAYLOAD)):
            try:
                decoded.append((name, decode(shape, outer[7], maximum=MAX_ARCHIVE_BYTES)))
            except MuseumError:
                pass
        require(len(decoded) == 1, "Artist original op24 payload layout missing/ambiguous")
        layout, payload = decoded[0]; delegation_evidence = None
        if layout == "original_publication":
            binding, archived_terms, submitted, statement, proof, effective, authority, archived_publication, archived_code = payload
            require(evidence[5] != 2 and association == (ZERO, ZERO, 0, ZERO, (ZERO_ADDRESS, ZERO, ZERO, ZERO)),
                "Artist original publication association differs")
        else:
            binding, archived_terms, submitted, effective, proof, statement, subject, scoped, admission, delegation, subject_evidence = payload
            authority = admission[0]
            archived_publication, archived_code = decode((PUBLICATION, "bytes32"), subject_evidence, maximum=MAX_ARCHIVE_BYTES)
            require(not scoped and subject == (0, 0, ZERO, ZERO_ADDRESS) and admission[1:4] == (evidence[4], nonce, signed_at)
                and admission[5] == ZERO and admission[6] == (publication[0], host_code, terms[2], terms[3])
                and association == (evidence[1], evidence[2], evidence[3], admission[4], admission[6]),
                "Artist authenticated subject/association differs")
            if admission[4] != ZERO:
                grant = delegation[0]
                require(evidence[5] == 2 and authority[2] == 1 and authority[3] in (1, 2) and authority[0] == evidence[1]
                    and grant[:2] == (evidence[1], evidence[4]) and grant[2] in (0, publication[2])
                    and grant[3] & evidence[6] == evidence[6] and grant[4] <= timestamp < grant[5]
                    and (grant[6] == 0 or delegation[3] < grant[6]) and not delegation[4] and delegation[5] == ZERO
                    and delegation[1] != ZERO_ADDRESS and admission[4] == _hash(
                        ("bytes32", "uint256", "address", *GRANT, "uint256"),
                        (schema_id("6529STREAM_ARTIST_DELEGATION_RECORD_V1"), uint(self.a["chainId"]), suite[0], *grant, delegation[2])),
                    "Artist historical delegation admission differs")
                current, = self._read(suite[2][2], "delegationRecord(bytes32)", (DELEGATION,), ("bytes32",), (admission[4],))
                used, hint = self._read(suite[2][2], "delegatedNonceState(bytes32,address,uint256)", ("bool", "uint256"),
                    ("bytes32", "address", "uint256"), (evidence[1], evidence[4], nonce))
                require(current[:3] == delegation[:3] and current[3] > delegation[3] and used,
                    "Artist historical delegation immutable terms/nonce differs")
                grants, links = [], []
                for log in history["logs"]:
                    topics = log["topics"]
                    if log["address"] == suite[2][2] and len(topics) == 4 and topics[0] == GRANTED:
                        values = decode(("uint16", "uint32", "uint64", "uint64", "uint64", "bytes32", "uint256", "bytes32"), hex_bytes(log["data"]))
                        if values[-1] == admission[4]:
                            require(topics[1:] == [grant[0], "0x" + encode(("address",), (grant[1],)).hex(),
                                "0x" + encode(("uint256",), (grant[2],)).hex()] and values == (1, *grant[3:], delegation[2], admission[4])
                                and _position(log) < _position(event), "Artist original delegation grant event differs")
                            grants.append(log)
                    if log["address"] == suite[2][4] and len(topics) == 4 and topics[0] == DELEGATED and topics[1] == evidence[0]:
                        require(topics[2:] == [admission[4], evidence[1]] and decode(("uint16", "address"), hex_bytes(log["data"])) == (1, evidence[4])
                            and log["transactionHash"] == event["transactionHash"] and _position(log) > _position(event),
                            "Artist original attestation delegation event differs")
                        links.append(log)
                require(len(grants) == len(links) == 1, "Artist original delegation events missing/duplicate")
                delegation_evidence = {"recordHash": admission[4], "originalWire": json_values(delegation), "originalEvents": grants + links,
                    "currentWire": json_values(current), "currentNonceHint": str(hint), "qualification": "Later revocation/expiry does not rewrite original delegated authority."}
            else:
                require(evidence[5] != 2 and delegation == ((ZERO, ZERO_ADDRESS, 0, 0, 0, 0, 0, ZERO), ZERO_ADDRESS, 0, 0, False, ZERO),
                    "Artist unexpected delegated witness")
        require(archived_terms == terms and archived_publication == publication and archived_code == host_code
            and binding[0] == evidence[1] and binding[3:5] == (evidence[2], evidence[3]) and binding[9]
            and authority[0] == evidence[1] and (evidence[5] == 2 or authority[1:3] == (evidence[4], evidence[5]))
            and ((authority[2] == 1 and authority[3] in (1, 2)) or (authority[2] in (3, 4) and authority[3] == 3)),
            "Artist historical op24 binding/authority differs")
        require(submitted[0] == effective[0] == nonce and effective[1] == signed_at and submitted[2] == effective[2] == signature
            and len(signature) <= 4096 and 0 < signed_at <= timestamp, "Artist original authorization bytes/time differ")
        body, domain, digest = signed_preimage(uint(self.a["chainId"]), self.a["artistRegistry"], self.a["core"], terms, nonce, signed_at)
        require(proof[:2] == (evidence[4], digest), "Artist original signer/digest proof differs")
        if proof[2]:
            require(outer[3] == evidence[4] and signature == b"" and (evidence[5] == 2 or signed_at == timestamp)
                and submitted[1] in (0, signed_at) and (submitted[1] != 0 or signed_at == timestamp),
                "Artist original direct authority differs")
        else:
            require(submitted == effective, "Artist original relayed authorization changed")
        return binding, statement, {"submittedAuthorization": json_values(submitted), "effectiveAuthorization": json_values(effective),
            "signerApproval": json_values(proof), "authority": json_values(authority), "signatureHex": "0x" + signature.hex(),
            "structPreimageHex": "0x" + body.hex(), "domainSeparator": domain, "digest": digest,
            "verification": "historical_native_coordinator_acceptance", "currentSignatureRevalidated": False,
            "payloadLayout": layout, "delegation": delegation_evidence}

    def _attestation(self, original, events, coordinator, suite, configuration, history):
        attested, _, consumed, published, archives = events
        digest, receipt, record = original["recordHash"], original["receipt"], original["record"]
        authorization = receipt[8]; event_values, raw_event = attested[authorization]
        event = dict(raw_event); event["_record"] = authorization
        kind, = decode(("uint8",), hex_bytes(event["topics"][2]))
        signer, = decode(("address",), hex_bytes(event["topics"][3]))
        require(decode(("uint256",), hex_bytes(event["topics"][1])) == (uint(self.a["collectionId"]),)
            and event_values[0] == 1 and kind in (7, 8) and signer == receipt[1], "Artist original attestation event scope/signer differs")
        publication_record, = self._read(suite[2][4], "publicationAttestation(bytes32)", (PUBLICATION_RECORD,), ("bytes32",), (authorization,))
        publication, evidence, host_code = publication_record
        expected = (self.a["host"], receipt[1], self.a["collectionId"], record[1], record[0], record[4], record[2][2], "1",
            keccak256(hex_bytes(original["payloadHex"])), keccak256(record[3].encode("utf-8")), record[7], digest)
        require(tuple(json_values(publication)) == expected and host_code == self.pins[self.a["host"]], "Artist original publication candidate differs")
        capability = 64 if record[0] in (schema_id("ARTIST_INTENT"), schema_id("ARTIST_INTENT_WAIVER")) else 1
        require(kind == (7 if capability == 64 else 8) and evidence[0] == authorization and evidence[1] != ZERO
            and evidence[2] != ZERO and evidence[3] > 0 and evidence[4] == signer and evidence[5] == event_values[6]
            and evidence[5] in (1, 2, 3, 4) and evidence[6] == capability and evidence[7] == event_values[8]
            and evidence[8] == _hash((PUBLICATION,), (publication,)), "Artist publication evidence differs")
        terms = (uint(self.a["collectionId"]), kind, record[1], digest if kind == 7 else ZERO, PUBLICATION_SCHEMA,
            keccak256(encode(("uint16", PUBLICATION), (1, publication))), record[3])
        require(event_values[1:6] == (*terms[2:6], keccak256(terms[6].encode("utf-8"))), "Artist original signed terms differ")
        attestation, = self._read(suite[2][4], "attestationRecord(bytes32)", (ATTESTATION_RECORD,), ("bytes32",), (authorization,))
        require(attestation == (authorization, terms[3], terms[4], terms[5], evidence[3], evidence[7], signer), "Artist historical record differs")
        statement, = self._read(suite[2][4], "statementBytes(bytes32)", ("bytes",), ("bytes32",), (terms[5],))
        require(statement == encode(("uint16", PUBLICATION), (1, publication)), "Artist original full statement differs")
        signature, = self._read(suite[2][2], "signatureBundle(bytes32)", ("bytes",), ("bytes32",), (authorization,))
        require(self._read(suite[2][4], "attestationAuthorityClass(bytes32)", ("uint8",), ("bytes32",), (authorization,)) == (evidence[5],),
            "Artist historical authority class differs")
        association, = self._read(suite[2][4], "attestationAssociation(bytes32)", (ASSOCIATION,), ("bytes32",), (authorization,))
        outer, archive = self._archive(event, archives.get(event["transactionHash"], []), coordinator, suite, configuration)
        binding, archived_statement, signature_evidence = self._operation_payload(outer, terms, publication, evidence, host_code, signature,
            event_values[7], evidence[7], uint(history["blockTimestamps"][str(quantity(event["blockNumber"]))]), association, history, suite, event)
        require(archived_statement == statement and self._read(suite[2][0], "bindingAt(uint256,uint64)", (BINDING,),
            ("uint256", "uint64"), (publication[2], evidence[3])) == (binding,), "Artist original binding archive differs")
        record_preimage = attestation_preimage(uint(self.a["chainId"]), suite[0], self.a["core"], terms, evidence[1], signer,
            evidence[5], event_values[7], evidence[7])
        require(keccak256(record_preimage) == authorization, "Artist original record preimage differs")
        if evidence[5] != 2:
            require(self._read(suite[2][2], "nonceUsed(bytes32,uint256)", ("bool",),
                ("bytes32", "uint256"), (evidence[1], event_values[7])) == (True,), "Artist original nonce differs")
        values, publication_log = published[digest]; consumption = consumed[digest]
        require(json_values(values[0]) == record and values[1:5] == (digest, receipt[5], signer, "0x" + (1).to_bytes(32, "big").hex())
            and values[5] == 1 and publication_log["topics"][1:] == ["0x" + encode(("uint256",), (publication[2],)).hex(), record[0], record[1]]
            and consumption["topics"][1:] == [authorization, digest, "0x" + encode(("address",), (signer,)).hex()]
            and publication_log["transactionHash"] == consumption["transactionHash"]
            and _position(raw_event) < _position(archive["event"]) < _position(publication_log) < _position(consumption)
            and uint(receipt[3]) == uint(history["blockTimestamps"][str(quantity(publication_log["blockNumber"]))]),
            "Artist original Metadata/authorization publication receipt differs")
        current_binding, = self._read(suite[2][0], "binding(uint256)", (BINDING,), ("uint256",), (publication[2],))
        attribution = self._read(suite[2][4], "attributionState(uint256)", ("uint8", "uint64"), ("uint256",), (publication[2],))
        latest, = self._read(suite[2][4], "attestation(uint256,uint8,bytes32)", (ATTESTATION_RECORD,),
            ("uint256", "uint8", "bytes32"), terms[:3])
        status = self._read(suite[2][4], "artistAttestationStatus(uint256,uint8,bytes32,bytes32)",
            ("uint8", "bytes32", "bytes32", "uint8", "uint64"), ("uint256", "uint8", "bytes32", "bytes32"), (*terms[:3], terms[3]))
        require(status[0] <= 3 and status[1:3] == (latest[0], latest[1]) and status[4] == latest[5], "Artist current attestation observation differs")
        return {"metadataRecordHash": digest, "attestationRecordHash": authorization, "metadataOriginal": original,
            "historicalAuthority": dict(zip(("artistId", "bindingHash", "bindingGeneration", "signer", "authorityClass", "requiredCapability", "signedAt"), json_values(evidence)[1:8])),
            "historicalBindingWire": json_values(binding), "publication": dict(zip(PUBLICATION_NAMES, json_values(publication))),
            "publicationWire": json_values(publication_record), "evidenceWire": json_values(evidence), "attestationWire": json_values(attestation),
            "associationWire": json_values(association), "termsWire": json_values(terms), "statementHex": "0x" + statement.hex(),
            "signatureHex": "0x" + signature.hex(), "signatureEvidence": signature_evidence,
            "recordPreimageHex": "0x" + record_preimage.hex(), "archive": archive,
            "originalIdentityDocumentHash": binding[2], "publicationPosition": _location(publication_log),
            "metadataPublicationPosition": _location(publication_log),
            "originalEvents": [raw_event, publication_log, consumption],
            "current": {"binding": json_values(current_binding), "attribution": json_values(attribution),
                "latestAttestation": json_values(latest), "attestationStatus": json_values(status),
                "statusAppliesToOriginalRecord": latest[0] == authorization,
                "statusSubjectStateHashArgument": terms[3], "qualification": "Current status describes the latest attestation for this subject; it does not replace this historical record or revalidate its authority."}}

    def _identity(self, artist, needed_documents, event, identity_owner, history):
        require(event is not None, "Artist original identity registration missing")
        authority, = decode(("address",), hex_bytes(event["topics"][2]))
        version, document, uri, nonce = decode(("uint16", "bytes32", "string", "uint256"), hex_bytes(event["data"]), maximum=MAX_ABI)
        require(version == 1 and authority != ZERO_ADDRESS and document != ZERO and artist == _hash(
            ("bytes32", "uint256", "address", "address", "bytes32", "uint256"),
            (schema_id("6529STREAM_ARTIST_ID_V1"), uint(self.a["chainId"]), self.a["artistRegistry"], authority, document, nonce)),
            "Artist original identity preimage differs")
        current, = self._read(identity_owner, "identity(bytes32)", (IDENTITY,), ("bytes32",), (artist,))
        require(current[0] != ZERO_ADDRESS and current[1] in (1, 3, 4) and 1 <= current[2] <= 4 and current[5] == document
            and current[6] == uri and current[3] == uint(history["blockTimestamps"][str(quantity(event["blockNumber"]))])
            and current[3] <= current[4] <= uint(self.a["timestamp"]), "Artist immutable registration/current identity differs")
        authority_state = self._read(identity_owner, "authorityState(bytes32)", ("address", "uint8", "uint8", "bytes32"), ("bytes32",), (artist,))
        require(authority_state == (*current[:3], document), "Artist current authority observations differ")
        operative, = self._read(identity_owner, "operativeIdentityRecord(bytes32)", ("bytes32",), ("bytes32",), (artist,))
        operative_bytes, = self._read(identity_owner, "identityRecordBytes(bytes32)", ("bytes",), ("bytes32",), (artist,))
        cause, = self._read(identity_owner, "currentIdentityContestCause(bytes32)", (CAUSE,), ("bytes32",), (artist,))
        documents = []
        for digest in sorted(needed_documents | {document, operative}):
            raw, = self._read(identity_owner, "identityDocumentBytes(bytes32)", ("bytes",), ("bytes32",), (digest,))
            require(0 < len(raw) <= 8192 and keccak256(raw) == digest and (digest != operative or raw == operative_bytes),
                "Artist original/current identity document bytes differ")
            documents.append({"documentHash": digest, "bytesHex": "0x" + raw.hex(), "meaning": "uninterpreted_original_identity_document"})
        return {"artistId": artist, "identityDocumentHash": document,
            "identityDocumentHex": next(d["bytesHex"] for d in documents if d["documentHash"] == document),
            "originalURI": uri, "originalAuthorityAddress": authority, "registrationNonce": str(nonce), "registrationEvent": event,
            "documents": documents, "currentIdentityWire": json_values(current), "currentAuthorityWire": json_values(authority_state),
            "currentOperativeDocumentHash": operative, "currentIdentityContestCauseWire": json_values(cause),
            "qualification": "Stable native artist identity and account authority; display names are not human identity or independent-reviewer credentials."}

    def _capture(self):
        catalogue_raw = self.metadata_catalog.snapshot()
        catalogue = loads(catalogue_raw, maximum=MAX_SNAPSHOT, canonical=True)
        selected = {row["recordHash"]: row for row in catalogue["records"] if row["receipt"][2] == "1"}
        require(len(selected) <= MAX_RECORDS, "Artist backlink count bound")
        coordinator, suite, configuration = self._suite()
        history = scan_history(self.reader, self.a)
        events = self._events(history, selected, suite)
        attestations, documents = [], {}
        for digest in sorted(selected):
            row = self._attestation(selected[digest], events, coordinator, suite, configuration, history)
            attestations.append(row)
            documents.setdefault(row["historicalAuthority"]["artistId"], set()).add(row["originalIdentityDocumentHash"])
        identities = [self._identity(artist, needed, events[1].get(artist), suite[2][2], history) for artist, needed in sorted(documents.items())]
        identity_map = {row["artistId"]: row for row in identities}
        for row in attestations:
            identity = identity_map[row["historicalAuthority"]["artistId"]]
            require(_position(identity["registrationEvent"]) < _position(row["originalEvents"][0]), "Artist registration follows original attestation")
            row["current"]["identity"] = identity["currentIdentityWire"]
        end = self.reader.request("eth_getBlockByHash", [self.a["blockHash"], False])
        require(type(end) is dict and end.get("hash") == self.a["blockHash"] and end.get("stateRoot") == self.a["stateRoot"]
            and quantity(end.get("number")) == uint(self.a["blockNumber"])
            and quantity(end.get("timestamp")) == uint(self.a["timestamp"]), "Artist final anchor differs")
        _consistent(self.metadata_catalog.transcript(), self.transcript())
        if type(self.reader.transport) is ReplayTransport:
            self.reader.transport.finish()
        result = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1", "sourceRevision": SOURCE_REVISION,
            "mode": "caller_admitted_rpc_artist_attestation" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "provenanceDeclaredByCaller": True, "anchorHash": keccak256(self.anchor_bytes), "metadataCatalogueHash": keccak256(catalogue_raw),
            "metadataCatalogueTranscriptHash": keccak256(self.metadata_catalog.transcript()), "transcriptHash": keccak256(self.transcript()),
            "sourceState": catalogue["sourceState"], "host": self.a["host"], "artistRegistry": self.a["artistRegistry"],
            "suite": {"coordinator": coordinator, "configurationHash": configuration, "wire": json_values(suite), "codePins": self.a["codePins"]},
            "scope": "all_class1_backlinks_in_supplied_complete_Metadata_collection", "attestations": attestations, "identities": identities,
            "generalNotarizationEvidence": "not_captured_by_artist_overlay", "claims": CLAIMS, "qualification": QUALIFICATION})
        require(len(result) <= MAX_SNAPSHOT, "Artist evidence snapshot bound")
        return result
