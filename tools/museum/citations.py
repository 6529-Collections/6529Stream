"""Canonical original-token citations; parsing is not source authentication."""
import re

from .canonical import MuseumError, hex_bytes, uint

PATTERN = re.compile(r"eip155:(0|[1-9][0-9]*)/erc721:(0x[0-9a-f]{40})/(0|[1-9][0-9]*)(?:@(fin|snap|chain):(0x[0-9a-f]{64}))?")


def parse_citation(value, *, require_state=False):
    match = PATTERN.fullmatch(value) if isinstance(value, str) and len(value) <= 300 else None
    if match is None:
        raise MuseumError("citation requires canonical original token and typed state qualifier")
    chain, core, token, kind, digest = match.groups()
    if uint(chain) == 0 or uint(token) == 0 or not any(hex_bytes(core, 20)):
        raise MuseumError("citation nonzero chain/Core/token required")
    if require_state and kind is None:
        raise MuseumError("citation record-state qualifier required")
    if kind is not None and not any(hex_bytes(digest, 32)):
        raise MuseumError("citation state hash is empty")
    return {"chainId": chain, "core": core, "tokenId": token,
            "qualifier": None if kind is None else {"kind": kind, "hash": digest}}


def canonical_citation(chain_id, core, token_id, qualifier=None):
    suffix = ""
    if qualifier is not None:
        if not isinstance(qualifier, dict) or set(qualifier) != {"kind", "hash"}:
            raise MuseumError("citation qualifier shape")
        suffix = "@" + qualifier["kind"] + ":" + qualifier["hash"]
    result = f"eip155:{chain_id}/erc721:{core}/{token_id}{suffix}"
    parse_citation(result)
    return result
