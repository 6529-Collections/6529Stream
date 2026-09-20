"""Complete bounded collection/token RIGHTS selection from the original native graph.

Selection is a recorded notice. This reader neither resolves legal rights nor
turns source timestamps into an unprovided civil-date assessment convention.
"""
from tools.metadata.rights_profile import USES
from .account_profile import JCS_BYTES
from .canonical import dumps, hex_bytes, keccak256, loads, record_chain, schema_id, subject_id, uint
from .chain_abi import calldata, decode, encode
from .chain_history import MAX_BLOCKS, scan_history
from .chain_rpc import RecordingReader, ReplayTransport, RpcTransport, quantity
from .independent_source import IndependentSourceAdapter
from .independent_wire import RECORD, RAW_BYTES, ZERO, ZERO_ADDRESS, generic_hash, json_values, require
from .metadata_rights_source import (SCHEMA_NAME, SCHEMA_BYTES, SCHEMA_HASH, PROFILE_NAME,
    PROFILE_BYTES as RIGHTS_PROFILE_BYTES, PROFILE_HASH as RIGHTS_PROFILE_HASH, JCS_ID,
    RECORD_TYPE, RECEIPT, POINTER, validate_rights)

PROFILE = "STREAM_MUSEUM_CURRENT_RIGHTS_SOURCE_V1"
MAX_REVISIONS = 64
MAX_OUTPUT = 8 * 1024 * 1024
SELECTION = ("bytes32", "bytes32", "bytes32", "address", "uint256", "uint64", "uint64", "uint64",
    "uint64", "uint8", "address", "uint8", "bytes32", "bytes32")
EMPTY_SELECTION = (ZERO, ZERO, ZERO, ZERO_ADDRESS, 0, 0, 0, 0, 0, 0, ZERO_ADDRESS, 0, ZERO, ZERO)
PROVIDER_CONFIG = (("address",) * 22, ("bytes32",) * 22, "uint256", "uint256", "uint256", "uint256", "bytes32")
DOCUMENT_FACTS = ("bool", "uint8", "uint8", "bytes32", "bytes32", "bytes32", "uint32", "uint256", "bytes32")
PRESENTATION = ("bool", "address", "bytes32", "bytes32", "uint64", "bytes32", "address", "bytes32", "bytes32", "uint64", "uint64", "bytes32")
SUITE = ("address", "address", ("address",) * 7, "address", "address", "address", "address", "address", "address", "bytes32", "address")
METADATA_RECORDED = schema_id("CollectionRecordRecorded(uint256,bytes32,bytes32,(bytes32,bytes32,(uint16,bytes,bytes32),string,bytes32,bytes32,(uint16,bytes,bytes32),uint64),bytes32,bytes32,address,bytes32,uint16)")
CLAIMS = {"completeCollectionTokenSelectedHistory": True, "canonicalOriginalProviderBinding": True,
    "nativeCurrentSelectionChecked": True, "originalPublicationBlocksChecked": True,
    "fullMetadataLaneHistory": False, "currentGrantReauthorization": False,
    "legalRightsProven": False, "effectiveDateApplicabilityAssessed": False,
    "completeFinalityProviderEligibility": False, "consensusVerified": False,
    "cryptographicStateProof": False, "cryptographicReceiptProof": False, "actualChainAcceptance": False}
QUALIFICATION = ("Complete selected RIGHTS history for one collection and its token at a supplied RPC anchor. "
    "Core's installed router binds its original finality registry and that registry's native provider, which "
    "fixes this selector. Original records, publisher and selector classes, grants, dates and instruments "
    "remain recorded notices. Token grants, including unspecified, take precedence per use. No date "
    "applicability, legal permission, current grant authority, consensus or complete finality eligibility is inferred. "
    "This admission profile requires installed ACTIVE Core pointers; it does not model every Core tokenURI fallback. "
    "An absent selection says nothing about unselected historical RIGHTS publications.")
