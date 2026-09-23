"""Strict, offline transport for the actual VIEW reference ceremony.

No browser, Solidity, network, or archive authority is executed here. Capture
reports are retained observations, not independent proof of browser execution.
All integer Environment inputs are canonical unsigned decimal strings; the
only boolean is softwareRasterization. No commitments or identities are filled
with synthetic defaults. Run with ``python -m tools.preservation.view_ceremony_inputs``.
"""
from __future__ import annotations

import argparse
import ast
import base64
import hashlib
import json
from pathlib import Path
import re
import shutil
import stat
import tempfile
import zipfile
import zlib

from tools.preservation import reference_archive, reference_capture
from tools.preservation.reference_package import canonical, safe_name

ZERO = "0x" + "00" * 32
MAX_JSON = 16 * 1024 * 1024  # Offline transport bound, not an onchain gas claim.
ENV_FIELDS = (
    "objectHash coverageHash manifestHash manifestBytes engineName engineVersion "
    "engineExecutableSha256 toolchainName toolchainVersion toolchainSha256 "
    "engineExecutablePath toolchainPath packageFiles platformPrerequisites "
    "operatingSystem operatingSystemVersion architecture viewportWidth viewportHeight "
    "devicePixelRatio colorSpace softwareRasterization captureProfile licenseNote"
).split()
TEXT_BOUNDS = {
    "engineName": 256, "engineVersion": 256, "toolchainName": 256,
    "toolchainVersion": 256, "engineExecutablePath": 1024, "toolchainPath": 1024,
    "operatingSystem": 64, "operatingSystemVersion": 128, "architecture": 64,
    "colorSpace": 64, "licenseNote": 16384,
}
GRAPH_ROLES = (
    "CORE METADATA ROUTER FINALITY PROVIDER DISCOVERY ARTIST_REGISTRY SCHEMAS STORE "
    "DECLARATIONS VIEW_REGISTRY VIEW_RENDERER VIEW_SOURCE_SET PRESERVATION_RENDERER "
    "CHECKPOINT OUTPUT_MANIFEST SNAPSHOT REFERENCE INVENTORY BUNDLE ARTIFACT_COVERAGE "
    "EXTERNAL_COVERAGE SCOPE_MEMBERSHIP GOVERNANCE_EXECUTOR ROLE_REGISTRY ARCHIVE SNAPSHOT_AUTHORITY "
    "ROOT_SAFE ARTIST_SAFE"
).split()
PUBLICATION_IDS = (
    "viewId adoptionRecord checkpoint outputManifest snapshotRecord rootRecord "
    "basicBindingRecord completeBindingRecord"
).split()
PUBLICATION_ABIS = (
    "adoptionABI checkpointABI outputManifestABI snapshotReceiptABI basicBindingABI "
    "completeBindingABI referenceDependenciesABI inventoryDependenciesABI bundleDependenciesABI rootRecordABI rootBindingABI"
).split()
ENDPOINT_FIELDS = (
    "contentHash sha256Digest arweaveDataRoot byteSize firstDataPath lastDataPath "
    "firstChunkRaw lastChunkRaw"
).split()


def _keys(value, names, label):
    if type(value) is not dict or set(value) != set(names):
        raise ValueError(label + " fields differ")


def _ordered_keys(value, names, label):
    _keys(value, names, label)
    if list(value) != list(names):
        raise ValueError(label + " field order differs")


