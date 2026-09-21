"""Bounded source archive for the concrete V10 and dossier V3 replay tools.

The archive preserves exact Git blobs, dependency inputs, instructions,
vectors, licenses and external prerequisite declarations.  Verification
restores and statically re-derives the Python import closure.  It never imports
or executes restored code and never downloads or installs a dependency.
"""
from __future__ import annotations

import ast
from dataclasses import dataclass
import importlib.util
import io
import json
from pathlib import Path
import re
import stat
import subprocess
import sys
from tempfile import TemporaryDirectory
import zipfile

from tools.preservation import reference_package as burn

from .canonical import MuseumError, dumps, keccak256, schema_id
from .repository_exchange import _destination, _publish


NAME = "STREAM_MUSEUM_PRESERVED_TOOL_SOURCE_V1"
SOURCE_REVISION = "aa8ce49e5c8c2cba4315c1763ebc5df881a686e4"
ENTRY_MODULES = (
    "tools.museum.acquisition_canonical_v10",
    "tools.museum.canonical_object_dossier_v3",
    "tools.museum.repository_exchange",
    "tools.preservation.reference_package",
)
LOCK_PATHS = (
    "requirements-tools.txt",
    "requirements-tools.lock",
    "tools/museum/requirements.txt",
    "tools/museum/requirements-jsonld.txt",
)
DATA_PREFIXES = ("schemas/museum/", "schemas/records/")
REQUIRED_DATA_PATHS = (
    "schemas/museum/account-profile/RFC8785_JCS.json",
    "schemas/records/standards/conservation/language-subtag-registry.txt.gz",
    "schemas/records/standards/conservation/rfc5646.txt.gz",
)
MAX_PARTS_MANIFEST = 2 * 1024 * 1024
MAX_PARTS = 512
MAX_FILES = 8192
MAX_ARCHIVE = 128 * 1024 * 1024
MAX_EXPANDED = 128 * 1024 * 1024
MAX_MEMBER = 32 * 1024 * 1024
MAX_VECTORS = 16
MAX_VECTOR_BYTES = 96 * 1024 * 1024
VECTOR_SCHEMA = "STREAM_PRESERVED_TOOL_REPLAY_VECTORS_V1"

CLAIMS = {
    "exactSelectedSourceBytesPreserved": True,
    "exactSelectedRuntimeDataBytesPreserved": True,
    "declaredGitRevisionRetained": True,
    "gitRevisionAssociationProvenByStandaloneVerify": False,
    "actualPythonImportClosureRecomputed": True,
    "completeDeclaredRuntimeDataPrefixDenominatorVerified": True,
    "allDeclaredVectorOccurrencesPreserved": True,
    "completeArchiveBytesVerified": True,
    "restoredCodeExecuted": False,
    "networkFetchPerformed": False,
    "dependencyInstallationPerformed": False,
    "externalArtifactAuthenticityProven": False,
    "zeroOperatorRegenerationProven": False,
    "currentToolConformanceProven": False,
    "institutionalAcceptance": False,
}
QUALIFICATION = (
    "The archive binds exact source, runtime-data, lock, instruction, vector, license and prerequisite bytes. "
    "Its verifier bounds and restores the transport, then statically recomputes the local Python "
    "import closure and checks the complete declared runtime-data prefixes without importing or "
    "executing restored code. External pins and prerequisite "
    "declarations remain supplied commitments unless their bytes are separately retained and "
    "verified. Build reads exact blobs from the declared frozen Git revision; later standalone "
    "verification authenticates the selected bytes through the external archive pin but cannot "
    "independently prove their Git provenance without a separately admitted Git object proof. "
    "Runtime input packages and each V3 package's embedded semantic-model closure are "
    "separate replay inputs. This source archive does not itself prove successful regeneration, "
    "current conformance, release acceptance or institutional ingest."
)
PROFILE_BYTES = dumps({
    "name": NAME,
    "version": "1",
    "sourceRevision": SOURCE_REVISION,
    "entryModules": list(ENTRY_MODULES),
    "runtimeDataPrefixes": list(DATA_PREFIXES),
    "requiredRuntimeDataPaths": list(REQUIRED_DATA_PATHS),
    "transport": burn.VERSION,
    "vectorSchema": VECTOR_SCHEMA,
    "bounds": {"partsManifestBytes": str(MAX_PARTS_MANIFEST), "parts": str(MAX_PARTS),
        "files": str(MAX_FILES), "archiveBytes": str(MAX_ARCHIVE),
        "expandedBytes": str(MAX_EXPANDED), "memberBytes": str(MAX_MEMBER),
        "vectors": str(MAX_VECTORS), "vectorBytes": str(MAX_VECTOR_BYTES)},
    "claims": CLAIMS,
    "qualification": QUALIFICATION,
})
PROFILE_HASH = keccak256(PROFILE_BYTES)

