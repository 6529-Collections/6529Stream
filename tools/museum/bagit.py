"""Deterministic public BagIt transport. Fixity never grants source authority."""
from dataclasses import dataclass
from datetime import date
from hashlib import sha256
from pathlib import Path
import re

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .package import MAX_BYTES, MAX_FILES, MAX_MANIFEST, _package_path

DECLARATION = b"BagIt-Version: 1.0\nTag-File-Character-Encoding: UTF-8\n"
PROFILE = {"id": "STREAM_BAGIT_PROFILE_V1", "version": "1",
    "status": "prospective_unregistered_implementation_profile",
    "bagIt": "1.0", "encoding": "UTF-8", "manifestAlgorithms": ["sha256", "keccak256"],
    "tagManifestAlgorithm": "sha256", "limits": {"files": MAX_FILES, "bytes": MAX_BYTES,
    "descriptionBytes": MAX_MANIFEST, "pathBytes": 1024},
    "sourceAdmission": "Explicit input commitments; transport verifies bytes, never record authority, disclosure rights or completeness of an operator-selected inventory.",
    "fetch": "Only non-render-critical ipfs/ar references with committed hashes, size and two externally admitted archive evidence files; never fetched by this tool.",
    "ocfl": "OCFL 1.1; unchanged canonical work identity; immutable complete versions retain exact bag payload and tags.",
    "claims": {"registered": False, "institutionalIngest": False, "fullDossierConformance": False}}
PROFILE_BYTES = dumps(PROFILE)
PROFILE_HASH = keccak256(PROFILE_BYTES)
ZERO = "0x" + "00" * 32


def _keys(value, expected, label):
    if not isinstance(value, dict) or set(value) != set(expected.split()):
        raise MuseumError("invalid " + label + " fields")


def _hash(value):
    if not any(hex_bytes(value, 32)):
        raise MuseumError("zero packaging commitment")
    return value


def _text(value, limit=1024):
    if (not isinstance(value, str) or not value or len(value.encode("utf-8")) > limit
            or value.strip() != value or any(ord(c) < 32 or ord(c) == 127 for c in value)):
        raise MuseumError("invalid packaging text")
    return value


def _path(name):
    _text(name)
    if (len(name.encode("utf-8")) > 1024 or any(c in name for c in '%<>"|?*')
            or name.startswith("/") or "\\" in name or ":" in name):
        raise MuseumError("nonportable packaging path")
    _package_path(Path.cwd(), name)
    return name


def _paths(names):
    folded, prefixes = set(), {}
    for name in names:
        _path(name)
        key = name.casefold()
        if key in folded:
            raise MuseumError("duplicate packaging path")
        folded.add(key)
        parts = name.split("/")
        for index in range(1, len(parts)):
            spelling = "/".join(parts[:index]); canonical = spelling.casefold()
            if canonical in prefixes and prefixes[canonical] != spelling:
                raise MuseumError("inconsistent shared-directory casing")
            prefixes[canonical] = spelling
    for name in folded:
        if any("/".join(name.split("/")[:i]) in folded for i in range(1, len(name.split("/")))):
            raise MuseumError("packaging file/directory collision")


def _citation(value):
    _text(value)
    match = re.fullmatch(r"eip155:([1-9][0-9]*)/erc721:(0x[0-9a-f]{40})/([1-9][0-9]*)@(fin|snap|chain):(0x[0-9a-f]{64})", value)
    if not match or not any(hex_bytes(match[2], 20)):
        raise MuseumError("typed canonical record-state citation required")
    uint(match[1]); uint(match[3]); _hash(match[5])
    return value.split("@", 1)[0]


