"""Original prospective simulation publications, independently of current liveness."""
import base64
import hashlib
import json
import re

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_abi import Array, calldata, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require
from .owner_catalog_source import _location, _position
from .public_chain_history import scan_public_history, PROFILE_HASH as HISTORY_PROFILE_HASH
from .public_history_rpc import PublicRecordingReader, PublicReplayTransport, PublicRpcTransport
from .public_conservation_provider_source import COMMON, GAS_INFO, REGISTERED_EVENT, REGISTERED_DATA

SOURCE_REVISION = "905bbe2a3f33f5e7fca436a987d8cba532149e8e"
PROFILE = "STREAM_MUSEUM_PUBLIC_PROSPECTIVE_REFERENCE_SOURCE_V1"
MAX_ANCHOR, MAX_ABI, MAX_PAYLOAD, MAX_OUTPUT = 65536, 1048576, 524288, 33554432
MAX_RECORDS, MAX_GAS_EVENTS, MAX_TOTAL_PAYLOAD = 64, 256, 8388608
# Literal native definition bytes at SOURCE_REVISION; never generated or fetched at runtime.
NATIVE_SCHEMA_BYTES = b'{"encoding":"Solidity ABI 0.8.19 canonical re-encoding","enums":{"PayloadSourceType":["NONE","INLINE_CHUNKS","SSTORE2","ETHFS","DEPENDENCY_REGISTRY","IPFS","ARWEAVE","HTTPS","WEB3_CALL"]},"execution":{"components":[{"name":"profile","type":"bytes32"},{"name":"sourceHash","type":"bytes32"},{"name":"vectorHash","type":"bytes32"},{"name":"environmentManifestHash","type":"bytes32"},{"name":"htmlSha256","type":"bytes32"},{"name":"pngSha256","type":"bytes32[2]"},{"name":"observedAt","type":"uint64"},{"name":"exitCode","type":"uint32"}],"name":"execution","type":"tuple"},"maximumPayloadBytes":524288,"name":"STREAM_PROSPECTIVE_REFERENCE_ABI_V1","payload":[{"name":"domain","type":"bytes32"},{"components":[{"name":"collectionId","type":"uint256"},{"name":"referenceId","type":"bytes32"},{"name":"expectedHead","type":"bytes32"},{"name":"expectedRevision","type":"uint64"},{"name":"expectedSourceHash","type":"bytes32"},{"components":[{"components":[{"name":"name","type":"string"},{"name":"seed","type":"bytes32"},{"name":"input","type":"bytes"}],"name":"vector","type":"tuple"},{"name":"animationHTML","type":"bytes"},{"name":"objectHash","type":"bytes32"},{"name":"coverageHash","type":"bytes32"},{"name":"repeatCaptureSha256","type":"bytes32[2]"},{"name":"capturedAt","type":"uint64"},{"name":"execution","type":"bytes"}],"name":"captures","type":"tuple[]"},{"components":[{"name":"objectHash","type":"bytes32"},{"name":"coverageHash","type":"bytes32"},{"name":"manifestHash","type":"bytes32"},{"name":"manifestBytes","type":"uint32"},{"name":"engineName","type":"string"},{"name":"engineVersion","type":"string"},{"name":"engineExecutableSha256","type":"bytes32"},{"name":"toolchainName","type":"string"},{"name":"toolchainVersion","type":"string"},{"name":"toolchainSha256","type":"bytes32"},{"name":"engineExecutablePath","type":"string"},{"name":"toolchainPath","type":"string"},{"components":[{"name":"path","type":"string"},{"name":"byteSize","type":"uint64"},{"name":"sha256Digest","type":"bytes32"}],"name":"packageFiles","type":"tuple[]"},{"components":[{"name":"path","type":"string"},{"name":"byteSize","type":"uint64"},{"name":"sha256Digest","type":"bytes32"}],"name":"platformPrerequisites","type":"tuple[]"},{"name":"operatingSystem","type":"string"},{"name":"operatingSystemVersion","type":"string"},{"name":"architecture","type":"string"},{"name":"viewportWidth","type":"uint16"},{"name":"viewportHeight","type":"uint16"},{"name":"devicePixelRatio","type":"uint8"},{"name":"colorSpace","type":"string"},{"name":"softwareRasterization","type":"bool"},{"name":"captureProfile","type":"bytes32"},{"name":"licenseNote","type":"string"}],"name":"environment","type":"tuple"},{"name":"manifestURI","type":"string"},{"name":"effectiveAt","type":"uint64"},{"name":"reasonHash","type":"bytes32"}],"name":"publication","type":"tuple"},{"components":[{"name":"floorSourceId","type":"uint64"},{"name":"floorSourceSetHash","type":"bytes32"},{"components":[{"name":"metadata","type":"address"},{"name":"metadataCodeHash","type":"bytes32"},{"name":"provider","type":"address"},{"name":"providerCodeHash","type":"bytes32"},{"name":"configurationHash","type":"bytes32"},{"name":"predecessor","type":"uint64"},{"name":"admittedAt","type":"uint64"},{"name":"actionId","type":"bytes32"}],"name":"provider","type":"tuple"},{"components":[{"name":"scopeSubject","type":"bytes32"},{"name":"membershipHash","type":"bytes32"},{"name":"mediaInventoryHash","type":"bytes32"},{"name":"scriptSourceHash","type":"bytes32"},{"name":"sourceContextHash","type":"bytes32"},{"name":"scriptWork","type":"bool"}],"name":"release","type":"tuple"},{"name":"router","type":"address"},{"name":"routerCodeHash","type":"bytes32"},{"name":"artistId","type":"bytes32"},{"components":[{"name":"registry","type":"address"},{"name":"artistId","type":"bytes32"},{"name":"bindingGeneration","type":"uint64"},{"name":"bindingHash","type":"bytes32"},{"name":"attributionState","type":"uint8"},{"name":"authorityStatus","type":"uint8"},{"name":"currentAuthority","type":"address"}],"name":"artist","type":"tuple"},{"components":[{"name":"presentationProfile","type":"bytes32"},{"name":"configured","type":"bool"},{"name":"mode","type":"bytes32"},{"name":"renderer","type":"address"},{"name":"rendererCodeHash","type":"bytes32"},{"name":"scriptHash","type":"bytes32"},{"name":"scriptBytes","type":"uint32"},{"name":"imageURIHash","type":"bytes32"},{"name":"animationBaseURIHash","type":"bytes32"},{"name":"scriptLocked","type":"bool"},{"name":"mediaLocked","type":"bool"},{"name":"baseURILocked","type":"bool"},{"name":"dependenciesLocked","type":"bool"},{"name":"artistIdentityLocked","type":"bool"},{"name":"displayMetadataLocked","type":"bool"},{"name":"coreFrozen","type":"bool"}],"name":"serving","type":"tuple"},{"components":[{"name":"name","type":"string"},{"name":"description","type":"string"},{"name":"imageURI","type":"string"},{"name":"animationBaseURI","type":"string"},{"name":"script","type":"string"}],"name":"display","type":"tuple"},{"components":[{"name":"renderer","type":"address"},{"name":"rendererCodeHash","type":"bytes32"},{"name":"routerVersion","type":"bytes32"},{"name":"routerManifestHash","type":"bytes32"},{"name":"presentationProfile","type":"bytes32"},{"name":"rendererContext","type":"bytes32"},{"name":"dependencyReadSet","type":"bytes32"},{"name":"rendererClass","type":"bytes32"}],"name":"renderer","type":"tuple"},{"name":"scriptManifestHash","type":"bytes32"},{"components":[{"name":"scriptHash","type":"bytes32"},{"name":"rendererCompatibility","type":"bytes32"},{"name":"sourceType","type":"uint8"},{"name":"libraryURI","type":"string"},{"name":"scriptURI","type":"string"},{"name":"sourcePointer","type":"string"},{"name":"mimeType","type":"string"},{"name":"chunkCount","type":"uint256"},{"name":"executable","type":"bool"}],"name":"scriptManifest","type":"tuple"},{"name":"mediaManifestHash","type":"bytes32"},{"components":[{"name":"imageSourceType","type":"uint8"},{"name":"imageURI","type":"string"},{"name":"imageHash","type":"bytes32"},{"name":"imageMimeType","type":"string"},{"name":"animationSourceType","type":"uint8"},{"name":"animationURI","type":"string"},{"name":"animationHash","type":"bytes32"},{"name":"animationMimeType","type":"string"},{"name":"contentSourceType","type":"uint8"},{"name":"contentURI","type":"string"},{"name":"contentHash","type":"bytes32"},{"name":"contentMimeType","type":"string"},{"name":"manifestURI","type":"string"},{"name":"manifestHash","type":"bytes32"},{"name":"alternatesURI","type":"string"},{"name":"alternatesHash","type":"bytes32"}],"name":"mediaManifest","type":"tuple"},{"name":"script","type":"bytes"}],"name":"source","type":"tuple"},{"components":[{"name":"sourceHash","type":"bytes32"},{"components":[{"name":"coverageHash","type":"bytes32"},{"name":"objectHash","type":"bytes32"},{"name":"artistId","type":"bytes32"},{"name":"contentHash","type":"bytes32"},{"name":"sha256Digest","type":"bytes32"},{"name":"arweaveDataRoot","type":"bytes32"},{"name":"byteSize","type":"uint64"},{"name":"firstFamilyRecordHash","type":"bytes32"},{"name":"secondFamilyRecordHash","type":"bytes32"},{"name":"firstReceiptHash","type":"bytes32"},{"name":"secondReceiptHash","type":"bytes32"},{"name":"firstFixityHash","type":"bytes32"},{"name":"secondFixityHash","type":"bytes32"},{"name":"checkpointHash","type":"bytes32"},{"name":"profileHash","type":"bytes32"}],"name":"environmentCoverage","type":"tuple"},{"components":[{"name":"coverageHash","type":"bytes32"},{"name":"objectHash","type":"bytes32"},{"name":"artistId","type":"bytes32"},{"name":"contentHash","type":"bytes32"},{"name":"sha256Digest","type":"bytes32"},{"name":"arweaveDataRoot","type":"bytes32"},{"name":"byteSize","type":"uint64"},{"name":"firstFamilyRecordHash","type":"bytes32"},{"name":"secondFamilyRecordHash","type":"bytes32"},{"name":"firstReceiptHash","type":"bytes32"},{"name":"secondReceiptHash","type":"bytes32"},{"name":"firstFixityHash","type":"bytes32"},{"name":"secondFixityHash","type":"bytes32"},{"name":"checkpointHash","type":"bytes32"},{"name":"profileHash","type":"bytes32"}],"name":"captureCoverage","type":"tuple[]"}],"name":"evidence","type":"tuple"},{"name":"environmentJSON","type":"bytes"}],"payloadDomain":"6529STREAM_PROSPECTIVE_REFERENCE_PAYLOAD_V1","receipt":{"components":[{"name":"recordHash","type":"bytes32"},{"name":"chainHash","type":"bytes32"},{"name":"collectionId","type":"uint256"},{"name":"referenceId","type":"bytes32"},{"name":"predecessor","type":"bytes32"},{"name":"revision","type":"uint64"},{"name":"subject","type":"bytes32"},{"name":"membershipHash","type":"bytes32"},{"name":"sourceHash","type":"bytes32"},{"name":"payloadHash","type":"bytes32"},{"name":"payloadBytes","type":"uint32"},{"name":"recorder","type":"address"},{"name":"authorizationClass","type":"uint8"},{"name":"grantRevision","type":"uint64"},{"name":"effectiveAt","type":"uint64"},{"name":"recordedAt","type":"uint64"},{"name":"reasonHash","type":"bytes32"},{"name":"schemaHash","type":"bytes32"},{"name":"profileHash","type":"bytes32"},{"name":"canonicalizationHash","type":"bytes32"}],"name":"receipt","type":"tuple"},"version":1}\n'
NATIVE_PROFILE_BYTES = b'{"archive":"Original complete environment ZIP and each PNG have full object identity and current dual-receipt coverage. Exact HTML and raw script plus full media ABI descriptor occur in the complete package-file inventory. Execution is canonical attributed ABI retained separately, avoiding a ZIP self-hash cycle. Current fixity refresh preserves saved original coverage identities.","authority":"Actual current selected Metadata CURATOR collection class3 before global scope0 class8, nonzero grant revision; permissionless uploads/preparation confer no publication authority. Publication rechecks head, complete source and writer late; current reads retain original recorder/grant provenance.","bounds":{"captures":[1,2],"htmlBytes":40960,"inputBytes":4096,"scriptBytes":24576},"canonicalization":"STREAM_ABI_PROSPECTIVE_REFERENCE_V1","claim":"Curator-attributed STATIC still/BYTE_EXACT execution of one or two named simulation vectors; no EVM execution proof or universal seed coverage.","deployment":"Core-bound Floor then reference host then provider then original governed Floor source admission. Reference derives the provider after deployment, never constructor-pins its future runtime.","environment":"Original STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1 complete Windows/AMD64 software/sRGB/DPR1 still package and platform prerequisite inventory; named engine/toolchain bytes. Actual ZIP membership, executable dependency completeness and browser replay are verified offline, never inferred from inventory declarations alone.","history":"Immutable original full Publication and canonical payload; current getter refuses source/runtime/head or archive drift. Permanent Floor may independently preserve an already-successful identical semantic release receipt.","laterRequired":"Actual terminal/finalized token outputs, original serial/identity and required first/last capture coverage remain separate post-mint and finality requirements.","media":"Full semantic shared-media descriptor is bound; display/master bytes and their preservation requirements remain independently enforced by the original master/floor producer. A media URI is not archive proof.","name":"STREAM_PROSPECTIVE_NAMED_SIMULATION_PROFILE_V1","packagePaths":["prospective/script.js","prospective/media.abi","prospective/<vectorName>.html"],"renderer":"Original selected renderer/version/context/read-set and active constructor-fixed STATIC classification are retained as provenance. The fixed prospective encoder is a separate source-pinned executable input convention, not an actual token render or finality adapter.","schema":"STREAM_PROSPECTIVE_REFERENCE_ABI_V1","scope":"COLLECTION pre-sale or newly introduced semantic release, independently of minted count.","simulation":"Fixed encoder STREAM_PROSPECTIVE context with named seed and opaque Base64 input, no tokenId/serial/finalized/Coordinator. Every vector is declared and retained; zero seed is a legitimate simulation value. One or two unique ASCII alphanumeric/underscore/hyphen names up to64bytes; input at most4096bytes.","source":"Actual permanent Core-bound Floor latest source row and exact currentReleaseContext; complete current selected stable/chunked script bytes and full media manifest. Source identity includes provider/runtime/config, selected Core pointers, renderer/catalog and artist. Existing actual-token snapshots and finality are not inferred.","unsupported":"Library bundles, alternate/opaque media denominators, non-native presentation, DYNAMIC works, other capture/acceptance classes and VIEW require separate implemented profiles; none is silently accepted.","version":1}\n'
NATIVE_CANON_BYTES = b'{"domains":{"chain":"6529STREAM_PROSPECTIVE_REFERENCE_CHAIN_V1","evidence":"6529STREAM_PROSPECTIVE_COLLECTION_REFERENCE_EVIDENCE_V1","record":"6529STREAM_PROSPECTIVE_REFERENCE_RECORD_V1","source":"6529STREAM_PROSPECTIVE_SOURCE_V1"},"encoding":"abi.encode(payloadDomain,Publication,Source,Evidence,bytes environmentJSON)","name":"STREAM_ABI_PROSPECTIVE_REFERENCE_V1","rules":"Exact ABI offsets/widths/padding and re-encoding equality; all tuple and array order retained. Publication.expectedSourceHash is normalized to authenticated source for preview. Environment is original complete canonical JSON. Execution is abi.encode(Execution). No receipt recordedAt or record hash enters the payload.","version":1}\n'
# End of pinned native definitions.

