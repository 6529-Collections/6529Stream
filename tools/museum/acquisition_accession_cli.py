"""Read-only ACCESSION capture, pinned offline composition and verification.

Only an explicitly named process environment variable supplies an RPC endpoint.
Public disclosure is required before reading inputs or inspecting destinations.
"""
import argparse
import os
from pathlib import Path
import re

from . import acquisition_accession as acquisition
from .bagit import MAX_BYTES, read_tree
from .canonical import dumps, hex_bytes, keccak256, loads
from .independent_wire import require
from .public_history_rpc import (MAX_TRANSCRIPT, PROFILE as RPC_PROFILE,
    PublicReplayTransport, PublicRpcTransport)
from .repository_exchange import _destination, _publish as atomic_publish

ANCHOR_LIMITS = {"owner": 524288, "ownership": 65536}
MAX_PINS, MAX_SELECTION = 4096, 4096
MAX_DOCUMENT_BYTES, MAX_DOCUMENT_TOTAL = 1048576, 16777216
DOCUMENT_NAME = re.compile(r"[0-9a-f]{64}\.bin")


def _unlinked(path):
    path = Path(path).absolute()
    require(not any(p.is_symlink() or (hasattr(p, "is_junction") and p.is_junction()) for p in (path, *path.parents)),
        "accession input cannot traverse a link or junction")
    return path


def _read(path, maximum):
    path = _unlinked(path)
    require(path.is_file() and 0 < path.stat().st_size <= maximum, "accession input file bound/type")
    with path.open("rb") as stream:
        raw = stream.read(maximum + 1)
    require(0 < len(raw) <= maximum, "accession input file byte bound")
    return raw


def _flat(directory, *, names=None, maximum):
    """Validate a bounded flat inventory before opening any member's bytes."""
    root = _unlinked(directory)
    require(root.is_dir(), "accession input directory required")
    found = {}
    with os.scandir(root) as entries:
        for entry in entries:
            require(len(found) < maximum, "accession input file count bound")
            path = Path(entry.path)
            require(not entry.is_symlink() and not (hasattr(path, "is_junction") and path.is_junction())
                and entry.is_file(follow_symlinks=False),
                "accession input requires flat regular files without links")
            require(entry.name.casefold() not in {name.casefold() for name in found},
                "accession input case alias")
            require(entry.name in names if names is not None else DOCUMENT_NAME.fullmatch(entry.name) is not None,
                "accession input filename differs")
            found[entry.name] = path
    if names is not None:
        require(set(found) == names, "accession exact source triplet required")
    return found


def read_documents(directory):
    """Read only caller-declared public document inputs, never remote references."""
    if directory is None:
        return {}
    paths = _flat(directory, maximum=acquisition.MAX_DOCUMENTS)
    require(sum(p.stat().st_size for p in paths.values()) <= MAX_DOCUMENT_TOTAL,
        "accession public document aggregate bound")
    documents, total = {}, 0
    for name, path in sorted(paths.items()):
        raw = _read(path, min(MAX_DOCUMENT_BYTES, MAX_DOCUMENT_TOTAL - total))
        total += len(raw)
        documents["0x" + name[:-4]] = raw
    acquisition._documents(documents)
    return documents


def _triplet(directory, kind):
    paths = _flat(directory, names=acquisition.INPUTS, maximum=3)
    limits = {"anchor.json": ANCHOR_LIMITS[kind], "transcript.json": MAX_TRANSCRIPT,
        "snapshot.json": MAX_BYTES}
    require(sum(p.stat().st_size for p in paths.values()) <= MAX_BYTES, "accession source aggregate bound")
    files, total = {}, 0
    for name, path in sorted(paths.items()):
        files[name] = _read(path, min(limits[name], MAX_BYTES - total))
        total += len(files[name])
    return files


def _pins(raw, kind):
    value = loads(raw, maximum=MAX_PINS, canonical=True)
    require(type(value) is dict and set(value) == acquisition.PIN_NAMES
        and value["profileHash"] == acquisition._sources()[kind][2]
        and value["provenance"] in ("trusted_rpc", "synthetic_fixture"), "accession closed source pins differ")
    for name in acquisition.PIN_NAMES - {"provenance"}:
        require(any(hex_bytes(value[name], 32)), "accession source pin is zero")
    return value