def _pairs(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise ValueError("duplicate JSON field: " + key)
        value[key] = item
    return value


def _bad_number(_):
    raise ValueError("noninteger JSON number")


def load_json(path: Path):
    return _json(_read(path, MAX_JSON))


def _json(raw):
    return json.loads(raw.decode("utf-8"), object_pairs_hook=_pairs,
                      parse_float=_bad_number, parse_constant=_bad_number)


def _read(path, maximum):
    with Path(path).open("rb") as stream:
        raw = stream.read(maximum + 1)
    if len(raw) > maximum:
        raise ValueError("bounded file exceeds transport limit: " + str(path))
    return raw


def _uint(value, width=256, positive=False):
    if type(value) is not str or not re.fullmatch(r"0|[1-9][0-9]*", value):
        raise ValueError("canonical unsigned decimal string required")
    if len(value) > 78:
        raise ValueError("unsigned integer width")
    number = int(value)
    if number >= 1 << width or (positive and not number):
        raise ValueError("unsigned integer width/nonzero")
    return number


def _hex(value, size=None, nonzero=False):
    if type(value) is not str or not re.fullmatch(r"0x(?:[0-9a-f]{2})*", value):
        raise ValueError("canonical lowercase hex required")
    raw = bytes.fromhex(value[2:])
    if (size is not None and len(raw) != size) or (nonzero and not any(raw)):
        raise ValueError("hex width/nonzero")
    return raw


def _sha(raw):
    return hashlib.sha256(raw).hexdigest()


def _anchor(value):
    if type(value) is not str or not re.fullmatch(r"[0-9a-f]{64}", value):
        raise ValueError("external SHA256 must be 64 lowercase hex digits without 0x")
    return value


def _kh(raw):
    from Crypto.Hash import keccak
    return "0x" + keccak.new(digest_bits=256, data=raw).hexdigest()


def _text(value, bound):
    if type(value) is not str or not value or len(value.encode("utf-8")) > bound:
        raise ValueError("text bound")


def _files(rows, relative):
    if type(rows) is not list or not rows:
        raise ValueError("complete nonempty file inventory required")
    previous, aliases = b"", set()
    for row in rows:
        _keys(row, ("path", "byteSize", "sha256Digest"), "file")
        _text(row["path"], 1024 if relative else 2048)
        if relative:
            safe_name(row["path"])
        name = row["path"].encode("utf-8")
        if name <= previous or row["path"].casefold() in aliases:
            raise ValueError("file inventory order/alias")
        previous = name
        aliases.add(row["path"].casefold())
        _uint(row["byteSize"], 64)
        _hex(row["sha256Digest"], 32, True)


def validate_environment(value):
    """Validate the original 24-field Environment, before archive commitments exist."""
    _keys(value, ENV_FIELDS, "Environment")
    for key in ("objectHash", "coverageHash", "manifestHash"):
        if value[key] != ZERO:
            raise ValueError("initial " + key + " must be zero")
    if _uint(value["manifestBytes"], 32) != 0:
        raise ValueError("initial manifestBytes must be zero")
    for name, maximum in TEXT_BOUNDS.items():
        _text(value[name], maximum)
    for name in ("engineExecutableSha256", "toolchainSha256", "captureProfile"):
        _hex(value[name], 32, True)
    _files(value["packageFiles"], True)
    _files(value["platformPrerequisites"], False)
    for name in ("viewportWidth", "viewportHeight"):
        if not 1 <= _uint(value[name], 16) <= 4096:
            raise ValueError("viewport bound")
    if (value["operatingSystem"], value["architecture"], value["colorSpace"],
            _uint(value["devicePixelRatio"], 8), value["softwareRasterization"]) != (
            "Windows", "AMD64", "srgb", 1, True) or type(value["softwareRasterization"]) is not bool:
        raise ValueError("original Windows software capture profile")
    if value["captureProfile"] != _kh(reference_capture.PROFILE.encode()):
        raise ValueError("capture profile differs")
    inventory = {row["path"]: row for row in value["packageFiles"]}
    for path, digest in (("engineExecutablePath", "engineExecutableSha256"), ("toolchainPath", "toolchainSha256")):
        member = inventory.get(value[path])
        if member is None or member["sha256Digest"] != value[digest] or not _uint(member["byteSize"], 64):
            raise ValueError("exact nonempty executable/toolchain inventory member")
    if len(canonical(value)) > 524288:
        raise ValueError("environment exceeds original manifest bound")
    return value


def _word(value):
    return value.to_bytes(32, "big")


def _dynamic(raw):
    return _word(len(raw)) + raw + bytes((-len(raw)) % 32)


def _tuple(fields):
    """Pairs (dynamic, encoded payload); all static fields here occupy one word."""
    cursor, head, tail = 32 * len(fields), [], []
    for dynamic, raw in fields:
        head.append(_word(cursor) if dynamic else raw)
        if dynamic:
            tail.append(raw)
            cursor += len(raw)
    return b"".join(head + tail)


def _file_array(rows):
    values = [_tuple([(True, _dynamic(row["path"].encode())),
                      (False, _word(int(row["byteSize"]))),
                      (False, _hex(row["sha256Digest"], 32))]) for row in rows]
    return _word(len(rows)) + _tuple([(True, value) for value in values])


def encode_environment(value):
    """Return exact abi.encode(Environment), including the outer dynamic offset."""
    validate_environment(value)
    fields = []
    for name in ENV_FIELDS:
        item = value[name]
        if name in TEXT_BOUNDS:
            fields.append((True, _dynamic(item.encode("utf-8"))))
        elif name in ("packageFiles", "platformPrerequisites"):
            fields.append((True, _file_array(item)))
        elif name == "softwareRasterization":
            fields.append((False, _word(int(item))))
        elif name in ("manifestBytes", "viewportWidth", "viewportHeight", "devicePixelRatio"):
            fields.append((False, _word(int(item))))
        else:
            fields.append((False, _hex(item, 32)))
    return {"environmentABI": "0x" + (_word(32) + _tuple(fields)).hex()}


def require_environment_abi(value, encoded):
    _keys(encoded, ("environmentABI",), "encoded environment")
    _hex(encoded["environmentABI"])
    if encode_environment(value) != encoded:
        raise ValueError("noncanonical or different Environment ABI")


def object_endpoints(path: Path):
    """Hash complete bytes once, then seek exact native endpoint intervals (<=256KiB)."""
    before = path.stat()
    observed = reference_archive.inspect(path)
    chunks = observed["native"]["chunks"]
    raw_chunks = []
    with path.open("rb") as stream:
        for chunk in (chunks[0], chunks[-1]):
            stream.seek(chunk["start"])
            raw = stream.read(chunk["end"] - chunk["start"])
            if len(raw) != chunk["end"] - chunk["start"] or _sha(raw) != chunk["sha256"]:
                raise ValueError("object changed or native endpoint differs")
            raw_chunks.append("0x" + raw.hex())
    after = path.stat()
    if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
        raise ValueError("object changed during endpoint capture")
    return dict(zip(ENDPOINT_FIELDS, (
        "0x" + observed["keccak256"], "0x" + observed["sha256"],
        "0x" + observed["arweaveDataRoot"], int(observed["byteSize"]),
        "0x" + chunks[0]["path"], "0x" + chunks[-1]["path"], *raw_chunks,
    )))


def require_object_endpoints(path: Path, value):
    _keys(value, ENDPOINT_FIELDS, "object endpoints")
    if type(value["byteSize"]) is not int or value != object_endpoints(path):
        raise ValueError("complete object/endpoints differ")


def _controls(raw):
    values = {}
    for node in ast.parse(raw.decode("utf-8")).body:
        if isinstance(node, ast.Assign):
            for target in node.targets:
                if isinstance(target, ast.Name) and target.id in ("PROFILE", "FLAGS", "GUARDS"):
                    if target.id in values:
                        raise ValueError("duplicate tool controls")
                    values[target.id] = ast.literal_eval(node.value)
    # This transport supports the repository's exact capture protocol, not a
    # caller-chosen script that merely makes the same report-shaped assertions.
    if values != {"PROFILE": reference_capture.PROFILE, "FLAGS": reference_capture.FLAGS,
                  "GUARDS": reference_capture.GUARDS}:
        raise ValueError("archived capture controls differ")
    return values


def validate_package_endpoints(runtime: Path, environment, manifest_path: Path):
    """Check existing member-<20digits> transport against streamed complete ZIP entries.

    Empty package members have no endpoint object. Every nonempty member must
    have exactly one correctly indexed proof; supplied paths never select files.
    """
    validate_environment(environment)
    manifest = load_json(manifest_path)
    _keys(manifest, ("version", "complete", "archiveSha256", "archiveBytes", "inventorySha256",
                     "memberCount", "nonemptyMemberCount", "packageProofPaths", "files",
                     "storageInclusionEstablished", "receiptAuthorityEstablished"), "member manifest")
    expected = environment["packageFiles"]
    with runtime.open("rb") as stream:
        archive_sha = hashlib.file_digest(stream, "sha256").hexdigest()
    indices = [i for i, row in enumerate(expected) if int(row["byteSize"])]
    if (manifest["version"] != "STREAM_PRESERVATION_PACKAGE_ENDPOINTS_V1"
            or manifest["complete"] is not True or manifest["archiveSha256"] != archive_sha
            or manifest["archiveBytes"] != str(runtime.stat().st_size)
            or manifest["inventorySha256"] != _sha(canonical(expected))
            or type(manifest["memberCount"]) is not int or manifest["memberCount"] != len(expected)
            or type(manifest["nonemptyMemberCount"]) is not int or manifest["nonemptyMemberCount"] != len(indices)
            or manifest["storageInclusionEstablished"] is not False
            or manifest["receiptAuthorityEstablished"] is not False
            or type(manifest["files"]) is not list or len(manifest["files"]) != len(indices)
            or type(manifest["packageProofPaths"]) is not list or len(manifest["packageProofPaths"]) != len(indices)):
        raise ValueError("complete package manifest differs")
    proofs, paths = {}, []
    for index, row, supplied_path in zip(indices, manifest["files"], manifest["packageProofPaths"]):
        _keys(row, ("packageIndex", "path", "sha256"), "member transport")
        name = f"member-{index:020d}.json"
        if (type(row["packageIndex"]) is not int or row["packageIndex"] != index
                or row["path"] != name or type(supplied_path) is not str
                or Path(supplied_path).name != name):
            raise ValueError("member index/path differs")
        proof_path = manifest_path.parent / name
        raw = _read(proof_path, 2 * 1024 * 1024)
        if _sha(raw) != row["sha256"]:
            raise ValueError("member transport hash differs")
        proof = _json(raw)
        _keys(proof, ["packageIndex", "path", *ENDPOINT_FIELDS], "member endpoint")
        if (type(proof["packageIndex"]) is not int or proof["packageIndex"] != index
                or proof["path"] != expected[index]["path"]):
            raise ValueError("member identity differs")
        proofs[index] = {key: proof[key] for key in ENDPOINT_FIELDS}
        paths.append(str(proof_path.resolve()))
    controls = None
    with zipfile.ZipFile(runtime) as archive, tempfile.TemporaryDirectory(prefix="view-member-") as directory:
        infos = archive.infolist()
        if [info.filename for info in infos] != [row["path"] for row in expected]:
            raise ValueError("complete ordered ZIP inventory differs")
        for index, (info, row) in enumerate(zip(infos, expected)):
            if info.is_dir() or stat.S_ISLNK(info.external_attr >> 16) or info.flag_bits & 1:
                raise ValueError("unsupported ZIP member")
            if info.file_size != int(row["byteSize"]):
                raise ValueError("ZIP member length differs")
            temporary = Path(directory) / "member.bin"
            with archive.open(info) as source, temporary.open("wb") as target:
                shutil.copyfileobj(source, target, 256 * 1024)
            with temporary.open("rb") as stream:
                digest = "0x" + hashlib.file_digest(stream, "sha256").hexdigest()
            if digest != row["sha256Digest"] or temporary.stat().st_size != int(row["byteSize"]):
                raise ValueError("ZIP member bytes differ")
            if int(row["byteSize"]):
                require_object_endpoints(temporary, proofs[index])
            if row["path"] == environment["toolchainPath"]:
                controls = _controls(_read(temporary, 1024 * 1024))
    if controls is None:
        raise ValueError("capture tool source absent")
    return {"archiveSha256": archive_sha, "packageProofPaths": paths, "controls": controls}


def validate_source(export: Path, expected_sha256: str, expected_revision: str):
    raw = _read(export / "source.json", MAX_JSON)
    if _sha(raw) != _anchor(expected_sha256):
        raise ValueError("external source SHA256 differs")
    source = _json(raw)
    _ordered_keys(source, ("schema", "schemaVersion", "fixture", "scope", "graph", "publication", "members", "sourceHash"), "source")
    if (source["schema"] != "STREAM_VIEW_CEREMONY_SOURCE_EXPORT_V1"
            or type(source["schemaVersion"]) is not int or source["schemaVersion"] != 1):
        raise ValueError("source schema differs")
    compact = lambda value: json.dumps(value, ensure_ascii=False, separators=(",", ":"), allow_nan=False).encode("utf-8")
    if raw != compact(source) or list(source)[-1] != "sourceHash":
        raise ValueError("source is not exact compact export JSON")
    if source["sourceHash"] != _kh(compact({k: v for k, v in source.items() if k != "sourceHash"})):
        raise ValueError("source aggregate hash differs")
    f = source["fixture"]
    _ordered_keys(f, ("host", "runtimeHash", "sourceRevision", "chainId", "initialBlockNumber", "initialTimestamp", "deploymentHash"), "fixture")
    _hex(f["host"], 20, True)
    for key in ("runtimeHash", "deploymentHash"):
        _hex(f[key], 32, True)
    _hex(expected_revision, 20, True)
    if f["sourceRevision"] != expected_revision:
        raise ValueError("external source revision differs")
    for key in ("chainId", "initialBlockNumber", "initialTimestamp"):
        _uint(f[key], 256, key == "chainId")
    scope = source["scope"]
    _ordered_keys(scope, ("scopeType", "collectionId", "tokenId", "scopeId"), "scope")
    if type(scope["scopeType"]) is not int or scope["scopeType"] != 4 or scope["tokenId"] != "0":
        raise ValueError("exact VIEW scope required")
    _uint(scope["collectionId"], 256, True)
    _hex(scope["scopeId"], 32, True)
    graph = source["graph"]
    if type(graph) is not list or len(graph) != len(GRAPH_ROLES):
        raise ValueError("complete graph required")
    for role, row in zip(GRAPH_ROLES, graph):
        _ordered_keys(row, ("role", "target", "runtimeHash"), "graph")
        if row["role"] != role:
            raise ValueError("graph role order differs")
        _hex(row["target"], 20, True)
        _hex(row["runtimeHash"], 32, True)
    publication = source["publication"]
    _ordered_keys(publication, PUBLICATION_IDS + PUBLICATION_ABIS, "publication")
    for key in PUBLICATION_IDS:
        _hex(publication[key], 32, True)
    # Declaration viewId and membership-derived scopeId are intentionally
    # distinct. The actual Solidity loader reconstructs both original joins.
    for key in PUBLICATION_ABIS:
        encoded = _hex(publication[key])
        if not encoded or len(encoded) % 32:
            raise ValueError("publication ABI word alignment")
        fixed = {"basicBindingABI": 1376, "completeBindingABI": 416, "rootBindingABI": 896}
        if key in fixed and len(encoded) != fixed[key]:
            raise ValueError("publication ABI exact width differs")
    members = source["members"]
    if type(members) is not list or not 1 <= len(members) <= 16384:
        raise ValueError("complete member inventory required")
    previous_token, previous_serial = 0, 0
    for index, member in enumerate(members):
        _ordered_keys(member, ("index", "tokenId", "collectionSerial", "json", "html", "outputReturn", "tokenData"), "member")
        token, serial = _uint(member["tokenId"], 256, True), _uint(member["collectionSerial"], 256, True)
        if _uint(member["index"], 64) != index or token <= previous_token or serial <= previous_serial:
            raise ValueError("member index/identity order differs")
        previous_token, previous_serial = token, serial
        bodies = {}
        for key, suffix, maximum in (("json", "json", 262144), ("html", "html", 262144),
                                      ("outputReturn", "output.abi", 992), ("tokenData", "token-data.bin", 16384)):
            row = member[key]
            _ordered_keys(row, ("path", "keccak256", "sha256", "byteLength"), "member bytes")
            if row["path"] != f"member-{index:020d}.{suffix}":
                raise ValueError("member filename/index differs")
            body = _read(export / row["path"], maximum)
            if (len(body) != _uint(row["byteLength"], 32) or _kh(body) != row["keccak256"]
                    or "0x" + _sha(body) != row["sha256"] or (key != "tokenData" and not body)
                    or (key == "outputReturn" and len(body) != 992)):
                raise ValueError("exported member raw bytes differ")
            bodies[key] = body
        # Exact fixed-width original Output: first seven words identity/lifecycle,
        # twenty entropy words, then original JSON/HTML hashes and byte lengths.
        output = bodies["outputReturn"]
        word = lambda i: int.from_bytes(output[i * 32:(i + 1) * 32], "big")
        if (word(0) != index or word(1) != token or word(2) != serial
                or word(3) >= 256 or word(4) not in (0, 1) or word(5) >= 256
                or output[6 * 32:7 * 32] != bytes.fromhex(_kh(bodies["tokenData"])[2:])
                or output[27 * 32:28 * 32] != bytes.fromhex(_kh(bodies["json"])[2:])
                or output[28 * 32:29 * 32] != bytes.fromhex(_kh(bodies["html"])[2:])
                or word(29) != len(bodies["json"]) or word(30) != len(bodies["html"])):
            raise ValueError("original output ABI/member identity differs")
    return source


def _png(raw, width, height):
    """Validate PNG CRCs, exact dimensions and bounded decompressed scanlines."""
    if not raw.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("PNG signature")
    offset, image, channels, ended = 8, bytearray(), 0, False
    while offset < len(raw):
        if offset + 12 > len(raw):
            raise ValueError("PNG truncated chunk")
        size = int.from_bytes(raw[offset:offset + 4], "big")
        kind = raw[offset + 4:offset + 8]
        end = offset + 12 + size
        body = raw[offset + 8:end - 4]
        if end > len(raw) or zlib.crc32(kind + body) != int.from_bytes(raw[end - 4:end], "big"):
            raise ValueError("PNG CRC/length")
        if offset == 8 and kind != b"IHDR":
            raise ValueError("PNG first header")
        if kind == b"IHDR":
            if (channels or size != 13 or int.from_bytes(body[:4], "big") != width
                    or int.from_bytes(body[4:8], "big") != height or body[8] != 8
                    or body[9] not in (2, 6) or body[10:] != bytes(3)):
                raise ValueError("PNG geometry/profile")
            channels = 3 if body[9] == 2 else 4
        elif kind == b"IDAT":
            image.extend(body)
        elif kind == b"IEND":
            if size or end != len(raw):
                raise ValueError("PNG terminal chunk")
            ended = True
        elif not kind[0] & 32:
            raise ValueError("PNG unsupported critical chunk")
        offset = end
    if not ended or not image:
        raise ValueError("PNG incomplete")
    expected = height * (width * channels + 1)
    decoder = zlib.decompressobj()
    pixels = decoder.decompress(bytes(image), expected + 1)
    if (len(pixels) != expected or not decoder.eof or decoder.unused_data or decoder.unconsumed_tail
            or any(pixels[i * (width * channels + 1)] > 4 for i in range(height))):
        raise ValueError("PNG scanline stream")


def _capture(directory, member, export, env, runtime_root, controls):
    html = _read(export / member["html"]["path"], 262144)
    metadata = _read(export / member["json"]["path"], 262144)
    if _read(directory / "original.html", 262144) != html:
        raise ValueError("capture original HTML differs")
    data = _json(metadata)
    prefix = "data:text/html;base64,"
    animation = data.get("animation_url") if type(data) is dict else None
    if type(animation) is not str or not animation.startswith(prefix):
        raise ValueError("original metadata HTML URI absent")
    encoded = animation[len(prefix):]
    decoded = base64.b64decode(encoded, validate=True)
    if decoded != html or base64.b64encode(decoded).decode() != encoded:
        raise ValueError("metadata/exact HTML differ")
    repeat = load_json(directory / "repeat.json")
    expected_repeat = {"profile": reference_capture.PROFILE, "acceptanceMode": "BYTE_EXACT",
                       "captureClass": "still", "sourceSha256": _sha(html),
                       "independentProcessCount": 2, "recordAuthorityEstablished": False,
                       "archiveCoverageEstablished": False}
    _keys(repeat, [*expected_repeat, "captureSha256"], "repeat report")
    if any(type(repeat[key]) is not type(value) or repeat[key] != value for key, value in expected_repeat.items()):
        raise ValueError("repeat report differs")
    package = {row["path"].casefold(): row for row in env["packageFiles"]}
    platform = {row["path"].replace("\\", "/").casefold(): row for row in env["platformPrerequisites"]}
    root = runtime_root.resolve().as_posix().rstrip("/") + "/"
    first, report_hashes = None, []
    for index in range(2):
        png = _read(directory / f"capture-{index}.png", 64 * 1024 * 1024)
        _png(png, int(env["viewportWidth"]), int(env["viewportHeight"]))
        if first is not None and first != png:
            raise ValueError("repeat PNG bytes differ")
        first = png
        raw_report = _read(directory / f"capture-{index}.json", MAX_JSON)
        report = _json(raw_report)
        report_hashes.append(_sha(raw_report))
        _keys(report, ("profile", "browser", "engineSha256", "gpu", "command", "os", "viewport",
                       "locale", "timezone", "colorSpace", "guardsSha256", "inspection", "sourceBytes",
                       "sourceSha256", "captureBytes", "captureSha256", "loadedModules"), "capture report")
        if (report["sourceSha256"] != _sha(html) or report["captureSha256"] != _sha(png)
                or repeat["captureSha256"] != _sha(png) or report["sourceBytes"] != len(html)
                or type(report["sourceBytes"]) is not int or type(report["captureBytes"]) is not int
                or report["captureBytes"] != len(png) or report["engineSha256"] != env["engineExecutableSha256"][2:]
                or report["browser"].get("product") != "Chrome/" + env["engineVersion"]):
            raise ValueError("report source/capture/engine differs")
        if (report["os"] != {"platform": "win32", "version": env["operatingSystemVersion"], "machine": "AMD64"}
                or report["viewport"] != {"width": int(env["viewportWidth"]), "height": int(env["viewportHeight"]), "deviceScaleFactor": 1}
                or report["profile"] != controls["PROFILE"] or report["colorSpace"] != "srgb"
                or report["locale"] != "en-US" or report["timezone"] != "UTC"
                or report["guardsSha256"] != _sha(controls["GUARDS"].encode())):
            raise ValueError("report environment/controls differ")
        command = report["command"]
        if (type(command) is not list or any(type(arg) is not str for arg in command)
                or "--no-sandbox" in command or any(command.count(flag) != 1 for flag in controls["FLAGS"])):
            raise ValueError("report browser flags differ")
        gpu = report["gpu"]
        if (gpu["featureStatus"].get("gpu_compositing") != "disabled_software"
                or gpu["featureStatus"].get("rasterization") != "disabled_software"
                or gpu["auxAttributes"].get("sandboxed") is not True):
            raise ValueError("report software raster/sandbox differs")
        reference_capture.check_inspection(report["inspection"], int(env["viewportWidth"]), int(env["viewportHeight"]))
        modules = report["loadedModules"]
        if type(modules) is not list or not modules:
            raise ValueError("loaded module observations absent")
        for module in modules:
            _keys(module, ("path", "bytes", "sha256"), "loaded module")
            name = module["path"].replace("\\", "/")
            row = package.get(name[len(root):].casefold()) if name.casefold().startswith(root.casefold()) else platform.get(name.casefold())
            if (row is None or type(module["bytes"]) is not int or int(row["byteSize"]) != module["bytes"]
                    or row["sha256Digest"] != "0x" + module["sha256"]):
                raise ValueError("unretained loaded dependency")
    endpoints = object_endpoints(directory / "capture-0.png")
    if endpoints["sha256Digest"] != "0x" + repeat["captureSha256"]:
        raise ValueError("capture changed during assembly")
    return {"tokenId": int(member["tokenId"]), "collectionSerial": int(member["collectionSerial"]),
            "html": "0x" + html.hex(), "metadataJSON": "0x" + metadata.hex(),
            "repeatCapture0Sha256": endpoints["sha256Digest"],
            "repeatCapture1Sha256": endpoints["sha256Digest"], **endpoints}, report_hashes


def assemble(export: Path, expected_source_sha256: str, expected_source_revision: str,
             capture_directories: list[Path], environment, runtime: Path,
             runtime_root: Path, member_manifest: Path):
    """Return three fixture input documents plus separate qualified audit metadata."""
    source = validate_source(export, expected_source_sha256, expected_source_revision)
    if len(source["members"]) != 2:
        raise ValueError("actual ceremony fixture requires exactly two members/captures")
    encoded = encode_environment(environment)
    package = validate_package_endpoints(runtime, environment, member_manifest)
    browser = object_endpoints(runtime)
    if browser["sha256Digest"] != "0x" + package["archiveSha256"]:
        raise ValueError("runtime changed during assembly")
    endpoints = [source["members"][0]]
    if len(source["members"]) > 1:
        endpoints.append(source["members"][-1])
    if len(capture_directories) != len(endpoints):
        raise ValueError("exact first/last capture directory count required")
    captures, reports = {}, []
    for index, (member, directory) in enumerate(zip(endpoints, capture_directories)):
        capture, report_hashes = _capture(directory, member, export, environment, runtime_root, package["controls"])
        captures[f"capture{index + 1}"] = capture
        reports.append({"membershipIndex": member["index"], "tokenId": member["tokenId"],
                        "captureReportSha256": report_hashes})
    # Recheck the external anchor and all exported bytes after reading observations.
    validate_source(export, expected_source_sha256, expected_source_revision)
    return {"environment": encoded, "browser": browser, "captures": captures,
            "audit": {"profile": "STREAM_VIEW_CEREMONY_INPUTS_V1", "sourceSha256": expected_source_sha256,
                      "sourceRevision": expected_source_revision, "sourceHash": source["sourceHash"],
                      "fixture": source["fixture"], "scope": source["scope"], "reports": reports,
                      "packageProofPaths": package["packageProofPaths"], "localByteConsistency": True,
                      "browserExecutionIndependentlyEstablished": False, "onchainAcceptanceEstablished": False}}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    env = sub.add_parser("environment", help="encode strict initial Environment JSON")
    env.add_argument("--input", type=Path, required=True)
    env.add_argument("--output", type=Path, required=True)
    obj = sub.add_parser("object", help="stream a complete ZIP/PNG/member into exact endpoint transport")
    obj.add_argument("--input", type=Path, required=True)
    obj.add_argument("--output", type=Path, required=True)
    join = sub.add_parser("assemble", aliases=["captures"], help="validate complete inputs and emit fixture documents")
    join.add_argument("--export", type=Path, required=True)
    join.add_argument("--expected-source-sha256", required=True)
    join.add_argument("--expected-source-revision", required=True)
    join.add_argument("--capture-directory", type=Path, action="append", required=True)
    join.add_argument("--environment", type=Path, required=True)
    join.add_argument("--runtime-zip", type=Path, required=True)
    join.add_argument("--runtime-root", type=Path, required=True)
    join.add_argument("--member-manifest", type=Path, required=True)
    join.add_argument("--output-directory", type=Path, required=True)
    args = parser.parse_args(argv)
    if args.command in ("environment", "object"):
        result = encode_environment(load_json(args.input)) if args.command == "environment" else object_endpoints(args.input)
        with args.output.open("xb") as output:
            output.write(canonical(result) + b"\n")
    else:
        result = assemble(args.export, args.expected_source_sha256, args.expected_source_revision,
                          args.capture_directory, load_json(args.environment), args.runtime_zip,
                          args.runtime_root, args.member_manifest)
        args.output_directory.mkdir(parents=True, exist_ok=False)
        for name, value in result.items():
            (args.output_directory / (name + ".json")).write_bytes(canonical(value) + b"\n")


if __name__ == "__main__":
    main()
