#!/usr/bin/env python3
"""Validate committed metadata golden fixtures for render-safety invariants."""

from __future__ import annotations

import argparse
import base64
import binascii
import json
import sys
from dataclasses import dataclass
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit


JSON_DATA_URI_PREFIX = "data:application/json;base64,"
HTML_DATA_URI_PREFIX = "data:text/html;base64,"

OFFCHAIN_PENDING_FIXTURE = "offchain-pending-token-uri.txt"
OFFCHAIN_FINAL_FIXTURE = "offchain-final-token-uri.txt"
ONCHAIN_PENDING_FIXTURE = "onchain-pending-schema-v1-token-uri.txt"
ONCHAIN_FINAL_FIXTURE = "onchain-final-schema-v1-token-uri.txt"

METADATA_SCHEMA_VERSION = "6529stream-v1"
STATE_PENDING = "pending"
STATE_FINAL = "final"

SAFE_CONTENT_SCHEMES = {"ar", "https", "ipfs"}
SAFE_SCRIPT_SCHEMES = {"https"}


class MetadataFixtureError(ValueError):
    """Raised when a metadata fixture violates the committed safety policy."""


@dataclass
class ScriptTag:
    attrs: dict[str, str]
    data: str = ""


class RenderSandboxParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=False)
        self.tags: list[tuple[str, str]] = []
        self.scripts: list[ScriptTag] = []
        self.errors: list[str] = []
        self._current_script: ScriptTag | None = None

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        tag = tag.lower()
        self.tags.append(("start", tag))
        if tag not in {"html", "head", "body", "script"}:
            self.errors.append(f"unexpected HTML tag <{tag}>")
        if tag == "script":
            if self._current_script is not None:
                self.errors.append("nested script tag")
            attr_map: dict[str, str] = {}
            for name, value in attrs:
                normalized = name.lower()
                if normalized in attr_map:
                    self.errors.append(f"duplicate script attribute {normalized}")
                attr_map[normalized] = value or ""
            script = ScriptTag(attr_map)
            self.scripts.append(script)
            self._current_script = script

    def handle_endtag(self, tag: str) -> None:
        tag = tag.lower()
        self.tags.append(("end", tag))
        if tag == "script":
            if self._current_script is None:
                self.errors.append("script end tag without matching start")
            self._current_script = None

    def handle_data(self, data: str) -> None:
        if self._current_script is not None:
            self._current_script.data += data
        elif data.strip():
            self.errors.append("non-whitespace text outside script tags")


def read_fixture(fixtures_dir: Path, name: str) -> str:
    path = fixtures_dir / name
    try:
        return path.read_text(encoding="utf-8").strip()
    except FileNotFoundError as exc:
        raise MetadataFixtureError(f"missing fixture: {path}") from exc


def decode_data_uri(data_uri: str, prefix: str, label: str) -> str:
    if not data_uri.startswith(prefix):
        raise MetadataFixtureError(f"{label} must start with {prefix}")
    encoded = data_uri[len(prefix) :]
    try:
        decoded = base64.b64decode(encoded, validate=True)
    except binascii.Error as exc:
        raise MetadataFixtureError(f"{label} has invalid base64 payload: {exc}") from exc
    try:
        return decoded.decode("utf-8", errors="strict")
    except UnicodeDecodeError as exc:
        raise MetadataFixtureError(f"{label} does not decode as valid UTF-8: {exc}") from exc


def validate_external_uri(uri: str, *, allowed_schemes: set[str], label: str) -> None:
    if uri == "":
        return
    if uri != uri.strip():
        raise MetadataFixtureError(f"{label} URI has leading or trailing whitespace")
    for character in uri:
        codepoint = ord(character)
        if codepoint <= 0x20 or codepoint == 0x7F:
            raise MetadataFixtureError(f"{label} URI contains whitespace or control characters")

    parsed = urlsplit(uri)
    if parsed.scheme not in allowed_schemes:
        allowed = ", ".join(sorted(allowed_schemes))
        raise MetadataFixtureError(
            f"{label} URI scheme {parsed.scheme or '<none>'} is not allowed; expected {allowed}"
        )
    if parsed.scheme == "https" and not parsed.netloc:
        raise MetadataFixtureError(f"{label} HTTPS URI is missing a host")
    if parsed.scheme in {"ar", "ipfs"} and not (parsed.netloc or parsed.path):
        raise MetadataFixtureError(f"{label} content URI is missing an identifier")


def validate_attributes(attributes: object, *, label: str) -> None:
    if not isinstance(attributes, list):
        raise MetadataFixtureError(f"{label} attributes must be a JSON array")
    for index, attribute in enumerate(attributes):
        if not isinstance(attribute, dict):
            raise MetadataFixtureError(f"{label} attribute {index} must be an object")
        if set(attribute) != {"trait_type", "value"}:
            raise MetadataFixtureError(
                f"{label} attribute {index} must contain only trait_type and value"
            )
        if not isinstance(attribute["trait_type"], str) or not isinstance(attribute["value"], str):
            raise MetadataFixtureError(f"{label} attribute {index} values must be strings")


