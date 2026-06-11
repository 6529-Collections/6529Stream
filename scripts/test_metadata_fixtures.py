#!/usr/bin/env python3
"""Focused tests for metadata fixture render-safety checks."""

from __future__ import annotations

import base64
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_metadata_fixtures.py")
SPEC = importlib.util.spec_from_file_location("check_metadata_fixtures", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)


def encode_data_uri(prefix: str, value: str) -> str:
    encoded = base64.b64encode(value.encode("utf-8")).decode("ascii")
    return f"{prefix}{encoded}"


def encode_raw_data_uri(prefix: str, value: bytes) -> str:
    encoded = base64.b64encode(value).decode("ascii")
    return f"{prefix}{encoded}"


def write_fixture(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def write_fixture_set(
    root: Path,
    *,
    offchain_pending: str = "ipfs://base/pending",
    offchain_final: str = "ipfs://base/10000000000",
    image: str = "ipfs://image/10000000000.png",
    attributes: object | None = None,
    animation_html: str | None = None,
    malformed_pending_uri: str | None = None,
    malformed_animation_uri: str | None = None,
) -> None:
    write_fixture(root / checker.OFFCHAIN_PENDING_FIXTURE, offchain_pending)
    write_fixture(root / checker.OFFCHAIN_FINAL_FIXTURE, offchain_final)

    if attributes is None:
        attributes = [{"trait_type": "Mood", "value": "Calm"}]

    pending_metadata = {
        "metadata_schema_version": checker.METADATA_SCHEMA_VERSION,
        "metadata_state": checker.STATE_PENDING,
        "name": "Genesis #0",
        "description": "Description",
        "image": image,
        "attributes": attributes,
    }
    pending_uri = (
        malformed_pending_uri
        if malformed_pending_uri is not None
        else encode_data_uri(
            checker.JSON_DATA_URI_PREFIX,
            json.dumps(pending_metadata, separators=(",", ":")),
        )
    )
    write_fixture(root / checker.ONCHAIN_PENDING_FIXTURE, pending_uri)

    if animation_html is None:
        animation_html = (
            "<html><head></head><body>"
            '<script src="https://cdn.example/script.js"></script>'
            "<script>let hash='0x01';let tokenId=10000000000;"
            "let tokenDataRaw='1,2,3';let tokenData=JSON.parse('['+tokenDataRaw+']');"
            "function draw(){}</script></body></html>"
        )
    final_metadata = dict(pending_metadata)
    final_metadata["metadata_state"] = checker.STATE_FINAL
    final_metadata["animation_url"] = (
        malformed_animation_uri
        if malformed_animation_uri is not None
        else encode_data_uri(checker.HTML_DATA_URI_PREFIX, animation_html)
    )
    write_fixture(
        root / checker.ONCHAIN_FINAL_FIXTURE,
        encode_data_uri(
            checker.JSON_DATA_URI_PREFIX, json.dumps(final_metadata, separators=(",", ":"))
        ),
    )


class MetadataFixtureTests(unittest.TestCase):
    def test_current_repository_fixtures_pass(self) -> None:
        repo_root = Path(__file__).resolve().parents[1]
        checker.validate_fixture_set(repo_root / "test" / "fixtures" / "metadata")

    def test_rejects_unsafe_offchain_uri_scheme(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_fixture_set(root, offchain_pending="javascript:alert(1)")
            with self.assertRaisesRegex(checker.MetadataFixtureError, "scheme javascript"):
                checker.validate_fixture_set(root)

    def test_rejects_malformed_data_uri(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_fixture_set(root, malformed_pending_uri="data:application/json;base64,@@@")
            with self.assertRaisesRegex(checker.MetadataFixtureError, "invalid base64"):
                checker.validate_fixture_set(root)

    def test_rejects_invalid_utf8_metadata_data_uri(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_fixture_set(
                root,
                malformed_pending_uri=encode_raw_data_uri(
                    checker.JSON_DATA_URI_PREFIX, b'{"name":"bad-\xff"}'
                ),
            )
            with self.assertRaisesRegex(checker.MetadataFixtureError, "valid UTF-8"):
                checker.validate_fixture_set(root)

    def test_rejects_invalid_utf8_animation_data_uri(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_fixture_set(
                root,
                malformed_animation_uri=encode_raw_data_uri(
                    checker.HTML_DATA_URI_PREFIX, b"<html>\xff</html>"
                ),
            )
            with self.assertRaisesRegex(checker.MetadataFixtureError, "valid UTF-8"):
                checker.validate_fixture_set(root)

    def test_rejects_empty_metadata_image(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_fixture_set(root, image="")
            with self.assertRaisesRegex(checker.MetadataFixtureError, "image URI must not be empty"):
                checker.validate_fixture_set(root)

    def test_rejects_attribute_with_missing_required_key(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_fixture_set(root, attributes=[{"trait_type": "Mood"}])
            with self.assertRaisesRegex(checker.MetadataFixtureError, "trait_type and value"):
                checker.validate_fixture_set(root)

    def test_rejects_attribute_with_unexpected_key(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_fixture_set(
                root,
                attributes=[{"trait_type": "Level", "value": "1", "display_type": "number"}],
            )
            with self.assertRaisesRegex(checker.MetadataFixtureError, "trait_type and value"):
                checker.validate_fixture_set(root)

    def test_rejects_attribute_with_non_string_value(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_fixture_set(root, attributes=[{"trait_type": "Level", "value": 1}])
            with self.assertRaisesRegex(checker.MetadataFixtureError, "values must be strings"):
                checker.validate_fixture_set(root)

    def test_rejects_unexpected_animation_html_tag(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_fixture_set(
                root,
                animation_html=(
                    "<html><head></head><body>"
                    '<script src="https://cdn.example/script.js"></script>'
                    "<img src=x>"
                    "<script>let hash='0x01';function draw(){}</script>"
                    "</body></html>"
                ),
            )
            with self.assertRaisesRegex(checker.MetadataFixtureError, "unexpected HTML tag"):
                checker.validate_fixture_set(root)

    def test_rejects_raw_script_boundary_breakout(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_fixture_set(
                root,
                animation_html=(
                    "<html><head></head><body>"
                    '<script src="https://cdn.example/script.js"></script>'
                    "<script>let hash='0x01';function draw(){"
                    "const x='</script><script>alert(1)</script>';}</script>"
                    "</body></html>"
                ),
            )
            with self.assertRaisesRegex(checker.MetadataFixtureError, "script"):
                checker.validate_fixture_set(root)

    def test_rejects_non_https_external_script(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_fixture_set(
                root,
                animation_html=(
                    "<html><head></head><body>"
                    '<script src="ipfs://dependency/script.js"></script>'
                    "<script>let hash='0x01';function draw(){}</script>"
                    "</body></html>"
                ),
            )
            with self.assertRaisesRegex(checker.MetadataFixtureError, "expected https"):
                checker.validate_fixture_set(root)


if __name__ == "__main__":
    unittest.main()
