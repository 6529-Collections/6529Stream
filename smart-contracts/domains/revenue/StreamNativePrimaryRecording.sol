// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativePrimaryExecution.sol";
import "./StreamNativeSettlementAdmission.sol";
import "./StreamPrimarySettlementValidation.sol";
import "./StreamPrimarySettlementEmission.sol";
import "./StreamPrimarySettlementHash.sol";
import "./StreamDeferredNativeSettlementValidation.sol";

/// @notice Existing native and deferred recorder execution behind a fixed compiler link.
/// @dev The original recorder owns the nonReentrant guard and supplies its exact immutable
/// context and storage references. Delegatecall preserves recorder identity, caller, value,
/// event emitter and all-or-nothing payment/replay/result effects; no new authority is added.
library StreamNativePrimaryRecording {
    bytes32 private constant _CLASS = keccak256("PRIMARY_SALE");
    bytes32 private constant _TOTAL = keccak256("6529STREAM_OFFICIAL_PRIMARY_SETTLED_V1");
    error InvalidSettlementContext(address target);

    struct Context {
        address core;
        bytes32 coreHash;
        address registry;
        bytes32 registryHash;
        bytes32 resolverHash;
        StreamNativePrimaryExecution.Context funding;
    }

    function settleNative(
        Context memory x,
        mapping(bytes32 => bool) storage settlementConsumed,
        mapping(
            bytes32 => StreamPrimarySettlementTypes.PrimarySettlementResult
        ) storage _results,
        mapping(bytes32 => uint256) storage _officialSettled,
        mapping(address => uint256) storage totalOfficialSettled,
        StreamNativeSettlementTypes.NativeSettlementCandidate calldata candidate
    ) public returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result) {
        StreamNativeSettlementTypes.NativeSettlementCandidate memory n = candidate;
        _validateNative(x, n);
        bytes32 key = StreamPrimarySettlementHash.settlementKey(
            address(this), n.saleAdapter, n.executionBinding.executionId
        );
        if (settlementConsumed[key]) {
            revert IStreamPrimarySaleSettlement.SettlementAlreadyConsumed(key);
        }
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c =
            StreamNativeSettlementHash.accountingContext(n);
        StreamSaleTemplate.Selection memory selected = _resolve(x, c);
        settlementConsumed[key] = true;
        bool escrowed = StreamNativePrimaryExecution.fund(
            x.funding, c.sale.collectionId, c.sale.amount, selected
        );
        _requireNativeContext(x);
        StreamNativeSettlementAdmission.requireAdmission(x.registry, n);
        _requireCurrent(x, c, selected);
        result = StreamPrimarySettlementTypes.PrimarySettlementResult(
            StreamNativeSettlementHash.candidateCommitment(address(this), n),
            key,
            selected.profileId,
            selected.wallet,
            address(0),
            c.sale.amount,
            c.executor,
            c.executionBinding.executionId,
            escrowed,
            c.operationIdentityCommitment,
            c.currentPolicyHash,
            c.boundPolicyHash
        );
        _results[key] = result;
        _officialSettled[
            _totalKey(_CLASS, selected.profileId, selected.wallet, address(0))
        ] += c.sale.amount;
        totalOfficialSettled[address(0)] += c.sale.amount;
        StreamPrimarySettlementEmission.emitSettlement(
            c, result, address(0), c.sale.expectedPrimaryPolicyHash
        );
    }

    function settleDeferred(
        Context memory x,
        mapping(bytes32 => bool) storage settlementConsumed,
        mapping(
            bytes32 => StreamPrimarySettlementTypes.PrimarySettlementResult
        ) storage _results,
        mapping(bytes32 => uint256) storage _officialSettled,
        mapping(address => uint256) storage totalOfficialSettled,
        mapping(bytes32 => bool) storage deferredPurchaseConsumed,
        StreamDeferredNativeSettlementTypes.DeferredNativeCandidate calldata candidate
    ) public returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result) {
        StreamDeferredNativeSettlementTypes.DeferredNativeCandidate memory d = candidate;
        _requireNativeContext(x);
        StreamDeferredNativeSettlementValidation.validate(
            StreamDeferredNativeSettlementValidation.Bindings(
                x.core, x.registry, address(x.funding.rights.resolver), address(x.funding.escrow)
            ),
            d
        );
        bytes32 purchaseKey = StreamDeferredNativeSettlementHash.purchaseKey(
            address(this), d.execution.saleAdapter, d.purchaseId
        );
        if (deferredPurchaseConsumed[purchaseKey]) {
            revert IStreamPrimarySaleSettlement.SettlementAlreadyConsumed(purchaseKey);
        }
        bytes32 key = StreamPrimarySettlementHash.settlementKey(
            address(this), d.execution.saleAdapter, d.execution.executionBinding.executionId
        );
        if (settlementConsumed[key]) {
            revert IStreamPrimarySaleSettlement.SettlementAlreadyConsumed(key);
        }
        deferredPurchaseConsumed[purchaseKey] = true;
        settlementConsumed[key] = true;
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c =
            StreamNativeSettlementHash.accountingContext(d.execution);
        StreamSaleTemplate.Selection memory selected = _resolve(x, c);
        bool escrowed = StreamNativePrimaryExecution.fund(
            x.funding, c.sale.collectionId, c.sale.amount, selected
        );
        _requireNativeContext(x);
        StreamDeferredNativeSettlementAdmission.requireAdmission(x.registry, d.execution);
        _requireCurrent(x, c, selected);
        result = StreamPrimarySettlementTypes.PrimarySettlementResult(
            StreamDeferredNativeSettlementHash.candidateCommitment(address(this), d),
            key,
            selected.profileId,
            selected.wallet,
            address(0),
            c.sale.amount,
            c.executor,
            c.executionBinding.executionId,
            escrowed,
            c.operationIdentityCommitment,
            c.currentPolicyHash,
            c.boundPolicyHash
        );
        _results[key] = result;
        _officialSettled[
            _totalKey(_CLASS, selected.profileId, selected.wallet, address(0))
        ] += c.sale.amount;
        totalOfficialSettled[address(0)] += c.sale.amount;
        StreamPrimarySettlementEmission.emitSettlement(
            c, result, address(0), d.originalPrimaryPolicyHash
        );
    }

    function _validateNative(
        Context memory x,
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c
    ) private view {
        StreamPrimarySettlementValidation.Bindings memory
            bindings = StreamPrimarySettlementValidation.Bindings(
            x.core, x.registry, address(x.funding.rights.resolver), address(x.funding.escrow)
        );
        StreamPrimarySettlementValidation.nativeFields(bindings, c);
        _requireNativeContext(x);
        StreamNativeSettlementAdmission.requireAdmission(x.registry, c);
        StreamPrimarySettlementValidation.nativeBindings(bindings, c);
    }

    function _requireNativeContext(Context memory x) private view {
        StreamSettlementAdmission.requireRegistry(x.core, x.coreHash, x.registry, x.registryHash);
        if (address(x.funding.rights.resolver).codehash != x.resolverHash) {
            revert InvalidSettlementContext(address(x.funding.rights.resolver));
        }
        if (address(x.funding.rights.factory).codehash != x.funding.factoryHash) {
            revert InvalidSettlementContext(address(x.funding.rights.factory));
        }
    }

    function _resolve(
        Context memory x,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
    ) private view returns (StreamSaleTemplate.Selection memory) {
        return StreamPrimarySettlementRights.resolve(
            x.funding.rights, c.sale.collectionId, c.rights, c.sale.expectedPrimaryPolicyHash
        );
    }

    function _requireCurrent(
        Context memory x,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        StreamSaleTemplate.Selection memory rights
    ) private view {
        StreamPrimarySettlementRights.requireCurrent(
            x.funding.rights,
            c.sale.collectionId,
            c.rights,
            c.sale.expectedPrimaryPolicyHash,
            rights
        );
    }

    function _totalKey(bytes32 revenueClass, bytes32 profileId, address wallet, address asset)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_TOTAL, revenueClass, profileId, wallet, asset));
    }
}
