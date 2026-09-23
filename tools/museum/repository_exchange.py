"""Offline export and exact historical import of externally pinned OCFL bags."""
from dataclasses import dataclass
from pathlib import Path
from tempfile import TemporaryDirectory
import ctypes
import os
import re
import sys

from .bagit import (Bag, MAX_BYTES, MAX_FILES, MAX_MANIFEST, _hash, read_tree,
                    verify_bag, verify_bag_files, write_tree)
from .canonical import MuseumError, dumps, loads
from .ocfl import ObjectVersion, _bag_for_state, build_version, verify_object_files

# Bound logical replay as well as the existing physical OCFL object bounds.
MAX_REPLAY_BYTES = 4 * MAX_BYTES
MAX_REPLAY_FILES = 4 * MAX_FILES
MODES = frozenset(("stream_bagit_package", "stream_bagit_hydrated_package",
                   "stream_museum_dossier_bagit_package"))


@dataclass(frozen=True)
class Version:
    version: str
    bag: Bag
    summary: dict


@dataclass(frozen=True)
class Inspection:
    object: ObjectVersion
    versions: tuple[Version, ...]
    report: dict


def _qualification():
    return {"exactSuppliedBytes": True, "declaredSemanticReplay": True,
            "networkFetch": False, "archivedCodeExecuted": False,
            "currentConformance": False, "sourceAuthorityProven": False,
            "fullDossierConformance": False, "institutionalIngest": False}


def _version(name, bag, metadata):
    value = loads(bag.manifest, maximum=MAX_MANIFEST)
    if value["mode"] not in MODES or value["selfContainment"] != "self_contained":
        raise MuseumError("exchange requires a supported self-contained bag")
    description = value["input"]
    summary = {"version": name, "created": metadata["created"], "message": metadata["message"],
               "bagManifestHash": bag.manifest_hash, "bagMode": value["mode"],
               "profileHash": value["profileHash"], "selfContainment": value["selfContainment"],
               "bundleKind": description["bundleKind"], "sourceMode": description["sourceMode"],
               "externalIdentifier": description.get("externalIdentifier", description.get("citation")),
               "declaredSemanticPackageCount": len(description["semanticPackages"]),
               "bagFiles": len(bag.files), "bagBytes": sum(len(raw) for _, raw in bag.files)}
    return Version(name, bag, summary)


def _budget(versions):
    if (sum(v.summary["bagBytes"] for v in versions) > MAX_REPLAY_BYTES
            or sum(v.summary["bagFiles"] for v in versions) > MAX_REPLAY_FILES):
        raise MuseumError("exchange logical replay bound")


def _replay(bag):
    # Snapshot verified bytes, never reread the caller's mutable source during replay.
    # Each version gets its own disposable tree: no cumulative disk amplification.
    with TemporaryDirectory(prefix="stream-exchange-replay-") as temporary:
        directory = Path(temporary) / "bag"
        write_tree(bag.files, directory)
        checked = verify_bag(directory, bag.manifest_hash)
        if checked != bag:
            raise MuseumError("semantic replay changed original bag")


def _inspection(obj, versions):
    inventory = loads(obj.inventory, maximum=MAX_MANIFEST)
    versions = tuple(versions)
    _budget(versions)
    return Inspection(obj, versions,
        {"mode": "stream_repository_exchange_inspection", "version": "1",
         "inventoryHash": obj.inventory_hash, "objectId": inventory["id"], "head": inventory["head"],
         "versions": [v.summary for v in versions], "qualification": _qualification()})


def inspect_object(directory, inventory_hash):
    """Check full physical history, then replay every declared semantic package offline."""
    _hash(inventory_hash)
    obj = verify_object_files(read_tree(directory), inventory_hash)
    inventory = loads(obj.inventory, maximum=MAX_MANIFEST)
    files = dict(obj.files)
    versions = []
    for number in range(1, len(inventory["versions"]) + 1):
        name = "v" + str(number)
        metadata = inventory["versions"][name]
        bag, _ = _bag_for_state(files, inventory, metadata["state"])
        versions.append(_version(name, bag, metadata))
        _budget(versions)
    seen = set()
    for version in versions:
        if version.bag.manifest_hash not in seen:
            _replay(version.bag)
            seen.add(version.bag.manifest_hash)
    return _inspection(obj, versions)


def _destination(output, sources):
    root = Path(output).absolute()
    for path in (root, *root.parents):
        if path.is_symlink() or path.is_junction():
            raise MuseumError("exchange output cannot traverse a link or junction")
    if root.exists():
        raise MuseumError("exchange output must be a new directory")
    if not root.parent.is_dir():
        raise MuseumError("exchange output parent must already exist")
    resolved = root.resolve()
    for source in sources:
        original = Path(source).resolve()
        if resolved.is_relative_to(original) or original.is_relative_to(resolved):
            raise MuseumError("exchange output overlaps an input directory")
    return root