INSTRUCTIONS = {
    "schema": "STREAM_PRESERVED_TOOL_REPLAY_INSTRUCTIONS_V1",
    "sourceRevision": SOURCE_REVISION,
    "python": {"implementation": "CPython", "version": "3.13.x",
        "isolatedRuntimeRequired": True, "network": False, "install": False},
    "commands": [
        {"id": "packet-v10-verify", "module": ENTRY_MODULES[0], "operation": "verify",
            "arguments": ["<case-root>", "--manifest-hash", "<manifest-hash>"]},
        {"id": "packet-v10-export", "module": ENTRY_MODULES[0], "operation": "export-packet",
            "arguments": ["<case-root>", "--manifest-hash", "<manifest-hash>"]},
        {"id": "dossier-v3-verify", "module": ENTRY_MODULES[1], "operation": "verify",
            "arguments": ["<case-root>", "--manifest-hash", "<manifest-hash>"]},
    ],
    "runtimeInputs": {
        "vectors": "vectors/replay-vectors.json and its complete cases/<id>/ trees",
        "semanticModel": "V3 verification reuses the exact dependency closure embedded in each retained conservation input",
        "sourceInputs": "No repository data path outside retained tools/, locks/, schemas/museum/ and schemas/records/ is silently read",
    },
    "execution": "Performed only by the enclosing isolated replay runner; this archive verifier never executes retained code.",
}


def _revision(value, label="tool source revision"):
    if not isinstance(value, str) or not re.fullmatch(r"[0-9a-f]{40}", value):
        raise MuseumError(label)
    return value


def _instructions(revision):
    value = dict(INSTRUCTIONS)
    value["sourceRevision"] = _revision(revision)
    return value


@dataclass(frozen=True)
class Transport:
    files: tuple[tuple[str, bytes], ...]
    restored_files: tuple[tuple[str, bytes], ...]
    archive_bytes: bytes
    package_manifest: dict
    report: dict


@dataclass(frozen=True)
class ToolArchive:
    files: tuple[tuple[str, bytes], ...]
    restored_files: tuple[tuple[str, bytes], ...]
    archive_bytes: bytes
    source_manifest: dict
    report: dict


def _sha(value: bytes) -> str:
    return burn.sha(value)


def _hex_sha(value, label):
    if not isinstance(value, str) or not re.fullmatch(r"[0-9a-f]{64}", value):
        raise MuseumError(label)
    return value


def _read_flat_package(package: Path):
    lexical = Path(package).absolute()
    for path in (lexical, *lexical.parents):
        if path.is_symlink() or (hasattr(path, "is_junction") and path.is_junction()):
            raise MuseumError("tool transport package path cannot traverse a link")
    root = lexical.resolve(strict=True)
    if not root.is_dir():
        raise MuseumError("tool transport package directory")
    entries = list(root.iterdir())
    if not 3 <= len(entries) <= MAX_PARTS + 2:
        raise MuseumError("tool transport package entry denominator")
    result, total = {}, 0
    for path in entries:
        if path.is_symlink() or path.is_junction() or not path.is_file():
            raise MuseumError("tool transport contains a non-file entry")
        name = burn.safe_name(path.name)
        before = path.stat()
        if before.st_size > MAX_ARCHIVE:
            raise MuseumError("tool transport file byte bound")
        with path.open("rb") as stream:
            raw = stream.read(MAX_ARCHIVE + 1)
        after = path.stat()
        if (before.st_size, before.st_mtime_ns, before.st_ino) != (
                after.st_size, after.st_mtime_ns, after.st_ino) or len(raw) != before.st_size:
            raise MuseumError("tool transport file changed during snapshot")
        total += len(raw)
        if total > 2 * MAX_ARCHIVE + MAX_PARTS_MANIFEST:
            raise MuseumError("tool transport aggregate byte bound")
        result[name] = raw
    return root, result


