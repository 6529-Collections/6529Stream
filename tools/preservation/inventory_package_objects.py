"""Reconstruct every declared uncompressed package member as a distinct object.

The caller supplies the original complete ordered inventory and whole-ZIP SHA256
anchor. This offline check proves local ZIP membership and byte correspondence;
it does not upload bytes or establish archival receipt/fixity signer authority.
Empty members retain their path and exact empty digest as explicit applicability.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import stat
import tempfile
import zipfile
from pathlib import Path

from tools.preservation.reference_archive import inspect
from tools.preservation.reference_package import canonical, safe_name


def member_abi(members: list[dict]) -> str:
    """Solidity (string,uint64,bytes32,bytes32,bytes32,bytes,bytes)[] witness.

    This is a test/transport encoding of every row, not an authenticated object.
    """
    def word(number):
        return number.to_bytes(32, "big")
    def dynamic(raw):
        return word(len(raw)) + raw + bytes((-len(raw)) % 32)
    tuples = []
    for member in members:
        path = dynamic(member["path"].encode("ascii"))
        first = dynamic(bytes.fromhex(member.get("firstDataPath", "0x")[2:]))
        last = dynamic(bytes.fromhex(member.get("lastDataPath", "0x")[2:]))
        content = member.get("contentHash", "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470")
        root = member.get("arweaveDataRoot", "0x" + "00" * 32)
        head = (word(224) + word(int(member["byteSize"])) + bytes.fromhex(content[2:])
                + bytes.fromhex(member["sha256Digest"][2:]) + bytes.fromhex(root[2:])
                + word(224 + len(path)) + word(224 + len(path) + len(first)))
        tuples.append(head + path + first + last)
    offset = 32 * len(tuples)
    offsets = []
    for value in tuples:
        offsets.append(word(offset)); offset += len(value)
    return "0x" + (word(32) + word(len(tuples)) + b"".join(offsets) + b"".join(tuples)).hex()


def reconstruct(archive_path: Path, declared: list[dict], expected_zip_sha256: str) -> dict:
    if not re.fullmatch(r"[0-9a-f]{64}", expected_zip_sha256):
        raise ValueError("whole archive SHA256 anchor")
    before = archive_path.stat()
    with archive_path.open("rb") as stream:
        actual_zip_sha = hashlib.file_digest(stream, "sha256").hexdigest()
    if actual_zip_sha != expected_zip_sha256:
        raise ValueError("whole archive differs")
    if not isinstance(declared, list) or not declared:
        raise ValueError("complete member inventory required")
    names = []
    for row in declared:
        if not isinstance(row, dict) or set(row) != {"path", "byteSize", "sha256Digest"}:
            raise ValueError("member shape")
        names.append(safe_name(row["path"]))
        if (not isinstance(row["byteSize"], str)
                or not re.fullmatch(r"0|[1-9][0-9]*", row["byteSize"])
                or int(row["byteSize"]) >= 2**64
                or not isinstance(row["sha256Digest"], str)
                or not re.fullmatch(r"0x[0-9a-f]{64}", row["sha256Digest"])):
            raise ValueError("member identity")
    if names != sorted(names) or len({n.casefold() for n in names}) != len(names):
        raise ValueError("member order or alias")
    result = []
    with zipfile.ZipFile(archive_path) as archive, tempfile.TemporaryDirectory() as temporary:
        members = archive.infolist()
        if [m.filename for m in members] != names:
            raise ValueError("complete ordered ZIP membership differs")
        # ZIP names are never used as local output paths.
        path = Path(temporary) / "member.bin"
        for index, (member, row) in enumerate(zip(members, declared)):
            if member.is_dir() or stat.S_ISLNK(member.external_attr >> 16) or member.flag_bits & 1:
                raise ValueError("unsupported ZIP member")
            raw = archive.read(member)
            if (len(raw) != int(row["byteSize"])
                    or "0x" + hashlib.sha256(raw).hexdigest() != row["sha256Digest"]):
                raise ValueError("original member bytes differ")
            identity = {"index": index, **row, "kind": "EMPTY_PACKAGE_MEMBER" if not raw else "EXTERNAL_REFERENCE"}
            if raw:
                path.write_bytes(raw)
                observed = inspect(path)
                identity.update(contentHash="0x" + observed["keccak256"],
                                arweaveDataRoot="0x" + observed["arweaveDataRoot"],
                                firstDataPath="0x" + observed["native"]["firstPath"],
                                lastDataPath="0x" + observed["native"]["lastPath"],
                                nativeChunkCount=observed["native"]["chunkCount"])
            result.append(identity)
    after = archive_path.stat()
    if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
        raise ValueError("archive changed during reconstruction")
    return {"version": "STREAM_PRESERVATION_PACKAGE_OBJECTS_V1",
            "archiveSha256": expected_zip_sha256, "archiveBytes": str(before.st_size),
            "inventorySha256": hashlib.sha256(canonical(declared)).hexdigest(),
            "memberCount": len(result), "members": result, "membersABI": member_abi(result),
            "storageInclusionEstablished": False, "receiptAuthorityEstablished": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--inventory", type=Path, required=True)
    parser.add_argument("--expected-zip-sha256", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    value = reconstruct(args.archive, json.loads(args.inventory.read_bytes()), args.expected_zip_sha256)
    args.output.write_bytes(canonical(value) + b"\n")
    print(json.dumps({"members": value["memberCount"], "empty": sum(m["kind"] == "EMPTY_PACKAGE_MEMBER" for m in value["members"]),
                      "archiveBytes": value["archiveBytes"], "archiveSha256": value["archiveSha256"]}))


if __name__ == "__main__":
    main()
