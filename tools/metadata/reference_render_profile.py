"""Exact definition pins for the registered native reference-render interpretation."""
import argparse
import json
from pathlib import Path
from Crypto.Hash import keccak

ROOT = Path(__file__).resolve().parents[2]
CATALOG_SCHEMA = "STREAM_RENDERER_CLASS_DECLARATION_V1"
CATALOG_PROFILE = "STREAM_RENDERER_CLASS_DECLARATION_JSON_PROFILE_V1"
SCHEMA = "STREAM_NATIVE_REFERENCE_RENDER_V1"
PROFILE = "STREAM_NATIVE_REFERENCE_RENDER_JSON_PROFILE_V1"
ENVIRONMENT_SCHEMA = "STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1"
PNG_SCHEMA = "STREAM_REFERENCE_PNG_OBJECT_V1"
ZIP_SCHEMA = "STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1"
FORMAT_CATALOG = "STREAM_REFERENCE_NATIVE_FORMATS_V1"

def canonical(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf8")

def digest(raw):
    return keccak.new(digest_bits=256, data=raw).hexdigest()

def documents():
    h={"type":"string","pattern":"^0x[0-9a-f]{64}$"}
    address={"type":"string","pattern":"^0x[0-9a-f]{40}$"}
    fields={"context":h,"dependencyReadSet":h,"presentationProfile":h,
            "renderer":address,"rendererClass":{"enum":["STATIC","DYNAMIC"]},
            "rendererCodeHash":h,"routerManifestHash":h,"routerVersion":h,"version":{"const":1}}
    schema={"$id":CATALOG_SCHEMA,"$schema":"https://json-schema.org/draft/2020-12/schema",
            "type":"object","properties":fields,"required":list(fields),"additionalProperties":False}
    profile={"name":CATALOG_PROFILE,"schema":CATALOG_SCHEMA,"version":1,"canonicalization":"RFC8785_JCS",
             "termination":"No trailing newline in the actual declaration payload.",
             "scope":"One complete immutable renderer version declaration. The reference host fixes its exact catalog ID, hash and bytes at deployment, never a publication-selected alternate.",
             "meaning":"Attributed registration of renderer class and exact runtime/Router module version/manifest/context/presentation/read-set. It does not prove arbitrary artwork JavaScript STATIC, static analysis, rendering goldens, or browser execution.",
             "current":"Exact active first-version CATALOG under RAW_BYTES, plus the exact active schema/profile definitions. No implicit supersession or latest-record selection.",
             "byteExact":"Only STATIC is admitted by the native BYTE_EXACT consumer; DYNAMIC requires another explicitly supported capture/acceptance profile.",
             "address":"Lowercase 20-byte 0x encoding; hashes lowercase 32-byte 0x encoding; no omitted/default fields."}
    def obj(fields):
        return {"type":"object","properties":fields,"required":list(fields),"additionalProperties":False}
    u={"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":78}
    text={"type":"string"}
    def fs(names,t=h): return {k:t for k in names.split()}
    file=obj({"byteSize":u,"path":text,"sha256Digest":h})
    env=obj({**fs("engineExecutablePath engineName engineVersion licenseNote operatingSystem operatingSystemVersion architecture colorSpace toolchainName toolchainPath toolchainVersion",text),
        **fs("captureProfile engineExecutableSha256 runtimeObjectHash toolchainSha256"),
        **fs("devicePixelRatio viewportWidth viewportHeight",u),"licenseBasis":{"const":"undetermined"},
        "softwareRasterization":{"const":True},"version":{"const":1},
        "packageFiles":{"type":"array","minItems":1,"items":file},"platformPrerequisites":{"type":"array","minItems":1,"items":file}})
    cov=obj({**fs("artistId arweaveDataRoot checkpointHash contentHash coverageHash firstFamilyRecordHash firstFixityHash firstReceiptHash objectHash profileHash secondFamilyRecordHash secondFixityHash secondReceiptHash sha256Digest"),"byteSize":u})
    capture=obj({**fs("environmentManifestHash htmlHash metadataJSONHash seed sourceSha256 tokenDataHash"),
        **fs("capturedAt collectionSerial htmlBytes tokenDataBytes tokenId",u),"animationHTMLBase64":text,
        "coverage":cov,"originalCoordinator":address,"repeatCaptureSha256":{"type":"array","minItems":2,"maxItems":2,"items":h}})
    snapshot=obj({**fs("canonicalizationHash inventoryPlan manifestHash profileHash recordHash schemaHash sourceHash"),"revision":u})
    publication=obj({**fs("authorizationClass effectiveAt grantRevision revision",u),**fs("predecessor reasonHash referenceId"),"manifestURI":text,"recorder":address})
    main=obj({"acceptanceMode":{"const":"BYTE_EXACT"},"artworkClassification":{"const":"STATIC"},"captureClass":{"const":"still"},
        "captures":{"type":"array","minItems":1,"maxItems":2,"items":capture},**fs("chainId collectionId environmentManifestBytes mintedEver",u),
        **fs("environmentManifestHash profileHash rendererCatalogHash rendererCatalogId schemaHash schemaId subject"),
        "environment":env,"environmentCoverage":cov,"publication":publication,"renderer":schema,
        "snapshot":snapshot,"sources":{"type":"array","minItems":7,"maxItems":7,"items":obj({"address":address,"role":u,"runtimeHash":h})},"version":{"const":1}})
    main.update({"$schema":"https://json-schema.org/draft/2020-12/schema","$id":SCHEMA})
    environment={"$schema":"https://json-schema.org/draft/2020-12/schema","$id":ENVIRONMENT_SCHEMA,**env}
    interpretation={"name":PROFILE,"schema":SCHEMA,"version":1,"canonicalization":"RFC8785_JCS",
        "manifestMaximumBytes":524288,"integerEncoding":"Every integer is an exact unsigned decimal string except version=1.",
        "authority":"New observed-reference type is allocated to existing CURATOR family; actual collection class3 precedes global scope0 class8. Saved grant revision and original recorder persist after revocation. Neither snapshot grants nor curator classification imply artist authorship.",
        "source":"Complete current native snapshot plus actual retained first and last mint-serial checkpoint leaves (one for singleton), burned endpoints included. Full original HTML must match historical Router JSON animation; original coordinator seed must be finalized and tokenData exact.",
        "renderer":"One constructor-fixed active registered renderer class declaration; exact actual runtime, Router module version/manifest, context and read-set. BYTE_EXACT requires declared STATIC, without proving arbitrary JavaScript static.",
        "environment":"Actual whole ZIP object is independently covered, never descriptor bytes in its place. Complete named engine/toolchain and package-file inventory, loaded native OS prerequisite tuples and explicit license note are retained. Curator attests executable containment and capture correspondence; offline package validator checks actual ZIP and runs. Ethereum validates declared ASCII relative paths and byte ordering, but Windows reserved-component and case-alias validity belongs to the offline package validator. Ethereum does not execute ZIP/browser or prove arbitrary script dependency closure.",
        "archive":"Original full object and two original receipts/fixities retained. Current liveness may use later PASS/repair for those same receipts only; immutable reference data excludes refreshed fixity heads. No automatic freshness/cadence or network-consensus claim.",
        "selfHash":"Manifest excludes its own payload/record hash and recordedAt; environment excludes its own manifestHash/bytes, which the outer manifest derives. expectedHead/revision are original provenance; expectedSourcesHash is CAS validation only.",
        "scope":"COLLECTION native ONCHAIN, curator-declared STATIC artwork, registered STATIC renderer, still/BYTE_EXACT, Windows/AMD64 software raster capture profile, first/last sample. Other scopes, capture classes and acceptance modes remain required separate profiles.",
        "lock":"Host-local REFERENCE_RENDER one-way terminal-action lock; it does not lock arbitrary generic metadata or change rendering. Future snapshot locks are separate source observations.",
        "license":"Undetermined license basis is preserved and does not authorize binary redistribution; no public upload is part of this increment."}
    png={"name":PNG_SCHEMA,"version":1,"encoding":"BINARY_EXACT","formatId":"IANA:image/png","meaning":"Full PNG capture object. Byte identity and independently attested full retrieval are distinct from semantic PNG decoding, performed by the capture/offline validator."}
    zipdoc={"name":ZIP_SCHEMA,"version":1,"encoding":"BINARY_EXACT","formatId":"IANA:application/zip","meaning":"Full runnable native browser/toolchain ZIP. Whole object coverage never substitutes an inventory descriptor; package execution and containment are independently checked offline and attributed by the original curator."}
    formats={"name":FORMAT_CATALOG,"version":1,"entries":[{"id":"IANA:application/zip","mediaType":"application/zip","objectSchema":ZIP_SCHEMA},{"id":"IANA:image/png","mediaType":"image/png","objectSchema":PNG_SCHEMA}],"meaning":"Exact media-type interpretation labels, not a claim that format identification or all runtime dependencies were proved onchain."}
    return {CATALOG_SCHEMA:schema,CATALOG_PROFILE:profile,SCHEMA:main,PROFILE:interpretation,
            ENVIRONMENT_SCHEMA:environment,PNG_SCHEMA:png,ZIP_SCHEMA:zipdoc,FORMAT_CATALOG:formats}

def outputs():
    docs={k:canonical(v) for k,v in documents().items()}
    out={f"schemas/records/{k}.json":raw for k,raw in docs.items()}
    lines=["// SPDX-License-Identifier: MIT","pragma solidity ^0.8.19;","", "// Generated by tools.metadata.reference_render_profile; do not edit.", "library StreamReferenceRenderDefinitions {"]
    for prefix,name in (("RENDERER_SCHEMA",CATALOG_SCHEMA),("RENDERER_PROFILE",CATALOG_PROFILE),("SCHEMA",SCHEMA),("PROFILE",PROFILE),("ENVIRONMENT_SCHEMA",ENVIRONMENT_SCHEMA),("PNG_SCHEMA",PNG_SCHEMA),("ZIP_SCHEMA",ZIP_SCHEMA),("FORMAT_CATALOG",FORMAT_CATALOG)):
        raw=docs[name]
        lines += [f'    bytes32 public constant {prefix}_ID = keccak256("{name}");',f'    bytes32 public constant {prefix}_HASH = 0x{digest(raw)};',f'    uint32 public constant {prefix}_BYTES = {len(raw)};']
    raw=(ROOT/"schemas/museum/account-profile/RFC8785_JCS.json").read_bytes()
    lines += ['    bytes32 public constant CANON_ID = keccak256("RFC8785_JCS");',f'    bytes32 public constant CANON_HASH = 0x{digest(raw)};',f'    uint32 public constant CANON_BYTES = {len(raw)};',"}",""]
    formatted=[]
    for line in lines:
        if len(line)>100 and " = " in line:
            left,right=line.split(" = ",1);formatted.extend([left+" =","        "+right])
        else:formatted.append(line)
    out["smart-contracts/domains/records/StreamReferenceRenderDefinitions.sol"]="\n".join(formatted).encode()
    return out

def main():
    p=argparse.ArgumentParser();p.add_argument("--check",action="store_true");args=p.parse_args()
    for path,raw in outputs().items():
        dest=ROOT/path
        if args.check:
            if dest.read_bytes()!=raw: raise SystemExit(f"definition mismatch: {path}")
        else: dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(raw)
    print("reference renderer definitions exact")

if __name__=="__main__":main()
