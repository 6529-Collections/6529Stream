"""Immutable OCFL 1.1 object versions preserving exact complete Stream bags."""
from copy import deepcopy
from dataclasses import dataclass
from datetime import datetime
from hashlib import sha256, sha512
import re

from .canonical import MuseumError, dumps, keccak256, loads
from .bagit import MAX_BYTES, MAX_FILES, MAX_MANIFEST, ZERO, _citation, _keys, _paths, _text
from .bagit import read_tree, verify_bag_files, write_tree

DECLARATION_NAME = "0=ocfl_object_1.1"
DECLARATION = b"ocfl_object_1.1\n"
INVENTORY_TYPE = "https://ocfl.io/1.1/spec/#inventory"
MAX_VERSIONS = 64


def _time(value):
    if not isinstance(value, str) or not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z", value):
        raise MuseumError("canonical UTC version timestamp required")
    try:
        return datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError as exc:
        raise MuseumError("invalid version timestamp") from exc


def _sidecar(raw):
    return (sha256(raw).hexdigest() + "  inventory.json\n").encode()


@dataclass(frozen=True)
class ObjectVersion:
    files: tuple[tuple[str, bytes], ...]
    inventory: bytes

    @property
    def inventory_hash(self):
        return keccak256(self.inventory)


def _bag_for_state(files, inventory, state):
    bag = {}
    for digest, logical in state.items():
        raw = files[inventory["manifest"][digest][0]]
        for name in logical:
            if not name.startswith("bag/"):
                raise MuseumError("unsupported OCFL logical namespace")
            bag[name[4:]] = raw
    manifest = bag.get("stream-manifest.json", b"")
    verified = verify_bag_files(bag, keccak256(manifest))
    value = loads(verified.manifest, maximum=MAX_MANIFEST)
    if value["selfContainment"] != "self_contained":
        raise MuseumError("OCFL requires complete embedded bags; hydrate fetch payloads first")
    return verified, value["input"]


def build_version(bag, *, created, message, previous=None, previous_inventory_hash=None):
    """Return a new object tree; never overwrite an old version or live storage root."""
    bag = verify_bag_files(bag.files, bag.manifest_hash)
    b = loads(bag.manifest, maximum=MAX_MANIFEST)
    if b["selfContainment"] != "self_contained":
        raise MuseumError("OCFL does not ingest an incomplete fetch-dependent bag")
    d = b["input"]; identity = _citation(d["citation"])
    _time(created); _text(message, 4096)
    files = {DECLARATION_NAME: DECLARATION}
    inventory = {"id": identity, "type": INVENTORY_TYPE, "digestAlgorithm": "sha256",
                 "head": "v1", "contentDirectory": "content", "manifest": {}, "versions": {}, "fixity": {"sha512": {}}}
    number = 1
    if previous is None:
        if previous_inventory_hash is not None or d["predecessor"] != ZERO:
            raise MuseumError("initial OCFL version cannot invent a predecessor")
    else:
        if previous_inventory_hash is None:
            raise MuseumError("external predecessor inventory hash required")
        prior = verify_object_files(previous.files, previous_inventory_hash)
        files = dict(prior.files)
        inventory = deepcopy(loads(prior.inventory, maximum=MAX_MANIFEST))
        if inventory["id"] != identity:
            raise MuseumError("OCFL successor changed canonical work identity")
        previous_bag, old = _bag_for_state(files, inventory, inventory["versions"][inventory["head"]]["state"])
        if (d["predecessor"] != previous_bag.manifest_hash or d["bundleKind"] != old["bundleKind"]
                or _time(created) <= _time(inventory["versions"][inventory["head"]]["created"])):
            raise MuseumError("OCFL version lineage or chronology mismatch")
        number = int(inventory["head"][1:]) + 1
    if number > MAX_VERSIONS:
        raise MuseumError("OCFL version bound")
    head = "v" + str(number); state = {}
    for name, raw in bag.files:
        digest = sha256(raw).hexdigest()
        state.setdefault(digest, []).append("bag/" + name)
        if digest not in inventory["manifest"]:
            path = head + "/content/" + digest
            files[path] = raw
            inventory["manifest"][digest] = [path]
            inventory["fixity"]["sha512"].setdefault(sha512(raw).hexdigest(), []).append(path)
    inventory["versions"][head] = {"created": created, "message": message, "state": state}
    inventory["head"] = head
    raw = dumps(inventory)
    if len(raw) > MAX_MANIFEST:
        raise MuseumError("OCFL inventory byte bound")
    files.update({"inventory.json": raw, "inventory.json.sha256": _sidecar(raw),
                  head + "/inventory.json": raw, head + "/inventory.json.sha256": _sidecar(raw)})
    if len(files) > MAX_FILES or sum(map(len, files.values())) > MAX_BYTES:
        raise MuseumError("OCFL aggregate bound")
    result = ObjectVersion(tuple(sorted(files.items())), raw)
    verify_object_files(result.files, result.inventory_hash)
    return result


