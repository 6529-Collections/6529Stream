#!/usr/bin/env python3
"""Validate StreamMintManager hash domains and operation identity against specs.

Also enforces the revenue-layer domain-string namespace rule
([RSR-DOMAINS] rule 4, ADR 0011 decision R12): every revenue-layer domain
string preimage in the revenue home table and its protocol v1 mirror must
start with ``6529STREAM_``.

The ADR 0018 target operation domains intentionally differ from the current
CON-014 Solidity/as-built table until the atomic implementation cutover. This
checker therefore validates them against their normative home and protocol-v1
mirror without pretending the current source already implements the target.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterable


DOC_PATH = Path("docs/launch-v1-target-architecture.md")
SOURCE_PATH = Path("smart-contracts/StreamMintManager.sol")
TABLE_HEADING = "### StreamMintManager Domain Constants"
SCHEMA_VERSION_CONSTANT = "SCHEMA_VERSION"
SCHEMA_VERSION = "1"


class MintManagerDomainError(RuntimeError):
    """Raised when the manager domain table, hashes, or Solidity constants drift."""


@dataclass(frozen=True)
class DomainSpec:
    name: str
    preimage: str
    owner: str
    schema_version: str
    inputs: str


EXPECTED_DOMAINS: tuple[DomainSpec, ...] = (
    DomainSpec(
        name="POLICY_DOMAIN",
        preimage="6529STREAM_MINT_MANAGER_POLICY_V1",
        owner="StreamMintManager",
        schema_version=SCHEMA_VERSION,
        inputs=(
            "POLICY_DOMAIN; uint256(block.chainid); address(this); "
            "address(mintLedger); address(moduleRegistry); SCHEMA_VERSION; collectionId; "
            "phaseId; _phaseConfigHash(config); _gateConfigHash(gateConfig); "
            "_orderedCounterConfigHash(collectionId, phaseId); _executorSetHash(collectionId, phaseId)"
        ),
    ),
    DomainSpec(
        name="PHASE_CONFIG_DOMAIN",
        preimage="6529STREAM_MINT_MANAGER_PHASE_CONFIG_V1",
        owner="StreamMintManager",
        schema_version=SCHEMA_VERSION,
        inputs=(
            "PHASE_CONFIG_DOMAIN; config.paused; config.startTime; config.endTime; "
            "config.maxBatchQuantity; config.configHash; config.metadataHash"
        ),
    ),
    DomainSpec(
        name="COUNTER_CONFIG_DOMAIN",
        preimage="6529STREAM_MINT_MANAGER_COUNTER_CONFIG_V1",
        owner="StreamMintManager",
        schema_version=SCHEMA_VERSION,
        inputs=(
            "COUNTER_CONFIG_DOMAIN; counterId; config.enabled; config.keyMode; "
            "config.capMode; config.deltaMode; config.staticCap; "
            "config.staticIncrement; config.counterConfigHash"
        ),
    ),
    DomainSpec(
        name="GATE_CONFIG_DOMAIN",
        preimage="6529STREAM_MINT_MANAGER_GATE_CONFIG_V1",
        owner="StreamMintManager",
        schema_version=SCHEMA_VERSION,
        inputs=(
            "GATE_CONFIG_DOMAIN; gateConfig.gate; gateConfig.gateConfigHash; "
            "gateConfig.gateCodehash; gateConfig.gateMetadataHash; "
            "gateConfig.gateSemanticVersion; gateConfig.gateGasLimit"
        ),
    ),
    DomainSpec(
        name="EXECUTOR_SET_DOMAIN",
        preimage="6529STREAM_MINT_MANAGER_EXECUTOR_SET_V1",
        owner="StreamMintManager",
        schema_version=SCHEMA_VERSION,
        inputs="EXECUTOR_SET_DOMAIN; sorted phase executor addresses",
    ),
    DomainSpec(
        name="SUBJECT_DOMAIN",
        preimage="6529STREAM_MINT_COUNTER_SUBJECT_V1",
        owner="StreamMintManager",
        schema_version=SCHEMA_VERSION,
        inputs=(
            "SUBJECT_DOMAIN; uint256(block.chainid); address(mintLedger); keyMode; "
            "constant mode: collectionId, phaseId, counterId; address modes: account; "
            "context mode: contextHash"
        ),
    ),
    DomainSpec(
        name="RESOLUTION_DOMAIN",
        preimage="6529STREAM_MINT_COUNTER_RESOLUTION_V1",
        owner="StreamMintManager",
        schema_version=SCHEMA_VERSION,
        inputs=(
            "RESOLUTION_DOMAIN; uint256(block.chainid); address(this); "
            "address(mintLedger); collectionId; phaseId; counterId; subjectKey; "
            "tokenIndex; counterConfigHash"
        ),
    ),
    DomainSpec(
        name="OPERATION_DOMAIN",
        preimage="6529STREAM_PREPARED_MINT_OPERATION_V1",
        owner="StreamMintManager",
        schema_version=SCHEMA_VERSION,
        inputs=(
            "OPERATION_DOMAIN; uint256(block.chainid); address(this); address(core); "
            "address(mintLedger); collectionId; phaseId; policyHash; authorizationId; "
            "requestCommitmentHash(payer, authorizer, initialRecipientsHash, "
            "beneficiariesHash, tokenDataHash, saltsHash); contextHash; msg.sender; "
            "operationNonce; quantity"
        ),
    ),
)


def normalize_cell(value: str) -> str:
    cell = value.strip()
    if cell.startswith("`") and cell.endswith("`") and len(cell) >= 2:
        cell = cell[1:-1]
    return " ".join(cell.split())


def extract_section(markdown: str) -> str:
    start = markdown.find(TABLE_HEADING)
    if start == -1:
        raise MintManagerDomainError(f"missing heading: {TABLE_HEADING}")
    next_heading = re.search(r"^## ", markdown[start + len(TABLE_HEADING) :], re.MULTILINE)
    if next_heading is None:
        return markdown[start:]
    return markdown[start : start + len(TABLE_HEADING) + next_heading.start()]


def parse_domain_table(markdown: str) -> dict[str, dict[str, str]]:
    section = extract_section(markdown)
    rows: dict[str, dict[str, str]] = {}
    headers: list[str] | None = None
    for raw_line in section.splitlines():
        line = raw_line.strip()
        if not line.startswith("|") or not line.endswith("|"):
            continue
        cells = [normalize_cell(cell) for cell in line.strip("|").split("|")]
        if set(cells) <= {"---"}:
            continue
        if headers is None:
            headers = cells
            continue
        if len(cells) != len(headers):
            raise MintManagerDomainError(f"malformed domain table row: {raw_line}")
        row = dict(zip(headers, cells))
        name = row.get("Constant name")
        if name is None:
            raise MintManagerDomainError("domain table missing Constant name column")
        if name in rows:
            raise MintManagerDomainError(f"duplicate domain table row: {name}")
        rows[name] = row
    if headers is None:
        raise MintManagerDomainError("missing StreamMintManager domain table")
    return rows


def parse_solidity_constants(source: str) -> tuple[dict[str, str], str]:
    constants = {
        match.group("name"): match.group("preimage")
        for match in re.finditer(
            r"bytes32\s+public\s+constant\s+(?P<name>[A-Z0-9_]+)\s*=\s*"
            r"keccak256\(\s*\"(?P<preimage>[^\"]+)\"\s*\)\s*;",
            source,
            re.DOTALL,
        )
    }
    schema_match = re.search(
        rf"uint16\s+public\s+constant\s+{SCHEMA_VERSION_CONSTANT}\s*=\s*(\d+)\s*;",
        source,
    )
    if schema_match is None:
        raise MintManagerDomainError(f"missing {SCHEMA_VERSION_CONSTANT} in {SOURCE_PATH}")
    return constants, schema_match.group(1)


def cast_keccak256(preimage: str) -> str:
    try:
        result = subprocess.run(
            ["cast", "keccak", preimage],
            check=True,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError as exc:
        raise MintManagerDomainError("cast is required to recompute keccak256 preimages") from exc
    except subprocess.CalledProcessError as exc:
        stderr = exc.stderr.strip()
        raise MintManagerDomainError(f"cast keccak failed for {preimage}: {stderr}") from exc
    digest = result.stdout.strip().lower()
    if not re.fullmatch(r"0x[0-9a-f]{64}", digest):
        raise MintManagerDomainError(f"cast returned invalid keccak256 digest: {digest}")
    return digest


def validate_documents(
    docs_text: str,
    source_text: str,
    *,
    domains: Iterable[DomainSpec] = EXPECTED_DOMAINS,
    keccak_fn: Callable[[str], str] = cast_keccak256,
) -> None:
    specs = {domain.name: domain for domain in domains}
    rows = parse_domain_table(docs_text)
    constants, schema_version = parse_solidity_constants(source_text)

    if set(rows) != set(specs):
        missing = sorted(set(specs) - set(rows))
        extra = sorted(set(rows) - set(specs))
        raise MintManagerDomainError(
            "StreamMintManager domain table mismatch"
            f"; missing={missing or '[]'} extra={extra or '[]'}"
        )
    if schema_version != SCHEMA_VERSION:
        raise MintManagerDomainError(
            f"{SCHEMA_VERSION_CONSTANT} drifted: expected {SCHEMA_VERSION}, got {schema_version}"
        )

    for name, spec in specs.items():
        if constants.get(name) != spec.preimage:
            raise MintManagerDomainError(
                f"{name} Solidity preimage drifted: expected {spec.preimage}, "
                f"got {constants.get(name) or '<missing>'}"
            )
        row = rows[name]
        expected_hash = keccak_fn(spec.preimage).lower()
        checks = {
            "String preimage": spec.preimage,
            "Hash value": expected_hash,
            "Owner": spec.owner,
            "Schema version": spec.schema_version,
            "Inputs": spec.inputs,
        }
        for column, expected in checks.items():
            actual = row.get(column)
            if actual != expected:
                raise MintManagerDomainError(
                    f"{name} {column} drifted: expected {expected!r}, got {actual!r}"
                )


REVENUE_DOC_PATH = Path("docs/revenue-splits-and-royalties.md")
REVENUE_NAMESPACE_PREFIX = "6529STREAM_"
MINT_SPEC_PATH = Path("docs/mint-policy-and-accounting.md")
SALES_SPEC_PATH = Path("docs/stream-sales-and-auctions.md")
ADR_0008_PATH = Path("docs/adr/0008-revenue-splits-and-royalty-resolver.md")
ADR_0018_PATH = Path("docs/adr/0018-batch-operation-root-and-token-identity.md")
ADR_INDEX_PATH = Path("docs/adr/README.md")
CONFORMANCE_PATH = Path("docs/launch-conformance-matrix.md")
ENTROPY_SPEC_PATH = Path("docs/stream-entropy-coordinator.md")
BACKLOG_PATH = Path("ops/EXECUTION_BACKLOG.md")
OPERATION_DOMAIN_MARKER = "Identity-domain constants [MPA-OPERATION-DOMAINS]:"
OPERATION_DOMAIN_END_MARKER = "\n```solidity"
ARCHITECTURE_OPERATION_DOMAIN_MARKER = (
    "### Mint Manager And Ledger Extension Mirror Rows"
)
ARCHITECTURE_OPERATION_DOMAIN_END_MARKER = (
    "\n### Sales And Auctions Mirror Rows"
)
OPERATION_SELECTOR_MARKER = (
    "Operation-identity selector goldens [MPA-OPERATION-SELECTORS]:"
)
OPERATION_SELECTOR_END_MARKER = "\nReturn types do not enter a selector."
SALES_DOMAIN_MARKER = "## Domain Constants And Typehashes"
SALES_DOMAIN_END_MARKER = "\n## Conformance Gates"
SALE_AUTHORIZATION_ASSIGNMENT_MARKER = "## Signed Sale Authorization"
SALE_AUTHORIZATION_ASSIGNMENT_END_MARKER = "\n## Fixed-Price Sales And Open Editions"
ARCHITECTURE_SALES_MARKER = "### Sales And Auctions Mirror Rows"
ARCHITECTURE_SALES_END_MARKER = "\n### Revenue Mirror Rows"
EVENT_TOPIC_MARKER = (
    "ADR 0018 target operation-event topic mirror [LCM-OPERATION-EVENTS]."
)
EVENT_TOPIC_END_MARKER = "\nChanging an indexed field set"
TARGET_OPERATION_DOMAINS: tuple[tuple[str, str], ...] = (
    ("MINT_REQUEST_COMMITMENT_DOMAIN", "6529STREAM_MINT_REQUEST_COMMITMENT_V1"),
    ("MINT_VALIDATED_RESULT_DOMAIN", "6529STREAM_MINT_VALIDATED_RESULT_V1"),
    (
        "MINT_COUNTER_CONSUMPTIONS_DOMAIN",
        "6529STREAM_MINT_COUNTER_CONSUMPTIONS_V1",
    ),
    ("MINT_NULLIFIERS_DOMAIN", "6529STREAM_MINT_NULLIFIERS_V1"),
    ("MINT_OPERATION_ROOT_DOMAIN", "6529STREAM_MINT_OPERATION_ROOT_V1"),
    ("MINT_TOKEN_OPERATION_ID_DOMAIN", "6529STREAM_MINT_TOKEN_OPERATION_ID_V1"),
    (
        "MINT_EXECUTION_PATH_SINGLE_STEP",
        "6529STREAM_MINT_EXECUTION_PATH_SINGLE_STEP_V1",
    ),
    ("MINT_EXECUTION_PATH_PREPARED", "6529STREAM_MINT_EXECUTION_PATH_PREPARED_V1"),
)
TARGET_OPERATION_DOMAIN_MIRROR_METADATA: dict[str, tuple[str, str, str]] = {
    "MINT_REQUEST_COMMITMENT_DOMAIN": (
        "StreamMintManager",
        "1",
        "interior composite; mint spec `[MPA-OPERATION]` "
        "(ADR 0011 decision R12; ADR 0018 proposal)",
    ),
    "MINT_VALIDATED_RESULT_DOMAIN": (
        "StreamMintManager",
        "1",
        "canonical gate/counter result composite; raw proof encodings excluded; "
        "mint spec `[MPA-OPERATION]` (ADR 0018 proposal)",
    ),
    "MINT_COUNTER_CONSUMPTIONS_DOMAIN": (
        "StreamMintManager",
        "1",
        "exact counter-order/token-index-order `CounterConsumption[]` composite; "
        "projected cap aggregation is separate; mint spec `[MPA-OPERATION]` "
        "(ADR 0018 proposal)",
    ),
    "MINT_NULLIFIERS_DOMAIN": (
        "StreamMintManager",
        "1",
        "ascending duplicate-free validated nullifier composite; mint spec "
        "`[MPA-OPERATION]` (ADR 0018 proposal)",
    ),
    "MINT_OPERATION_ROOT_DOMAIN": (
        "StreamMintManager",
        "1",
        "one root per manager batch; mint spec `[MPA-OPERATION]` "
        "(ADR 0018 proposal)",
    ),
    "MINT_TOKEN_OPERATION_ID_DOMAIN": (
        "StreamMintManager",
        "1",
        "per-token interior composite; mint spec `[MPA-OPERATION]` rule 1 "
        "(ADR 0012 decision T6; ADR 0018 proposal)",
    ),
    "MINT_EXECUTION_PATH_SINGLE_STEP": (
        "StreamMintManager",
        "1",
        "single-step execution-path identity; mint spec `[MPA-OPERATION]` "
        "(ADR 0018 proposal)",
    ),
    "MINT_EXECUTION_PATH_PREPARED": (
        "StreamMintManager",
        "1",
        "prepared execution-path identity; mint spec `[MPA-OPERATION]` "
        "(ADR 0018 proposal)",
    ),
}
TARGET_OPERATION_SELECTORS: tuple[tuple[str, str], ...] = (
    (
        "executeSingleStepMint((uint256,bytes32,address,address,address[],address[],"
        "bytes[],bytes32[],bytes32,bytes32,bytes32,bytes),bytes)",
        "0x286cd1d1",
    ),
    (
        "executePreparedMint((uint256,bytes32,address,address,address[],address[],"
        "bytes[],bytes32[],bytes32,bytes32,bytes32,bytes),bytes)",
        "0xc9281e5b",
    ),
    (
        "previewSingleStepMintOperation((uint256,bytes32,address,address,address[],"
        "address[],bytes[],bytes32[],bytes32,bytes32,bytes32,bytes),bytes)",
        "0xa5651f13",
    ),
    ("nextOperationNonce()", "0x37f8eaa5"),
    (
        "consume(uint256,bytes32,(bytes32,uint256,bytes32,bytes32,bytes32,address,"
        "address,address,address,uint64,uint64,bytes32,bytes32)[],bytes32,bytes32[],"
        "bytes32,bytes32)",
        "0x82e8f383",
    ),
    ("isManagerOperationRootUsed(address,bytes32)", "0xe67d8006"),
    ("isOperationRootUsed(bytes32)", "0x12837042"),
    (
        "snapshotTokenRoyaltyAtMint(uint256,uint256,bytes32,bytes32,bytes32,bytes32)",
        "0xc8323dfa",
    ),
)
TARGET_LEDGER_CONSUME_DECLARATION = """function consume(
    uint256 collectionId,
    bytes32 phaseId,
    CounterConsumption[] calldata consumptions,
    bytes32 authorizationId,
    bytes32[] calldata nullifiers,
    bytes32 boundPolicyHash,
    bytes32 operationRoot
) external;"""
TARGET_LEDGER_CONSUME_ABI_FRAGMENT = " ".join(
    TARGET_LEDGER_CONSUME_DECLARATION.split()
)
TARGET_OPERATION_ABI_FRAGMENTS: dict[Path, tuple[str, ...]] = {
    MINT_SPEC_PATH: (
        "function executeSingleStepMint( MintBatch calldata batch, "
        "bytes calldata gateData ) external "
        "returns ( uint256[] memory tokenIds, bytes32 operationRoot, "
        "bytes32[] memory operationIds );",
        "function executePreparedMint( MintBatch calldata batch, "
        "bytes calldata gateData ) external "
        "returns ( uint256[] memory tokenIds, bytes32 operationRoot, "
        "bytes32[] memory operationIds );",
        "function previewSingleStepMintOperation( MintBatch calldata batch, "
        "bytes calldata gateData ) external view "
        "returns ( bytes32 operationRoot, bytes32[] memory operationIds );",
        "function nextOperationNonce() external view returns (uint256);",
        TARGET_LEDGER_CONSUME_ABI_FRAGMENT,
        "function isManagerOperationRootUsed(address manager, bytes32 operationRoot) "
        "external view returns (bool);",
        "function isOperationRootUsed(bytes32 operationRoot) external view "
        "returns (bool);",
    ),
    REVENUE_DOC_PATH: (
        "function snapshotTokenRoyaltyAtMint( uint256 tokenId, "
        "uint256 collectionId, bytes32 operationRoot, bytes32 operationId, "
        "bytes32 revenueClass, bytes32 expectedRoyaltyAssignmentHash ) "
        "external returns (bytes32 tokenRoyaltyAssignmentHash);",
    ),
    ADR_0018_PATH: (
        TARGET_LEDGER_CONSUME_ABI_FRAGMENT,
    ),
}
TARGET_OPERATION_PREIMAGES: dict[str, tuple[str, ...]] = {
    "nullifiersHash": (
        "MINT_NULLIFIERS_DOMAIN",
        "canonicalNullifiers",
    ),
    "counterConsumptionsHash": (
        "MINT_COUNTER_CONSUMPTIONS_DOMAIN",
        "canonicalConsumptions",
    ),
    "validatedResultHash": (
        "MINT_VALIDATED_RESULT_DOMAIN",
        "address(gate)",
        "bytes32(batch.authorizationId)",
        "bytes32(nullifiersHash)",
        "address(validatedAuthorizer)",
        "uint8(validatedAuthorizerKind)",
        "uint64(validatedMaxQuantity)",
        "bytes32(validatedGateHash)",
        "bytes32(counterConsumptionsHash)",
    ),
    "requestCommitmentHash": (
        "MINT_REQUEST_COMMITMENT_DOMAIN",
        "address(payer)",
        "address(batch.authorizer)",
        "bytes32(batch.expectedPolicyHash)",
        "bytes32(initialRecipientsHash)",
        "bytes32(beneficiariesHash)",
        "bytes32(tokenDataArrayHash)",
        "bytes32(mintCommitmentsHash)",
        "bytes32(validatedResultHash)",
    ),
    "operationRoot": (
        "MINT_OPERATION_ROOT_DOMAIN",
        "uint256(block.chainid)",
        "address(this)",
        "address(core)",
        "address(mintLedger)",
        "bytes32(executionPath)",
        "uint256(collectionId)",
        "bytes32(phaseId)",
        "bytes32(currentPolicyHash)",
        "bytes32(boundPolicyHash)",
        "bytes32(batch.authorizationId)",
        "bytes32(requestCommitmentHash)",
        "bytes32(contextHash)",
        "address(msg.sender)",
        "uint256(firstOperationNonce)",
        "uint256(quantity)",
    ),
    "operationId": (
        "MINT_TOKEN_OPERATION_ID_DOMAIN",
        "bytes32(operationRoot)",
        "uint256(firstOperationNonce+tokenIndex)",
        "uint256(tokenIndex)",
        "bytes32(tokenDataHash)",
        "bytes32(mintCommitment)",
    ),
}
TARGET_MANAGER_ENTRY_PARAMETERS = (
    "MintBatchcalldatabatch",
    "bytescalldatagateData",
)
TARGET_MANAGER_ENTRY_RETURNS = (
    "uint256[]memorytokenIds",
    "bytes32operationRoot",
    "bytes32[]memoryoperationIds",
)
TARGET_MANAGER_PREVIEW_RETURNS = (
    "bytes32operationRoot",
    "bytes32[]memoryoperationIds",
)
TARGET_OPERATION_STRUCT_FIELDS: dict[str, tuple[str, ...]] = {
    "MintBatch": (
        "uint256 collectionId",
        "bytes32 phaseId",
        "address payer",
        "address authorizer",
        "address[] initialRecipients",
        "address[] beneficiaries",
        "bytes[] tokenData",
        "bytes32[] mintCommitments",
        "bytes32 expectedPolicyHash",
        "bytes32 authorizationId",
        "bytes32 contextHash",
        "bytes resolverData",
    ),
    "CounterConsumption": (
        "bytes32 valueKey",
        "uint256 collectionId",
        "bytes32 phaseId",
        "bytes32 counterId",
        "bytes32 subjectKey",
        "address payer",
        "address recipient",
        "address authorizer",
        "address executor",
        "uint64 increment",
        "uint64 cap",
        "bytes32 contextHash",
        "bytes32 resolutionHash",
    ),
    "GateResult": (
        "bytes32 authorizationId",
        "bytes32[] nullifiers",
        "address authorizer",
        "uint8 authorizerKind",
        "uint64 maxQuantity",
        "bytes32 gateHash",
    ),
}
SALE_AUTHORIZATION_TYPE_STRING = (
    "SaleAuthorization(uint256 chainId,address saleAdapter,address mintManager,"
    "uint256 collectionId,bytes32 phaseId,bytes32 saleId,uint8 saleKind,"
    "bytes32 revenueClass,bytes32 expectedPrimaryPolicyHash,"
    "uint8 primaryPolicyMode,bytes32 initialRecipientsHash,"
    "bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,"
    "bytes32 mintCommitmentsHash,address payer,address executor,address asset,"
    "uint256 unitPrice,uint256 quantity,bytes32 contentSelectionHash,"
    "bytes32 policyHash,bytes32 nonce,uint64 deadline,uint64 finalizeBy)"
)
SALE_AUTHORIZATION_TYPEHASH = (
    "0x6e5460498aa6274ffa516d53c6046a385c1ff9dd62d6adbfc54c339a4bb6e8d6"
)
SALE_AUTHORIZATION_HOME_ROW = {
    "Constant name": "SALE_AUTHORIZATION_TYPEHASH",
    "String preimage": "struct type string pinned in [SSA-AUTH]",
    "Hash value": SALE_AUTHORIZATION_TYPEHASH,
    "Owner": "sale adapters",
    "Schema version": "1",
    "Inputs": (
        "EIP-712 struct fields per [SSA-AUTH] (`bytes32 revenueClass`, "
        "`tokenDataArrayHash`, `mintCommitmentsHash`, and trailing "
        "`uint64 finalizeBy`; ADR 0011 decisions R6 and R10; ADR 0018 proposal)"
    ),
}
SALE_AUTHORIZATION_ARCHITECTURE_ROW = {
    "Constant name": "SALE_AUTHORIZATION_TYPEHASH",
    "String preimage": SALE_AUTHORIZATION_TYPE_STRING,
    "Hash value": SALE_AUTHORIZATION_TYPEHASH,
    "Owner": "sale adapters",
    "Schema version": "1",
    "Inputs": (
        "EIP-712 struct fields as listed; sales spec `[SSA-AUTH]` "
        "(`bytes32 revenueClass`, `tokenDataArrayHash`, `mintCommitmentsHash`, "
        "and trailing `uint64 finalizeBy`; ADR 0011 decisions R6 and R10; "
        "ADR 0018 proposal)"
    ),
}
TARGET_OPERATION_EVENTS: tuple[
    tuple[str, str, tuple[str, ...], tuple[str, ...]], ...
] = (
    (
        "MintLedgerOperationRootConsumed(uint16,bytes32,address,bytes32,bytes32,"
        "bytes32)",
        "0x32821c46b022bd0995b50921248ed67b1d69a27b6c7afcb0202dcb1fcbbebb24",
        ("operationRoot", "manager", "boundPolicyHash"),
        (
            "schemaVersion",
            "operationRoot",
            "manager",
            "currentPolicyHash",
            "boundPolicyHash",
            "authorizationId",
        ),
    ),
    (
        "MintLedgerCounterConsumed(uint16,bytes32,uint256,bytes32,address,bytes32,"
        "bytes32,uint64,uint64,uint64,bytes32,bytes32)",
        "0x82be7e1cfba45b84607ebae03dd739d908e1f7f47c467e76baabb4e64e53e888",
        ("valueKey", "collectionId", "phaseId"),
        (
            "schemaVersion",
            "valueKey",
            "collectionId",
            "phaseId",
            "manager",
            "counterId",
            "subjectKey",
            "increment",
            "newValue",
            "cap",
            "boundPolicyHash",
            "operationRoot",
        ),
    ),
    (
        "MintLedgerAuthorizationConsumed(uint16,bytes32,bytes32,address,bytes32)",
        "0x4ae914c98ae10051092be8a5fecc1584bd19371f9b629bc8a75a747a7eb77a80",
        ("authorizationId", "operationRoot", "manager"),
        (
            "schemaVersion",
            "authorizationId",
            "operationRoot",
            "manager",
            "boundPolicyHash",
        ),
    ),
    (
        "MintLedgerNullifierConsumed(uint16,bytes32,bytes32,address,bytes32)",
        "0x23bb00045254ab08fcfb223713983797db786dc4692827878cb7cef34f395b06",
        ("nullifier", "operationRoot", "manager"),
        (
            "schemaVersion",
            "nullifier",
            "operationRoot",
            "manager",
            "boundPolicyHash",
        ),
    ),
    (
        "MintBatchExecuted(uint16,bytes32,uint256,bytes32,address,address,address,"
        "uint256,uint256,bytes32,bytes32,bytes32,bytes32)",
        "0x4ea33b3409cbd25468bbab85511b2b4d12d4663b1225af0c8d845063a7f52415",
        ("operationRoot", "collectionId", "phaseId"),
        (
            "schemaVersion",
            "operationRoot",
            "collectionId",
            "phaseId",
            "executor",
            "payer",
            "authorizer",
            "firstTokenId",
            "quantity",
            "contextHash",
            "gateHash",
            "currentPolicyHash",
            "boundPolicyHash",
        ),
    ),
    (
        "MintAuthorizationConsumed(uint16,uint256,bytes32,bytes32,bytes32,bytes32)",
        "0x83fe1cd55fdb106a490131e3f5f7923949cb4abe4cb211e2d8d0e29232969c9b",
        ("collectionId", "phaseId", "authorizationId"),
        (
            "schemaVersion",
            "collectionId",
            "phaseId",
            "authorizationId",
            "boundPolicyHash",
            "operationRoot",
        ),
    ),
    (
        "MintTokenExecuted(uint16,bytes32,uint256,bytes32,uint256,bytes32,uint256,"
        "address,address,bytes32,bytes32)",
        "0x9a7828375f9c6ee3bf4a1308318e0f533ec7219823ec6b8e475529a60ebcdb8f",
        ("operationId", "tokenId", "operationRoot"),
        (
            "schemaVersion",
            "operationId",
            "tokenId",
            "operationRoot",
            "collectionId",
            "phaseId",
            "tokenIndex",
            "initialRecipient",
            "beneficiary",
            "tokenDataHash",
            "mintCommitment",
        ),
    ),
    (
        "PreparedMintStarted(uint16,bytes32,uint256,uint256,bytes32,uint256,address,"
        "bytes32,bytes32)",
        "0x1e2d8a1f460486b578f1af40819ce76be1d843363ec34b385fe331604f6817ac",
        ("operationId", "tokenId", "collectionId"),
        (
            "schemaVersion",
            "operationId",
            "tokenId",
            "collectionId",
            "operationRoot",
            "collectionSerial",
            "beneficiary",
            "tokenDataHash",
            "mintCommitment",
        ),
    ),
    (
        "PreparedMintCompleted(uint16,bytes32,uint256,uint256,bytes32,address)",
        "0x5e1526e787b4d79b30b4a423d4b531694eb879c8814cf7aadc233fe251aa80dc",
        ("operationId", "tokenId", "collectionId"),
        (
            "schemaVersion",
            "operationId",
            "tokenId",
            "collectionId",
            "operationRoot",
            "initialRecipient",
        ),
    ),
    (
        "TokenRoyaltySnapshotted(uint16,bytes32,uint256,bytes32,uint256,bytes32,"
        "bytes32)",
        "0x64ac79953c00686f9a6cf01fc972ff2b4395007acd76701973ae83ec0bfac491",
        ("operationId", "tokenId", "operationRoot"),
        (
            "schemaVersion",
            "operationId",
            "tokenId",
            "operationRoot",
            "collectionId",
            "revenueClass",
            "tokenRoyaltyAssignmentHash",
        ),
    ),
    (
        "PrimaryRevenueSettlementContext(bytes32,bytes32,bytes32,uint16,address,"
        "bytes32,uint8,uint256,uint256,bytes32,bytes32,uint256,address,address,"
        "bytes32)",
        "0x4df3ddabf618d53eea4adf5fb2991418d0ce412b0c9ffdf9c9f038e65de410fb",
        ("settlementKey", "revenueClass", "profileId"),
        (
            "settlementKey",
            "revenueClass",
            "profileId",
            "schemaVersion",
            "settlementCaller",
            "settlementId",
            "policyMode",
            "collectionId",
            "tokenId",
            "operationRoot",
            "operationId",
            "saleNonce",
            "poster",
            "beneficiary",
            "templateId",
        ),
    ),
    (
        "EntropyRegistered(uint16,uint256,uint256,address,bytes32)",
        "0x252241903fa837f87f928a854aa3e6a9b3233bc0f24a1e11fb3c99fbfa1fb3ee",
        ("collectionId", "tokenId", "mintedTo"),
        ("schemaVersion", "collectionId", "tokenId", "mintedTo", "mintCommitment"),
    ),
)
TARGET_OPERATION_EVENT_OWNERS: dict[str, Path] = {
    "MintLedgerOperationRootConsumed": MINT_SPEC_PATH,
    "MintLedgerCounterConsumed": MINT_SPEC_PATH,
    "MintLedgerAuthorizationConsumed": MINT_SPEC_PATH,
    "MintLedgerNullifierConsumed": MINT_SPEC_PATH,
    "MintBatchExecuted": MINT_SPEC_PATH,
    "MintAuthorizationConsumed": MINT_SPEC_PATH,
    "MintTokenExecuted": MINT_SPEC_PATH,
    "PreparedMintStarted": MINT_SPEC_PATH,
    "PreparedMintCompleted": MINT_SPEC_PATH,
    "TokenRoyaltySnapshotted": REVENUE_DOC_PATH,
    "PrimaryRevenueSettlementContext": REVENUE_DOC_PATH,
    "EntropyRegistered": ENTROPY_SPEC_PATH,
}
TARGET_OPERATION_EVENT_OWNER_LABELS: dict[str, str] = {
    "MintLedgerOperationRootConsumed": "mint ledger",
    "MintLedgerCounterConsumed": "mint ledger",
    "MintLedgerAuthorizationConsumed": "mint ledger",
    "MintLedgerNullifierConsumed": "mint ledger",
    "MintBatchExecuted": "mint manager",
    "MintAuthorizationConsumed": "mint manager",
    "MintTokenExecuted": "mint manager",
    "PreparedMintStarted": "mint manager",
    "PreparedMintCompleted": "mint manager",
    "TokenRoyaltySnapshotted": "revenue resolver",
    "PrimaryRevenueSettlementContext": "primary settlement",
    "EntropyRegistered": "entropy coordinator",
}
REVENUE_SECTION_MARKERS: tuple[tuple[Path, str, str], ...] = (
    (REVENUE_DOC_PATH, "Requirements [RSR-DOMAINS]:", "\n## "),
    (DOC_PATH, "### Revenue Mirror Rows", "\n### "),
)


def _extract_marked_section(markdown: str, start_marker: str, end_marker: str) -> str:
    start = markdown.find(start_marker)
    if start == -1:
        raise MintManagerDomainError(f"missing section marker: {start_marker}")
    end = markdown.find(end_marker, start + len(start_marker))
    if end == -1:
        raise MintManagerDomainError(
            f"missing section end marker {end_marker!r} after {start_marker!r}"
        )
    return markdown[start:end]


def parse_exact_markdown_table(
    markdown: str,
    start_marker: str,
    end_marker: str,
    expected_headers: tuple[str, ...],
    *,
    label: str,
) -> list[dict[str, str]]:
    section = _extract_marked_section(markdown, start_marker, end_marker)
    lines = section.splitlines()
    header_indexes: list[int] = []
    for index, raw_line in enumerate(lines):
        line = raw_line.strip()
        if not line.startswith("|") or not line.endswith("|"):
            continue
        cells = tuple(normalize_cell(cell) for cell in line.strip("|").split("|"))
        if cells == expected_headers:
            header_indexes.append(index)
    if len(header_indexes) != 1:
        raise MintManagerDomainError(
            f"{label} must contain exactly one target table header; "
            f"found {len(header_indexes)}"
        )
    header_index = header_indexes[0]
    if header_index + 1 >= len(lines):
        raise MintManagerDomainError(f"{label} table separator missing")
    separator = tuple(
        normalize_cell(cell)
        for cell in lines[header_index + 1].strip().strip("|").split("|")
    )
    if len(separator) != len(expected_headers) or set(separator) != {"---"}:
        raise MintManagerDomainError(f"{label} table separator drifted")
    rows: list[dict[str, str]] = []
    for raw_line in lines[header_index + 2 :]:
        line = raw_line.strip()
        if not line.startswith("|") or not line.endswith("|"):
            break
        cells = tuple(normalize_cell(cell) for cell in line.strip("|").split("|"))
        if len(cells) != len(expected_headers):
            raise MintManagerDomainError(
                f"malformed {label} row: expected {len(expected_headers)} cells, "
                f"got {len(cells)}: {line!r}"
            )
        rows.append(dict(zip(expected_headers, cells)))
    return rows


def markdown_table_row_count(
    markdown: str,
    *,
    column_index: int,
    predicate: Callable[[str], bool],
) -> int:
    count = 0
    for raw_line in markdown.splitlines():
        line = raw_line.strip()
        if not line.startswith("|") or not line.endswith("|"):
            continue
        cells = tuple(normalize_cell(cell) for cell in line.strip("|").split("|"))
        if column_index < len(cells) and predicate(cells[column_index]):
            count += 1
    return count


def validate_revenue_domain_prefixes(repo_root: Path) -> None:
    """Reject revenue-layer domain string preimages outside the 6529STREAM_ namespace."""
    for doc_path, start_marker, end_marker in REVENUE_SECTION_MARKERS:
        text = (repo_root / doc_path).read_text(encoding="utf-8")
        section = _extract_marked_section(text, start_marker, end_marker)
        headers: list[str] | None = None
        for raw_line in section.splitlines():
            line = raw_line.strip()
            if not line.startswith("|") or not line.endswith("|"):
                continue
            cells = [normalize_cell(cell) for cell in line.strip("|").split("|")]
            if set(cells) <= {"---"}:
                continue
            if headers is None or "String preimage" not in headers:
                headers = cells
                continue
            if len(cells) != len(headers):
                raise MintManagerDomainError(
                    f"malformed table row in {doc_path}: expected "
                    f"{len(headers)} cells, got {len(cells)}: {line!r}"
                )
            row = dict(zip(headers, cells))
            preimage = row.get("String preimage", "")
            if re.fullmatch(r"[A-Z0-9_]+", preimage) and not preimage.startswith(
                REVENUE_NAMESPACE_PREFIX
            ):
                raise MintManagerDomainError(
                    f"revenue-layer domain string {preimage!r} in {doc_path} lacks the "
                    f"{REVENUE_NAMESPACE_PREFIX} namespace prefix ([RSR-DOMAINS] rule 4)"
                )


def parse_operation_domain_table(markdown: str) -> dict[str, dict[str, str]]:
    section = _extract_marked_section(
        markdown, OPERATION_DOMAIN_MARKER, OPERATION_DOMAIN_END_MARKER
    )
    rows: dict[str, dict[str, str]] = {}
    headers: list[str] | None = None
    for raw_line in section.splitlines():
        line = raw_line.strip()
        if not line.startswith("|") or not line.endswith("|"):
            continue
        cells = [normalize_cell(cell) for cell in line.strip("|").split("|")]
        if set(cells) <= {"---"}:
            continue
        if headers is None:
            headers = cells
            continue
        if len(cells) != len(headers):
            raise MintManagerDomainError(
                f"malformed operation domain row: {raw_line}"
            )
        row = dict(zip(headers, cells))
        name = row.get("Constant")
        if name is None:
            raise MintManagerDomainError("operation domain table missing Constant column")
        if name in rows:
            raise MintManagerDomainError(f"duplicate operation domain row: {name}")
        rows[name] = row
    if headers != ["Constant", "String preimage", "Hash"]:
        raise MintManagerDomainError(
            "operation domain table headers drifted: "
            f"expected ['Constant', 'String preimage', 'Hash'], got {headers}"
        )
    return rows


def validate_operation_domains(
    mint_spec_text: str,
    architecture_text: str,
    *,
    keccak_fn: Callable[[str], str] = cast_keccak256,
) -> None:
    rows = parse_operation_domain_table(mint_spec_text)
    expected = dict(TARGET_OPERATION_DOMAINS)
    if set(rows) != set(expected):
        missing = sorted(set(expected) - set(rows))
        extra = sorted(set(rows) - set(expected))
        raise MintManagerDomainError(
            "operation domain table mismatch"
            f"; missing={missing or '[]'} extra={extra or '[]'}"
        )

    mirror_rows = parse_exact_markdown_table(
        architecture_text,
        ARCHITECTURE_OPERATION_DOMAIN_MARKER,
        ARCHITECTURE_OPERATION_DOMAIN_END_MARKER,
        (
            "Constant name",
            "String preimage",
            "Hash value",
            "Owner",
            "Schema version",
            "Inputs",
        ),
        label="operation-domain architecture mirror",
    )
    for name, preimage in expected.items():
        expected_hash = keccak_fn(preimage).lower()
        row = rows[name]
        global_home_count = markdown_table_row_count(
            mint_spec_text,
            column_index=0,
            predicate=lambda cell, target=name: cell == target,
        )
        if global_home_count != 1:
            raise MintManagerDomainError(
                f"{name} operation-domain home row cardinality/ownership "
                f"drifted: owning=1, global={global_home_count}"
            )
        if row["String preimage"] != preimage:
            raise MintManagerDomainError(
                f"{name} target preimage drifted: expected {preimage!r}, "
                f"got {row['String preimage']!r}"
            )
        if row["Hash"].lower() != expected_hash:
            raise MintManagerDomainError(
                f"{name} target hash drifted: expected {expected_hash}, "
                f"got {row['Hash']}"
            )
        target_rows = [
            row for row in mirror_rows if row["Constant name"] == name
        ]
        global_count = markdown_table_row_count(
            architecture_text,
            column_index=0,
            predicate=lambda cell, target=name: cell == target,
        )
        if len(target_rows) != 1 or global_count != 1:
            raise MintManagerDomainError(
                f"{name} target protocol-v1 mirror row cardinality/ownership "
                f"drifted: owning={len(target_rows)}, global={global_count}"
            )
        mirror_row = target_rows[0]
        owner, schema_version, inputs = TARGET_OPERATION_DOMAIN_MIRROR_METADATA[name]
        expected_mirror = {
            "Constant name": name,
            "String preimage": preimage,
            "Hash value": expected_hash,
            "Owner": owner,
            "Schema version": schema_version,
            "Inputs": inputs,
        }
        actual_mirror = dict(mirror_row)
        actual_mirror["Hash value"] = actual_mirror["Hash value"].lower()
        for column, expected_value in expected_mirror.items():
            if actual_mirror[column] != expected_value:
                raise MintManagerDomainError(
                    f"{name} target protocol-v1 mirror {column} drifted: "
                    f"expected {expected_value!r}, got {actual_mirror[column]!r}"
                )


def validate_operation_selectors(
    mint_spec_text: str,
    *,
    keccak_fn: Callable[[str], str] = cast_keccak256,
) -> None:
    selector_rows = parse_exact_markdown_table(
        mint_spec_text,
        OPERATION_SELECTOR_MARKER,
        OPERATION_SELECTOR_END_MARKER,
        ("Selector", "Canonical external signature"),
        label="operation selector golden",
    )
    expected_signatures = {
        signature for signature, _selector in TARGET_OPERATION_SELECTORS
    }
    actual_signatures = {
        row["Canonical external signature"] for row in selector_rows
    }
    if (
        actual_signatures != expected_signatures
        or len(selector_rows) != len(TARGET_OPERATION_SELECTORS)
    ):
        raise MintManagerDomainError(
            "operation selector table membership drifted: "
            f"missing={sorted(expected_signatures - actual_signatures)} "
            f"extra={sorted(actual_signatures - expected_signatures)} "
            f"rows={len(selector_rows)}"
        )
    for signature, pinned_selector in TARGET_OPERATION_SELECTORS:
        computed_selector = keccak_fn(signature).lower()[:10]
        if computed_selector != pinned_selector:
            raise MintManagerDomainError(
                f"{signature} checked selector constant drifted: "
                f"expected {computed_selector}, checker pins {pinned_selector}"
            )
        target_rows = [
            row
            for row in selector_rows
            if row["Canonical external signature"] == signature
        ]
        global_count = markdown_table_row_count(
            mint_spec_text,
            column_index=1,
            predicate=lambda cell, target=signature: cell == target,
        )
        if len(target_rows) != 1 or global_count != 1:
            raise MintManagerDomainError(
                "operation identity selector row cardinality/ownership drifted: "
                f"{signature}; owning={len(target_rows)}, global={global_count}"
            )
        if target_rows[0]["Selector"].lower() != pinned_selector:
            raise MintManagerDomainError(
                f"operation identity selector row missing or drifted: {signature}"
            )


def _extract_solidity_source(markdown: str) -> str:
    source = "\n".join(
        match.group("body")
        for match in re.finditer(
            r"```solidity(?P<body>.*?)```",
            markdown,
            re.DOTALL,
        )
    )
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.DOTALL)
    return re.sub(r"//[^\n]*", "", source)


def validate_operation_abi(documents: dict[Path, str]) -> None:
    for path, fragments in TARGET_OPERATION_ABI_FRAGMENTS.items():
        text = documents.get(path)
        if text is None:
            raise MintManagerDomainError(f"missing operation ABI home: {path}")
        solidity_source = _extract_solidity_source(text)
        for fragment in fragments:
            name_match = re.match(r"function\s+([A-Za-z_][A-Za-z0-9_]*)", fragment)
            if name_match is None:
                raise MintManagerDomainError(
                    f"invalid checked ABI fragment for {path}: {fragment!r}"
                )
            function_name = name_match.group(1)
            if (
                function_name == "consume"
                and fragment == TARGET_LEDGER_CONSUME_ABI_FRAGMENT
            ):
                exact_count = text.count(TARGET_LEDGER_CONSUME_DECLARATION)
                if exact_count != 1:
                    raise MintManagerDomainError(
                        f"consume ABI declaration block drifted in {path}: "
                        f"expected exactly one canonical seven-argument "
                        f"declaration; found {exact_count}"
                    )
            name_count = len(
                re.findall(
                    rf"\bfunction\s+{re.escape(function_name)}\s*\(",
                    solidity_source,
                )
            )
            declarations = list(
                re.finditer(
                    rf"\bfunction\s+{re.escape(function_name)}\s*\(.*?;",
                    solidity_source,
                    re.DOTALL,
                )
            )
            if name_count != 1 or len(declarations) != 1:
                raise MintManagerDomainError(
                    f"operation identity ABI declaration drifted in {path}: "
                    f"{function_name} must have exactly one Solidity declaration; "
                    f"found names={name_count}, declarations={len(declarations)}"
                )
            actual = " ".join(declarations[0].group(0).split())
            if actual != fragment:
                raise MintManagerDomainError(
                    f"operation identity ABI declaration drifted in {path}: "
                    f"expected {fragment!r}, got {actual!r}"
                )


def _normalize_solidity_term(value: str) -> str:
    without_comments = "\n".join(
        line.split("//", 1)[0] for line in value.splitlines()
    )
    return re.sub(r"\s+", "", without_comments)


def _split_top_level_commas(value: str) -> tuple[str, ...]:
    terms: list[str] = []
    start = 0
    depth = 0
    for index, character in enumerate(value):
        if character in "([{" :
            depth += 1
        elif character in ")]}":
            depth -= 1
            if depth < 0:
                raise MintManagerDomainError("unbalanced abi.encode preimage")
        elif character == "," and depth == 0:
            terms.append(_normalize_solidity_term(value[start:index]))
            start = index + 1
    if depth != 0:
        raise MintManagerDomainError("unbalanced abi.encode preimage")
    terms.append(_normalize_solidity_term(value[start:]))
    if any(not term for term in terms):
        raise MintManagerDomainError("empty abi.encode preimage term")
    return tuple(terms)


def parse_operation_preimage(markdown: str, variable_name: str) -> tuple[str, ...]:
    pattern = re.compile(
        rf"\bbytes32\s+{re.escape(variable_name)}\s*=\s*"
        r"keccak256\s*\(\s*abi\.encode\s*\((?P<body>.*?)\)\s*\)\s*;",
        re.DOTALL,
    )
    matches = list(pattern.finditer(markdown))
    if len(matches) != 1:
        raise MintManagerDomainError(
            f"{variable_name} abi.encode preimage must appear exactly once; "
            f"found {len(matches)}"
        )
    return _split_top_level_commas(matches[0].group("body"))


def validate_operation_preimages(mint_spec_text: str) -> None:
    for variable_name, expected_terms in TARGET_OPERATION_PREIMAGES.items():
        actual_terms = parse_operation_preimage(mint_spec_text, variable_name)
        normalized_expected = tuple(
            _normalize_solidity_term(term) for term in expected_terms
        )
        if actual_terms != normalized_expected:
            raise MintManagerDomainError(
                f"{variable_name} abi.encode sequence drifted: "
                f"expected {normalized_expected}, got {actual_terms}"
            )


def validate_operation_structs(mint_spec_text: str) -> None:
    for struct_name, expected_fields in TARGET_OPERATION_STRUCT_FIELDS.items():
        matches = list(
            re.finditer(
                rf"\bstruct\s+{re.escape(struct_name)}\s*\{{(?P<body>.*?)\}}",
                mint_spec_text,
                re.DOTALL,
            )
        )
        if len(matches) != 1:
            raise MintManagerDomainError(
                f"{struct_name} target struct must appear exactly once; "
                f"found {len(matches)}"
            )
        actual_fields = tuple(
            _normalize_solidity_term(field)
            for field in matches[0].group("body").split(";")
            if _normalize_solidity_term(field)
        )
        normalized_expected = tuple(
            _normalize_solidity_term(field) for field in expected_fields
        )
        if actual_fields != normalized_expected:
            raise MintManagerDomainError(
                f"{struct_name} target struct fields drifted: "
                f"expected {normalized_expected}, got {actual_fields}"
            )


def extract_operation_solidity_block(mint_spec_text: str) -> str:
    blocks = [
        match.group("body")
        for match in re.finditer(
            r"```solidity(?P<body>.*?)```",
            mint_spec_text,
            re.DOTALL,
        )
        if "function executeSingleStepMint" in match.group("body")
    ]
    if len(blocks) != 1:
        raise MintManagerDomainError(
            "operation identity Solidity block must appear exactly once; "
            f"found {len(blocks)}"
        )
    return blocks[0]


def validate_manager_entry_ownership(mint_spec_text: str) -> None:
    operation_block = extract_operation_solidity_block(mint_spec_text)
    solidity_source = _extract_solidity_source(mint_spec_text)
    for function_name in ("executeSingleStepMint", "executePreparedMint"):
        global_count = len(
            re.findall(
                rf"\bfunction\s+{re.escape(function_name)}\s*\(",
                solidity_source,
            )
        )
        if global_count != 1:
            raise MintManagerDomainError(
                f"{function_name} declaration must appear exactly once across "
                f"the owning Solidity blocks; found {global_count}"
            )
        pattern = re.compile(
            rf"\bfunction\s+{function_name}\s*\((?P<parameters>.*?)\)\s*"
            r"external(?P<mutability>.*?)returns\s*\((?P<returns>.*?)\)\s*;",
            re.DOTALL,
        )
        matches = list(pattern.finditer(operation_block))
        if len(matches) != 1:
            raise MintManagerDomainError(
                f"{function_name} declaration must appear exactly once; "
                f"found {len(matches)}"
            )
        match = matches[0]
        parameters = tuple(
            _normalize_solidity_term(term)
            for term in _split_top_level_commas(match.group("parameters"))
        )
        returns = tuple(
            _normalize_solidity_term(term)
            for term in _split_top_level_commas(match.group("returns"))
        )
        mutability = _normalize_solidity_term(match.group("mutability"))
        if parameters != TARGET_MANAGER_ENTRY_PARAMETERS:
            raise MintManagerDomainError(
                f"{function_name} parameter/callback ownership drifted: "
                f"expected {TARGET_MANAGER_ENTRY_PARAMETERS}, got {parameters}"
            )
        if mutability:
            raise MintManagerDomainError(
                f"{function_name} must be nonpayable with no mutability token; "
                f"got {mutability!r}"
            )
        if returns != TARGET_MANAGER_ENTRY_RETURNS:
            raise MintManagerDomainError(
                f"{function_name} return ABI drifted: "
                f"expected {TARGET_MANAGER_ENTRY_RETURNS}, got {returns}"
            )
    preview_name = "previewSingleStepMintOperation"
    preview_count = len(
        re.findall(
            rf"\bfunction\s+{preview_name}\s*\(",
            solidity_source,
        )
    )
    preview_pattern = re.compile(
        rf"\bfunction\s+{preview_name}\s*\((?P<parameters>.*?)\)\s*"
        r"external(?P<mutability>.*?)returns\s*\((?P<returns>.*?)\)\s*;",
        re.DOTALL,
    )
    preview_matches = list(preview_pattern.finditer(operation_block))
    if preview_count != 1 or len(preview_matches) != 1:
        raise MintManagerDomainError(
            f"{preview_name} declaration must appear exactly once; "
            f"found names={preview_count}, declarations={len(preview_matches)}"
        )
    preview = preview_matches[0]
    preview_parameters = tuple(
        _normalize_solidity_term(term)
        for term in _split_top_level_commas(preview.group("parameters"))
    )
    preview_returns = tuple(
        _normalize_solidity_term(term)
        for term in _split_top_level_commas(preview.group("returns"))
    )
    preview_mutability = _normalize_solidity_term(preview.group("mutability"))
    if preview_parameters != TARGET_MANAGER_ENTRY_PARAMETERS:
        raise MintManagerDomainError(
            f"{preview_name} parameter/callback ownership drifted: "
            f"expected {TARGET_MANAGER_ENTRY_PARAMETERS}, got {preview_parameters}"
        )
    if preview_mutability != "view":
        raise MintManagerDomainError(
            f"{preview_name} must be external view; got {preview_mutability!r}"
        )
    if preview_returns != TARGET_MANAGER_PREVIEW_RETURNS:
        raise MintManagerDomainError(
            f"{preview_name} return ABI drifted: "
            f"expected {TARGET_MANAGER_PREVIEW_RETURNS}, got {preview_returns}"
        )
    function_names = tuple(
        re.findall(
            r"\bfunction\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(",
            operation_block,
        )
    )
    expected_function_names = (
        "executeSingleStepMint",
        "executePreparedMint",
        "previewSingleStepMintOperation",
        "nextOperationNonce",
    )
    if function_names != expected_function_names:
        raise MintManagerDomainError(
            "manager operation function inventory drifted: "
            f"expected {expected_function_names}, got {function_names}"
        )
    forbidden_callback_tokens = (
        "settlementData",
        "callbackTarget",
        "callbackSelector",
        "callbackValue",
        "delegatecall",
        "call{value",
    )
    for token in forbidden_callback_tokens:
        if token in solidity_source:
            raise MintManagerDomainError(
                f"manager operation ABI includes forbidden callback surface {token!r}"
            )
    if re.search(r"\bfunction\s+mint\s*\(\s*MintBatch\b", solidity_source):
        raise MintManagerDomainError(
            "superseded mint(MintBatch,bytes) declaration remains co-live"
        )


def validate_sale_authorization_typehash(
    documents: dict[Path, str],
    *,
    keccak_fn: Callable[[str], str] = cast_keccak256,
) -> None:
    sales_text = documents.get(SALES_SPEC_PATH)
    architecture_text = documents.get(DOC_PATH)
    if sales_text is None or architecture_text is None:
        raise MintManagerDomainError("missing sale-authorization typehash document")
    assignment_pattern = re.compile(
        r"SALE_AUTHORIZATION_TYPEHASH\s*=\s*keccak256\s*\((?P<body>.*?)\)\s*;",
        re.DOTALL,
    )
    assignment_section = _extract_marked_section(
        sales_text,
        SALE_AUTHORIZATION_ASSIGNMENT_MARKER,
        SALE_AUTHORIZATION_ASSIGNMENT_END_MARKER,
    )
    owning_assignments = list(assignment_pattern.finditer(assignment_section))
    assignments_by_path = {
        path: list(assignment_pattern.finditer(text))
        for path, text in sorted(documents.items())
    }
    global_assignment_count = sum(
        len(matches) for matches in assignments_by_path.values()
    )
    non_owner_assignment_paths = sorted(
        path.as_posix()
        for path, matches in assignments_by_path.items()
        if path != SALES_SPEC_PATH
        for _match in matches
    )
    sales_global_count = len(assignments_by_path.get(SALES_SPEC_PATH, []))
    if (
        len(owning_assignments) != 1
        or sales_global_count != 1
        or global_assignment_count != 1
        or non_owner_assignment_paths
    ):
        raise MintManagerDomainError(
            "SALE_AUTHORIZATION_TYPEHASH assignment cardinality/ownership "
            f"drifted: owning={len(owning_assignments)}, "
            f"sales_global={sales_global_count}, "
            f"global={global_assignment_count}, "
            f"non_owners={non_owner_assignment_paths}"
        )
    assignment = owning_assignments[0]
    actual_type_string = "".join(
        re.findall(r'"([^"]*)"', assignment.group("body"))
    )
    if actual_type_string != SALE_AUTHORIZATION_TYPE_STRING:
        raise MintManagerDomainError(
            "SALE_AUTHORIZATION_TYPEHASH type string drifted: "
            f"expected {SALE_AUTHORIZATION_TYPE_STRING!r}, "
            f"got {actual_type_string!r}"
        )
    computed = keccak_fn(actual_type_string).lower()
    if computed != SALE_AUTHORIZATION_TYPEHASH:
        raise MintManagerDomainError(
            "SALE_AUTHORIZATION_TYPEHASH checker golden drifted: "
            f"expected {computed}, checker pins {SALE_AUTHORIZATION_TYPEHASH}"
        )
    headers = (
        "Constant name",
        "String preimage",
        "Hash value",
        "Owner",
        "Schema version",
        "Inputs",
    )
    sales_rows = parse_exact_markdown_table(
        sales_text,
        SALES_DOMAIN_MARKER,
        SALES_DOMAIN_END_MARKER,
        headers,
        label="sales domain/typehash home",
    )
    sales_targets = [
        row
        for row in sales_rows
        if row["Constant name"] == "SALE_AUTHORIZATION_TYPEHASH"
    ]
    sale_rows_by_path = {
        path: markdown_table_row_count(
            text,
            column_index=0,
            predicate=lambda cell: cell == "SALE_AUTHORIZATION_TYPEHASH",
        )
        for path, text in sorted(documents.items())
    }
    sales_global_row_count = sale_rows_by_path.get(SALES_SPEC_PATH, 0)
    sales_non_owner_paths = sorted(
        path.as_posix()
        for path, count in sale_rows_by_path.items()
        if path not in {SALES_SPEC_PATH, DOC_PATH}
        for _index in range(count)
    )
    if (
        len(sales_targets) != 1
        or sales_global_row_count != 1
        or sales_non_owner_paths
    ):
        raise MintManagerDomainError(
            "SALE_AUTHORIZATION_TYPEHASH sales mirror row cardinality/ownership "
            f"drifted: owning={len(sales_targets)}, "
            f"global={sales_global_row_count}, "
            f"non_owners={sales_non_owner_paths}"
        )
    sales_target = sales_targets[0]
    actual_sales_target = dict(sales_target)
    actual_sales_target["Hash value"] = actual_sales_target["Hash value"].lower()
    for column, expected_value in SALE_AUTHORIZATION_HOME_ROW.items():
        if actual_sales_target[column] != expected_value:
            raise MintManagerDomainError(
                "SALE_AUTHORIZATION_TYPEHASH sales home "
                f"{column} drifted: expected {expected_value!r}, "
                f"got {actual_sales_target[column]!r}"
            )
    architecture_rows = parse_exact_markdown_table(
        architecture_text,
        ARCHITECTURE_SALES_MARKER,
        ARCHITECTURE_SALES_END_MARKER,
        headers,
        label="sale typehash architecture mirror",
    )
    architecture_targets = [
        row
        for row in architecture_rows
        if row["Constant name"] == "SALE_AUTHORIZATION_TYPEHASH"
    ]
    architecture_global_count = sale_rows_by_path.get(DOC_PATH, 0)
    if (
        len(architecture_targets) != 1
        or architecture_global_count != 1
        or sales_non_owner_paths
    ):
        raise MintManagerDomainError(
            "SALE_AUTHORIZATION_TYPEHASH protocol-v1 mirror row "
            "cardinality/ownership drifted: "
            f"owning={len(architecture_targets)}, global={architecture_global_count}, "
            f"non_owners={sales_non_owner_paths}"
        )
    architecture_target = architecture_targets[0]
    actual_architecture_target = dict(architecture_target)
    actual_architecture_target["Hash value"] = actual_architecture_target[
        "Hash value"
    ].lower()
    for column, expected_value in SALE_AUTHORIZATION_ARCHITECTURE_ROW.items():
        if actual_architecture_target[column] != expected_value:
            raise MintManagerDomainError(
                "SALE_AUTHORIZATION_TYPEHASH protocol-v1 mirror "
                f"{column} drifted: expected {expected_value!r}, "
                f"got {actual_architecture_target[column]!r}"
            )


def parse_event_signatures(
    markdown: str,
) -> list[tuple[str, str, tuple[str, ...], tuple[str, ...]]]:
    events: list[tuple[str, str, tuple[str, ...], tuple[str, ...]]] = []
    target_names = {
        signature.split("(", 1)[0]
        for signature, _topic, _indexed_names, _parameter_names
        in TARGET_OPERATION_EVENTS
    }
    for match in re.finditer(
        r"\bevent\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*"
        r"\((?P<parameters>.*?)\)\s*;",
        markdown,
        re.DOTALL,
    ):
        name = match.group("name")
        if name not in target_names:
            continue
        parameter_types: list[str] = []
        indexed_names: list[str] = []
        parameter_names: list[str] = []
        raw_parameters = match.group("parameters").strip()
        if raw_parameters:
            for raw_parameter in raw_parameters.split(","):
                tokens = raw_parameter.split()
                if len(tokens) < 2:
                    raise MintManagerDomainError(
                        f"malformed event parameter in {match.group('name')}: "
                        f"{raw_parameter!r}"
                    )
                parameter_types.append(tokens[0])
                parameter_names.append(tokens[-1])
                if "indexed" in tokens:
                    indexed_names.append(tokens[-1])
        events.append(
            (
                name,
                f"{name}({','.join(parameter_types)})",
                tuple(indexed_names),
                tuple(parameter_names),
            )
        )
    return events


def validate_operation_events(
    documents: dict[Path, str],
    *,
    keccak_fn: Callable[[str], str] = cast_keccak256,
) -> None:
    parsed_by_path: dict[
        Path, list[tuple[str, str, tuple[str, ...], tuple[str, ...]]]
    ] = {}
    for owner_path in set(TARGET_OPERATION_EVENT_OWNERS.values()):
        if owner_path not in documents:
            raise MintManagerDomainError(
                f"missing operation event home: {owner_path}"
            )
    for path, text in sorted(documents.items()):
        parsed_by_path[path] = parse_event_signatures(text)

    mirror = documents.get(CONFORMANCE_PATH)
    if mirror is None:
        raise MintManagerDomainError(
            f"missing operation event topic mirror: {CONFORMANCE_PATH}"
        )

    mirror_rows = parse_exact_markdown_table(
        mirror,
        EVENT_TOPIC_MARKER,
        EVENT_TOPIC_END_MARKER,
        ("Canonical event signature", "topic0", "Indexed fields", "Owner"),
        label="operation-event topic mirror",
    )
    expected_event_signatures = {
        signature
        for signature, _topic, _indexed_names, _parameter_names
        in TARGET_OPERATION_EVENTS
    }
    actual_event_signatures = {
        row["Canonical event signature"] for row in mirror_rows
    }

    for (
        signature,
        pinned_topic,
        indexed_names,
        parameter_names,
    ) in TARGET_OPERATION_EVENTS:
        name = signature.split("(", 1)[0]
        owner = TARGET_OPERATION_EVENT_OWNERS[name]
        owner_matches = [
            (event_signature, event_indexed, event_parameters)
            for event_name, event_signature, event_indexed, event_parameters
            in parsed_by_path[owner]
            if event_name == name
        ]
        non_owner_matches = sorted(
            path.as_posix()
            for path, events in parsed_by_path.items()
            if path != owner
            for event_name, _signature, _indexed, _parameters in events
            if event_name == name
        )
        if len(owner_matches) != 1 or non_owner_matches:
            raise MintManagerDomainError(
                f"{name} target event declaration cardinality/ownership drifted: "
                f"owner={owner}, owning={len(owner_matches)}, "
                f"non_owners={non_owner_matches}"
            )
        actual = owner_matches[0]
        expected = (signature, indexed_names, parameter_names)
        if actual != expected:
            raise MintManagerDomainError(
                f"{name} target event signature/field layout drifted: "
                f"expected {expected}, got {actual or '<missing>'}"
            )
        computed_topic = keccak_fn(signature).lower()
        if computed_topic != pinned_topic:
            raise MintManagerDomainError(
                f"{name} checked topic constant drifted: expected {computed_topic}, "
                f"checker pins {pinned_topic}"
            )
        target_rows = [
            row
            for row in mirror_rows
            if row["Canonical event signature"].split("(", 1)[0] == name
        ]
        topic_rows_by_path = {
            path: markdown_table_row_count(
                text,
                column_index=0,
                predicate=lambda cell, target=name: (
                    cell.split("(", 1)[0] == target
                ),
            )
            for path, text in sorted(documents.items())
        }
        global_count = topic_rows_by_path.get(CONFORMANCE_PATH, 0)
        non_owner_topic_paths = sorted(
            path.as_posix()
            for path, count in topic_rows_by_path.items()
            if path != CONFORMANCE_PATH
            for _index in range(count)
        )
        if (
            len(target_rows) != 1
            or global_count != 1
            or non_owner_topic_paths
        ):
            raise MintManagerDomainError(
                f"{name} target event topic mirror cardinality/ownership drifted: "
                f"owning={len(target_rows)}, global={global_count}, "
                f"non_owners={non_owner_topic_paths}"
            )
        mirror_row = target_rows[0]
        if (
            mirror_row["Canonical event signature"] != signature
            or mirror_row["topic0"].lower() != pinned_topic
            or mirror_row["Indexed fields"] != ",".join(indexed_names)
            or mirror_row["Owner"] != TARGET_OPERATION_EVENT_OWNER_LABELS[name]
        ):
            raise MintManagerDomainError(
                f"{name} target event topic mirror row missing or drifted"
            )
    if (
        actual_event_signatures != expected_event_signatures
        or len(mirror_rows) != len(TARGET_OPERATION_EVENTS)
    ):
        raise MintManagerDomainError(
            "operation-event topic table membership drifted: "
            f"missing={sorted(expected_event_signatures - actual_event_signatures)} "
            f"extra={sorted(actual_event_signatures - expected_event_signatures)} "
            f"rows={len(mirror_rows)}"
        )


OPERATION_IDENTITY_FRAGMENTS: dict[Path, tuple[str, ...]] = {
    MINT_SPEC_PATH: (
        "Proposed\n"
        "[ADR 0018](adr/0018-batch-operation-root-and-token-identity.md) tracks the\n"
        "candidate mint operation-identity and replay-ownership amendment; it remains\n"
        "unaccepted",
        "Every batch of quantity `N` has one batch",
        "`operationRoot` and exactly `N` per-token `operationId` values.",
        "Both manager entries are nonpayable and asset-agnostic.",
        "`authorizationId` is a required nonzero typed request field.",
        "A configured gate must return a nonzero `authorizationId` equal to\n"
        "   `MintBatch.authorizationId`, return `authorizer` equal to\n"
        "   `MintBatch.authorizer`",
        "contains no generic settlement bytes, callback target, selector, value, or\n"
        "delegatecall surface.",
        "The preview is manager-owned: it uses\n"
        "   its own `msg.sender` as executor",
        "It emits no\n"
        "   event, writes or consumes no state",
        "executor term is exactly the adapter's `address(this)`",
        "substituting a different preview caller is an identity\n"
        "   mismatch.",
        "enabled counters appear in their policy-registration order;\n"
        "   a context-keyed counter contributes exactly one row; every other counter\n"
        "   contributes rows in ascending `tokenIndex`",
        "two\n"
        "equivalent presentations that validate to the same canonical result derive\n"
        "the same hash",
        "without a gate they equal `address(0)`, `uint8(AuthorizerKind.NONE)`, `0`,\n"
        "   and `bytes32(0)` respectively, and the manager requires\n"
        "   `batch.authorizer == address(0)` and an empty `canonicalNullifiers` array.",
        "No ungated path infers an authorizer kind from the caller, payer, account\n"
        "   code, or any phase field.",
        "This operation preimage does not invent a primary-settlement result field",
        "exact typed primary-settlement invocation, hostile callback\n"
        "cases, and execution-specific settlement replay key remain an explicit ADR\n"
        "0019 / issue #694 production blocker",
        "A prepared path must verify the explicit manager/root through\n"
        "the ledger and the current Core `PreparedMintRecord.operationId` before any\n"
        "resolver or settlement effect.",
        "A single-step path must preserve\n"
        "preview -> settlement -> manager-return comparison with whole-transaction\n"
        "rollback.",
        "PRE-GENESIS REMOVED: the earlier generic manager entry",
        "Emit central manager batch and ledger root events with the root,\n"
        "    per-token operation IDs, `currentPolicyHash`, and `boundPolicyHash`.",
        "The ticket's `policyHash` is `MintBatch.expectedPolicyHash`",
        "Child counter, authorization, and nullifier ledger events include\n"
        "   `boundPolicyHash`; the central root event includes\n"
        "   `currentPolicyHash` and `boundPolicyHash`",
        "`MintLedgerCounterConsumed` carries\n"
        "the `boundPolicyHash`, `operationRoot`, and cap/accounting values",
        "`MintBatch.expectedPolicyHash` and signed-ticket authority bind the\n"
        "authorized `boundPolicyHash`",
        "Live consent, gate/module/config evaluation, counters, caps, and\n"
        "increments are checked under `currentPolicyHash`.",
        "`operationRoot` commits `currentPolicyHash` and then `boundPolicyHash`.",
        "Preview returns `operationRoot` plus `operationIds`; it does not separately\n"
        "return either policy hash.",
        "Child authorization, nullifier, and counter-consumption events expose\n"
        "`boundPolicyHash` plus `operationRoot`.",
        "Per-token events join through `operationRoot` and do not separately expose\n"
        "either policy hash.",
        "changing the root, reserved token nonce, index,\n"
        "    token-data hash, or mint commitment changes the token operation ID.",
        "bytes32 boundPolicyHash,\n        bytes32 operationRoot",
        "bytes32(currentPolicyHash),\n    bytes32(boundPolicyHash)",
        "bytes32(batch.expectedPolicyHash),\n    bytes32(initialRecipientsHash)",
        "Configured and ungated phases\n"
        "   both accept the current or valid immediate-predecessor identity.",
        "`requireMintConsent(collectionId, phaseId, currentPolicyHash)`",
        "The central `MintLedgerOperationRootConsumed` and manager\n"
        "`MintBatchExecuted` events carry both hashes.",
        "The ledger stores the current `policyHash` and monotonically increasing\n"
        "   `currentPolicyRevision`.",
        "`block.timestamp <= previousPolicyGraceUntil`",
        "A second rotation overwrites the tuple and immediately invalidates\n"
        "   the older predecessor",
        "repeat cap checks under the\n"
        "    current registered counter policies",
        "`consume` receives explicit `collectionId` and `phaseId`;\n"
        "   it never infers phase identity from `consumptions`, because a valid phase\n"
        "   may consume an empty counter array.",
        "`registeredPhasePolicyHashes[msg.sender][collectionId][phaseId]`",
        "The caller never supplies\n"
        "   `currentPolicyHash`, and the ledger never calls the manager to discover it.",
        "`row.collectionId == collectionId` and `row.phaseId == phaseId`",
        "`consumptions` may be empty. The ledger still validates manager, explicit\n"
        "   phase, current/bound policy identity, root, authorization, and nullifiers",
        "emits exactly one `MintLedgerOperationRootConsumed` using the loaded\n"
        "   `currentPolicyHash` and supplied `boundPolicyHash`",
        "It emits no\n"
        "   `MintLedgerCounterConsumed` or `MintLedgerCounterConsumptionContext` event\n"
        "   for an empty array.",
        "Pass the exact batch `collectionId` and `phaseId` to\n"
        "    `StreamMintLedger.consume`. The ledger independently loads\n"
        "    `currentPolicyHash` from the calling manager's registered phase tuple",
        "Missing current-policy artist consent",
        "function isManagerOperationRootUsed(address manager, bytes32 operationRoot)",
        "event MintLedgerOperationRootConsumed(",
        "event MintTokenExecuted(",
        "Core authenticates only the current singleton",
        "stores no lifetime operation-ID replay.",
        "Entropy registration  owns tokenId plus mintCommitment; receives no root or operationId",
    ),
    REVENUE_DOC_PATH: (
        "Proposed\n"
        "[ADR 0018](adr/0018-batch-operation-root-and-token-identity.md) tracks the\n"
        "candidate operation-identity amendment and remains unaccepted.",
        "bytes32 operationRoot,\n    bytes32 operationId,\n    bytes32 revenueClass,",
        "event TokenRoyaltySnapshotted(",
        "Completion-time entropy registration correlates",
        "intentionally receives no\nroot or operation ID.",
        "Before either\n"
        "step may perform an effect, the resolver or settlement participant must verify\n"
        "the explicit manager/root through\n"
        "`isManagerOperationRootUsed(manager, operationRoot)` and the current Core\n"
        "`preparedMint(tokenId).operationId`.",
        "Known repeat-sale collision. The current `settlementKey` also lacks a\n"
        "purchase/execution identity.",
        "`operationRoot` is\n"
        "not a universal replacement",
        "`snapshotTokenRoyaltyAtMint` is `PREPARED_MINT`-only.",
        "`PRE_REVENUE_SINGLE_STEP` has no prepared record and must reject any policy\n"
        "    requiring a token-level primary or royalty snapshot",
        "Sale adapter calls the manager-owned\n"
        "   `previewSingleStepMintOperation(batch, gateData)`.",
        "Mint manager validates the phase, recomputes `currentPolicyHash`, accepts\n"
        "   `batch.expectedPolicyHash` as the current or exact unexpired immediate\n"
        "   predecessor, and defines `boundPolicyHash = batch.expectedPolicyHash`.",
        "Mint manager passes the exact batch `collectionId` and `phaseId` to the\n"
        "   ledger. Using the manager caller as scope, the ledger independently loads\n"
        "   `currentPolicyHash` from that registered phase tuple",
        "after `currentPolicyHash` computation and before",
    ),
    ADR_0018_PATH: (
        "# ADR 0018: Batch Operation Root And Token Identity",
        "Proposed only for the pre-genesis production target",
        "This draft is not accepted, does not close issue #688",
        "Every successful manager batch of quantity `N > 0`",
        "The manager entrypoints are nonpayable and asset-agnostic.",
        "`MintBatch.authorizationId` is a required nonzero typed request field.",
        "Root derivation, nonce-range reservation, all token operation IDs",
        "The proposed `SALE_AUTHORIZATION_TYPEHASH` additionally binds "
        "`tokenDataArrayHash` and\n`mintCommitmentsHash`",
        "The preview is manager-owned, is safe for a `STATICCALL`",
        "returns exactly `batch.beneficiaries.length`\n"
        "token operation IDs.",
        "The operation root explicitly\n"
        "binds `currentPolicyHash` then `boundPolicyHash`",
        "`MintBatchExecuted` and the central\n"
        "`MintLedgerOperationRootConsumed` carry both hashes.",
        "configured and ungated phases accept the current\n"
        "or valid immediate-predecessor identity",
        "The manager passes the exact batch `collectionId` and `phaseId`; the ledger\n"
        "uses `msg.sender` as manager scope and independently loads\n"
        "`currentPolicyHash`",
        "The caller never supplies\n"
        "`currentPolicyHash`, and the ledger never infers phase identity from counter\n"
        "rows or calls the manager.",
        "`consumptions` may be empty: the ledger still validates and consumes the root\n"
        "plus any authorization/nullifiers",
        "## Settlement Invariant And Open Blocker",
        "ADR 0019 / issue #694 must define the exact\n"
        "typed invocation, hostile callback cases, and execution-ID-bound distinct-key\n"
        "and replay tests.",
        "The ledger rejects a zero root and a root already used in the calling manager's\n"
        "scope before any ledger write.",
        "An\n"
        "unregistered phase, cross-phase row, invalid bound hash, replay, counter\n"
        "mismatch, or downstream manager, Core, resolver, settlement, entropy, or\n"
        "receiver failure reverts all ledger writes, events, and the manager nonce\n"
        "reservation.",
        "compares\n"
        "the returned root and token operation ID vector with the preview.",
        "## Atomic Cutover And Core Replay Removal",
        "The generated event catalog remains an as-built artifact",
    ),
    ADR_0008_PATH: (
        "`operationRoot` plus per-token `operationId` binding, as proposed by ADR 0018,",
    ),
    SALES_SPEC_PATH: (
        "-> StreamMintManager.executeSingleStepMint(...) or executePreparedMint(...)",
        "compares the\n   returned root and token operation IDs with its preview",
        "uses exactly\n   its own `address(this)` for the manager-executor term",
        "`tokenDataArrayHash` and `mintCommitmentsHash` are the exact canonical\n"
        "   batch hashes",
        "exact typed primary-settlement call\n"
        "   and execution-specific repeat-sale key remain ADR 0019 / issue #694\n"
        "   blockers",
        "Central manager-batch and ledger-root-consumption facts expose both\n"
        "   `currentPolicyHash` and `boundPolicyHash`",
        "child authorization and consumption\n"
        "   facts use `boundPolicyHash` and join through `operationRoot`.",
        "the manager passes the exact batch `collectionId` and\n"
        "`phaseId` to `StreamMintLedger.consume`; the ledger uses the manager caller as\n"
        "scope, independently loads the current registered phase policy",
    ),
    CONFORMANCE_PATH: (
        "Proposed\n"
        "[ADR 0018](adr/0018-batch-operation-root-and-token-identity.md) supplies draft\n"
        "target mint-operation identity and replay gates. They remain unaccepted",
        "exactly one root plus `N` token operation IDs",
        "full normalized request/result/root/token preimage mutation coverage",
        "adapter preview uses its own `address(this)` as manager executor",
        "exact typed primary-settlement callback and execution-ID-bound "
        "repeat-sale replay remain ADR 0019 / #694 blockers",
    ),
    BACKLOG_PATH: (
        "one root plus `N` token\n   operation IDs",
    ),
    DOC_PATH: (
        "Proposed\n"
        "[ADR 0018](adr/0018-batch-operation-root-and-token-identity.md) tracks the\n"
        "candidate operation-identity amendment and remains unaccepted",
    ),
    ADR_INDEX_PATH: (
        "| [`0018-batch-operation-root-and-token-identity.md`]"
        "(0018-batch-operation-root-and-token-identity.md) | Proposed | "
        "[#688](https://github.com/6529-Collections/6529Stream/issues/688): "
        "proposed one manager batch root, `N` token operation IDs",
    ),
}
OPERATION_FORBIDDEN_FRAGMENTS: dict[Path, tuple[str, ...]] = {
    MINT_SPEC_PATH: (
        "bytes calldata settlementData",
        "path, and its own caller\n   address",
        "changes the token ID.",
        "per-token IDs",
        "`MintLedgerCounterConsumed` carries\n"
        "the `policyHash`, `operationRoot`, and cap/accounting values",
        "Every mint event, ledger consumption event, signed ticket, and preview\n"
        "response must include the active `policyHash`.",
        "`0x79e9746a`",
        "consume((bytes32,uint256,bytes32,bytes32,bytes32,address,address,address,"
        "address,uint64,uint64,bytes32,bytes32)[],bytes32,bytes32[],bytes32,bytes32)",
        "function consume(\n    CounterConsumption[] calldata consumptions,",
    ),
    ADR_0018_PATH: (
        "Accepted for the pre-genesis production target",
        "## Accepted Risks",
        "exact request contents",
        "token-ID model",
        "all token IDs",
        "Per-token IDs",
        "an ungated phase accepts only the current hash",
        "ungated predecessor",
        "all expose the same bound hash",
        "preview, ledger, sale, mint, and consumption facts all expose the same bound hash",
        "function consume(\n    CounterConsumption[] calldata consumptions,",
    ),
    SALES_SPEC_PATH: (
        "0xffd150d67de6a2619775f6cb884eadc8802d3d37fbd584d32ad0ff83ceddb098",
        "every emitted sale, mint, or consumption\n   policy hash are the same value",
    ),
    CONFORMANCE_PATH: (
        "exactly one root plus `N` token IDs",
    ),
    BACKLOG_PATH: (
        "one root plus `N` token IDs",
    ),
    ADR_INDEX_PATH: (
        "| [`0018-batch-operation-root-and-token-identity.md`]"
        "(0018-batch-operation-root-and-token-identity.md) | Accepted |",
    ),
}
OPERATION_IDENTITY_EXACT_COUNTS: dict[
    Path, tuple[tuple[str, int], ...]
] = {
    MINT_SPEC_PATH: (
        (
            "Emit central manager batch and ledger root events with the root,\n"
            "per-token operation IDs, `currentPolicyHash`, and `boundPolicyHash`.",
            1,
        ),
        (
            "Child counter, authorization, and nullifier ledger events include\n"
            "`boundPolicyHash`; the central root event includes\n"
            "`currentPolicyHash` and `boundPolicyHash`",
            1,
        ),
        (
            "`MintLedgerCounterConsumed` carries\n"
            "the `boundPolicyHash`, `operationRoot`, and cap/accounting values",
            1,
        ),
        (
            "Preview returns `operationRoot` plus `operationIds`; it does not separately\n"
            "return either policy hash.",
            1,
        ),
        (
            "Per-token events join through `operationRoot` and do not separately expose\n"
            "either policy hash.",
            1,
        ),
        ("`block.timestamp <= previousPolicyGraceUntil`", 5),
        ("`gateResult.authorizer == batch.authorizer`", 1),
        (
            "A second rotation overwrites the tuple and immediately invalidates\n"
            "the older predecessor",
            1,
        ),
        ("Missing current-policy artist consent", 1),
        (
            "`registeredPhasePolicyHashes[msg.sender][collectionId][phaseId]`",
            1,
        ),
        (
            "`row.collectionId == collectionId` and "
            "`row.phaseId == phaseId`",
            1,
        ),
        (
            "`consumptions` may be empty. The ledger still validates manager, explicit\n"
            "phase, current/bound policy identity, root, authorization, and nullifiers",
            1,
        ),
    ),
    REVENUE_DOC_PATH: (
        (
            "Sale adapter calls the manager-owned\n"
            "`previewSingleStepMintOperation(batch, gateData)`.",
            1,
        ),
        (
            "Mint manager calls `requireMintConsent(collectionId, phaseId,\n"
            "currentPolicyHash)`",
            2,
        ),
        (
            "Mint manager passes the exact batch `collectionId` and `phaseId` to the\n"
            "ledger. Using the manager caller as scope, the ledger independently loads\n"
            "`currentPolicyHash` from that registered phase tuple",
            2,
        ),
    ),
    ADR_0018_PATH: (
        (
            "The operation root explicitly\n"
            "binds `currentPolicyHash` then `boundPolicyHash`",
            1,
        ),
        (
            "The manager passes the exact batch `collectionId` and `phaseId`; the ledger\n"
            "uses `msg.sender` as manager scope and independently loads\n"
            "`currentPolicyHash`",
            1,
        ),
    ),
}


def validate_operation_identity_fragments(documents: dict[Path, str]) -> None:
    for path, fragments in OPERATION_IDENTITY_FRAGMENTS.items():
        text = documents.get(path)
        if text is None:
            raise MintManagerDomainError(f"missing operation identity document: {path}")
        normalized_text = " ".join(text.split())
        for fragment in fragments:
            if " ".join(fragment.split()) not in normalized_text:
                raise MintManagerDomainError(
                    f"operation identity contract drifted in {path}: "
                    f"missing {fragment!r}"
                )
    for path, forbidden_fragments in OPERATION_FORBIDDEN_FRAGMENTS.items():
        text = documents.get(path)
        if text is None:
            raise MintManagerDomainError(f"missing operation identity document: {path}")
        normalized_text = " ".join(text.split())
        for fragment in forbidden_fragments:
            if " ".join(fragment.split()) in normalized_text:
                raise MintManagerDomainError(
                    f"operation identity stale/forbidden contract in {path}: "
                    f"found {fragment!r}"
                )
    for path, exact_counts in OPERATION_IDENTITY_EXACT_COUNTS.items():
        text = documents.get(path)
        if text is None:
            raise MintManagerDomainError(f"missing operation identity document: {path}")
        normalized_text = " ".join(text.split())
        for fragment, expected_count in exact_counts:
            normalized_fragment = " ".join(fragment.split())
            actual_count = normalized_text.count(normalized_fragment)
            if actual_count != expected_count:
                raise MintManagerDomainError(
                    f"operation identity exact fragment count drifted in {path}: "
                    f"expected {expected_count}, found {actual_count}: {fragment!r}"
                )


def validate_repo(repo_root: Path) -> None:
    docs_text = (repo_root / DOC_PATH).read_text(encoding="utf-8")
    source_text = (repo_root / SOURCE_PATH).read_text(encoding="utf-8")
    validate_documents(docs_text, source_text)
    validate_revenue_domain_prefixes(repo_root)
    mint_spec_text = (repo_root / MINT_SPEC_PATH).read_text(encoding="utf-8")
    validate_operation_domains(mint_spec_text, docs_text)
    validate_operation_selectors(mint_spec_text)
    validate_operation_preimages(mint_spec_text)
    validate_operation_structs(mint_spec_text)
    validate_manager_entry_ownership(mint_spec_text)
    operation_documents = {
        path: (repo_root / path).read_text(encoding="utf-8")
        for path in set(OPERATION_IDENTITY_FRAGMENTS)
        | {
            DOC_PATH,
            MINT_SPEC_PATH,
            REVENUE_DOC_PATH,
            ENTROPY_SPEC_PATH,
            CONFORMANCE_PATH,
        }
    }
    validate_operation_abi(operation_documents)
    validate_operation_identity_fragments(operation_documents)
    validate_sale_authorization_typehash(operation_documents)
    validate_operation_events(operation_documents)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-root",
        default=Path(__file__).resolve().parent.parent,
        type=Path,
        help="Repository root to validate.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        validate_repo(args.repo_root)
    except MintManagerDomainError as exc:
        print(f"mint manager domain constants check failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