SCHEMA = json.loads(NATIVE_SCHEMA_BYTES)
def abi(p):
    kind = p["type"]; base = kind.split("[")[0]
    value = tuple(abi(c) for c in p["components"]) if base == "tuple" else base
    for length in re.findall(r"\[([0-9]*)\]", kind):
        value = (value,) * int(length) if length else Array(value, 2 if p["name"] in ("captures", "captureCoverage") else 1024)
    return value

PAYLOAD = tuple(abi(p) for p in SCHEMA["payload"])
PUBLICATION, SOURCE, EVIDENCE = PAYLOAD[1:4]
RECEIPT, EXECUTION = abi(SCHEMA["receipt"]), abi(SCHEMA["execution"])
CAPTURE, ENVIRONMENT = PUBLICATION[5].item, PUBLICATION[6]
VECTOR, COVERAGE = CAPTURE[0], EVIDENCE[1]
DEP = (("address",) * 6, ("bytes32",) * 6, "uint256", "bytes32", "bytes32", "uint32", "uint256", "uint256", "uint256")
DOCUMENT_FACTS = ("bool", "uint8", "uint8", "bytes32", "bytes32", "bytes32", "uint32", "uint256", "bytes32")
OBJECT = ("bytes32",) * 6 + ("uint64",) + ("bytes32",) * 3
ARCHIVE_RECEIPT = ("bytes32",) * 6 + ("address", "uint64", "uint256", "uint64")
FIXITY = ("bytes32",) * 11 + ("uint64", "uint64", "uint64", "uint8", "bytes32", "bytes32", "bytes32", "address", "uint256", "uint64")
POINTER = ("address", "bytes32", "bool", "bytes32", "bytes4", "address", "uint8", "bytes32", "bytes32", "uint64")
PARAMETER_NAMES = tuple("PROSPECTIVE_REFERENCE_" + n + "_GAS" for n in ("READ", "SOURCE", "ARCHIVE"))
PARAMETER_IDS = tuple(schema_id("6529STREAM_GGP_" + n) for n in PARAMETER_NAMES)
UPDATED_EVENT = schema_id("GasParameterUpdated(uint16,bytes32,address,bytes32,uint256,uint256,uint256)")
UPDATED_DATA = ("uint16", "uint256", "uint256", "uint256")
DOMAIN = {key: schema_id(value) for key, value in {
    "source": "6529STREAM_PROSPECTIVE_SOURCE_V1", "payload": "6529STREAM_PROSPECTIVE_REFERENCE_PAYLOAD_V1",
    "record": "6529STREAM_PROSPECTIVE_REFERENCE_RECORD_V1", "chain": "6529STREAM_PROSPECTIVE_REFERENCE_CHAIN_V1",
    "evidence": "6529STREAM_PROSPECTIVE_COLLECTION_REFERENCE_EVIDENCE_V1",
    "simulation": "6529STREAM_PROSPECTIVE_NAMED_SIMULATION_V1"}.items()}
