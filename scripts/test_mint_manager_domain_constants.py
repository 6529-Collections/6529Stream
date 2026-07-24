#!/usr/bin/env python3
"""Focused tests for the StreamMintManager domain constant checker."""

from __future__ import annotations

import importlib.util
import re
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


def operation_preimage_fixture(
    *,
    replacement: tuple[str, int, str] | None = None,
) -> str:
    blocks: list[str] = []
    for variable_name, terms in checker.TARGET_OPERATION_PREIMAGES.items():
        rendered_terms = list(terms)
        if replacement is not None and replacement[0] == variable_name:
            rendered_terms[replacement[1]] = replacement[2]
        blocks.append(
            f"bytes32 {variable_name} = keccak256(abi.encode("
            + ", ".join(rendered_terms)
            + "));"
        )
    return "\n".join(blocks)


def committed_operation_documents() -> dict[Path, str]:
    repo_root = SCRIPT_PATH.parent.parent
    paths = (
        set(checker.OPERATION_IDENTITY_FRAGMENTS)
        | {
            checker.DOC_PATH,
            checker.MINT_SPEC_PATH,
            checker.REVENUE_DOC_PATH,
            checker.ENTROPY_SPEC_PATH,
            checker.CONFORMANCE_PATH,
        }
    )
    return {
        path: (repo_root / path).read_text(encoding="utf-8")
        for path in paths
    }


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
        first_selector = checker.TARGET_OPERATION_SELECTORS[0][1]
        stale_spec = mint_spec.replace(
            f"`{first_selector}`", "`0x00000000`", 1
        )

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

    def test_rejects_every_operation_preimage_field_mutation(self) -> None:
        for variable_name, terms in checker.TARGET_OPERATION_PREIMAGES.items():
            for index, _term in enumerate(terms):
                with self.subTest(variable_name=variable_name, index=index):
                    mutated = operation_preimage_fixture(
                        replacement=(
                            variable_name,
                            index,
                            f"bytes32(mutated{index})",
                        )
                    )
                    with self.assertRaisesRegex(
                        checker.MintManagerDomainError,
                        rf"{variable_name} abi\.encode sequence drifted",
                    ):
                        checker.validate_operation_preimages(mutated)

    def test_rejects_operation_preimage_reordering(self) -> None:
        terms = list(checker.TARGET_OPERATION_PREIMAGES["operationRoot"])
        terms[2], terms[3] = terms[3], terms[2]
        reordered = operation_preimage_fixture().replace(
            ", ".join(checker.TARGET_OPERATION_PREIMAGES["operationRoot"]),
            ", ".join(terms),
            1,
        )

        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            r"operationRoot abi\.encode sequence drifted",
        ):
            checker.validate_operation_preimages(reordered)

    def test_rejects_every_operation_struct_field_mutation(self) -> None:
        mint_spec = (
            SCRIPT_PATH.parent.parent / checker.MINT_SPEC_PATH
        ).read_text(encoding="utf-8")
        for struct_name, fields in checker.TARGET_OPERATION_STRUCT_FIELDS.items():
            match = re.search(
                rf"\bstruct\s+{re.escape(struct_name)}\s*\{{.*?\}}",
                mint_spec,
                re.DOTALL,
            )
            self.assertIsNotNone(match)
            assert match is not None
            for index, field in enumerate(fields):
                with self.subTest(struct_name=struct_name, field=field):
                    mutated_block, replacement_count = re.subn(
                        rf"(?m)^(?P<indent>\s*){re.escape(field)};\s*$",
                        rf"\g<indent>bytes32 mutatedField{index};",
                        match.group(0),
                        count=1,
                    )
                    self.assertEqual(replacement_count, 1)
                    mutated = (
                        mint_spec[: match.start()]
                        + mutated_block
                        + mint_spec[match.end() :]
                    )
                    with self.assertRaisesRegex(
                        checker.MintManagerDomainError,
                        rf"{struct_name} target struct fields drifted",
                    ):
                        checker.validate_operation_structs(mutated)

    def test_rejects_payable_manager_entry(self) -> None:
        mint_spec = (
            SCRIPT_PATH.parent.parent / checker.MINT_SPEC_PATH
        ).read_text(encoding="utf-8")
        payable_spec = mint_spec.replace(
            ") external returns (\n    uint256[] memory tokenIds,",
            ") external payable returns (\n    uint256[] memory tokenIds,",
            1,
        )

        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "must be nonpayable",
        ):
            checker.validate_manager_entry_ownership(payable_spec)

    def test_rejects_read_only_manager_mutability(self) -> None:
        mint_spec = (
            SCRIPT_PATH.parent.parent / checker.MINT_SPEC_PATH
        ).read_text(encoding="utf-8")
        for mutability in ("view", "pure"):
            with self.subTest(mutability=mutability):
                mutated = mint_spec.replace(
                    ") external returns (\n    uint256[] memory tokenIds,",
                    f") external {mutability} returns (\n"
                    "    uint256[] memory tokenIds,",
                    1,
                )
                self.assertNotEqual(mutated, mint_spec)
                with self.assertRaisesRegex(
                    checker.MintManagerDomainError,
                    "must be nonpayable",
                ):
                    checker.validate_manager_entry_ownership(mutated)

    def test_rejects_generic_callback_manager_surfaces(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        mint_spec = (repo_root / checker.MINT_SPEC_PATH).read_text(
            encoding="utf-8"
        )
        mutations = {
            "settlementData": (
                "bytes calldata gateData\n) external returns",
                "bytes calldata gateData,\n"
                "    bytes calldata settlementData\n) external returns",
            ),
            "callbackTarget": (
                "bytes calldata gateData\n) external returns",
                "bytes calldata gateData,\n"
                "    address callbackTarget\n) external returns",
            ),
            "callbackSelector": (
                "bytes calldata gateData\n) external returns",
                "bytes calldata gateData,\n"
                "    bytes4 callbackSelector\n) external returns",
            ),
            "callbackValue": (
                "bytes calldata gateData\n) external returns",
                "bytes calldata gateData,\n"
                "    uint256 callbackValue\n) external returns",
            ),
            "delegatecall": (
                "function nextOperationNonce()",
                "callbackTarget.delegatecall(callbackData);\n\n"
                "function nextOperationNonce()",
            ),
            "call-value": (
                "function nextOperationNonce()",
                "callbackTarget.call{value: callbackValue}(callbackData);\n\n"
                "function nextOperationNonce()",
            ),
        }
        for name, (old, new) in mutations.items():
            with self.subTest(name=name):
                mutated = mint_spec.replace(old, new, 1)
                self.assertNotEqual(mutated, mint_spec)
                with self.assertRaises(checker.MintManagerDomainError):
                    checker.validate_manager_entry_ownership(mutated)

        out_of_block_callback = (
            mint_spec
            + "\n```solidity\n"
            + "function callback(bytes calldata settlementData) external;\n"
            + "```\n"
        )
        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "forbidden callback surface",
        ):
            checker.validate_manager_entry_ownership(out_of_block_callback)

    def test_rejects_co_live_superseded_manager_mint(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        mint_spec = (repo_root / checker.MINT_SPEC_PATH).read_text(
            encoding="utf-8"
        )
        mutated = (
            mint_spec
            + "\n```solidity\n"
            + "function mint(MintBatch calldata batch, bytes calldata gateData) "
            + "external;\n"
            + "```\n"
        )

        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            r"superseded mint\(MintBatch,bytes\) declaration remains co-live",
        ):
            checker.validate_manager_entry_ownership(mutated)

    def test_rejects_adapter_external_caller_preview(self) -> None:
        documents = committed_operation_documents()
        documents[checker.MINT_SPEC_PATH] = documents[
            checker.MINT_SPEC_PATH
        ].replace(
            "and exactly `address(this)` for the executor term",
            "and the adapter external caller for the executor term",
            1,
        )

        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "operation identity contract drifted",
        ):
            checker.validate_operation_identity_fragments(documents)

    def test_rejects_unsourced_ungated_authorizer_kind(self) -> None:
        documents = committed_operation_documents()
        mutations = (
            (
                "`uint8(AuthorizerKind.NONE)`",
                "`uint8(AuthorizerKind.CALLER_ADAPTER)`",
            ),
            (
                "`batch.authorizer == address(0)`",
                "`batch.authorizer == msg.sender`",
            ),
        )
        for old, new in mutations:
            with self.subTest(mutation=new):
                mutated = dict(documents)
                mutated[checker.MINT_SPEC_PATH] = documents[
                    checker.MINT_SPEC_PATH
                ].replace(old, new, 1)
                self.assertNotEqual(
                    mutated[checker.MINT_SPEC_PATH],
                    documents[checker.MINT_SPEC_PATH],
                )
                with self.assertRaisesRegex(
                    checker.MintManagerDomainError,
                    "operation identity contract drifted",
                ):
                    checker.validate_operation_identity_fragments(mutated)

    def test_rejects_accepted_adr0018_status(self) -> None:
        documents = committed_operation_documents()
        documents[checker.ADR_0018_PATH] = documents[
            checker.ADR_0018_PATH
        ].replace(
            "Proposed only for the pre-genesis production target",
            "Accepted for the pre-genesis production target",
            1,
        )

        with self.assertRaises(checker.MintManagerDomainError):
            checker.validate_operation_identity_fragments(documents)

    def test_rejects_accepted_adr0018_index_status(self) -> None:
        documents = committed_operation_documents()
        documents[checker.ADR_INDEX_PATH] = documents[
            checker.ADR_INDEX_PATH
        ].replace(
            "| Proposed |",
            "| Accepted |",
            1,
        )

        with self.assertRaises(checker.MintManagerDomainError):
            checker.validate_operation_identity_fragments(documents)

    def test_rejects_operation_id_terminology_regression(self) -> None:
        documents = committed_operation_documents()
        mutations = (
            (
                checker.BACKLOG_PATH,
                "one root plus `N` token\n   operation IDs",
                "one root plus `N` token IDs",
            ),
            (
                checker.ADR_0018_PATH,
                "all token operation IDs",
                "all token IDs",
            ),
            (
                checker.MINT_SPEC_PATH,
                "root, per-token operation IDs",
                "root, per-token IDs",
            ),
        )
        for path, old, new in mutations:
            with self.subTest(path=path):
                mutated = dict(documents)
                mutated[path] = documents[path].replace(old, new, 1)
                self.assertNotEqual(mutated[path], documents[path])
                with self.assertRaises(checker.MintManagerDomainError):
                    checker.validate_operation_identity_fragments(mutated)

    def test_rejects_sale_authorization_content_binding_drift(self) -> None:
        documents = committed_operation_documents()
        for field in ("tokenDataArrayHash", "mintCommitmentsHash"):
            with self.subTest(field=field):
                mutated = dict(documents)
                mutated[checker.SALES_SPEC_PATH] = documents[
                    checker.SALES_SPEC_PATH
                ].replace(
                    f"bytes32 {field}",
                    f"bytes32 stale{field[0].upper() + field[1:]}",
                    1,
                )
                with self.assertRaisesRegex(
                    checker.MintManagerDomainError,
                    "SALE_AUTHORIZATION_TYPEHASH type string drifted",
                ):
                    checker.validate_sale_authorization_typehash(
                        mutated,
                        keccak_fn=lambda _: checker.SALE_AUTHORIZATION_TYPEHASH,
                    )

    def test_rejects_sale_authorization_typehash_mirror_drift(self) -> None:
        documents = committed_operation_documents()
        documents[checker.DOC_PATH] = documents[checker.DOC_PATH].replace(
            checker.SALE_AUTHORIZATION_TYPEHASH,
            "0x" + "00" * 32,
            1,
        )

        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "protocol-v1 mirror row missing or drifted",
        ):
            checker.validate_sale_authorization_typehash(
                documents,
                keccak_fn=lambda _: checker.SALE_AUTHORIZATION_TYPEHASH,
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
        documents[checker.MINT_SPEC_PATH] += (
            "\n<!-- function executeSingleStepMint( MintBatch calldata batch, "
            "bytes calldata gateData ) external returns ( uint256[] memory tokenIds, "
            "bytes32 operationRoot, bytes32[] memory operationIds ); -->\n"
        )

        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "operation identity ABI declaration drifted",
        ):
            checker.validate_operation_abi(documents)

    def test_rejects_conflicting_duplicate_operation_abi_declaration(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        documents = {
            path: (repo_root / path).read_text(encoding="utf-8")
            for path in checker.TARGET_OPERATION_ABI_FRAGMENTS
        }
        documents[checker.MINT_SPEC_PATH] += (
            "\n```solidity\n"
            "function consume(bytes32 operationRoot) external;\n"
            "```\n"
        )

        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "consume must have exactly one Solidity declaration",
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
