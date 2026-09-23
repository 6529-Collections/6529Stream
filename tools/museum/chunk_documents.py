"""Create deterministic archive chunks from already captured local bytes."""

from hashlib import sha256
from pathlib import Path

from .canonical import dumps
from .dependencies import Limits, chunk_carrier


def write_document(destination: Path, data: bytes, provenance: dict, limits=Limits()) -> dict:
    digest = "0x" + sha256(data).hexdigest()
    chunks = []
    for index, offset in enumerate(range(0, len(data), limits.chunk_bytes)):
        part = data[offset:offset + limits.chunk_bytes]
        part_hash = "0x" + sha256(part).hexdigest()
        path = "chunks/" + digest[2:] + "/" + str(index).zfill(6) + ".bin"
        target = destination / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(part)
        chunk_carrier(part, digest, str(index), limits.carrier_bytes)
        chunks.append({"path": path, "byteLength": str(len(part)), "sha256": part_hash})
    return dict(provenance, byteLength=str(len(data)), sha256=digest, chunks=chunks)
