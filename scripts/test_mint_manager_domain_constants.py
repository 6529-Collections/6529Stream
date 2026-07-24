#!/usr/bin/env python3
"""Focused tests for the StreamMintManager domain constant checker."""

from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_mint_manager_domain_constants.py")
SPEC = importlib.util.spec_from_file_location("check_mint_manager_domain_constants", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)


def table_for(domain: object, hash_value: str) -> str:
    return "\n".join(
        [
            "# Spec",
            checker.TABLE_HEADING,
            "",
            "| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |",
            "| --- | --- | --- | --- | --- | --- |",
            (
                f"| `{domain.name}` | `{domain.preimage}` | `{hash_value}` | "
                f"`{domain.owner}` | `{domain.schema_version}` | `{domain.inputs}` |"
            ),
            "",
            "## Next Section",
            "",
        ]
    )


class MintManagerDomainConstantTests(unittest.TestCase):
    def test_committed_domain_table_matches_solidity_constants(self) -> None:
        checker.validate_repo(SCRIPT_PATH.parent.parent)

    def test_rejects_hash_drift(self) -> None:
        domain = checker.DomainSpec(
            name="POLICY_DOMAIN",
            preimage="6529STREAM_MINT_MANAGER_POLICY_V1",
            owner="StreamMintManager",
            schema_version="1",
            inputs="POLICY_DOMAIN",
        )
        docs_text = table_for(domain, "0x" + "00" * 32)
        source_text = (
            'contract Mock { bytes32 public constant POLICY_DOMAIN = '
            'keccak256("6529STREAM_MINT_MANAGER_POLICY_V1"); '
            "uint16 public constant SCHEMA_VERSION = 1; }"
        )

        with self.assertRaisesRegex(checker.MintManagerDomainError, "Hash value drifted"):
            checker.validate_documents(
                docs_text,
                source_text,
                domains=(domain,),
                keccak_fn=lambda _: "0x" + "11" * 32,
            )

    def test_rejects_solidity_preimage_drift(self) -> None:
        domain = checker.DomainSpec(
            name="POLICY_DOMAIN",
            preimage="6529STREAM_MINT_MANAGER_POLICY_V1",
            owner="StreamMintManager",
            schema_version="1",
            inputs="POLICY_DOMAIN",
        )
        docs_text = table_for(domain, "0x" + "11" * 32)
        source_text = (
            'contract Mock { bytes32 public constant POLICY_DOMAIN = '
            'keccak256("6529STREAM_MINT_MANAGER_POLICY_V2"); '
            "uint16 public constant SCHEMA_VERSION = 1; }"
        )

        with self.assertRaisesRegex(checker.MintManagerDomainError, "Solidity preimage drifted"):
            checker.validate_documents(
                docs_text,
                source_text,
                domains=(domain,),
                keccak_fn=lambda _: "0x" + "11" * 32,
            )

    def test_rejects_target_operation_hash_drift(self) -> None:
        rows = [
            checker.OPERATION_DOMAIN_MARKER,
            "",
            "| Constant | String preimage | Hash |",
            "| --- | --- | --- |",
        ]
        for index, (name, preimage) in enumerate(checker.TARGET_OPERATION_DOMAINS):
            digest = "0x" + ("00" if index == 0 else "11") * 32
            rows.append(f"| `{name}` | `{preimage}` | `{digest}` |")
        rows.extend(["", "```solidity", ""])
        architecture = "\n".join(
            f"| `{name}` | `{preimage}` | {'0x' + '11' * 32} |"
            for name, preimage in checker.TARGET_OPERATION_DOMAINS
        )

        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "MINT_REQUEST_COMMITMENT_DOMAIN target hash drifted",
        ):
            checker.validate_operation_domains(
                "\n".join(rows),
                architecture,
                keccak_fn=lambda _: "0x" + "11" * 32,
            )

    def test_rejects_missing_operation_identity_contract_fragment(self) -> None:
        documents = {
            path: "\n".join(fragments)
            for path, fragments in checker.OPERATION_IDENTITY_FRAGMENTS.items()
        }
        documents[checker.ADR_0018_PATH] = documents[checker.ADR_0018_PATH].replace(
            "## Atomic Cutover And Core Replay Removal", ""
        )

        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "operation identity contract drifted",
        ):
            checker.validate_operation_identity_fragments(documents)

    def test_rejects_target_operation_selector_drift(self) -> None:
        mint_spec = "\n".join(
            f"| `{selector}` | `{signature}` |"
            for signature, selector in checker.TARGET_OPERATION_SELECTORS
        )
        stale_spec = mint_spec.replace("`0x32425026`", "`0x00000000`", 1)

        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "operation identity selector row missing or drifted",
        ):
            checker.validate_operation_selectors(
                stale_spec,
                keccak_fn=lambda signature: next(
                    selector + "0" * 56
                    for expected_signature, selector in checker.TARGET_OPERATION_SELECTORS
                    if expected_signature == signature
                ),
            )

    def test_rejects_target_operation_return_abi_drift(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        documents = {
            path: (repo_root / path).read_text(encoding="utf-8")
            for path in checker.TARGET_OPERATION_ABI_FRAGMENTS
        }
        documents[checker.MINT_SPEC_PATH] = documents[
            checker.MINT_SPEC_PATH
        ].replace(
            "uint256[] memory tokenIds,\n    bytes32 operationRoot,\n"
            "    bytes32[] memory operationIds",
            "uint256[] memory tokenIds,\n    bytes32[] memory operationIds,\n"
            "    bytes32 operationRoot",
            1,
        )

        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "operation identity ABI declaration drifted",
        ):
            checker.validate_operation_abi(documents)

    def test_rejects_target_operation_event_index_drift(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        documents = {
            path: (repo_root / path).read_text(encoding="utf-8")
            for path in (
                checker.MINT_SPEC_PATH,
                checker.REVENUE_DOC_PATH,
                checker.ENTROPY_SPEC_PATH,
                checker.CONFORMANCE_PATH,
            )
        }
        documents[checker.MINT_SPEC_PATH] = documents[
            checker.MINT_SPEC_PATH
        ].replace(
            "bytes32 indexed operationRoot,\n    address indexed manager,",
            "bytes32 operationRoot,\n    address indexed manager,",
            1,
        )

        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "MintLedgerOperationRootConsumed target event signature/field layout drifted",
        ):
            checker.validate_operation_events(documents)

    def test_rejects_target_operation_event_unindexed_name_drift(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        documents = {
            path: (repo_root / path).read_text(encoding="utf-8")
            for path in (
                checker.MINT_SPEC_PATH,
                checker.REVENUE_DOC_PATH,
                checker.ENTROPY_SPEC_PATH,
                checker.CONFORMANCE_PATH,
            )
        }
        documents[checker.MINT_SPEC_PATH] = documents[
            checker.MINT_SPEC_PATH
        ].replace(
            "bytes32 authorizationId\n);\n\n"
            "event MintLedgerCounterConsumed",
            "bytes32 replayId\n);\n\n"
            "event MintLedgerCounterConsumed",
            1,
        )

        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "MintLedgerOperationRootConsumed target event signature/field layout drifted",
        ):
            checker.validate_operation_events(documents)


if __name__ == "__main__":
    unittest.main()
