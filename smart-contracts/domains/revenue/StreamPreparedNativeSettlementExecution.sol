// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamPreparedNativeSettlementAccounting.sol";
import "./StreamNativePrimaryExecution.sol";
import "./StreamPrimarySettlementEmission.sol";
import "./StreamPrimarySettlementHash.sol";

/// @notice New prepared recorder entry through a fixed linked boundary and exact storage refs.
/// @dev No storage overlay, callback-selected state or new authority. Original recorder context
/// and full facts are rechecked after funding; every effect remains in the same transaction.
library StreamPreparedNativeSettlementExecution {
    struct Context {
        address core;
        bytes32 coreHash;
        address registry;
        bytes32 registryHash;
        bytes32 resolverHash;
        StreamNativePrimaryExecution.Context funding;
    }
    error InvalidSettlementContext(address target);
    event PreparedNativeRevenueRecorded(
        bytes32 indexed settlementKey,
        bytes32 indexed saleKey,
        bytes32 indexed factsHash,
        StreamPreparedNativeSettlementTypes.Facts facts,
        StreamPreparedNativeSettlementTypes.Intent intent
    );

    function execute(
        Context memory x,
        mapping(bytes32 => bool) storage saleConsumed,
        mapping(bytes32 => bool) storage settlementConsumed,
        mapping(bytes32 => StreamPrimarySettlementTypes.PrimarySettlementResult) storage results,
        mapping(bytes32 => bytes32) storage factsHashes,
        mapping(bytes32 => uint256) storage officialSettled,
        mapping(address => uint256) storage totals,
        StreamPreparedNativeSettlementTypes.Facts calldata facts,
        StreamPreparedNativeSettlementTypes.Intent calldata intent
    ) public returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result) {
        requireContext(x);
        if (
            msg.sender != facts.saleAdapter || facts.recorder != address(this)
                || facts.recorderCodeHash != address(this).codehash || msg.value != intent.amount
                || intent.payer == address(this) || intent.payer == facts.saleAdapter
                || intent.payer == address(x.funding.escrow)
        ) revert IStreamPreparedNativePrimarySaleSettlement.InvalidPreparedNativeSettlement();
        StreamNativeSettlementTypes.SaleLifecycleBinding memory lifecycle =
            StreamPreparedNativeSettlementValidation.requireActive(
                x.core, x.registry, facts, intent
            );
        (
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
            StreamSaleTemplate.Selection memory selected
        ) = StreamPreparedNativeSettlementAccounting.derive(
            x.funding.rights, facts, intent, lifecycle
        );
        if (intent.payer == selected.wallet) {
            revert IStreamPreparedNativePrimarySaleSettlement.InvalidPreparedNativeSettlement();
        }
        bytes32 saleKey = StreamPreparedNativeSettlementHash.saleKey(
            address(this), facts.saleAdapter, intent.saleId, intent.saleNonce
        );
        bytes32 key = StreamPrimarySettlementHash.settlementKey(
            address(this), facts.saleAdapter, c.executionBinding.executionId
        );
        if (saleConsumed[saleKey]) {
            revert IStreamPreparedNativePrimarySaleSettlement.PreparedNativeSaleAlreadySettled(saleKey);
        }
        if (settlementConsumed[key]) {
            revert IStreamPrimarySaleSettlement.SettlementAlreadyConsumed(key);
        }
        saleConsumed[saleKey] = true;
        settlementConsumed[key] = true;
        bool escrowed = StreamNativePrimaryExecution.fund(
            x.funding, c.sale.collectionId, c.sale.amount, selected
        );
        requireContext(x);
        StreamNativeSettlementTypes.SaleLifecycleBinding memory current =
            StreamPreparedNativeSettlementValidation.requireActive(
                x.core, x.registry, facts, intent
            );
        (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory after_,) = StreamPreparedNativeSettlementAccounting.derive(
            x.funding.rights, facts, intent, current
        );
        if (keccak256(abi.encode(after_)) != keccak256(abi.encode(c))) {
            revert IStreamPreparedNativePrimarySaleSettlement.InvalidPreparedNativeSettlement();
        }
        result = StreamPrimarySettlementTypes.PrimarySettlementResult(
            StreamPreparedNativeSettlementHash.candidateCommitment(facts, intent, c),
            key,
            selected.profileId,
            selected.wallet,
            address(0),
            intent.amount,
            intent.executor,
            c.executionBinding.executionId,
            escrowed,
            facts.operationRoot,
            facts.currentPolicyHash,
            facts.boundPolicyHash
        );
        results[key] = result;
        factsHashes[key] = StreamPreparedNativeSettlementHash.factsHash(facts);
        officialSettled[
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_OFFICIAL_PRIMARY_SETTLED_V1"),
                    keccak256("PRIMARY_SALE"),
                    selected.profileId,
                    selected.wallet,
                    address(0)
                )
            )
        ] += intent.amount;
        totals[address(0)] += intent.amount;
        StreamPrimarySettlementEmission.emitSettlement(
            c, result, address(0), intent.originalPrimaryPolicyHash
        );
        emit PreparedNativeRevenueRecorded(key, saleKey, factsHashes[key], facts, intent);
    }

    function requireContext(Context memory x) private view {
        StreamSettlementAdmission.requireRegistry(x.core, x.coreHash, x.registry, x.registryHash);
        if (address(x.funding.rights.resolver).codehash != x.resolverHash) {
            revert InvalidSettlementContext(address(x.funding.rights.resolver));
        }
        if (address(x.funding.rights.factory).codehash != x.funding.factoryHash) {
            revert InvalidSettlementContext(address(x.funding.rights.factory));
        }
    }
}