def _preflight(package: Path, expected_parts_sha256: str):
    _hex_sha(expected_parts_sha256, "tool transport external manifest pin")
    root, files = _read_flat_package(package)
    raw = files.get("parts.json", b"")
    if not raw or len(raw) > MAX_PARTS_MANIFEST or _sha(raw) != expected_parts_sha256:
        raise MuseumError("tool transport external manifest differs")
    try:
        value = json.loads(raw)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise MuseumError("tool transport manifest JSON") from exc
    if burn.canonical(value) + b"\n" != raw or not isinstance(value, dict) or set(value) != {
            "version", "archiveFormat", "archiveBytes", "archiveSha256", "manifestSha256",
            "partBytes", "parts", "files", "declaration"}:
        raise MuseumError("tool transport canonical manifest shape")
    if (value["version"] != burn.VERSION or value["archiveFormat"] != "ZIP_DEFLATE"
            or value["partBytes"] != burn.PART_BYTES):
        raise MuseumError("tool transport profile")
    parts, members = value["parts"], value["files"]
    if not isinstance(parts, list) or not 1 <= len(parts) <= MAX_PARTS:
        raise MuseumError("tool transport part denominator")
    if not isinstance(members, list) or not 1 <= len(members) <= MAX_FILES:
        raise MuseumError("tool transport member denominator")
    archive_size = value["archiveBytes"]
    if type(archive_size) is not int or not 1 <= archive_size <= MAX_ARCHIVE:
        raise MuseumError("tool transport archive byte bound")
    expanded = 0
    paths = []
    for row in members:
        if not isinstance(row, dict) or set(row) != {"path", "bytes", "sha256"}:
            raise MuseumError("tool transport member inventory shape")
        name = burn.safe_name(row["path"])
        size = row["bytes"]
        if type(size) is not int or not 0 <= size <= MAX_MEMBER:
            raise MuseumError("tool transport member byte bound")
        _hex_sha(row["sha256"], "tool transport member digest")
        expanded += size
        if expanded > MAX_EXPANDED:
            raise MuseumError("tool transport expanded byte bound")
        paths.append(name)
    if paths != sorted(paths) or len({path.casefold() for path in paths}) != len(paths):
        raise MuseumError("tool transport member order or alias")
    complete = bytearray()
    expected_names = {"parts.json", "runtime.zip"}
    for index, row in enumerate(parts):
        if not isinstance(row, dict) or set(row) != {"index", "offset", "path", "bytes", "sha256"}:
            raise MuseumError("tool transport part shape")
        name = f"part-{index:06d}.bin"
        if (row["index"] != index or row["offset"] != len(complete) or row["path"] != name
                or type(row["bytes"]) is not int or not 1 <= row["bytes"] <= burn.PART_BYTES):
            raise MuseumError("tool transport part coordinate")
        if index + 1 < len(parts) and row["bytes"] != burn.PART_BYTES:
            raise MuseumError("tool transport short nonfinal part")
        _hex_sha(row["sha256"], "tool transport part digest")
        body = files.get(name)
        if body is None or len(body) != row["bytes"] or _sha(body) != row["sha256"]:
            raise MuseumError("tool transport part bytes differ")
        complete.extend(body); expected_names.add(name)
    archive = bytes(complete)
    if (len(archive) != archive_size or _sha(archive) != value["archiveSha256"]
            or files.get("runtime.zip") != archive or set(files) != expected_names):
        raise MuseumError("tool transport complete archive differs")
    internal = burn.canonical({"version": burn.VERSION, "declaration": value["declaration"],
        "files": members})
    if expanded + len(internal) > MAX_EXPANDED:
        raise MuseumError("tool transport expanded byte bound")
    try:
        with zipfile.ZipFile(io.BytesIO(archive)) as zipped:
            rows = zipped.infolist(); names = [burn.safe_name(row.filename) for row in rows]
            sizes = {row["path"]: row["bytes"] for row in members}; sizes["PACKAGE.json"] = len(internal)
            if (names != sorted(names) or len(names) != len(sizes)
                    or len({name.casefold() for name in names}) != len(names) or set(names) != set(sizes)):
                raise MuseumError("tool transport ZIP member denominator")
            for row in rows:
                if (row.is_dir() or row.flag_bits & 1 or stat.S_ISLNK(row.external_attr >> 16)
                        or row.file_size != sizes[row.filename] or row.file_size > MAX_MEMBER):
                    raise MuseumError("tool transport ZIP member metadata")
    except (zipfile.BadZipFile, RuntimeError) as exc:
        raise MuseumError("tool transport ZIP structure") from exc
    return root, files, value, archive


def _read_restored(root: Path):
    rows = burn.rows(root)
    if not 1 <= len(rows) <= MAX_FILES + 1:
        raise MuseumError("tool restored member denominator")
    total, result = 0, {}
    for row in rows:
        if row["bytes"] > MAX_MEMBER:
            raise MuseumError("tool restored member byte bound")
        total += row["bytes"]
        if total > MAX_EXPANDED:
            raise MuseumError("tool restored expanded byte bound")
        result[row["path"]] = (root / row["path"]).read_bytes()
    return result