def _anchor(kind, raw, expected_hash, profile_hash):
    constructor, _, expected_profile = acquisition._sources()[kind]
    require(type(raw) is bytes and 0 < len(raw) <= ANCHOR_LIMITS[kind]
        and any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
        "accession external anchor pin/bound differs")
    require(profile_hash == expected_profile, "accession external source profile differs")
    empty = dumps({"version": 2, "profile": RPC_PROFILE, "calls": []})
    return constructor(raw, PublicReplayTransport(empty, keccak256(empty)), provenance="trusted_rpc")


def _preflight(owner_raw, owner_hash, owner_profile, ownership_raw, ownership_hash, ownership_profile,
               selection_raw, selection_hash):
    owner = _anchor("owner", owner_raw, owner_hash, owner_profile)
    ownership = _anchor("ownership", ownership_raw, ownership_hash, ownership_profile)
    # Empty replay readers perform no RPC: validate both original anchors and
    # their shared identity/runtime before loading an endpoint.
    acquisition._join(owner, ownership)
    require(type(selection_raw) is bytes and 0 < len(selection_raw) <= MAX_SELECTION
        and any(hex_bytes(selection_hash, 32)) and keccak256(selection_raw) == selection_hash,
        "accession external selection pin/bound differs")
    selection = loads(selection_raw, maximum=MAX_SELECTION, canonical=True)
    require(type(selection) is dict and set(selection) == {"profile", "host", "tokenId", "accessionRecordHash"}
        and selection["profile"] == acquisition.PROFILE and selection["host"] == owner.a["host"]
        and selection["tokenId"] == owner.a["tokenId"] and any(hex_bytes(selection["accessionRecordHash"], 32)),
        "accession explicit original selection differs")


def _retained(kind, raw, transport):
    source = acquisition._sources()[kind][0](raw, transport, provenance="trusted_rpc")
    snapshot = source.snapshot()
    files = {"anchor.json": raw, "snapshot.json": snapshot, "transcript.json": source.transcript()}
    pins = {name + "Hash": keccak256(files[name + ".json"]) for name in ("anchor", "transcript", "snapshot")}
    pins.update(profileHash=acquisition._sources()[kind][2], provenance="trusted_rpc")
    return files, pins


def _verified(result):
    rebuilt = acquisition.verify(dict(result.files), result.manifest_hash)
    require(rebuilt.files == result.files, "accession pre-publication replay differs")
    return result


def capture(owner_raw, owner_hash, owner_profile, ownership_raw, ownership_hash, ownership_profile,
            selection_raw, selection_hash, transport, *, disclosure, documents=None):
    """Two actual public readers share one read-only transport; replay before return."""
    acquisition._public(disclosure)
    _preflight(owner_raw, owner_hash, owner_profile, ownership_raw, ownership_hash, ownership_profile,
        selection_raw, selection_hash)
    documents = {} if documents is None else documents
    acquisition._documents(documents)
    require(type(transport) is PublicRpcTransport, "accession capture requires explicit public read-only transport")
    owner_files, owner_pins = _retained("owner", owner_raw, transport)
    ownership_files, ownership_pins = _retained("ownership", ownership_raw, transport)
    return _verified(acquisition.compose(owner_files, owner_pins, ownership_files, ownership_pins,
        selection_raw, selection_hash, disclosure=disclosure, documents=documents))


