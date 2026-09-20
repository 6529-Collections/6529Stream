"""Bounded native citation evidence at one externally admitted RPC block.

Stored finality, snapshot publication and executed recovery are different facts.
This reader does not reconstruct historical execution authority or Ethereum proofs.
"""
from jsonschema import ValidationError
from tools.metadata import snapshot_profile as inline, chunked_snapshot_profile as chunked
from .account_profile import JCS_BYTES
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_abi import Array, calldata, decode, encode
from .chain_rpc import RecordingReader, ReplayTransport, RpcTransport, quantity
from .citations_v2 import canonical_citation
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require

PROFILE = "STREAM_MUSEUM_CANONICAL_CITATION_SOURCE_V1"
MAX_OUTPUT = 16777216
MAX_HISTORY = 64
MAX_SELECTED = 16
FULL_GETTER_LIMIT = 491520
SCOPE = ("uint8", "uint256", "uint256", "bytes32")
SCOPE_SIG = "(uint8,uint256,uint256,bytes32)"
COMPONENT = ("bytes32", "address", "bytes4", "bytes32", "bytes32", "bytes32", "bytes32")
MANIFEST = ("string", "bytes32", "bytes32", "bytes32", "bytes32")
COLLECTION = ("bool", "bytes32", "bytes32", "bytes32", "string", "bytes32", "address", "uint64")
SCOPED = ("bool", SCOPE, "bytes32", "bytes32", "bytes32", "bytes32", "string", "address", "uint64")
WITNESS = ("bytes32", "address", "bytes32", "bytes32", "uint64")
POINTER = ("address", "bytes32", "bool", "bytes32", "bytes4", "address", "uint8", "bytes32", "bytes32", "uint64")
PUBLICATION = ("uint256", "bytes32", "bytes32", "uint64", "bytes32", "bytes32", "string", "uint64", "bytes32")
RECEIPT = ("bytes32", "uint256", "bytes32", "bytes32", "uint64", "bytes32", "bytes32", "uint32",
           "bytes32", "bytes32", "address", "uint8", "uint64", "uint8", "uint64", "uint64", "uint64",
           "bytes32", "bytes32", "bytes32", "bytes32")
DEPENDENCIES = (("address",) * 9, ("bytes32",) * 9, "uint256", "uint256", "uint256", "uint256", "uint256")
EVIDENCE = ("uint8", "bytes32", "address", "bytes32", "uint8", "uint64", "bytes32", "uint64", "uint64", "uint32", "uint32")
RECOVERY = ("bool", "bytes32", SCOPE, "bytes32", "bytes32", "uint64", "bytes32", "bytes32", "bool",
            COMPONENT, MANIFEST, EVIDENCE, "bytes32", "string", "uint64")
RECOVERY_REQUEST = (SCOPE, "bytes32", "bytes32", "bytes32", COMPONENT, MANIFEST, "bytes32", "string")
ROUTE = ("bool", "address", "bytes32", "bytes32", "bytes32")
STATUS = ("bool", "bool", "bytes32", "bytes32")
HEAD = ("bytes32", "bytes32", "uint64")
CLAIMS = {"nativeStorageJoinsChecked": True, "originalTokenIdentityRetained": True,
    "historicalExecutionReenacted": False, "allFinalityScopesCaptured": False,
    "fullProtocolHistory": False, "defaultRendererCitationVerified": False,
    "successorDeclarationVerified": False, "pidRegistrationVerified": False,
    "cryptographicStateProof": False, "consensusVerified": False, "actualChainAcceptance": False}
