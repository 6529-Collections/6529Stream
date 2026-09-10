#!/usr/bin/env python3
"""Shared no-secret scanner for JSON-like release evidence."""

from __future__ import annotations

import re
from typing import Any


SECRET_KEY_RE = re.compile(
    r"(^|[_\-\s])("
    r"private[_\-\s]?key|mnemonic|seed[_\-\s]?phrase|rpc[_\-\s]?url|"
    r"api[_\-\s]?key|password|hsm[_\-\s]?credential|signer[_\-\s]?secret|"
    r"unreleased[_\-\s]?drop[_\-\s]?payload|raw[_\-\s]?signature|"
    r"bearer[_\-\s]?token"
    r")([_\-\s]|$)"
    r"|(^|[_\-\s])client[_\-\s]?secret([_\-\s]|$)"
    r"|(^|[_\-\s])secret$",
    re.IGNORECASE,
)
# SECRET_KEY_RE intentionally catches keys whose final segment is "secret".
# Legitimate policy metadata must be listed explicitly rather than weakening
# the shared pattern.
SAFE_SECRET_POLICY_KEYS = frozenset(
    {"redaction_policy", "no_secrets", "redacted_fields"}
)
SECRET_VALUE_RE = re.compile(
    r"\b(private[_ -]?key|mnemonic|seed[_ -]?phrase|secret|rpc[_ -]?url|"
    r"api[_ -]?key|password|client[_ -]?secret|hsm[_ -]?credential|"
    r"signer[_ -]?secret|bearer[_ -]?token|raw[_ -]?signature|"
    r"unreleased[_ -]?drop[_ -]?payload)\s*[:=]",
    re.IGNORECASE,
)


class NoSecretScanError(RuntimeError):
    """Raised when JSON-like evidence contains secret-shaped data."""


def scan_json_no_secrets(value: Any, path: str = "$") -> None:
    """Reject secret-shaped keys and assignment-looking string values."""
    if isinstance(value, dict):
        for key, item in value.items():
            key_text = str(key)
            key_lower = key_text.lower()
            if (
                key_lower not in SAFE_SECRET_POLICY_KEYS
                and SECRET_KEY_RE.search(key_text)
            ):
                raise NoSecretScanError(
                    f"secret-like key found at {path}.{key_text}"
                )
            scan_json_no_secrets(item, f"{path}.{key_text}")
    elif isinstance(value, list):
        for index, item in enumerate(value):
            scan_json_no_secrets(item, f"{path}[{index}]")
    elif isinstance(value, str) and SECRET_VALUE_RE.search(value):
        raise NoSecretScanError(f"secret-like value found at {path}")