def _description(raw):
    d = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    _keys(d, "mode version bundleKind sourceMode disclosure citation baggingDate bundleManifest schema recordChainHeads tool predecessor payloads semanticPackages", "packaging input")
    if (d["mode"] != "stream_bagit_input" or d["version"] != "1"
            or d["bundleKind"] not in ("OBJECT_DOSSIER_V1", "STATE_EXPORT")
            or d["sourceMode"] not in ("synthetic_fixture", "externally_admitted_records")
            or d["disclosure"] != "public"):
        raise MuseumError("unsupported or restricted packaging input")
    _citation(d["citation"])
    if not isinstance(d["baggingDate"], str) or not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", d["baggingDate"]):
        raise MuseumError("invalid bagging date")
    try:
        date.fromisoformat(d["baggingDate"])
    except ValueError as exc:
        raise MuseumError("invalid bagging date") from exc
    for name, fields in (("bundleManifest", "path hash"), ("schema", "path id hash")):
        _keys(d[name], fields, name)
        _path(d[name]["path"]); _hash(d[name]["hash"])
    _hash(d["schema"]["id"])
    _keys(d["tool"], "name version sourceHash", "tool")
    _text(d["tool"]["name"]); _text(d["tool"]["version"]); _hash(d["tool"]["sourceHash"])
    if d["predecessor"] != ZERO:
        _hash(d["predecessor"])
    if not isinstance(d["recordChainHeads"], list) or len(d["recordChainHeads"]) > 512:
        raise MuseumError("chain-head count limit")
    scopes = []
    for row in d["recordChainHeads"]:
        _keys(row, "scope head", "chain head")
        scopes.append(_text(row["scope"])); _hash(row["head"])
    if scopes != sorted(set(scopes)):
        raise MuseumError("noncanonical or duplicate chain-head scope")
    if not isinstance(d["payloads"], list) or not 1 <= len(d["payloads"]) <= MAX_FILES - 8:
        raise MuseumError("payload count limit")
    names, total = [], 0
    for row in d["payloads"]:
        _keys(row, "path bytes sha256 keccak256 renderCritical delivery", "payload")
        names.append(row["path"]); total += uint(row["bytes"], 64)
        _hash(row["sha256"]); _hash(row["keccak256"])
        if type(row["renderCritical"]) is not bool:
            raise MuseumError("explicit render-critical classification required")
        delivery = row["delivery"]
        if delivery == {"kind": "embedded"}:
            continue
        _keys(delivery, "kind uri archiveEvidence", "fetch delivery")
        if delivery["kind"] != "fetch" or row["renderCritical"]:
            raise MuseumError("render-critical bytes must be embedded")
        # Canonical content-addressed URI validation is shared with the IIIF adapter.
        from .iiif_uri import content_uri_facts
        content_uri_facts(delivery["uri"], row["sha256"][2:])
        evidence = delivery["archiveEvidence"]
        if not isinstance(evidence, list) or len(evidence) != 2:
            raise MuseumError("fetch requires two distinct archive-family evidence references")
        families = []
        for proof in evidence:
            _keys(proof, "family path hash", "archive evidence")
            families.append(proof["family"]); _path(proof["path"]); _hash(proof["hash"])
        if set(families) != {"onchain", "permanent_external"}:
            raise MuseumError("unsupported archive evidence families")
    _paths(names)
    if names != sorted(names) or total > MAX_BYTES:
        raise MuseumError("noncanonical payload order or byte bound")
    rows = {row["path"]: row for row in d["payloads"]}
    for name in ("bundleManifest", "schema"):
        spec = d[name]; row = rows.get(spec["path"])
        if row is None or row["delivery"] != {"kind": "embedded"} or row["keccak256"] != spec["hash"]:
            raise MuseumError("bundle/schema bytes must be embedded and exact")
    for row in rows.values():
        for proof in row["delivery"].get("archiveEvidence", []):
            selected = rows.get(proof["path"])
            if (selected is None or selected["delivery"] != {"kind": "embedded"}
                    or selected["keccak256"] != proof["hash"]):
                raise MuseumError("archive evidence bytes must be embedded and exact")
    if not isinstance(d["semanticPackages"], list) or len(d["semanticPackages"]) > 16:
        raise MuseumError("semantic package count limit")
    prefixes = []
    for package in d["semanticPackages"]:
        _keys(package, "prefix manifestHash", "semantic package")
        prefix = _path(package["prefix"]); prefixes.append(prefix)
        _hash(package["manifestHash"])
        row = rows.get(prefix + "/manifest.json")
        if row is None or row["keccak256"] != package["manifestHash"]:
            raise MuseumError("semantic manifest not retained")
        if any(r["delivery"] != {"kind": "embedded"} for p, r in rows.items() if p.startswith(prefix + "/")):
            raise MuseumError("semantic interpretation must be embedded")
    _paths(prefixes)
    if any(a != b and b.startswith(a + "/") for a in prefixes for b in prefixes):
        raise MuseumError("nested semantic package overlap")
    return d


