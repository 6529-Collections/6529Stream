"""Original native shared-slot master histories; archive liveness stays separate."""
from jsonschema import Draft202012Validator
from jsonschema.exceptions import ValidationError
from . import artist_attestation_source as artist
from . import public_conservation_source as conservation
from . import public_personhood_source as personhood
from .account_profile import JCS_BYTES
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, record_chain, schema_id, subject_id, uint
from .chain_abi import encode, decode
from .independent_wire import RECORD, RAW_BYTES, ZERO, ZERO_ADDRESS, generic_hash, json_values, require
from .metadata_catalog_source import RECEIPT, POLICY, ARTIST
from .current_rights_source import METADATA_RECORDED
from .owner_catalog_source import _location, _position
from .public_chain_history import scan_public_history, PROFILE_HASH as HISTORY_PROFILE_HASH
from .public_history_rpc import PublicRecordingReader, PublicReplayTransport, PublicRpcTransport
from .conservation_capture_join import _observations

PROFILE = "STREAM_MUSEUM_PUBLIC_MEDIA_MASTER_SOURCE_V1"
SOURCE_REVISION = "905bbe2a3f33f5e7fca436a987d8cba532149e8e"
COMMON = personhood.COMMON
MAX_ANCHOR, MAX_REVISIONS, MAX_OUTPUT = 65536, 64, 32 * 1024 * 1024
ASSOCIATION = conservation.ASSOCIATION
MANIFEST = ("uint8", "string", "bytes32", "string") * 3 + ("string", "bytes32", "string", "bytes32")
RECORD_EVIDENCE = ("bytes32", "bytes32", "address", "uint8", "uint64", "uint64", "bytes32", "bytes32", artist.EVIDENCE, "bytes32")
SELECTION = ("uint8", "bytes32", "bytes32", "uint8", "bytes32", "bytes32", RECORD_EVIDENCE, ASSOCIATION,
    "bytes32", "bytes32", "uint8", "bytes32", "uint64", "bytes32")
