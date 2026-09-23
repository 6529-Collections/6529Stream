// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamPreparedNativeSettlementAccounting.sol";
import "./StreamPreparedNativeOfferValidation.sol";
import "./StreamNativePrimaryExecution.sol";
import "./StreamPrimarySettlementEmission.sol";
import "./StreamPrimarySettlementHash.sol";

/// @notice Positive strict-policy primary offers through an independently authenticated admission.
/// @dev No storage overlay, callback-selected state or new authority. Original recorder context
/// and full facts are rechecked after funding; every effect remains in the same transaction.
library StreamPreparedNativeOfferRecording {
    struct Context {
        address core;
        bytes32 coreHash;
        address registry;
        bytes32 registryHash;
        bytes32 resolverHash;
        StreamNativePrimaryExecution.Context funding;
    }
    error InvalidSettlementContext(address target);
    error PreparedNativeOfferAlreadySettled(address adapter, bytes32 purchaseId);
    event PreparedNativeOfferRecorded(
        uint16 schemaVersion,
        address indexed adapter,
        bytes32 indexed purchaseId,
        bytes32 indexed settlementKey,
        bytes32 saleId,
        uint256 saleNonce,
        bytes32 offerDigest,
        bytes32 authorizationDigest
    );
    event PreparedNativeOfferRevenueRecorded(
        bytes32 indexed settlementKey,
        bytes32 indexed saleKey,
        bytes32 indexed factsHash,
        StreamPreparedNativeSettlementTypes.Facts facts,
        StreamPreparedNativeSettlementTypes.Intent intent
    );

    event PreparedNativeOfferContentRecorded(
        bytes32 indexed settlementKey,
        bytes32 indexed contentHash,
        StreamPreparedNativeContentTypes.Facts content
    );

    function execute(
        Context memory x,
        mapping(address => mapping(bytes32 => bool)) storage purchaseConsumed,
        mapping(
            bytes32 => bool
        ) storage settlementConsumed,
        mapping(bytes32 => StreamPrimarySettlementTypes.PrimarySettlementResult) storage results,
        mapping(bytes32 => bytes32) storage factsHashes,
        mapping(bytes32 => bytes32) storage contentHashes,
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
            StreamPreparedNativeOfferValidation.requireActive(x.core, x.registry, facts, intent);
        (
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
            StreamSaleTemplate.Selection memory selected
        ) = StreamPreparedNativeSettlementAccounting.derive(
            x.funding.rights, facts, intent, lifecycle
        );
        if (
            intent.payer == selected.wallet
                || c.sale.expectedPrimaryPolicyHash != intent.originalPrimaryPolicyHash
        ) {
            revert IStreamPreparedNativePrimarySaleSettlement.InvalidPreparedNativeSettlement();
        }
        bytes32 saleKey = StreamPreparedNativeSettlementHash.saleKey(
            address(this), facts.saleAdapter, intent.saleId, intent.saleNonce
        );
        bytes32 key = StreamPrimarySettlementHash.settlementKey(
            address(this), facts.saleAdapter, c.executionBinding.executionId
        );
        StreamPreparedNativeOfferTypes.Purchase memory purchase =
            StreamPreparedNativeOfferHash.readPurchase(facts.saleAdapter, facts.intentHash, intent);
        if (purchaseConsumed[facts.saleAdapter][purchase.purchaseId]) {
            revert PreparedNativeOfferAlreadySettled(facts.saleAdapter, purchase.purchaseId);
        }
        if (settlementConsumed[key]) {
            revert IStreamPrimarySaleSettlement.SettlementAlreadyConsumed(key);
        }
        purchaseConsumed[facts.saleAdapter][purchase.purchaseId] = true;
        settlementConsumed[key] = true;
        bool escrowed = StreamNativePrimaryExecution.fund(
            x.funding, c.sale.collectionId, c.sale.amount, selected
        );
        requireContext(x);
        StreamNativeSettlementTypes.SaleLifecycleBinding memory current =
            StreamPreparedNativeOfferValidation.requireActive(x.core, x.registry, facts, intent);
        (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory after_,) = StreamPreparedNativeSettlementAccounting.derive(
            x.funding.rights, facts, intent, current
        );
        if (keccak256(abi.encode(after_)) != keccak256(abi.encode(c))) {
            revert IStreamPreparedNativePrimarySaleSettlement.InvalidPreparedNativeSettlement();
        }
        StreamPreparedNativeContentTypes.Facts memory content =
            StreamPreparedNativeOfferReads.requireActive(x.registry, facts, intent);
        if (
            keccak256(
                    abi.encode(
                        StreamPreparedNativeOfferHash.readPurchase(
                            facts.saleAdapter, facts.intentHash, intent
                        )
                    )
                ) != keccak256(abi.encode(purchase))
        ) {
            revert IStreamPreparedNativePrimarySaleSettlement.InvalidPreparedNativeSettlement();
        }
        result = StreamPrimarySettlementTypes.PrimarySettlementResult(
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_PREPARED_NATIVE_OFFER_CANDIDATE_V1"),
                    block.chainid,
                    address(this),
                    facts,
                    content,
                    intent,
                    purchase,
                    c
                )
            ),
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
        contentHashes[key] = StreamPreparedNativeContentHash.factsHash(content);
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
        emit PreparedNativeOfferRevenueRecorded(key, saleKey, factsHashes[key], facts, intent);
        emit PreparedNativeOfferContentRecorded(key, contentHashes[key], content);
        emit PreparedNativeOfferRecorded(
            1,
            facts.saleAdapter,
            purchase.purchaseId,
            key,
            intent.saleId,
            intent.saleNonce,
            purchase.offerDigest,
            intent.saleAuthorizationDigest
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
