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


def mutate_table_row_cell(
    markdown: str,
    row_key: str,
    column_index: int,
    replacement: str,
) -> str:
    matches = 0
    output: list[str] = []
    for raw_line in markdown.splitlines(keepends=True):
        newline = "\n" if raw_line.endswith("\n") else ""
        line = raw_line.removesuffix("\n")
        stripped = line.strip()
        if stripped.startswith("|") and stripped.endswith("|"):
            cells = line.strip().strip("|").split("|")
            if cells and checker.normalize_cell(cells[0]) == row_key:
                cells[column_index] = f" {replacement} "
                line = "|" + "|".join(cells) + "|"
                matches += 1
        output.append(line + newline)
    if matches != 1:
        raise AssertionError(
            f"expected exactly one table row for {row_key}, found {matches}"
        )
    return "".join(output)


def exact_table_row_line(markdown: str, row_key: str) -> str:
    matches: list[str] = []
    for raw_line in markdown.splitlines():
        line = raw_line.strip()
        if not line.startswith("|") or not line.endswith("|"):
            continue
        cells = line.strip("|").split("|")
        if cells and checker.normalize_cell(cells[0]) == row_key:
            matches.append(raw_line)
    if len(matches) != 1:
        raise AssertionError(
            f"expected one exact table row for {row_key}, found {len(matches)}"
        )
    return matches[0]


