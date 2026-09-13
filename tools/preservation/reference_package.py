"""Deterministic, fully enumerated native runtime packages and bounded part transport.

The package contains actual engine/toolchain files. Splitting is transport only:
the external manifest commits every ordered part and every original file. Local
hash validation is not an onchain artifact receipt or a license determination.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
from pathlib import Path, PurePosixPath
import shutil
import stat
import tempfile
import zipfile

PART_BYTES = 512 * 1024
PYTHON_SHA256 = "4acbed6dd1c744b0376e3b1cf57ce906f9dc9e95e68824584c8099a63025a3c3"
PYTHON_URL = "https://www.python.org/ftp/python/3.12.10/python-3.12.10-embed-amd64.zip"
VERSION = "STREAM_NATIVE_REFERENCE_PACKAGE_V1"


def canonical(value: object) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"),
                      allow_nan=False).encode("utf-8")


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def safe_name(name: str) -> str:
    path = PurePosixPath(name)
    if (not name or path.is_absolute() or str(path) != name or any(c in name for c in '\\:<>"|?*')
            or any(p in (".", "..", "") or p.endswith((" ", ".")) for p in name.split("/"))
            or any(ord(c) < 32 or ord(c) > 126 for c in name)):
        raise ValueError("noncanonical package path")
    for component in path.parts:
        stem = component.split(".")[0].upper()
        if stem in {"CON", "PRN", "AUX", "NUL", *(f"COM{i}" for i in range(10)), *(f"LPT{i}" for i in range(10))}:
            raise ValueError("reserved native path")
    return name


def rows(root: Path) -> list[dict]:
    result, seen = [], set()
    for path in sorted(root.rglob("*"), key=lambda p: p.relative_to(root).as_posix()):
        if path.is_symlink() or (hasattr(path, "is_junction") and path.is_junction()):
            raise ValueError("package contains a link")
        if not path.is_file():
            continue
        name = safe_name(path.relative_to(root).as_posix())
        if name.casefold() in seen:
            raise ValueError("case-insensitive package alias")
        seen.add(name.casefold())
        raw = path.read_bytes()
        result.append({"path": name, "bytes": len(raw), "sha256": sha(raw)})
    return result


def _write_zip(destination: Path, files: list[tuple[str, bytes]]) -> None:
    with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED,
                         compresslevel=9, allowZip64=True) as archive:
        for name, raw in files:
            info = zipfile.ZipInfo(safe_name(name), date_time=(1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | 0o644) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, raw, compresslevel=9)


def package_tree(root: Path, output: Path, declaration: dict) -> dict:
    """No fetch or execution; preserve every regular file under the explicit root."""
    root = root.resolve(strict=True)
    output = output.resolve()
    if output.is_relative_to(root):
        raise ValueError("package output cannot be inside its input")
    output.mkdir(parents=True, exist_ok=False)
    inventory = rows(root)
    if not inventory or any(r["path"] == "PACKAGE.json" for r in inventory):
        raise ValueError("empty package or reserved manifest name")
    internal = {"version": VERSION, "declaration": declaration, "files": inventory}
    manifest_bytes = canonical(internal)
    files = [(r["path"], (root / r["path"]).read_bytes()) for r in inventory]
    # Capture races cannot turn the committed inventory into different ZIP bytes.
    for row, (_, raw) in zip(inventory, files):
        if (len(raw), sha(raw)) != (row["bytes"], row["sha256"]):
            raise ValueError("input file changed during packaging")
    files.append(("PACKAGE.json", manifest_bytes))
    files.sort(key=lambda item: item[0])
    archive_path = output / "runtime.zip"
    _write_zip(archive_path, files)
    whole = archive_path.read_bytes()
    parts = []
    for offset in range(0, len(whole), PART_BYTES):
        raw = whole[offset:offset + PART_BYTES]
        index = len(parts)
        name = f"part-{index:06d}.bin"
        (output / name).write_bytes(raw)
        parts.append({"index": index, "offset": offset, "path": name,
                      "bytes": len(raw), "sha256": sha(raw)})
    external = {"version": VERSION, "archiveFormat": "ZIP_DEFLATE",
                "archiveBytes": len(whole), "archiveSha256": sha(whole),
                "manifestSha256": sha(manifest_bytes), "partBytes": PART_BYTES,
                "parts": parts, "files": inventory, "declaration": declaration}
    (output / "parts.json").write_bytes(canonical(external) + b"\n")
    return external


def restore(package: Path, destination: Path, expected_manifest_sha256: str) -> dict:
    """Restore only after externally anchored manifest/parts/member validation.

    expected_manifest_sha256 is a caller's trusted commitment. It is deliberately
    not read from inside the untrusted package it is supposed to authenticate.
    """
    raw_manifest = (package / "parts.json").read_bytes()
    if sha(raw_manifest) != expected_manifest_sha256:
        raise ValueError("external package manifest anchor differs")
    manifest = json.loads(raw_manifest)
    if canonical(manifest) + b"\n" != raw_manifest or manifest["version"] != VERSION:
        raise ValueError("package manifest is not canonical")
    if set(manifest) != {"version", "archiveFormat", "archiveBytes", "archiveSha256",
                         "manifestSha256", "partBytes", "parts", "files", "declaration"}:
        raise ValueError("package manifest keys differ")
    if manifest["archiveFormat"] != "ZIP_DEFLATE" or type(manifest["partBytes"]) is not int or manifest["partBytes"] != PART_BYTES:
        raise ValueError("unsupported transport")
    if not manifest["parts"] or not manifest["files"]:
        raise ValueError("empty package")
    whole = bytearray()
    for index, row in enumerate(manifest["parts"]):
        if set(row) != {"index", "offset", "path", "bytes", "sha256"}:
            raise ValueError("part keys differ")
        if type(row["index"]) is not int or row["index"] != index or type(row["offset"]) is not int or row["offset"] != len(whole):
            raise ValueError("part order or offset differs")
        if row["path"] != f"part-{index:06d}.bin":
            raise ValueError("part path differs")
        raw = (package / row["path"]).read_bytes()
        if type(row["bytes"]) is not int or not 1 <= row["bytes"] <= PART_BYTES:
            raise ValueError("part width differs")
        if index + 1 < len(manifest["parts"]) and row["bytes"] != PART_BYTES:
            raise ValueError("short nonfinal part")
        if len(raw) != row["bytes"] or sha(raw) != row["sha256"]:
            raise ValueError("part bytes differ")
        whole.extend(raw)
    if type(manifest["archiveBytes"]) is not int or len(whole) != manifest["archiveBytes"] or sha(whole) != manifest["archiveSha256"]:
        raise ValueError("complete archive differs")
    import io
    with zipfile.ZipFile(io.BytesIO(whole)) as archive:
        members = archive.infolist()
        names = [safe_name(m.filename) for m in members]
        if len({n.casefold() for n in names}) != len(names) or names != sorted(names):
            raise ValueError("duplicate, aliased or unordered ZIP members")
        expected = {"PACKAGE.json": {"bytes": None, "sha256": manifest["manifestSha256"]}}
        paths = []
        for row in manifest["files"]:
            if set(row) != {"path", "bytes", "sha256"} or type(row["bytes"]) is not int or row["bytes"] < 0:
                raise ValueError("file inventory shape differs")
            name = safe_name(row["path"])
            paths.append(name)
            if name in expected:
                raise ValueError("duplicate inventory member")
            expected[name] = row
        if paths != sorted(paths) or len({n.casefold() for n in paths}) != len(paths) or set(names) != set(expected):
            raise ValueError("complete file inventory differs")
        retained = {}
        for member in members:
            if member.is_dir() or stat.S_ISLNK(member.external_attr >> 16) or member.flag_bits & 1:
                raise ValueError("unsupported ZIP member")
            row = expected[member.filename]
            if row["bytes"] is not None and member.file_size != row["bytes"]:
                raise ValueError("ZIP declared size differs")
            raw = archive.read(member)
            if sha(raw) != row["sha256"]:
                raise ValueError("ZIP original file differs")
            retained[member.filename] = raw
        internal = {"version": VERSION, "declaration": manifest["declaration"], "files": manifest["files"]}
        if retained["PACKAGE.json"] != canonical(internal):
            raise ValueError("inner and outer package meaning differs")
    destination.mkdir(parents=True, exist_ok=False)
    for name, raw in retained.items():
        path = destination / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(raw)
    return manifest


def build_native_tree(chrome: Path, version: str, python_zip: Path, destination: Path) -> dict:
    """Copy exact installed engine build and pinned portable toolchain, not user data."""
    if sha(python_zip.read_bytes()) != PYTHON_SHA256:
        raise ValueError("portable Python pin differs")
    if importlib.metadata.version("websockets") != "15.0.1":
        raise ValueError("capture transport version differs")
    if not version or any(c not in "0123456789." for c in version):
        raise ValueError("invalid engine directory")
    destination.mkdir(parents=True, exist_ok=False)
    engine = destination / "engine"
    engine.mkdir()
    shutil.copyfile(chrome / "chrome.exe", engine / "chrome.exe")
    shutil.copytree(chrome / version, engine / version)
    python = destination / "python"
    python.mkdir()
    with zipfile.ZipFile(python_zip) as archive:
        # Official pinned bytes, still enforce safe regular names before extraction.
        for item in archive.infolist():
            safe_name(item.filename)
            if item.is_dir() or stat.S_ISLNK(item.external_attr >> 16):
                raise ValueError("unexpected Python archive member")
            (python / item.filename).write_bytes(archive.read(item))
    distribution = importlib.metadata.distribution("websockets")
    for relative in distribution.files or []:
        name = relative.as_posix()
        if "__pycache__" in name or not (name.startswith("websockets/") or name.startswith("websockets-15.0.1.dist-info/")):
            continue
        safe_name(name)
        source = Path(distribution.locate_file(relative))
        target = python / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
    tool = destination / "tool"
    tool.mkdir()
    shutil.copyfile(Path(__file__).with_name("reference_capture.py"), tool / "reference_capture.py")
    note = (
        "This package retains an observed installed proprietary Google Chrome build for local "
        "preservation experiments. Its licenseBasis is undetermined. This note is not a license "
        "or permission instrument. Windows and its named loader/system-module prerequisites "
        "are external platform requirements; this package does not contain a self-contained OS. "
        "No installed user profile, browsing history or credentials are included. The complete "
        "version directory includes unused components; their presence is not capture support.\n"
    )
    (destination / "PRESERVATION_NOTE.txt").write_text(note, encoding="utf-8", newline="\n")
    return {"profile": "STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1", "engine": "Google Chrome",
            "engineVersion": version, "engineEntry": "engine/chrome.exe",
            "toolEntry": "tool/reference_capture.py", "runtimeEntry": "python/python.exe",
            "pythonVersion": "3.12.10", "pythonOriginalURL": PYTHON_URL,
            "pythonOriginalSha256": PYTHON_SHA256, "websocketsVersion": "15.0.1",
            "licenseBasis": "undetermined", "licenseInstrument": None,
            "licenseNote": "PRESERVATION_NOTE.txt", "operatingSystemIncluded": False,
            "platform": "Windows x86_64; exact loader/system-module requirements in capture evidence"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    build = sub.add_parser("native")
    build.add_argument("--chrome", type=Path, required=True)
    build.add_argument("--version", required=True)
    build.add_argument("--python-zip", type=Path, required=True)
    build.add_argument("--output", type=Path, required=True)
    unpack = sub.add_parser("restore")
    unpack.add_argument("--package", type=Path, required=True)
    unpack.add_argument("--output", type=Path, required=True)
    unpack.add_argument("--manifest-sha256", required=True)
    args = parser.parse_args()
    if args.command == "native":
        with tempfile.TemporaryDirectory(prefix="stream-native-package-") as directory:
            root = Path(directory) / "runtime"
            declaration = build_native_tree(args.chrome, args.version, args.python_zip, root)
            result = package_tree(root, args.output, declaration)
    else:
        result = restore(args.package, args.output, args.manifest_sha256)
    print(json.dumps({"parts": len(result["parts"]), "files": len(result["files"]),
                      "archiveBytes": result["archiveBytes"], "archiveSha256": result["archiveSha256"]}))


if __name__ == "__main__":
    main()