STABLE = schema_id("6529STREAM_ROUTER_STABLE_PRESENTATION_V1")
CHUNKED = schema_id("6529STREAM_ROUTER_CHUNKED_PRESENTATION_V1")
RAW_BYTES = schema_id("RAW_BYTES")

def signature(kind):
    if isinstance(kind, Array): return signature(kind.item) + "[]"
    return kind if isinstance(kind, str) else "(" + ",".join(signature(x) for x in kind) + ")"

def abi_signature(parameter):
    kind=parameter["type"]
    return "("+",".join(abi_signature(c) for c in parameter["components"])+")"+kind[5:] if kind.startswith("tuple") else kind

PUBLICATION_EVENT = schema_id("ProspectiveReferencePublished(uint16,bytes32,uint256,bytes32," + signature(RECEIPT) + ",string)")
EVENT_DATA = ("uint16", RECEIPT, "string")
PUBLICATION_SIGNATURES = ("core()", "conservationFloor()", "dependencies()", "currentSource(uint256)",
    "simulationHTML(uint256," + signature(VECTOR) + ")",
    "previewProspectiveReference(" + abi_signature(SCHEMA["payload"][1]) + ",address)",
    "publishProspectiveReference(" + abi_signature(SCHEMA["payload"][1]) + ")", "currentProspectiveReference(uint256)",
    "requireProspectiveCollectionReference(uint256,bytes32,bytes32)", "prospectiveRecord(bytes32)",
    "prospectivePayload(bytes32)", "prospectiveCount(uint256)", "prospectiveAt(uint256,uint256)")
_interface = 0
for _sig in PUBLICATION_SIGNATURES: _interface ^= int(schema_id(_sig)[:10], 16)
PUBLICATION_INTERFACE = "0x" + f"{_interface:08x}"

DEFINITIONS = (
    (schema_id("STREAM_PROSPECTIVE_REFERENCE_ABI_V1"), 0, "0x8416f4cb0125f5c2156d0105a7f02bda039c38399cccb2716a38163011a7efe6", 9169, NATIVE_SCHEMA_BYTES),
    (schema_id("STREAM_PROSPECTIVE_NAMED_SIMULATION_PROFILE_V1"), 2, "0x62837f1da89beeeda117c5d509eeadda40a7cfb17441870bfe78295ff14f223c", 3630, NATIVE_PROFILE_BYTES),
    (schema_id("STREAM_ABI_PROSPECTIVE_REFERENCE_V1"), 1, "0xa49312f8b4a2956768955836725736f560e4fc1b0b5a2b5257dc006db19b3668", 708, NATIVE_CANON_BYTES),
    (schema_id("STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1"), 0, "0xe09ea65b22dccf9a9528b0ec4c940a831be48a060f0a095157a65aff5b290b90", 2236, None),
    (schema_id("STREAM_REFERENCE_PNG_OBJECT_V1"), 0, "0x06dacccbad9218d04f77cbfdd597dfa61e2cab5b58c0fb8f5a1344ce301cb489", 286, None),
    (schema_id("STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1"), 0, "0xb3cedd289be34a31fcd20d1941c86e28f31723e4c61f11ddf87894cda4903cac", 351, None),
    (schema_id("STREAM_REFERENCE_NATIVE_FORMATS_V1"), 2, "0x91a426d25d6e00c056cea336611731171bfe84e1b90bf10f7e2e0d0edc6d8c03", 422, None),
    (schema_id("RFC8785_JCS"), 1, "0xbc33af15c6b6374052871a5fdfa255f900f56fa594f650b2d0814c681fdb35a9", 362, None),
    (schema_id("STREAM_RENDERER_CLASS_DECLARATION_V1"),0,"0xce9047a5c3bc8ab8aa1b9a5f1cd77a1902725799750654135be9b6f942811bc1",838,None),
    (schema_id("STREAM_RENDERER_CLASS_DECLARATION_JSON_PROFILE_V1"),2,"0xbec0b224d0e79c1c8d775742321a8f0efb7caaa551ffbd5f758606517a8ad530",1074,None))

def hash_abi(kinds, values): return keccak256(encode(kinds, values))
def topic(kind, value): return "0x" + encode((kind,), (value,)).hex()
def sha(raw): return "0x" + hashlib.sha256(raw).hexdigest()
def safe_uri(value):
    raw=value.encode("utf-8")
    return len(raw)<=2048 and (not raw or (all(b>32 and b!=127 for b in raw) and
        ((raw.startswith(b"https://") and len(raw)>8 and raw[8] not in b"/?#")
        or (raw.startswith(b"ipfs://") and len(raw)>7) or (raw.startswith(b"ar://") and len(raw)>5))))
def renderer_declaration(renderer):
    require(renderer[0]!=ZERO_ADDRESS and all(x!=ZERO for x in renderer[1:]) and renderer[7] in (schema_id("STATIC"),schema_id("DYNAMIC")),
        "prospective renderer declaration fields")
    return dumps({"context":renderer[5],"dependencyReadSet":renderer[6],"presentationProfile":renderer[4],"renderer":renderer[0],
        "rendererClass":"STATIC" if renderer[7]==schema_id("STATIC") else "DYNAMIC","rendererCodeHash":renderer[1],
        "routerManifestHash":renderer[3],"routerVersion":renderer[2],"version":1})