def exact_event_declaration(markdown: str, event_name: str) -> str:
    matches = re.findall(
        rf"\bevent\s+{re.escape(event_name)}\s*\(.*?\)\s*;",
        markdown,
        re.DOTALL,
    )
    if len(matches) != 1:
        raise AssertionError(
            f"expected one event declaration for {event_name}, found {len(matches)}"
        )
    return matches[0]


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
        documents = committed_operation_documents()
        name, _preimage = checker.TARGET_OPERATION_DOMAINS[0]
        mint_spec = documents[checker.MINT_SPEC_PATH]
        hash_match = re.search(
            rf"(?m)^\| `{name}` \|.*?\| `(?P<hash>0x[0-9a-f]{{64}})` \|$",
            mint_spec,
        )
        self.assertIsNotNone(hash_match)
        assert hash_match is not None
        stale_spec = (
            mint_spec[: hash_match.start("hash")]
            + "0x"
            + "00" * 32
            + mint_spec[hash_match.end("hash") :]
        )

        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "MINT_REQUEST_COMMITMENT_DOMAIN target hash drifted",
        ):
            checker.validate_operation_domains(
                stale_spec,
                documents[checker.DOC_PATH],
            )

    def test_rejects_target_operation_solidity_preimage_drift(self) -> None:
        documents = committed_operation_documents()
        repo_root = SCRIPT_PATH.parent.parent
        source = (repo_root / checker.SOURCE_PATH).read_text(encoding="utf-8")
        name, preimage = checker.TARGET_OPERATION_DOMAINS[0]
        stale_source = source.replace(preimage, f"{preimage}_DRIFT", 1)
        self.assertNotEqual(stale_source, source)

        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            rf"{name} Solidity implementation preimage/cardinality drifted",
        ):
            checker.validate_operation_domains(
                documents[checker.MINT_SPEC_PATH],
                documents[checker.DOC_PATH],
                source_text=stale_source,
            )

    def test_rejects_superseded_operation_domain_in_solidity(self) -> None:
        documents = committed_operation_documents()
        repo_root = SCRIPT_PATH.parent.parent
        source = (repo_root / checker.SOURCE_PATH).read_text(encoding="utf-8")
        stale_source = source.replace(
            "contract StreamMintManager",
            "bytes32 public constant OPERATION_DOMAIN = "
            'keccak256("6529STREAM_PREPARED_MINT_OPERATION_V1");\n'
            "contract StreamMintManager",
            1,
        )
        self.assertNotEqual(stale_source, source)

        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "superseded OPERATION_DOMAIN remains co-live",
        ):
            checker.validate_operation_domains(
                documents[checker.MINT_SPEC_PATH],
                documents[checker.DOC_PATH],
                source_text=stale_source,
            )

    def test_rejects_linked_identity_library_preimage_drift(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        source = (repo_root / checker.IDENTITY_SOURCE_PATH).read_text(encoding="utf-8")
        name, preimage = checker.IDENTITY_LIBRARY_DOMAINS[0]
        stale_source = source.replace(preimage, f"{preimage}_DRIFT", 1)
        self.assertNotEqual(stale_source, source)

        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            rf"{name} linked identity-library preimage/cardinality drifted",
        ):
            checker.validate_identity_library_domains(stale_source)

    def test_rejects_missing_linked_identity_library_domain(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        source = (repo_root / checker.IDENTITY_SOURCE_PATH).read_text(encoding="utf-8")
        name, preimage = checker.IDENTITY_LIBRARY_DOMAINS[-1]
        assignment = re.search(
            rf'\bbytes32\s+private\s+constant\s+{re.escape(name)}\s*=\s*'
            rf'keccak256\(\s*"{re.escape(preimage)}"\s*\)\s*;',
            source,
            re.DOTALL,
        )
        self.assertIsNotNone(assignment)
        assert assignment is not None
        stale_source = source[: assignment.start()] + source[assignment.end() :]

        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            rf"{name} linked identity-library preimage/cardinality drifted",
        ):
            checker.validate_identity_library_domains(stale_source)

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
        mint_spec = committed_operation_documents()[checker.MINT_SPEC_PATH]
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
            )

    def test_rejects_legacy_consume_selector_and_signature(self) -> None:
        documents = committed_operation_documents()
        mint_spec = documents[checker.MINT_SPEC_PATH]
        selector_mutation = mint_spec.replace(
            "`0x82e8f383`",
            "`0x79e9746a`",
            1,
        )
        self.assertNotEqual(selector_mutation, mint_spec)
        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "operation identity selector row missing or drifted",
        ):
            checker.validate_operation_selectors(selector_mutation)

        legacy_abi = mint_spec.replace(
            "function consume(\n"
            "    uint256 collectionId,\n"
            "    bytes32 phaseId,\n"
            "    CounterConsumption[] calldata consumptions,",
            "function consume(\n"
            "    CounterConsumption[] calldata consumptions,",
            1,
        )
        self.assertNotEqual(legacy_abi, mint_spec)
        documents[checker.MINT_SPEC_PATH] = legacy_abi
        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "consume ABI declaration block drifted",
        ):
            checker.validate_operation_abi(documents)

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
            "executor term is exactly the adapter's `address(this)`",
            "executor term is the adapter's external caller",
            1,
        )
        self.assertNotEqual(
            documents[checker.MINT_SPEC_PATH],
            committed_operation_documents()[checker.MINT_SPEC_PATH],
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

    def test_rejects_proposed_adr0018_status(self) -> None:
        documents = committed_operation_documents()
        documents[checker.ADR_0018_PATH] = documents[
            checker.ADR_0018_PATH
        ].replace(
            "Accepted for pre-genesis implementation on 2026-07-26",
            "Proposed only for the pre-genesis production target",
            1,
        )

        with self.assertRaises(checker.MintManagerDomainError):
            checker.validate_operation_identity_fragments(documents)

    def test_rejects_proposed_adr0018_index_status(self) -> None:
        documents = committed_operation_documents()
        documents[checker.ADR_INDEX_PATH] = documents[
            checker.ADR_INDEX_PATH
        ].replace(
            "(0018-batch-operation-root-and-token-identity.md) | Accepted |",
            "(0018-batch-operation-root-and-token-identity.md) | Proposed |",
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
                "per-token operation IDs, `currentPolicyHash`",
                "per-token IDs, `currentPolicyHash`",
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
            "protocol-v1 mirror Hash value drifted",
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

    def test_rejects_consume_phase_identity_omission_reorder_or_type_drift(
        self,
    ) -> None:
        documents = committed_operation_documents()
        mint_spec = documents[checker.MINT_SPEC_PATH]
        declaration = checker.TARGET_LEDGER_CONSUME_DECLARATION
        self.assertEqual(mint_spec.count(declaration), 1)
        mutations = (
            (
                "    uint256 collectionId,\n    bytes32 phaseId,\n",
                "    uint256 collectionId,\n",
            ),
            (
                "    uint256 collectionId,\n    bytes32 phaseId,\n",
                "    bytes32 phaseId,\n    uint256 collectionId,\n",
            ),
            (
                "    uint256 collectionId,\n    bytes32 phaseId,\n",
                "    bytes32 collectionId,\n    bytes32 phaseId,\n",
            ),
        )
        for old, new in mutations:
            with self.subTest(mutation=new):
                mutated_declaration = declaration.replace(old, new, 1)
                self.assertNotEqual(mutated_declaration, declaration)
                mutated = dict(documents)
                mutated[checker.MINT_SPEC_PATH] = mint_spec.replace(
                    declaration,
                    mutated_declaration,
                    1,
                )
                self.assertNotEqual(
                    mutated[checker.MINT_SPEC_PATH],
                    mint_spec,
                )
                with self.assertRaisesRegex(
                    checker.MintManagerDomainError,
                    "consume ABI declaration block drifted",
                ):
                    checker.validate_operation_abi(mutated)

    def test_rejects_removal_of_ledger_event_rollback_guarantee(self) -> None:
        documents = committed_operation_documents()
        adr = documents[checker.ADR_0018_PATH]
        canonical = (
            "receiver failure reverts all ledger writes, events, and the manager nonce\n"
            "reservation."
        )
        mutated_text = adr.replace(
            canonical,
            "receiver failure reverts all ledger writes and the manager nonce\n"
            "reservation.",
            1,
        )
        self.assertNotEqual(mutated_text, adr)
        documents[checker.ADR_0018_PATH] = mutated_text
        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "operation identity contract drifted",
        ):
            checker.validate_operation_identity_fragments(documents)

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

    def test_rejects_non_view_operation_preview(self) -> None:
        mint_spec = committed_operation_documents()[checker.MINT_SPEC_PATH]
        mutated = mint_spec.replace(
            ") external view returns (\n    bytes32 operationRoot,",
            ") external pure returns (\n    bytes32 operationRoot,",
            1,
        )
        self.assertNotEqual(mutated, mint_spec)
        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "previewSingleStepMintOperation must be external view",
        ):
            checker.validate_manager_entry_ownership(mutated)

    def test_rejects_duplicate_or_conflicting_selector_rows(self) -> None:
        mint_spec = committed_operation_documents()[checker.MINT_SPEC_PATH]
        signature, _selector = checker.TARGET_OPERATION_SELECTORS[0]
        mutated = (
            mint_spec
            + f"\n| `0x00000000` | `{signature}` |\n"
        )
        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "selector row cardinality/ownership drifted",
        ):
            checker.validate_operation_selectors(mutated)

    def test_rejects_arbitrary_extra_selector_table_row(self) -> None:
        mint_spec = committed_operation_documents()[checker.MINT_SPEC_PATH]
        mutated = mint_spec.replace(
            checker.OPERATION_SELECTOR_END_MARKER,
            "| `0xdeadbeef` | `arbitraryCallback(bytes)` |"
            + checker.OPERATION_SELECTOR_END_MARKER,
            1,
        )
        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "selector table membership drifted",
        ):
            checker.validate_operation_selectors(mutated)

    def test_rejects_duplicate_or_conflicting_operation_domain_mirrors(self) -> None:
        documents = committed_operation_documents()
        name, preimage = checker.TARGET_OPERATION_DOMAINS[0]
        mutated = (
            documents[checker.DOC_PATH]
            + f"\n| `{name}` | `{preimage}` | {'0x' + '00' * 32} | "
            "`StreamMintManager` | `1` | conflicting |\n"
        )
        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "cardinality/ownership drifted",
        ):
            checker.validate_operation_domains(
                documents[checker.MINT_SPEC_PATH],
                mutated,
            )

    def test_rejects_every_operation_domain_mirror_column_drift(self) -> None:
        documents = committed_operation_documents()
        name, _preimage = checker.TARGET_OPERATION_DOMAINS[0]
        columns = (
            (0, "Constant name"),
            (1, "String preimage"),
            (2, "Hash value"),
            (3, "Owner"),
            (4, "Schema version"),
            (5, "Inputs"),
        )
        for column_index, column_name in columns:
            with self.subTest(column=column_name):
                architecture = mutate_table_row_cell(
                    documents[checker.DOC_PATH],
                    name,
                    column_index,
                    f"mutated-{column_index}",
                )
                expected_error = (
                    "cardinality/ownership drifted"
                    if column_index == 0
                    else f"mirror {re.escape(column_name)} drifted"
                )
                with self.assertRaisesRegex(
                    checker.MintManagerDomainError,
                    expected_error,
                ):
                    checker.validate_operation_domains(
                        documents[checker.MINT_SPEC_PATH],
                        architecture,
                    )

    def test_rejects_duplicate_operation_domain_row_outside_home(self) -> None:
        documents = committed_operation_documents()
        name, preimage = checker.TARGET_OPERATION_DOMAINS[0]
        digest = checker.cast_keccak256(preimage)
        mint_spec = (
            documents[checker.MINT_SPEC_PATH]
            + f"\n| `{name}` | `{preimage}` | `{digest}` |\n"
        )
        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "operation-domain home row cardinality/ownership drifted",
        ):
            checker.validate_operation_domains(
                mint_spec,
                documents[checker.DOC_PATH],
            )

    def test_rejects_duplicate_sale_authorization_assignment(self) -> None:
        documents = committed_operation_documents()
        documents[checker.SALES_SPEC_PATH] += (
            "\nSALE_AUTHORIZATION_TYPEHASH = keccak256(\n"
            '    "SaleAuthorization(bytes32 conflicting)"\n'
            ");\n"
        )
        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "assignment cardinality/ownership drifted",
        ):
            checker.validate_sale_authorization_typehash(documents)

    def test_rejects_sale_authorization_assignment_moved_outside_owner(self) -> None:
        documents = committed_operation_documents()
        sales_text = documents[checker.SALES_SPEC_PATH]
        assignment_match = re.search(
            r"SALE_AUTHORIZATION_TYPEHASH\s*=\s*keccak256\s*"
            r"\(.*?\)\s*;",
            sales_text,
            re.DOTALL,
        )
        self.assertIsNotNone(assignment_match)
        assert assignment_match is not None
        assignment = assignment_match.group(0)
        documents[checker.SALES_SPEC_PATH] = (
            sales_text[: assignment_match.start()]
            + sales_text[assignment_match.end() :]
            + "\n"
            + assignment
            + "\n"
        )
        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "assignment cardinality/ownership drifted",
        ):
            checker.validate_sale_authorization_typehash(documents)

    def test_rejects_sale_authorization_assignment_in_every_non_owner_doc(
        self,
    ) -> None:
        documents = committed_operation_documents()
        assignment_match = re.search(
            r"SALE_AUTHORIZATION_TYPEHASH\s*=\s*keccak256\s*"
            r"\(.*?\)\s*;",
            documents[checker.SALES_SPEC_PATH],
            re.DOTALL,
        )
        self.assertIsNotNone(assignment_match)
        assert assignment_match is not None
        assignment = assignment_match.group(0)
        variants = (
            ("duplicate", assignment),
            (
                "conflicting",
                assignment.replace(
                    "SaleAuthorization(",
                    "SaleAuthorizationConflict(",
                    1,
                ),
            ),
        )
        for path in sorted(set(documents) - {checker.SALES_SPEC_PATH}):
            for label, candidate in variants:
                with self.subTest(path=path, variant=label):
                    mutated = dict(documents)
                    mutated[path] += "\n" + candidate + "\n"
                    with self.assertRaisesRegex(
                        checker.MintManagerDomainError,
                        re.escape(path.as_posix()),
                    ):
                        checker.validate_sale_authorization_typehash(mutated)

    def test_rejects_sale_authorization_assignment_relocated_to_every_non_owner_doc(
        self,
    ) -> None:
        documents = committed_operation_documents()
        sales_text = documents[checker.SALES_SPEC_PATH]
        assignment_match = re.search(
            r"SALE_AUTHORIZATION_TYPEHASH\s*=\s*keccak256\s*"
            r"\(.*?\)\s*;",
            sales_text,
            re.DOTALL,
        )
        self.assertIsNotNone(assignment_match)
        assert assignment_match is not None
        assignment = assignment_match.group(0)
        without_assignment = (
            sales_text[: assignment_match.start()]
            + sales_text[assignment_match.end() :]
        )
        for path in sorted(set(documents) - {checker.SALES_SPEC_PATH}):
            with self.subTest(path=path):
                mutated = dict(documents)
                mutated[checker.SALES_SPEC_PATH] = without_assignment
                mutated[path] += "\n" + assignment + "\n"
                with self.assertRaisesRegex(
                    checker.MintManagerDomainError,
                    re.escape(path.as_posix()),
                ):
                    checker.validate_sale_authorization_typehash(mutated)

    def test_sale_authorization_assignment_non_owner_paths_are_sorted(self) -> None:
        documents = committed_operation_documents()
        assignment_match = re.search(
            r"SALE_AUTHORIZATION_TYPEHASH\s*=\s*keccak256\s*"
            r"\(.*?\)\s*;",
            documents[checker.SALES_SPEC_PATH],
            re.DOTALL,
        )
        self.assertIsNotNone(assignment_match)
        assert assignment_match is not None
        assignment = assignment_match.group(0)
        non_owners = sorted(set(documents) - {checker.SALES_SPEC_PATH})
        selected = [non_owners[-1], non_owners[0]]
        mutated = dict(documents)
        for path in selected:
            mutated[path] += "\n" + assignment + "\n"
        with self.assertRaises(checker.MintManagerDomainError) as raised:
            checker.validate_sale_authorization_typehash(mutated)
        expected = sorted(path.as_posix() for path in selected)
        self.assertIn(f"non_owners={expected}", str(raised.exception))

    def test_rejects_duplicate_sale_authorization_rows_in_each_owner(self) -> None:
        documents = committed_operation_documents()
        for path in (checker.SALES_SPEC_PATH, checker.DOC_PATH):
            with self.subTest(path=path):
                mutated = dict(documents)
                mutated[path] += (
                    "\n| `SALE_AUTHORIZATION_TYPEHASH` | conflicting | "
                    f"{checker.SALE_AUTHORIZATION_TYPEHASH} | owner | `1` | bad |\n"
                )
                with self.assertRaisesRegex(
                    checker.MintManagerDomainError,
                    "cardinality/ownership drifted",
                ):
                    checker.validate_sale_authorization_typehash(
                        mutated,
                        keccak_fn=lambda _: checker.SALE_AUTHORIZATION_TYPEHASH,
                    )

    def test_rejects_sale_authorization_rows_in_every_non_owner_doc(self) -> None:
        documents = committed_operation_documents()
        sales_row = exact_table_row_line(
            documents[checker.SALES_SPEC_PATH],
            "SALE_AUTHORIZATION_TYPEHASH",
        )
        variants = (
            ("duplicate", sales_row),
            (
                "conflicting",
                sales_row.replace("sale adapters", "conflicting owner", 1),
            ),
        )
        non_owners = sorted(
            set(documents) - {checker.SALES_SPEC_PATH, checker.DOC_PATH}
        )
        for path in non_owners:
            for label, row in variants:
                with self.subTest(path=path, variant=label):
                    mutated = dict(documents)
                    mutated[path] += "\n" + row + "\n"
                    with self.assertRaisesRegex(
                        checker.MintManagerDomainError,
                        re.escape(path.as_posix()),
                    ):
                        checker.validate_sale_authorization_typehash(
                            mutated,
                            keccak_fn=lambda _: checker.SALE_AUTHORIZATION_TYPEHASH,
                        )

    def test_rejects_sale_authorization_rows_relocated_to_every_non_owner_doc(
        self,
    ) -> None:
        documents = committed_operation_documents()
        non_owners = sorted(
            set(documents) - {checker.SALES_SPEC_PATH, checker.DOC_PATH}
        )
        for owner in (checker.SALES_SPEC_PATH, checker.DOC_PATH):
            row = exact_table_row_line(
                documents[owner],
                "SALE_AUTHORIZATION_TYPEHASH",
            )
            without_row = documents[owner].replace(row, "", 1)
            self.assertNotEqual(without_row, documents[owner])
            for path in non_owners:
                with self.subTest(owner=owner, path=path):
                    mutated = dict(documents)
                    mutated[owner] = without_row
                    mutated[path] += "\n" + row + "\n"
                    with self.assertRaisesRegex(
                        checker.MintManagerDomainError,
                        re.escape(path.as_posix()),
                    ):
                        checker.validate_sale_authorization_typehash(
                            mutated,
                            keccak_fn=lambda _: checker.SALE_AUTHORIZATION_TYPEHASH,
                        )

    def test_rejects_every_sale_authorization_home_row_column_drift(self) -> None:
        documents = committed_operation_documents()
        for column_index, column_name in enumerate(
            (
                "Constant name",
                "String preimage",
                "Hash value",
                "Owner",
                "Schema version",
                "Inputs",
            )
        ):
            with self.subTest(column=column_name):
                mutated = dict(documents)
                mutated[checker.SALES_SPEC_PATH] = mutate_table_row_cell(
                    documents[checker.SALES_SPEC_PATH],
                    "SALE_AUTHORIZATION_TYPEHASH",
                    column_index,
                    f"mutated-{column_index}",
                )
                expected_error = (
                    "cardinality/ownership drifted"
                    if column_index == 0
                    else f"sales home {re.escape(column_name)} drifted"
                )
                with self.assertRaisesRegex(
                    checker.MintManagerDomainError,
                    expected_error,
                ):
                    checker.validate_sale_authorization_typehash(
                        mutated,
                        keccak_fn=lambda _: checker.SALE_AUTHORIZATION_TYPEHASH,
                    )

    def test_rejects_every_sale_authorization_architecture_column_drift(
        self,
    ) -> None:
        documents = committed_operation_documents()
        for column_index, column_name in enumerate(
            (
                "Constant name",
                "String preimage",
                "Hash value",
                "Owner",
                "Schema version",
                "Inputs",
            )
        ):
            with self.subTest(column=column_name):
                mutated = dict(documents)
                mutated[checker.DOC_PATH] = mutate_table_row_cell(
                    documents[checker.DOC_PATH],
                    "SALE_AUTHORIZATION_TYPEHASH",
                    column_index,
                    f"mutated-{column_index}",
                )
                expected_error = (
                    "cardinality/ownership drifted"
                    if column_index == 0
                    else f"protocol-v1 mirror {re.escape(column_name)} drifted"
                )
                with self.assertRaisesRegex(
                    checker.MintManagerDomainError,
                    expected_error,
                ):
                    checker.validate_sale_authorization_typehash(
                        mutated,
                        keccak_fn=lambda _: checker.SALE_AUTHORIZATION_TYPEHASH,
                    )

    def test_rejects_duplicate_or_conflicting_event_topic_rows(self) -> None:
        documents = committed_operation_documents()
        signature = checker.TARGET_OPERATION_EVENTS[0][0]
        name = signature.split("(", 1)[0]
        documents[checker.CONFORMANCE_PATH] += (
            f"\n| `{name}(bytes32)` | `{'0x' + '00' * 32}` | `bad` | mint ledger |\n"
        )
        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "topic mirror cardinality/ownership drifted",
        ):
            checker.validate_operation_events(documents)

    def test_rejects_arbitrary_extra_event_topic_table_row(self) -> None:
        documents = committed_operation_documents()
        documents[checker.CONFORMANCE_PATH] = documents[
            checker.CONFORMANCE_PATH
        ].replace(
            checker.EVENT_TOPIC_END_MARKER,
            "| `ArbitraryEvent(bytes32)` | `"
            + "0x"
            + "00" * 32
            + "` | `value` | arbitrary |"
            + checker.EVENT_TOPIC_END_MARKER,
            1,
        )
        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "topic table membership drifted",
        ):
            checker.validate_operation_events(documents)

    def test_rejects_duplicate_exact_target_event_declaration(self) -> None:
        documents = committed_operation_documents()
        event_match = re.search(
            r"\bevent MintLedgerOperationRootConsumed\s*\(.*?\)\s*;",
            documents[checker.MINT_SPEC_PATH],
            re.DOTALL,
        )
        self.assertIsNotNone(event_match)
        assert event_match is not None
        documents[checker.MINT_SPEC_PATH] += (
            "\n```solidity\n" + event_match.group(0) + "\n```\n"
        )
        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "event declaration cardinality/ownership drifted",
        ):
            checker.validate_operation_events(documents)

    def test_rejects_target_event_moved_to_wrong_document(self) -> None:
        documents = committed_operation_documents()
        event_match = re.search(
            r"\bevent TokenRoyaltySnapshotted\s*\(.*?\)\s*;",
            documents[checker.REVENUE_DOC_PATH],
            re.DOTALL,
        )
        self.assertIsNotNone(event_match)
        assert event_match is not None
        event = event_match.group(0)
        documents[checker.REVENUE_DOC_PATH] = (
            documents[checker.REVENUE_DOC_PATH][: event_match.start()]
            + documents[checker.REVENUE_DOC_PATH][event_match.end() :]
        )
        documents[checker.MINT_SPEC_PATH] += (
            "\n```solidity\n" + event + "\n```\n"
        )
        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "event declaration cardinality/ownership drifted",
        ):
            checker.validate_operation_events(documents)

    def test_rejects_each_target_event_in_every_non_owner_document(self) -> None:
        documents = committed_operation_documents()
        for signature, _topic, _indexed, _parameters in (
            checker.TARGET_OPERATION_EVENTS
        ):
            name = signature.split("(", 1)[0]
            owner = checker.TARGET_OPERATION_EVENT_OWNERS[name]
            declaration = exact_event_declaration(documents[owner], name)
            variants = (
                ("duplicate", declaration),
                ("conflicting", f"event {name}(bytes32 conflicting);"),
            )
            for path in sorted(set(documents) - {owner}):
                for label, candidate in variants:
                    with self.subTest(event=name, path=path, variant=label):
                        mutated = dict(documents)
                        mutated[path] += (
                            "\n```solidity\n" + candidate + "\n```\n"
                        )
                        with self.assertRaisesRegex(
                            checker.MintManagerDomainError,
                            re.escape(path.as_posix()),
                        ):
                            checker.validate_operation_events(mutated)

    def test_rejects_each_target_event_relocated_to_every_non_owner_document(
        self,
    ) -> None:
        documents = committed_operation_documents()
        for signature, _topic, _indexed, _parameters in (
            checker.TARGET_OPERATION_EVENTS
        ):
            name = signature.split("(", 1)[0]
            owner = checker.TARGET_OPERATION_EVENT_OWNERS[name]
            declaration = exact_event_declaration(documents[owner], name)
            without_declaration = documents[owner].replace(declaration, "", 1)
            self.assertNotEqual(without_declaration, documents[owner])
            for path in sorted(set(documents) - {owner}):
                with self.subTest(event=name, path=path):
                    mutated = dict(documents)
                    mutated[owner] = without_declaration
                    mutated[path] += (
                        "\n```solidity\n" + declaration + "\n```\n"
                    )
                    with self.assertRaisesRegex(
                        checker.MintManagerDomainError,
                        re.escape(path.as_posix()),
                    ):
                        checker.validate_operation_events(mutated)

    def test_rejects_each_event_topic_row_in_every_non_owner_document(
        self,
    ) -> None:
        documents = committed_operation_documents()
        for signature, _topic, _indexed, _parameters in (
            checker.TARGET_OPERATION_EVENTS
        ):
            name = signature.split("(", 1)[0]
            row = exact_table_row_line(
                documents[checker.CONFORMANCE_PATH],
                signature,
            )
            variants = (
                ("duplicate", row),
                (
                    "conflicting",
                    row.replace(signature, f"{name}(bytes32)", 1),
                ),
            )
            for path in sorted(set(documents) - {checker.CONFORMANCE_PATH}):
                for label, candidate in variants:
                    with self.subTest(event=name, path=path, variant=label):
                        mutated = dict(documents)
                        mutated[path] += "\n" + candidate + "\n"
                        with self.assertRaisesRegex(
                            checker.MintManagerDomainError,
                            re.escape(path.as_posix()),
                        ):
                            checker.validate_operation_events(mutated)

    def test_rejects_each_event_topic_row_relocated_to_every_non_owner_document(
        self,
    ) -> None:
        documents = committed_operation_documents()
        for signature, _topic, _indexed, _parameters in (
            checker.TARGET_OPERATION_EVENTS
        ):
            name = signature.split("(", 1)[0]
            row = exact_table_row_line(
                documents[checker.CONFORMANCE_PATH],
                signature,
            )
            without_row = documents[checker.CONFORMANCE_PATH].replace(row, "", 1)
            self.assertNotEqual(
                without_row,
                documents[checker.CONFORMANCE_PATH],
            )
            for path in sorted(set(documents) - {checker.CONFORMANCE_PATH}):
                with self.subTest(event=name, path=path):
                    mutated = dict(documents)
                    mutated[checker.CONFORMANCE_PATH] = without_row
                    mutated[path] += "\n" + row + "\n"
                    with self.assertRaisesRegex(
                        checker.MintManagerDomainError,
                        re.escape(path.as_posix()),
                    ):
                        checker.validate_operation_events(mutated)

    def test_rejects_snapshot_event_schema_version_not_first(self) -> None:
        documents = committed_operation_documents()
        revenue = documents[checker.REVENUE_DOC_PATH]
        mutated = revenue.replace(
            "event TokenRoyaltySnapshotted(\n    uint16 schemaVersion,\n"
            "    bytes32 indexed operationId,",
            "event TokenRoyaltySnapshotted(\n"
            "    bytes32 indexed operationId,\n    uint16 schemaVersion,",
            1,
        )
        self.assertNotEqual(mutated, revenue)
        documents[checker.REVENUE_DOC_PATH] = mutated
        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "TokenRoyaltySnapshotted target event signature/field layout drifted",
        ):
            checker.validate_operation_events(documents)

    def test_rejects_current_bound_or_grace_contract_regression(self) -> None:
        documents = committed_operation_documents()
        mutations = (
            (
                checker.MINT_SPEC_PATH,
                "`requireMintConsent(collectionId, phaseId, currentPolicyHash)`",
                "`requireMintConsent(collectionId, phaseId, boundPolicyHash)`",
            ),
            (
                checker.MINT_SPEC_PATH,
                "`boundPolicyHash` only when it equals that loaded current hash or "
                "the exact\n   stored immediate predecessor with adjacent revision "
                "and\n   `block.timestamp <= previousPolicyGraceUntil`.",
                "`boundPolicyHash` only when it equals that loaded current hash or "
                "the exact\n   stored immediate predecessor with adjacent revision "
                "and\n   `block.timestamp < previousPolicyGraceUntil`.",
            ),
            (
                checker.MINT_SPEC_PATH,
                "`gateResult.authorizer == batch.authorizer`",
                "`gateResult.authorizer == msg.sender`",
            ),
            (
                checker.MINT_SPEC_PATH,
                "Missing current-policy artist consent",
                "Missing predecessor-policy artist consent",
            ),
            (
                checker.MINT_SPEC_PATH,
                "Configured and ungated phases\n"
                "   both accept the current or valid immediate-predecessor identity.",
                "Ungated phases accept only the current identity.",
            ),
            (
                checker.ADR_0018_PATH,
                "The operation root explicitly\n"
                "binds `currentPolicyHash` then `boundPolicyHash`",
                "The operation root binds only `boundPolicyHash`",
            ),
            (
                checker.ADR_0018_PATH,
                "configured and ungated phases accept the current\n"
                "or valid immediate-predecessor identity",
                "configured phases accept a predecessor; ungated predecessor fails",
            ),
            (
                checker.MINT_SPEC_PATH,
                "Emit central manager batch and ledger root events with the root,\n"
                "    per-token operation IDs, `currentPolicyHash`, and "
                "`boundPolicyHash`.",
                "Emit all events with only `boundPolicyHash`.",
            ),
            (
                checker.MINT_SPEC_PATH,
                "Child counter, authorization, and nullifier ledger events include\n"
                "   `boundPolicyHash`; the central root event includes\n"
                "   `currentPolicyHash` and `boundPolicyHash`",
                "All ledger events include generic `policyHash`",
            ),
            (
                checker.MINT_SPEC_PATH,
                "`MintLedgerCounterConsumed` carries\n"
                "the `boundPolicyHash`, `operationRoot`, and cap/accounting values",
                "`MintLedgerCounterConsumed` carries\n"
                "the `policyHash`, `operationRoot`, and cap/accounting values",
            ),
            (
                checker.MINT_SPEC_PATH,
                "Preview returns `operationRoot` plus `operationIds`; it does not "
                "separately\n     return either policy hash.",
                "Every mint event, ledger consumption event, signed ticket, and "
                "preview\n     response must include the active `policyHash`.",
            ),
            (
                checker.REVENUE_DOC_PATH,
                "Sale adapter calls the manager-owned\n"
                "   `previewSingleStepMintOperation(batch, gateData)`.",
                "Sale adapter derives the root from the request and nonce.",
            ),
            (
                checker.REVENUE_DOC_PATH,
                "currentPolicyHash)` on the artist authority registry",
                "boundPolicyHash)` on the artist authority registry",
            ),
            (
                checker.REVENUE_DOC_PATH,
                "Mint manager passes the exact batch `collectionId` and `phaseId` "
                "to the\n   ledger. Using the manager caller as scope, the ledger "
                "independently loads\n   `currentPolicyHash` from that registered "
                "phase tuple",
                "Mint ledger verifies only the manager-registered policy hash",
            ),
            (
                checker.MINT_SPEC_PATH,
                "`consume` receives explicit `collectionId` and `phaseId`;\n"
                "   it never infers phase identity from `consumptions`, because a "
                "valid phase\n   may consume an empty counter array.",
                "`consume` infers phase identity from the first counter row.",
            ),
            (
                checker.MINT_SPEC_PATH,
                "`registeredPhasePolicyHashes[msg.sender][collectionId][phaseId]`",
                "`registeredPhasePolicyHashes[msg.sender][consumptions[0].phaseId]`",
            ),
            (
                checker.MINT_SPEC_PATH,
                "`row.collectionId == collectionId` and "
                "`row.phaseId == phaseId`",
                "counter rows may span phases",
            ),
            (
                checker.MINT_SPEC_PATH,
                "`consumptions` may be empty. The ledger still validates manager, "
                "explicit\n   phase, current/bound policy identity, root, "
                "authorization, and nullifiers",
                "empty consumptions revert",
            ),
            (
                checker.ADR_0018_PATH,
                "The caller never supplies\n"
                "`currentPolicyHash`, and the ledger never infers phase identity "
                "from counter\nrows or calls the manager.",
                "The caller supplies currentPolicyHash.",
            ),
            (
                checker.SALES_SPEC_PATH,
                "Central manager-batch and ledger-root-consumption facts expose both\n"
                "   `currentPolicyHash` and `boundPolicyHash`",
                "Every emitted sale, mint, or consumption policy hash is the "
                "same bound value",
            ),
        )
        for path, old, new in mutations:
            with self.subTest(path=path, mutation=new):
                mutated = dict(documents)
                mutated[path] = documents[path].replace(old, new, 1)
                self.assertNotEqual(mutated[path], documents[path])
                with self.assertRaises(checker.MintManagerDomainError):
                    checker.validate_operation_identity_fragments(mutated)

    def test_reports_missing_exact_selector_section_separately(self) -> None:
        mint_spec = committed_operation_documents()[checker.MINT_SPEC_PATH]
        mutated = mint_spec.replace(checker.OPERATION_SELECTOR_MARKER, "", 1)
        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "missing section marker: Operation-identity selector goldens",
        ):
            checker.validate_operation_selectors(mutated)

    def test_reports_missing_exact_domain_mirror_section_separately(self) -> None:
        documents = committed_operation_documents()
        architecture = documents[checker.DOC_PATH].replace(
            checker.ARCHITECTURE_OPERATION_DOMAIN_MARKER,
            "",
            1,
        )
        with self.assertRaisesRegex(
            checker.MintManagerDomainError,
            "missing section marker: ### Mint Manager And Ledger Extension",
        ):
            checker.validate_operation_domains(
                documents[checker.MINT_SPEC_PATH],
                architecture,
            )

    def test_rejects_current_bound_event_field_substitution(self) -> None:
        documents = committed_operation_documents()
        mint_spec = documents[checker.MINT_SPEC_PATH]
        mutations = (
            (
                "bytes32 currentPolicyHash,\n    bytes32 indexed boundPolicyHash,",
                "bytes32 boundPolicyHash,\n    bytes32 indexed boundPolicyHash,",
            ),
            (
                "bytes32 currentPolicyHash,\n    bytes32 boundPolicyHash\n);",
                "bytes32 boundPolicyHash,\n    bytes32 boundPolicyHash\n);",
            ),
        )
        for old, new in mutations:
            with self.subTest(mutation=new):
                mutated = dict(documents)
                mutated[checker.MINT_SPEC_PATH] = mint_spec.replace(old, new, 1)
                self.assertNotEqual(mutated[checker.MINT_SPEC_PATH], mint_spec)
                with self.assertRaisesRegex(
                    checker.MintManagerDomainError,
                    "target event signature/field layout drifted",
                ):
                    checker.validate_operation_events(mutated)


if __name__ == "__main__":
    unittest.main()
