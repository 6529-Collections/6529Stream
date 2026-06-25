#!/usr/bin/env python3
"""Generate a deterministic custom-error catalog from the protocol surface."""

from __future__ import annotations

import argparse
import filecmp
import json
import re
import sys
import tempfile
from pathlib import Path
from typing import Any


CATALOG_SCHEMA = "6529stream.custom-error-catalog.v1"
GENERATOR_VERSION = "1"
DEFAULT_SURFACE = Path("release-artifacts/latest/protocol-surface-report.json")
DEFAULT_OUTPUT = Path("release-artifacts/latest/custom-error-catalog.json")
SELECTOR_RE = re.compile(r"^0x[0-9a-f]{8}$")


class CustomErrorCatalogError(RuntimeError):
    pass


CATEGORY_BY_ERROR_NAME = {
    "AlreadyInitialized": "split_payment_safety",
    "AssetNotActive": "asset_policy_safety",
    "AssetPolicyReadFailed": "asset_policy_safety",
    "AssetPolicyUnchanged": "asset_policy_safety",
    "ArtistSignatureUnauthorized": "access_control",
    "BurnedTokenRemintNotAllowed": "supply_minting",
    "CollectionAlreadyFrozen": "metadata_integrity",
    "CollectionDataMissing": "supply_minting",
    "CollectionFinalSupplyWindowActive": "supply_minting",
    "CollectionHasPendingTokenMetadata": "metadata_integrity",
    "CollectionMintWindowActive": "supply_minting",
    "CollectionNotCreated": "supply_minting",
    "CollectionSupplyReached": "supply_minting",
    "CollectionSupplyTooLarge": "supply_minting",
    "DependencyChunkIndexOutOfBounds": "metadata_integrity",
    "DependencyFieldInvalidUTF8": "metadata_integrity",
    "DependencyFieldTooLarge": "metadata_integrity",
    "DependencyKeyReserved": "metadata_integrity",
    "DependencyVersionMissing": "metadata_integrity",
    "DuplicateSplitEntry": "split_payment_safety",
    "EmptyContractURI": "metadata_integrity",
    "EmptyRandomWords": "randomness_lifecycle",
    "ERC20BalanceReadFailed": "split_payment_safety",
    "ERC20TransferFailed": "split_payment_safety",
    "ERC20TransferInvariantBroken": "split_payment_safety",
    "ERC2981InvalidDefaultRoyalty": "configuration",
    "ERC2981InvalidDefaultRoyaltyReceiver": "configuration",
    "ERC2981InvalidTokenRoyalty": "configuration",
    "ERC2981InvalidTokenRoyaltyReceiver": "configuration",
    "FinalSupplyTimeNotPassed": "supply_minting",
    "FrozenCollectionDependencyRegistry": "metadata_integrity",
    "FunctionAdminUnauthorized": "access_control",
    "InvalidAdminContract": "configuration",
    "InvalidAsset": "asset_policy_safety",
    "InvalidAssetPolicyHash": "asset_policy_safety",
    "InvalidAssetPolicyRegistry": "asset_policy_safety",
    "InvalidAssetStatus": "asset_policy_safety",
    "InvalidCoreContract": "configuration",
    "InvalidDependencyRegistryContract": "configuration",
    "InvalidEntryCount": "split_payment_safety",
    "InvalidInitializationInput": "split_payment_safety",
    "InvalidAssignmentScope": "revenue_assignment_safety",
    "InvalidAssignmentType": "revenue_assignment_safety",
    "InvalidMaterializedAccount": "revenue_assignment_safety",
    "InvalidMinterContract": "configuration",
    "InvalidMintManagerContract": "configuration",
    "InvalidPolicyMode": "primary_settlement_safety",
    "InvalidPrimaryPolicyHash": "revenue_assignment_safety",
    "InvalidPrimarySale": "primary_settlement_safety",
    "InvalidPrimaryTemplateEntry": "revenue_assignment_safety",
    "InvalidPrimaryTemplateTotal": "revenue_assignment_safety",
    "InvalidRandomizerContract": "configuration",
    "InvalidRevenueClass": "revenue_assignment_safety",
    "InvalidSettlementCaller": "primary_settlement_safety",
    "InvalidSplitFactory": "configuration",
    "InvalidSplitAccount": "split_payment_safety",
    "InvalidSplitShare": "split_payment_safety",
    "InvalidSplitTotal": "split_payment_safety",
    "InvalidTokenMetadataInput": "metadata_integrity",
    "MetadataFieldInvalidUTF8": "metadata_integrity",
    "MetadataFieldTooLarge": "metadata_integrity",
    "MetadataFrozen": "metadata_integrity",
    "MetadataMutationPaused": "pause_emergency",
    "NoReleasableFunds": "split_payment_safety",
    "IncorrectNativeValue": "primary_settlement_safety",
    "AuthorizationAlreadyConsumed": "mint_ledger_accounting",
    "CounterCapExceeded": "mint_ledger_accounting",
    "CounterPolicyLengthMismatch": "mint_ledger_accounting",
    "CounterPolicyMismatch": "mint_ledger_accounting",
    "CounterPolicyNotRegistered": "mint_ledger_accounting",
    "CounterValueOverflow": "mint_ledger_accounting",
    "CounterValueKeyMismatch": "mint_ledger_accounting",
    "DuplicateCounterPolicy": "mint_ledger_accounting",
    "EmptyCounterConsumption": "mint_ledger_accounting",
    "InvalidCounterPolicy": "mint_ledger_accounting",
    "InvalidLedgerWriter": "mint_ledger_accounting",
    "InvalidPhasePolicy": "mint_ledger_accounting",
    "NullifiersUnsupported": "mint_ledger_accounting",
    "NativeReceiptInvariantBroken": "split_payment_safety",
    "NativeTransferFailed": "split_payment_safety",
    "NotMintManager": "access_control",
    "NotMinterContract": "access_control",
    "ObservedReceiptsDecreased": "split_payment_safety",
    "OnlyCoordinatorCanFulfill": "access_control",
    "PendingRandomnessRequests": "randomness_lifecycle",
    "PreparedMintAlreadyPending": "supply_minting",
    "PreparedMintMismatch": "supply_minting",
    "PreparedMintNotFound": "supply_minting",
    "PreparedMintOperationReused": "supply_minting",
    "PrimaryAssignmentFrozen": "revenue_assignment_safety",
    "PrimaryAssignmentMissing": "revenue_assignment_safety",
    "PrimaryPolicyHashMismatch": "primary_settlement_safety",
    "RandomizerRequestReentrancy": "randomness_lifecycle",
    "RandomnessPostProcessingRetryLimitReached": "randomness_lifecycle",
    "RandomnessRequestAlreadyExists": "randomness_lifecycle",
    "RandomnessRequestNotFailedPostProcessing": "randomness_lifecycle",
    "RandomnessRequestNotFulfilled": "randomness_lifecycle",
    "RandomnessRequestNotPending": "randomness_lifecycle",
    "ReentrancyGuardReentrantCall": "auction_payment_safety",
    "SettlementAlreadyConsumed": "primary_settlement_safety",
    "SplitWalletAddressPoisoned": "split_payment_safety",
    "StaleRandomnessRequest": "randomness_lifecycle",
    "TokenNotMinted": "supply_minting",
    "TokenOutsideCollectionRange": "supply_minting",
    "TokenDataHashMismatch": "metadata_integrity",
    "TokenRandomnessRequestAlreadyExists": "randomness_lifecycle",
    "UnauthorizedInitializer": "access_control",
    "UnauthorizedLedgerWriter": "mint_ledger_accounting",
    "UnauthorizedReleaseRecipient": "access_control",
    "UnauthorizedSettlementCaller": "access_control",
    "UnknownDependency": "metadata_integrity",
    "UnknownPrimaryTemplate": "revenue_assignment_safety",
    "UnknownProfile": "split_payment_safety",
    "UnknownRandomnessRequest": "randomness_lifecycle",
    "UnsafeMetadataURI": "metadata_integrity",
    "UnsafeRawAttributes": "metadata_integrity",
    "UnsupportedAccountSource": "revenue_assignment_safety",
    "UnsupportedAsset": "split_payment_safety",
    "UnverifiedSplitProfile": "revenue_assignment_safety",
    "UnverifiedSplitWallet": "primary_settlement_safety",
    "WrongRandomnessProvider": "randomness_lifecycle",
    "WrongRandomnessTokenCollection": "randomness_lifecycle",
    "ZeroDerivedSeed": "randomness_lifecycle",
    "ZeroRecipient": "split_payment_safety",
    "ZeroTokenHash": "metadata_integrity",
}