def capture_paths(*, owner_anchor, owner_anchor_hash, owner_source_profile_hash,
                  ownership_anchor, ownership_anchor_hash, ownership_source_profile_hash,
                  selection, selection_hash, rpc_env, disclosure, output, documents=None):
    acquisition._public(disclosure)
    require(type(rpc_env) is str and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]{0,127}", rpc_env) is not None,
        "accession RPC environment variable name invalid")
    inputs = [owner_anchor, ownership_anchor, selection] + ([] if documents is None else [documents])
    _destination(output, inputs)
    owner_raw = _read(owner_anchor, ANCHOR_LIMITS["owner"])
    ownership_raw = _read(ownership_anchor, ANCHOR_LIMITS["ownership"])
    selection_raw = _read(selection, MAX_SELECTION)
    _preflight(owner_raw, owner_anchor_hash, owner_source_profile_hash, ownership_raw, ownership_anchor_hash,
        ownership_source_profile_hash, selection_raw, selection_hash)
    retained = read_documents(documents)
    endpoint = os.environ.get(rpc_env)
    require(endpoint is not None and endpoint != "", "accession RPC environment variable unavailable")
    result = capture(owner_raw, owner_anchor_hash, owner_source_profile_hash, ownership_raw, ownership_anchor_hash,
        ownership_source_profile_hash, selection_raw, selection_hash, PublicRpcTransport(endpoint),
        disclosure=disclosure, documents=retained)
    atomic_publish(dict(result.files), output, inputs)
    return result


def compose_paths(*, owner_source, owner_pins, ownership_source, ownership_pins,
                  selection, selection_hash, disclosure, output, documents=None):
    acquisition._public(disclosure)
    inputs = [owner_source, owner_pins, ownership_source, ownership_pins, selection]
    if documents is not None:
        inputs.append(documents)
    _destination(output, inputs)
    owner_pin = _pins(_read(owner_pins, MAX_PINS), "owner")
    ownership_pin = _pins(_read(ownership_pins, MAX_PINS), "ownership")
    owner_files, ownership_files = _triplet(owner_source, "owner"), _triplet(ownership_source, "ownership")
    require(sum(len(v) for f in (owner_files, ownership_files) for v in f.values()) <= MAX_BYTES,
        "accession combined source byte bound")
    selected = _read(selection, MAX_SELECTION)
    _preflight(owner_files["anchor.json"], owner_pin["anchorHash"], owner_pin["profileHash"],
        ownership_files["anchor.json"], ownership_pin["anchorHash"], ownership_pin["profileHash"], selected, selection_hash)
    result = _verified(acquisition.compose(owner_files, owner_pin, ownership_files, ownership_pin,
        selected, selection_hash, disclosure=disclosure, documents=read_documents(documents)))
    atomic_publish(dict(result.files), output, inputs)
    return result


def verify_path(directory, manifest_hash):
    _unlinked(directory)
    return acquisition.verify(read_tree(directory), manifest_hash)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    live = sub.add_parser("capture")
    for kind in ("owner", "ownership"):
        live.add_argument("--" + kind + "-anchor", type=Path, required=True)
        live.add_argument("--" + kind + "-anchor-hash", required=True)
        live.add_argument("--" + kind + "-source-profile-hash", required=True)
    live.add_argument("--rpc-env", required=True)
    offline = sub.add_parser("compose")
    for kind in ("owner", "ownership"):
        offline.add_argument("--" + kind + "-source", type=Path, required=True)
        offline.add_argument("--" + kind + "-pins", type=Path, required=True)
    for command in (live, offline):
        command.add_argument("--selection", type=Path, required=True)
        command.add_argument("--selection-hash", required=True)
        command.add_argument("--disclosure", required=True)
        command.add_argument("--output", type=Path, required=True)
        command.add_argument("--documents", type=Path)
    check = sub.add_parser("verify")
    check.add_argument("directory", type=Path)
    check.add_argument("--manifest-hash", required=True)
    sub.add_parser("profiles")
    options = vars(parser.parse_args(argv)); command = options.pop("command")
    if command == "profiles":
        print(dumps({"acquisitionProfileHash": acquisition.PROFILE_HASH,
            "sources": {kind: row[2] for kind, row in acquisition._sources().items()}}).decode("utf-8"))
        return
    if command == "verify":
        result = verify_path(**options)
    else:
        result = (capture_paths if command == "capture" else compose_paths)(**options)
    print(dumps({"manifestHash": result.manifest_hash, "files": str(len(result.files)),
        "provenance": result.report["provenance"], "providerLogCompletenessTrusted": True,
        "sourceConsensusVerified": False, "actualChainAcceptance": False}).decode("utf-8"))


if __name__ == "__main__":
    main()
