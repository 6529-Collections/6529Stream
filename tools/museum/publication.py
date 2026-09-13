"""Prospective native document metadata; no registration or chain admission."""

import argparse
from dataclasses import dataclass
from hashlib import sha256
from pathlib import Path
import re
import sys

from .canonical import MuseumError, dumps, hex_bytes, keccak256, schema_id


CHUNK_BYTES = 8192
MAX_CHUNKS = 64
MAX_DOCUMENT_BYTES = CHUNK_BYTES * MAX_CHUNKS
KINDS = {"SCHEMA": 0, "CANONICALIZATION": 1, "CATALOG": 2, "DEPENDENCY": 3}
ZERO = "0x" + "00" * 32


@dataclass(frozen=True)
class PublicationPlan:
    name: str
    kind: str
    canonicalization_id: str
    supersedes_id: str
    uri: str
    content: bytes

    def __post_init__(self):
        if not isinstance(self.name, str) or not re.fullmatch(r"[A-Za-z0-9_.-]{1,128}", self.name):
            raise MuseumError("invalid document name")
        if self.kind not in KINDS:
            raise MuseumError("invalid document kind")
        if hex_bytes(self.canonicalization_id, 32) == bytes(32):
            raise MuseumError("missing canonicalization definition")
        hex_bytes(self.supersedes_id, 32)
        try:
            uri_bytes = self.uri.encode("utf-8")
        except (AttributeError, UnicodeError) as exc:
            raise MuseumError("invalid document URI") from exc
        if len(uri_bytes) > 2048:
            raise MuseumError("document URI byte limit")
        if type(self.content) is not bytes or not 1 <= len(self.content) <= MAX_DOCUMENT_BYTES:
            raise MuseumError("logical document byte limit")

    @property
    def chunks(self) -> tuple[bytes, ...]:
        return tuple(self.content[i:i + CHUNK_BYTES] for i in range(0, len(self.content), CHUNK_BYTES))

    def metadata(self) -> dict:
        return {
            "mode": "prospective_unregistered",
            "documentId": schema_id(self.name),
            "specification": {
                "name": self.name, "kind": str(KINDS[self.kind]),
                "contentHash": keccak256(self.content),
                "canonicalizationId": self.canonicalization_id,
                "supersedesId": self.supersedes_id, "uri": self.uri,
                "totalBytes": str(len(self.content)),
            },
            "chunkHashes": [keccak256(chunk) for chunk in self.chunks],
            "chunkByteLengths": [str(len(chunk)) for chunk in self.chunks],
            "transportSha256": "0x" + sha256(self.content).hexdigest(),
            "claims": {"registered": False, "canonicalizationAdmitted": False,
                       "governanceAuthorized": False},
        }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--name", required=True)
    parser.add_argument("--kind", choices=KINDS, required=True)
    parser.add_argument("--canonicalization-id", required=True)
    parser.add_argument("--supersedes-id", default=ZERO)
    parser.add_argument("--uri", default="")
    args = parser.parse_args()
    # Read one extra byte to reject over-limit local input without unbounded allocation.
    with args.source.open("rb") as file:
        content = file.read(MAX_DOCUMENT_BYTES + 1)
    plan = PublicationPlan(args.name, args.kind, args.canonicalization_id,
                           args.supersedes_id, args.uri, content)
    sys.stdout.buffer.write(dumps(plan.metadata()) + b"\n")


if __name__ == "__main__":
    main()
