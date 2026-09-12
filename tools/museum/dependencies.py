"""Bounded, content-addressed local documents. This module has no URL opener."""

from dataclasses import dataclass
from hashlib import sha256
from pathlib import Path, PurePosixPath

from .canonical import MuseumError, dumps, hex_bytes, uint


@dataclass(frozen=True)
class Limits:
    documents: int = 512
    chunks: int = 4096
    chunk_bytes: int = 8192
    carrier_bytes: int = 24575
    aggregate_bytes: int = 16 * 1024 * 1024
    dependency_depth: int = 8


def safe_path(root: Path, relative: str) -> Path:
    if not isinstance(relative, str) or not relative or "\\" in relative or ":" in relative:
        raise MuseumError("invalid archive path")
    parts = PurePosixPath(relative).parts
    if relative.startswith("/") or any(p in (".", "..") for p in relative.split("/")):
        raise MuseumError("archive path traversal")
    if any(not p or p.endswith((" ", ".")) for p in relative.split("/")):
        raise MuseumError("ambiguous archive path")
    result = root.joinpath(*parts).resolve()
    if not result.is_relative_to(root.resolve()):
        raise MuseumError("archive path escape")
    return result


class OfflineDocuments:
    def __init__(self, root: Path, index: dict, limits=Limits()):
        self._documents = {}
        rows = index.get("documents", [])
        if not rows or len(rows) > limits.documents:
            raise MuseumError("document count limit")
        chunks = sum(len(row.get("chunks", [])) for row in rows)
        if chunks > limits.chunks:
            raise MuseumError("chunk count limit")
        total = sum(uint(row["byteLength"], 64) for row in rows)
        chunk_total = sum(uint(chunk["byteLength"], 32) for row in rows for chunk in row["chunks"])
        if total > limits.aggregate_bytes or chunk_total > limits.aggregate_bytes:
            raise MuseumError("dependency byte limit")
        paths = set()
        edges = {}
        for row in rows:
            uri = row["sourceUri"]
            if uri in self._documents:
                raise MuseumError("duplicate dependency URI")
            if not row.get("revision") or not row.get("retrievedAt") or not row.get("mediaType"):
                raise MuseumError("missing dependency provenance")
            parts = []
            declared_size = uint(row["byteLength"], 64)
            if not row["chunks"]:
                raise MuseumError("empty dependency")
            for i, chunk in enumerate(row["chunks"]):
                path = chunk["path"]
                if path.casefold() in paths:
                    raise MuseumError("duplicate dependency path")
                paths.add(path.casefold())
                size = uint(chunk["byteLength"], 32)
                if size == 0 or size > limits.chunk_bytes:
                    raise MuseumError("chunk byte limit")
                if i < len(row["chunks"]) - 1 and size != limits.chunk_bytes:
                    raise MuseumError("noncanonical chunk partition")
                file = safe_path(root, path)
                if file.stat().st_size != size:
                    raise MuseumError("chunk size mismatch")
                content = file.read_bytes()
                if sha256(content).digest() != hex_bytes(chunk["sha256"], 32):
                    raise MuseumError("chunk hash mismatch")
                chunk_carrier(content, row["sha256"], str(i), limits.carrier_bytes)
                parts.append(content)
            content = b"".join(parts)
            if len(content) != declared_size or sha256(content).digest() != hex_bytes(row["sha256"], 32):
                raise MuseumError("document reconstruction mismatch")
            self._documents[uri] = content
            edges[uri] = row.get("dependencies", [])

        if sum(len(v) for v in edges.values()) > limits.chunks:
            raise MuseumError("dependency edge limit")
        memo = {}

        def visit(uri, stack):
            if uri not in edges:
                raise MuseumError("unresolved dependency")
            if uri in stack:
                raise MuseumError("cyclic dependency")
            if uri in memo:
                return memo[uri]
            if len(edges[uri]) != len(set(edges[uri])):
                raise MuseumError("duplicate dependency edge")
            depth = max((1 + visit(child, stack + (uri,)) for child in edges[uri]), default=0)
            if depth > limits.dependency_depth:
                raise MuseumError("dependency depth limit")
            memo[uri] = depth
            return depth

        for uri in edges:
            visit(uri, ())

    def load(self, uri: str) -> bytes:
        try:
            return self._documents[uri]
        except KeyError as exc:
            raise MuseumError("offline dependency unavailable") from exc

    def jsonld_loader(self, uri, options=None):
        """JSON-LD processor document-loader signature; never falls back online.

        Raw upstream context is not reserialized or restricted to Stream's
        string-only numeric fields: JSON-LD @version legitimately contains 1.1.
        """
        import json
        import math
        from .canonical import _pairs
        data = self.load(uri)
        try:
            def constant(_):
                raise MuseumError("nonfinite JSON-LD constant")

            document = json.loads(data.decode("utf-8"), object_pairs_hook=_pairs, parse_constant=constant)

            def validate(value, depth=0):
                if depth > 64:
                    raise MuseumError("JSON-LD nesting limit")
                if isinstance(value, str):
                    value.encode("utf-8")
                elif isinstance(value, float) and not math.isfinite(value):
                    raise MuseumError("nonfinite JSON-LD number")
                elif type(value) is int and abs(value) > (1 << 53) - 1:
                    raise MuseumError("inexact JSON-LD integer")
                elif isinstance(value, dict):
                    for key, item in value.items():
                        validate(key, depth + 1)
                        validate(item, depth + 1)
                elif isinstance(value, list):
                    for item in value:
                        validate(item, depth + 1)

            validate(document)
        except (ValueError, UnicodeError, RecursionError) as exc:
            raise MuseumError("invalid dependency JSON") from exc
        return {"contextUrl": None, "documentUrl": uri, "document": document}


def chunk_carrier(content: bytes, document_sha256: str, index: str, maximum=24575) -> bytes:
    """Candidate payload bytes, not a registration or an allocated record type.

    Root may select an existing raw document carrier instead. The complete
    proposed JSON payload is bounded, including hex expansion and metadata.
    """
    hex_bytes(document_sha256, 32)
    uint(index, 32)
    result = dumps({"documentSha256": document_sha256, "index": index,
                    "data": "0x" + content.hex()})
    if len(result) > maximum:
        raise MuseumError("encoded chunk carrier byte limit")
    return result