def zero(kind):
    if isinstance(kind, Array): return ()
    if isinstance(kind, tuple): return tuple(zero(k) for k in kind)
    if kind.startswith("uint"): return 0
    return False if kind == "bool" else ZERO_ADDRESS if kind == "address" else b"" if kind == "bytes" else "" if kind == "string" else "0x" + "00" * int(kind[5:])
def named(spec, value): return {p["name"]: v for p, v in zip(spec["components"], value, strict=True)}
def source_hash(a, dep, cid, source):
    return hash_abi(("bytes32", "uint256", "address", DEP, "uint256", SOURCE), (DOMAIN["source"], uint(a["chainId"]), a["host"], dep, cid, source))
def record_hash(a, dep, publication, receipt):
    return hash_abi(("bytes32", "uint256", "address", "address", "address", PUBLICATION, RECEIPT),
        (DOMAIN["record"], uint(a["chainId"]), a["host"], a["core"], dep[0][1], publication, (ZERO, ZERO, *receipt[2:])))
def chain_hash(a, predecessor_chain, receipt):
    return hash_abi(("bytes32", "uint256", "address", "address", "uint256", "bytes32", "uint64", "bytes32"),
        (DOMAIN["chain"], uint(a["chainId"]), a["host"], a["core"], receipt[2], predecessor_chain, receipt[5], receipt[0]))
