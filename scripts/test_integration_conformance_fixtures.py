#!/usr/bin/env python3
"""Focused tests for the integration conformance fixture checker."""

from __future__ import annotations

import copy
import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_integration_conformance_fixtures.py")
SPEC = importlib.util.spec_from_file_location(
    "check_integration_conformance_fixtures", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")


def minimal_address_book() -> dict[str, object]:
    return {
        "schema_version": checker.ADDRESS_BOOK_SCHEMA,
        "deployment_version": "anvil-6529stream-v0.1.0-001",
        "network": {"chain_id": 31337},
        "contracts": {
            "StreamAdmins": {"address": "0x0000000000000000000000000000000000000001"},
            "StreamCore": {"address": "0x0000000000000000000000000000000000000003"},
            "StreamCuratorsPool": {"address": "0x0000000000000000000000000000000000000004"},
            "StreamDrops": {"address": "0x0000000000000000000000000000000000000006"},
            "StreamAuctions": {"address": "0x0000000000000000000000000000000000000007"},
            "NextGenRandomizerVRF": {"address": "0x0000000000000000000000000000000000000008"},
            "NextGenRandomizerRNG": {"address": "0x0000000000000000000000000000000000000009"},
            "StreamContractMetadata": {"address": "0x000000000000000000000000000000000000000a"},
        },
    }


def minimal_event_catalog() -> dict[str, object]:
    return {
        "schema_version": checker.EVENT_TOPIC_CATALOG_SCHEMA,
        "topics": [
            {
                "name": "Transfer",
                "signature": "Transfer(address,address,uint256)",
                "topic0": "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
                "emitted_by": ["StreamCore"],
            },
            {
                "name": "DropAuthorizationConsumed",
                "signature": "DropAuthorizationConsumed(bytes32,address,address,address,address,uint256,uint8,bytes32,uint256,uint256)",
                "topic0": "0x7e3045d3a2a1fef2fc94a01efa83491c5f85085bbdd39006e21b9283a1b385ab",
                "emitted_by": ["StreamDrops"],
            },
            {
                "name": "AuctionRegistered",
                "signature": "AuctionRegistered(bytes32,uint256,uint256,address,address,uint256,uint256)",
                "topic0": "0xd2775dd7621cecc5f3799d293e90e8ccde35a11535a788c55d57da0b52f625f8",
                "emitted_by": ["StreamAuctions"],
            },
        ],
    }


def payload_fixture() -> dict[str, object]:
    return {"signing_status": "unsigned"}


def minimal_fixture() -> dict[str, object]:
    return {
        "schema_version": checker.FIXTURE_SCHEMA,
        "maturity": {
            "not_production_ready": True,
            "not_generated_sdk": True,
            "not_external_evidence": True,
        },
        "source_artifacts": {
            "address_book": "deployments/address-books/anvil-6529stream-v0.1.0-001.json",
            "deployment_manifest": "deployments/examples/anvil-6529stream-v0.1.0-001.json",
            "event_topic_catalog": "release-artifacts/latest/event-topic-catalog.json",
            "abi_checksums": "release-artifacts/latest/abi-checksums.json",
            "release_manifest": "release-artifacts/latest/release-manifest.json",
            "release_checksums": "release-artifacts/latest/release-checksums.json",
            "drop_authorization_fixed_price": "test/fixtures/drop-authorization/payload-generator/fixed-price-output.json",
            "drop_authorization_auction": "test/fixtures/drop-authorization/payload-generator/auction-output.json",
        },
        "artifact_chain_config_case": {
            "chain_id": 31337,
            "deployment_version": "anvil-6529stream-v0.1.0-001",
            "required_contracts": {
                name: entry["address"]
                for name, entry in minimal_address_book()["contracts"].items()
            },
            "negative_cases": [
                {"name": "wrong-chain-id", "expected_error": "wrong chain ID"},
                {"name": "wrong-deployment-version", "expected_error": "deployment version mismatch"},
                {"name": "missing-contract", "expected_error": "missing or invalid contract address"},
            ],
        },
        "drop_authorization_cases": [
            {
                "name": "fixed-price-eoa",
                "fixture": "test/fixtures/drop-authorization/payload-generator/fixed-price-output.json",
                "expected_primary_type": "DropAuthorization",
                "expected_domain": {
                    "name": "6529StreamDrops",
                    "version": "1",
                    "chainId": 31337,
                    "verifyingContract": "0x0000000000000000000000000000000000000006",
                },
                "expected_sale_mode": "fixed_price",
                "negative_cases": [
                    "wrong-domain",
                    "stale-signer-epoch",
                    "expired-deadline",
                    "token-data-substitution",
                    "zero-address-signer",
                    "replayed-drop-id",
                ],
            },
            {
                "name": "auction-eoa",
                "fixture": "test/fixtures/drop-authorization/payload-generator/auction-output.json",
                "expected_primary_type": "DropAuthorization",
                "expected_domain": {
                    "name": "6529StreamDrops",
                    "version": "1",
                    "chainId": 31337,
                    "verifyingContract": "0x0000000000000000000000000000000000000006",
                },
                "expected_sale_mode": "auction",
                "negative_cases": [
                    "wrong-domain",
                    "stale-signer-epoch",
                    "expired-deadline",
                    "auction-custody-mismatch",
                    "zero-address-signer",
                    "replayed-drop-id",
                ],
            },
        ],
        "event_decoding_cases": [
            {
                "name": "stream-core-transfer-mint",
                "contract": "StreamCore",
                "emitter": "0x0000000000000000000000000000000000000003",
                "event": "Transfer",
                "signature": "Transfer(address,address,uint256)",
                "topic0": "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
                "sample_log": {
                    "chain_id": 31337,
                    "block_number": 1,
                    "block_hash": "0x1111111111111111111111111111111111111111111111111111111111111111",
                    "transaction_hash": "0x2222222222222222222222222222222222222222222222222222222222222222",
                    "log_index": 0,
                },
                "expected_dispatch_key": "0x0000000000000000000000000000000000000003:0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
                "expected_entity": "Token",
                "expected_read_after_event": [
                    {
                        "contract": "StreamCore",
                        "function": "ownerOf",
                        "args": {"tokenId": "1"},
                        "block_number": 1,
                    }
                ],
                "negative_cases": [
                    "wrong-emitter",
                    "unknown-topic",
                    "duplicate-log-idempotent",
                    "reorg-rollback",
                ],
            },
            {
                "name": "drop-authorization-consumed",
                "contract": "StreamDrops",
                "emitter": "0x0000000000000000000000000000000000000006",
                "event": "DropAuthorizationConsumed",
                "signature": "DropAuthorizationConsumed(bytes32,address,address,address,address,uint256,uint8,bytes32,uint256,uint256)",
                "topic0": "0x7e3045d3a2a1fef2fc94a01efa83491c5f85085bbdd39006e21b9283a1b385ab",
                "sample_log": {
                    "chain_id": 31337,
                    "block_number": 2,
                    "block_hash": "0x3333333333333333333333333333333333333333333333333333333333333333",
                    "transaction_hash": "0x4444444444444444444444444444444444444444444444444444444444444444",
                    "log_index": 1,
                },
                "expected_dispatch_key": "0x0000000000000000000000000000000000000006:0x7e3045d3a2a1fef2fc94a01efa83491c5f85085bbdd39006e21b9283a1b385ab",
                "expected_entity": "DropExecution",
                "expected_read_after_event": [
                    {
                        "contract": "StreamDrops",
                        "function": "isDropConsumed",
                        "args": {"dropId": "fixture-drop-id"},
                        "block_number": 2,
                    }
                ],
                "negative_cases": [
                    "wrong-emitter",
                    "unknown-topic",
                    "duplicate-log-idempotent",
                    "reorg-rollback",
                ],
            },
            {
                "name": "auction-registered",
                "contract": "StreamAuctions",
                "emitter": "0x0000000000000000000000000000000000000007",
                "event": "AuctionRegistered",
                "signature": "AuctionRegistered(bytes32,uint256,uint256,address,address,uint256,uint256)",
                "topic0": "0xd2775dd7621cecc5f3799d293e90e8ccde35a11535a788c55d57da0b52f625f8",
                "sample_log": {
                    "chain_id": 31337,
                    "block_number": 3,
                    "block_hash": "0x5555555555555555555555555555555555555555555555555555555555555555",
                    "transaction_hash": "0x6666666666666666666666666666666666666666666666666666666666666666",
                    "log_index": 2,
                },
                "expected_dispatch_key": "0x0000000000000000000000000000000000000007:0xd2775dd7621cecc5f3799d293e90e8ccde35a11535a788c55d57da0b52f625f8",
                "expected_entity": "Auction",
                "expected_read_after_event": [
                    {
                        "contract": "StreamAuctions",
                        "function": "getAuctionStatus",
                        "args": {"tokenId": "1"},
                        "block_number": 3,
                    }
                ],
                "negative_cases": [
                    "wrong-emitter",
                    "unknown-topic",
                    "duplicate-log-idempotent",
                    "reorg-rollback",
                ],
            },
        ],
        "indexer_behaviour_cases": {
            "log_identity": {
                "optimistic_key_fields": ["chain_id", "transaction_hash", "log_index"],
                "confirmed_key_fields": [
                    "chain_id",
                    "block_hash",
                    "transaction_hash",
                    "log_index",
                ],
            },
            "confirmation_policy": {"minimum_confirmations": 12},
            "unknown_log_policy": {
                "unknown_emitter": "reject",
                "unknown_topic0": "reject",
                "known_topic_wrong_emitter": "reject",
            },
            "no_secret_redaction_cases": [{"name": "redaction"}],
        },
    }


def seed_required_files(root: Path, fixture: dict[str, object]) -> None:
    source_artifacts = fixture["source_artifacts"]
    assert isinstance(source_artifacts, dict)
    write_json(root / str(source_artifacts["address_book"]), minimal_address_book())
    write_text(root / str(source_artifacts["deployment_manifest"]), "{}\n")
    write_json(root / str(source_artifacts["event_topic_catalog"]), minimal_event_catalog())
    write_text(root / str(source_artifacts["abi_checksums"]), "{}\n")
    write_text(root / str(source_artifacts["release_manifest"]), "{}\n")
    write_text(root / str(source_artifacts["release_checksums"]), "{}\n")
    write_json(root / str(source_artifacts["drop_authorization_fixed_price"]), payload_fixture())
    write_json(root / str(source_artifacts["drop_authorization_auction"]), payload_fixture())


class IntegrationConformanceFixtureTests(unittest.TestCase):
    def test_accepts_committed_fixture_and_doc(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])
        self.assertEqual(result, 0)

    def test_accepts_minimal_valid_fixture(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture = minimal_fixture()
            seed_required_files(root, fixture)
            write_json(root / checker.DEFAULT_FIXTURE, fixture)
            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                checker.validate_fixture(root, root / checker.DEFAULT_FIXTURE)

    def test_rejects_bad_schema(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture = minimal_fixture()
            fixture["schema_version"] = "wrong"
            seed_required_files(root, fixture)
            write_json(root / checker.DEFAULT_FIXTURE, fixture)
            with self.assertRaisesRegex(
                checker.IntegrationConformanceFixtureError,
                "schema_version",
            ):
                checker.validate_fixture(root, root / checker.DEFAULT_FIXTURE)

    def test_rejects_missing_source_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture = minimal_fixture()
            seed_required_files(root, fixture)
            source = fixture["source_artifacts"]
            assert isinstance(source, dict)
            (root / str(source["release_manifest"])).unlink()
            write_json(root / checker.DEFAULT_FIXTURE, fixture)
            with self.assertRaisesRegex(
                checker.IntegrationConformanceFixtureError,
                "source_artifacts.release_manifest is missing",
            ):
                checker.validate_fixture(root, root / checker.DEFAULT_FIXTURE)

    def test_rejects_contract_address_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture = minimal_fixture()
            required = fixture["artifact_chain_config_case"]["required_contracts"]
            required["StreamCore"] = "0x0000000000000000000000000000000000000099"
            seed_required_files(root, fixture)
            write_json(root / checker.DEFAULT_FIXTURE, fixture)
            with self.assertRaisesRegex(
                checker.IntegrationConformanceFixtureError,
                "required contract address drift",
            ):
                checker.validate_fixture(root, root / checker.DEFAULT_FIXTURE)

    def test_rejects_missing_negative_case(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture = minimal_fixture()
            event_case = fixture["event_decoding_cases"][0]
            event_case["negative_cases"].remove("reorg-rollback")
            seed_required_files(root, fixture)
            write_json(root / checker.DEFAULT_FIXTURE, fixture)
            with self.assertRaisesRegex(
                checker.IntegrationConformanceFixtureError,
                "missing negative cases",
            ):
                checker.validate_fixture(root, root / checker.DEFAULT_FIXTURE)

    def test_rejects_sale_mode_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture = minimal_fixture()
            fixture["drop_authorization_cases"][0]["expected_sale_mode"] = "auction"
            seed_required_files(root, fixture)
            write_json(root / checker.DEFAULT_FIXTURE, fixture)
            with self.assertRaisesRegex(
                checker.IntegrationConformanceFixtureError,
                "expected_sale_mode drift",
            ):
                checker.validate_fixture(root, root / checker.DEFAULT_FIXTURE)

    def test_rejects_topic_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture = minimal_fixture()
            fixture["event_decoding_cases"][0]["topic0"] = (
                "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
            )
            seed_required_files(root, fixture)
            write_json(root / checker.DEFAULT_FIXTURE, fixture)
            with self.assertRaisesRegex(
                checker.IntegrationConformanceFixtureError,
                "topic0 does not match",
            ):
                checker.validate_fixture(root, root / checker.DEFAULT_FIXTURE)

    def test_rejects_wrong_emitter(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture = minimal_fixture()
            fixture["event_decoding_cases"][0]["emitter"] = (
                "0x0000000000000000000000000000000000000007"
            )
            seed_required_files(root, fixture)
            write_json(root / checker.DEFAULT_FIXTURE, fixture)
            with self.assertRaisesRegex(
                checker.IntegrationConformanceFixtureError,
                "emitter does not match",
            ):
                checker.validate_fixture(root, root / checker.DEFAULT_FIXTURE)

    def test_rejects_bad_dispatch_key(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture = minimal_fixture()
            fixture["event_decoding_cases"][0]["expected_dispatch_key"] = "bad"
            seed_required_files(root, fixture)
            write_json(root / checker.DEFAULT_FIXTURE, fixture)
            with self.assertRaisesRegex(
                checker.IntegrationConformanceFixtureError,
                "expected_dispatch_key",
            ):
                checker.validate_fixture(root, root / checker.DEFAULT_FIXTURE)

    def test_rejects_secret_shaped_fixture_value(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture = minimal_fixture()
            fixture["productionPrivateKey"] = (
                "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
            )
            seed_required_files(root, fixture)
            write_json(root / checker.DEFAULT_FIXTURE, fixture)
            with self.assertRaisesRegex(
                checker.IntegrationConformanceFixtureError,
                "secret-shaped fixture field",
            ):
                checker.validate_fixture(root, root / checker.DEFAULT_FIXTURE)

    def test_committed_doc_validation_rejects_missing_heading(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        doc = repo_root / checker.DEFAULT_DOC
        original = doc.read_text(encoding="utf-8")
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fake_doc = root / checker.DEFAULT_DOC
            write_text(fake_doc, original.replace("## Event Dispatch Cases\n", ""))
            with self.assertRaisesRegex(
                checker.IntegrationConformanceFixtureError,
                "missing required headings",
            ):
                checker.validate_doc(repo_root, fake_doc)


if __name__ == "__main__":
    unittest.main(verbosity=2)
