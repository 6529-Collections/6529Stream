#!/usr/bin/env python3
"""Validate StreamMintManager hash domain constants against the checked spec.

Also enforces the revenue-layer domain-string namespace rule
([RSR-DOMAINS] rule 4, ADR 0011 decision R12): every revenue-layer domain
string preimage in the revenue home table and its protocol v1 mirror must
start with ``6529STREAM_``.
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
REVENUE_SECTION_MARKERS: tuple[tuple[Path, str, str], ...] = (
    (REVENUE_DOC_PATH, "Requirements [RSR-DOMAINS]:", "\n## "),
    (DOC_PATH, "### Revenue Mirror Rows", "\n### "),
)


def _extract_marked_section(markdown: str, start_marker: str, end_marker: str) -> str:
    start = markdown.find(start_marker)
    if start == -1:
        raise MintManagerDomainError(f"missing section marker: {start_marker}")
    end = markdown.find(end_marker, start + len(start_marker))
    return markdown[start:] if end == -1 else markdown[start:end]


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
            row = dict(zip(headers, cells))
            preimage = row.get("String preimage", "")
            if re.fullmatch(r"[A-Z0-9_]+", preimage) and not preimage.startswith(
                REVENUE_NAMESPACE_PREFIX
            ):
                raise MintManagerDomainError(
                    f"revenue-layer domain string {preimage!r} in {doc_path} lacks the "
                    f"{REVENUE_NAMESPACE_PREFIX} namespace prefix ([RSR-DOMAINS] rule 4)"
                )


def validate_repo(repo_root: Path) -> None:
    docs_text = (repo_root / DOC_PATH).read_text(encoding="utf-8")
    source_text = (repo_root / SOURCE_PATH).read_text(encoding="utf-8")
    validate_documents(docs_text, source_text)
    validate_revenue_domain_prefixes(repo_root)


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
