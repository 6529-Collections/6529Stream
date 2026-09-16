"""Retain original local archive capture inputs and reconstruct them offline."""
import gzip
import hashlib
import io
from pathlib import Path
import tempfile

from .archive_evidence import verify_evidence
from .canonical import dumps, keccak256, loads
from .independent_wire import require
from .package import write_package
from .semantic_export import MANIFEST_PATH, build_export
from .typed_authority_fixture import REQUIRED as BASE_REQUIRED, OPTIONAL, rebuild as rebuild_authority

REQUIRED = (*BASE_REQUIRED, "archive-publication.json", "archive-grant.json", "archive-result.json")
MAX_BYTES = 64 * 1024 * 1024


def rebuild(files):
    anchor = loads(files["anchor.json"], maximum=524288, canonical=True)
    require(anchor["environment"] == "local_evm_fixture" and anchor["chainId"] == "31337",
        "retained archive fixture requires actual local capture scope")
    authority = rebuild_authority(files)
    with tempfile.TemporaryDirectory() as temporary:
        directory = Path(temporary) / "authority"; write_package(authority, directory)
        export = build_export(directory, authority.manifest_hash, disclosure="public")
    result = loads(files["archive-result.json"], maximum=65536, canonical=True)
    require(export.manifest_hash == result["exportManifestHash"], "retained archive export pin differs")
    manifest = dict(export.files)[MANIFEST_PATH]
    require(keccak256(manifest) == result["semanticManifestHash"], "retained semantic manifest pin differs")
    evidence = verify_evidence(files["archive-publication.json"], result["publicationEvidenceHash"], manifest,
        source_anchor_bytes=files["anchor.json"])
    require(evidence["recordHash"] == result["archiveRecordHash"], "retained archive record pin differs")
    grant = loads(files["archive-grant.json"], maximum=8388608, canonical=True)
    publication = loads(files["archive-publication.json"], maximum=8388608, canonical=True)
    require(all(grant[name] == publication[name] for name in ("recordType", "family", "authorizationMask",
        "authorizationClass", "authorizationClassName", "collectionId"))
        and grant["writer"] == publication["recorder"], "retained archive governance and receipt differ")
    return export, evidence


def retain(capture, destination):
    capture, destination = Path(capture), Path(destination)
    files, total = {}, 0
    for name in REQUIRED + OPTIONAL:
        path = capture / name
        if name in OPTIONAL and not path.exists(): continue
        size = path.stat().st_size; total += size
        require(size <= MAX_BYTES and total <= MAX_BYTES, "archive retained input bound")
        files[name] = path.read_bytes(); require(len(files[name]) == size, "archive input changed while reading")
    require(all(n in files for n in OPTIONAL) or all(n not in files for n in OPTIONAL), "archive publisher retention pair")
    export, evidence = rebuild(files)
    expanded = dumps({"files": {name: raw.hex() for name, raw in sorted(files.items())}})
    packed = gzip.compress(expanded, compresslevel=9, mtime=0)
    manifest = dumps({"version": "1", "mode": "retained_actual_local_archive_export_capture",
        "archiveSha256": hashlib.sha256(packed).hexdigest(), "expandedBytes": str(len(expanded)),
        "exportManifestHash": export.manifest_hash, "archiveRecordHash": evidence["recordHash"],
        "classification": "Actual local native Metadata/Safe ARCHIVE publication; externally pinned trusted-RPC evidence, not consensus proof.",
        "snapshotMode": loads(files["authority-result.json"])["snapshotMode"],
        "authorityPublisherAuthenticated": False, "qualifiedHumanReview": False,
        "files": [{"path": name, "byteLength": str(len(raw)), "keccak256": keccak256(raw)} for name, raw in sorted(files.items())]})
    destination.mkdir(parents=True, exist_ok=False)
    (destination / "inputs.json.gz").write_bytes(packed)
    (destination / "manifest.json").write_bytes(manifest)
    return keccak256(manifest)


def read(directory, manifest_hash):
    directory = Path(directory)
    manifest_path, archive_path = directory / "manifest.json", directory / "inputs.json.gz"
    require(manifest_path.stat().st_size <= 65536 and archive_path.stat().st_size <= MAX_BYTES, "archive fixture bound")
    raw = manifest_path.read_bytes(); require(keccak256(raw) == manifest_hash, "archive fixture external pin differs")
    manifest = loads(raw, maximum=65536, canonical=True); packed = archive_path.read_bytes()
    require(hashlib.sha256(packed).hexdigest() == manifest["archiveSha256"], "archive fixture packed pin differs")
    with gzip.GzipFile(fileobj=io.BytesIO(packed)) as stream: expanded = stream.read(MAX_BYTES * 2 + 1048576 + 1)
    require(len(expanded) == int(manifest["expandedBytes"]) and len(expanded) <= MAX_BYTES * 2 + 1048576, "archive fixture expanded bound")
    encoded = loads(expanded, maximum=MAX_BYTES * 2 + 1048576, canonical=True)["files"]
    require(set(REQUIRED) <= set(encoded) <= set(REQUIRED + OPTIONAL), "archive fixture exact file set")
    require(all(n in encoded for n in OPTIONAL) or all(n not in encoded for n in OPTIONAL), "archive fixture publisher retention pair")
    files = {name: bytes.fromhex(value) for name, value in encoded.items()}
    require(sum(map(len, files.values())) <= MAX_BYTES, "archive fixture decoded bound")
    require(manifest["files"] == [{"path": name, "byteLength": str(len(content)), "keccak256": keccak256(content)}
        for name, content in sorted(files.items())], "archive fixture original input commitments differ")
    return files, manifest


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__); sub = parser.add_subparsers(dest="command", required=True)
    pack = sub.add_parser("retain"); pack.add_argument("capture", type=Path); pack.add_argument("destination", type=Path)
    verify = sub.add_parser("verify"); verify.add_argument("directory", type=Path); verify.add_argument("--manifest-hash", required=True)
    args = parser.parse_args()
    if args.command == "retain": print(retain(args.capture, args.destination))
    else:
        files, manifest = read(args.directory, args.manifest_hash); export, evidence = rebuild(files)
        require(export.manifest_hash == manifest["exportManifestHash"] and evidence["recordHash"] == manifest["archiveRecordHash"], "archive fixture replay result differs")
        print(export.manifest_hash)


if __name__ == "__main__": main()
