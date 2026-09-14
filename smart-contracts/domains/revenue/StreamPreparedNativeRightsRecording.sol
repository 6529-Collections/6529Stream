// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamPreparedNativeRightsAccounting.sol";
import "./StreamNativePrimaryExecution.sol";
import "./StreamScopedNativePrimaryExecution.sol";
import "./StreamPrimarySettlementEmission.sol";
import "./StreamPrimarySettlementHash.sol";

/// @notice New prepared recorder entry through a fixed linked boundary and exact storage refs.
/// @dev No storage overlay, callback-selected state or new authority. Original recorder context
/// and full facts are rechecked after funding; every effect remains in the same transaction.
library StreamPreparedNativeRightsRecording {
    struct Context {
        address core;
        bytes32 coreHash;
        address registry;
        bytes32 registryHash;
        bytes32 resolverHash;
        StreamNativePrimaryExecution.Context funding;
    }
    error InvalidSettlementContext(address target);
    event PreparedNativeRightsRevenueRecorded(
        bytes32 indexed settlementKey,
        bytes32 indexed saleKey,
        bytes32 indexed factsHash,
        StreamPreparedNativeRightsTypes.Facts facts,
        StreamPreparedNativeRightsTypes.Intent intent,
        bytes32 currentPrimaryPolicyHash
    );

    event DynamicPreparedPrimaryBeneficiariesBound(
        uint16 schemaVersion,
        bytes32 indexed settlementKey,
        bytes32 indexed templateId,
        bytes32 beneficiaryHash,
        address poster
    );

    function execute(
        Context memory x,
        mapping(bytes32 => bool) storage saleConsumed,
        mapping(bytes32 => bool) storage settlementConsumed,
        mapping(bytes32 => StreamPrimarySettlementTypes.PrimarySettlementResult) storage results,
        mapping(bytes32 => bytes32) storage factsHashes,
        mapping(bytes32 => uint256) storage officialSettled,
        mapping(address => uint256) storage totals,
        StreamPreparedNativeRightsTypes.Facts calldata rights,
        StreamPreparedNativeRightsTypes.Intent calldata original
    ) public returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result) {
        StreamPreparedNativeSettlementTypes.Facts memory facts = rights.mint;
        StreamPreparedNativeSettlementTypes.Intent memory intent = original.sale;
        requireContext(x);
        if (
            msg.sender != facts.saleAdapter || facts.recorder != address(this)
                || facts.recorderCodeHash != address(this).codehash || msg.value != intent.amount
                || intent.payer == address(this) || intent.payer == facts.saleAdapter
                || intent.payer == address(x.funding.escrow)
        ) revert IStreamPreparedNativePrimarySaleSettlement.InvalidPreparedNativeSettlement();
        StreamNativeSettlementTypes.SaleLifecycleBinding memory lifecycle =
            StreamPreparedNativeRightsValidation.requireActive(x.core, x.registry, rights, original);
        (
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
            StreamSaleTemplate.Selection memory selected,
            bytes32 beneficiaryHash
        ) = StreamPreparedNativeRightsAccounting.derive(
            x.funding.rights, rights, original, lifecycle
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
        bool escrowed;
        if (original.original.mode >= 5 && original.original.mode <= 7) {
            escrowed = StreamScopedNativePrimaryExecution.fund(
                x.funding,
                c.sale.collectionId,
                c.sale.tokenId,
                original.original.mode,
                intent.poster,
                c.sale.amount,
                selected,
                beneficiaryHash
            );
        } else if (
            original.original.mode == StreamPreparedNativeRightsTypes.DYNAMIC_COLLECTION_TEMPLATE
        ) {
            escrowed = StreamNativePrimaryExecution.fundForPoster(
                x.funding,
                c.sale.collectionId,
                c.sale.amount,
                selected,
                intent.poster,
                beneficiaryHash
            );
        } else {
            escrowed = StreamNativePrimaryExecution.fund(
                x.funding, c.sale.collectionId, c.sale.amount, selected
            );
        }
        requireContext(x);
        StreamNativeSettlementTypes.SaleLifecycleBinding memory current =
            StreamPreparedNativeRightsValidation.requireActive(x.core, x.registry, rights, original);
        (
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory after_,,
            bytes32 currentBeneficiaries
        ) = StreamPreparedNativeRightsAccounting.derive(x.funding.rights, rights, original, current);
        if (
            keccak256(abi.encode(after_)) != keccak256(abi.encode(c))
                || currentBeneficiaries != beneficiaryHash
        ) {
            revert IStreamPreparedNativePrimarySaleSettlement.InvalidPreparedNativeSettlement();
        }
        result = StreamPrimarySettlementTypes.PrimarySettlementResult(
            StreamPreparedNativeRightsHash.candidateCommitment(rights, original, c),
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
        factsHashes[key] = StreamPreparedNativeRightsHash.factsHash(rights);
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
        if (beneficiaryHash != 0) {
            emit DynamicPreparedPrimaryBeneficiariesBound(
                1, key, selected.templateId, beneficiaryHash, intent.poster
            );
        }
        emit PreparedNativeRightsRevenueRecorded(
            key, saleKey, factsHashes[key], rights, original, c.sale.expectedPrimaryPolicyHash
        );
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