def verify_transport(package: Path, expected_parts_sha256: str) -> Transport:
    """Verify and privately restore one Burn transport without executing it."""
    try:
        root, package_files, manifest, archive = _preflight(package, expected_parts_sha256)
        with TemporaryDirectory(prefix="stream-tool-transport-") as temporary:
            snapshot = Path(temporary) / "package"; snapshot.mkdir()
            for name, raw in package_files.items():
                (snapshot / name).write_bytes(raw)
            restored = Path(temporary) / "restored"
            checked = burn.restore(snapshot, restored, expected_parts_sha256)
            files = _read_restored(restored)
        if checked != manifest:
            raise MuseumError("tool transport restore manifest differs")
        internal = files.pop("PACKAGE.json", None)
        if internal != burn.canonical({"version": burn.VERSION,
                "declaration": manifest["declaration"], "files": manifest["files"]}):
            raise MuseumError("tool transport internal manifest differs")
        report = {"transport": burn.VERSION, "partsManifestSha256": expected_parts_sha256,
            "archiveSha256": manifest["archiveSha256"], "archiveKeccak256": keccak256(archive),
            "archiveBytes": str(len(archive)), "partCount": str(len(manifest["parts"])),
            "fileCount": str(len(manifest["files"])),
            "restoredCodeExecuted": False, "networkFetchPerformed": False}
        return Transport(tuple(sorted(package_files.items())), tuple(sorted(files.items())), archive,
            manifest, report)
    except MuseumError:
        raise
    except (OSError, KeyError, TypeError, ValueError, OverflowError) as exc:
        raise MuseumError("malformed preserved tool transport") from exc


def restore_transport(package: Path, expected_parts_sha256: str, destination: Path) -> Transport:
    """Publish verified restored bytes atomically; never execute them."""
    checked = verify_transport(package, expected_parts_sha256)
    _destination(destination, [package])
    _publish(dict(checked.restored_files), destination, [package])
    return checked


def _module_path(module, available):
    path = module.replace(".", "/") + ".py"
    if path in available:
        return path
    path = module.replace(".", "/") + "/__init__.py"
    return path if path in available else None


def _module_name(path):
    if path.endswith("/__init__.py"):
        return path[:-12].replace("/", ".")
    return path[:-3].replace("/", ".")


def _resolve_import(node, current_module, is_package, available):
    package = current_module if is_package else current_module.rpartition(".")[0]
    candidates = []
    if isinstance(node, ast.Import):
        candidates.extend(alias.name for alias in node.names)
    else:
        name = ("." * node.level) + (node.module or "")
        try:
            base = importlib.util.resolve_name(name, package) if node.level else (node.module or "")
        except (ImportError, ValueError) as exc:
            raise MuseumError("tool source relative import") from exc
        if base:
            candidates.append(base)
        for alias in node.names:
            child = (base + "." + alias.name) if base else (package + "." + alias.name)
            base_path = _module_path(base, available) if base else None
            if (_module_path(child, available) is not None or node.module is None
                    or (base.startswith("tools") and base_path is not None
                        and base_path.endswith("/__init__.py"))):
                candidates.append(child)
    return list(dict.fromkeys(candidates))


def _closure(available, getter, entry_modules=ENTRY_MODULES):
    pending, selected, edges, imports = list(entry_modules), {}, [], []
    queued = set(pending)
    while pending:
        module = pending.pop(0)
        path = _module_path(module, available)
        if path is None:
            raise MuseumError("tool source module absent: " + module)
        raw = getter(path)
        if path in selected:
            continue
        selected[path] = raw
        try:
            tree = ast.parse(raw.decode("utf-8"), filename=path)
        except (UnicodeDecodeError, SyntaxError) as exc:
            raise MuseumError("tool source Python syntax: " + path) from exc
        current = _module_name(path); is_package = path.endswith("/__init__.py")
        for node in ast.walk(tree):
            if not isinstance(node, (ast.Import, ast.ImportFrom)):
                continue
            resolved = _resolve_import(node, current, is_package, available)
            names = [alias.name for alias in node.names]
            imports.append({"path": path, "line": node.lineno, "column": node.col_offset,
                "kind": "from" if isinstance(node, ast.ImportFrom) else "import",
                "module": node.module if isinstance(node, ast.ImportFrom) else None,
                "level": node.level if isinstance(node, ast.ImportFrom) else 0,
                "names": names, "resolved": resolved})
            for dependency in resolved:
                dep_path = _module_path(dependency, available)
                if dependency.startswith("tools.") and dep_path is None:
                    raise MuseumError("tool source local import absent: " + dependency)
                if dep_path is not None and dependency.startswith("tools."):
                    edges.append({"importer": path, "line": node.lineno,
                        "module": dependency, "path": dep_path})
                    if dependency not in queued:
                        queued.add(dependency); pending.append(dependency)
        # Preserve package initializers that Python loads on the way to a module.
        parts = current.split(".")[:-1 if not is_package else None]
        for index in range(1, len(parts) + 1):
            parent = ".".join(parts[:index])
            parent_path = _module_path(parent, available)
            if parent_path and parent not in queued:
                queued.add(parent); pending.append(parent)
    imports.sort(key=lambda row: (row["path"], row["line"], row["column"], row["kind"]))
    edges.sort(key=lambda row: (row["importer"], row["line"], row["module"], row["path"]))
    local_modules = {_module_name(path).split(".")[0] for path in selected}
    external = sorted({name.split(".")[0] for row in imports for name in row["resolved"]
        if name and name.split(".")[0] not in local_modules and not name.startswith("tools.")})
    stdlib = sorted(name for name in external if name in sys.stdlib_module_names)
    third_party = sorted(set(external) - set(stdlib))
    files = [{"path": path, "bytes": len(raw), "sha256": _sha(raw)}
        for path, raw in sorted(selected.items())]
    return selected, {"entryModules": list(entry_modules), "files": files,
        "importOccurrences": imports, "localEdges": edges,
        "stdlibModules": stdlib, "thirdPartyModules": third_party}