OBJECT = ("bytes32",) * 6 + ("uint64",) + ("bytes32",) * 3
COVERAGE = ("bytes32",) * 6 + ("uint64",) + ("bytes32",) * 8
SERVING = ("string",) * 5
EMPTY_SELECTION = conservation._zero(SELECTION)
MASTER_NAME, WAIVER_NAME, NATIVE_PROFILE = "STREAM_MEDIA_MASTER_ASSOCIATION_V1", "STREAM_MASTER_WAIVER_V1", "STREAM_MEDIA_MASTER_SELECTED_SLOTS_PROFILE_V1"
JCS = schema_id("RFC8785_JCS")
TYPES = (schema_id("MEDIA_RELATIONSHIP"), schema_id("ARTIST_STATEMENT"))
MEDIA_FAMILY = schema_id("MEDIA")
SELECTED_EVENT = schema_id("MediaMasterSelected(uint256,bytes32,uint8," + conservation._signature(SELECTION) + ")")
MANIFEST_EVENT = schema_id("CollectionManifestStored(uint16,uint256,uint8,bytes32,address,bytes32)")
MANIFEST_SELECTED_EVENT = schema_id("CollectionManifestSelected(uint16,uint256,uint8,bytes32,address,bytes32)")
OBJECT_EVENT = schema_id("ExternalObjectRecorded(bytes32," + conservation._signature(OBJECT) + ")")
COVERAGE_EVENT = schema_id("ExternalCoverageRecorded(bytes32,bytes32," + conservation._signature(COVERAGE) + ")")
# Exact immutable source documents are embedded below by the bounded source audit.
DEFINITIONS = {'STREAM_MEDIA_MASTER_ASSOCIATION_V1': b'{"$id":"urn:6529stream:schema:STREAM_MEDIA_MASTER_ASSOCIATION_V1","$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"coverageHash":{"pattern":"^0x[0-9a-f]{64}(?![\\\\s\\\\S])","type":"string"},"displayHash":{"pattern":"^0x[0-9a-f]{64}(?![\\\\s\\\\S])","type":"string"},"masterObjectHash":{"pattern":"^0x[0-9a-f]{64}(?![\\\\s\\\\S])","type":"string"},"masterRole":{"enum":["SOURCE_MASTER","PRINT_MASTER"]},"mediaSlot":{"maximum":3,"minimum":1,"type":"integer"},"predecessor":{"oneOf":[{"pattern":"^0x[0-9a-f]{64}(?![\\\\s\\\\S])","type":"string"},{"type":"null"}]},"selectedMediaManifestHash":{"pattern":"^0x[0-9a-f]{64}(?![\\\\s\\\\S])","type":"string"},"subjectId":{"pattern":"^0x[0-9a-f]{64}(?![\\\\s\\\\S])","type":"string"},"version":{"const":1}},"required":["coverageHash","displayHash","masterObjectHash","masterRole","mediaSlot","predecessor","selectedMediaManifestHash","subjectId","version"],"title":"STREAM_MEDIA_MASTER_ASSOCIATION_V1","type":"object","x-stream-document-status":"prospective_unregistered"}', 'STREAM_MASTER_WAIVER_V1': b'{"$id":"urn:6529stream:schema:STREAM_MASTER_WAIVER_V1","$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"artist":{"additionalProperties":false,"properties":{"artistId":{"pattern":"^0x[0-9a-f]{64}(?![\\\\s\\\\S])","type":"string"},"bindingGeneration":{"maxLength":78,"not":{"pattern":"[\\\\r\\\\n]"},"pattern":"^(0|[1-9][0-9]*)$","type":"string"},"bindingHash":{"pattern":"^0x[0-9a-f]{64}(?![\\\\s\\\\S])","type":"string"}},"required":["artistId","bindingGeneration","bindingHash"],"type":"object"},"predecessor":{"oneOf":[{"pattern":"^0x[0-9a-f]{64}(?![\\\\s\\\\S])","type":"string"},{"type":"null"}]},"reason":{"maxLength":16384,"minLength":1,"type":"string"},"scope":{"additionalProperties":false,"properties":{"mediaObjects":{"items":{"additionalProperties":false,"properties":{"masterRoles":{"items":{"enum":["SOURCE_MASTER","PRINT_MASTER"]},"maxItems":2,"minItems":1,"type":"array","uniqueItems":true},"mediaClass":{"enum":["still_image","print_destined","audio","video","interactive_capture"]},"objectId":{"pattern":"^0x[0-9a-f]{64}(?![\\\\s\\\\S])","type":"string"}},"required":["objectId","mediaClass","masterRoles"],"type":"object"},"maxItems":512,"minItems":1,"type":"array"},"subjectId":{"pattern":"^0x[0-9a-f]{64}(?![\\\\s\\\\S])","type":"string"}},"required":["subjectId","mediaObjects"],"type":"object"},"subjectId":{"pattern":"^0x[0-9a-f]{64}(?![\\\\s\\\\S])","type":"string"},"version":{"const":1},"waiverStatement":{"additionalProperties":false,"properties":{"hash":{"additionalProperties":false,"properties":{"algorithm":{"maximum":6,"minimum":1,"type":"integer"},"canonicalizationId":{"pattern":"^0x[0-9a-f]{64}(?![\\\\s\\\\S])","type":"string"},"digest":{"pattern":"^0x(?:[0-9a-f]{2}){1,128}$","type":"string"}},"required":["algorithm","canonicalizationId","digest"],"type":"object"},"uri":{"format":"uri","maxLength":2048,"type":"string"}},"required":["hash","uri"],"type":"object"}},"required":["version","subjectId","artist","scope","waiverStatement","reason","predecessor"],"title":"STREAM_MASTER_WAIVER_V1","type":"object","x-stream-document-status":"prospective_unregistered"}', 'STREAM_MEDIA_MASTER_SELECTED_SLOTS_PROFILE_V1': b'{"canonicalization":"RFC8785_JCS","denominator":"All occupied image, animation and content slots of current selected native kind3 MediaManifest. Nonempty manifestURI/hash, alternatesURI/hash or animationBaseURI are unsupported; zero selected manifest is unavailable. No claim to external/token-specific media closure.","id":"STREAM_MEDIA_MASTER_SELECTED_SLOTS_PROFILE_V1","master":{"authorityClasses":[6,7],"coverage":"Original native external coverage with current passing full-object fixity and independent ENDOWED plus possession families; no platform proof is inferred.","distinctFromDisplay":"master ObjectIdentity.contentHash must differ from selected media slot displayHash","recordType":"MEDIA_RELATIONSHIP","roles":["SOURCE_MASTER","PRINT_MASTER"],"schemaId":"STREAM_MEDIA_MASTER_ASSOCIATION_V1"},"objectIdRecipe":"keccak256(abi.encode(keccak256(\\"6529STREAM_MEDIA_MASTER_SLOT_V1\\"),uint256(chainId),address(core),address(metadata),uint256(collectionId),bytes32(subjectId),bytes32(selectedManifestHash),uint8(slot),bytes32(displayHash)))","platform":"ArtistId zero never admits a waiver; current external archive producer rejects zero, so actual platform master unavailable until a genuine native producer is added.","recordBytesMaximum":8192,"selection":"Per collection subject and slot, retained append-only exact predecessor/revision lineage across original master and waiver records; fresh selected manifest hash required. Permissionless adoption does not grant authorship.","status":"prospective_unregistered","version":1,"waiver":{"authority":"Original consumed op24 publication, authorityClass=1, subjectKind=8, capability=1, current artist binding matches original; no estate or delegate substitution.","recordType":"ARTIST_STATEMENT","schemaId":"STREAM_MASTER_WAIVER_V1","scope":"scope.subjectId equals subjectId. Each mediaObjects.objectId binds a selected slot using objectIdRecipe. Duplicate objectIds or duplicate masterRoles reject. mediaClass is the original artist declaration, never inferred from a MIME label."}}'}
NATIVE_PROFILE_HASH = "0x77133c55381ef35de45e4824c63983ae7ff021a4fb2b8da2a036ec06c0126ff2"
CLAIMS = {"threeSlotDenominatorChecked": True, "completeBoundSelectionHistories": True,
    "originalMasterAndWaiverAuthoritySeparated": True, "savedCoveragePreimagesReconstructed": True,
    "currentArchiveLivenessChecked": False, "historicalArchiveExecutionReplayed": False,
    "historicalManifestSelectionCompletenessProven": False, "providerLogCompletenessTrusted": True,
    "canonicalMappingTrusted": True, "archiveRetrievalProven": False, "institutionalStandingProven": False,
    "originalSignaturesRevalidated": False, "actualChainAcceptance": False, "completeAcquisitionPacket": False}
