"""Network-free hydration of an exact externally pinned fetch-dependent Stream bag."""
from hashlib import sha256
from pathlib import Path

from .canonical import MuseumError, dumps, keccak256, loads, uint
from .bagit import Bag, DECLARATION, MAX_BYTES, MAX_FILES, MAX_MANIFEST, _description
from .bagit import _keys, _lines, _paths, read_tree, verify_bag, verify_bag_files, write_tree

SOURCE_PREFIX = "provenance/source-bag/"
SOURCE_SUFFIX = ".original"
PROFILE = {"id": "STREAM_BAGIT_HYDRATION_PROFILE_V1", "version": "1",
    "status": "prospective_unregistered_implementation_profile", "bagIt": "1.0",
    "input": "Original version1 Stream fetch-dependent bag plus the complete exact missing payload set, supplied locally.",
    "verification": "Original declared length, SHA-256 and keccak256 for every supplied payload. No URL resolution, retrieval claim or archival authority inference.",
    "provenance": "Every original tag byte is retained under provenance/source-bag with a .original suffix. The original fetch.txt and tagmanifest are inert provenance; there is no active root fetch.txt.",
    "limits": {"files": MAX_FILES, "bytes": MAX_BYTES, "manifestBytes": MAX_MANIFEST},
    "meaning": "Original schema, bundle, citation, source/disclosure mode, chain heads, tool and predecessor remain unchanged. Hydration changes transport availability only."}
PROFILE_BYTES = dumps(PROFILE)
PROFILE_HASH = keccak256(PROFILE_BYTES)


def hydrate_bag(original, supplied):
    """Pure deterministic byte verification. Filesystem verify_bag also replays nested semantics."""
    original = verify_bag_files(original.files, original.manifest_hash)
    before = loads(original.manifest, maximum=MAX_MANIFEST, canonical=True)
    if before.get("mode") != "stream_bagit_package" or before["selfContainment"] != "fetch_dependent":
        raise MuseumError("hydration requires the original version1 fetch-dependent bag")
    d = _description(dumps(before["input"]))
    supplied = dict(supplied); _paths(supplied)
    missing = {r["path"]: r for r in d["payloads"] if r["delivery"]["kind"] == "fetch"}
    if not missing or set(supplied) != set(missing):
        raise MuseumError("hydration requires the complete exact missing payload set")
    for name, raw in supplied.items():
        row = missing[name]
        if (type(raw) is not bytes or len(raw) != uint(row["bytes"], 64)
                or "0x" + sha256(raw).hexdigest() != row["sha256"] or keccak256(raw) != row["keccak256"]):
            raise MuseumError("hydrated payload does not match original commitments")
    files = {name: raw for name, raw in original.files if name.startswith("data/")}
    files.update({"data/" + name: raw for name, raw in supplied.items()})
    source_tags = {SOURCE_PREFIX + name + SOURCE_SUFFIX: raw for name, raw in original.files if not name.startswith("data/")}
    files.update(source_tags)
    manifest = dumps({"mode": "stream_bagit_hydrated_package", "version": "1",
        "profileHash": PROFILE_HASH, "sourceBagManifestHash": original.manifest_hash,
        "selfContainment": "self_contained", "input": d,
        "qualification": before["qualification"],
        "hydration": {"verifiedPayloads": sorted(missing), "bytesSuppliedLocally": True,
                      "networkRetrievalPerformed": False, "archivalAvailabilityEstablished": False}})
    if len(manifest) > MAX_MANIFEST:
        raise MuseumError("hydrated manifest byte bound")
    # Preserve the original exact metadata values; only the availability tag changes.
    info = dict(original.files)["bag-info.txt"].replace(b"Stream-Self-Containment: fetch_dependent\n",
                                                      b"Stream-Self-Containment: self_contained\n")
    files.update({"bagit.txt": DECLARATION, "bag-info.txt": info, "stream-manifest.json": manifest,
        "stream-hydration-profile.json": PROFILE_BYTES,
        "manifest-sha256.txt": _lines(d["payloads"], "sha256"),
        "manifest-keccak256.txt": _lines(d["payloads"], "keccak256")})
    files["tagmanifest-sha256.txt"] = "".join(sha256(raw).hexdigest() + "  " + name + "\n"
        for name, raw in sorted(files.items()) if not name.startswith("data/")).encode()
    if len(files) > MAX_FILES or sum(map(len, files.values())) > MAX_BYTES:
        raise MuseumError("hydrated bag aggregate bound")
    _paths(files)
    return Bag(tuple(sorted(files.items())), manifest)


def verify_hydrated_bag_files(files, expected_manifest_hash):
    files = dict(files)
    if len(files) > MAX_FILES or sum(map(len, files.values())) > MAX_BYTES:
        raise MuseumError("hydrated bag aggregate bound")
    _paths(files)
    raw = files.get("stream-manifest.json", b"")
    if keccak256(raw) != expected_manifest_hash:
        raise MuseumError("external hydrated manifest mismatch")
    m = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    _keys(m, "mode version profileHash sourceBagManifestHash selfContainment input qualification hydration", "hydration manifest")
    if m["mode"] != "stream_bagit_hydrated_package" or m["version"] != "1" or m["profileHash"] != PROFILE_HASH:
        raise MuseumError("unsupported hydration profile")
    d = _description(dumps(m["input"]))
    source_tags = {name: content for name, content in files.items() if name.startswith(SOURCE_PREFIX)}
    if any(not name.endswith(SOURCE_SUFFIX) for name in source_tags):
        raise MuseumError("hydration source tag name differs")
    old = {name[len(SOURCE_PREFIX):-len(SOURCE_SUFFIX)]: content for name, content in source_tags.items()}
    supplied = {}
    for row in d["payloads"]:
        name = "data/" + row["path"]
        if name not in files:
            raise MuseumError("hydrated bag payload missing")
        if row["delivery"]["kind"] == "embedded":
            old[name] = files[name]
        else:
            supplied[row["path"]] = files[name]
    original_raw = old.get("stream-manifest.json", b"")
    # Require the source profile before recursive dispatch; hydration chains are not admitted.
    original_value = loads(original_raw, maximum=MAX_MANIFEST, canonical=True)
    if not isinstance(original_value, dict) or original_value.get("mode") != "stream_bagit_package":
        raise MuseumError("hydration provenance must be an original version1 bag")
    original = verify_bag_files(old, m["sourceBagManifestHash"])
    rebuilt = hydrate_bag(original, supplied)
    if rebuilt.manifest != raw or dict(rebuilt.files) != files:
        raise MuseumError("hydration tags, provenance or payload inventory differs")
    return rebuilt


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("supplied", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--source-manifest-hash", required=True)
    args = parser.parse_args()
    try:
        original = verify_bag(args.source, args.source_manifest_hash)
        hydrated = hydrate_bag(original, read_tree(args.supplied))
        write_tree(hydrated.files, args.output)
        verify_bag_files(read_tree(args.output), hydrated.manifest_hash)
    except (MuseumError, OSError, KeyError, TypeError, ValueError) as exc:
        parser.exit(1, str(exc) + "\n")
    print(dumps({"manifestHash": hydrated.manifest_hash, "sourceBagManifestHash": original.manifest_hash,
        "selfContainment": "self_contained", "completeBag": True,
        "networkRetrievalPerformed": False, "sourceAuthorityVerified": False}).decode())


if __name__ == "__main__":
    main()
