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


if __name__ == "__main__":
    unittest.main()