QUALIFICATION = ("Native collection kind3 image/animation/content denominator and all selected master/waiver revisions on the "
    "externally admitted original selector. Original Metadata classes6/7 master records and class1 consumed Artist op24 waivers "
    "stay distinct. Historical manifest and immutable external ObjectIdentity/Coverage bytes reconstruct saved hash preimages; "
    "current requireCoverage is deliberately not called. A later fixity or family change does not erase the saved record, and "
    "PRESENT is the recorded selection status, not a current archive availability claim. URI bytes do not prove archival delivery. "
    "Candidate folds identify observed selection boundaries; the caller must join the actual historical release manifest, "
    "association and chronology. Current-router kind3 selections include clears, reselections and unsupported prior hosts; "
    "other routers' complete selection histories are not captured. Unsupported historical stored manifests remain raw evidence. "
    "Empty-denominator current association is never invented as historical. No complete "
    "renderer history, historical execution, institutional truth, signature reauthorization, consensus or full packet is proved.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "sourceReviewCommit": SOURCE_REVISION,
    "historyProfileHash": HISTORY_PROFILE_HASH, "nativeProfileHash": NATIVE_PROFILE_HASH,
    "bounds": {"slots": "3", "revisionsPerSlot": str(MAX_REVISIONS), "anchorBytes": str(MAX_ANCHOR), "outputBytes": str(MAX_OUTPUT)},
    "rules": ["Closed externally admitted current Core/Metadata/Router/Artist/selector/coverage graph; original provider target6 is a separate composition join.",
        "Every slot revision and event agrees with its predecessor, original record and native selection hash. Old manifest bytes and coverage commitments remain retained.",
        "Every current-router kind3 selection event is retained, including zero clears and old-hash reselections. Foreign-host selections remain unsupported original observations; only matching current-host manifests are reconstructed.",
        "Supported stored manifests additionally satisfy the pinned Metadata writer's NONE/IPFS/ARWEAVE/HTTPS asset, MIME and content-URI constraints; other typed originals remain unsupported and cannot authorize a candidate fold.",
        "Complete original payload, receipt, index/predecessor chain and publication are verified; waiver retains native op24 statement, consumed authorization and signature bytes.",
        "Immutable ObjectIdentity and Coverage getters agree with original events and hash domains; current liveness is never substituted for historical evidence.",
        "Exact definitions and current policy status are retained without erasing historical selections after lifecycle changes.",
        "All scan stages reconcile complete receipts, repeated RPC facts, headers and matching query hits; completeness remains provider trust."],
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def h(kinds, values): return keccak256(encode(kinds, values))


def native(kind, value):
    if isinstance(kind, tuple): return tuple(native(k, v) for k, v in zip(kind, value, strict=True))
    if kind.startswith("uint"): return uint(value, int(kind[4:]))
    if kind == "bytes": return hex_bytes(value)
    return value


def inventory(manifest):
    require(len(encode((MANIFEST,), (manifest,))) <= 16384 and manifest[12:] == ("", ZERO, "", ZERO), "media unsupported opaque denominator")
    hashes = []
    for index in range(3):
        kind, uri, digest, mime = manifest[index * 4:index * 4 + 4]
        require((uri == "" and digest == ZERO) if kind == 0 else
            (1 <= kind <= 8 and len(uri.encode()) > 0 and digest != ZERO), "media slot source/hash")
        hashes.append(digest)
    return tuple(hashes), h(("bytes32", MANIFEST), (schema_id("6529STREAM_MEDIA_MASTER_INVENTORY_V1"), manifest))


def _stored_manifest_supported(manifest):
    def uri_ok(value):
        raw=value.encode("utf-8")
        return 0<len(raw)<=2048 and all(byte>32 and byte!=127 for byte in raw) and (
            value.startswith("ipfs://") and len(raw)>7 or value.startswith("ar://") and len(raw)>5
            or value.startswith("https://") and len(raw)>8 and raw[8] not in b"/?#")
    for index in range(3):
        kind,uri,digest,mime=manifest[index*4:index*4+4]
        if kind==0:
            if (uri,digest,mime)!=("",ZERO,""):return False
        elif kind not in (5,6,7) or not uri.startswith({5:"ipfs://",6:"ar://",7:"https://"}[kind]) or not uri_ok(uri) or not 0<len(mime.encode("utf-8"))<=128:
            return False
    return all((uri_ok(manifest[index]) if manifest[index] else manifest[index+1]==ZERO) for index in (12,14))


def object_id(a, subject, manifest, slot, display):
    return h(("bytes32", "uint256", "address", "address", "uint256", "bytes32", "bytes32", "uint8", "bytes32"),
        (schema_id("6529STREAM_MEDIA_MASTER_SLOT_V1"), uint(a["chainId"]), a["core"], a["host"], uint(a["collectionId"]), subject, manifest, slot, display))


def selection_hash(a, row):
    return h(("bytes32", "uint256", "address", "address", "address", "address", "address", "bytes32", "uint256", SELECTION),
        (schema_id("6529STREAM_MEDIA_MASTER_SELECTION_V1"), uint(a["chainId"]), a["mediaMaster"], a["core"], a["host"], a["schemas"],
            a["externalCoverage"], NATIVE_PROFILE_HASH, uint(a["collectionId"]), (*row[:-1], ZERO)))


def evidence_hash(a, manifest_hash, inventory_hash, hashes, association, slot_selections, archive_hashes):
    subject = subject_id("collection", a["chainId"], a["core"], a["collectionId"])
    require(len(hashes) == len(slot_selections) == len(archive_hashes) == 3, "media facts slot count")
    result = h(("bytes32", "uint256", "address", "address", "address", "address", "uint256", "bytes32", "bytes32", "bytes32", ("bytes32",)*3, ASSOCIATION),
        (NATIVE_PROFILE_HASH, uint(a["chainId"]), a["mediaMaster"], a["core"], a["host"], a["externalCoverage"], uint(a["collectionId"]),
            subject, manifest_hash, inventory_hash, tuple(hashes), association))
    for index, digest in enumerate(hashes):
        if digest == ZERO: continue
        row = slot_selections[index]
        require(row[0] in (1, 2) and row[1:5] == (subject, manifest_hash, index + 1, digest) and row[7] == association
            and row[13] == selection_hash(a, row) and (archive_hashes[index] != ZERO if row[0] == 1 else archive_hashes[index] == ZERO), "media facts selected correspondence")
        result = h(("bytes32", "uint8", "bytes32", "bytes32"), (result, index + 1, row[13], archive_hashes[index]))
    return result


class PublicMediaMasterSource:
    _read = conservation.PublicConservationSource._read
    _one = conservation.PublicConservationSource._one
    _pointer = conservation.PublicConservationSource._pointer
    _chunk = conservation.PublicConservationSource._chunk
    _suite = conservation.PublicConservationSource._suite
    _known_identity = conservation.PublicConservationSource._known_identity
    _current_association = conservation.PublicConservationSource._current_association
    _document = conservation.PublicConservationSource._document

    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc") and (provenance != "trusted_rpc" or type(transport) in (PublicReplayTransport, PublicRpcTransport)), "media provenance")
        a = loads(anchor_bytes, maximum=MAX_ANCHOR, canonical=True)
        addresses = ("core", "host", "router", "schemas", "store", "artistRegistry", "mediaMaster", "externalCoverage", "executor")
        require(type(a) is dict and set(a) == set(COMMON) | set(addresses) | {"profile", "codePins", "runtimeAdmission"} and a["profile"] == PROFILE, "media anchor shape/profile")
        require(uint(a["chainId"]) > 0 and uint(a["collectionId"]) > 0 and a["environment"] in ("public_chain", "local_evm_fixture"), "media source identity")
        uint(a["blockNumber"]); uint(a["timestamp"], 64)
        for key in ("blockHash", "stateRoot", "deploymentEvidenceHash"): require(any(hex_bytes(a[key], 32)), "media source commitment")
        admission = a["runtimeAdmission"]
        require(type(admission) is dict and set(admission) == {"sourceCommit", "kind", "artifactHash"} and admission["sourceCommit"] == SOURCE_REVISION
            and any(hex_bytes(admission["artifactHash"], 32)) and admission["kind"] == ("synthetic_fixture" if provenance == "synthetic_fixture" else "externally_admitted_runtime"), "media runtime admission")
        require(type(a["codePins"]) is list and 9 <= len(a["codePins"]) <= 256, "media pin bound")
        pins = {}
        for pin in a["codePins"]:
            require(type(pin) is dict and set(pin) == {"address", "runtimeHash"} and any(hex_bytes(pin["address"], 20)) and any(hex_bytes(pin["runtimeHash"], 32)) and pin["address"] not in pins, "media code pin")
            pins[pin["address"]] = pin["runtimeHash"]
        require(len({a[key] for key in addresses}) == len(addresses) and all(a[key] in pins for key in addresses), "media required graph pins")
        self.a, self.pins, self.anchor_bytes, self.provenance = a, pins, anchor_bytes, provenance
        self.reader = PublicRecordingReader(transport, a["blockHash"])
        self._started, self._snapshot, self._reads = False, None, {}
        self.chunks, self.documents, self.records, self.identities, self.manifests, self.coverages = {}, {}, {}, {}, {}, {}

    def _bindings(self):
        a = self.a
        for target, digest in self.pins.items():
            code = hex_bytes(self.reader.code(target))
            require(0 < len(code) <= 24576 and keccak256(code) == digest, "media runtime differs")
        pointers = {key: json_values(self._pointer(role, a[key])) for role,key in (("COLLECTION_METADATA","host"),("METADATA_ROUTER","router"),("ARTIST_REGISTRY","artistRegistry"))}
        for target, getter, expected in ((a["host"],"core",a["core"]),(a["host"],"schemaRegistry",a["schemas"]),(a["host"],"chunkStore",a["store"]),
                (a["host"],"artistRegistry",a["artistRegistry"]),(a["router"],"core",a["core"]),(a["schemas"],"chunkStore",a["store"]),
                (a["externalCoverage"],"core",a["core"]),(a["externalCoverage"],"governanceAuthority",a["executor"]),
                (a["mediaMaster"],"governanceAuthority",a["executor"])):
            require(self._one(target,getter+"()","address") == expected, "media reciprocal binding")
        for key,getter in (("core","core"),("host","metadata"),("schemas","schemaRegistry"),("store","chunkStore"),("externalCoverage","externalCoverage")):
            require(self._one(a["mediaMaster"],getter+"()","address") == a[key], "media selector dependencies")
        require(self._one(a["mediaMaster"],"deploymentChainId()","uint256") == uint(a["chainId"])
            and self._one(a["mediaMaster"],"profileHash()","bytes32") == NATIVE_PROFILE_HASH, "media selector domain/profile")
        require(self._one(a["host"],"artistRegistryCodeHash()","bytes32") == self.pins[a["artistRegistry"]], "media Artist pin")
        return {"pointers":pointers,"artist":self._suite(),"selector":a["mediaMaster"],"externalCoverage":a["externalCoverage"]}

    def _manifest(self, digest, events):
        if digest in self.manifests: return self.manifests[digest]
        topic = "0x" + uint(self.a["collectionId"]).to_bytes(32,"big").hex()
        matching = [e for e in events if e["topics"] == [MANIFEST_EVENT, topic, "0x"+(3).to_bytes(32,"big").hex(), digest]]
        require(len(matching) == 1, "media original manifest publication missing/ambiguous")
        event = matching[0]; version, router, source_hash = decode(("uint16","address","bytes32"),hex_bytes(event["data"]))
        require(version == 1 and router in self.pins, "media historical router pin")
        value = self._one(self.a["host"],"recordedMediaManifest(bytes32)",MANIFEST,("bytes32",),(digest,))
        try: hashes, inv = inventory(value)
        except MuseumError: hashes, inv = None, None
        require(h(("bytes32","uint256","address","address","address","bytes32","uint256","bytes32",MANIFEST),
            (schema_id("6529STREAM_CURRENT_MEDIA_MANIFEST_V1"),uint(self.a["chainId"]),self.a["core"],self.a["host"],router,self.pins[router],uint(self.a["collectionId"]),source_hash,value)) == digest,
            "media historical manifest hash differs")
        writer_shape=_stored_manifest_supported(value)
        shared = writer_shape and hashes is not None and source_hash == h(("string","string"),(value[1],""))
        row = {"manifestHash":digest,"manifest":json_values(value),"hashes":None if hashes is None else list(hashes),"inventoryHash":inv,"sourceHash":source_hash,
            "sharedSlotProfile":shared,"nativeWriterShape":writer_shape,"router":router,"routerCodeHash":self.pins[router],"publication":_location(event),"log":event}
        self.manifests[digest] = row
        return row

    def _definitions(self, waiver):
        name = WAIVER_NAME if waiver else MASTER_NAME
        for n,kind,raw in ((name,0,DEFINITIONS[name]),(NATIVE_PROFILE,2,DEFINITIONS[NATIVE_PROFILE]),("RFC8785_JCS",1,JCS_BYTES)):
            self._document(schema_id(n),kind,RAW_BYTES,expected=raw,first=True)

    def _original(self, digest, waiver, subject):
        if digest in self.records: return self.records[digest]
        self._definitions(waiver); a=self.a; cid=uint(a["collectionId"])
        record,receipt=self._read(a["host"],"collectionRecord(bytes32)",("bytes32",),(digest,),(RECORD,RECEIPT))[1]
        rt,sid,content,uri,schema,scheme,signature,effective=record
        name=WAIVER_NAME if waiver else MASTER_NAME
        policy=self._one(a["host"],"recordPolicy(bytes32)",POLICY,("bytes32",),(rt,))
        require(rt==TYPES[int(waiver)] and sid==subject and schema==schema_id(name) and content[0]==1 and len(content[1])==32 and content[2]==JCS
            and scheme==ZERO and signature==(0,b"",ZERO) and effective>0 and receipt[0]==cid and receipt[1]!=ZERO_ADDRESS
            and receipt[2] in ((1,) if waiver else (6,7)) and 0<receipt[3]<=uint(a["timestamp"]) and receipt[6]==keccak256(DEFINITIONS[name])
            and receipt[7]==keccak256(JCS_BYTES) and ((receipt[8]!=ZERO) if waiver else receipt[8]==ZERO), "media original record/receipt shape")
        require(generic_hash(uint(a["chainId"]),a["host"],a["core"],cid,receipt[1],record)==digest, "media original hash")
        direct_receipt=self._one(a["host"],"collectionRecordReceipt(bytes32)",RECEIPT,("bytes32",),(digest,))
        require(direct_receipt==receipt and self._one(a["host"],"recordHashAt(uint256,bytes32,uint256)","bytes32",("uint256","bytes32","uint256"),(cid,rt,receipt[4]))==digest,"media original index/receipt")
        previous=ZERO
        if receipt[4]:
            prior=self._one(a["host"],"recordHashAt(uint256,bytes32,uint256)","bytes32",("uint256","bytes32","uint256"),(cid,rt,receipt[4]-1))
            prior_receipt=self._one(a["host"],"collectionRecordReceipt(bytes32)",RECEIPT,("bytes32",),(prior,))
            require(prior!=ZERO and prior_receipt[0]==cid and prior_receipt[4]+1==receipt[4],"media original predecessor")
            previous=prior_receipt[5]
        require(record_chain(a["chainId"],a["host"],a["collectionId"],rt,previous,digest,str(receipt[4]))==receipt[5],"media original chain")
        raw=self._chunk("0x"+content[1].hex()); require(0<len(raw)<=8192,"media payload bound")
        value=loads(raw,maximum=8192,canonical=True)
        try: Draft202012Validator(loads(DEFINITIONS[name])).validate(value)
        except ValidationError as exc: raise MuseumError("media payload schema") from exc
        require(value["subjectId"]==subject,"media payload subject")
        saved=None; evidence=conservation._zero(artist.EVIDENCE); evidence_hash_=ZERO
        statement=b""; bundle=b""; attestation=None
        if waiver:
            from tools.metadata.genesis_preservation_profile import validate as validate_waiver
            validate_waiver(WAIVER_NAME,raw)
            require(self._one(a["host"],"consumedArtistAuthorization(bytes32)","bool",("bytes32",),(receipt[8],)),"media waiver unconsumed authorization")
            saved=self._one(self.artist_owners[2],"publicationAttestation(bytes32)",artist.PUBLICATION_RECORD,("bytes32",),(receipt[8],))
            publication,evidence,host_code=saved
            require(publication==(a["host"],receipt[1],cid,sid,rt,schema,JCS,1,keccak256(raw),keccak256(uri.encode()),effective,digest)
                and host_code==self.pins[a["host"]] and evidence[:1]==(receipt[8],) and evidence[1]!=ZERO and evidence[2]!=ZERO and evidence[3]>0
                and evidence[4]==receipt[1] and evidence[5:7]==(1,1) and 0<evidence[7]<=receipt[3] and evidence[8]==h((artist.PUBLICATION,),(publication,)),"media waiver original op24")
            statement=encode(("uint16",artist.PUBLICATION),(1,publication))
            attestation=self._one(self.artist_owners[2],"attestationRecord(bytes32)",artist.ATTESTATION_RECORD,("bytes32",),(receipt[8],))
            require(attestation==(receipt[8],ZERO,artist.PUBLICATION_SCHEMA,keccak256(statement),evidence[3],evidence[7],receipt[1])
                and self._one(self.artist_owners[2],"statementBytes(bytes32)","bytes",("bytes32",),(attestation[3],))==statement,"media waiver full statement")
            bundle=self._one(self.artist_owners[0],"signatureBundle(bytes32)","bytes",("bytes32",),(receipt[8],))
            require(len(bundle)<=4096,"media waiver signature bound")
            evidence_hash_=h((artist.PUBLICATION_RECORD,),(saved,))
        native_evidence=(digest,keccak256(raw),receipt[1],receipt[2],receipt[3],receipt[4],receipt[5],h((RECEIPT,),(receipt,)),evidence,evidence_hash_)
        row={"recordHash":digest,"record":json_values(record),"receipt":json_values(receipt),"payloadHex":"0x"+raw.hex(),"value":value,
            "nativeEvidence":json_values(native_evidence),"policy":json_values(policy),"publication":None,"savedPublication":json_values(saved),
            "attestation":json_values(attestation),"statementHex":"0x"+statement.hex(),"signatureHex":"0x"+bundle.hex()}
        self.records[digest]=row
        return row

    def _scope(self,subject,slot):
        a=self.a; cid=uint(a["collectionId"])
        head=self._one(a["mediaMaster"],"currentMaster(uint256,bytes32,uint8)",SELECTION,("uint256","bytes32","uint8"),(cid,subject,slot))
        if head[0]==0:
            require(head==EMPTY_SELECTION,"media partial empty selection")
            return {"status":"ABSENT","head":json_values(head),"history":[],"events":[]}
        require(0<head[12]<=MAX_REVISIONS,"media selection revision bound")
        previous=EMPTY_SELECTION; rows=[]
        for revision in range(1,head[12]+1):
            row=self._one(a["mediaMaster"],"masterSelectionAt(uint256,bytes32,uint8,uint64)",SELECTION,("uint256","bytes32","uint8","uint64"),(cid,subject,slot,revision))
            require(row[0] in (1,2) and row[1]==subject and row[3]==slot and row[10] in (0,1) and row[12]==revision and row[11]==previous[6][0]
                and row[6][0]!=previous[6][0] and row[6][4]>=previous[6][4] and (row[0]!=previous[0] or row[6][5]>previous[6][5])
                and row[5]==object_id(a,subject,row[2],slot,row[4]) and row[13]==selection_hash(a,row),"media selected lineage/hash")
            original=self._original(row[6][0],row[0]==2,subject)
            require(original["nativeEvidence"]==json_values(row[6]) and row[7][0]!=ZERO and row[7][1]!=ZERO and row[7][2]>0 and row[7][3]!=ZERO,"media selected original/association")
            value=original["value"]
            require(value["predecessor"]==(None if row[11]==ZERO else row[11]),"media payload predecessor")
            if row[0]==1:
                require(value=={"coverageHash":row[9],"displayHash":row[4],"masterObjectHash":row[8],"masterRole":("SOURCE_MASTER","PRINT_MASTER")[row[10]],
                    "mediaSlot":slot,"predecessor":None if row[11]==ZERO else row[11],"selectedMediaManifestHash":row[2],"subjectId":subject,"version":1},"media master payload correspondence")
            else:
                matches=[obj for obj in value["scope"]["mediaObjects"] if obj["objectId"]==row[5]]
                require(row[8:10]==(ZERO,ZERO) and value["artist"]=={"artistId":row[7][0],"bindingHash":row[7][1],"bindingGeneration":str(row[7][2])}
                    and value["scope"]["subjectId"]==subject and len({obj["objectId"] for obj in value["scope"]["mediaObjects"]})==len(value["scope"]["mediaObjects"])
                    and len(matches)==1 and matches[0]["masterRoles"][0]==("SOURCE_MASTER","PRINT_MASTER")[row[10]]
                    and row[6][8][1:4]==row[7][:3],"media waiver selected scope/association")
            rows.append(json_values(row)); previous=row
        require(previous==head,"media selected head/history")
        return {"status":("ABSENT","PRESENT","WAIVED")[head[0]],"head":json_values(head),"history":rows,"events":[]}

    def _coverage(self, selection, events):
        digest=selection[9]
        if digest in self.coverages:
            row=self.coverages[digest]; require(row["objectHash"]==selection[8] and row["object"][0]==selection[7][0] and row["object"][3]!=selection[4],"media repeated coverage identity")
            return row
        a=self.a; host=a["externalCoverage"]
        o=self._one(host,"objectIdentity(bytes32)",OBJECT,("bytes32",),(selection[8],))
        c=self._one(host,"coverage(bytes32)",COVERAGE,("bytes32",),(digest,))
        require(all(value!=ZERO for i,value in enumerate(o) if i!=6) and o[6]>0 and o[0]==selection[7][0] and o[3]!=selection[4]
            and h(("bytes32","uint256","address","address",OBJECT),(schema_id("6529STREAM_EXTERNAL_OBJECT_V1"),uint(a["chainId"]),host,a["core"],o))==selection[8],"media master object identity/hash")
        require(c[0]==digest and c[1]==selection[8] and c[2:7]==(o[0],o[3],o[4],o[5],o[6]) and all(value!=ZERO for i,value in enumerate(c) if i!=6)
            and c[14]==schema_id("STREAM_EXTERNAL_ARTIFACT_COVERAGE_V1") and c[7]!=c[8] and c[9]!=c[10]
            and h(("bytes32","uint256","address",COVERAGE),(schema_id("6529STREAM_EXTERNAL_COVERAGE_V1"),uint(a["chainId"]),host,(ZERO,*c[1:])))==digest,"media saved coverage hash/correspondence")
        original=[]
        for kinds,values,topics in (((OBJECT,),(o,),[OBJECT_EVENT,selection[8]]),((COVERAGE,),(c,),[COVERAGE_EVENT,digest,selection[8]])):
            matching=[e for e in events if e["address"]==host and e["topics"]==topics]
            require(len(matching)==1 and decode(kinds,hex_bytes(matching[0]["data"]))==values,"media original object/coverage event")
            original.append(matching[0])
        require(_position(original[0])<_position(original[1]),"media object/coverage chronology")
        row={"coverageHash":digest,"objectHash":selection[8],"object":json_values(o),"coverage":json_values(c),"archiveHash":h((OBJECT,COVERAGE),(o,c)),
            "objectPublication":_location(original[0]),"publication":_location(original[1]),"logs":original,"currentLiveness":"not_checked"}
        self.coverages[digest]=row
        return row

    def _capture(self):
        a=self.a; cid=uint(a["collectionId"]); topic="0x"+cid.to_bytes(32,"big").hex()
        binding=self._bindings(); association=self._current_association()
        subject=subject_id("collection",a["chainId"],a["core"],a["collectionId"])
        scopes={str(slot):self._scope(subject,slot) for slot in (1,2,3)}
        filters=[{"address":a["mediaMaster"],"topics":[SELECTED_EVENT,topic]},
            {"address":a["host"],"topics":[MANIFEST_EVENT,topic,"0x"+(3).to_bytes(32,"big").hex()]},
            {"address":a["router"],"topics":[MANIFEST_SELECTED_EVENT,topic,"0x"+(3).to_bytes(32,"big").hex()]},
            {"address":a["host"],"topics":[METADATA_RECORDED,topic,list(TYPES)]}]
        primary=scan_public_history(self.reader,a,filters=filters)
        require(len(primary["logs"])<=1024,"media primary event bound")
        for event in primary["logs"]:
            if event["address"]==a["host"] and event["topics"][0]==MANIFEST_EVENT:
                require(len(event["topics"])==4,"media manifest publication topics")
                self._manifest(event["topics"][3],primary["logs"])
        manifest_selections=[]
        for event in primary["logs"]:
            if event["address"]!=a["router"] or event["topics"][0]!=MANIFEST_SELECTED_EVENT:continue
            require(len(event["topics"])==4,"media router selection topics")
            version,host,code=decode(("uint16","address","bytes32"),hex_bytes(event["data"]))
            digest=event["topics"][3]
            require(version==1 and ((host,code)==(ZERO_ADDRESS,ZERO) if digest==ZERO else
                (host!=ZERO_ADDRESS and code!=ZERO)),"media router selection identity")
            supported=digest!=ZERO and host==a["host"] and code==self.pins[a["host"]]
            if supported:
                require(digest in self.manifests,"media selected original manifest missing")
                require(self.manifests[digest]["router"]==a["router"] and _position(self.manifests[digest]["log"])<_position(event),"media manifest selected before original")
            require(not manifest_selections or (digest,host,code)!=(manifest_selections[-1]["manifestHash"],manifest_selections[-1]["host"],manifest_selections[-1]["codeHash"]),"media duplicate router selection")
            manifest_selections.append({"manifestHash":digest,"host":host,"codeHash":code,"supportedHost":supported,"publication":_location(event),"log":event})
        current_hash=self._one(a["host"],"mediaManifestHash(uint256)","bytes32",("uint256",),(cid,))
        require(current_hash!=ZERO,"media selected manifest unavailable")
        current_manifest=self._manifest(current_hash,primary["logs"])
        current_value=self._one(a["host"],"mediaManifest(uint256)",MANIFEST,("uint256",),(cid,))
        require(json_values(current_value)==current_manifest["manifest"] and current_manifest["router"]==a["router"],"media current manifest differs")
        selected=self._one(a["router"],"selectedCollectionManifest(uint256,uint8)",("address","bytes32","bytes32"),("uint256","uint8"),(cid,3))
        require(manifest_selections and selected==(manifest_selections[-1]["host"],manifest_selections[-1]["codeHash"],manifest_selections[-1]["manifestHash"]),"media current selection/event tail")
        serving=self._one(a["router"],"collectionServingSource(uint256)",SERVING,("uint256",),(cid,))
        require(selected==(a["host"],self.pins[a["host"]],current_hash) and serving[3]=="" and serving[2]==current_value[1] and current_manifest["sharedSlotProfile"],"media current router denominator")
        mask=sum(1<<index for index,digest in enumerate(current_manifest["hashes"]) if digest!=ZERO)
        context=self._read(a["mediaMaster"],"collectionMediaContext(uint256)",("uint256",),(cid,),("bytes32","bytes32","bytes32","uint8"))[1]
        require(context==(subject,current_hash,current_manifest["inventoryHash"],mask),"media authenticated denominator differs")
        positions={}; publications={}
        for event in primary["logs"]:
            if event["topics"][0]==METADATA_RECORDED:
                record,digest,chain,recorder,authority,version=decode((RECORD,"bytes32","bytes32","address","bytes32","uint16"),hex_bytes(event["data"]),maximum=32768)
                if digest not in self.records: continue
                original=self.records[digest]; receipt=original["receipt"]
                require(digest not in publications and json_values(record)==original["record"] and chain==receipt[5] and recorder==receipt[1]
                    and authority=="0x"+uint(receipt[2]).to_bytes(32,"big").hex() and version==1 and event["topics"]==[METADATA_RECORDED,topic,record[0],subject]
                    and receipt[3]==primary["blockTimestamps"][str(int(event["blockNumber"],16))],"media original publication differs")
                original["publication"]={"recordedBlock":str(int(event["blockNumber"],16)),"log":event}; publications[digest]=event
            elif event["topics"][0]==SELECTED_EVENT:
                require(len(event["topics"])==4 and event["topics"][2]==subject,"media selected event scope")
                slot=int(event["topics"][3],16); require(slot in (1,2,3),"media selected event slot")
                row,=decode((SELECTION,),hex_bytes(event["data"])); scope=scopes[str(slot)]; index=len(scope["events"])
                require(index<len(scope["history"]) and json_values(row)==scope["history"][index],"media selected event/history")
                scope["events"].append(event); positions[row[13]]=event
        require(all(row["publication"] for row in self.records.values()) and all(len(scope["events"])==len(scope["history"]) for scope in scopes.values()),"media missing original/selected event")
        objects=sorted({row[8] for scope in scopes.values() for item in scope["history"] if (row:=native(SELECTION,item))[0]==1})
        coverage_keys=sorted({row[9] for scope in scopes.values() for item in scope["history"] if (row:=native(SELECTION,item))[0]==1})
        extra_filters=[]
        for signature,keys in ((OBJECT_EVENT,objects),(COVERAGE_EVENT,coverage_keys)):
            for start in range(0,len(keys),64): extra_filters.append({"address":a["externalCoverage"],"topics":[signature,keys[start:start+64]]})
        secondary=scan_public_history(self.reader,a,filters=extra_filters) if extra_filters else None
        candidates=[]; latest=[EMPTY_SELECTION]*3
        ordered=sorted((native(SELECTION,row) for scope in scopes.values() for row in scope["history"]),key=lambda row:_position(positions[row[13]]))
        for row in ordered:
            event=positions[row[13]]; manifest=self._manifest(row[2],primary["logs"])
            require(manifest["sharedSlotProfile"] and manifest["hashes"][row[3]-1]==row[4] and _position(manifest["log"])<_position(event)
                and _position(publications[row[6][0]])<_position(event),"media selection original chronology/manifest")
            if manifest["router"]==a["router"]:
                prior=[item for item in manifest_selections if _position(item["log"])<_position(event)]
                require(prior and prior[-1]["supportedHost"] and prior[-1]["manifestHash"]==row[2],"media master selected against inactive manifest")
            if row[0]==1:
                coverage=self._coverage(row,secondary["logs"])
                require(_position(coverage["logs"][1])<_position(event),"media coverage after selection")
            latest[row[3]-1]=row
            archives=[ZERO if item[0]!=1 else self.coverages[item[9]]["archiveHash"] for item in latest]
            try: facts=evidence_hash(a,row[2],manifest["inventoryHash"],manifest["hashes"],row[7],latest,archives)
            except MuseumError: continue
            candidates.append({"subjectId":subject,"manifestHash":row[2],"inventoryHash":manifest["inventoryHash"],"hashes":manifest["hashes"],"association":json_values(row[7]),
                "slotSelections":json_values(tuple(latest)),"archiveHashes":archives,"factsHash":facts,"publication":_location(event),"log":event,"scope":"selection_event_boundary"})
        heads=[native(SELECTION,scopes[str(slot)]["head"]) for slot in (1,2,3)]
        archives=[ZERO if row[0]!=1 else self.coverages[row[9]]["archiveHash"] for row in heads]
        for slot,row in enumerate(heads,1):
            reasons=[]
            if current_manifest["hashes"][slot-1]==ZERO: reasons.append("unoccupied_current_slot")
            if row[0]==0: reasons.append("no_selected_head")
            elif row[2]!=current_hash or row[4]!=current_manifest["hashes"][slot-1]: reasons.append("historical_manifest")
            if row[0] and row[7]!=self.current_association: reasons.append("historical_association")
            if not self.association_eligible: reasons.append("association_not_currently_eligible")
            if row[0]==1: reasons.append("current_archive_liveness_not_checked")
            if row[0]:
                original=self.records[row[6][0]]; policy=original["policy"]
                if policy[0]!=(ARTIST if row[0]==2 else MEDIA_FAMILY) or not policy[2] or not (uint(policy[1]) & (1<<uint(original["receipt"][2]))): reasons.append("current_record_policy_unavailable")
                if any(doc["facts"][2]!="0" for doc in self.documents.values()): reasons.append("definition_not_active")
            scopes[str(slot)]["currentEligibility"]={"eligible":not reasons,"reasons":reasons}
        current_facts=None
        try: current_facts=evidence_hash(a,current_hash,current_manifest["inventoryHash"],current_manifest["hashes"],self.current_association,heads,archives)
        except MuseumError: pass
        if mask==0:
            candidates.append({"subjectId":subject,"manifestHash":current_hash,"inventoryHash":current_manifest["inventoryHash"],"hashes":current_manifest["hashes"],"association":json_values(self.current_association),
                "slotSelections":json_values(tuple(heads)),"archiveHashes":archives,"factsHash":current_facts,"publication":None,"scope":"source_block_only"})
        self.reader.request("eth_getBlockByHash",[a["blockHash"],False]); self.reader.request("eth_getBlockByNumber",[hex(uint(a["blockNumber"])),False])
        _observations(a,{"media":self.reader.rows},self.pins)
        if type(self.reader.transport) is PublicReplayTransport: self.reader.transport.finish()
        result={"profile":PROFILE,"profileHash":PROFILE_HASH,"version":"1","sourceReviewCommit":SOURCE_REVISION,"mode":"public_media_master_source",
            "source":a,"sourceState":{key:a[key] for key in COMMON},"anchorHash":keccak256(self.anchor_bytes),"transcriptHash":keccak256(self.reader.transcript()),
            "binding":binding,"currentAssociation":association,"mediaContext":{**current_manifest,"subjectId":subject,"occupiedMask":str(mask),"routerServingSource":json_values(serving),
                "currentFactsPreimageHash":current_facts,"currentArchiveLiveness":"not_checked"},"slots":scopes,"manifests":list(self.manifests.values()),
            "records":list(self.records.values()),"coverage":list(self.coverages.values()),"documents":list(self.documents.values()),"historicalCandidates":candidates,
            "manifestSelections":manifest_selections,
            "historyCoverage":{"primary":primary["coverage"],"coverage":None if secondary is None else secondary["coverage"]},"claims":CLAIMS,"qualification":QUALIFICATION}
        raw=dumps(result); require(len(raw)<=MAX_OUTPUT,"media snapshot byte bound"); return raw

    def snapshot(self):
        if self._snapshot is not None: return self._snapshot
        require(not self._started,"failed media capture cannot resume"); self._started=True
        try: self._snapshot=self._capture()
        except MuseumError: raise
        except (KeyError,TypeError,ValueError,IndexError,OverflowError) as exc: raise MuseumError("malformed media evidence") from exc
        return self._snapshot

    def transcript(self):
        require(self._snapshot is not None,"media snapshot required"); return self.reader.transcript()
