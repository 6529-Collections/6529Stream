"""Current native attribution and generation-specific original sanction evidence."""
from . import artist_attestation_source as artist
from . import public_personhood_source as personhood
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_abi import Array, calldata, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require
from .owner_catalog_source import _location, _position
from .public_chain_history import scan_public_history, PROFILE_HASH as HISTORY_PROFILE_HASH
from .public_history_rpc import PublicRecordingReader, PublicReplayTransport, PublicRpcTransport

PROFILE = "STREAM_MUSEUM_PUBLIC_ATTRIBUTION_SOURCE_V1"
SOURCE_REVISION = "905bbe2a3f33f5e7fca436a987d8cba532149e8e"
COMMON = personhood.COMMON
MAX_ANCHOR, MAX_ABI, MAX_OUTPUT, MAX_EVENTS, MAX_ARCHIVES = 65536, 65536, 32 * 1024 * 1024, 128, 256
MAX_TRANSITION_URI = 8192
TERMS = ("uint8", "uint256", "uint256", "bytes32", "bytes32", "bytes32")
RECORD = ("bytes32", "bytes32", "address", "uint8", TERMS, "uint256", "uint64", "uint64", "uint64", "bytes32", "bytes32")
SUBJECT = ("bytes32", "uint256", "address", "address", "uint8", "uint256", "uint256", "bytes32") + ("bytes32",) * 6
SUBJECT_FIELDS = ("domain", "chainId", "core", "finalityRegistry", "scopeType", "collectionId", "tokenId", "scopeId",
    "coreFactsHash", "nonSanctionComponentsHash", "manifestURIHash", "manifestContentHash", "manifestSchemaId", "manifestCanonicalizationHash")
