"""Whole-file fixity and native Arweave data-root reconstruction, without upload.

The native root is a separate commitment from flat SHA256/Keccak. Matching all
three after retrieval is an observation for a named fixity signer, not an
Ethereum hash computation, storage receipt, or Arweave consensus proof.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

MAX_CHUNK = 256 * 1024
MIN_CHUNK = 32 * 1024
UPSTREAM_COMMIT = "af2073ae0025c6d68535f1dcea3d7d94962ace4f"
UPSTREAM_SHA256 = "19c033264b8bf29c000ae98a90a5d09b46579aaca0a460a8ca70ee73e2ed80cd"


def _hash(raw: bytes) -> bytes:
    return hashlib.sha256(raw).digest()


def _note(value: int) -> bytes:
    return value.to_bytes(32, "big")


def native_tree(path: Path, _observe=None) -> dict:
    """Pinned arweave-js chunking, including its final zero leaf at exact multiples.

    That zero leaf enters the root but is not an uploadable payload chunk. The
    complete ordered nonempty leaves and first/last payload proofs are retained.
    """
    size = path.stat().st_size
    if not 0 < size < 2**64:
        raise ValueError("external object must have a nonzero uint64 byte size")
    leaves = []
    with path.open("rb") as stream:
        cursor = 0
        while size - cursor >= MAX_CHUNK:
            length = MAX_CHUNK
            following = size - cursor - length
            if 0 < following < MIN_CHUNK:
                length = (size - cursor + 1) // 2
            raw = stream.read(length)
            if len(raw) != length:
                raise ValueError("file changed during native reconstruction")
            if _observe is not None:
                _observe(raw)
            cursor += length
            digest = _hash(raw)
            leaves.append({"digest": digest, "start": cursor - length, "end": cursor,
                           "id": _hash(_hash(digest) + _hash(_note(cursor)))})
        raw = stream.read()
        if len(raw) != size - cursor:
            raise ValueError("file changed during native reconstruction")
        if _observe is not None:
            _observe(raw)
        digest = _hash(raw)
        leaves.append({"digest": digest, "start": cursor, "end": size,
                       "id": _hash(_hash(digest) + _hash(_note(size)))})
    layer = leaves.copy()
    while len(layer) > 1:
        following = []
        for index in range(0, len(layer), 2):
            left = layer[index]
            if index + 1 == len(layer):
                following.append(left)
                continue
            right = layer[index + 1]
            following.append({"left": left, "right": right, "end": right["end"],
                              "split": left["end"],
                              "id": _hash(_hash(left["id"]) + _hash(right["id"]) + _hash(_note(left["end"])))})
        layer = following
    root = layer[0]
    proofs = []
    def visit(node, prefix=b""):
        if "left" not in node:
            if node["start"] != node["end"]:
                proofs.append({"start": node["start"], "end": node["end"],
                               "sha256": node["digest"].hex(),
                               "path": (prefix + node["digest"] + _note(node["end"])).hex()})
            return
        prefix += node["left"]["id"] + node["right"]["id"] + _note(node["split"])
        visit(node["left"], prefix)
        visit(node["right"], prefix)
    visit(root)
    return {"dataRoot": root["id"].hex(), "dataSize": str(size),
            "chunkCount": len(proofs), "hasFinalZeroLeaf": leaves[-1]["start"] == leaves[-1]["end"],
            "chunks": proofs, "firstPath": proofs[0]["path"], "lastPath": proofs[-1]["path"]}


def inspect(path: Path) -> dict:
    from Crypto.Hash import keccak
    before = path.stat()
    flat_sha = hashlib.sha256()
    flat_keccak = keccak.new(digest_bits=256)
    size = 0
    def observed(raw):
        nonlocal size
        size += len(raw)
        flat_sha.update(raw)
        flat_keccak.update(raw)
    # Both flat digests and every native leaf consume the exact same read bytes.
    native = native_tree(path, observed)
    after = path.stat()
    if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns) or size != before.st_size:
        raise ValueError("object changed during whole-file fixity")
    return {"profile": "STREAM_EXTERNAL_OBJECT_FIXITY_V1", "byteSize": str(size),
            "sha256": flat_sha.hexdigest(), "keccak256": flat_keccak.hexdigest(),
            "arweaveDataRoot": native["dataRoot"], "native": native,
            "upstreamCommit": UPSTREAM_COMMIT, "upstreamSourceSha256": UPSTREAM_SHA256,
            "storageInclusionEstablished": False, "receiptAuthorityEstablished": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--object", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    value = inspect(args.object)
    args.output.write_text(json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
    print(json.dumps({k: value[k] for k in ("byteSize", "sha256", "keccak256", "arweaveDataRoot")}))


if __name__ == "__main__":
    main()