def validate_metadata_json(raw_json: str, *, expected_state: str) -> dict[str, object]:
    try:
        metadata = json.loads(raw_json)
    except json.JSONDecodeError as exc:
        raise MetadataFixtureError(f"{expected_state} metadata JSON does not parse: {exc}") from exc
    if not isinstance(metadata, dict):
        raise MetadataFixtureError(f"{expected_state} metadata must be a JSON object")

    expected_keys = {
        "metadata_schema_version",
        "metadata_state",
        "name",
        "description",
        "image",
        "attributes",
    }
    if expected_state == STATE_FINAL:
        expected_keys.add("animation_url")
    if set(metadata) != expected_keys:
        raise MetadataFixtureError(
            f"{expected_state} metadata keys changed: {sorted(metadata)}"
        )
    if metadata["metadata_schema_version"] != METADATA_SCHEMA_VERSION:
        raise MetadataFixtureError(f"{expected_state} metadata schema version changed")
    if metadata["metadata_state"] != expected_state:
        raise MetadataFixtureError(f"{expected_state} metadata state field changed")

    for key in ("name", "description", "image"):
        if not isinstance(metadata[key], str):
            raise MetadataFixtureError(f"{expected_state} metadata {key} must be a string")

    validate_external_uri(
        metadata["image"], allowed_schemes=SAFE_CONTENT_SCHEMES, label=f"{expected_state} image"
    )
    validate_attributes(metadata["attributes"], label=expected_state)
    return metadata


def validate_animation_html(html: str) -> None:
    parser = RenderSandboxParser()
    parser.feed(html)
    parser.close()
    if parser.errors:
        raise MetadataFixtureError("; ".join(parser.errors))

    expected_tags = [
        ("start", "html"),
        ("start", "head"),
        ("end", "head"),
        ("start", "body"),
        ("start", "script"),
        ("end", "script"),
        ("start", "script"),
        ("end", "script"),
        ("end", "body"),
        ("end", "html"),
    ]
    if parser.tags != expected_tags:
        raise MetadataFixtureError(f"animation HTML wrapper changed: {parser.tags}")
    if len(parser.scripts) != 2:
        raise MetadataFixtureError(f"expected two script tags, found {len(parser.scripts)}")

    external_script = parser.scripts[0]
    inline_script = parser.scripts[1]
    if set(external_script.attrs) != {"src"}:
        raise MetadataFixtureError("external script must contain only src")
    if external_script.data.strip():
        raise MetadataFixtureError("external script tag must not contain inline code")
    validate_external_uri(
        external_script.attrs["src"],
        allowed_schemes=SAFE_SCRIPT_SCHEMES,
        label="external script",
    )

    if inline_script.attrs:
        raise MetadataFixtureError("inline generative script must not have attributes")
    inline_lower = inline_script.data.lower()
    if not inline_script.data.strip():
        raise MetadataFixtureError("inline generative script is empty")
    if "<script" in inline_lower or "</script" in inline_lower:
        raise MetadataFixtureError("inline generative script contains raw script tag text")
    if "let hash=" not in inline_script.data or "function draw()" not in inline_script.data:
        raise MetadataFixtureError("inline generative script lost expected bootstrap code")


def validate_fixture_set(fixtures_dir: Path) -> None:
    offchain_pending = read_fixture(fixtures_dir, OFFCHAIN_PENDING_FIXTURE)
    offchain_final = read_fixture(fixtures_dir, OFFCHAIN_FINAL_FIXTURE)
    validate_external_uri(
        offchain_pending, allowed_schemes=SAFE_CONTENT_SCHEMES, label="off-chain pending tokenURI"
    )
    validate_external_uri(
        offchain_final, allowed_schemes=SAFE_CONTENT_SCHEMES, label="off-chain final tokenURI"
    )
    if not offchain_pending.endswith(f"/{STATE_PENDING}"):
        raise MetadataFixtureError("off-chain pending tokenURI must end with /pending")

    pending_json = decode_data_uri(
        read_fixture(fixtures_dir, ONCHAIN_PENDING_FIXTURE),
        JSON_DATA_URI_PREFIX,
        "on-chain pending tokenURI",
    )
    validate_metadata_json(pending_json, expected_state=STATE_PENDING)

    final_json = decode_data_uri(
        read_fixture(fixtures_dir, ONCHAIN_FINAL_FIXTURE),
        JSON_DATA_URI_PREFIX,
        "on-chain final tokenURI",
    )
    final_metadata = validate_metadata_json(final_json, expected_state=STATE_FINAL)
    animation_url = final_metadata["animation_url"]
    if not isinstance(animation_url, str):
        raise MetadataFixtureError("final animation_url must be a string")
    animation_html = decode_data_uri(animation_url, HTML_DATA_URI_PREFIX, "final animation_url")
    validate_animation_html(animation_html)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Validate committed metadata golden fixtures for render-safety invariants."
    )
    parser.add_argument(
        "--fixtures-dir",
        type=Path,
        default=Path("test/fixtures/metadata"),
        help="Directory containing metadata golden fixture files.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        validate_fixture_set(args.fixtures_dir)
    except MetadataFixtureError as exc:
        print(f"metadata fixture check failed: {exc}", file=sys.stderr)
        return 1
    print(f"Validated metadata fixtures in {args.fixtures_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