def evidence_hash(a, dep, receipt):
    return hash_abi(("bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "bytes32", RECEIPT),
        (DOMAIN["evidence"], uint(a["chainId"]), a["host"], a["core"], dep[0][1], receipt[2], receipt[6], receipt[7], receipt))

def vector_hash(vector):
    require(re.fullmatch(r"[A-Za-z0-9_-]{1,64}", vector[0]) is not None and len(vector[2]) <= 4096, "prospective vector unsupported")
    return hash_abi(("bytes32", VECTOR), (DOMAIN["simulation"], vector))
def simulation_html(a, cid, digest, vector, script):
    require(0 < len(script) <= 24576, "prospective script byte bound")
    text = script.decode("utf-8"); vector_digest = vector_hash(vector)
    escaped = re.sub(r"</script", lambda m: "<\\/" + m.group(0)[2:], text, flags=re.IGNORECASE)
    body = ('<!doctype html><html data-stream-render-state="prospective"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1"></head><body><script>'
        'const STREAM_PROSPECTIVE={profile:"' + DOMAIN["simulation"] + '",chainId:"' + a["chainId"]
        + '",core:"' + a["core"] + '",collectionId:"' + str(cid) + '",sourceHash:"' + digest
        + '",vectorHash:"' + vector_digest + '",name:"' + vector[0] + '",seed:"' + vector[1]
        + '",inputBase64:"' + base64.b64encode(vector[2]).decode() + '"};Object.freeze(STREAM_PROSPECTIVE);</script><script>'
        + escaped + '</script></body></html>').encode("utf-8")
    require(len(body) <= 40960, "prospective HTML byte bound")
    return body

def environment_bytes(environment):
    spec = SCHEMA["payload"][1]["components"][6]
    e = named(spec, environment)
    require(e["objectHash"] != ZERO and e["coverageHash"] != ZERO and e["engineExecutableSha256"] != ZERO
        and e["toolchainSha256"] != ZERO and e["packageFiles"] and e["platformPrerequisites"]
        and 0 < e["viewportWidth"] <= 4096 and 0 < e["viewportHeight"] <= 4096
        and e["devicePixelRatio"] == 1 and e["softwareRasterization"] and e["colorSpace"] == "srgb"
        and e["operatingSystem"] == "Windows" and e["architecture"] == "AMD64"
        and e["captureProfile"] == schema_id("STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1"), "prospective unsupported environment")
    def files(rows, relative):
        result = []; previous = None
        for path, size, digest in rows:
            raw = path.encode("utf-8")
            require(0 < len(raw) <= (1024 if relative else 2048) and digest != ZERO
                and (previous is None or previous < raw), "prospective file inventory order/bounds")
            if relative:
                require(all(32 <= c <= 126 and chr(c) not in '\\:<>"|?*' for c in raw)
                    and all(part and not part.endswith((".", " ")) for part in path.split("/")), "prospective relative package path")
            previous = raw; result.append({"path": path, "byteSize": str(size), "sha256Digest": digest})
        return result
    result = {key: e[key] for key in ("architecture", "captureProfile", "colorSpace", "engineExecutablePath",
        "engineExecutableSha256", "engineName", "engineVersion", "licenseNote", "operatingSystem", "operatingSystemVersion",
        "softwareRasterization", "toolchainName", "toolchainPath", "toolchainSha256", "toolchainVersion")}
    for key, bound in (("architecture",64),("colorSpace",64),("engineExecutablePath",1024),("engineName",256),
            ("engineVersion",256),("licenseNote",16384),("operatingSystem",64),("operatingSystemVersion",128),
            ("toolchainName",256),("toolchainPath",1024),("toolchainVersion",256)):
        require(len(e[key].encode()) <= bound, "prospective environment text bound")
    result.update(devicePixelRatio=str(e["devicePixelRatio"]), viewportWidth=str(e["viewportWidth"]), viewportHeight=str(e["viewportHeight"]),
        licenseBasis="undetermined", runtimeObjectHash=e["objectHash"], version=1,
        packageFiles=files(e["packageFiles"], True), platformPrerequisites=files(e["platformPrerequisites"], False))
    for path_key, digest_key in (("engineExecutablePath", "engineExecutableSha256"), ("toolchainPath", "toolchainSha256")):
        found = [row for row in e["packageFiles"] if row[0] == e[path_key]]
        require(len(found) == 1 and found[0][1] > 0 and found[0][2] == e[digest_key], "prospective executable inventory member")
    raw = dumps(result); require(len(raw) <= MAX_PAYLOAD, "prospective environment JSON bound")
    return raw

CLAIMS = {"completeScopedPublicationHistory": True, "originalPayloadPreimagesChecked": True,
    "originalGasAtPublicationReconstructed": True, "originalAndCurrentSourcesSeparated": True,
    "prospectiveReceiptEvidenceHashesChecked": True, "immutableArchiveFactsRetained": True,
    "providerLogCompletenessTrusted": True, "canonicalMappingTrusted": True,
    "historicalCurrentPairReplayed": False, "currentPublicationAuthorityReauthorized": False,
    "browserExecutionProven": False, "zipMembershipVerified": False, "archiveConsensusProven": False,
    "allSeedCoverageProven": False, "postMintReferenceProven": False, "finalityProven": False,
    "institutionalAcceptance": False, "runtimeArtifactAuthenticated": False,
    "nativeRuntimeAcceptance": False, "actualChainAcceptance": False, "completeAcquisitionPacket": False}
QUALIFICATION = ("Original collection-scoped prospective simulation publications and their complete native history at one pinned block. "
    "Canonical payload retains original Source, Coverage and environment declarations; original GGP values are reconstructed at each publication. "
    "Current source observations are separate and can be unevaluated after observed dependency or source changes. "
    "Historical currentReceiptPair liveness inputs were not stored; original immutable archive facts do not reproduce those gates or archive consensus. "
    "Source and native manifest field correspondence does not reexecute the original writer. "
    "Exact HTML, execution declarations and file commitments do not prove browser execution, ZIP membership, universal seed coverage, "
    "post-mint reference, finality, institutional acceptance or runtime authenticity. Native CURATOR class3 or global class8 authority is original receipt provenance, "
    "never reauthorized from current grants. Provider log completeness and canonical mappings remain trusted.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "sourceReviewCommit": SOURCE_REVISION,
    "historyProfileHash": HISTORY_PROFILE_HASH, "nativeDefinitionHashes": [r[2] for r in DEFINITIONS],
    "bounds": {"anchorBytes": str(MAX_ANCHOR), "abiBytes": str(MAX_ABI), "payloadBytes": str(MAX_PAYLOAD),
        "records": str(MAX_RECORDS), "gasEvents": str(MAX_GAS_EVENTS), "aggregatePayloadBytes": str(MAX_TOTAL_PAYLOAD), "snapshotBytes": str(MAX_OUTPUT)},
    "scope": "One explicit prospective host and collection; no arbitrary receipt list. Count/At/head and every matching Published event are joined bijectively.",
    "gas": "All host registrations and updates, exact three names/order, native monotonic revisions, old/new values and immutable floors. Historical dependency gas is selected strictly before each publication. Governance execution is not reexecuted.",
    "current": "Read fixed dependencies and deterministic named Core/Floor/runtime observations first. Incompatible observations yield not_evaluated, never absence. Compatible currentSource is canonically decoded and its exact source hash reconstructed. requireProspectiveCollectionReference is not called.",
    "originals": "Publication and Receipt from prospectiveRecord; canonical payload from prospectivePayload; complete original Source/Evidence/environment, HTML/execution bytes and immutable Coverage/ObjectIdentity/receipt/fixity getters. Current archive liveness is not substituted.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


class PublicProspectiveReferenceSource:
    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc") and (provenance != "trusted_rpc"
            or type(transport) in (PublicRpcTransport, PublicReplayTransport)), "prospective provenance")
        a = loads(anchor_bytes, maximum=MAX_ANCHOR, canonical=True)
        require(type(a) is dict and set(a) == set(COMMON) | {"profile", "host", "codePins", "runtimeAdmission"}
            and a["profile"] == PROFILE and a["environment"] in ("public_chain", "local_evm_fixture"), "prospective anchor shape/profile")
        require(uint(a["chainId"]) > 0 and uint(a["collectionId"]) > 0, "prospective nonzero identity")
        uint(a["blockNumber"]); uint(a["timestamp"], 64)
        require(all(any(hex_bytes(a[k], 32)) for k in ("blockHash", "stateRoot", "deploymentEvidenceHash"))
            and all(any(hex_bytes(a[k], 20)) for k in ("core", "host")) and a["host"] != a["core"], "prospective anchor commitments")
        admission = a["runtimeAdmission"]
        require(type(admission) is dict and set(admission) == {"sourceCommit", "kind", "artifactHash"}
            and admission["sourceCommit"] == SOURCE_REVISION and any(hex_bytes(admission["artifactHash"], 32))
            and admission["kind"] == ("synthetic_fixture" if provenance == "synthetic_fixture" else "externally_admitted_runtime"), "prospective runtime admission")
        require(type(a["codePins"]) is list and 2 <= len(a["codePins"]) <= 128, "prospective pin bound")
        pins = {}
        for row in a["codePins"]:
            require(type(row) is dict and set(row) == {"address", "runtimeHash"} and any(hex_bytes(row["address"], 20))
                and any(hex_bytes(row["runtimeHash"], 32)) and row["address"] not in pins, "prospective invalid/duplicate pin")
            pins[row["address"]] = row["runtimeHash"]
        require(all(a[k] in pins for k in ("core", "host")), "prospective required pins")
        self.a, self.anchor_bytes, self.pins, self.provenance = a, anchor_bytes, pins, provenance
        self.reader = PublicRecordingReader(transport, a["blockHash"])
        self._started, self._snapshot, self._code, self._archive = False, None, {}, {}

    def read(self, target, name, outputs, inputs=(), values=()):
        return decode(outputs, hex_bytes(self.reader.call(target, calldata(name, inputs, values))), maximum=MAX_ABI)
    def one(self, target, name, output, inputs=(), values=()): return self.read(target, name, (output,), inputs, values)[0]
    def code(self, address):
        if address not in self._code:
            raw = hex_bytes(self.reader.code(address)); require(len(raw) <= 24576, "prospective runtime bound")
            if address in self.pins: require(raw and keccak256(raw) == self.pins[address], "prospective runtime pin differs")
            self._code[address] = raw
        return self._code[address]
    def pin(self, address, digest):
        require(address != ZERO_ADDRESS and digest != ZERO and self.code(address) and keccak256(self.code(address)) == digest,
            "prospective original dependency runtime differs")
    def _bindings(self):
        a = self.a; host = a["host"]
        for address in sorted(self.pins): self.code(address)
        for interface, expected in ((PUBLICATION_INTERFACE, True), ("0x01ffc9a7", True), ("0xffffffff", False)):
            require(self.one(host, "supportsInterface(bytes4)", "bool", ("bytes4",), (interface,)) == expected, "prospective interface differs")
        d = self.one(host, "dependencies()", DEP)
        require(d[0][0] == a["core"] and d[1][0] == self.pins[a["core"]] and d[2] == uint(a["chainId"])
            and d[3] != ZERO and d[4] != ZERO and 0 < d[5] <= MAX_PAYLOAD and d[6] >= 50000
            and d[7] >= d[6] and d[8] >= d[6], "prospective dependency configuration")
        for address, digest in zip(d[0], d[1], strict=True): self.pin(address, digest)
        for target, getter, output, expected in ((host,"core()","address",a["core"]),
                (host,"conservationFloor()","address",d[0][1]), (host,"deploymentChainId()","uint256",d[2]),
                (d[0][1],"core()","address",a["core"]), (d[0][1],"coreCodeHash()","bytes32",d[1][0]),
                (d[0][1],"deploymentChainId()","uint256",d[2]), (d[0][2],"chunkStore()","address",d[0][3]),
                (d[0][4],"core()","address",a["core"]), (d[0][5],"PROFILE()","bytes32",DOMAIN["simulation"])):
            require(self.one(target, getter, output) == expected, "prospective reciprocal dependency differs")
        require(self.read(a["core"], "conservationFloor()", ("address", "bytes32")) == (d[0][1], d[1][1])
            and self.one(a["core"], "collectionExists(uint256)", "bool", ("uint256",), (uint(a["collectionId"]),)), "prospective permanent Floor/collection differs")
        executor = self.one(host, "governanceAuthority()", "address")
        require(executor != ZERO_ADDRESS and self.one(d[0][1], "governanceAuthority()", "address") == executor,
            "prospective original governance authority differs")
        self.pin(executor, self.one(d[0][1], "executorCodeHash()", "bytes32"))
        return d, executor

    def _gas(self, dep, executor, history):
        host = self.a["host"]
        require(self.one(host, "gasParameterIds()", Array("bytes32", 3)) == PARAMETER_IDS, "prospective gas inventory")
        events = [e for e in history["logs"] if e["topics"][0] in (REGISTERED_EVENT, UPDATED_EVENT)]
        require(len(events) <= MAX_GAS_EVENTS, "prospective gas history bound")
        registrations = [e for e in events if e["topics"][0] == REGISTERED_EVENT]
        require(len(registrations) == 3, "prospective exact three gas registrations")
        current, rows, changes = {}, [], []
        for i, event in enumerate(registrations):
            value = decode(REGISTERED_DATA, hex_bytes(event["data"]), maximum=MAX_ABI)
            require(event["topics"] == [REGISTERED_EVENT, PARAMETER_IDS[i]] and value[:2] == (2, PARAMETER_NAMES[i])
                and value[2] >= value[3] > 0 and value[4] == 2, "prospective original gas registration")
            if i: require(_position(event) == (*_position(registrations[i-1])[:2], _position(registrations[i-1])[2]+1), "prospective registration chronology")
            current[PARAMETER_IDS[i]] = (value[2], value[3], value[4], 1)
            rows.append({"parameterId": PARAMETER_IDS[i], "name": value[1], "genesisValue": str(value[2]), "floor": str(value[3]),
                "failureClass": str(value[4]), "log": event, "publication": _location(event)})
        actions = set()
        for event in events:
            if event["topics"][0] == REGISTERED_EVENT: continue
            require(len(event["topics"]) == 4 and event["topics"][1] in current and event["topics"][2] == topic("address",host)
                and event["topics"][3] != ZERO and _position(event) > _position(registrations[-1]), "prospective gas update identity")
            parameter, action = event["topics"][1], event["topics"][3]
            require((parameter,action) not in actions, "prospective gas action reuse"); actions.add((parameter,action))
            version, old, new, floor = decode(UPDATED_DATA, hex_bytes(event["data"]))
            prior = current[parameter]
            require(version == 2 and old == prior[0] and old < new <= old*2 and floor == prior[1], "prospective gas update transition")
            current[parameter] = (new, floor, prior[2], prior[3]+1)
            changes.append({"parameterId":parameter, "oldValue":str(old), "newValue":str(new), "actionId":action,
                "revision":str(prior[3]+1), "log":event, "publication":_location(event)})
        for i, parameter in enumerate(PARAMETER_IDS):
            require(self.read(host,"gasParameterInfo(bytes32)", GAS_INFO,("bytes32",),(parameter,)) == current[parameter]
                and self.one(host,"gasParameter(bytes32)","uint256",("bytes32",),(parameter,)) == current[parameter][0]
                and dep[6+i] == current[parameter][0], "prospective current gas/history differs")
        return {"registrations":rows,"updates":changes,"current":[{"parameterId":p,"info":json_values(current[p])} for p in PARAMETER_IDS],
            "governanceAuthority":executor,"governanceExecutionReplayed":False}

    def _gas_at(self, dep, gas, event):
        require(_position(gas["registrations"][-1]["log"]) < _position(event), "prospective publication before constructor")
        values = {row["parameterId"]: uint(row["genesisValue"]) for row in gas["registrations"]}
        for row in gas["updates"]:
            if _position(row["log"]) < _position(event): values[row["parameterId"]] = uint(row["newValue"])
        return (*dep[:6], *(values[p] for p in PARAMETER_IDS))

    def _definitions(self, dep):
        schema, store = dep[0][2:4]; result = []
        rows = list(DEFINITIONS) + [(dep[3],2,dep[4],dep[5],None)]
        seen = set()
        for identifier,kind,digest,size,expected in rows:
            require(identifier not in seen,"prospective renderer/definition alias"); seen.add(identifier)
            facts = self.one(schema,"documentFacts(bytes32)",DOCUMENT_FACTS,("bytes32",),(identifier,))
            require(facts[0] and facts[1] == kind and facts[2] <= 2 and facts[3:7] == (digest,RAW_BYTES,ZERO,size)
                and 0 < facts[7] <= 128 and facts[8] != ZERO,"prospective original definition facts")
            parts, chunks = [], []
            for index in range(facts[7]):
                chunk = self.one(schema,"documentChunkHashAt(bytes32,uint256)","bytes32",("bytes32","uint256"),(identifier,index))
                pointer,length = self.read(store,"chunk(bytes32)",("address","uint32"),("bytes32",),(chunk,))
                raw = self.one(store,"readChunk(bytes32)","bytes",("bytes32",),(chunk,))
                require(0 < length == len(raw) <= 24576 and keccak256(raw) == chunk and self.code(pointer) == b"\x00"+raw,
                    "prospective definition chunk/carrier")
                parts.append(raw); chunks.append({"hash":chunk,"pointer":pointer,"bytes":str(length),"payloadHex":"0x"+raw.hex()})
            raw = b"".join(parts)
            require(len(raw) == size and keccak256(raw) == digest and (expected is None or raw == expected),"prospective exact definition bytes")
            result.append({"documentId":identifier,"facts":json_values(facts),"chunks":chunks,"payloadHex":"0x"+raw.hex(),
                "currentStatus":str(facts[2]),"historicalDefinitionEligibilityReexecuted":False})
        return result

    def _source_fields(self, dep, source, at):
        a=self.a; cid=uint(a["collectionId"]); s=named(SCHEMA["payload"][2],source)
        require(s["floorSourceId"]>0 and s["floorSourceSetHash"] != ZERO
            and self.one(dep[0][1],"sourceAt(uint64)",SOURCE[2],("uint64",),(s["floorSourceId"],)) == s["provider"]
            and self.one(dep[0][1],"sourceSetHashAt(uint64)","bytes32",("uint64",),(s["floorSourceId"],)) == s["floorSourceSetHash"],
            "prospective original Floor source differs")
        provider=s["provider"]; release=s["release"]; serving=s["serving"]; renderer=s["renderer"]
        require(provider[5] < s["floorSourceId"] and 0 < provider[6] <= at and provider[4] != ZERO and provider[7] != ZERO,
            "prospective original provider provenance")
        subject=hash_abi(("bytes32","uint256","address","uint256"),
            (schema_id("6529STREAM_SUBJECT_COLLECTION_V1"),uint(a["chainId"]),a["core"],cid))
        require(release[0] == subject and release[5] and all(release[i] != ZERO for i in range(5)),"prospective collection/script scope")
        require(release[1] == hash_abi(("bytes32","uint256","address","uint256","bytes32","bytes32","bytes32"),
            (schema_id("6529STREAM_CONSERVATION_COLLECTION_RELEASE_V1"),uint(a["chainId"]),a["core"],cid,release[0],release[2],release[3])),"prospective membership preimage")
        require(s["artistId"] == s["artist"][1] and s["artist"][0] != ZERO_ADDRESS and s["artist"][4] <= 5 and s["artist"][5] <= 4,
            "prospective Artist observation")
        script=s["script"]; m=s["scriptManifest"]; media=s["mediaManifest"]
        display=s["display"]
        require(serving[2] == schema_id("ONCHAIN") and all(len(value.encode("utf-8")) <= bound
            for value,bound in zip(display,(256,2048,2048,0,8192),strict=True))
            and serving[7:9] == (keccak256(display[2].encode()),keccak256(display[3].encode())),
            "prospective original serving/display fields")
        require(serving[0] in (STABLE,CHUNKED) and serving[1] and serving[5] == keccak256(script) and serving[6] == len(script)
            and 0 < len(script) <= 24576 and m[0] == serving[5] and m[1] == serving[0] and m[3] == ""
            and safe_uri(m[4]) and m[6] == "application/javascript" and m[8] and s["scriptManifestHash"] != ZERO,"prospective native script fields")
        script.decode("utf-8")
        if serving[0] == STABLE:
            require(m[2] == 1 and m[7] == 1 and m[5] == "" and s["display"][4].encode() == script,"prospective stable script")
        else: require(m[2] in (1,2) and m[7] > 0,"prospective unsupported chunked source")
        normalized=(*m[:5],"",*m[6:])
        require(release[3] == hash_abi(("bytes32",SOURCE[12],"uint32","address","bytes32"),
            (schema_id("6529STREAM_CONSERVATION_NATIVE_SCRIPT_V1"),normalized,serving[6],serving[3],serving[4])),"prospective script source preimage")
        require(media[12:] == ("",ZERO,"",ZERO) and s["mediaManifestHash"] != ZERO
            and media[1] == s["display"][2],"prospective unsupported media denominator")
        for offset in (0,4,8):
            kind,uri,digest,mime=media[offset:offset+4]
            require((uri == "" and digest == ZERO and mime == "") if kind == 0 else
                (kind in (5,6,7) and uri.startswith({5:"ipfs://",6:"ar://",7:"https://"}[kind])
                    and safe_uri(uri) and digest != ZERO and 0 < len(mime.encode("utf-8")) <= 128),
                "prospective native media slot")
        require(release[2] == hash_abi(("bytes32",SOURCE[14]),(schema_id("6529STREAM_MEDIA_MASTER_INVENTORY_V1"),media)),"prospective media preimage")
        mask=sum(bit for bit,index in ((1,2),(2,6),(4,10)) if media[index] != ZERO)
        require(release[4] == hash_abi(("bytes32","bytes32","bytes32","uint8",SOURCE[8],"bytes32"),
            (provider[4],s["mediaManifestHash"],s["scriptManifestHash"],mask,serving,release[1])),"prospective context preimage")
        require(renderer[:2] == serving[3:5] and renderer[4] == serving[0] and renderer[7] == schema_id("STATIC")
            and all(renderer[i] != ZERO for i in range(1,8)),"prospective renderer observation")
        if serving[0] == STABLE:
            require(renderer[5:7] == (schema_id("6529STREAM_METADATA_TOKEN_RENDER_CONTEXT_V1"),
                schema_id("6529STREAM_METADATA_RENDER_NO_EXTERNAL_READS_V1")),"prospective stable renderer context")
        catalog=renderer_declaration(renderer)
        require(keccak256(catalog)==dep[4] and len(catalog)==dep[5],"prospective exact renderer catalogue")
        return s

    def _archive_facts(self, dep, coverage, artist_id, at, runtime):
        host=dep[0][4]; key=coverage[0]
        if key in self._archive:
            row=self._archive[key]
            require(row["coverage"] == json_values(coverage),"prospective conflicting saved coverage")
            require(coverage[2] == artist_id and row["objectIdentity"][1] == DEFINITIONS[5 if runtime else 4][0],
                "prospective saved archive artist/object role")
            require(all(uint(x["fixity"][13]) <= at for x in row["receipts"]),"prospective saved archive time")
            return row
        require(key != ZERO and coverage[2] == artist_id and artist_id != ZERO
            and coverage[7] != coverage[8] and all(coverage[i] != ZERO for i in range(15) if i != 6)
            and coverage[6] > 0,"prospective original archive coverage fields")
        require(hash_abi(("bytes32","uint256","address",COVERAGE),
            (schema_id("6529STREAM_EXTERNAL_COVERAGE_V1"),uint(self.a["chainId"]),host,(ZERO,*coverage[1:]))) == key
            and self.one(host,"coverage(bytes32)",COVERAGE,("bytes32",),(key,)) == coverage,"prospective original coverage hash/getter")
        obj=self.one(host,"objectIdentity(bytes32)",OBJECT,("bytes32",),(coverage[1],))
        require(obj[0] == artist_id and obj[3:7] == coverage[3:7] and obj[2] == RAW_BYTES
            and obj[1] == DEFINITIONS[5 if runtime else 4][0]
            and obj[7:] == (schema_id("IANA:application/zip" if runtime else "IANA:image/png"),DEFINITIONS[6][0],DEFINITIONS[6][2])
            and hash_abi(("bytes32","uint256","address","address",OBJECT),
                (schema_id("6529STREAM_EXTERNAL_OBJECT_V1"),uint(self.a["chainId"]),host,self.a["core"],obj)) == coverage[1],
            "prospective original object identity/hash")
        receipts=[]
        for family_index,receipt_index,fixity_index in ((7,9,11),(8,10,12)):
            r,identifier,sig=self.read(host,"receipt(bytes32)",(ARCHIVE_RECEIPT,"bytes","bytes"),("bytes32",),(coverage[receipt_index],))
            f,fsig=self.read(host,"fixity(bytes32)",(FIXITY,"bytes"),("bytes32",),(coverage[fixity_index],))
            require(len(identifier)<=8192 and len(sig)<=4096 and len(fsig)<=4096
                and r[:2] == (coverage[1],coverage[family_index]) and r[2] == keccak256(identifier)
                and r[6] != ZERO_ADDRESS and 0 < r[7] <= at and r[9] >= r[7]
                and hash_abi(("bytes32","uint256","address",ARCHIVE_RECEIPT),
                    (schema_id("6529STREAM_EXTERNAL_RECEIPT_V1"),uint(self.a["chainId"]),host,r)) == coverage[receipt_index],
                "prospective original archive receipt")
            require(f[:4] == (coverage[receipt_index],*r[:3]) and f[4] == schema_id("STREAM_EXTERNAL_OBJECT_FIXITY_V1")
                and f[5:13] == (obj[4],obj[4],obj[3],obj[3],obj[5],obj[5],obj[6],obj[6])
                and r[7] <= f[13] <= at and f[14] == 1 and f[15] != ZERO and f[18] not in (ZERO_ADDRESS,r[6])
                and f[20] >= f[13] and hash_abi(("bytes32","uint256","address",FIXITY),
                    (schema_id("6529STREAM_EXTERNAL_FIXITY_V1"),uint(self.a["chainId"]),host,f)) == coverage[fixity_index],
                "prospective original archive fixity")
            receipts.append({"receiptHash":coverage[receipt_index],"receipt":json_values(r),"identifierHex":"0x"+identifier.hex(),
                "signatureHex":"0x"+sig.hex(),"fixityHash":coverage[fixity_index],"fixity":json_values(f),"fixitySignatureHex":"0x"+fsig.hex()})
        row={"host":host,"coverageHash":key,"coverage":json_values(coverage),"objectIdentity":json_values(obj),"receipts":receipts,
            "historicalCurrentPairReplayed":False,"originalSignaturesReauthorized":False,"archiveConsensusProven":False}
        self._archive[key]=row
        return row

    def _record(self, dep, gas, digest, index, previous, previous_chain, event, history):
        host=self.a["host"]; cid=uint(self.a["collectionId"])
        p,r=self.read(host,"prospectiveRecord(bytes32)",(PUBLICATION,RECEIPT),("bytes32",),(digest,))
        raw=self.one(host,"prospectivePayload(bytes32)","bytes",("bytes32",),(digest,))
        require(0 < len(raw) <= MAX_PAYLOAD,"prospective payload byte bound")
        domain,saved_p,s,e,environment=decode(PAYLOAD,raw,maximum=MAX_PAYLOAD)
        require(domain == DOMAIN["payload"] and saved_p == p and encode(PAYLOAD,(domain,p,s,e,environment)) == raw,
            "prospective canonical original payload")
        require(event["topics"] == [PUBLICATION_EVENT,digest,topic("uint256",cid),p[1]]
            and decode(EVENT_DATA,hex_bytes(event["data"]),maximum=MAX_ABI) == (1,r,p[7]),"prospective original publication event")
        at=uint(history["blockTimestamps"][str(int(event["blockNumber"],16))])
        require(p[0] == cid and p[1] != ZERO and p[2] == previous and p[3] == index and p[4] != ZERO
            and p[9] != ZERO and 0 < p[8] <= at and safe_uri(p[7]),"prospective publication identity/lineage/URI")
        require(r[0] == digest and r[2:6] == (cid,p[1],previous,index+1) and r[8] == p[4]
            and r[9:11] == (keccak256(raw),len(raw)) and r[11] != ZERO_ADDRESS and r[12] in (3,8) and r[13]>0
            and r[14:17] == (p[8],at,p[9]) and r[17:] == tuple(row[2] for row in DEFINITIONS[:3]),"prospective original receipt fields")
        original_dep=self._gas_at(dep,gas,event)
        require(record_hash(self.a,original_dep,p,r) == digest and chain_hash(self.a,previous_chain,r) == r[1],"prospective native record/chain preimage")
        require(e[0] == r[8] == source_hash(self.a,original_dep,cid,s),"prospective historical source hash/gas differs")
        fields=self._source_fields(original_dep,s,at)
        require(r[6:8] == fields["release"][:2],"prospective receipt subject/membership")
        require(environment_bytes(p[6]) == environment and len(environment) == p[6][3] and keccak256(environment) == p[6][2]
            and p[6][2] != ZERO,"prospective exact original environment")
        captures=[]; names=set(); package={row[0]:(row[1],row[2]) for row in p[6][12]}
        def member(path,raw): require(package.get(path) == (len(raw),sha(raw)),"prospective required package member")
        member("prospective/script.js",fields["script"]); member("prospective/media.abi",encode((SOURCE[14],),(fields["mediaManifest"],)))
        require(1 <= len(p[5]) <= 2 and len(e[2]) == len(p[5]),"prospective capture denominator")
        archive=[self._archive_facts(dep,e[1],fields["artistId"],at,True)]
        require(e[1][0:2] == (p[6][1],p[6][0]),"prospective environment coverage link")
        for capture,cov in zip(p[5],e[2],strict=True):
            v,html,obj,coverage,repeats,stamp,execution=capture
            require(v[0] not in names,"prospective duplicate vector"); names.add(v[0])
            require(html == simulation_html(self.a,cid,e[0],v,fields["script"]) and 0 < stamp <= p[8]
                and repeats[0] != ZERO and repeats[0] == repeats[1],"prospective HTML/repeat capture")
            x,=decode((EXECUTION,),execution,maximum=MAX_ABI)
            require(x == (DOMAIN["simulation"],e[0],vector_hash(v),p[6][2],sha(html),repeats,stamp,0),"prospective execution declaration")
            member("prospective/"+v[0]+".html",html)
            require(cov[:2] == (coverage,obj) and cov[4] == repeats[0],"prospective capture coverage link")
            archive.append(self._archive_facts(dep,cov,fields["artistId"],at,False))
            captures.append({"vector":json_values(v),"vectorHash":vector_hash(v),"animationHTMLHex":"0x"+html.hex(),
                "executionHex":"0x"+execution.hex(),"execution":json_values(x),"capturedAt":str(stamp),"browserExecutionProven":False})
        return {"index":str(index),"recordHash":digest,"receipt":json_values(r),"receiptFields":{k:json_values(v) for k,v in named(SCHEMA["receipt"],r).items()},
            "nativePublication":json_values(p),"publication":_location(event),"log":event,"payloadHex":"0x"+raw.hex(),
            "publicationAbiHex":"0x"+encode((PUBLICATION,),(p,)).hex(),"originalSource":json_values(s),"originalEvidence":json_values(e),
            "environmentHex":"0x"+environment.hex(),"originalDependencies":json_values(original_dep),
            "evidenceHash":evidence_hash(self.a,original_dep,r),"archiveFacts":archive,"captures":captures}

    def _current_source(self, dep):
        core=self.a["core"]; floor=dep[0][1]; observations={}; reasons=[]
        count,head=self.read(floor,"sourceSetHead()",("uint64","bytes32"))
        require(self.one(floor,"sourceCount()","uint64") == count,"prospective current Floor count")
        observations["floorSourceHead"]=[str(count),head]
        if count == 0: reasons.append("no_current_floor_source")
        current=None
        if count:
            current=self.one(floor,"sourceAt(uint64)",SOURCE[2],("uint64",),(count,)); observations["floorSource"]=json_values(current)
            require(self.one(floor,"sourceSetHashAt(uint64)","bytes32",("uint64",),(count,)) == head,"prospective current source head")
            for key,index in (("metadata",0),("provider",2)):
                raw=self.code(current[index]); digest=keccak256(raw)
                observations[key+"Runtime"]={"address":current[index],"observedHash":digest,"bytes":str(len(raw)),"savedHash":current[index+1]}
                if not raw or digest != current[index+1]: reasons.append(key+"_runtime_differs")
        pointers={}
        for name in ("COLLECTION_METADATA","METADATA_ROUTER","ARTIST_REGISTRY"):
            role=schema_id(name); pointer=self.one(core,"getSatellitePointer(bytes32)",POINTER,("bytes32",),(role,))
            pointers[name]=pointer; observations[name]=json_values(pointer)
            if pointer[0] == ZERO_ADDRESS or pointer[1] == ZERO or pointer[3] != role or pointer[6] != 1 or pointer[7] == ZERO or pointer[8] == ZERO or pointer[9] == 0:
                reasons.append(name.lower()+"_pointer_not_active")
            else:
                raw=self.code(pointer[0])
                observations[name+"Runtime"]={"bytes":str(len(raw)),"hash":keccak256(raw)}
                if not raw or keccak256(raw) != pointer[1]: reasons.append(name.lower()+"_runtime_differs")
        if current and pointers["COLLECTION_METADATA"][:2] != current[:2]: reasons.append("current_metadata_differs_from_floor_source")
        if not reasons:
            router=pointers["METADATA_ROUTER"][0]
            profile=self.one(router,"renderingProfile()",("bytes32","bytes32","bytes32"))
            observations["renderingProfile"]=json_values(profile)
            if profile[0] not in (STABLE,CHUNKED): reasons.append("unsupported_current_presentation_profile")
        if reasons: return {"status":"not_evaluated","observations":observations,"reasons":reasons,"source":None,"sourceHash":None}
        s,digest=self.read(self.a["host"],"currentSource(uint256)",(SOURCE,"bytes32"),("uint256",),(uint(self.a["collectionId"]),))
        require(s[0:3] == (count,head,current) and s[4:6] == pointers["METADATA_ROUTER"][:2]
            and s[7][0] == pointers["ARTIST_REGISTRY"][0] and digest == source_hash(self.a,dep,uint(self.a["collectionId"]),s),"prospective current source hash/graph")
        self._source_fields(dep,s,uint(self.a["timestamp"]))
        return {"status":"observed","observations":observations,"reasons":[],"source":json_values(s),"sourceHash":digest,
            "requireProspectiveCollectionReferenceCalled":False,"currentArchiveLivenessProven":False}

    def _capture(self):
        host=self.a["host"]; cid=uint(self.a["collectionId"])
        history=scan_public_history(self.reader,self.a,filters=[{"address":host,"topics":[PUBLICATION_EVENT,None,topic("uint256",cid)]},
            {"address":host,"topics":[[REGISTERED_EVENT,UPDATED_EVENT]]}])
        dep,executor=self._bindings(); gas=self._gas(dep,executor,history); definitions=self._definitions(dep)
        count=self.one(host,"prospectiveCount(uint256)","uint256",("uint256",),(cid,))
        require(count <= MAX_RECORDS,"prospective record count bound")
        events=[e for e in history["logs"] if e["topics"][0] == PUBLICATION_EVENT]
        require(len(events) == count,"prospective event/count denominator")
        records=[]; previous=previous_chain=ZERO; ids=set(); total=0
        for index,event in enumerate(events):
            digest=self.one(host,"prospectiveAt(uint256,uint256)","bytes32",("uint256","uint256"),(cid,index))
            require(digest != ZERO and digest not in ids,"prospective duplicate original record"); ids.add(digest)
            row=self._record(dep,gas,digest,index,previous,previous_chain,event,history)
            if records: require(uint(row["receiptFields"]["recordedAt"]) >= uint(records[-1]["receiptFields"]["recordedAt"]),"prospective receipt time order")
            require(all(row["receipt"][3] != old["receipt"][3] for old in records),"prospective reused reference ID")
            total += len(hex_bytes(row["payloadHex"])); require(total <= MAX_TOTAL_PAYLOAD,"prospective aggregate payload bound")
            records.append(row); previous,previous_chain=digest,row["receipt"][1]
        head=self.one(host,"currentProspectiveReference(uint256)",RECEIPT,("uint256",),(cid,))
        expected=zero(RECEIPT) if not records else self.read(host,"prospectiveRecord(bytes32)",(PUBLICATION,RECEIPT),("bytes32",),(previous,))[1]
        require(head == expected,"prospective current history head differs")
        current=self._current_source(dep)
        require(self.one(host,"dependencies()",DEP) == dep and self.one(host,"prospectiveCount(uint256)","uint256",("uint256",),(cid,)) == count,
            "prospective final dependencies/history differs")
        self.reader.request("eth_getBlockByHash",[self.a["blockHash"],False])
        self.reader.request("eth_getBlockByNumber",[hex(uint(self.a["blockNumber"])),False])
        if type(self.reader.transport) is PublicReplayTransport: self.reader.transport.finish()
        raw=dumps({"profile":PROFILE,"profileHash":PROFILE_HASH,"version":"1","source":self.a,"sourceReviewCommit":SOURCE_REVISION,
            "sourceState":{k:self.a[k] for k in COMMON},"provenance":self.provenance,"runtimeAdmissionStatus":self.a["runtimeAdmission"]["kind"],
            "dependencies":json_values(dep),"gasHistory":gas,"definitions":definitions,"currentSource":current,
            "history":{"count":str(count),"head":previous,"chainHash":previous_chain},"records":records,
            "historyCoverage":history["coverage"],"claims":CLAIMS,"qualification":QUALIFICATION})
        require(len(raw) <= MAX_OUTPUT,"prospective snapshot byte bound")
        return raw
    def snapshot(self):
        if self._snapshot is not None: return self._snapshot
        require(not self._started,"failed prospective capture cannot resume"); self._started=True
        try: self._snapshot=self._capture()
        except MuseumError: raise
        except (KeyError,TypeError,IndexError,ValueError,OverflowError) as exc: raise MuseumError("malformed prospective evidence") from exc
        return self._snapshot
    def transcript(self):
        require(self._snapshot is not None,"prospective snapshot required before transcript")
        return self.reader.transcript()
