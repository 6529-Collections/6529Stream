#!/usr/bin/env python3
"""Hostile tests for the current recovery owner-record continuity extension."""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import shutil
import tempfile
import unittest
from pathlib import Path
from types import ModuleType
from typing import Any

from jsonschema import Draft202012Validator

REPO_ROOT = Path(__file__).resolve().parents[2]
CHECKER_PATH = REPO_ROOT / "tools/protocol/check_artist_owner_record_continuity_extension.py"


def _load_checker() -> ModuleType:
    spec = importlib.util.spec_from_file_location("owner_record_continuity_checker", CHECKER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load owner record continuity checker")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


CHECKER = _load_checker()


class ArtistOwnerRecordContinuityExtensionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)
        copied = [CHECKER.PACKET_PATH, CHECKER.SCHEMA_PATH,
                  *(Path(row["path"]) for row in CHECKER.EXPECTED_HISTORICAL_INPUTS)]
        for relative in copied:
            destination = self.root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(REPO_ROOT / relative, destination)

    def tearDown(self) -> None:
        self.tempdir.cleanup()


    def _read(self, relative: Path) -> dict[str, Any]:
        return json.loads((self.root / relative).read_text(encoding="utf-8"))


    def _write(self, relative: Path, value: Any) -> None:
        (self.root / relative).write_text(
            json.dumps(value, indent=2) + "\n", encoding="utf-8"
        )


    def _packet(self) -> dict[str, Any]:
        return self._read(CHECKER.PACKET_PATH)


    def _write_packet(self, packet: dict[str, Any]) -> None:
        self._write(CHECKER.PACKET_PATH, packet)


    def _assert_rejected(self, expected: str) -> None:
        with self.assertRaisesRegex(CHECKER.ContinuityError, expected):
            CHECKER.check(self.root)


    def _refresh_packet_semantic_digest(self) -> str:
        packet = self._packet()
        payload = dict(packet)
        payload.pop("semantic_digest")
        digest = "sha256:" + CHECKER._canonical_sha(payload)
        packet["semantic_digest"] = digest
        self._write_packet(packet)
        return digest


    def _assert_rejected_after_semantic_rebind(self, expected: str) -> None:
        digest = self._refresh_packet_semantic_digest()
        original = CHECKER.SEMANTIC_DIGEST
        try:
            CHECKER.SEMANTIC_DIGEST = digest
            self._assert_rejected(expected)
        finally:
            CHECKER.SEMANTIC_DIGEST = original


    def test_current_owner_domain_is_constructor_identity_not_logical_namespace(self) -> None:
        packet = self._packet()
        profile = packet["operation35_secondary_occurrence"]["operative_owner_binding"]
        self.assertEqual(CHECKER._keccak_text("domain:identity_authority"), profile["owner_domain_id"])
        baseline = self._read(CHECKER.historical.PACKET_PATH)
        old_domain = baseline["canonical_vectors"]["fixture_identity"]["owner_domain_id"]
        self.assertNotEqual(old_domain, profile["owner_domain_id"])
        profile["owner_domain_id"] = old_domain
        self._write_packet(packet)
        self._assert_rejected("schema validation failed")


    def test_current_owner_vector_and_schema_repin_still_rejects(self) -> None:
        packet = self._packet()
        item = packet["operation35_secondary_occurrence"]
        item["operative_owner_binding"]["vectors"][0]["record_delta"] = "0x" + "ee" * 32
        schema = self._read(CHECKER.SCHEMA_PATH)
        schema["properties"]["operation35_secondary_occurrence"]["const"] = copy.deepcopy(item)
        self._write(CHECKER.SCHEMA_PATH, schema)
        self._write_packet(packet)
        old_schema, old_semantic = CHECKER.SCHEMA_SHA256, CHECKER.SEMANTIC_DIGEST
        try:
            CHECKER.SCHEMA_SHA256 = hashlib.sha256((self.root / CHECKER.SCHEMA_PATH).read_bytes()).hexdigest()
            CHECKER.SEMANTIC_DIGEST = self._refresh_packet_semantic_digest()
            self._assert_rejected("operation35 occurrence policy or vectors drifted")
        finally:
            CHECKER.SCHEMA_SHA256, CHECKER.SEMANTIC_DIGEST = old_schema, old_semantic


    def test_occurrence_cannot_accept_caller_primary_or_change_preimages(self) -> None:
        for field in ("ordinary_coordinate_unchanged", "permanent_semantic_preimages_unchanged", "owner_record_commitment_preimage_unchanged", "existing_or_caller_selected_primary_allowed"):
            with self.subTest(field=field):
                packet = self._packet()
                item = packet["operation35_secondary_occurrence"]
                item[field] = not item[field]
                self._write_packet(packet)
                self._assert_rejected("schema validation failed")
                shutil.copy2(REPO_ROOT / CHECKER.PACKET_PATH, self.root / CHECKER.PACKET_PATH)


    def test_occurrence_coordinated_packet_schema_and_digest_repin_is_rejected(self) -> None:
        packet = self._packet()
        item = packet["operation35_secondary_occurrence"]
        item["existing_or_caller_selected_primary_allowed"] = True
        schema = self._read(CHECKER.SCHEMA_PATH)
        schema["properties"]["operation35_secondary_occurrence"]["const"] = copy.deepcopy(item)
        self._write(CHECKER.SCHEMA_PATH, schema)
        self._write_packet(packet)
        old_schema, old_semantic = CHECKER.SCHEMA_SHA256, CHECKER.SEMANTIC_DIGEST
        try:
            CHECKER.SCHEMA_SHA256 = hashlib.sha256((self.root / CHECKER.SCHEMA_PATH).read_bytes()).hexdigest()
            CHECKER.SEMANTIC_DIGEST = self._refresh_packet_semantic_digest()
            self._assert_rejected("operation35 occurrence policy or vectors drifted")
        finally:
            CHECKER.SCHEMA_SHA256, CHECKER.SEMANTIC_DIGEST = old_schema, old_semantic


    def test_occurrence_domain_or_primary_vector_substitution_is_rejected(self) -> None:
        packet = self._packet()
        packet["operation35_secondary_occurrence"]["vectors"][0]["expected_primary_recovery_record_hash"] = "0x" + "ee" * 32
        self._write_packet(packet)
        self._assert_rejected("schema validation failed")


    def test_occurrence_exception_cannot_move_to_another_slot_or_owner(self) -> None:
        for field, value in (("operation_id", 34), ("record_position", 0), ("owner_domain", "consent_finality")):
            with self.subTest(field=field):
                packet = self._packet()
                packet["operation35_secondary_occurrence"][field] = value
                self._write_packet(packet)
                self._assert_rejected("schema validation failed")
                shutil.copy2(REPO_ROOT / CHECKER.PACKET_PATH, self.root / CHECKER.PACKET_PATH)


    def test_occurrence_requires_one_revision_two_appends_and_atomic_failure(self) -> None:
        for field, value in (("owner_revision_delta", 2), ("ordered_record_appends", 1), ("second_append_failure", "keep_first_append"), ("duplicate_primary_action_or_nonce", "accept_idempotently")):
            with self.subTest(field=field):
                packet = self._packet()
                packet["operation35_secondary_occurrence"][field] = value
                self._write_packet(packet)
                self._assert_rejected("schema validation failed")
                shutil.copy2(REPO_ROOT / CHECKER.PACKET_PATH, self.root / CHECKER.PACKET_PATH)


    def test_occurrence_reuses_lists_only_across_distinct_primaries(self) -> None:
        rows = self._packet()["operation35_secondary_occurrence"]["vectors"]
        for a, b in ((rows[0], rows[1]), (rows[2], rows[3])):
            self.assertEqual(a["superseded_record_hashes"], b["superseded_record_hashes"])
            self.assertEqual(a["expected_secondary_semantic_hash"], b["expected_secondary_semantic_hash"])
            self.assertNotEqual(a["expected_primary_recovery_record_hash"], b["expected_primary_recovery_record_hash"])
            self.assertNotEqual(a["expected_occurrence_key"], b["expected_occurrence_key"])
        self.assertNotEqual(rows[0]["artist_id"], rows[1]["artist_id"])
        self.assertNotEqual(rows[2]["governance_action_id"], rows[3]["governance_action_id"])


    def test_current_extension_and_both_calculations_pass(self) -> None:
        CHECKER.check(self.root)

    def test_envelope_identity_and_unknown_fields_are_rejected(self) -> None:
        for key, value in (("schema", "wrong.v2"), ("status", "RELEASE_ACCEPTED"),
                           ("maturity", "audited"), ("historical_commit", "0" * 40),
                           ("unknown", True)):
            with self.subTest(key=key):
                packet = self._packet()
                packet[key] = value
                self._write_packet(packet)
                self._assert_rejected("schema validation failed")
                shutil.copyfile(REPO_ROOT / CHECKER.PACKET_PATH, self.root / CHECKER.PACKET_PATH)

    def test_baseline_reference_and_each_baseline_file_are_bound(self) -> None:
        packet = self._packet()
        packet["historical_inputs"][0]["sha256"] = "0" * 64
        self._write_packet(packet)
        self._assert_rejected("schema validation failed")
        shutil.copyfile(REPO_ROOT / CHECKER.PACKET_PATH, self.root / CHECKER.PACKET_PATH)
        for row in CHECKER.EXPECTED_HISTORICAL_INPUTS:
            target = self.root / row["path"]
            original = target.read_bytes()
            with self.subTest(path=row["path"]):
                target.write_bytes(original + b" ")
                self._assert_rejected("historical input bytes drifted")
                target.write_bytes(original)

    def test_digest_drift_is_rejected(self) -> None:
        packet = self._packet()
        packet["semantic_digest"] = "sha256:" + "0" * 64
        self._write_packet(packet)
        self._assert_rejected("packet semantic digest drifted")

    def test_duplicate_keys_and_non_json_constants_are_rejected(self) -> None:
        for raw, reason in ((b'{"schema": 1, "schema": 2}', "duplicate JSON key"),
                            (b'{"schema": NaN}', "non-JSON constant"),
                            (b'[]', "JSON object required")):
            with self.subTest(raw=raw):
                (self.root / CHECKER.PACKET_PATH).write_bytes(raw)
                self._assert_rejected(reason)


if __name__ == "__main__":
    unittest.main(verbosity=2)