def _rows(files):
    return [{"path": path, "bytes": len(raw), "sha256": _sha(raw)}
        for path, raw in sorted(files.items())]


def _pins(value):
    if not isinstance(value, list) or not value:
        raise MuseumError("tool source external pins required")
    seen, result = set(), []
    for row in value:
        if not isinstance(row, dict) or set(row) != {"name", "role", "uri", "sha256", "bytes"}:
            raise MuseumError("tool source external pin shape")
        if (not isinstance(row["name"], str) or not row["name"] or row["name"] in seen
                or row["role"] not in ("runtime", "distribution", "source", "system")
                or not isinstance(row["uri"], str) or not row["uri"].startswith(("https://", "urn:"))
                or type(row["bytes"]) is not int or row["bytes"] <= 0):
            raise MuseumError("tool source external pin")
        _hex_sha(row["sha256"], "tool source external pin digest")
        seen.add(row["name"]); result.append(dict(row))
    return sorted(result, key=lambda row: row["name"])


def _licenses(value):
    if not isinstance(value, list):
        raise MuseumError("tool source license declarations")
    result = [{"subject": "repository-source", "expression": "MIT",
        "instrumentPath": "licenses/repository-LICENSE",
        "qualification": "Exact retained repository license bytes; no dependency license inference."}]
    for row in value:
        if not isinstance(row, dict) or set(row) != {
                "subject", "expression", "instrumentPath", "qualification"}:
            raise MuseumError("tool source license declaration shape")
        if (not all(isinstance(row[key], str) and row[key] for key in
                ("subject", "expression", "qualification"))
                or row["instrumentPath"] is not None):
            raise MuseumError("tool source external license declaration")
        result.append(dict(row))
    if len({row["subject"] for row in result}) != len(result):
        raise MuseumError("tool source duplicate license subject")
    return sorted(result, key=lambda row: row["subject"])


def _prerequisites(value, pins):
    if not isinstance(value, list) or not value:
        raise MuseumError("tool source prerequisite declarations required")
    pin_names = {row["name"] for row in pins}; seen = set(); result = []
    for row in value:
        if not isinstance(row, dict) or set(row) != {
                "name", "version", "platform", "included", "pin", "qualification"}:
            raise MuseumError("tool source prerequisite declaration shape")
        if (not all(isinstance(row[key], str) and row[key] for key in
                ("name", "version", "platform", "qualification"))
                or type(row["included"]) is not bool or row["included"] is not False
                or row["pin"] not in pin_names or row["name"] in seen):
            raise MuseumError("tool source prerequisite declaration")
        seen.add(row["name"]); result.append(dict(row))
    if not any(row["name"] == "CPython" and row["version"].startswith("3.13") for row in result):
        raise MuseumError("tool source CPython 3.13 prerequisite")
    return sorted(result, key=lambda row: row["name"])