@dataclass(frozen=True)
class Bag:
    files: tuple[tuple[str, bytes], ...]
    manifest: bytes

    @property
    def manifest_hash(self):
        return keccak256(self.manifest)


def _lines(rows, algorithm):
    return "".join(row[algorithm][2:] + "  data/" + row["path"] + "\n" for row in rows).encode("utf-8")


def build_bag(description_bytes, payloads):
    """Preserve exact caller-supplied bytes; no chain lookup, downloads or authority inference."""
    d = _description(description_bytes)
    payloads = dict(payloads)
    rows = d["payloads"]
    expected = {r["path"] for r in rows if r["delivery"]["kind"] == "embedded"}
    if set(payloads) != expected:
        raise MuseumError("embedded payload inventory differs")
    for row in rows:
        if row["path"] not in payloads:
            continue
        raw = payloads[row["path"]]
        if (type(raw) is not bytes or len(raw) != uint(row["bytes"], 64)
                or "0x" + sha256(raw).hexdigest() != row["sha256"] or keccak256(raw) != row["keccak256"]):
            raise MuseumError("payload fixity mismatch")
    fetch = [r for r in rows if r["delivery"]["kind"] == "fetch"]
    status = "fetch_dependent" if fetch else "self_contained"
    manifest = dumps({"mode": "stream_bagit_package", "version": "1", "profileHash": PROFILE_HASH,
        "selfContainment": status, "input": d,
        "qualification": {"sourceAuthorityVerified": False, "inventoryCompletenessVerified": False,
                          "archivalAuthorityVerified": False, "institutionalIngest": False}})
    if len(manifest) > MAX_MANIFEST:
        raise MuseumError("bag manifest byte bound")
    info = {"External-Identifier": d["citation"], "Bagging-Date": d["baggingDate"],
            "Payload-Oxum": str(sum(uint(r["bytes"], 64) for r in rows)) + "." + str(len(rows)),
            "Stream-Schema-Id": d["schema"]["id"], "Stream-Schema-Hash": d["schema"]["hash"],
            "Stream-Self-Containment": status}
    files = {"data/" + name: raw for name, raw in payloads.items()}
    files.update({"bagit.txt": DECLARATION, "bag-info.txt": "".join(k + ": " + v + "\n" for k, v in info.items()).encode(),
        "stream-manifest.json": manifest, "stream-bagit-profile.json": PROFILE_BYTES,
        "manifest-sha256.txt": _lines(rows, "sha256"), "manifest-keccak256.txt": _lines(rows, "keccak256")})
    if fetch:
        files["fetch.txt"] = "".join(r["delivery"]["uri"] + " " + r["bytes"] + " data/" + r["path"] + "\n" for r in fetch).encode()
    files["tagmanifest-sha256.txt"] = "".join(sha256(raw).hexdigest() + "  " + name + "\n"
        for name, raw in sorted(files.items()) if not name.startswith("data/")).encode()
    if sum(map(len, files.values())) > MAX_BYTES or len(files) > MAX_FILES:
        raise MuseumError("bag aggregate byte/file bound")
    return Bag(tuple(sorted(files.items())), manifest)


def verify_bag_files(files, expected_manifest_hash):
    files = dict(files)
    if len(files) > MAX_FILES or sum(map(len, files.values())) > MAX_BYTES:
        raise MuseumError("bag aggregate byte/file bound")
    _paths(files)
    raw = files.get("stream-manifest.json", b"")
    if keccak256(raw) != expected_manifest_hash:
        raise MuseumError("external bag manifest mismatch")
    value = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    if not isinstance(value, dict) or "input" not in value:
        raise MuseumError("bag manifest missing input")
    if value.get("mode") == "stream_bagit_hydrated_package":
        from .hydration import verify_hydrated_bag_files
        return verify_hydrated_bag_files(files, expected_manifest_hash)
    rebuilt = build_bag(dumps(value["input"]), {name[5:]: content for name, content in files.items() if name.startswith("data/")})
    if dict(rebuilt.files) != files or rebuilt.manifest != raw:
        raise MuseumError("noncanonical, missing or altered bag content/tags")
    return rebuilt