QUALIFICATION = ("Exact externally pinned RPC storage observations for one original Core token. "
    "Collection/token finality records and selected native ONCHAIN snapshots only. Historical stored "
    "authority is retained, not reauthenticated. Live diagnostic mismatch does not erase history. "
    "An executed recovery citation commits its 704-byte manifest, not its action ID, route hash or original finality. "
    "No renderer, successor, PID registration, institutional conformance or consensus claim.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_reader",
    "bounds": {"outputBytes": str(MAX_OUTPUT), "transcriptBytes": "67108864", "snapshotHistory": str(MAX_HISTORY),
        "selectedSnapshots": str(MAX_SELECTED), "componentsPerScope": "32", "recoveryRecords": "64",
        "snapshotInlineBytes": "524288", "snapshotChunkedBytes": "3000000", "segmentBytes": "8192",
        "fullSnapshotGetterBytes": str(FULL_GETTER_LIMIT), "finalityManifestBytes": "32768", "recoveryManifestBytes": "704",
        "recoveryRequestBytes": "24575"},
    "rules": {"identity": "Original nonzero Core/chain/token; exact mapping, collection serial and minted/burned lifecycle.",
        "finality": "Immutable Router original binding, collection/token receipts, ordered components/hash, bytes and execution witness. Original core-facts preimage not retained by these getters and not invented.",
        "snapshot": "Exact inline/chunked domains, complete bounded receipt history with nondecreasing publication timestamps, selected full bytes reconstructed from every immutable segment; compare whole getter when transport envelope permits. Effective dates may vary. Stored sourceHash is retained, not recomputed from present state.",
        "recovery": "Both exact heads and per-family resolution/status; each existing head retains its historical original before exact/collection fallback. Complete bounded predecessor history, exact intent and recovered-route hashes, native full request ABI byte limit; no pending intent becomes rec.",
        "selection": "All nonempty observed original finality and executed recoveries become choices; snap choices only from selected complete manifests. No default is chosen.",
        "trust": "Pinned anchor/runtime/transcript; source labels remain synthetic_fixture or caller_admitted_rpc. No network fetch of document references."},
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def component_hash(value):
    return keccak256(encode((COMPONENT,), (value,)))


def recovery_intent(chain, host, r):
    # Eight-word prefix plus fourteen-word tail; content hash excluded from itself.
    return encode(("bytes32", "uint256", "address", SCOPE, "bytes32", "bytes32", "bytes32", COMPONENT,
        "bytes32", "bytes32", "bytes32", "bytes32", "bytes32"),
        (schema_id("6529STREAM_FINALITY_RECOVERY_INTENT_V1"), chain, host, r[2], r[3], r[4], r[6], r[9],
         r[10][1], r[10][3], r[10][4], r[12], keccak256(r[13].encode("utf8"))))


def recovery_request(r):
    return encode((RECOVERY_REQUEST,), ((r[2], r[3], r[4], r[6], r[9], r[10], r[12], r[13]),))


def recovered_hash(chain, host, r):
    domain = "6529STREAM_FINALITY_RECOVERY_V1" if r[2][0] == 0 else "6529STREAM_SCOPED_FINALITY_RECOVERY_V1"
    return keccak256(encode(("bytes32", "uint256", "address", "bytes32", "bytes32", "bytes32", "uint64",
        SCOPE, COMPONENT, "bytes32", EVIDENCE, "bytes32"),
        (schema_id(domain), chain, host, r[1], r[3], r[4], r[5], r[2], r[9], r[10][2], r[11], r[12])))


def snapshot_hash(chain, host, core, metadata, p, r, profile):
    before = list(r); before[0] = before[5] = ZERO
    domain = "6529STREAM_" + ("NATIVE" if profile == "inline_v1" else "CHUNKED") + "_SNAPSHOT_RECORD_V1"
    return keccak256(encode(("bytes32", "uint256", "address", "address", "address", PUBLICATION, RECEIPT),
        (schema_id(domain), chain, host, core, metadata, p, before)))


def snapshot_chain(chain, host, core, cid, previous, revision, digest, profile):
    domain = "6529STREAM_" + ("NATIVE" if profile == "inline_v1" else "CHUNKED") + "_SNAPSHOT_CHAIN_V1"
    return keccak256(encode(("bytes32", "uint256", "address", "address", "uint256", "bytes32", "uint64", "bytes32"),
        (schema_id(domain), chain, host, core, cid, previous, revision, digest)))


class CanonicalCitationSource:
    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc") and
            (provenance != "trusted_rpc" or type(transport) in (ReplayTransport, RpcTransport)), "citation provenance")
        a = loads(anchor_bytes, maximum=65536, canonical=True)
        keys = "profile chainId core tokenId collectionId blockHash blockNumber timestamp stateRoot environment deploymentEvidenceHash codePins router originalFinality recovery snapshots"
        require(type(a) is dict and set(a) == set(keys.split()) and a["profile"] == PROFILE, "citation anchor shape/profile")
        require(a["environment"] in ("local_evm_fixture", "public_chain"), "citation environment")
        for k in ("chainId", "tokenId", "collectionId"): require(uint(a[k]) > 0, "citation nonzero identity")
        uint(a["blockNumber"]); uint(a["timestamp"], 64)
        for k in ("blockHash", "stateRoot", "deploymentEvidenceHash"): require(any(hex_bytes(a[k], 32)), "citation anchor commitment")
        required = [a[k] for k in ("core", "router", "originalFinality")]
        if a["recovery"] is not None: required.append(a["recovery"])
        selected = a["snapshots"]
        if selected is not None:
            require(type(selected) is dict and set(selected) == {"host", "profile", "records"}
                and selected["profile"] in ("inline_v1", "chunked_v1"), "citation snapshot selection profile")
            require(type(selected["records"]) is list and 0 < len(selected["records"]) <= MAX_SELECTED
                and len(set(selected["records"])) == len(selected["records"]), "citation snapshot selection bound/duplicate")
            for h in selected["records"]: require(any(hex_bytes(h, 32)), "citation snapshot record hash")
            required.append(selected["host"])
        for address in required: require(any(hex_bytes(address, 20)), "citation binding address")
        require(type(a["codePins"]) is list and len(required) <= len(a["codePins"]) <= 32, "citation runtime pin bound")
        pins = {}
        for p in a["codePins"]:
            require(type(p) is dict and set(p) == {"address", "runtimeHash"}, "citation pin shape")
            require(any(hex_bytes(p["address"], 20)) and any(hex_bytes(p["runtimeHash"], 32)) and p["address"] not in pins, "citation duplicate/empty pin")
            pins[p["address"]] = p["runtimeHash"]
        require(all(address in pins for address in required), "citation missing runtime pin")
        self.anchor_bytes, self.a, self.pins, self.provenance = anchor_bytes, a, pins, provenance
        self.reader = RecordingReader(transport, a["blockHash"])
        self._started, self._snapshot, self._responses, self._byte_count = False, None, {}, 0

    def _read(self, target, signature, inputs=(), values=(), outputs=(), *, maximum=32768):
        data = calldata(signature, inputs, values)
        value = self.reader.call(target, data)
        require(type(value) is str and len(value) <= 2 + maximum * 2, "citation return bound")
        key = (target, data)
        require(key not in self._responses or value == self._responses[key], "citation repeated read differs")
        self._responses[key] = value
        return decode(outputs, hex_bytes(value), maximum=maximum)

    def _block(self):
        a = self.a
        b = self.reader.request("eth_getBlockByHash", [a["blockHash"], False])
        require(type(b) is dict and b.get("hash") == a["blockHash"] and b.get("stateRoot") == a["stateRoot"]
            and quantity(b.get("number")) == uint(a["blockNumber"]) and quantity(b.get("timestamp")) == uint(a["timestamp"]), "citation source block differs")

    def _bytes(self, raw):
        self._byte_count += len(raw)
        require(self._byte_count <= MAX_OUTPUT // 3, "citation aggregate payload bound")
        return "0x" + raw.hex()

    def _code(self, address, maximum):
        value = self.reader.code(address)
        require(type(value) is str and len(value) <= 2 + maximum * 2, "citation code return bound")
        key = (address, "code")
        require(key not in self._responses or self._responses[key] == value, "citation repeated code differs")
        self._responses[key] = value
        return hex_bytes(value)

    def _citation(self, kind, digest):
        a = self.a
        return canonical_citation(a["chainId"], a["core"], a["tokenId"], {"kind": kind, "hash": digest})

    def snapshot(self):
        if self._snapshot is not None: return self._snapshot
        require(not self._started, "citation failed capture cannot resume")
        self._started = True
        a, cid, token = self.a, uint(self.a["collectionId"]), uint(self.a["tokenId"])
        require(quantity(self.reader.request("eth_chainId", [])) == uint(a["chainId"]), "citation chain differs")
        self._block()
        for address, expected in self.pins.items():
            raw = self._code(address, 24576)
            require(0 < len(raw) <= 24576 and keccak256(raw) == expected, "citation runtime differs")
        identity = self._read(a["core"], "tokenCollectionIdentity(uint256)", ("uint256",), (token,), ("bool", "uint256", "uint256", "bool"))
        lifecycle, = self._read(a["core"], "tokenLifecycle(uint256)", ("uint256",), (token,), ("uint8",))
        require(identity[0] and identity[1] == cid and identity[2] > 0 and lifecycle in (2, 3)
            and identity[3] == (lifecycle == 3), "citation original mapping/lifecycle differs")
        for host in (a["router"], a["originalFinality"]):
            require(self._read(host, "core()", outputs=("address",)) == (a["core"],), "citation native Core binding")
        require(self._read(a["router"], "servingOriginalFinalityAnchor()", outputs=("address", "bytes32"))
            == (a["originalFinality"], self.pins[a["originalFinality"]]), "citation original finality anchor differs")
        saved = self._read(a["router"], "originalFinalityAnchor(uint256)", ("uint256",), (cid,), ("address", "bytes32"))
        require(saved in ((ZERO_ADDRESS, ZERO), (a["originalFinality"], self.pins[a["originalFinality"]])), "citation collection original anchor differs")
        for sig, expected in (("streamModuleType()", "ARTWORK_FINALITY_REGISTRY"),
                ("streamModuleVersion()", "6529stream.canonical-artwork-finality.v1")):
            require(self._read(a["originalFinality"], sig, outputs=("bytes32",)) == (schema_id(expected),), "citation original Finality profile")
        scopes = ((0, cid, 0, ZERO), (1, cid, token, ZERO))
        originals = [self._finality(scope) for scope in scopes]
        snapshots = self._snapshots() if a["snapshots"] is not None else None
        recovery = self._recovery(scopes, originals) if a["recovery"] is not None else None
        choices = {"fin": [{"hash": row["record"][2], "citation": self._citation("fin", row["record"][2]), "scope": row["scope"],
                    "finalityRecordHash": row["record"][2]} for row in originals if row["record"][0]],
            "snap": [] if snapshots is None else [{"hash": row["receipt"][6], "citation": self._citation("snap", row["receipt"][6]),
                    "manifestHash": row["receipt"][6], "recordHash": row["receipt"][0], "host": a["snapshots"]["host"]}
                    for row in snapshots["selected"]],
            "rec": [] if recovery is None else [{"hash": row["record"][10][2], "citation": self._citation("rec", row["record"][10][2]),
                    "manifestHash": row["record"][10][2], "recoveryId": row["record"][1],
                    "originalFinalityRecordHash": row["record"][3], "recoveryRouteHash": row["record"][7],
                    "scope": row["record"][2]} for row in recovery["records"]], "chain": []}
        self._block()
        if type(self.reader.transport) is ReplayTransport: self.reader.transport.finish()
        result = {"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1", "source": a,
            "mode": "caller_admitted_rpc" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "anchorHash": keccak256(self.anchor_bytes), "transcriptHash": keccak256(self.reader.transcript()),
            "originalWorkCitation": canonical_citation(a["chainId"], a["core"], a["tokenId"]),
            "identity": {"native": json_values(identity), "tokenId": a["tokenId"], "collectionId": str(identity[1]),
                "collectionSerial": str(identity[2]), "burned": identity[3], "lifecycle": str(lifecycle)},
            "finality": originals, "snapshots": snapshots, "recovery": recovery,
            "choices": choices, "claims": CLAIMS, "qualification": QUALIFICATION}
        raw = dumps(result)
        require(len(raw) <= MAX_OUTPUT, "citation output bound")
        self._snapshot = raw
        return raw

    def transcript(self):
        require(self._snapshot is not None, "citation snapshot required before transcript")
        return self.reader.transcript()

    def _finality(self, scope):
        host = self.a["originalFinality"]
        r, = self._read(host, "artworkScopeFinalityRecord(" + SCOPE_SIG + ")", (SCOPE,), (scope,), (SCOPED,))
        if scope[0] == 0:
            c, = self._read(host, "collectionFinalityRecord(uint256)", ("uint256",), (scope[1],), (COLLECTION,))
            expected = (r[0], r[2], r[3], r[4], r[6], r[5], r[7], r[8])
            require(c == expected, "citation collection/scoped record differs")
        count, = self._read(host, "finalityComponentCountForScope(" + SCOPE_SIG + ")", (SCOPE,), (scope,), ("uint256",))
        require(count <= 32, "citation component count bound")
        components, = self._read(host, "finalityComponentsForScope(" + SCOPE_SIG + ",uint256,uint256)",
            (SCOPE, "uint256", "uint256"), (scope, 0, count), (Array(COMPONENT, 32),))
        require(len(components) == count and list(components) == sorted(set(components)), "citation component count/order")
        diagnostic = self._read(host, "verifyArtworkScopeFinality(" + SCOPE_SIG + ")", (SCOPE,), (scope,), ("bool", "bytes32", "bytes32"))
        require(diagnostic[1:] == (r[2], r[5]), "citation finality diagnostic identity differs")
        raw, witness = b"", None
        if not r[0]:
            require(r == (False, (0, 0, 0, ZERO), ZERO, ZERO, ZERO, ZERO, "", ZERO_ADDRESS, 0)
                and count == 0 and not diagnostic[0], "citation malformed absent finality")
        else:
            require(r[1] == scope and r[2] != ZERO and r[3] != ZERO and r[7] == host
                and 0 < r[8] <= uint(self.a["timestamp"]) and count > 0, "citation finality scope/storage shape")
            require(len(r[6].encode("utf8")) <= 2048 and keccak256(r[6].encode("utf8")) == r[4], "citation finality URI hash")
            require(keccak256(encode(("bytes32", Array(COMPONENT, 32)),
                (schema_id("6529STREAM_FINALITY_COMPONENTS_V1"), components))) == r[5], "citation components hash differs")
            require(self._read(host, "finalityManifestStored(bytes32)", ("bytes32",), (r[3],), ("bool",)) == (True,), "citation finality manifest missing")
            raw, = self._read(host, "finalityManifestBytes(bytes32)", ("bytes32",), (r[3],), ("bytes",), maximum=32832)
            require(0 < len(raw) <= 32768 and keccak256(raw) == r[3], "citation finality manifest hash/bytes")
            witness, = self._read(host, "finalityExecutionWitness(bytes32)", ("bytes32",), (r[2],), (WITNESS,))
            require(witness[0] != ZERO and witness[1] != ZERO_ADDRESS and witness[2] != ZERO
                and witness[3] != ZERO and witness[4] > 0, "citation finality execution witness missing")
        return {"scope": json_values(scope), "record": json_values(r), "components": json_values(components),
            "currentDiagnostic": json_values(diagnostic), "manifestBytes": self._bytes(raw), "executionWitness": json_values(witness) if witness else None}

    def _snapshots(self):
        a, selection = self.a, self.a["snapshots"]
        host, profile, cid = selection["host"], selection["profile"], uint(a["collectionId"])
        d, = self._read(host, "dependencies()", outputs=(DEPENDENCIES,))
        require(d[2] == uint(a["chainId"]) and d[0][0] == a["core"] and d[0][4] == a["router"], "citation snapshot dependency identity")
        for address, digest in zip(d[0], d[1]):
            require(self.pins.get(address) == digest, "citation snapshot dependency pin missing/differs")
        for getter, expected in (("core()", d[0][0]), ("metadataHost()", d[0][1]),
                ("schemaRegistry()", d[0][2]), ("chunkStore()", d[0][3]), ("metadataRouter()", d[0][4])):
            require(self._read(host, getter, outputs=("address",)) == (expected,), "citation snapshot dependency getter differs")
        module = inline if profile == "inline_v1" else chunked
        documents = module.generated()
        pins = (keccak256(documents[f"schemas/records/{module.SCHEMA}.json"]),
            keccak256(documents[f"schemas/records/{module.PROFILE}.json"]), keccak256(JCS_BYTES))
        limit = 524288 if profile == "inline_v1" else 3000000
        count, = self._read(host, "snapshotCount(uint256)", ("uint256",), (cid,), ("uint256",))
        require(0 < count <= MAX_HISTORY, "citation snapshot history bound")
        current, = self._read(host, "currentSnapshot(uint256)", ("uint256",), (cid,), (RECEIPT,))
        history, selected, seen, ids = [], [], set(), set()
        previous, previous_chain, previous_recorded_at = ZERO, ZERO, 0
        for i in range(count):
            digest, = self._read(host, "snapshotRecordAt(uint256,uint256)", ("uint256", "uint256"), (cid, i), ("bytes32",))
            require(digest != ZERO and digest not in seen, "citation duplicate snapshot history")
            seen.add(digest)
            p, r = self._read(host, "snapshotRecord(bytes32)", ("bytes32",), (digest,), (PUBLICATION, RECEIPT))
            require(p[0] == r[1] == cid and p[1] == r[2] != ZERO and p[1] not in ids
                and p[2] == r[3] == previous and p[3] == i and r[4] == i + 1 and r[0] == digest
                and p[4] == r[8] != ZERO and p[5] == r[9] != ZERO and p[7] == r[15]
                and p[8] == r[17] != ZERO and 0 < r[15] <= r[16] <= uint(a["timestamp"])
                and r[10] != ZERO_ADDRESS and r[11] in (7, 8) and r[12] > 0 and r[13] in (7, 8)
                and r[14] > 0 and r[18:] == pins and 0 < r[7] <= limit and r[6] != ZERO
                and len(p[6].encode("utf8")) <= 2048, "citation snapshot publication/receipt linkage")
            require(r[16] >= previous_recorded_at, "citation snapshot publication time regressed")
            ids.add(p[1])
            require(snapshot_hash(uint(a["chainId"]), host, a["core"], d[0][1], p, r, profile) == digest, "citation snapshot record hash")
            require(snapshot_chain(uint(a["chainId"]), host, a["core"], cid, previous_chain, r[4], digest, profile) == r[5], "citation snapshot chain hash")
            require(self._read(host, "snapshotHash(uint256,bytes32)", ("uint256", "bytes32"), (cid, p[1]), ("bytes32",)) == (r[6],), "citation snapshot ID/manifest differs")
            history.append({"publication": json_values(p), "receipt": json_values(r)})
            if digest in selection["records"]:
                raw, chunks = self._snapshot_bytes(host, digest, cid, p[1], r[6], r[7])
                try: value = module.validate(raw)
                except (ValueError, TypeError, KeyError, UnicodeError, ValidationError) as exc: raise MuseumError("citation snapshot manifest profile") from exc
                require(value["chainId"] == a["chainId"] and value["collectionId"] == a["collectionId"]
                    and [(s["address"], s["runtimeHash"]) for s in value["sources"]] == list(zip(d[0], d[1])), "citation snapshot manifest source joins")
                pub = value["publication"]
                expected = dict(zip("snapshotId predecessor revision publisher authorizationClass grantRevision displayAuthorizationClass displayGrantRevision effectiveAt reasonHash manifestURI".split(),
                    (r[2], r[3], str(r[4]), r[10], str(r[11]), str(r[12]), str(r[13]), str(r[14]), str(r[15]), r[17], p[6])))
                require(pub == expected and value["entropy"]["planId"] == r[9], "citation snapshot manifest publication joins")
                selected.append({**history[-1], "manifestBytes": self._bytes(raw), "chunks": chunks,
                    "fullGetterCompared": len(raw) <= FULL_GETTER_LIMIT})
            previous, previous_chain, previous_recorded_at = digest, r[5], r[16]
        require(set(selection["records"]) <= seen and current == r, "citation snapshot selection/head differs")
        require(self._read(host, "latestSnapshotHash(uint256)", ("uint256",), (cid,), ("bytes32",)) == (r[6],), "citation latest snapshot manifest differs")
        return {"dependencies": json_values(d), "current": json_values(current), "history": history, "selected": selected,
            "qualification": "Complete receipt history within bound; full bytes only for selected publications. Current head means most recent publication, not current rendering or source equivalence."}

    def _snapshot_bytes(self, host, digest, cid, snapshot_id, content_hash, size):
        count, = self._read(host, "snapshotManifestChunkCount(bytes32)", ("bytes32",), (digest,), ("uint256",))
        require(count == (size + 8191) // 8192, "citation snapshot chunk count")
        require(self._byte_count + size <= MAX_OUTPUT // 3, "citation aggregate payload bound")
        chunks, parts = [], []
        for i in range(count):
            h, pointer, length = self._read(host, "snapshotManifestChunkAt(bytes32,uint256)", ("bytes32", "uint256"), (digest, i), ("bytes32", "address", "uint32"))
            require(length == min(8192, size - i * 8192) and pointer != ZERO_ADDRESS, "citation snapshot chunk length/pointer")
            code = self._code(pointer, 8193)
            require(len(code) == length + 1 and code[:1] == b"\0" and keccak256(code[1:]) == h, "citation snapshot chunk runtime hash")
            parts.append(code[1:]); chunks.append({"chunkHash": h, "pointer": pointer, "length": str(length)})
        require(self._read(host, "snapshotManifestPointer(uint256,bytes32)", ("uint256", "bytes32"), (cid, snapshot_id), ("address",)) == (chunks[0]["pointer"],), "citation first snapshot pointer")
        raw = b"".join(parts)
        require(len(raw) == size and keccak256(raw) == content_hash, "citation snapshot manifest bytes/hash")
        if size <= FULL_GETTER_LIMIT:
            whole, = self._read(host, "snapshotManifestBytes(bytes32)", ("bytes32",), (digest,), ("bytes",), maximum=size + 96)
            require(whole == raw, "citation whole snapshot getter differs")
        return raw, chunks

    def _recovery(self, scopes, originals):
        host, a = self.a["recovery"], self.a
        for getter, expected in (("core()", a["core"]), ("originalFinalityRegistry()", a["originalFinality"])):
            require(self._read(host, getter, outputs=("address",)) == (expected,), "citation recovery original binding")
        require(self._read(host, "streamModuleType()", outputs=("bytes32",)) == (schema_id("STREAM_ARTWORK_FINALITY_RECOVERY"),), "citation recovery module type")
        require(self._read(host, "streamModuleVersion()", outputs=("bytes32",)) == (schema_id("6529stream.artwork-finality-recovery.v1"),), "citation recovery module version")
        pointer, = self._read(a["core"], "getSatellitePointer(bytes32)", ("bytes32",), (schema_id("ARTWORK_FINALITY_RECOVERY"),), (POINTER,))
        require(pointer[0] == host and pointer[1] == self.pins[host] and pointer[3] == schema_id("STREAM_ARTWORK_FINALITY_RECOVERY")
            and pointer[4] == "0x83685f5c" and pointer[5] != ZERO_ADDRESS and pointer[6] in (1, 2)
            and pointer[7] != ZERO and pointer[8] != ZERO and pointer[9] > 0, "citation current recovery pointer")
        original_by_hash = {row["record"][2]: row for row in originals if row["record"][0]}
        records, heads, routes = {}, [], []
        def retain(digest):
            if digest in records: return records[digest]
            require(digest != ZERO and len(records) < MAX_HISTORY, "citation recovery history bound")
            r, = self._read(host, "finalityRecoveryRecord(bytes32)", ("bytes32",), (digest,), (RECOVERY,))
            require(r[0] and r[1] == digest and r[2] in scopes and r[3] in original_by_hash and r[5] > 0
                and r[6] != ZERO and r[7] != ZERO and r[8] and r[12] != ZERO and 0 < r[14] <= uint(a["timestamp"]), "citation executed recovery identity/scope")
            original_scope = tuple(int(v) if i < 3 else v for i, v in enumerate(original_by_hash[r[3]]["scope"]))
            require(original_scope == r[2] or original_scope == scopes[0], "citation recovery original scope")
            require(len(r[10][0].encode("utf8")) > 0
                and r[10][1] == keccak256(r[10][0].encode("utf8")) and all(h != ZERO for h in r[10][2:]), "citation recovery manifest reference")
            require(len(recovery_request(r)) <= 24575, "citation recovery request ABI byte bound")
            require(r[11][0] in (1, 2), "citation recovery evidence kind")
            raw, = self._read(host, "finalityRecoveryManifestBytes(bytes32)", ("bytes32",), (r[10][2],), ("bytes",), maximum=768)
            require(len(raw) == 704 and raw == recovery_intent(uint(a["chainId"]), host, r)
                and keccak256(raw) == r[10][2] and recovered_hash(uint(a["chainId"]), host, r) == r[7], "citation recovery manifest/route hash")
            records[digest] = r
            return r
        for scope in scopes:
            head = self._read(host, "activeFinalityRecovery(" + SCOPE_SIG + ")", (SCOPE,), (scope,), HEAD)
            if head[0] == ZERO: require(head == (ZERO, ZERO, 0), "citation malformed empty recovery head")
            else:
                r = retain(head[0])
                require(r[2] == scope and (r[7], r[5]) == head[1:], "citation recovery head differs")
            heads.append({"scope": json_values(scope), "head": json_values(head)})
            # A head permanently retains its admitted original, even when a later exact
            # token finality now exists. Native resolution consults current exact/collection
            # originals only when this scope has no recovery head.
            origin = (original_by_hash[records[head[0]][3]] if head[0] != ZERO else
                originals[scope[0]] if originals[scope[0]]["record"][0] else originals[0])
            for family in sorted({c[0] for c in origin["components"]}):
                route = self._read(host, "resolvedFinalityRoute(bytes32," + SCOPE_SIG + ")", ("bytes32", SCOPE), (family, scope), ROUTE)
                status = self._read(host, "finalityRecoveryRouteStatus(bytes32," + SCOPE_SIG + ")", ("bytes32", SCOPE), (family, scope), STATUS)
                require(route[0] == status[0] and route[2] == status[2] and route[4] == status[3], "citation recovery route/status differs")
                require(route[0] and route[3] == origin["record"][2] and route[1] != ZERO_ADDRESS, "citation resolved original/family differs")
                if route[4] != ZERO:
                    r = retain(route[4])
                    require(r[3] == route[3] and r[2] in (scope, scopes[0]) and r[9][0] == family
                        and r[9][1] == route[1] and component_hash(r[9]) == route[2], "citation selected recovery family differs")
                else:
                    matches = [c for c in origin["components"] if c[0] == family]
                    require(len(matches) == 1 and matches[0][1] == route[1] and component_hash(matches[0]) == route[2], "citation original route differs")
                routes.append({"scope": json_values(scope), "family": family, "route": json_values(route), "status": json_values(status)})
        for digest in list(records):
            seen = set()
            r = records[digest]
            while True:
                require(r[1] not in seen, "citation recovery cycle")
                seen.add(r[1])
                if r[4] == ZERO:
                    require(r[5] == 1, "citation recovery first generation")
                    break
                prior = retain(r[4])
                require(prior[2] == r[2] and prior[3] == r[3] and prior[5] + 1 == r[5]
                    and prior[14] <= r[14], "citation recovery predecessor lineage")
                r = prior
        # Check the current family override against the complete retained exact-head chain.
        # Later actions in other families do not replace this family's selected action.
        for selected in routes:
            scope = tuple(int(v) if i < 3 else v for i, v in enumerate(selected["scope"]))
            head = heads[scope[0]]["head"][0]
            if head == ZERO and selected["route"][3] == originals[0]["record"][2]:
                head = heads[0]["head"][0]
            expected = ZERO
            while head != ZERO:
                r = records[head]
                if r[9][0] == selected["family"]:
                    expected = head
                    break
                head = r[4]
            require(selected["route"][4] == expected, "citation recovery override is not latest family action")
        return {"exactHeads": heads, "routes": routes,
            "records": [{"record": json_values(r), "manifestBytes": self._bytes(recovery_intent(uint(a["chainId"]), host, r))}
                for _, r in sorted(records.items())],
            "qualification": "Exact-scope heads differ from per-family overrides. Diagnostic currentness is independent of permanent executed provenance."}