def _vectors(value):
    if not isinstance(value, dict) or "replay-vectors.json" not in value:
        raise MuseumError("tool source replay vector descriptor")
    files = {}
    total = 0
    for path, raw in value.items():
        name = burn.safe_name(path)
        if not isinstance(raw, bytes) or name != path or name in files:
            raise MuseumError("tool source vector file")
        total += len(raw)
        if total > MAX_VECTOR_BYTES:
            raise MuseumError("tool source vector bytes")
        files[name] = raw
    try:
        descriptor = json.loads(files["replay-vectors.json"])
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise MuseumError("tool source vector descriptor JSON") from exc
    if (burn.canonical(descriptor) != files["replay-vectors.json"]
            or not isinstance(descriptor, dict) or set(descriptor) != {"schema", "cases"}
            or descriptor["schema"] != VECTOR_SCHEMA or not isinstance(descriptor["cases"], list)
            or not 1 <= len(descriptor["cases"]) <= MAX_VECTORS):
        raise MuseumError("tool source vector descriptor shape")
    ids, covered = [], {"replay-vectors.json"}
    for row in descriptor["cases"]:
        if not isinstance(row, dict) or set(row) != {"id", "kind", "root", "manifestHash"}:
            raise MuseumError("tool source vector case shape")
        identifier = row["id"]
        if (not isinstance(identifier, str) or not re.fullmatch(r"[a-z][a-z0-9-]{0,47}", identifier)
                or row["kind"] not in ("packet_v10", "dossier_v3")
                or row["root"] != "cases/" + identifier):
            raise MuseumError("tool source vector case")
        root = row["root"] + "/"; manifest = root + "manifest.json"
        if manifest not in files or keccak256(files[manifest]) != row["manifestHash"]:
            raise MuseumError("tool source vector manifest pin")
        ids.append(identifier)
        matched = {path for path in files if path.startswith(root)}
        if not matched:
            raise MuseumError("tool source empty vector case")
        covered.update(matched)
    if ids != sorted(ids) or len(set(ids)) != len(ids) or covered != set(files):
        raise MuseumError("tool source vector order or denominator")
    return files, descriptor