def _rename_new(source, destination):
    """Publish a directory atomically without replacing even an empty destination."""
    if os.name == "nt":
        # Windows rename fails if the destination already exists.
        os.rename(source, destination)
        return
    if sys.platform.startswith("linux"):
        # POSIX rename alone can replace an existing empty directory. Require
        # Linux RENAME_NOREPLACE rather than a check-then-rename fallback.
        library = ctypes.CDLL(None, use_errno=True)
        rename = getattr(library, "renameat2", None)
        if rename is not None:
            rename.argtypes = (ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint)
            rename.restype = ctypes.c_int
            if rename(-100, os.fsencode(source), -100, os.fsencode(destination), 1) == 0:
                return
            error = ctypes.get_errno()
            raise OSError(error, os.strerror(error), str(destination))
    raise MuseumError("atomic no-replace publication requires Windows or Linux renameat2")


def _publish(files, output, sources):
    root = _destination(output, sources)
    # Same-filesystem staging makes the final directory rename atomic. No
    # user-visible output exists until all writes and readback checks succeed.
    with TemporaryDirectory(prefix=".stream-exchange-", dir=root.parent) as temporary:
        staged = Path(temporary) / "result"
        write_tree(files, staged)
        if read_tree(staged) != dict(files):
            raise MuseumError("exchange staged-byte verification differs")
        _destination(root, sources)
        _rename_new(staged, root)


def export_bag(bag_directory, bag_manifest_hash, output, *, created, message,
               previous=None, previous_inventory_hash=None):
    """Export a pinned complete bag as a new immutable OCFL object tree."""
    if (previous is None) != (previous_inventory_hash is None):
        raise MuseumError("previous path and external inventory hash must be paired")
    sources = [bag_directory] + ([] if previous is None else [previous])
    _destination(output, sources)
    _hash(bag_manifest_hash)
    bag = verify_bag_files(read_tree(bag_directory), bag_manifest_hash)
    current = _version("v1", bag, {"created": created, "message": message})
    _budget((current,))
    prior = None if previous is None else inspect_object(previous, previous_inventory_hash)
    versions = [] if prior is None else list(prior.versions)
    current = _version("v" + str(len(versions) + 1), bag, {"created": created, "message": message})
    _budget([*versions, current])
    _replay(bag)
    obj = build_version(bag, created=created, message=message,
                        previous=None if prior is None else prior.object,
                        previous_inventory_hash=previous_inventory_hash)
    result = _inspection(obj, [*versions, current])
    _publish(obj.files, output, sources)
    return result


def import_version(directory, inventory_hash, version, bag_manifest_hash, output):
    """Restore one explicitly selected historical bag, preserving every original byte."""
    _destination(output, [directory])
    if not isinstance(version, str) or not re.fullmatch(r"v[1-9][0-9]*", version):
        raise MuseumError("explicit canonical version vN required; no latest/head alias")
    _hash(bag_manifest_hash)
    inspection = inspect_object(directory, inventory_hash)
    selected = next((row for row in inspection.versions if row.version == version), None)
    if selected is None:
        raise MuseumError("selected version is absent")
    if selected.bag.manifest_hash != bag_manifest_hash:
        raise MuseumError("selected bag external manifest pin differs")
    _publish(selected.bag.files, output, [directory])
    return {"mode": "stream_repository_exchange_import", "version": "1",
            "inventoryHash": inspection.object.inventory_hash,
            "objectId": inspection.report["objectId"], "objectHead": inspection.report["head"],
            "selectedVersion": version, "bagManifestHash": bag_manifest_hash,
            "selected": selected.summary, "qualification": _qualification()}


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    export = commands.add_parser("export")
    export.add_argument("bag_directory", type=Path); export.add_argument("output", type=Path)
    export.add_argument("--bag-manifest-hash", required=True)
    export.add_argument("--created", required=True); export.add_argument("--message", required=True)
    export.add_argument("--previous", type=Path); export.add_argument("--previous-inventory-hash")
    restore = commands.add_parser("import")
    restore.add_argument("directory", type=Path); restore.add_argument("output", type=Path)
    restore.add_argument("--inventory-hash", required=True); restore.add_argument("--version", required=True)
    restore.add_argument("--bag-manifest-hash", required=True)
    inspect = commands.add_parser("inspect")
    inspect.add_argument("directory", type=Path); inspect.add_argument("--inventory-hash", required=True)
    args = vars(parser.parse_args())
    command = args.pop("command")
    try:
        if command == "export":
            result = export_bag(**args).report
        elif command == "import":
            result = import_version(**args)
        else:
            result = inspect_object(**args).report
    except (MuseumError, OSError, KeyError, TypeError, ValueError) as exc:
        parser.exit(1, str(exc) + "\n")
    print(dumps(result).decode("utf-8"))


if __name__ == "__main__":
    main()
