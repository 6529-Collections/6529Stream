"""Targeted native personhood observations and original documentary correspondence."""
from . import artist_attestation_source as artist
from . import general_attestation_source as general
from . import personhood_documentary as documentary
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_abi import calldata, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require
from .owner_catalog_source import _location, _position
from .public_chain_history import scan_public_history, PROFILE_HASH as HISTORY_PROFILE_HASH
from .public_history_rpc import PublicRecordingReader, PublicReplayTransport, PublicRpcTransport

PROFILE = "STREAM_MUSEUM_PUBLIC_PERSONHOOD_SOURCE_V1"
SOURCE_REVISION = "68498f8d8fc95d9a96324426bf7c1e50976b8405"
COMMON = ("chainId", "core", "collectionId", "blockHash", "blockNumber", "timestamp",
    "stateRoot", "environment", "deploymentEvidenceHash")
MAX_ANCHOR, MAX_ABI, MAX_OUTPUT, MAX_RECORDS = 65536, 65536, 32 * 1024 * 1024, 128
POINTER = ("address", "bytes32", "bool", "bytes32", "bytes4", "address", "uint8", "bytes32", "bytes32", "uint64")
STATUSES = ("NONE", "WAIVER", "RESOLVED", "STALE", "UNRESOLVED")
EVIDENCE_SCHEMA = schema_id("6529STREAM_ARTIST_PERSONHOOD_EVIDENCE_V1")
WAIVER_SCHEMA = schema_id("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")
SUMMARY_TAG = schema_id("6529STREAM_ARTIST_PERSONHOOD_PROOF_SUMMARY_V1")
SUMMARY_TYPE = schema_id("ARTIST_PERSONHOOD_PROOF_SUMMARY")
STATEMENT_TYPE = schema_id("ARTIST_PUBLICATION_STATEMENT")
STORED_EVENT = schema_id("ArtistStoredPayload(uint16,uint256,bytes32,bytes32,address)")
GENERAL_EVENT = schema_id("GeneralAttestationRecorded(uint256,bytes32,bytes32,bytes32,address,uint8,uint8,bytes32,bytes32,uint16)")
GENERAL_DATA = ("bytes32", "address", "uint8", "uint8", "bytes32", "bytes32", "uint16")
ATTESTED_DATA = ("uint16", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint8", "uint256", "uint64", "bytes32")
PREIMAGE = ("bytes32", "uint256", "address", "address", "uint256", "uint8", "bytes32", "bytes32",
    "bytes32", "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64")


# Fixed Solidity arrays use the same static layout, but the event signature retains their array syntax.
SUMMARY_SIGNATURE = "(uint16,uint256,bytes32,bytes32,bytes32,bytes32,uint64,uint256,bytes32,(uint16,bytes32,address,bytes32,bytes32,address,bytes32,bytes32),bytes32,address,bytes32,address,bytes32,address,bytes32,address,bytes32,bytes32[4],uint256,bytes32,bytes32,address,bytes32,bytes32,address[6],bytes32[6])"
SUMMARY_EVENT = schema_id("ArtistPersonhoodProofRetained(uint16,bytes32,address,bytes32," + SUMMARY_SIGNATURE + ")")
CLAIMS = {"targetedCurrentNativeHeadChecked": True, "originalAndOperativeIdentitiesSeparated": True,
    "originalProofAndWaiverHashDomainsSeparated": True, "originalDocumentaryBytesReconstructedWhenAvailable": True,
    "sameRecorderSupersessionCheckedWhenAvailable": True, "providerLogCompletenessTrusted": True,
    "canonicalMappingTrusted": True, "completePersonhoodHistory": False,
    "sourceArtifactAuthenticityProven": False, "historicalSaleTimeCurrentnessProven": False,
    "currentSignatureRevalidation": False, "personhoodProven": False,
    "institutionalStandingProven": False, "documentaryTruthProven": False,
    "actualChainAcceptance": False, "sourceConsensusVerified": False, "completeAcquisitionPacket": False}
QUALIFICATION = (
    "One current collection binding and its schema-specific native personhood head. Original op24 and "
    "General proof bytes are reconciled in their original Registry domains when retained provenance is "
    "available; registration identity and operative identity remain separate. A resolved proof commits "
    "its tagged summary; an explicit waiver commits its original native record. Same-recorder report "
    "supersession does not select a replacement. This targeted reader is not a complete personhood "
    "history and cannot reverse an old paid summary commitment from a changed current head. Unavailable "
    "original code or documentary carriers fail capture; native UNRESOLVED remains unresolved even if "
    "unbounded documentary reads work. Runtime/source and RPC provenance require external admission. "
    "No signature reauthorization, institutional standing, legal personhood, factual truth, historical "
    "sale-time execution, consensus or complete acquisition packet is established.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "sourceReviewCommit": SOURCE_REVISION,
    "historyProfileHash": HISTORY_PROFILE_HASH, "personhoodReferenceProfileHash": documentary.PROFILE_HASH,
    "bounds": {"anchorBytes": str(MAX_ANCHOR),
        "abiBytes": str(MAX_ABI), "snapshotBytes": str(MAX_OUTPUT), "scopedGeneralEvents": str(MAX_RECORDS)},
    "anchor": "Common collection source state, Metadata and Artist facade, explicit current/original runtime pins and source-specific runtimeAdmission. Artist ID is derived from the current binding.",
    "scope": "Current native schema-specific head only; original op24 publication and summary retentions, original General record and its complete provider-observed same-subject lane events. No caller-chosen replacement, historical hash hint or global denominator.",
    "rules": ["Current Core-selected Metadata/Artist and reciprocal Coordinator/Binding/Identity/Attribution/Archive graph.",
        "Exact current Selection, compact status and personhoodAttestation; current binding/operative identity are separate from original registration identity.",
        "Original native hash is independently rebuilt from its original event/domain and retained statement/signature; no nonexistent op24 record-preimage getter is assumed.",
        "Original authority classes 1 through 4 remain distinct. A zero head cannot contradict an observed same-Artist personhood publication in the current owner.",
        "When the current owner has a local same-Artist personhood publication, the current head must equal the last such event and name the current Registry. Later original-owner publications do not rewrite an imported head.",
        "Resolved original 48-word summary, full General documentary proof, all four exact definitions and six immutable carriers must reconcile.",
        "Original summary retention and both carriers share the op24 transaction. Imported owner/archive carriers share their own retention transaction. The selected General report must be its recorder's latest publication before original op24.",
        "Imported summaries retain original Registry/Attribution evidence and identical current-owner summary; importing is not reexecuted.",
        "Lifecycle status is excluded from immutable document-facts hashes. ACTIVE/DEPRECATED General modules may remain current; only the original recorder-scoped head affects supersession.",
        "A missing original Registry is disclosed without inventing its op24 domain. Opaque or bounded-read UNRESOLVED never becomes resolved from offchain reconstruction."],
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def zero(kind):
    if isinstance(kind, tuple): return tuple(zero(x) for x in kind)
    return False if kind == "bool" else ZERO_ADDRESS if kind == "address" else ZERO if kind == "bytes32" else 0


class PublicPersonhoodSource:
    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc") and
            (provenance != "trusted_rpc" or type(transport) in (PublicRpcTransport, PublicReplayTransport)),
            "personhood provenance")
        a = loads(anchor_bytes, maximum=MAX_ANCHOR, canonical=True)
        require(type(a) is dict and set(a) == set(COMMON) | {"profile", "host", "artistRegistry", "codePins", "runtimeAdmission"}
            and a["profile"] == PROFILE, "personhood anchor shape/profile")
        require(uint(a["chainId"]) > 0 and uint(a["collectionId"]) > 0
            and a["environment"] in ("public_chain", "local_evm_fixture"), "personhood source identity")
        uint(a["blockNumber"]); uint(a["timestamp"], 64)
        for key in ("blockHash", "stateRoot", "deploymentEvidenceHash"):
            require(any(hex_bytes(a[key], 32)), "personhood empty source commitment")
        adm = a["runtimeAdmission"]
        require(type(adm) is dict and set(adm) == {"sourceCommit", "kind", "artifactHash"}
            and adm["sourceCommit"] == SOURCE_REVISION and any(hex_bytes(adm["artifactHash"], 32))
            and adm["kind"] == ("synthetic_fixture" if provenance == "synthetic_fixture" else "externally_admitted_runtime"),
            "personhood runtime admission differs")
        require(type(a["codePins"]) is list and 3 <= len(a["codePins"]) <= 128, "personhood code pin bound")
        pins = {}
        for row in a["codePins"]:
            require(type(row) is dict and set(row) == {"address", "runtimeHash"}
                and any(hex_bytes(row["address"], 20)) and any(hex_bytes(row["runtimeHash"], 32))
                and row["address"] not in pins, "personhood invalid/duplicate pin")
            pins[row["address"]] = row["runtimeHash"]
        require(len({a[k] for k in ("core", "host", "artistRegistry")}) == 3
            and all(a[k] in pins for k in ("core", "host", "artistRegistry")), "personhood required source pins")
        self.a, self.pins, self.anchor_bytes, self.provenance = a, pins, anchor_bytes, provenance
        self.reader = PublicRecordingReader(transport, a["blockHash"])
        self._started, self._snapshot, self.suites = False, None, {}

    def read(self, target, name, outputs, inputs=(), values=()):
        return decode(outputs, hex_bytes(self.reader.call(target, calldata(name, inputs, values))), maximum=MAX_ABI)

    def one(self, target, name, output, inputs=(), values=()):
        return self.read(target, name, (output,), inputs, values)[0]

    def code(self, address, expected_hash=None):
        raw = hex_bytes(self.reader.code(address))
        require(0 < len(raw) <= 24576 and (expected_hash is None or keccak256(raw) == expected_hash),
            "personhood runtime/carrier differs")
        return raw

    def pin(self, address):
        require(address in self.pins, "personhood discovered dependency has no external pin")
        return self.code(address, self.pins[address])

    def suite(self, registry):
        if registry in self.suites: return self.suites[registry]
        self.pin(registry)
        coordinator = self.one(registry, "operationCoordinator()", "address"); self.pin(coordinator)
        suite = self.one(coordinator, "suiteConfiguration()", artist.SUITE)
        require(suite[0] == registry and suite[3] == self.a["core"] and suite[9] != ZERO
            and self.one(coordinator, "deploymentChainId()", "uint256") == uint(self.a["chainId"]),
            "personhood reciprocal suite differs")
        owners = (suite[2][0], suite[2][2], suite[2][4]); archive = suite[1]
        require(len(set((registry, coordinator, archive, *owners))) == 6, "personhood source aliases")
        for target in (registry, *owners):
            self.pin(target)
            require(self.one(target, "core()", "address") == self.a["core"]
                and self.one(target, "operationCoordinator()", "address") == coordinator,
                "personhood owner source differs")
        for target in owners:
            require(self.one(target, "artistRegistry()", "address") == registry
                and self.one(target, "deploymentChainId()", "uint256") == uint(self.a["chainId"]),
                "personhood owner original registry differs")
        self.pin(archive)
        require(self.one(archive, "artistRegistry()", "address") == registry
            and self.one(archive, "operationCoordinator()", "address") == coordinator, "personhood archive source differs")
        row = {"registry": registry, "coordinator": coordinator, "configuration": json_values(suite),
            "binding": owners[0], "identity": owners[1], "attribution": owners[2], "archive": archive}
        self.suites[registry] = row
        return row

    def _graph(self):
        a = self.a
        for target, digest in sorted(self.pins.items()): self.code(target, digest)
        pointers = {}
        for name, target in (("COLLECTION_METADATA", a["host"]), ("ARTIST_REGISTRY", a["artistRegistry"])):
            role = schema_id(name)
            row = self.one(a["core"], "getSatellitePointer(bytes32)", POINTER, ("bytes32",), (role,))
            require(row[0] == target and row[1] == self.pins[target] and row[3] == role and row[6] == 1
                and row[7] != ZERO and row[8] != ZERO and row[9] > 0, "personhood current Core pointer differs")
            pointers[name] = json_values(row)
        require(self.one(a["host"], "core()", "address") == a["core"]
            and self.one(a["host"], "artistRegistry()", "address") == a["artistRegistry"]
            and self.one(a["host"], "artistRegistryCodeHash()", "bytes32") == self.pins[a["artistRegistry"]],
            "personhood Metadata original facade differs")
        return {"current": self.suite(a["artistRegistry"]), "original": None, "pointers": pointers}

    def _current(self, graph):
        a, owner = self.a, graph["current"]
        cid = uint(a["collectionId"])
        binding = self.one(owner["binding"], "binding(uint256)", artist.BINDING, ("uint256",), (cid,))
        artist_id = binding[0]
        if artist_id == ZERO:
            require(binding == zero(artist.BINDING), "personhood partial empty binding")
            registered = operative = ZERO
        else:
            authority = self.read(owner["identity"], "authorityState(bytes32)", ("address", "uint8", "uint8", "bytes32"),
                ("bytes32",), (artist_id,))
            registered = authority[3]
            operative = self.one(owner["identity"], "operativeIdentityRecord(bytes32)", "bytes32", ("bytes32",), (artist_id,))
            require(registered != ZERO and binding[4] > 0, "personhood known registration differs")
        selected = self.one(owner["attribution"], "personhoodEvidence(uint256,bytes32)", documentary.SELECTION,
            ("uint256", "bytes32"), (cid, artist_id))
        compact = self.read(owner["attribution"], "personhoodEvidenceStatus(uint256,bytes32)", ("bytes32", "uint8"),
            ("uint256", "bytes32"), (cid, artist_id))
        require(selected[-1] < len(STATUSES) and compact == (selected[0][0], selected[-1])
            and self.one(owner["attribution"], "personhoodAttestation(uint256,bytes32)", artist.ATTESTATION_RECORD,
                ("uint256", "bytes32"), (cid, artist_id)) == selected[0], "personhood native head/status differs")
        gas = None
        if selected[0][0] != ZERO:
            gas = self.read(a["artistRegistry"], "gasParameterInfo(bytes32)", ("uint256", "uint256", "uint8", "uint64"),
                ("bytes32",), (schema_id("6529STREAM_GGP_ARTIST_SALE_FACTS_READ_GAS"),))
            if selected[-1] != 4:
                require(0 < gas[0] <= ((1 << 256) - 1) // 64 and gas[2] == 2 and gas[3] > 0,
                    "personhood current read gas differs")
        return {"artistId": artist_id, "binding": json_values(binding), "registrationIdentityRecordHash": registered,
            "operativeIdentityRecordHash": operative, "selection": json_values(selected), "status": STATUSES[selected[-1]],
            "evidenceHash": ZERO, "evidenceHashDomain": "none", "identityCurrent": selected[-3],
            "notarizationCurrent": selected[-2], "currentReadGas": None if gas is None else json_values(gas)}, binding, selected

    def _native(self, graph, current, selected):
        owner, record = graph["current"], selected[0]
        if record[0] == ZERO:
            require(selected == zero(documentary.SELECTION), "personhood partial empty native selection")
            return None, None
        require(record[1] != ZERO and record[2] in (WAIVER_SCHEMA, EVIDENCE_SCHEMA) and record[3] != ZERO
            and record[4] > 0 and record[6] != ZERO_ADDRESS and 0 < record[5] <= uint(self.a["timestamp"]),
            "personhood native record fields differ")
        require(self.one(owner["attribution"], "attestationRecord(bytes32)", artist.ATTESTATION_RECORD,
            ("bytes32",), (record[0],)) == record, "personhood selected record differs")
        statement = self.one(owner["attribution"], "statementBytes(bytes32)", "bytes", ("bytes32",), (record[3],))
        require(0 < len(statement) <= 8192 and keccak256(statement) == record[3], "personhood original statement differs")
        summary = self.one(owner["attribution"], "personhoodProofSummary(bytes32)", documentary.SUMMARY,
            ("bytes32",), (record[0],))
        digest = self.one(owner["attribution"], "personhoodProofSummaryHash(bytes32)", "bytes32", ("bytes32",), (record[0],))
        admitted = summary[0] == 1
        if admitted:
            require(record[2] == EVIDENCE_SCHEMA and selected[1] != ZERO_ADDRESS
                and digest == keccak256(encode(("bytes32", documentary.SUMMARY), (SUMMARY_TAG, summary)))
                and summary[1:5] == (uint(self.a["chainId"]), record[0], record[3], current["artistId"])
                and summary[6:9] == (record[4], uint(self.a["collectionId"]), record[1])
                and summary[9] == selected[2] and summary[9][2] == selected[1]
                and summary[11] == self.a["core"] and summary[12] == self.pins[self.a["core"]],
                "personhood original summary/header differs")
            require(documentary.decode_reference(statement) == summary[9],
                "personhood original statement/reference differs")
            doc = documentary.verify_documentary(self, summary)
        else:
            require(summary == zero(documentary.SUMMARY) and digest == ZERO, "personhood malformed empty summary")
            require(selected[2] == zero(documentary.REFERENCE), "personhood unadmitted reference substituted")
            doc = None
        original = None
        if selected[1] != ZERO_ADDRESS:
            original = self.suite(selected[1]); graph["original"] = original
            require(self.one(original["attribution"], "attestationRecord(bytes32)", artist.ATTESTATION_RECORD,
                ("bytes32",), (record[0],)) == record
                and self.one(original["attribution"], "statementBytes(bytes32)", "bytes", ("bytes32",), (record[3],)) == statement,
                "personhood original imported record differs")
            saved_binding = self.one(original["binding"], "bindingAt(uint256,uint64)", artist.BINDING,
                ("uint256", "uint64"), (uint(self.a["collectionId"]), record[4]))
            require(saved_binding[0] == current["artistId"] and saved_binding[4] == record[4] and saved_binding[9]
                and saved_binding[3] != ZERO and (not admitted or saved_binding[3] == summary[5]),
                "personhood original binding differs")
            signature_bytes = self.one(original["identity"], "signatureBundle(bytes32)", "bytes", ("bytes32",), (record[0],))
            require(len(signature_bytes) <= 4096, "personhood original signature bound")
            if admitted:
                require(self.one(original["attribution"], "personhoodProofSummary(bytes32)", documentary.SUMMARY,
                    ("bytes32",), (record[0],)) == summary and self.one(original["attribution"],
                    "personhoodProofSummaryHash(bytes32)", "bytes32", ("bytes32",), (record[0],)) == digest,
                    "personhood original imported summary differs")
        else:
            require(not admitted, "personhood summary original registry absent")
            saved_binding, signature_bytes = None, None
        return {"recordHash": record[0], "record": json_values(record), "recordPreimageHex": None,
            "statementHex": "0x" + statement.hex(), "originalRegistry": selected[1],
            "originalBinding": None if saved_binding is None else json_values(saved_binding),
            "signatureHex": None if signature_bytes is None else "0x" + signature_bytes.hex(),
            "publication": None, "authorization": None, "summary": json_values(summary), "summaryHash": digest, "summaryRetentions": [],
            "originalOp24Correspondence": "origin_unavailable" if original is None else "pending"}, doc

    def _status(self, current, binding, selected, native, doc):
        if native is None: return
        record = selected[0]
        identity_current = binding[9] and binding[0] == current["artistId"] and binding[4] == record[4]
        identity_current = identity_current and current["operativeIdentityRecordHash"] != ZERO
        identity_current = identity_current and current["operativeIdentityRecordHash"] == record[1]
        if doc is not None:
            identity_current = identity_current and binding[3] == native["summary"][5]
        # A bounded native read may fail while these unconstrained RPC reads succeed.
        # Preserve that explicit UNRESOLVED result, rather than upgrading it from the audit.
        if selected[-1] == 4:
            require(not selected[-2] and selected[3:6] == (ZERO, ZERO_ADDRESS, ZERO)
                and (not selected[-3] or (doc is None and record[2] == EVIDENCE_SCHEMA and identity_current)),
                "personhood unresolved flags differ")
            return
        require(selected[-3] == identity_current, "personhood current operative identity differs")
        if record[2] == WAIVER_SCHEMA:
            require(doc is None and selected[3:6] == (ZERO, ZERO_ADDRESS, ZERO) and not selected[-2]
                and selected[-1] == (1 if identity_current else 3), "personhood explicit waiver status differs")
        else:
            require(doc is not None, "personhood unadmitted evidence status differs")
            facts = tuple(doc["facts"])
            require(selected[3:6] == facts[:3] and selected[-2] == facts[3]
                and selected[-1] == (2 if identity_current and facts[3] else 3), "personhood recorder currentness differs")
        if selected[-1] in (1, 2):
            current["evidenceHash"] = record[0] if selected[-1] == 1 else native["summaryHash"]
            current["evidenceHashDomain"] = "native_op24_record" if selected[-1] == 1 else "personhood_proof_summary"

    def _filters(self, graph, native, doc):
        if native is None or graph["original"] is None:
            # Fixed current-owner key filter still supplies an anchored public-history envelope.
            return [{"address": graph["current"]["attribution"], "topics": [artist.ATTESTED,
                "0x" + uint(self.a["collectionId"]).to_bytes(32, "big").hex(), "0x" + (10).to_bytes(32, "big").hex()]}]
        original = graph["original"]
        filters = [{"address": original["attribution"], "topics": [artist.ATTESTED,
            "0x" + uint(self.a["collectionId"]).to_bytes(32, "big").hex(), "0x" + (10).to_bytes(32, "big").hex()]}]
        if original["attribution"] != graph["current"]["attribution"]:
            filters.append({"address": graph["current"]["attribution"], "topics": filters[0]["topics"][:]})
        for owner in dict.fromkeys((original["attribution"], original["archive"],
                graph["current"]["attribution"], graph["current"]["archive"])):
            if doc is not None:
                filters.append({"address": owner, "topics": [STORED_EVENT, None, SUMMARY_TYPE, native["summaryHash"]]})
            if owner == original["attribution"]:
                filters.append({"address": owner, "topics": [STORED_EVENT, None, STATEMENT_TYPE, native["record"][3]]})
        if doc is not None:
            for owner in dict.fromkeys((original["attribution"], graph["current"]["attribution"])):
                filters.append({"address": owner, "topics": [SUMMARY_EVENT, native["recordHash"]]})
            s = native["summary"]
            filters.append({"address": s[9][5], "topics": [GENERAL_EVENT,
                "0x" + uint(s[20]).to_bytes(32, "big").hex(), s[21], s[22]]})
        return filters

    def _stored(self, history, owner, kind, digest, raw):
        events = [e for e in history["logs"] if e["address"] == owner and len(e["topics"]) == 4
            and e["topics"][0] == STORED_EVENT and e["topics"][2:] == [kind, digest]]
        require(len(events) == 1, "personhood exact retained payload event missing/duplicate")
        event = events[0]
        version, pointer = decode(("uint16", "address"), hex_bytes(event["data"]))
        index, = decode(("uint256",), hex_bytes(event["topics"][1]))
        require(version == 1 and index < self.one(owner, "storedPayloadCount()", "uint256")
            and self.read(owner, "storedPayloadAt(uint256)", ("address", "bytes32", "bytes32"),
                ("uint256",), (index,)) == (pointer, kind, digest)
            and self.code(pointer) == b"\x00" + raw, "personhood retained payload index/carrier differs")
        return {"owner": owner, "pointer": pointer, "payloadType": kind, "payloadHash": digest,
            "index": str(index), "publication": _location(event)}

    def _events(self, history, graph, current, native, doc, selected):
        local = []
        for event in history["logs"]:
            if event["address"] != graph["current"]["attribution"] or not event["topics"] \
                    or event["topics"][0] != artist.ATTESTED: continue
            require(len(event["topics"]) == 4, "personhood current-owner publication topics")
            values = decode(ATTESTED_DATA, hex_bytes(event["data"]), maximum=MAX_ABI)
            if values[1] == current["artistId"] and values[3] in (WAIVER_SCHEMA, EVIDENCE_SCHEMA):
                require(values[0] == 1, "personhood current-owner publication version")
                local.append(values[-1])
        if local:
            require(native is not None, "personhood empty head contradicts observed personhood publication")
            require(selected[1] == graph["current"]["registry"] and selected[0][0] == local[-1],
                "personhood current head contradicts latest local personhood publication")
        if native is None: return
        if graph["original"] is None: return
        original, record = graph["original"], selected[0]
        events = []
        for event in history["logs"]:
            if event["address"] != original["attribution"] or not event["topics"] or event["topics"][0] != artist.ATTESTED: continue
            require(len(event["topics"]) == 4, "personhood original op24 topics")
            values = decode(ATTESTED_DATA, hex_bytes(event["data"]), maximum=MAX_ABI)
            if values[-1] == record[0]: events.append((event, values))
        require(len(events) == 1, "personhood original op24 event missing/duplicate")
        event, values = events[0]
        signer, = decode(("address",), hex_bytes(event["topics"][3]))
        require(values[0] == 1 and values[1:5] == (current["artistId"], record[1], record[2], record[3])
            and signer == record[6] and values[8] == record[5] and values[6] in (1, 2, 3, 4)
            and record[5] <= uint(history["blockTimestamps"][str(int(event["blockNumber"], 16))]),
            "personhood original op24 publication differs")
        for owner in dict.fromkeys((original["attribution"], graph["current"]["attribution"])):
            require(self.one(owner, "attestationAuthorityClass(bytes32)", "uint8", ("bytes32",), (record[0],)) == values[6],
                "personhood original authority class differs")
        preimage = encode(PREIMAGE, (schema_id("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"), uint(self.a["chainId"]),
            original["registry"], self.a["core"], uint(self.a["collectionId"]), 10, *values[1:6],
            current["artistId"], signer, values[6], values[7], values[8]))
        require(keccak256(preimage) == record[0], "personhood original op24 hash/domain differs")
        native.update(recordPreimageHex="0x" + preimage.hex(), publication=_location(event), originalOp24Correspondence="reconstructed")
        body = encode(("bytes32", "address", "uint256", "uint8", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint256", "uint64"),
            (artist.TYPE_HASH, self.a["core"], uint(self.a["collectionId"]), 10, *values[1:6], values[7], values[8]))
        domain = encode(("bytes32", "bytes32", "bytes32", "uint256", "address"),
            (schema_id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                schema_id("6529StreamArtistRegistry"), schema_id("1"), uint(self.a["chainId"]), original["registry"]))
        native["authorization"] = {"bodyHex": "0x" + body.hex(), "domainHex": "0x" + domain.hex(),
            "domainHash": keccak256(domain), "digest": keccak256(b"\x19\x01" + hex_bytes(keccak256(domain)) + hex_bytes(keccak256(body))),
            "authorityClass": str(values[6]), "nonce": str(values[7]), "signedAt": str(values[8]),
            "originalSignatureBytesRetained": True, "signatureCryptographyRevalidated": False}
        native["statementRetention"] = self._stored(history, original["attribution"], STATEMENT_TYPE, record[3], hex_bytes(native["statementHex"]))
        position = lambda row: tuple(uint(row[k]) for k in ("blockNumber", "transactionIndex", "logIndex"))
        transaction = lambda row: tuple(row[k] for k in ("blockHash", "transactionHash", "transactionIndex"))
        require(position(native["statementRetention"]["publication"]) < _position(event),
            "personhood statement retention follows original op24")
        if doc is None: return
        summary = self.one(graph["current"]["attribution"], "personhoodProofSummary(bytes32)", documentary.SUMMARY,
            ("bytes32",), (record[0],))
        raw = encode(("bytes32", documentary.SUMMARY), (SUMMARY_TAG, summary))
        for owner in dict.fromkeys((original["attribution"], graph["current"]["attribution"])):
            found = [e for e in history["logs"] if e["address"] == owner and e["topics"][:2] == [SUMMARY_EVENT, record[0]]]
            require(len(found) == 1 and found[0]["topics"] == [SUMMARY_EVENT, record[0], "0x" + bytes(12).hex() + hex_bytes(original["registry"]).hex()]
                and decode(("uint16", "bytes32", documentary.SUMMARY), hex_bytes(found[0]["data"]), maximum=MAX_ABI)
                    == (1, native["summaryHash"], summary), "personhood original summary event differs")
            require(_position(event) < _position(found[0]), "personhood summary precedes original op24")
            if owner == original["attribution"]:
                require(transaction(_location(found[0])) == transaction(_location(event)),
                    "personhood original summary transaction differs")
            native["summaryRetentions"].append({"owner": owner, "publication": _location(found[0])})
        native["summaryCarriers"] = [self._stored(history, owner, SUMMARY_TYPE, native["summaryHash"], raw)
            for owner in dict.fromkeys((original["attribution"], original["archive"],
                graph["current"]["attribution"], graph["current"]["archive"]))]
        carriers = {row["owner"]: row for row in native["summaryCarriers"]}
        retentions = {row["owner"]: row for row in native["summaryRetentions"]}
        for suite in (original, graph["current"]):
            own, archived = carriers[suite["attribution"]], carriers[suite["archive"]]
            retained = retentions[suite["attribution"]]
            require(own["pointer"] == archived["pointer"]
                and transaction(own["publication"]) == transaction(retained["publication"])
                and transaction(retained["publication"]) == transaction(archived["publication"])
                and position(own["publication"]) < position(retained["publication"])
                and position(retained["publication"]) < position(archived["publication"]),
                "personhood original summary/archive carrier order differs")
        self._general_events(history, summary, event, doc)

    def _general_events(self, history, summary, op24, doc):
        host, digest = summary[9][5], summary[9][7]
        events = [e for e in history["logs"] if e["address"] == host and e["topics"] == [GENERAL_EVENT,
            "0x" + summary[20].to_bytes(32, "big").hex(), summary[21], summary[22]]]
        require(0 < len(events) <= MAX_RECORDS, "personhood General event denominator bound")
        latest, original, head_at_admission = {}, None, ZERO
        for event in events:
            data = decode(GENERAL_DATA, hex_bytes(event["data"]), maximum=MAX_ABI)
            value, receipt = self.read(host, "attestation(bytes32)", (general.ATTESTATION, general.RECEIPT), ("bytes32",), (data[0],))
            require(general.native_record_hash(uint(self.a["chainId"]), host, value, receipt) == data[0]
                and (value[1], value[2], value[3]) == (summary[20], summary[22], summary[21])
                and data[1:] == (value[0], receipt[1], receipt[2], value[9], receipt[5], 1)
                and receipt[0] == value[0] and receipt[3] == uint(history["blockTimestamps"][str(int(event["blockNumber"], 16))])
                and self.one(host, "recordHashAt(uint256,bytes32,uint256)", "bytes32",
                    ("uint256", "bytes32", "uint256"), (value[1], value[3], receipt[4])) == data[0],
                "personhood original General publication differs")
            require(value[9] == latest.get(receipt[0], ZERO), "personhood General recorder supersession differs")
            latest[receipt[0]] = data[0]
            if receipt[0] == summary[23] and _position(event) < _position(op24):
                head_at_admission = data[0]
            if data[0] == digest:
                require(original is None and _position(event) < _position(op24), "personhood General original/op24 order differs")
                original = _location(event)
        observed = self.one(host, "latestAttestationHashFor(uint256,bytes32,bytes32,address)", "bytes32",
            ("uint256", "bytes32", "bytes32", "address"), (summary[20], summary[21], summary[22], summary[23]))
        require(original is not None and latest.get(summary[23]) == observed, "personhood General recorder event/head differs")
        require(head_at_admission == digest, "personhood General reference was superseded before original op24")
        doc["publication"] = original
        doc["recorderHistory"] = {"eventCount": str(len(events)), "latestByRecorder":
            [{"recorder": who, "recordHash": value} for who, value in sorted(latest.items())]}

    def _capture(self):
        graph = self._graph()
        current, binding, selected = self._current(graph)
        native, doc = self._native(graph, current, selected)
        self._status(current, binding, selected, native, doc)
        history = scan_public_history(self.reader, self.a, filters=self._filters(graph, native, doc))
        self._events(history, graph, current, native, doc, selected)
        # Repeated reads must be identical under the same pinned source block.
        require(self.one(graph["current"]["attribution"], "personhoodEvidence(uint256,bytes32)", documentary.SELECTION,
            ("uint256", "bytes32"), (uint(self.a["collectionId"]), current["artistId"])) == selected,
            "personhood final native head differs")
        self.reader.request("eth_getBlockByHash", [self.a["blockHash"], False])
        self.reader.request("eth_getBlockByNumber", [hex(uint(self.a["blockNumber"])), False])
        if type(self.reader.transport) is PublicReplayTransport: self.reader.transport.finish()
        raw = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1", "source": self.a,
            "sourceReviewCommit": SOURCE_REVISION, "sourceState": {key: self.a[key] for key in COMMON},
            "provenance": self.provenance, "runtimeAdmissionStatus": self.a["runtimeAdmission"]["kind"],
            "anchorHash": keccak256(self.anchor_bytes), "transcriptHash": keccak256(self.reader.transcript()),
            "graph": graph, "current": current, "native": native, "documentary": doc,
            "historyCoverage": history["coverage"], "claims": CLAIMS, "qualification": QUALIFICATION})
        require(len(raw) <= MAX_OUTPUT, "personhood snapshot bound")
        return raw

    def snapshot(self):
        if self._snapshot is not None: return self._snapshot
        require(not self._started, "failed personhood capture cannot resume")
        self._started = True
        try: self._snapshot = self._capture()
        except MuseumError: raise
        except (KeyError, TypeError, IndexError, ValueError, OverflowError) as exc:
            raise MuseumError("malformed personhood evidence") from exc
        return self._snapshot

    def transcript(self):
        require(self._snapshot is not None, "personhood snapshot required before transcript")
        return self.reader.transcript()