ARCHIVE_SCHEMA = schema_id("6529STREAM_ARTIST_SANCTION_ARCHIVE_V1")
ARCHIVE_CANON = schema_id("6529STREAM_ARTIST_SANCTION_ARCHIVE_ABI_V1")
SANCTION_ARCHIVE = ("bytes32", "uint16", "uint256", "address", "address", "address", RECORD, "bytes", "bytes")
FACTS = ("bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint64")
TRANSITION = ("uint256", "bytes32", "uint64", "bytes32", "bytes32", "uint8")
COMPONENT = ("bytes32", "address", "bytes4", "bytes32", "bytes32", "bytes32", "bytes32")
MANIFEST = ("string", "bytes32", "bytes32", "bytes32", "bytes32")
REQUEST = (TERMS, Array(COMPONENT, 32), MANIFEST, "string", "string", "string")
PREPARED = (SUBJECT, "bytes", "bytes32", "bytes32")
OP12 = (artist.BINDING, REQUEST, artist.AUTHORIZATION, artist.PROOF, artist.AUTHORITY, RECORD, PREPARED)
FINALITY = ("bytes32", "bytes32", "bytes32", "bytes32", "address", "uint64", "bytes32")
EXECUTION = ("bytes32", "address", "bytes32", "bytes32", "uint64")
ARCHIVE_WITNESS = (("bytes32", "bytes32", "bytes32"), "bytes32")
OP13 = (artist.BINDING, TRANSITION, RECORD, "address", "bytes32", FINALITY, Array(COMPONENT, 32), EXECUTION, ARCHIVE_WITNESS, "bytes32", "bytes32")
DECLARATION = ("bytes32", "bytes32", "address", "uint64")
CORRECTION = ("uint256", "address", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint64", "uint64", "bool", "bytes32")
PLATFORM = (DECLARATION, "uint8", "bytes32", "bytes32", "uint256", "bytes32", CORRECTION)
AUTHORITY = ("address", "uint8", "uint8", "bytes32")
COMPOSITE = ("uint8", "uint64", "bytes32", "uint8", "bytes32")
STATE_EVENT = schema_id("ArtistAttributionStateChanged(uint16,uint256,uint8,uint64,uint8,address,uint8,bytes32,bytes32,string)")
STATE_DATA = ("uint16", "uint64", "uint8", "address", "uint8", "bytes32", "bytes32", "string")
SANCTION_EVENT = schema_id("ArtistSanctionRecorded(uint16,uint256,bytes32,address,uint8,uint256,bytes32,bytes32,uint8,bytes32,uint256,uint64)")
SANCTION_DATA = ("uint16", "uint8", "uint256", "bytes32", "bytes32", "uint8", "bytes32", "uint256", "uint64")
PLATFORM_EVENT = schema_id("PlatformWorksDeclared(uint16,uint256,bytes32,bytes32,address,uint64)")
PLATFORM_DATA = ("uint16", "bytes32", "bytes32", "address", "uint64")
STATE_NAMES = ("NONE", "CLAIMED", "ARTIST_ACCEPTED", "ARTIST_SANCTIONED", "DISPUTED", "REVOKED")
CLAIMS = {"currentNativeAttributionChecked": True, "originalConfirmationSeparatedFromLatestSanction": True,
    "generationSpecificObservedTransitionsChecked": True, "nativeSanctionArchiveHashesReconstructed": True,
    "platformDeclarationSeparatedFromStateZero": True, "providerLogCompletenessTrusted": True,
    "canonicalMappingTrusted": True, "historicalImportCompletenessProven": False, "originalSignaturesReauthorized": False,
    "historicalFinalityExecutionRevalidated": False, "runtimeAcceptanceProven": False, "institutionalStandingProven": False,
    "personhoodProven": False, "sourceConsensusVerified": False, "actualChainAcceptance": False, "completeAcquisitionPacket": False}
QUALIFICATION = ("Current Core-selected Artist graph with provider-observed target collection attribution and sanction events. "
    "Only a generation's original 2-to-3 transition selects its confirmed sanction; the latest association sanction and "
    "later dispute restoration are separate. State zero is NONE, never an inferred Platform Works declaration. Original "
    "sanction record, typed archive, ceremony, signatures and supported operation12/13 evidence are reconstructed without "
    "current signature reauthorization. Imported or hydrated state without a local transition baseline remains explicitly "
    "incomplete. Principal operation12 and native operation13 layouts are supported; other original operation layouts "
    "fail closed. No historical finality execution, institution, personhood, consensus, runtime acceptance or complete "
    "packet is proved. Current satellite ACTIVE admission and an 8192-byte historical transition URI limit are this reader's "
    "strict source availability policies, not native transition URI limits. Longer historical URIs fail capture.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "sourceReviewCommit": SOURCE_REVISION,
    "historyProfileHash": HISTORY_PROFILE_HASH, "bounds": {"anchorBytes": str(MAX_ANCHOR), "abiBytes": str(MAX_ABI),
        "snapshotBytes": str(MAX_OUTPUT), "targetEvents": str(MAX_EVENTS), "archiveCandidates": str(MAX_ARCHIVES), "transitionUriBytes": str(MAX_TRANSITION_URI)},
    "anchor": "Common collection state plus profile, host, artistRegistry, codePins and exact source-specific runtimeAdmission.",
    "rules": ["Reciprocal current Core/Metadata/facade/Coordinator/Binding/Identity/Attribution/Sanction/Archive bindings and immutable code pins.",
        "Fixed owner4 StateChanged/PlatformDeclared and owner6 SanctionRecorded filters cover the whole numeric source range. Archive candidates come only from retained full successful event receipts.",
        "Observed old/new state and binding generation transitions are ordered; current getter agrees with the observed tail. Missing imported baselines are disclosed, not rewritten as no state.",
        "Every original sanction uses exact record and EIP712 hash domains, actual accepted generation binding, complete canonical ceremony/subject and immutable archive/facts/carrier.",
        "Every generation's local original confirmation requires its operation13 archive, the last matching association sanction published before that transition, ordered components, native replay key and finality evidence. Later restoration or sanctions never replace it.",
        "The exact latest association getter is compared with observed scoped publications. Sanctions have no native import path: every nonzero latest sanction requires its original local publication.",
        "Every saved Platform Works declaration requires its unique local original declaration event. Historical transition URIs over the explicit reader byte bound are unsupported.",
        "All repeated RPC reads, final source hash/number mappings and exact replay consumption must agree."], "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def hash_abi(kinds, values): return keccak256(encode(kinds, values))
def zero(kind): return personhood.zero(kind)
def topic(kind, value): return "0x" + encode((kind,), (value,)).hex()


def record_hash(a, registry, r):
    return hash_abi(("bytes32", "uint256", "address", "bytes32", "address", "uint8", *TERMS, "uint256", "uint64"),
        (schema_id("6529STREAM_ARTIST_SANCTION_RECORD_V1"), uint(a["chainId"]), registry, r[1], r[2], r[3], *r[4], r[5], r[6]))


def authorization(a, registry, r):
    body = encode(("bytes32", "address", *TERMS, "uint256", "uint64"),
        ("0x0651c04c186a25456f0dc9ca0a4a29a5537f2aeb0fe7e69cb2d3d202b41549b3", a["core"], *r[4], r[5], r[7]))
    domain = encode(("bytes32", "bytes32", "bytes32", "uint256", "address"),
        (schema_id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            schema_id("6529StreamArtistRegistry"), schema_id("1"), uint(a["chainId"]), registry))
    return body, domain, keccak256(b"\x19\x01" + hex_bytes(keccak256(domain)) + hex_bytes(keccak256(body)))


def ceremony(raw, a, finality, r):
    c = loads(raw, maximum=8192, canonical=True)
    require(type(c) is dict and set(c) == {"contentRoot", "mediaHashes", "referenceRenderHashes", "sanctionSubject", "schema", "signingTool", "statement"}
        and c["schema"] == "6529STREAM_ARTIST_SANCTION_CEREMONY_V1", "sanction ceremony shape")
    require(type(c["signingTool"]) is dict and set(c["signingTool"]) == {"name", "version"}, "sanction ceremony tool shape")
    for text, maximum in ((c["statement"], 2048), (c["signingTool"]["name"], 128), (c["signingTool"]["version"], 128)):
        require(type(text) is str and 0 < len(text.encode("utf8")) <= maximum, "sanction ceremony text bound")
    for key in ("mediaHashes", "referenceRenderHashes"):
        require(type(c[key]) is list and len(c[key]) <= 16 and all(any(hex_bytes(h, 32)) for h in c[key]), "sanction ceremony hash inventory")
    require(any(hex_bytes(c["contentRoot"], 32)) or c["mediaHashes"], "sanction ceremony empty content")
    p = c["sanctionSubject"]
    require(type(p) is dict and set(p) == set(SUBJECT_FIELDS) and type(p["scopeType"]) is int, "sanction subject shape")
    values = tuple(uint(p[k], int(kind[4:])) if kind.startswith("uint") and k != "scopeType" else p[k]
        for k, kind in zip(SUBJECT_FIELDS, SUBJECT))
    require(values[:4] == (schema_id("6529STREAM_ARTIST_SANCTION_SUBJECT_V1"), uint(a["chainId"]), a["core"], finality)
        and values[4:8] == r[4][:4] and hash_abi((SUBJECT,), (values,)) == r[4][4], "sanction subject context/hash differs")
    # Canonical encode additionally validates every fixed-width word.
    require(keccak256(raw) == r[4][5], "sanction ceremony statement hash differs")
    return c, values


class PublicAttributionSource(personhood.PublicPersonhoodSource):
    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc") and (provenance != "trusted_rpc"
            or type(transport) in (PublicRpcTransport, PublicReplayTransport)), "attribution provenance")
        a = loads(anchor_bytes, maximum=MAX_ANCHOR, canonical=True)
        require(type(a) is dict and set(a) == set(COMMON) | {"profile", "host", "artistRegistry", "codePins", "runtimeAdmission"}
            and a["profile"] == PROFILE, "attribution anchor shape/profile")
        require(uint(a["chainId"]) > 0 and uint(a["collectionId"]) > 0 and a["environment"] in ("public_chain", "local_evm_fixture"), "attribution identity")
        uint(a["blockNumber"]); uint(a["timestamp"], 64)
        require(all(any(hex_bytes(a[k], 32)) for k in ("blockHash", "stateRoot", "deploymentEvidenceHash")), "attribution source commitments")
        admission = a["runtimeAdmission"]
        require(type(admission) is dict and set(admission) == {"sourceCommit", "kind", "artifactHash"}
            and admission["sourceCommit"] == SOURCE_REVISION and any(hex_bytes(admission["artifactHash"], 32))
            and admission["kind"] == ("synthetic_fixture" if provenance == "synthetic_fixture" else "externally_admitted_runtime"), "attribution runtime admission")
        require(type(a["codePins"]) is list and 3 <= len(a["codePins"]) <= 128, "attribution code pin bound")
        pins = {}
        for row in a["codePins"]:
            require(type(row) is dict and set(row) == {"address", "runtimeHash"} and any(hex_bytes(row["address"], 20))
                and any(hex_bytes(row["runtimeHash"], 32)) and row["address"] not in pins, "attribution code pin shape")
            pins[row["address"]] = row["runtimeHash"]
        require(len({a[k] for k in ("core", "host", "artistRegistry")}) == 3 and all(a[k] in pins for k in ("core", "host", "artistRegistry")), "attribution required pins")
        self.a, self.pins, self.anchor_bytes, self.provenance = a, pins, anchor_bytes, provenance
        self.reader = PublicRecordingReader(transport, a["blockHash"])
        self._started, self._snapshot, self.suites = False, None, {}
        self._bindings, self._archives = {}, {}

    def snapshot(self):
        if self._snapshot is not None: return self._snapshot
        require(not self._started, "failed attribution capture cannot resume")
        self._started = True
        try: self._snapshot = self._capture()
        except MuseumError: raise
        except (KeyError, TypeError, IndexError, ValueError, OverflowError) as exc:
            raise MuseumError("malformed attribution evidence") from exc
        return self._snapshot

    def transcript(self):
        require(self._snapshot is not None, "attribution snapshot required before transcript")
        return self.reader.transcript()

    def suite(self, registry):
        if registry in self.suites: return self.suites[registry]
        row = super().suite(registry); suite = row["configuration"]
        row["sanction"] = suite[2][6]
        require(len({registry, row["coordinator"], row["archive"], row["binding"], row["identity"], row["attribution"], row["sanction"]}) == 7,
            "attribution graph aliases")
        for index in (0, 2, 4, 6):
            owner = suite[2][index]; self.pin(owner)
            for getter, expected in (("core", self.a["core"]), ("artistRegistry", registry), ("operationCoordinator", row["coordinator"]),
                    ("archiveV2", row["archive"]), ("mintManager", suite[4])):
                require(self.one(owner, getter + "()", "address") == expected, "attribution reciprocal owner graph")
            require(self.one(owner, "domainId()", "bytes32") == artist.DOMAINS[index]
                and self.one(owner, "deploymentChainId()", "uint256") == uint(self.a["chainId"]), "attribution owner domain/chain")
        row["configurationHash"] = self.one(row["coordinator"], "configurationHash()", "bytes32")
        require(row["configurationHash"] != ZERO, "attribution empty configuration")
        return row

    def _binding(self, graph, generation):
        if generation not in self._bindings:
            b = self.one(graph["binding"], "bindingAt(uint256,uint64)", artist.BINDING, ("uint256", "uint64"), (uint(self.a["collectionId"]), generation))
            require(b[4] == generation and b[0] != ZERO and b[3] != ZERO and b[1] != ZERO_ADDRESS and b[2] != ZERO
                and b[8] != ZERO_ADDRESS and b[5] in (1, 2) and b[6] <= 1 and b[7] <= 1, "attribution historical binding differs")
            self._bindings[generation] = b
        return self._bindings[generation]

    def _current(self, graph):
        cid = uint(self.a["collectionId"])
        b = self.one(graph["binding"], "binding(uint256)", artist.BINDING, ("uint256",), (cid,))
        state = self.read(graph["attribution"], "attributionState(uint256)", ("uint8", "uint64"), ("uint256",), (cid,))
        require(state[0] < len(STATE_NAMES), "attribution state enum")
        authority, operative = (ZERO_ADDRESS, 0, 0, ZERO), ZERO
        if b[0] == ZERO: require(b == zero(artist.BINDING) and state == (0, 0), "attribution partial empty binding/state")
        else:
            authority = self.read(graph["identity"], "authorityState(bytes32)", AUTHORITY, ("bytes32",), (b[0],))
            operative = self.one(graph["identity"], "operativeIdentityRecord(bytes32)", "bytes32", ("bytes32",), (b[0],))
            require(b[4] > 0 and authority[3] != ZERO and state[1] == b[4] and self._binding(graph, b[4]) == b
                and authority[0] != ZERO_ADDRESS and authority[1] in (1, 3, 4) and authority[2] in (1, 2, 3, 4) and operative != ZERO
                and state[0] != 0 and (b[9] or state[0] not in (2, 3, 4)) and (state[0] != 1 or not b[9]), "attribution current generation/registration")
        composite = self.read(graph["registry"], "collectionArtistState(uint256)", COMPOSITE, ("uint256",), (cid,))
        require(composite == (*state, b[0], authority[2], b[3]), "attribution composite read differs")
        platform = self.one(graph["attribution"], "platformWorksState(uint256)", PLATFORM, ("uint256",), (cid,))
        declaration = self.read(graph["registry"], "platformWorksDeclaration(uint256)", ("bool", "bytes32", "uint64"), ("uint256",), (cid,))
        require(declaration == (platform[0][0] != ZERO, platform[0][0], platform[0][3]), "attribution platform declaration differs")
        if not declaration[0]: require(platform[0] == zero(DECLARATION), "attribution partial empty declaration")
        return {"binding": json_values(b), "attribution": json_values(state), "stateLabel": STATE_NAMES[state[0]],
            "collectionArtistState": json_values(composite), "authority": json_values(authority),
            "registrationIdentityRecordHash": authority[3], "operativeIdentityRecordHash": operative,
            "platformWorksState": json_values(platform), "platformDeclaration": json_values(declaration)}, b, state, platform

    def _operation_archive(self, event, operation, scope, graph, mask):
        candidates = [log for log in self._receipt_logs if log["address"] == graph["archive"] and log["topics"][0] == artist.ARCHIVED
            and log["transactionHash"] == event["transactionHash"] and _position(log) > _position(event)]
        require(len(candidates) <= MAX_ARCHIVES, "attribution archive candidates bound")
        matches = []
        for log in candidates:
            require(len(log["topics"]) == 4, "attribution archive topics")
            version, = decode(("uint64",), hex_bytes(log["topics"][2]))
            if version != 1: continue
            key = log["topics"][1]
            if key not in self._archives:
                raw = self.one(graph["archive"], "artistEvidenceBytesV2(bytes32,uint64)", "bytes", ("bytes32", "uint64"), (key, 1))
                require(0 < len(raw) <= artist.MAX_ARCHIVE_BYTES, "attribution archive byte bound")
                meta = self.read(graph["archive"], "artistEvidenceMetadataV2(bytes32,uint64)", ("bytes32", "address", "uint32", "uint64"), ("bytes32", "uint64"), (key, 1))
                pointer, size = decode(("address", "uint256"), hex_bytes(log["data"]))
                require(meta == (keccak256(raw), pointer, len(raw), int(log["blockNumber"], 16)) and size == len(raw)
                    and log["topics"][3] == meta[0] and self.code(pointer) == b"\0" + raw, "attribution archive receipt/carrier")
                self._archives[key] = raw, meta
            raw, meta = self._archives[key]
            if len(raw) < 160 or int.from_bytes(raw[64:96], "big") != operation or raw[128:160] != hex_bytes(scope): continue
            outer = decode(artist.ARCHIVE, raw, maximum=artist.MAX_ARCHIVE_BYTES)
            require(outer[:3] == (1, graph["configurationHash"], operation) and outer[3] != ZERO_ADDRESS and key == hash_abi(
                ("bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"),
                (schema_id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), uint(self.a["chainId"]), graph["registry"], graph["coordinator"], operation, outer[3], scope)),
                "attribution operation archive identity")
            for index in range(7):
                before, after = outer[5][index], outer[6][index]
                require((before[0] == after[0] == artist.DOMAINS[index]) if (mask >> index) & 1 else before == after == zero(artist.SNAPSHOT),
                    "attribution operation owner snapshot domain")
            matches.append((outer, {"evidenceId": key, "version": "1", "metadata": json_values(meta), "bytesHex": "0x" + raw.hex(),
                "publication": _location(log), "log": log}))
        require(len(matches) == 1, "attribution exact original operation archive missing/ambiguous")
        return matches[0]

    def _sanction(self, digest, event, graph, history):
        r = self.one(graph["sanction"], "sanctionRecord(bytes32)", RECORD, ("bytes32",), (digest,))
        terms = r[4]
        require(r[0] == digest != ZERO and r[1] != ZERO and r[2] != ZERO_ADDRESS and r[3] in (1, 3, 4)
            and terms[1] == uint(self.a["collectionId"]) and terms[0] <= 4 and terms[4] != ZERO and terms[5] != ZERO
            and ((terms[2] == 0 and terms[3] == ZERO) if terms[0] == 0 else (terms[2] > 0 and terms[3] == ZERO) if terms[0] == 1 else (terms[2] == 0 and terms[3] != ZERO))
            and 0 < r[6] <= uint(self.a["timestamp"]) and r[7] >= r[6] and r[8] > 0 and r[9] != ZERO
            and record_hash(self.a, graph["registry"], r) == digest, "attribution native sanction record")
        binding = self._binding(graph, r[8])
        require(binding[0] == r[1] and binding[3] == r[9] and binding[9], "sanction original binding differs")
        raw = self.one(graph["sanction"], "sanctionArchiveBytes(bytes32)", "bytes", ("bytes32",), (digest,))
        require(0 < len(raw) <= artist.MAX_ARCHIVE_BYTES, "sanction typed archive bound")
        archived = decode(SANCTION_ARCHIVE, raw, maximum=artist.MAX_ARCHIVE_BYTES)
        require(archived[:5] == (ARCHIVE_SCHEMA, 1, uint(self.a["chainId"]), graph["registry"], self.a["core"])
            and archived[5] != ZERO_ADDRESS and archived[6] == r and 0 < len(archived[7]) <= 8192 and 0 < len(archived[8]) <= 4096,
            "sanction immutable archive differs")
        facts = self.one(graph["sanction"], "sanctionArchiveFacts(bytes32)", FACTS, ("bytes32",), (digest,))
        require(facts == (digest, r[1], ARCHIVE_SCHEMA, ARCHIVE_CANON, keccak256(raw), len(raw)), "sanction archive facts differ")
        c, subject = ceremony(archived[7], self.a, archived[5], r)
        body, domain, computed = authorization(self.a, graph["registry"], r)
        require(r[10] == computed, "sanction authorization digest differs")
        result = {"recordHash": digest, "owner": graph["sanction"], "record": json_values(r), "binding": json_values(binding),
            "publication": _location(event), "log": event, "archiveBytesHex": "0x" + raw.hex(),
            "archiveFacts": json_values(facts), "ceremony": c, "ceremonyHex": "0x" + archived[7].hex(), "signatureHex": "0x" + archived[8].hex(),
            "authorization": {"bodyHex": "0x" + body.hex(), "domainHex": "0x" + domain.hex(), "digest": computed},
            "originalOperationArchive": None, "publicationStatus": "local_original_reconstructed"}
        data = decode(SANCTION_DATA, hex_bytes(event["data"]), maximum=MAX_ABI)
        require(event["topics"] == [SANCTION_EVENT, topic("uint256", terms[1]), terms[4], topic("address", r[2])]
            and data == (1, terms[0], terms[2], terms[3], digest, r[3], terms[5], r[5], r[6])
            and r[6] == uint(history["blockTimestamps"][str(int(event["blockNumber"], 16))]), "sanction native event correspondence")
        outer, retained = self._operation_archive(event, 12, digest, graph, 0x47)
        payload = decode(OP12, outer[7], maximum=artist.MAX_ARCHIVE_BYTES)
        b, request, submitted, proof, authority, saved, prepared = payload
        require(b == binding and request[0] == terms and submitted == (r[5], r[7], archived[8]) and proof == (r[2], r[10], False)
            and authority[0:3] == (r[1], r[2], r[3]) and ((authority[2] == 1 and authority[3] in (1, 2))
                or (authority[2] in (3, 4) and authority[3] == 3)) and saved == r and prepared[:2] == (subject, archived[7])
            and prepared[2] != ZERO and prepared[3] != ZERO, "sanction original operation12 payload differs")
        require(request[2][1:] == subject[10:] and keccak256(request[2][0].encode()) == request[2][1]
            and request[3:] == (c["statement"], c["signingTool"]["name"], c["signingTool"]["version"]), "sanction original request/ceremony differs")
        result["originalOperationArchive"] = {**retained, "operation": "12", "payload": json_values(payload)}
        return result

    def _confirmation(self, event, row, graph):
        data = tuple_native(STATE_DATA, event["data"]); r = tuple_native(RECORD, row["record"]); b = self._binding(graph, int(event["generation"]))
        p = (uint(self.a["collectionId"]), r[1], r[8], r[0], data[6], 2)
        require(r[4][:4] == (0, p[0], 0, ZERO) and r[8] == int(event["generation"]) and r[3] in (1, 3)
            and data[4] == r[3] and data[6] != ZERO and data[7] == "" and row["publication"] is not None
            and _position(row["log"]) < _position(event["log"]), "sanction original confirmation differs")
        scope = hash_abi(("bytes32", TRANSITION), (schema_id("6529STREAM_ARTIST_SANCTION_FINALIZATION_TRANSITION_V1"), p))
        outer, retained = self._operation_archive(event["log"], 13, scope, graph, 0x51)
        payload = decode(OP13, outer[7], maximum=artist.MAX_ARCHIVE_BYTES)
        require(outer[3] == data[3] and payload[:3] == (b, p, r) and payload[3] != ZERO_ADDRESS and payload[4] != ZERO
            and payload[5][0] == p[4] and payload[5][4] == payload[3] and 0 < payload[5][5] <= self._event_times[event["publication"]["blockNumber"]]
            and all(payload[5][i] != ZERO for i in (0, 1, 2, 3, 6)) and payload[8][0][0] == r[0]
            and payload[7][0] != ZERO and payload[7][1] != ZERO_ADDRESS and payload[7][3] != ZERO and payload[7][4] > 0
            and all(value != ZERO for value in payload[8][0]) and payload[8][1] != ZERO
            and payload[9] != ZERO and payload[10] != ZERO, "sanction original operation13 payload differs")
        components = payload[6]
        encoded = [encode((COMPONENT,), (item,)) for item in components]
        matching = [item for item in components if item[0] == schema_id("ARTIST_SANCTION")]
        require(1 <= len(components) <= 32 and all(a < b for a, b in zip(encoded, encoded[1:])) and len(matching) == 1
            and matching[0][1] == graph["registry"] and matching[0][2] == schema_id("finalityState(uint256)")[:10]
            and matching[0][3] == self.pins[graph["registry"]] and matching[0][6] == r[0], "sanction confirmation component correspondence")
        replay_key = hash_abi(("bytes32", "uint256", "address", "address", "address", "address", "bytes32", "bytes32", "bytes32"),
            (schema_id("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"), uint(self.a["chainId"]), graph["registry"], graph["coordinator"],
                graph["archive"], graph["sanction"], artist.DOMAINS[6], schema_id("consent_finality.replay.sanction_finalization_transition_key"), scope))
        require(payload[10] == replay_key, "sanction confirmation replay key differs")
        require(hash_abi(("bytes32", Array(COMPONENT, 32)), (schema_id("6529STREAM_FINALITY_COMPONENTS_V1"), payload[6])) == payload[5][3],
            "sanction confirmation component hash differs")
        return {**retained, "operation": "13", "transition": json_values(p), "payload": json_values(payload), "sanctionRecordHash": r[0]}

    def _capture(self):
        graph = self._graph(); g = graph["current"]
        current, binding, state, platform = self._current(g)
        cid = topic("uint256", uint(self.a["collectionId"]))
        filters = [{"address": g["attribution"], "topics": [STATE_EVENT, cid]},
            {"address": g["attribution"], "topics": [PLATFORM_EVENT, cid]}, {"address": g["sanction"], "topics": [SANCTION_EVENT, cid]}]
        history = scan_public_history(self.reader, self.a, filters=filters)
        require(len(history["logs"]) <= MAX_EVENTS, "attribution target event bound")
        self._event_times = {key: uint(value) for key, value in history["blockTimestamps"].items()}
        self._receipt_logs = []
        seen = set()
        for read in self.reader.rows:
            if read["method"] != "eth_getTransactionReceipt": continue
            receipt = read["result"]
            if receipt["transactionHash"] in seen: continue
            seen.add(receipt["transactionHash"]); self._receipt_logs.extend(receipt["logs"])
        transitions, sanction_events, platform_events = [], {}, []
        prior = None; complete = True
        for event in history["logs"]:
            if event["topics"][0] == STATE_EVENT:
                require(len(event["topics"]) == 3, "attribution transition topics")
                new, = decode(("uint8",), hex_bytes(event["topics"][2])); data = decode(STATE_DATA, hex_bytes(event["data"]), maximum=MAX_ABI)
                _, generation, old, actor, authority, record, reason, uri = data
                require(data[0] == 1 and generation > 0 and new < 6 and old < 6 and actor != ZERO_ADDRESS
                    and (old, new) in ((0, 1), (5, 1), (1, 2), (2, 3), (2, 4), (3, 4), (4, 2), (4, 3), (4, 5), (1, 5), (2, 5), (3, 5))
                    and record != ZERO and len(uri.encode()) <= MAX_TRANSITION_URI, "attribution transition fields")
                require(old != 0 or generation == 1, "attribution initial claim generation")
                if prior is None: complete = old == 0 and new == 1 and generation == 1
                else: require(old == prior[0] and generation == prior[1] + (1 if new == 1 else 0), "attribution transition continuity differs")
                b = self._binding(g, generation)
                if new == 1: require(record == b[3] and authority == 0, "attribution claim binding differs")
                prior = new, generation
                transitions.append({"newState": str(new), "oldState": str(old), "generation": str(generation), "actor": actor,
                    "authorityClass": str(authority), "recordHash": record, "reasonHash": reason, "reasonURI": uri,
                    "data": json_values(data), "publication": _location(event), "log": event})
            elif event["topics"][0] == SANCTION_EVENT:
                data = decode(SANCTION_DATA, hex_bytes(event["data"]), maximum=MAX_ABI)
                require(data[4] not in sanction_events, "duplicate sanction publication"); sanction_events[data[4]] = event
            else: platform_events.append(event)
        if transitions: require(prior == state, "attribution current state differs from event tail")
        else: complete = state == (0, 0)
        records = {digest: self._sanction(digest, event, g, history) for digest, event in sanction_events.items()}
        latest = ZERO
        if binding[0] != ZERO:
            latest = self.one(g["sanction"], "sanctionForAssociation(bytes32,uint64,bytes32,uint8,uint256,uint256,bytes32)", "bytes32",
                ("bytes32", "uint64", "bytes32", "uint8", "uint256", "uint256", "bytes32"),
                (binding[0], binding[4], binding[3], 0, uint(self.a["collectionId"]), 0, ZERO))
            local = [row for row in records.values() if row["record"][1] == binding[0] and row["record"][8:10] == [str(binding[4]), binding[3]]
                and row["record"][4][:4] == ["0", self.a["collectionId"], "0", ZERO]]
            if local: require(latest == local[-1]["recordHash"], "sanction latest association differs from event tail")
            require((latest != ZERO and latest in records) if local else latest == ZERO, "sanction latest original publication missing")
        confirmations, generations = [], set()
        for event in transitions:
            if (event["oldState"], event["newState"]) != ("2", "3"): continue
            require(event["generation"] not in generations, "attribution original confirmation ambiguous")
            generations.add(event["generation"])
            require(event["recordHash"] in records, "attribution confirmation sanction original missing")
            saved = records[event["recordHash"]]
            matching = [row for row in records.values() if row["record"][1] == saved["record"][1]
                and row["record"][8:10] == saved["record"][8:10] and row["record"][4][:4] == saved["record"][4][:4]
                and _position(row["log"]) < _position(event["log"])]
            require(matching and matching[-1]["recordHash"] == event["recordHash"], "confirmation was not latest sanction at transition")
            confirmations.append({"transition": event, "archive": self._confirmation(event, saved, g)})
        selected = next((row for row in confirmations if row["transition"]["generation"] == str(state[1])), None)
        original = None if selected is None else selected["transition"]
        confirmation_archive = None if selected is None else selected["archive"]
        if platform[0][0] != ZERO:
            d = platform[0]
            require(d[1] != ZERO and d[2] != ZERO_ADDRESS and d[3] > 0 and hash_abi(
                ("bytes32", "uint256", "address", "address", "uint256", "bytes32", "uint64"),
                (schema_id("6529STREAM_PLATFORM_WORKS_DECLARATION_V1"), uint(self.a["chainId"]), g["registry"], self.a["core"], uint(self.a["collectionId"]), d[1], d[3])) == d[0],
                "attribution platform original hash differs")
            require(len(platform_events) == 1, "platform original declaration missing/ambiguous")
            if platform_events:
                e = platform_events[0]
                require(e["topics"] == [PLATFORM_EVENT, cid] and decode(PLATFORM_DATA, hex_bytes(e["data"])) == (1, *d)
                    and d[3] == uint(history["blockTimestamps"][str(int(e["blockNumber"], 16))]), "platform original event differs")
        else: require(not platform_events, "platform absent getter contradicts event")
        require(self.read(g["attribution"], "attributionState(uint256)", ("uint8", "uint64"), ("uint256",), (uint(self.a["collectionId"]),)) == state,
            "attribution final state changed")
        self.reader.request("eth_getBlockByHash", [self.a["blockHash"], False])
        self.reader.request("eth_getBlockByNumber", [hex(uint(self.a["blockNumber"])), False])
        if type(self.reader.transport) is PublicReplayTransport: self.reader.transport.finish()
        raw = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1", "sourceReviewCommit": SOURCE_REVISION,
            "source": self.a, "sourceState": {k: self.a[k] for k in COMMON}, "provenance": self.provenance,
            "runtimeAdmissionStatus": self.a["runtimeAdmission"]["kind"], "anchorHash": keccak256(self.anchor_bytes),
            "transcriptHash": keccak256(self.reader.transcript()), "graph": graph, "current": current,
            "history": {"transitions": transitions, "completeLocalBaseline": complete,
                "baselineStatus": "local_from_none" if complete else "unavailable_imported_or_hydrated", "originalConfirmation": original,
                "confirmationArchive": confirmation_archive, "confirmations": confirmations, "restorations": [e for e in transitions if e["oldState"] == "4"],
                "platformEvents": platform_events}, "sanctions": {"records": list(records.values()), "latestAssociationHash": latest,
                    "originalConfirmedHash": ZERO if original is None else original["recordHash"]},
            "historyCoverage": history["coverage"], "claims": CLAIMS, "qualification": QUALIFICATION})
        require(len(raw) <= MAX_OUTPUT, "attribution snapshot byte bound")
        return raw


def tuple_native(kind, value):
    if isinstance(kind, Array): return tuple(tuple_native(kind.item, row) for row in value)
    if isinstance(kind, tuple): return tuple(tuple_native(k, v) for k, v in zip(kind, value, strict=True))
    if kind.startswith("uint"): return uint(value, int(kind[4:]))
    if kind == "bytes": return hex_bytes(value)
    return value