def _git(repository, *args):
    try:
        return subprocess.run(["git", "-C", str(repository), *args], check=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout
    except (OSError, subprocess.CalledProcessError) as exc:
        raise MuseumError("tool source Git read failed") from exc


def _git_inventory(repository, revision):
    _revision(revision)
    raw = _git(repository, "ls-tree", "-r", "--name-only", revision)
    try:
        paths = raw.decode("utf-8").splitlines()
    except UnicodeDecodeError as exc:
        raise MuseumError("tool source Git path encoding") from exc
    return set(paths)


def _git_blob(repository, revision, path):
    return _git(repository, "show", revision + ":" + path)


def _git_blobs(repository, revision, paths):
    """Read a bounded explicit Git-blob denominator in one cat-file process."""
    paths = tuple(paths)
    if (not paths or len(paths) > MAX_FILES or any(not isinstance(path, str)
            or "\n" in path or "\r" in path for path in paths)):
        raise MuseumError("tool source Git data path denominator")
    request = b"".join((revision + ":" + path + "\n").encode("utf-8") for path in paths)
    try:
        raw = subprocess.run(["git", "-C", str(repository), "cat-file", "--batch"],
            input=request, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout
    except (OSError, subprocess.CalledProcessError) as exc:
        raise MuseumError("tool source Git data read failed") from exc
    offset, result, total = 0, {}, 0
    for path in paths:
        end = raw.find(b"\n", offset)
        if end < 0:
            raise MuseumError("tool source Git data response")
        header = raw[offset:end].split(); offset = end + 1
        if (len(header) != 3 or not re.fullmatch(rb"[0-9a-f]{40}", header[0])
                or header[1] != b"blob" or not header[2].isdigit()):
            raise MuseumError("tool source Git data blob")
        size = int(header[2])
        if not 0 <= size <= MAX_MEMBER or offset + size >= len(raw):
            raise MuseumError("tool source Git data byte bound")
        body = raw[offset:offset + size]; offset += size
        if raw[offset:offset + 1] != b"\n":
            raise MuseumError("tool source Git data framing")
        offset += 1; total += size
        if total > MAX_EXPANDED:
            raise MuseumError("tool source Git data aggregate bound")
        result[path] = body
    if offset != len(raw):
        raise MuseumError("tool source Git data trailing response")
    return result


def _manifest(files, closure, revision, pins, licenses, prerequisites, descriptor):
    categories = {
        "source": _rows({path: raw for path, raw in files.items() if path.startswith("tools/")}),
        "data": _rows({path: raw for path, raw in files.items()
            if path.startswith(DATA_PREFIXES)}),
        "locks": _rows({path: raw for path, raw in files.items() if path.startswith("locks/")}),
        "instructions": _rows({path: raw for path, raw in files.items() if path.startswith("instructions/")}),
        "vectors": _rows({path: raw for path, raw in files.items() if path.startswith("vectors/")}),
        "licenses": _rows({path: raw for path, raw in files.items() if path.startswith("licenses/")}),
        "declarations": _rows({path: raw for path, raw in files.items() if path.startswith("declarations/")}),
    }
    return {"profile": NAME, "profileHash": PROFILE_HASH, "sourceRevision": revision,
        "closure": closure, "categories": categories, "vectorDescriptor": descriptor,
        "externalPins": pins, "licenses": licenses, "prerequisites": prerequisites,
        "claims": CLAIMS, "qualification": QUALIFICATION}


def build(repository: Path, output: Path, *, source_revision=SOURCE_REVISION,
          vectors, external_pins, licenses, prerequisites) -> ToolArchive:
    """Build from exact Git blobs and explicit caller-retained vector/declaration bytes."""
    try:
        repository = Path(repository).resolve(strict=True)
        # The logical source is the immutable Git object database at source_revision,
        # not the mutable repository directory.  A new output below repository/out is
        # therefore safe and cannot enter the exact `git show revision:path` reads.
        output = _destination(Path(output), [])
        pins = _pins(external_pins); license_rows = _licenses(licenses)
        prerequisite_rows = _prerequisites(prerequisites, pins)
        vector_files, descriptor = _vectors(vectors)
        available = _git_inventory(repository, source_revision)
        cache = {}
        def getter(path):
            if path not in cache:
                cache[path] = _git_blob(repository, source_revision, path)
            return cache[path]
        selected, closure = _closure(available, getter)
        data_paths = sorted(path for path in available if path.startswith(DATA_PREFIXES))
        data_files = _git_blobs(repository, source_revision, data_paths)
        with TemporaryDirectory(prefix="stream-tool-source-") as temporary:
            root = Path(temporary) / "source-tree"; root.mkdir()
            staged = {**selected, **data_files}
            for path in LOCK_PATHS:
                if path not in available:
                    raise MuseumError("tool source lock absent: " + path)
                staged["locks/" + path.replace("/", "-")] = getter(path)
            if "LICENSE" not in available:
                raise MuseumError("tool source repository license absent")
            staged["licenses/repository-LICENSE"] = getter("LICENSE")
            staged["instructions/replay.json"] = burn.canonical(_instructions(source_revision))
            staged.update({"vectors/" + path: raw for path, raw in vector_files.items()})
            staged["declarations/external-pins.json"] = burn.canonical(pins)
            staged["declarations/licenses.json"] = burn.canonical(license_rows)
            staged["declarations/prerequisites.json"] = burn.canonical(prerequisite_rows)
            source_manifest = _manifest(staged, closure, source_revision, pins, license_rows,
                prerequisite_rows, descriptor)
            source_raw = burn.canonical(source_manifest)
            staged["manifest/source.json"] = source_raw
            for path, raw in staged.items():
                target = root / burn.safe_name(path); target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(raw)
            declaration = {"profile": NAME, "profileHash": PROFILE_HASH,
                "sourceRevision": source_revision, "sourceManifestSha256": _sha(source_raw),
                "archiveKind": "V10_V3_EXACT_SOURCE_AND_REPLAY_INPUTS"}
            result = burn.package_tree(root, output, declaration)
        parts_sha = _sha((output / "parts.json").read_bytes())
        checked = verify(output, parts_sha)
        if checked.report["archiveSha256"] != result["archiveSha256"]:
            raise MuseumError("tool source build readback differs")
        return checked
    except MuseumError:
        raise
    except (OSError, KeyError, TypeError, ValueError, OverflowError) as exc:
        raise MuseumError("malformed preserved tool source input") from exc


def _verify_restored(transport: Transport):
    files = dict(transport.restored_files)
    raw = files.get("manifest/source.json", b"")
    try:
        manifest = json.loads(raw)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise MuseumError("tool source manifest JSON") from exc
    if burn.canonical(manifest) != raw or not isinstance(manifest, dict) or set(manifest) != {
            "profile", "profileHash", "sourceRevision", "closure", "categories",
            "vectorDescriptor", "externalPins", "licenses", "prerequisites", "claims", "qualification"}:
        raise MuseumError("tool source canonical manifest shape")
    revision = _revision(manifest["sourceRevision"])
    if (manifest["profile"] != NAME or manifest["profileHash"] != PROFILE_HASH
            or manifest["claims"] != CLAIMS
            or manifest["qualification"] != QUALIFICATION):
        raise MuseumError("tool source manifest profile")
    if set(manifest["categories"]) != {
            "source", "data", "locks", "instructions", "vectors", "licenses", "declarations"}:
        raise MuseumError("tool source category denominator")
    declaration = transport.package_manifest["declaration"]
    if declaration != {"profile": NAME, "profileHash": PROFILE_HASH,
            "sourceRevision": revision, "sourceManifestSha256": _sha(raw),
            "archiveKind": "V10_V3_EXACT_SOURCE_AND_REPLAY_INPUTS"}:
        raise MuseumError("tool source package declaration")
    expected_paths = {"manifest/source.json"}
    for name, rows in manifest["categories"].items():
        if name not in {"source", "data", "locks", "instructions", "vectors", "licenses", "declarations"}:
            raise MuseumError("tool source category")
        actual = []
        for row in rows:
            if not isinstance(row, dict) or set(row) != {"path", "bytes", "sha256"}:
                raise MuseumError("tool source category row")
            path = burn.safe_name(row["path"])
            if type(row["bytes"]) is not int or row["bytes"] < 0:
                raise MuseumError("tool source category byte count")
            body = files.get(path)
            if body is None or len(body) != row["bytes"] or _sha(body) != row["sha256"]:
                raise MuseumError("tool source category bytes")
            if ((name == "source" and not path.startswith("tools/"))
                    or (name == "data" and not path.startswith(DATA_PREFIXES))
                    or (name not in {"source", "data"} and not path.startswith(name + "/"))):
                raise MuseumError("tool source category path")
            actual.append(row); expected_paths.add(path)
        if (actual != sorted(actual, key=lambda row: row["path"])
                or len({row["path"] for row in actual}) != len(actual)):
            raise MuseumError("tool source category order")
    if set(files) != expected_paths:
        raise MuseumError("tool source complete restored denominator")
    data_paths = {row["path"] for row in manifest["categories"]["data"]}
    if (not manifest["categories"]["data"] or not set(REQUIRED_DATA_PATHS) <= data_paths
            or {prefix for prefix in DATA_PREFIXES
                if any(row["path"].startswith(prefix) for row in manifest["categories"]["data"])}
                != set(DATA_PREFIXES)):
        raise MuseumError("tool source runtime data prefix denominator")
    expected_locks = {"locks/" + path.replace("/", "-") for path in LOCK_PATHS}
    if ({row["path"] for row in manifest["categories"]["locks"]} != expected_locks
            or {row["path"] for row in manifest["categories"]["instructions"]}
                != {"instructions/replay.json"}
            or {row["path"] for row in manifest["categories"]["licenses"]}
                != {"licenses/repository-LICENSE"}
            or {row["path"] for row in manifest["categories"]["declarations"]} != {
                "declarations/external-pins.json", "declarations/licenses.json",
                "declarations/prerequisites.json"}):
        raise MuseumError("tool source required category files")
    source = {path: body for path, body in files.items() if path.startswith("tools/")}
    selected, closure = _closure(set(source), lambda path: source[path])
    if set(selected) != set(source) or closure != manifest["closure"]:
        raise MuseumError("tool source actual import closure differs")
    pins = _pins(manifest["externalPins"])
    supplied_licenses = [row for row in manifest["licenses"] if row.get("subject") != "repository-source"]
    if len(supplied_licenses) + 1 != len(manifest["licenses"]):
        raise MuseumError("tool source repository license declaration")
    licenses = _licenses(supplied_licenses)
    prerequisites = _prerequisites(manifest["prerequisites"], pins)
    if pins != manifest["externalPins"] or licenses != manifest["licenses"] or prerequisites != manifest["prerequisites"]:
        raise MuseumError("tool source declarations differ")
    if (files.get("declarations/external-pins.json") != burn.canonical(pins)
            or files.get("declarations/licenses.json") != burn.canonical(licenses)
            or files.get("declarations/prerequisites.json") != burn.canonical(prerequisites)):
        raise MuseumError("tool source retained declaration bytes differ")
    vector_files = {path.removeprefix("vectors/"): body for path, body in files.items()
        if path.startswith("vectors/")}
    _, descriptor = _vectors(vector_files)
    if descriptor != manifest["vectorDescriptor"]:
        raise MuseumError("tool source vector descriptor differs")
    if files.get("instructions/replay.json") != burn.canonical(_instructions(revision)):
        raise MuseumError("tool source replay instructions differ")
    report = dict(transport.report)
    report.update({"profile": NAME, "profileHash": PROFILE_HASH,
        "sourceRevision": revision, "reviewedDefaultSourceRevision": SOURCE_REVISION,
        "sourceManifestSha256": _sha(raw),
        "sourceManifestHash": keccak256(raw), "closureHash": keccak256(burn.canonical(closure)),
        "sourceFileCount": str(len(source)), "importOccurrenceCount": str(len(closure["importOccurrences"])),
        "runtimeDataFileCount": str(len(manifest["categories"]["data"])),
        "runtimeDataHash": keccak256(burn.canonical(manifest["categories"]["data"])),
        "vectorCaseCount": str(len(descriptor["cases"])), "actualClosureVerified": True,
        "claims": CLAIMS, "qualification": QUALIFICATION})
    return manifest, report


def verify(package: Path, expected_parts_sha256: str) -> ToolArchive:
    """Verify transport and semantic source closure without executing archived code."""
    transport = verify_transport(package, expected_parts_sha256)
    manifest, report = _verify_restored(transport)
    return ToolArchive(transport.files, transport.restored_files,
        transport.archive_bytes, manifest, report)


def restore_verified(package: Path, expected_parts_sha256: str, destination: Path) -> ToolArchive:
    """Verify source semantics, then atomically publish exact restored bytes."""
    checked = verify(package, expected_parts_sha256)
    _destination(destination, [package])
    _publish(dict(checked.restored_files), destination, [package])
    return checked
