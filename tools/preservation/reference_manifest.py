"""Independent consistency and retained-package checks for native reference manifests.

These checks join declared bytes to local artifacts. They do not establish a
live contract grant, network inclusion, independent human observation, licensing,
or the completeness of arbitrary JavaScript dependencies.
"""
from __future__ import annotations
import ast
import base64
import hashlib
import json
import re
import stat
import zipfile
import zlib
from pathlib import Path
from jsonschema import Draft202012Validator
from tools.metadata import reference_render_profile as profile
from tools.preservation.reference_package import safe_name
from tools.preservation.reference_archive import inspect

MAX_BYTES = 524288

def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf8")

def kh(raw):
    return "0x" + profile.digest(raw)

def sh(raw):
    return "0x" + hashlib.sha256(raw).hexdigest()

def _noninteger_number(token):
    raise ValueError("noninteger JSON number is outside this profile")


def _pairs(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise ValueError("duplicate member")
        value[key] = item
    return value

def uint(value, width=256, positive=False):
    if not isinstance(value, str) or not re.fullmatch(r"0|[1-9][0-9]*", value):
        raise ValueError("unsigned decimal string")
    number = int(value)
    if number >= 1 << width or (positive and not number):
        raise ValueError("unsigned width or nonzero")
    return number

def nonzero(row, names):
    for name in names.split():
        if int(row[name], 16) == 0:
            raise ValueError("zero " + name)

def text(value, maximum, empty=False):
    if not isinstance(value, str) or (not value and not empty) or len(value.encode("utf8")) > maximum:
        raise ValueError("text bound")

def _files(rows, relative):
    previous = None
    aliases = set()
    for row in rows:
        text(row["path"], 1024 if relative else 2048)
        uint(row["byteSize"], 64)
        nonzero(row, "sha256Digest")
        name = row["path"]
        if relative:
            if any(ord(c) < 0x20 or ord(c) >= 0x7f for c in name):
                raise ValueError("relative ASCII path")
            safe_name(name)
        if previous is not None and previous.encode() >= name.encode():
            raise ValueError("ordered files")
        if name.casefold() in aliases:
            raise ValueError("Windows case alias")
        previous = name
        aliases.add(name.casefold())

def validate(raw: bytes):
    if not 0 < len(raw) <= MAX_BYTES:
        raise ValueError("manifest bytes")
    value = json.loads(raw.decode("utf8"), object_pairs_hook=_pairs,
                       parse_float=_noninteger_number, parse_constant=_noninteger_number)
    if canonical(value) != raw:
        raise ValueError("canonical JSON")
    Draft202012Validator(profile.documents()[profile.SCHEMA]).validate(value)
    for key, name in (("schemaId", profile.SCHEMA), ("schemaHash", profile.SCHEMA), ("profileHash", profile.PROFILE)):
        expected = kh(name.encode()) if key == "schemaId" else kh(profile.canonical(profile.documents()[name]))
        if value[key] != expected:
            raise ValueError("definition pin")
    chain = uint(value["chainId"], positive=True)
    cid = uint(value["collectionId"], positive=True)
    sources = value["sources"]
    if [r["role"] for r in sources] != [str(i) for i in range(7)]:
        raise ValueError("source order")
    for row in sources:
        nonzero(row, "address runtimeHash")
    expected = kh(bytes.fromhex(kh(b"6529STREAM_SUBJECT_COLLECTION_V1")[2:]) + chain.to_bytes(32,"big")
                  + int(sources[0]["address"],16).to_bytes(32,"big") + cid.to_bytes(32,"big"))
    if value["subject"] != expected:
        raise ValueError("collection subject")
    renderer = value["renderer"]
    nonzero(renderer,"renderer rendererCodeHash routerVersion routerManifestHash context presentationProfile dependencyReadSet")
    if renderer["rendererClass"] != "STATIC" or kh(canonical(renderer)) != value["rendererCatalogHash"]:
        raise ValueError("fixed STATIC declaration")
    nonzero(value,"rendererCatalogId")
    pub = value["publication"]
    if pub["authorizationClass"] not in ("3","8"):
        raise ValueError("curator authority class")
    uint(pub["grantRevision"],64,True);uint(pub["effectiveAt"],64,True)
    revision = uint(pub["revision"],64,True)
    nonzero(pub,"recorder reasonHash referenceId")
    if (int(pub["predecessor"],16)==0) != (revision==1):
        raise ValueError("predecessor shape")
    text(pub["manifestURI"],2048,True)
    snapshot=value["snapshot"]
    nonzero(snapshot,"recordHash manifestHash sourceHash inventoryPlan schemaHash profileHash canonicalizationHash")
    uint(snapshot["revision"],64,True)
    env=value["environment"]
    for name in ("engineName","engineVersion","toolchainName","toolchainVersion"):
        text(env[name],256)
    text(env["operatingSystemVersion"],128);text(env["licenseNote"],16384)
    if (env["operatingSystem"],env["architecture"],env["colorSpace"],env["devicePixelRatio"]) != ("Windows","AMD64","srgb","1"):
        raise ValueError("native software profile")
    for name in ("viewportWidth","viewportHeight"):
        if not 1 <= uint(env[name],16) <= 4096:
            raise ValueError("viewport")
    if env["captureProfile"] != kh(b"STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1"):
        raise ValueError("capture profile")
    _files(env["packageFiles"],True);_files(env["platformPrerequisites"],False)
    inventory={r["path"]:r for r in env["packageFiles"]}
    for path_key, digest_key in (("engineExecutablePath","engineExecutableSha256"),("toolchainPath","toolchainSha256")):
        row=inventory.get(env[path_key])
        if row is None or row["sha256Digest"]!=env[digest_key] or uint(row["byteSize"],64)==0:
            raise ValueError("executable inventory member")
    env_raw=canonical(env)
    if kh(env_raw)!=value["environmentManifestHash"] or len(env_raw)!=uint(value["environmentManifestBytes"],32,True):
        raise ValueError("environment exact commitment")
    _coverage(value["environmentCoverage"])
    if env["runtimeObjectHash"]!=value["environmentCoverage"]["objectHash"]:
        raise ValueError("runtime object")
    count=uint(value["mintedEver"],positive=True)
    captures=value["captures"]
    expected_serials=[1] if count==1 else [1,count]
    if [uint(c["collectionSerial"],positive=True) for c in captures]!=expected_serials:
        raise ValueError("first/last complete inventory")
    if len({c["tokenId"] for c in captures})!=len(captures):
        raise ValueError("duplicate sample")
    for c in captures:
        uint(c["tokenId"],positive=True);uint(c["capturedAt"],64,True)
        if uint(c["tokenDataBytes"],32)>16384:
            raise ValueError("token data bound")
        nonzero(c,"originalCoordinator metadataJSONHash tokenDataHash htmlHash sourceSha256")
        html=base64.b64decode(c["animationHTMLBase64"],validate=True)
        if base64.b64encode(html).decode()!=c["animationHTMLBase64"] or not 0<len(html)<=40960:
            raise ValueError("canonical HTML base64")
        if len(html)!=uint(c["htmlBytes"],32,True) or kh(html)!=c["htmlHash"] or sh(html)!=c["sourceSha256"]:
            raise ValueError("complete HTML")
        if c["environmentManifestHash"]!=value["environmentManifestHash"]:
            raise ValueError("capture environment")
        _coverage(c["coverage"])
        if c["coverage"]["artistId"]!=value["environmentCoverage"]["artistId"]:
            raise ValueError("archive artist")
        if c["repeatCaptureSha256"] != [c["coverage"]["sha256Digest"]]*2:
            raise ValueError("repeat capture commitment")
    return value

def _coverage(row):
    uint(row["byteSize"],64,True)
    nonzero(row,"objectHash artistId contentHash sha256Digest arweaveDataRoot coverageHash firstFamilyRecordHash secondFamilyRecordHash firstReceiptHash secondReceiptHash firstFixityHash secondFixityHash checkpointHash profileHash")
    if row["firstFamilyRecordHash"]==row["secondFamilyRecordHash"] or row["firstReceiptHash"]==row["secondReceiptHash"]:
        raise ValueError("two distinct original slots")

def object_bytes(path: Path, coverage):
    actual=inspect(path)
    for observed,expected in (("sha256","sha256Digest"),("keccak256","contentHash"),("arweaveDataRoot","arweaveDataRoot")):
        if "0x"+actual[observed]!=coverage[expected]:
            raise ValueError("whole-object " + observed)
    if actual["byteSize"]!=coverage["byteSize"]:
        raise ValueError("whole-object size")
    return actual

def package_bytes(value, archive_path: Path):
    """Full original ZIP bytes, every exact entry and all native/flat object hashes."""
    object_bytes(archive_path,value["environmentCoverage"])
    expected=value["environment"]["packageFiles"]
    with zipfile.ZipFile(archive_path) as archive:
        infos=archive.infolist()
        if [i.filename for i in infos]!=[r["path"] for r in expected]:
            raise ValueError("complete ZIP member inventory")
        for info,row in zip(infos,expected):
            if info.is_dir() or stat.S_ISLNK(info.external_attr>>16) or info.flag_bits&1:
                raise ValueError("unsupported ZIP entry")
            raw=archive.read(info)
            if len(raw)!=int(row["byteSize"]) or sh(raw)!=row["sha256Digest"]:
                raise ValueError("ZIP entry bytes")
        return tool_controls(archive.read(value["environment"]["toolchainPath"]))

def tool_controls(source: bytes):
    """Read literal capture controls from archived source without executing any of it."""
    values={}
    for node in ast.parse(source.decode("utf8")).body:
        if isinstance(node,ast.Assign):
            for target in node.targets:
                if isinstance(target,ast.Name) and target.id in ("PROFILE","FLAGS","GUARDS"):
                    if target.id in values:raise ValueError("duplicate archived tool control")
                    values[target.id]=ast.literal_eval(node.value)
    if set(values)!={"PROFILE","FLAGS","GUARDS"} or values["PROFILE"]!="STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1" or not isinstance(values["GUARDS"],str) or not values["GUARDS"] or not isinstance(values["FLAGS"],tuple) or not values["FLAGS"] or any(not isinstance(v,str) for v in values["FLAGS"]):
        raise ValueError("unsupported archived tool controls")
    return {"profile":values["PROFILE"],"guardsSha256":hashlib.sha256(values["GUARDS"].encode()).hexdigest(),"flags":values["FLAGS"]}

def png_pixels(raw: bytes, width: int, height: int):
    """Validate the bounded noninterlaced RGB/RGBA PNG geometry emitted by this tool."""
    if len(raw)<33 or raw[:8]!=b"\x89PNG\r\n\x1a\n":
        raise ValueError("PNG signature")
    offset=8;chunks=[];image=bytearray();ended=False
    while offset<len(raw):
        if offset+12>len(raw):raise ValueError("PNG truncated chunk")
        size=int.from_bytes(raw[offset:offset+4],"big");kind=raw[offset+4:offset+8]
        end=offset+12+size
        if end>len(raw):raise ValueError("PNG chunk length")
        body=raw[offset+8:offset+8+size]
        if zlib.crc32(kind+body)!=int.from_bytes(raw[offset+8+size:end],"big"):
            raise ValueError("PNG CRC")
        chunks.append(kind)
        if kind==b"IHDR":
            if len(chunks)!=1 or size!=13 or int.from_bytes(body[:4],"big")!=width or int.from_bytes(body[4:8],"big")!=height or body[8]!=8 or body[9] not in (2,6) or body[10:]!=b"\x00\x00\x00":
                raise ValueError("PNG supported geometry")
            channels=3 if body[9]==2 else 4
        elif kind==b"IDAT":image.extend(body)
        elif kind==b"IEND":
            if size or end!=len(raw):raise ValueError("PNG terminal chunk")
            ended=True
        elif kind[0]&32==0:raise ValueError("unsupported critical PNG chunk")
        offset=end
    if not ended or not chunks or chunks[0]!=b"IHDR" or not image:
        raise ValueError("PNG incomplete")
    expected=height*(width*channels+1)
    decoder=zlib.decompressobj();pixels=decoder.decompress(bytes(image),expected+1)
    if len(pixels)!=expected or not decoder.eof or decoder.unused_data or decoder.unconsumed_tail:
        raise ValueError("PNG pixel stream")
    if any(pixels[i*(width*channels+1)]>4 for i in range(height)):
        raise ValueError("PNG row filter")
    return pixels

def capture_bytes(value, index: int, metadata_path: Path, capture_directory: Path, runtime_root: Path, controls: dict):
    """Join actual Router JSON, full HTML, both PNGs and named loaded-module observations.

    runtime_root is the explicit fresh restored package root from these reports.
    Reports are retained observations, not cryptographic proof of OS execution.
    """
    c=value["captures"][index];env=value["environment"]
    raw=metadata_path.read_bytes()
    if kh(raw)!=c["metadataJSONHash"]:
        raise ValueError("original Router JSON")
    metadata=json.loads(raw,object_pairs_hook=_pairs)
    prefix="data:text/html;base64,"
    if not metadata["animation_url"].startswith(prefix):
        raise ValueError("native Router animation")
    html=base64.b64decode(metadata["animation_url"][len(prefix):],validate=True)
    if html!=base64.b64decode(c["animationHTMLBase64"],validate=True) or html!=(capture_directory/"original.html").read_bytes():
        raise ValueError("original source export")
    package={r["path"].casefold():r for r in env["packageFiles"]}
    platform={r["path"].casefold():r for r in env["platformPrerequisites"]}
    root=runtime_root.resolve().as_posix().rstrip("/")+"/"
    first=None
    for i in range(2):
        png_path=capture_directory/f"capture-{i}.png";png=png_path.read_bytes();object_bytes(png_path,c["coverage"])
        png_pixels(png,int(env["viewportWidth"]),int(env["viewportHeight"]))
        if first is not None and png!=first:
            raise ValueError("actual repeated bytes")
        first=png
        report=json.loads((capture_directory/f"capture-{i}.json").read_bytes(),object_pairs_hook=_pairs)
        if (report["sourceSha256"],report["captureSha256"],report["engineSha256"])!=(c["sourceSha256"][2:],c["coverage"]["sha256Digest"][2:],env["engineExecutableSha256"][2:]):
            raise ValueError("reported source/capture/engine")
        if report["sourceBytes"]!=len(html) or report["captureBytes"]!=len(png) or report["browser"]["product"]!="Chrome/"+env["engineVersion"]:
            raise ValueError("reported bytes or build")
        if report["os"]!={"platform":"win32","machine":"AMD64","version":env["operatingSystemVersion"]} or report["viewport"]!={"width":int(env["viewportWidth"]),"height":int(env["viewportHeight"]),"deviceScaleFactor":1}:
            raise ValueError("reported platform/viewport")
        if report["profile"]!="STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1" or report["colorSpace"]!="srgb" or report["locale"]!="en-US" or report["timezone"]!="UTC" or "--no-sandbox" in report["command"]:
            raise ValueError("reported capture profile")
        if report["guardsSha256"]!=controls["guardsSha256"] or report["profile"]!=controls["profile"] or any(report["command"].count(flag)!=1 for flag in controls["flags"]):
            raise ValueError("reported controls differ from actual archived tool")
        gpu=report["gpu"]
        if gpu["featureStatus"].get("gpu_compositing")!="disabled_software" or gpu["featureStatus"].get("rasterization")!="disabled_software" or gpu["auxAttributes"].get("sandboxed") is not True:
            raise ValueError("reported software raster or sandbox")
        observation=report["inspection"];width=int(env["viewportWidth"]);height=int(env["viewportHeight"])
        if observation["unsupported"] or observation["animations"] or observation["resources"] or observation["text"].strip() or any(n not in ("CANVAS","SCRIPT") for n in observation["nodes"]):
            raise ValueError("reported unsupported capture feature")
        if observation["canvas"]!=[{"width":width,"height":height,"x":0,"y":0,"displayWidth":width,"displayHeight":height}] or (observation["width"],observation["height"],observation["ratio"])!=(width,height,1):
            raise ValueError("reported canvas viewport")
        if not report["loadedModules"]:
            raise ValueError("loaded-module observations absent")
        for module in report["loadedModules"]:
            name=module["path"].replace("\\","/")
            row=package.get(name[len(root):].casefold()) if name.casefold().startswith(root.casefold()) else platform.get(name.casefold())
            if row is None or int(row["byteSize"])!=module["bytes"] or row["sha256Digest"]!="0x"+module["sha256"]:
                raise ValueError("unretained loaded dependency")
    return {"tokenId":c["tokenId"],"sourceSha256":c["sourceSha256"],"captureSha256":c["coverage"]["sha256Digest"],"repeatCount":2}


def main():
    import argparse
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest",type=Path,required=True)
    parser.add_argument("--expected-manifest-keccak",required=True)
    parser.add_argument("--runtime-zip",type=Path,required=True)
    parser.add_argument("--runtime-root",type=Path,required=True)
    parser.add_argument("--metadata",type=Path,action="append",required=True)
    parser.add_argument("--capture-directory",type=Path,action="append",required=True)
    parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args();raw=args.manifest.read_bytes()
    if kh(raw)!=args.expected_manifest_keccak:
        raise ValueError("externally supplied original manifest anchor")
    value=validate(raw)
    if len(args.metadata)!=len(value["captures"]) or len(args.capture_directory)!=len(value["captures"]):
        raise ValueError("complete sample bundle")
    controls=package_bytes(value,args.runtime_zip)
    captures=[capture_bytes(value,i,m,c,args.runtime_root,controls) for i,(m,c) in enumerate(zip(args.metadata,args.capture_directory))]
    result={"manifestHash":kh(raw),"manifestBytes":len(raw),"runtimeObjectHash":value["environmentCoverage"]["objectHash"],
            "runtimeSHA256":value["environmentCoverage"]["sha256Digest"],"runtimeBytes":value["environmentCoverage"]["byteSize"],
            "packageFileCount":len(value["environment"]["packageFiles"]),"platformPrerequisiteCount":len(value["environment"]["platformPrerequisites"]),
            "captures":captures,"localByteConsistency":True,"liveAuthorityOrArchiveEstablished":False,
            "qualification":"Exact provided manifest, full ZIP/native/flat hashes, actual source and repeat bytes plus declared reports; no independent network/authority/execution attestation or licensing inference."}
    args.output.write_bytes(canonical(result)+b"\n")
    print(json.dumps({k:result[k] for k in ("manifestHash","runtimeBytes","packageFileCount","platformPrerequisiteCount")}))

if __name__=="__main__":main()