CATEGORY_BY_ERROR_ID = {
    "StreamPrimarySaleSettlement:AssetNotActive(address,uint8)": "primary_settlement_safety",
    "StreamPrimarySaleSettlement:AssetPolicyReadFailed(address,address)": "primary_settlement_safety",
    "StreamPrimarySaleSettlement:ERC20BalanceReadFailed(address,address)": "primary_settlement_safety",
    "StreamPrimarySaleSettlement:ERC20TransferFailed(address,address,address,uint256)": "primary_settlement_safety",
    "StreamPrimarySaleSettlement:ERC20TransferInvariantBroken(address,address,address,uint256,uint256,uint256,uint256)": "primary_settlement_safety",
    "StreamPrimarySaleSettlement:NativeTransferFailed(address,uint256)": "primary_settlement_safety",
    "StreamPrimarySaleSettlement:PrimaryAssignmentMissing(bytes32,uint256,uint256)": "primary_settlement_safety",
    "StreamPrimarySaleSettlement:ReentrancyGuardReentrantCall()": "primary_settlement_safety",
    "StreamPrimarySaleSettlement:UnsupportedAsset(address)": "primary_settlement_safety",
    "StreamSplitWallet:ReentrancyGuardReentrantCall()": "split_payment_safety",
}

SEVERITY_BY_CATEGORY = {
    "access_control": "critical",
    "asset_policy_safety": "high",
    "pause_emergency": "high",
    "metadata_integrity": "high",
    "randomness_lifecycle": "high",
    "auction_payment_safety": "high",
    "mint_ledger_accounting": "high",
    "primary_settlement_safety": "high",
    "revenue_assignment_safety": "high",
    "split_payment_safety": "high",
    "supply_minting": "medium",
    "configuration": "medium",
}

