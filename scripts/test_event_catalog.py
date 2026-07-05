#!/usr/bin/env python3
"""Focused tests for the v1 event catalog checker."""

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_event_catalog.py")
REPO_ROOT = SCRIPT_PATH.parent.parent
SPEC = importlib.util.spec_from_file_location("check_event_catalog", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)

from spec_conformance import keccak256_hex  # noqa: E402


def event(signature: str, **overrides) -> dict:
    payload = {
        "signature": signature,
        "topic0": keccak256_hex(signature),
        "schemaVersion": 1,
        "owner": "revenue",
        "status": "active",
        "indexed": ["collectionId"],
        "unindexed": ["schemaVersion", "amount"],
        "supersedes": [],
        "replacedBy": None,
        "semanticsURI": "ipfs://x",
        "semanticsHash": {"algorithm": "KECCAK256", "digest": "0x" + "ab" * 32},
    }
    payload.update(overrides)
    return payload


def catalog_bytes(events: list[dict], **extra) -> bytes:
    payload = {
        "schema": checker.CATALOG_SCHEMA,
        "chainId": 1,
        "deployment": "0x0",
        "events": events,
    }
    payload.update(extra)
    return checker.canonical_json_bytes(payload)


def write_catalog(path: Path, raw: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(raw)


class EventCatalogTests(unittest.TestCase):
    def test_committed_repo_has_no_v1_catalog_yet(self) -> None:
        self.assertFalse((REPO_ROOT / checker.DEFAULT_CATALOG_PATH).exists())

    def test_committed_legacy_catalog_holds_the_indexed_bound(self) -> None:
        count = checker.validate_legacy_indexed_bound(REPO_ROOT)
        self.assertIsNotNone(count)
        self.assertGreater(count, 50)

    def test_legacy_indexed_bound_rejects_four_indexed(self) -> None:
        legacy = {
            "schema_version": "6529stream.event-topic-catalog.v1",
            "topics": [
                {
                    "signature": "Wide(address,address,address,address)",
                    "inputs": [{"indexed": True}] * 4,
                }
            ],
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / checker.LEGACY_CATALOG_PATH
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(legacy), encoding="utf-8")
            with self.assertRaises(checker.EventCatalogError) as ctx:
                checker.validate_legacy_indexed_bound(root)
            self.assertIn("log topic limit", str(ctx.exception))

    def test_accepts_valid_catalog(self) -> None:
        events = [
            event("ThingHappened(uint16,uint256)"),
            event(
                "Transfer(address,address,uint256)",
                indexed=["from", "to", "tokenId"],
                unindexed=[],
            ),
        ]
        raw = catalog_bytes(events, standardExemptions=["Transfer(address,address,uint256)"])
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "event-catalog.json"
            write_catalog(path, raw)
            self.assertEqual(checker.validate_catalog(path), 2)

    def test_accepts_standard_shape_mirror_tag(self) -> None:
        events = [
            event("ControlledOwnershipChanged(uint16,uint256,uint256,address,address)"),
            event(
                "Transfer(address,address,uint256)",
                indexed=["from", "to", "tokenId"],
                unindexed=[],
                mirrorOf="ControlledOwnershipChanged(uint16,uint256,uint256,address,address)",
            ),
        ]
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "event-catalog.json"
            write_catalog(path, catalog_bytes(events))
            self.assertEqual(checker.validate_catalog(path), 2)

    def test_rejects_topic0_drift_and_missing_schema_version(self) -> None:
        events = [
            event("ThingHappened(uint16,uint256)", topic0="0x" + "00" * 32),
            event("Bare(uint256)", unindexed=["value"]),
        ]
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "event-catalog.json"
            write_catalog(path, catalog_bytes(events))
            with self.assertRaises(checker.EventCatalogError) as ctx:
                checker.validate_catalog(path)
            message = str(ctx.exception)
            self.assertIn("topic0 drifted", message)
            self.assertIn("no schemaVersion field", message)

    def test_rejects_four_indexed_fields(self) -> None:
        events = [
            event(
                "Wide(uint16,uint256,uint256,uint256,uint256)",
                indexed=["a", "b", "c", "d"],
            )
        ]
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "event-catalog.json"
            write_catalog(path, catalog_bytes(events))
            with self.assertRaises(checker.EventCatalogError) as ctx:
                checker.validate_catalog(path)
            self.assertIn("log topic limit", str(ctx.exception))

    def test_rejects_broken_supersession_links(self) -> None:
        old = event("Old(uint16,uint256)", replacedBy="New(uint16,uint256)", status="active")
        new = event("New(uint16,uint256)")
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "event-catalog.json"
            write_catalog(path, catalog_bytes([old, new]))
            with self.assertRaises(checker.EventCatalogError) as ctx:
                checker.validate_catalog(path)
            message = str(ctx.exception)
            self.assertIn("archived forever", message)
            self.assertIn("does not list Old(uint16,uint256) in supersedes", message)

    def test_rejects_governed_configuration_without_action_id(self) -> None:
        events = [event("PointerMoved(uint16,bytes32)", governedConfiguration=True)]
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "event-catalog.json"
            write_catalog(path, catalog_bytes(events))
            with self.assertRaises(checker.EventCatalogError) as ctx:
                checker.validate_catalog(path)
            self.assertIn("actionId", str(ctx.exception))

    def test_rejects_non_canonical_encoding(self) -> None:
        events = [event("ThingHappened(uint16,uint256)")]
        pretty = json.dumps(
            json.loads(catalog_bytes(events).decode("utf-8")), indent=2
        ).encode("utf-8")
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "event-catalog.json"
            write_catalog(path, pretty)
            with self.assertRaises(checker.EventCatalogError) as ctx:
                checker.validate_catalog(path)
            self.assertIn("canonical", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