def verify_object_files(files, expected_inventory_hash):
    files = dict(files); _paths(files)
    if len(files) > MAX_FILES or sum(map(len, files.values())) > MAX_BYTES:
        raise MuseumError("OCFL aggregate bound")
    raw = files.get("inventory.json", b"")
    if keccak256(raw) != expected_inventory_hash:
        raise MuseumError("external OCFL inventory mismatch")
    current = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    _keys(current, "id type digestAlgorithm head contentDirectory manifest versions fixity", "OCFL inventory")
    if (current["type"] != INVENTORY_TYPE or current["digestAlgorithm"] != "sha256"
            or current["contentDirectory"] != "content" or not isinstance(current["head"], str)
            or not re.fullmatch(r"v[1-9][0-9]*", current["head"])):
        raise MuseumError("unsupported OCFL profile")
    number = int(current["head"][1:])
    if not 1 <= number <= MAX_VERSIONS or set(current["versions"]) != {"v" + str(n) for n in range(1, number + 1)}:
        raise MuseumError("OCFL version sequence mismatch")
    expected = {DECLARATION_NAME, "inventory.json", "inventory.json.sha256"}
    if files.get(DECLARATION_NAME) != DECLARATION or files.get("inventory.json.sha256") != _sidecar(raw):
        raise MuseumError("OCFL declaration or root inventory sidecar mismatch")
    known_manifest, known_versions = {}, {}
    previous_bag = None; previous_input = None; previous_time = None
    for n in range(1, number + 1):
        head = "v" + str(n)
        expected.update({head + "/inventory.json", head + "/inventory.json.sha256"})
        version_raw = files.get(head + "/inventory.json", b"")
        if files.get(head + "/inventory.json.sha256") != _sidecar(version_raw):
            raise MuseumError("OCFL historical inventory sidecar mismatch")
        inv = loads(version_raw, maximum=MAX_MANIFEST, canonical=True)
        _keys(inv, "id type digestAlgorithm head contentDirectory manifest versions fixity", "historical OCFL inventory")
        for field in ("id", "type", "digestAlgorithm", "contentDirectory"):
            if inv[field] != current[field]:
                raise MuseumError("OCFL historical profile or identity changed")
        if inv["head"] != head or not isinstance(inv["manifest"], dict) or not isinstance(inv["versions"], dict):
            raise MuseumError("OCFL historical head mismatch")
        _keys(inv["fixity"], "sha512", "OCFL fixity")
        if not isinstance(inv["fixity"]["sha512"], dict):
            raise MuseumError("OCFL fixity must be a map")
        for digest, paths in inv["manifest"].items():
            if not re.fullmatch(r"[0-9a-f]{64}", digest) or not isinstance(paths, list) or len(paths) != 1:
                raise MuseumError("noncanonical OCFL content digest/path")
            path = paths[0]
            if not re.fullmatch(r"v[1-9][0-9]*/content/" + digest, path) or int(path.split('/')[0][1:]) > n:
                raise MuseumError("OCFL physical content outside its version")
            content = files.get(path)
            if content is None or sha256(content).hexdigest() != digest:
                raise MuseumError("OCFL content fixity mismatch")
            expected.add(path)
        for key, value in known_manifest.items():
            if inv["manifest"].get(key) != value:
                raise MuseumError("OCFL historical content mapping changed")
        fresh = {k: v for k, v in inv["manifest"].items() if k not in known_manifest}
        if any(not v[0].startswith(head + "/") for v in fresh.values()):
            raise MuseumError("OCFL newly listed content must belong to this version")
        fixity = {}
        for digest, paths in inv["manifest"].items():
            fixity.setdefault(sha512(files[paths[0]]).hexdigest(), []).append(paths[0])
        fixity = {k: sorted(v) for k, v in fixity.items()}
        if inv["fixity"]["sha512"] != fixity:
            raise MuseumError("OCFL supplementary fixity differs")
        if set(inv["versions"]) != set(known_versions) | {head}:
            raise MuseumError("OCFL historical version set differs")
        for key, value in known_versions.items():
            if inv["versions"][key] != value:
                raise MuseumError("OCFL prior version state rewritten")
        version = inv["versions"][head]
        _keys(version, "created message state", "OCFL version")
        observed = _time(version["created"]); _text(version["message"], 4096)
        if previous_time is not None and observed <= previous_time:
            raise MuseumError("OCFL version chronology is not increasing")
        if not isinstance(version["state"], dict) or not version["state"]:
            raise MuseumError("OCFL empty version state")
        logical = []
        for digest, names in version["state"].items():
            if digest not in inv["manifest"] or not isinstance(names, list) or not names or names != sorted(set(names)):
                raise MuseumError("OCFL state does not resolve uniquely")
            logical.extend(names)
        _paths(logical)
        if not set(fresh) <= set(version["state"]):
            raise MuseumError("OCFL unused new content")
        bag, d = _bag_for_state(files, inv, version["state"])
        if _citation(d["citation"]) != current["id"]:
            raise MuseumError("bag citation differs from OCFL identity")
        if d["predecessor"] != (ZERO if previous_bag is None else previous_bag.manifest_hash):
            raise MuseumError("OCFL bag predecessor mismatch")
        if previous_input is not None and d["bundleKind"] != previous_input["bundleKind"]:
            raise MuseumError("OCFL bundle family changed")
        known_manifest, known_versions = inv["manifest"], inv["versions"]
        previous_bag, previous_input, previous_time = bag, d, observed
    if version_raw != raw or set(files) != expected:
        raise MuseumError("OCFL root/head inventory or file inventory differs")
    return ObjectVersion(tuple(sorted(files.items())), raw)