CALLER_ACTION_BY_CATEGORY = {
    "access_control": "Do not retry unchanged; verify caller role, signer, coordinator, or authorized contract address.",
    "asset_policy_safety": "Refresh the asset policy registry and token standard review before retrying; inactive, unsupported, malformed, or unapproved assets are terminal until governance updates the policy.",
    "pause_emergency": "Do not retry until the relevant pause domain is unpaused by governance or the operator runbook.",
    "metadata_integrity": "Treat as terminal for the submitted metadata/dependency payload; refresh release artifacts and validate field policy before retrying.",
    "randomness_lifecycle": "Refresh request state and provider epoch before retrying; stale, duplicate, wrong-provider, and wrong-token callbacks are terminal for that payload.",
    "auction_payment_safety": "Treat as a protected accounting or reentrancy boundary; refresh balances/credits and retry only through the documented flow.",
    "mint_ledger_accounting": "Treat as a protected mint accounting boundary; refresh manager authorization, phase policy hash, counter policy, replay ID, and counter values before retrying.",
    "primary_settlement_safety": "Treat as a protected primary-sale settlement boundary; refresh sale context, assignment hash, asset policy, replay state, and ERC-20 allowance/balance before retrying.",
    "revenue_assignment_safety": "Refresh resolver assignment, template, materialized account, and split-wallet state before retrying; unsupported dynamic sources and frozen assignments are terminal unless governance changes configuration.",
    "split_payment_safety": "Refresh split profile, wallet, and asset state; invalid profiles, unsupported assets, and release precondition failures are terminal unless the submitted state changes.",
    "supply_minting": "Refresh collection/token state before retrying; supply windows, minted state, and burn boundaries are authoritative.",
    "configuration": "Verify the configured address, percentage, or protocol parameter before retrying.",
}

TRACEABILITY_BY_CATEGORY = {
    "access_control": [
        "test/StreamCustomErrorNegative.t.sol",
        "test/StreamCoreCustomErrors.t.sol",
    ],
    "asset_policy_safety": [
        "test/StreamSplitWallet.t.sol",
    ],
    "pause_emergency": [
        "test/StreamPauseControls.t.sol",
        "test/StreamCustomErrorNegative.t.sol",
    ],
    "metadata_integrity": [
        "test/StreamMetadataCrossInvariants.t.sol",
        "test/StreamMetadataUtf8.t.sol",
        "test/StreamCustomErrorNegative.t.sol",
    ],
    "randomness_lifecycle": [
        "test/StreamRandomizerLifecycle.t.sol",
        "test/StreamRandomizerAdversarial.t.sol",
        "test/StreamCustomErrorNegative.t.sol",
    ],
    "auction_payment_safety": [
        "test/StreamPaymentsInvariant.t.sol",
        "test/StreamCustomErrorNegative.t.sol",
    ],
    "mint_ledger_accounting": [
        "test/StreamMintLedger.t.sol",
    ],
    "primary_settlement_safety": [
        "test/StreamPrimarySaleSettlement.t.sol",
    ],
    "revenue_assignment_safety": [
        "test/StreamPrimarySaleSettlement.t.sol",
    ],
    "split_payment_safety": [
        "test/StreamSplitWallet.t.sol",
    ],
    "supply_minting": [
        "test/StreamCoreCustomErrors.t.sol",
        "test/StreamCustomErrorNegative.t.sol",
    ],
    "configuration": [
        "test/StreamRoyalty.t.sol",
        "test/StreamCustomErrorNegative.t.sol",
    ],
}

