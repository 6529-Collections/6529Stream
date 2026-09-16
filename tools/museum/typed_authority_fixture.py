"""Retain and replay bounded original typed-authority capture inputs offline."""
import gzip
import hashlib
import io
from pathlib import Path
import tempfile

from .authority import need
from .authority_package_v2 import build_authority_package
from .authority_v2 import PROFILE_HASH
from .canonical import dumps, keccak256, loads
from .package import write_package
from .package_recorded import INPUT_FILES, build_recorded_package

ROOT = Path(__file__).resolve().parents[2] / "schemas/museum"
REQUIRED = (*INPUT_FILES, "pins.json", "premis-plan.json", "iiif-plan.json", "lido-plan.json",
    "authority-requests.json", "authority-selection.json", "authority-snapshot.descriptor.json",
    "authority-snapshot.rdf.json", "authority-result.json", "native-inputs.json")
OPTIONAL = ("authority-publisher-response.json", "authority-publisher-response-evidence.json")
MAX_BYTES = 64 * 1024 * 1024


def rebuild(files):
    pins = loads(files["pins.json"], canonical=True)
    base_pins = {key: value for key, value in pins.items() if key != "package_manifest"}
    original = build_recorded_package({name: files[name] for name in INPUT_FILES}, root=ROOT, disclosure="public", **base_pins,
        premis_plan_bytes=files["premis-plan.json"], iiif_plan_bytes=files["iiif-plan.json"], lido_plan_bytes=files["lido-plan.json"])
    need(original.manifest_hash == pins["package_manifest"], "retained base package differs")
    requests = files["authority-requests.json"]; selection = files["authority-selection.json"]
    descriptor, snapshot = files["authority-snapshot.descriptor.json"], files["authority-snapshot.rdf.json"]
    # Read the exact logical snapshot path from the retained original assertion selection.
    from .recorded_projection import replay_source_bytes
    source = replay_source_bytes(ROOT, {name: files[name] for name in INPUT_FILES},
        **{name + "_hash": pins[name + "_hash"] for name in ("source", "publication", "interpretation", "profile")})
    policy = loads(selection, canonical=True)
    from .authority_v2 import _body
    path = _body(source.assertion(policy["sourceAuthoritySet"][0])[0])["alignment"]["snapshotRef"]["path"]
    with tempfile.TemporaryDirectory() as directory:
        base = Path(directory) / "source"; write_package(original, base)
        result = build_authority_package(base, original.manifest_hash, requests, selection,
            {path: (descriptor, snapshot, keccak256(descriptor))}, request_hash=keccak256(requests),
            selection_hash=keccak256(selection), profile_hash=PROFILE_HASH, disclosure="public")
    reported = loads(files["authority-result.json"], canonical=True)
    need(result.manifest_hash == reported["manifestHash"], "retained authority package differs")
    return result


def retain(capture, destination):
    capture, destination = Path(capture).resolve(), Path(destination).resolve()
    files = {}; total = 0
    for name in REQUIRED + OPTIONAL:
        path = capture / name
        if name in OPTIONAL and not path.exists(): continue
        size = path.stat().st_size; total += size
        need(size <= MAX_BYTES and total <= MAX_BYTES, "retained input bound")
        files[name] = path.read_bytes()
        need(len(files[name]) == size, "retained input changed while reading")
    need(all(name in files for name in OPTIONAL) or all(name not in files for name in OPTIONAL), "publisher retention pair incomplete")
    result = rebuild(files)
    raw = dumps({"files": {name: content.hex() for name, content in sorted(files.items())}})
    packed = gzip.compress(raw, compresslevel=9, mtime=0)
    manifest = dumps({"version": "1", "mode": "retained_actual_local_safe_typed_authority_capture",
        "archiveSha256": hashlib.sha256(packed).hexdigest(), "expandedBytes": str(len(raw)),
        "authorityManifestHash": result.manifest_hash,
        "snapshotMode": loads(files["authority-result.json"])["snapshotMode"],
        "sourceClassification": "Actual local EVM records on pinned native products and official Safe; externally anchored trusted-RPC evidence, no consensus proof.",
        "authorityPublisherAuthenticated": False, "qualifiedHumanReview": False,
        "files": [{"path": name, "byteLength": str(len(content)), "keccak256": keccak256(content)} for name, content in sorted(files.items())]})
    destination.mkdir(parents=True, exist_ok=False)
    (destination / "inputs.json.gz").write_bytes(packed)
    (destination / "manifest.json").write_bytes(manifest)
    return keccak256(manifest)


def read(directory, manifest_hash):
    directory = Path(directory)
    manifest_path = directory / "manifest.json"; archive_path = directory / "inputs.json.gz"
    need(manifest_path.stat().st_size <= 65536 and archive_path.stat().st_size <= MAX_BYTES, "retained archive bound")
    raw = manifest_path.read_bytes(); need(keccak256(raw) == manifest_hash, "retained fixture manifest pin differs")
    manifest = loads(raw, maximum=65536, canonical=True); packed = archive_path.read_bytes()
    need(hashlib.sha256(packed).hexdigest() == manifest["archiveSha256"], "retained fixture archive pin differs")
    with gzip.GzipFile(fileobj=io.BytesIO(packed)) as stream: expanded = stream.read(MAX_BYTES * 2 + 1048576 + 1)
    need(len(expanded) == int(manifest["expandedBytes"]) and len(expanded) <= MAX_BYTES * 2 + 1048576, "retained expanded bound")
    encoded = loads(expanded, maximum=MAX_BYTES * 2 + 1048576, canonical=True)["files"]
    need(set(REQUIRED) <= set(encoded) <= set(REQUIRED + OPTIONAL), "retained fixture exact file set")
    files = {name: bytes.fromhex(value) for name, value in encoded.items()}
    need(sum(map(len, files.values())) <= MAX_BYTES, "retained decoded bound")
    need(manifest["files"] == [{"path": name, "byteLength": str(len(content)), "keccak256": keccak256(content)}
        for name, content in sorted(files.items())], "retained input commitments differ")
    return files, manifest


def main():
    import argparse
    p = argparse.ArgumentParser(description=__doc__); sub = p.add_subparsers(dest="command", required=True)
    pack = sub.add_parser("retain"); pack.add_argument("capture", type=Path); pack.add_argument("destination", type=Path)
    verify = sub.add_parser("verify"); verify.add_argument("directory", type=Path); verify.add_argument("--manifest-hash", required=True)
    args = p.parse_args()
    if args.command == "retain": print(retain(args.capture, args.destination))
    else:
        files, manifest = read(args.directory, args.manifest_hash); result = rebuild(files)
        need(result.manifest_hash == manifest["authorityManifestHash"], "retained replay result differs")
        print(result.manifest_hash)


if __name__ == "__main__": main()