def main():
    import argparse
    from pathlib import Path
    from .bagit import verify_bag
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    add = commands.add_parser("version")
    add.add_argument("bag", type=Path); add.add_argument("output", type=Path)
    add.add_argument("--bag-manifest-hash", required=True)
    add.add_argument("--created", required=True); add.add_argument("--message", required=True)
    add.add_argument("--previous", type=Path); add.add_argument("--previous-inventory-hash")
    verify = commands.add_parser("verify")
    verify.add_argument("directory", type=Path); verify.add_argument("--inventory-hash", required=True)
    args = parser.parse_args()
    try:
        if args.command == "version":
            if (args.previous is None) != (args.previous_inventory_hash is None):
                raise MuseumError("previous path and external inventory hash must be paired")
            previous = None if args.previous is None else verify_object_files(read_tree(args.previous), args.previous_inventory_hash)
            result = build_version(verify_bag(args.bag, args.bag_manifest_hash), created=args.created,
                                   message=args.message, previous=previous, previous_inventory_hash=args.previous_inventory_hash)
            write_tree(result.files, args.output)
        else:
            result = verify_object_files(read_tree(args.directory), args.inventory_hash)
    except (MuseumError, OSError, KeyError, TypeError, ValueError) as exc:
        parser.exit(1, str(exc) + "\n")
    print(result.inventory_hash, "OCFL byte/version verification; source authority and institutional acceptance remain external.")


if __name__ == "__main__":
    main()