def read_tree(directory):
    root = Path(directory)
    if root.is_symlink() or (hasattr(root, "is_junction") and root.is_junction()) or not root.is_dir():
        raise MuseumError("package directory required")
    files, total, directories = {}, 0, set()
    for path in root.rglob("*"):
        if path.is_symlink() or (hasattr(path, "is_junction") and path.is_junction()):
            raise MuseumError("package links are unsupported")
        if not path.is_file():
            if not path.is_dir():
                raise MuseumError("package special file unsupported")
            directories.add(path.relative_to(root).as_posix())
            continue
        name = path.relative_to(root).as_posix(); _path(name)
        total += path.stat().st_size
        if total > MAX_BYTES or len(files) >= MAX_FILES:
            raise MuseumError("package aggregate bound")
        files[name] = path.read_bytes()
        if sum(map(len, files.values())) > MAX_BYTES:
            raise MuseumError("package changed beyond byte bound during read")
    _paths(files)
    expected_directories = {"/".join(name.split("/")[:i]) for name in files for i in range(1, len(name.split("/")))}
    if directories != expected_directories:
        raise MuseumError("undeclared empty package directory")
    return files


def write_tree(files, directory):
    files = dict(files); _paths(files)
    if len(files) > MAX_FILES or sum(map(len, files.values())) > MAX_BYTES:
        raise MuseumError("package aggregate bound")
    root = Path(directory)
    # Parent links cannot redirect output, and an existing directory is never reused.
    for parent in (root, *root.parents):
        if parent.is_symlink() or (hasattr(parent, "is_junction") and parent.is_junction()):
            raise MuseumError("output parent links are unsupported")
    root.mkdir(parents=True, exist_ok=False)
    for name, raw in sorted(files.items()):
        path = _package_path(root, name)
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("xb") as handle:
            handle.write(raw)


def _verify_semantics(d, payload_directory):
    for package in d["semanticPackages"]:
        from .package_v2 import verify_package
        original = verify_package(Path(payload_directory) / package["prefix"], package["manifestHash"])
        source_mode = loads(original.manifest, maximum=MAX_MANIFEST)["mode"]
        if source_mode.startswith("synthetic") and d["sourceMode"] != "synthetic_fixture":
            raise MuseumError("synthetic semantic package cannot become recorded")


def verify_bag(directory, expected_manifest_hash):
    bag = verify_bag_files(read_tree(directory), expected_manifest_hash)
    _verify_semantics(loads(bag.manifest, maximum=MAX_MANIFEST)["input"], Path(directory) / "data")
    return bag


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    build = commands.add_parser("build")
    build.add_argument("description", type=Path); build.add_argument("payload_directory", type=Path)
    build.add_argument("output", type=Path); build.add_argument("--description-hash", required=True)
    verify = commands.add_parser("verify")
    verify.add_argument("directory", type=Path); verify.add_argument("--manifest-hash", required=True)
    args = parser.parse_args()
    try:
        if args.command == "build":
            if args.description.stat().st_size > MAX_MANIFEST:
                raise MuseumError("description byte bound")
            raw = args.description.read_bytes()
            if keccak256(raw) != args.description_hash:
                raise MuseumError("external description hash mismatch")
            bag = build_bag(raw, read_tree(args.payload_directory))
            _verify_semantics(loads(bag.manifest, maximum=MAX_MANIFEST)["input"], args.payload_directory)
            write_tree(bag.files, args.output)
            verify_bag_files(read_tree(args.output), bag.manifest_hash)
        else:
            bag = verify_bag(args.directory, args.manifest_hash)
    except (MuseumError, OSError, KeyError, TypeError, ValueError) as exc:
        parser.exit(1, str(exc) + "\n")
    value = loads(bag.manifest, maximum=MAX_MANIFEST)
    print(dumps({"manifestHash": bag.manifest_hash, "selfContainment": value["selfContainment"],
        "bagComplete": value["selfContainment"] == "self_contained",
        "scope": "Declared bytes/tags and selected nested semantic replay; source authority and institutional acceptance are separate."}).decode())


if __name__ == "__main__":
    main()
