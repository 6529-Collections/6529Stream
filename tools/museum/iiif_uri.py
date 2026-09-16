"""Closed content-addressed URI profile; no retrieval or availability claim."""

import base64
import re

from .canonical import MuseumError


def content_uri_facts(uri, sha256_hex):
    if not isinstance(sha256_hex, str) or re.fullmatch(r"[0-9a-f]{64}", sha256_hex) is None:
        raise MuseumError("declared SHA-256 must be exact lowercase hex")
    if not isinstance(uri, str):
        raise MuseumError("content URI must be a string")
    if uri.startswith("ipfs://"):
        # CIDv1/raw/sha2-256: four canonical single-byte varints and32 bytes.
        # The fixed profile deliberately excludes DAG-PB, paths and other bases.
        cid = uri[7:]
        if re.fullmatch(r"b[a-z2-7]{58}", cid) is None:
            raise MuseumError("unsupported IPFS URI profile")
        raw = base64.b32decode(cid[1:].upper() + "======")
        if raw[:4] != bytes((1, 0x55, 0x12, 0x20)) or len(raw) != 36:
            raise MuseumError("unsupported CID version/codec/hash")
        if "b" + base64.b32encode(raw).decode("ascii").lower().rstrip("=") != cid:
            raise MuseumError("noncanonical CID encoding")
        if raw[4:].hex() != sha256_hex:
            raise MuseumError("raw CID differs from declared PREMIS SHA-256")
        return {"scheme": "ipfs", "profile": "CIDv1/raw/sha2-256/base32lower",
                "rawDigestAgreement": True, "bytesRetrieved": False}
    if uri.startswith("ar://"):
        txid = uri[5:]
        if re.fullmatch(r"[A-Za-z0-9_-]{43}", txid) is None:
            raise MuseumError("unsupported Arweave URI profile")
        raw = base64.urlsafe_b64decode(txid + "=")
        if len(raw) != 32 or base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=") != txid:
            raise MuseumError("noncanonical Arweave transaction identifier")
        return {"scheme": "ar", "profile": "32-byte transaction identifier/base64url",
                "rawDigestAgreement": None, "bytesRetrieved": False,
                "reason": "transaction identifier is not the media byte digest"}
    raise MuseumError("painting content requires the supported content-addressed URI profile")