PROFILE_BYTES = dumps({"id": PROFILE, "version": "1", "status": "prospective_unregistered_export_profile",
    "sourceReviewCommit": "1bc06f5bcb403ae56e07cb627578fd18626a81c8",
    "bounds": {"revisionsPerScope": str(MAX_REVISIONS), "scopes": "2", "payloadBytes": "8192",
        "blocksIncludingGenesis": str(MAX_BLOCKS), "snapshotBytes": str(MAX_OUTPUT), "transcriptBytes": "67108864"},
    "rules": {"binding": "Installed ACTIVE Core METADATA_ROUTER -> servingOriginalFinalityAnchor with locked/saved anchor parity -> scopeEvidenceProvider and immutable code hash -> nativeConfiguration.targets[16]; current Core COLLECTION_METADATA must match targets[1].",
        "selection": "Exact zero or revision1 through current head; zero selectionHash when recomputing 23-word native preimage; predecessor, record index, time and original receipt joins. Every relevant RightsRecordSelected event bijectively matches history and follows original publication.",
        "definitions": "Exact original RIGHTS schema, JSON profile and JCS bytes; active compact document facts, RAW_BYTES declarations and ordered immutable Store chunks.",
        "publication": "Every header and receipt to genesis; original CollectionRecordRecorded event determines recordedBlock. No selected transaction hint denominator.",
        "precedence": "Token record wins all six explicitly present grant statuses, including unspecified; never fall back per missing meaning. Both source records remain visible.",
        "dates": "Retain inclusive Gregorian effectiveDates and original effectiveAt. No inferred timezone or automatic date eligibility/filtering.",
        "absence": "All fourteen current getter words zero on the canonical bound selector; missing or unsupported evidence fails capture."},
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _interface(signatures):
    value = 0
    for signature in signatures: value ^= int(schema_id(signature)[:10], 16)
    return "0x" + f"{value:08x}"


_DOCUMENT_SIG = "(bool,string,bytes32)"
_GRANT_SIG = "(uint8,(uint8,string," + _DOCUMENT_SIG + "),string)"
_STATEMENT_SIG = "(bytes32,bytes32,uint8,(uint8,bytes32,string,address,bytes32),(" + ",".join([_GRANT_SIG] * 6) + "),uint32,uint32,bool," + _DOCUMENT_SIG + ",bool,uint8,bytes32)"
RIGHTS_INTERFACE = _interface(("core()", "metadata()", "schemaRegistry()", "chunkStore()", "deploymentChainId()",
    "selectCurrent(uint256,bytes32,bytes32,bytes32,uint64," + _STATEMENT_SIG + ")", "currentRights(uint256,bytes32)",
    "rightsSelectionAt(uint256,bytes32,uint64)", "requireCurrent(uint256,bytes32,bytes32,uint64)"))
SELECTED_EVENT = schema_id("RightsRecordSelected(uint256,bytes32,bytes32,(" + ",".join(SELECTION) + "))")


def selection_hash(a, subject, row):
    return keccak256(encode(("bytes32", "uint256", "address", "address", "address", "address", "address",
        "uint256", "bytes32", SELECTION), (schema_id("6529STREAM_RIGHTS_SELECTION_V1"), uint(a["chainId"]),
        a["rightsSelector"], a["core"], a["host"], a["schemas"], a["store"], uint(a["collectionId"]),
        subject, row[:-1] + (ZERO,))))


class CurrentRightsSource:
    _chunk = IndependentSourceAdapter._chunk

    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc") and
            (provenance != "trusted_rpc" or type(transport) in (RpcTransport, ReplayTransport)), "current RIGHTS provenance")
        a = loads(anchor_bytes, maximum=65536, canonical=True)
        hosts = ("core", "host", "router", "originalFinality", "provider", "rightsSelector", "schemas", "store")
        require(type(a) is dict and set(a) == set(hosts) | {"profile", "chainId", "tokenId", "collectionId", "blockHash",
            "blockNumber", "timestamp", "stateRoot", "environment", "deploymentEvidenceHash", "codePins"}
            and a["profile"] == PROFILE, "current RIGHTS anchor shape/profile")
        require(a["environment"] in ("local_evm_fixture", "public_chain"), "current RIGHTS environment")
        for name in ("chainId", "tokenId", "collectionId", "blockNumber", "timestamp"):
            uint(a[name], 64 if name == "timestamp" else 256)
        require(all(uint(a[k]) > 0 for k in ("chainId", "tokenId", "collectionId")), "current RIGHTS nonzero identity")
        for name in ("blockHash", "stateRoot", "deploymentEvidenceHash"):
            require(any(hex_bytes(a[name], 32)), "current RIGHTS commitment")
        require(len({a[k] for k in hosts}) == len(hosts), "current RIGHTS distinct native hosts")
        for name in hosts: require(any(hex_bytes(a[name], 20)), "current RIGHTS native address")
        require(type(a["codePins"]) is list and len(hosts) <= len(a["codePins"]) <= 64, "current RIGHTS pin bound")
        pins = {}
        for row in a["codePins"]:
            require(type(row) is dict and set(row) == {"address", "runtimeHash"}, "current RIGHTS pin shape")
            require(any(hex_bytes(row["address"], 20)) and any(hex_bytes(row["runtimeHash"], 32))
                and row["address"] not in pins, "current RIGHTS duplicate/zero pin")
            pins[row["address"]] = row["runtimeHash"]
        require(all(a[k] in pins for k in hosts), "current RIGHTS missing native pin")
        self.anchor_bytes, self.a, self.pins, self.provenance = anchor_bytes, a, pins, provenance
        self.reader = RecordingReader(transport, a["blockHash"])
        self._snapshot, self._started, self._reads = None, False, {}
        self.chunks, self.documents, self.records, self.artist_identities = {}, {}, {}, {}

    def _read(self, target, signature, inputs=(), values=(), outputs=(), maximum=32768):
        data = calldata(signature, inputs, values)
        result = self.reader.call(target, data)
        require(type(result) is str and len(result) <= 2 + 2 * maximum, "current RIGHTS return bound")
        key = (target, data)
        require(key not in self._reads or self._reads[key] == result, "current RIGHTS repeated read differs")
        self._reads[key] = result
        raw = hex_bytes(result)
        return raw, decode(outputs, raw, maximum=maximum)

    def _one(self, target, signature, kind, inputs=(), values=()):
        return self._read(target, signature, inputs, values, (kind,))[1][0]

    def _pointer(self, name, target):
        p = self._one(self.a["core"], "getSatellitePointer(bytes32)", POINTER, ("bytes32",), (schema_id(name),))
        require(p[0] == "0x" + "00" * 12 + target[2:] and p[1] == self.pins[target]
            and p[3] == schema_id(name) and p[6] == "0x" + "00" * 31 + "01", "current RIGHTS Core pointer differs")
        return p

    def _bindings(self):
        a = self.a
        for address, expected in self.pins.items():
            code = self.reader.code(address)
            require(type(code) is str and 2 < len(code) <= 2 + 24576 * 2
                and keccak256(hex_bytes(code)) == expected, "current RIGHTS runtime differs")
        pointers = {"metadata": self._pointer("COLLECTION_METADATA", a["host"]),
            "router": self._pointer("METADATA_ROUTER", a["router"])}
        for target, interfaces in ((a["core"], ("0x80ac58cd",)), (a["rightsSelector"], (RIGHTS_INTERFACE,))):
            for interface in ("0x01ffc9a7",) + interfaces:
                require(self._one(target, "supportsInterface(bytes4)", "bool", ("bytes4",), (interface,)), "current RIGHTS native interface")
            require(not self._one(target, "supportsInterface(bytes4)", "bool", ("bytes4",), ("0xffffffff",)), "current RIGHTS invalid interface")
        require(self._one(a["router"], "core()", "address") == a["core"], "current RIGHTS router Core differs")
        require(self._read(a["router"], "servingOriginalFinalityAnchor()", outputs=("address", "bytes32"))[1]
            == (a["originalFinality"], self.pins[a["originalFinality"]]), "current RIGHTS original finality anchor differs")
        presentation = self._one(a["router"], "artistPresentation(uint256)", PRESENTATION, ("uint256",), (uint(a["collectionId"]),))
        saved = self._read(a["router"], "originalFinalityAnchor(uint256)", ("uint256",), (uint(a["collectionId"]),), ("address", "bytes32"))[1]
        require(saved == ((a["originalFinality"], self.pins[a["originalFinality"]]) if presentation[0] else (ZERO_ADDRESS, ZERO)),
            "current RIGHTS saved original/presentation lock differs")
        for signature, expected in (("coreReads()", a["core"]), ("metadataReads()", a["host"]),
            ("scopeEvidenceProvider()", a["provider"])):
            require(self._one(a["originalFinality"], signature, "address") == expected, "current RIGHTS original provider binding differs")
        require(self._one(a["originalFinality"], "scopeEvidenceProviderCodeHash()", "bytes32") == self.pins[a["provider"]],
            "current RIGHTS immutable provider code hash differs")
        configuration = self._one(a["provider"], "nativeConfiguration()", PROVIDER_CONFIG)
        targets, hashes, chain, read_gas, source_gas, component_gas, inventory_hash = configuration
        require(chain == uint(a["chainId"]) and 0 < read_gas <= component_gas <= (1 << 32) - 1
            and source_gas > component_gas + component_gas // 63 + 100000 and source_gas < 1 << 32
            and inventory_hash != ZERO and all(t != ZERO_ADDRESS for t in targets) and all(h != ZERO for h in hashes),
            "current RIGHTS native provider configuration")
        for index, key in ((0, "core"), (1, "host"), (2, "router"), (4, "schemas"), (5, "store"),
            (12, "originalFinality"), (16, "rightsSelector")):
            require(targets[index] == a[key] and hashes[index] == self.pins[a[key]], "current RIGHTS canonical selector configuration differs")
        for signature, expected in (("core()", a["core"]), ("metadataHost()", a["host"]), ("metadataRouter()", a["router"])):
            require(self._one(a["provider"], signature, "address") == expected, "current RIGHTS provider reciprocal binding")
        for signature, expected in (("coreCodeHash()", self.pins[a["core"]]), ("metadataHostCodeHash()", self.pins[a["host"]]),
            ("metadataRouterCodeHash()", self.pins[a["router"]])):
            require(self._one(a["provider"], signature, "bytes32") == expected, "current RIGHTS provider reciprocal code pin")
        require(self._one(a["provider"], "deploymentChainId()", "uint256") == chain, "current RIGHTS provider chain")
        for key, getter in (("core", "core"), ("host", "metadata"), ("schemas", "schemaRegistry"), ("store", "chunkStore")):
            require(self._one(a["rightsSelector"], getter + "()", "address") == a[key]
                and self._one(a["rightsSelector"], getter + "CodeHash()", "bytes32") == self.pins[a[key]],
                "current RIGHTS selector immutable dependency")
        require(self._one(a["rightsSelector"], "deploymentChainId()", "uint256") == chain, "current RIGHTS selector chain")
        for key, getter in (("core", "core"), ("schemas", "schemaRegistry"), ("store", "chunkStore")):
            require(self._one(a["host"], getter + "()", "address") == a[key]
                and self._one(a["host"], getter + "CodeHash()", "bytes32") == self.pins[a[key]], "current RIGHTS Metadata binding")
        require(self._one(a["schemas"], "chunkStore()", "address") == a["store"], "current RIGHTS definition Store binding")
        self._configuration = configuration
        return {"corePointers": {k: json_values(v) for k, v in pointers.items()}, "nativeConfiguration": json_values(configuration),
            "artistPresentation": json_values(presentation), "savedOriginalFinalityAnchor": json_values(saved),
            "originalProvider": a["provider"], "rightsSelector": a["rightsSelector"]}

    def _definitions(self):
        for name, kind, expected in ((SCHEMA_NAME, 0, SCHEMA_BYTES), (PROFILE_NAME, 2, RIGHTS_PROFILE_BYTES),
            ("RFC8785_JCS", 1, JCS_BYTES)):
            key = schema_id(name)
            facts = self._one(self.a["schemas"], "documentFacts(bytes32)", DOCUMENT_FACTS, ("bytes32",), (key,))
            require(facts[:7] == (True, kind, 0, keccak256(expected), RAW_BYTES, ZERO, len(expected))
                and 0 < facts[7] <= 64 and facts[8] != ZERO, "current RIGHTS active definition facts differ")
            parts, hashes = [], []
            for index in range(facts[7]):
                digest = self._one(self.a["schemas"], "documentChunkHashAt(bytes32,uint256)", "bytes32",
                    ("bytes32", "uint256"), (key, index))
                part = self._chunk(digest)
                require(index + 1 == facts[7] or len(part) == 8192, "current RIGHTS definition segment length")
                parts.append(part); hashes.append(digest)
            raw = b"".join(parts)
            require(raw == expected, "current RIGHTS complete definition bytes differ")
            self.documents[key] = {"documentId": key, "payloadHex": "0x" + raw.hex(), "facts": json_values(facts), "chunkHashes": hashes}

    def _original(self, record_hash, subject):
        if record_hash in self.records:
            require(self.records[record_hash]["record"][1] == subject, "current RIGHTS repeated original subject")
            return self.records[record_hash]
        a, cid = self.a, uint(self.a["collectionId"])
        _, (record, receipt) = self._read(a["host"], "collectionRecord(bytes32)", ("bytes32",), (record_hash,), (RECORD, RECEIPT))
        rt, sid, content, uri, schema, scheme, signature, effective = record
        require(receipt[0] == cid and receipt[1] != ZERO_ADDRESS and receipt[2] in (7, 8)
            and 0 < receipt[3] <= uint(a["timestamp"]) and receipt[6:9] == (SCHEMA_HASH, keccak256(JCS_BYTES), ZERO)
            and rt == RECORD_TYPE and sid == subject and schema == schema_id(SCHEMA_NAME)
            and content[0] == 1 and len(content[1]) == 32 and content[2] == JCS_ID
            and scheme == ZERO and signature == (0, b"", ZERO) and effective > 0,
            "current RIGHTS original receipt/family/definition differs")
        require(generic_hash(uint(a["chainId"]), a["host"], a["core"], cid, receipt[1], record) == record_hash,
            "current RIGHTS original record hash differs")
        require(self._one(a["host"], "recordHashAt(uint256,bytes32,uint256)", "bytes32",
            ("uint256", "bytes32", "uint256"), (cid, rt, receipt[4])) == record_hash, "current RIGHTS original index differs")
        previous = ZERO
        if receipt[4]:
            prior = self._one(a["host"], "recordHashAt(uint256,bytes32,uint256)", "bytes32",
                ("uint256", "bytes32", "uint256"), (cid, rt, receipt[4] - 1))
            _, (pr, rr) = self._read(a["host"], "collectionRecord(bytes32)", ("bytes32",), (prior,), (RECORD, RECEIPT))
            require(prior != ZERO and pr[0] == rt and rr[0] == cid and rr[4] + 1 == receipt[4]
                and generic_hash(uint(a["chainId"]), a["host"], a["core"], cid, rr[1], pr) == prior,
                "current RIGHTS original lane predecessor differs")
            previous = rr[5]
        require(record_chain(a["chainId"], a["host"], a["collectionId"], rt, previous, record_hash, str(receipt[4])) == receipt[5],
            "current RIGHTS original chain differs")
        payload = self._chunk("0x" + content[1].hex())
        value = validate_rights(payload, subject)
        row = {"recordHash": record_hash, "record": json_values(record), "receipt": json_values(receipt),
            "payloadHex": "0x" + payload.hex(), "value": value, "publication": None}
        self.records[record_hash] = row
        return row

    def _artist(self, artist):
        if artist in self.artist_identities: return self.artist_identities[artist]["identityRecordHash"]
        a = self.a; facade = self._configuration[0][11]
        require(facade in self.pins and self.pins[facade] == self._configuration[1][11]
            and self._one(a["host"], "artistRegistry()", "address") == facade
            and self._one(a["host"], "artistRegistryCodeHash()", "bytes32") == self.pins[facade]
            and self._one(facade, "core()", "address") == a["core"], "current RIGHTS licensor facade binding")
        coordinator = self._one(facade, "operationCoordinator()", "address")
        require(coordinator in self.pins and self._one(coordinator, "deploymentChainId()", "uint256") == uint(a["chainId"]),
            "current RIGHTS licensor coordinator binding")
        suite = self._one(coordinator, "suiteConfiguration()", SUITE)
        require(suite[0] == facade and suite[3] == a["core"], "current RIGHTS licensor suite binding")
        owner = suite[2][2]
        require(owner in self.pins and self._one(owner, "core()", "address") == a["core"]
            and self._one(owner, "artistRegistry()", "address") == facade
            and self._one(owner, "operationCoordinator()", "address") == coordinator
            and self._one(owner, "deploymentChainId()", "uint256") == uint(a["chainId"]), "current RIGHTS licensor Identity owner binding")
        _, identity = self._read(owner, "authorityState(bytes32)", ("bytes32",), (artist,), ("address", "uint8", "uint8", "bytes32"))
        require(identity[3] != ZERO, "current RIGHTS unknown licensor registration")
        self.artist_identities[artist] = {"artistId": artist, "identityRecordHash": identity[3], "identityOwner": owner,
            "authorityState": json_values(identity), "qualification": "Immutable known registration only; current status or collection artist equality is not required."}
        return identity[3]

    def _scope(self, kind):
        a, cid = self.a, uint(self.a["collectionId"])
        subject = subject_id(kind, a["chainId"], a["core"], a["collectionId"], token_id=a["tokenId"] if kind == "token" else "0")
        head = self._one(a["rightsSelector"], "currentRights(uint256,bytes32)", SELECTION, ("uint256", "bytes32"), (cid, subject))
        if head[0] == ZERO:
            require(head == EMPTY_SELECTION, "current RIGHTS partial empty head")
            return {"status": "absent", "subjectId": subject, "current": json_values(head), "history": []}
        require(0 < head[6] <= MAX_REVISIONS, "current RIGHTS selected history bound")
        history, previous = [], EMPTY_SELECTION
        for revision in range(1, head[6] + 1):
            row = self._one(a["rightsSelector"], "rightsSelectionAt(uint256,bytes32,uint64)", SELECTION,
                ("uint256", "bytes32", "uint64"), (cid, subject, revision))
            require(row[0] != ZERO and row[1] == previous[0] and row[2] != ZERO and row[3] != ZERO_ADDRESS
                and row[4] in (0, cid) and row[5] > 0 and row[6] == revision
                and previous[8] <= row[8] <= uint(a["timestamp"]) and row[9] in (7, 8)
                and row[10] != ZERO_ADDRESS and row[11] in (7, 8)
                and (revision == 1 or row[7] > previous[7]) and selection_hash(a, subject, row) == row[13],
                "current RIGHTS selection hash/lineage/authority differs")
            original = self._original(row[0], subject); receipt = original["receipt"]
            require(row[2] == keccak256(hex_bytes(original["payloadHex"])) and row[7] == uint(receipt[4])
                and row[8] >= uint(receipt[3]) and row[10] == receipt[1] and row[11] == uint(receipt[2])
                and original["value"]["predecessor"] == (None if previous[0] == ZERO else previous[0]),
                "current RIGHTS selected original/payload predecessor differs")
            licensor = original["value"]["licensor"]["identity"]
            require(row[12] == (self._artist(licensor["artistId"]) if licensor["kind"] == "artist" else ZERO),
                "current RIGHTS licensor registration differs")
            history.append(json_values(row)); previous = row
        require(previous == head, "current RIGHTS last history/head differs")
        require(self._one(a["rightsSelector"], "requireCurrent(uint256,bytes32,bytes32,uint64)", SELECTION,
            ("uint256", "bytes32", "bytes32", "uint64"), (cid, subject, head[0], head[6])) == head,
            "current RIGHTS consuming eligibility differs")
        return {"status": "present", "subjectId": subject, "current": json_values(head), "history": history}

    def _publications(self, history):
        for log in history["logs"]:
            if log["address"] != self.a["host"] or not log["topics"] or log["topics"][0] != METADATA_RECORDED: continue
            require(len(log["topics"]) == 4, "current RIGHTS publication topics")
            _, digest, chain, recorder, authority, version = values = decode((RECORD, "bytes32", "bytes32", "address", "bytes32", "uint16"),
                hex_bytes(log["data"]), maximum=32768)
            if digest not in self.records: continue
            original = self.records[digest]; receipt = original["receipt"]
            require(original["publication"] is None and json_values(values[0]) == original["record"]
                and chain == receipt[5] and recorder == receipt[1] and authority == "0x" + uint(receipt[2]).to_bytes(32, "big").hex()
                and version == 1 and log["topics"][1:] == ["0x" + uint(self.a["collectionId"]).to_bytes(32, "big").hex(),
                    RECORD_TYPE, original["record"][1]] and receipt[3] == history["blockTimestamps"][str(quantity(log["blockNumber"]))],
                "current RIGHTS original publication event differs")
            original["publication"] = {"recordedBlock": str(quantity(log["blockNumber"])), "log": log}
        require(all(row["publication"] is not None for row in self.records.values()), "current RIGHTS original publication missing")

    def _selection_events(self, history, scopes):
        by_subject = {scope["subjectId"]: scope for scope in scopes.values()}
        for scope in scopes.values(): scope["events"] = []
        for log in history["logs"]:
            if log["address"] != self.a["rightsSelector"] or not log["topics"] or log["topics"][0] != SELECTED_EVENT: continue
            require(len(log["topics"]) == 4, "current RIGHTS selected event topics")
            cid, = decode(("uint256",), hex_bytes(log["topics"][1], 32))
            if cid != uint(self.a["collectionId"]) or log["topics"][2] not in by_subject: continue
            scope = by_subject[log["topics"][2]]
            row, = decode((SELECTION,), hex_bytes(log["data"]), maximum=448)
            position = len(scope["events"])
            require(position < len(scope["history"]) and json_values(row) == scope["history"][position]
                and row[0] == log["topics"][3] and str(row[8]) == history["blockTimestamps"][str(quantity(log["blockNumber"]))],
                "current RIGHTS selected event/history differs")
            publication = self.records[row[0]]["publication"]["log"]
            require((quantity(publication["blockNumber"]), quantity(publication["logIndex"])) <
                (quantity(log["blockNumber"]), quantity(log["logIndex"])), "current RIGHTS selection precedes publication")
            scope["events"].append(log)
        require(all(len(scope["events"]) == len(scope["history"]) for scope in scopes.values()),
            "current RIGHTS missing selected event")

    def snapshot(self):
        if self._snapshot is not None: return self._snapshot
        require(not self._started, "current RIGHTS failed capture cannot resume"); self._started = True
        a = self.a; history = scan_history(self.reader, a)
        source_header = dumps(next(row["result"] for row in self.reader.rows if row["method"] == "eth_getBlockByHash"
            and row["params"] == [a["blockHash"], False]))
        binding = self._bindings()
        _, identity = self._read(a["core"], "tokenCollectionIdentity(uint256)", ("uint256",), (uint(a["tokenId"]),), ("bool", "uint256", "uint256", "bool"))
        lifecycle = self._one(a["core"], "tokenLifecycle(uint256)", "uint8", ("uint256",), (uint(a["tokenId"]),))
        require(identity[0] and identity[1] == uint(a["collectionId"]) and identity[2] > 0 and lifecycle in (2, 3)
            and identity[3] == (lifecycle == 3), "current RIGHTS token identity/lifecycle differs")
        self._definitions()
        scopes = {kind: self._scope(kind) for kind in ("collection", "token")}
        self._publications(history)
        self._selection_events(history, scopes)
        chosen = scopes["token"] if scopes["token"]["status"] == "present" else scopes["collection"]
        grants = ({use: "unspecified" for use in USES} if chosen["status"] == "absent" else
            {use: self.records[chosen["current"][0]]["value"]["grants"][use]["status"] for use in USES})
        count = sum(value != "unspecified" for value in grants.values())
        completeness = "absent" if chosen["status"] == "absent" else "specified" if count == 6 else "unspecified" if count == 0 else "partially_specified"
        for scope in scopes.values():
            require(json_values(self._one(a["rightsSelector"], "currentRights(uint256,bytes32)", SELECTION,
                ("uint256", "bytes32"), (uint(a["collectionId"]), scope["subjectId"]))) == scope["current"], "current RIGHTS final selected head differs")
        require(dumps(self.reader.request("eth_getBlockByHash", [a["blockHash"], False])) == source_header, "current RIGHTS final source header differs")
        seen = {}
        for row in self.reader.rows:
            key, value = dumps([row["method"], row["params"]]), dumps(row["result"])
            require(key not in seen or seen[key] == value, "current RIGHTS repeated RPC result differs")
            seen[key] = value
        if type(self.reader.transport) is ReplayTransport: self.reader.transport.finish()
        result = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1", "source": a,
            "mode": "caller_admitted_rpc" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "anchorHash": keccak256(self.anchor_bytes), "transcriptHash": keccak256(self.reader.transcript()), "binding": binding,
            "identity": {"tokenId": a["tokenId"], "collectionId": a["collectionId"], "collectionSerial": str(identity[2]),
                "lifecycle": str(lifecycle), "burned": identity[3]}, "scopes": scopes,
            "records": list(self.records.values()), "documents": list(self.documents.values()),
            "artistLicensorIdentities": list(self.artist_identities.values()), "effectiveGrants": grants, "completeness": completeness,
            "historyCoverage": {k: history[k] for k in ("startBlock", "endBlock", "blockCount", "transactionCount")},
            "dateAssessment": "not_assessed_no_inferred_timezone", "claims": CLAIMS, "qualification": QUALIFICATION})
        require(len(result) <= MAX_OUTPUT, "current RIGHTS snapshot bound")
        self._snapshot = result
        return result

    def transcript(self):
        require(self._snapshot is not None, "current RIGHTS snapshot required before transcript")
        return self.reader.transcript()