TRACEABILITY_BY_ERROR_NAME = {
    "InvalidMintManagerContract": [
        "test/StreamMintManagerCoreHooks.t.sol",
    ],
    "NotMintManager": [
        "test/StreamMintManagerCoreHooks.t.sol",
    ],
    "PreparedMintAlreadyPending": [
        "test/StreamMintManagerCoreHooks.t.sol",
    ],
    "PreparedMintMismatch": [
        "test/StreamMintManagerCoreHooks.t.sol",
    ],
    "PreparedMintNotFound": [
        "test/StreamMintManagerCoreHooks.t.sol",
    ],
    "PreparedMintOperationReused": [
        "test/StreamMintManagerCoreHooks.t.sol",
    ],
    "TokenDataHashMismatch": [
        "test/StreamMintManagerCoreHooks.t.sol",
    ],
}


def load_json(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise CustomErrorCatalogError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise CustomErrorCatalogError(f"invalid JSON in {path}: {exc}") from exc


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def normalize_path(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def require_dict(value: Any, path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise CustomErrorCatalogError(f"{path} must be an object")
    return value


def require_list(value: Any, path: str) -> list[Any]:
    if not isinstance(value, list):
        raise CustomErrorCatalogError(f"{path} must be a list")
    return value


def classify_error(contract_name: str, name: str, signature: str) -> str:
    category = CATEGORY_BY_ERROR_ID.get(canonical_error_id(contract_name, signature))
    if category is not None:
        return category
    try:
        return CATEGORY_BY_ERROR_NAME[name]
    except KeyError as exc:
        raise CustomErrorCatalogError(
            f"{signature} is not covered by custom error category map"
        ) from exc


def canonical_error_id(contract_name: str, signature: str) -> str:
    return f"{contract_name}:{signature}"


def catalog_entry(
    contract_name: str,
    contract: dict[str, Any],
    error: dict[str, Any],
) -> dict[str, Any]:
    name = str(error.get("name", ""))
    signature = str(error.get("signature", ""))
    selector = str(error.get("selector", ""))
    if not name or not signature:
        raise CustomErrorCatalogError(f"{contract_name} has a custom error missing name/signature")
    if not SELECTOR_RE.fullmatch(selector):
        raise CustomErrorCatalogError(f"{contract_name}:{signature} has invalid selector {selector!r}")

    category = classify_error(contract_name, name, signature)
    tests = list(TRACEABILITY_BY_CATEGORY[category])
    for test_path in TRACEABILITY_BY_ERROR_NAME.get(name, []):
        if test_path not in tests:
            tests.append(test_path)

    return {
        "id": canonical_error_id(contract_name, signature),
        "contract": contract_name,
        "source": str(contract.get("source", "")),
        "name": name,
        "signature": signature,
        "selector": selector,
        "category": category,
        "severity": SEVERITY_BY_CATEGORY[category],
        "inputs": error.get("inputs", []),
        "caller_action": CALLER_ACTION_BY_CATEGORY[category],
        "traceability": {
            "source_artifact": str(contract.get("artifact_path", "")),
            "tests": tests,
            "surface_report": "release-artifacts/latest/protocol-surface-report.json",
        },
    }


def build_catalog(repo_root: Path, surface_path: Path, output_path: Path) -> dict[str, Any]:
    surface = require_dict(load_json(surface_path), str(surface_path))
    contracts = require_dict(surface.get("contracts"), f"{surface_path}.contracts")

    entries = []
    categories: dict[str, int] = {}
    severities: dict[str, int] = {}
    selectors: dict[str, list[str]] = {}
    for contract_name in sorted(contracts):
        contract = require_dict(contracts[contract_name], f"contracts.{contract_name}")
        for error in require_list(contract.get("custom_errors"), f"contracts.{contract_name}.custom_errors"):
            entry = catalog_entry(contract_name, contract, require_dict(error, "custom_error"))
            entries.append(entry)
            categories[entry["category"]] = categories.get(entry["category"], 0) + 1
            severities[entry["severity"]] = severities.get(entry["severity"], 0) + 1
            selectors.setdefault(entry["selector"], []).append(entry["id"])

    entries.sort(key=lambda item: (item["contract"], item["signature"]))
    duplicate_selectors = {
        selector: sorted(ids)
        for selector, ids in sorted(selectors.items())
        if len(ids) > 1
    }

    return {
        "schema_version": CATALOG_SCHEMA,
        "generated_by": f"scripts/generate_custom_error_catalog.py:{GENERATOR_VERSION}",
        "source": {
            "protocol_surface_report": normalize_path(surface_path, repo_root),
            "output": normalize_path(output_path, repo_root),
        },
        "summary": {
            "custom_error_count": len(entries),
            "contract_count": len({entry["contract"] for entry in entries}),
            "category_counts": dict(sorted(categories.items())),
            "severity_counts": dict(sorted(severities.items())),
            "duplicate_selectors": duplicate_selectors,
        },
        "entries": entries,
    }


def validate_catalog(catalog: dict[str, Any], repo_root: Path | None = None) -> None:
    if catalog.get("schema_version") != CATALOG_SCHEMA:
        raise CustomErrorCatalogError("custom error catalog has wrong schema_version")
    entries = require_list(catalog.get("entries"), "entries")
    ids = set()
    for entry_value in entries:
        entry = require_dict(entry_value, "entries[]")
        entry_id = str(entry.get("id", ""))
        if not entry_id:
            raise CustomErrorCatalogError("custom error catalog entry is missing id")
        if entry_id in ids:
            raise CustomErrorCatalogError(f"duplicate custom error catalog id: {entry_id}")
        ids.add(entry_id)
        if entry.get("severity") not in SEVERITY_BY_CATEGORY.values():
            raise CustomErrorCatalogError(f"{entry_id} has invalid severity")
        if entry.get("category") not in SEVERITY_BY_CATEGORY:
            raise CustomErrorCatalogError(f"{entry_id} has invalid category")
        if not SELECTOR_RE.fullmatch(str(entry.get("selector", ""))):
            raise CustomErrorCatalogError(f"{entry_id} has invalid selector")
        traceability = require_dict(entry.get("traceability"), f"{entry_id}.traceability")
        tests = require_list(traceability.get("tests"), f"{entry_id}.traceability.tests")
        if entry.get("severity") in {"critical", "high"} and not tests:
            raise CustomErrorCatalogError(f"{entry_id} is high severity without test traceability")
        for test_path in tests:
            if not isinstance(test_path, str) or not test_path.startswith("test/"):
                raise CustomErrorCatalogError(f"{entry_id} has invalid test traceability path")
            if repo_root is not None and not (repo_root / test_path).is_file():
                raise CustomErrorCatalogError(
                    f"{entry_id} references missing test traceability file: {test_path}"
                )


def generate_catalog(repo_root: Path, surface_path: Path, output_path: Path) -> Path:
    catalog = build_catalog(repo_root, surface_path, output_path)
    validate_catalog(catalog, repo_root)
    write_json(output_path, catalog)
    return output_path


def check_catalog(repo_root: Path, surface_path: Path, output_path: Path) -> int:
    if not output_path.exists():
        print(
            f"{output_path} is missing; run `python scripts/generate_custom_error_catalog.py`.",
            file=sys.stderr,
        )
        return 1

    try:
        validate_catalog(require_dict(load_json(output_path), str(output_path)), repo_root)
    except CustomErrorCatalogError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    with tempfile.TemporaryDirectory() as temp_dir:
        generated = Path(temp_dir) / output_path.name
        expected_catalog = build_catalog(repo_root, surface_path, output_path)
        validate_catalog(expected_catalog, repo_root)
        write_json(generated, expected_catalog)
        if not filecmp.cmp(generated, output_path, shallow=False):
            print(
                f"{output_path} is out of date; run "
                "`python scripts/generate_custom_error_catalog.py`.",
                file=sys.stderr,
            )
            return 1

    print(f"{output_path} is up to date")
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--surface", type=Path, default=DEFAULT_SURFACE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    repo_root = args.repo_root.resolve()
    surface_path = args.surface if args.surface.is_absolute() else repo_root / args.surface
    output_path = args.output if args.output.is_absolute() else repo_root / args.output

    try:
        if args.check:
            return check_catalog(repo_root, surface_path, output_path)
        written = generate_catalog(repo_root, surface_path, output_path)
    except CustomErrorCatalogError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(normalize_path(written, repo_root))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
