// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamConservationFloorReads.sol";
import "../revenue/StreamNativeSettlementHash.sol";
import "../revenue/StreamNativeSupplementalHash.sol";
import "../../interfaces/stream/revenue/IStreamNativeClearingSaleBinding.sol";
import "../../interfaces/stream/revenue/IStreamNativeSupplementalSettlement.sol";

/// @notice Exact native purchase joins for supplemental payments against an immutable floor receipt.
/// @dev Runs in the permanent ledger, after the admitted recorder has stored both consumed results.
library StreamConservationFloorSupplemental {
    function requireOriginal(
        StreamConservationFloorReads.Context memory x,
        StreamConservationFloorTypes.SettlementReceipt memory original,
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c,
        StreamNativeSupplementalTypes.NativeSupplementalResult memory r
    ) public view {
        _original(x, original, c);
        _result(x, c, r);
        _purchase(x, c, r);
    }

    function _original(
        StreamConservationFloorReads.Context memory x,
        StreamConservationFloorTypes.SettlementReceipt memory original,
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c
    ) private view {
        StreamNativeSettlementTypes.NativeSettlementCandidate memory n = c.originalFloor;
        bytes32 commitment = StreamNativeSettlementHash.candidateCommitment(msg.sender, n);
        bytes32 key = StreamPrimarySettlementHash.settlementKey(
            msg.sender, n.saleAdapter, n.executionBinding.executionId
        );
        if (
            original.recorder != msg.sender || original.recorderCodeHash != msg.sender.codehash
                || original.collectionId != n.sale.collectionId || original.tokenId != 0
                || original.settlementKey != key || key != c.purchase.floorSettlementKey
                || original.candidateCommitment != commitment
                || commitment != c.purchase.floorCandidateCommitment
                || original.candidatePayloadHash
                    != keccak256(abi.encode(StreamNativeSettlementHash.accountingContext(n)))
                || n.sale.revenueClass != keccak256("PRIMARY_SALE") || n.sale.policyMode != 0
                || n.sale.tokenId != 0 || n.sale.collectionId == 0 || n.orchestrationOrder != 1
                || n.executionBinding.executionId != StreamNativeSettlementHash.executionId(n)
        ) revert IStreamConservationFloor.ConservationFloorSettlementMismatch(key);
        bytes memory raw = StreamConservationFloorReads.read(
            msg.sender,
            abi.encodeCall(IStreamPrimarySaleSettlement.settlementResult, (key)),
            384,
            x.readGas
        );
        StreamPrimarySettlementTypes.PrimarySettlementResult memory previous =
            abi.decode(raw, (StreamPrimarySettlementTypes.PrimarySettlementResult));
        if (
            keccak256(raw) != original.resultHash
                || keccak256(raw) != keccak256(abi.encode(previous))
        ) {
            revert IStreamConservationFloor.ConservationFloorSettlementMismatch(key);
        }
        // Reuses exact field/result checks, including native asset zero and the same collection.
        StreamConservationFloorReads.requireCandidate(
            x, msg.sender, StreamNativeSettlementHash.accountingContext(n), previous
        );
    }

    function _result(
        StreamConservationFloorReads.Context memory x,
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c,
        StreamNativeSupplementalTypes.NativeSupplementalResult memory r
    ) private view {
        bytes32 executionId = StreamNativeSupplementalHash.executionId(msg.sender, c);
        if (
            r.candidateCommitment != StreamNativeSupplementalHash.candidateCommitment(msg.sender, c)
                || r.settlementKey
                    != StreamPrimarySettlementHash.settlementKey(
                        msg.sender, c.originalFloor.saleAdapter, executionId
                    ) || r.executionId != executionId || r.purchaseId != c.purchaseId
                || r.originalFloorSettlementKey != c.purchase.floorSettlementKey
                || r.tokenId != c.purchase.tokenId || r.profileId == 0 || r.wallet == address(0)
                || r.profileId != c.currentRights.profileId || r.wallet != c.currentRights.wallet
                || r.executor != c.executor || c.executor == address(0)
                || r.originalOperationRoot != c.originalFloor.operationIdentityCommitment
                || r.originalOperationId != c.originalFloor.operationId
                || r.originalExpectedPrimaryPolicyHash
                    != c.originalFloor.sale.expectedPrimaryPolicyHash
                || r.currentPrimaryPolicyHash != c.currentPrimaryPolicyHash
                || c.currentPrimaryPolicyHash == 0
                || r.policyDrift
                    != (r.originalExpectedPrimaryPolicyHash != r.currentPrimaryPolicyHash)
                || keccak256(
                        StreamConservationFloorReads.read(
                            msg.sender,
                            abi.encodeCall(
                                IStreamNativeSupplementalSettlement.nativeSupplementalResult,
                                (r.settlementKey)
                            ),
                            512,
                            x.readGas
                        )
                    ) != keccak256(abi.encode(r))
        ) revert IStreamConservationFloor.ConservationFloorSettlementMismatch(r.settlementKey);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory common =
            StreamPrimarySettlementTypes.PrimarySettlementResult(
                r.candidateCommitment,
                r.settlementKey,
                r.profileId,
                r.wallet,
                address(0),
                r.amount,
                r.executor,
                r.executionId,
                r.escrowed,
                r.originalOperationRoot,
                c.originalFloor.currentPolicyHash,
                c.originalFloor.boundPolicyHash
            );
        StreamConservationFloorReads.requireStoredResult(x, msg.sender, common);
    }

    function _purchase(
        StreamConservationFloorReads.Context memory x,
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c,
        StreamNativeSupplementalTypes.NativeSupplementalResult memory r
    ) private view {
        StreamNativeSupplementalTypes.ClearingPurchaseFacts memory p = c.purchase;
        if (
            c.purchaseId == 0 || c.purchaseId != StreamNativeSupplementalHash.purchaseId(c)
                || p.purchaseNonce == 0 || p.tokenId == 0
                || p.status != StreamNativeSupplementalTypes.SUPPLEMENTAL_OWED
                || p.effectiveFinalizeBy == 0 || block.timestamp > p.effectiveFinalizeBy
                || p.floorPrice == 0 || p.floorPrice != c.originalFloor.sale.amount
                || p.paidPrice < p.floorPrice || p.globalClearingPrice < p.floorPrice
                || p.originalOperationId != c.originalFloor.operationId
                || p.originalAuthorizationDigest
                    != c.originalFloor.executionBinding.saleAuthorizationDigest
        ) revert IStreamConservationFloor.ConservationFloorSettlementMismatch(r.settlementKey);
        uint256 uniform = p.globalClearingPrice;
        if (p.hasPriceOverride) {
            if (p.priceOverride < p.floorPrice) {
                revert IStreamConservationFloor.ConservationFloorInvalidEvidence();
            }
            if (p.priceOverride < uniform) uniform = p.priceOverride;
        } else if (p.priceOverride != 0) {
            revert IStreamConservationFloor.ConservationFloorInvalidEvidence();
        }
        if (
            uniform != p.buyerUniformPrice || uniform > p.paidPrice || uniform <= p.floorPrice
                || r.amount != uniform - p.floorPrice
        ) revert IStreamConservationFloor.ConservationFloorInvalidEvidence();
        _consumer(x, c, r.candidateCommitment);
        StreamConservationFloorReads.requireToken(
            x, c.originalFloor.sale.collectionId, p.tokenId, true
        );
    }

    function _consumer(
        StreamConservationFloorReads.Context memory x,
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c,
        bytes32 commitment
    ) private view {
        StreamNativeSettlementTypes.NativeSettlementCandidate memory n = c.originalFloor;
        StreamConservationFloorReads.requireNativeSale(x, n);
        address adapter = n.saleAdapter;
        if (
            StreamConservationFloorReads.word(adapter, abi.encodeWithSignature("core()"), x.readGas)
                    != uint160(x.core)
                || StreamConservationFloorReads.word(
                        adapter, abi.encodeWithSignature("primarySaleSettlement()"), x.readGas
                    ) != uint160(msg.sender)
                || StreamConservationFloorReads.word(
                        adapter, abi.encodeWithSignature("mintManager()"), x.readGas
                    ) != uint160(n.mintManager)
                || bytes32(
                        StreamConservationFloorReads.word(
                            adapter, abi.encodeWithSignature("mintManagerCodeHash()"), x.readGas
                        )
                    ) != n.mintManager.codehash
                || StreamConservationFloorReads.word(
                        adapter,
                        abi.encodeCall(
                            IERC165.supportsInterface,
                            (type(IStreamNativeClearingSaleBinding).interfaceId)
                        ),
                        x.readGas
                    ) != 1
                || bytes32(
                        StreamConservationFloorReads.word(
                            adapter,
                            abi.encodeCall(
                                IStreamNativeClearingSaleBinding.activeNativeSupplementalSettlement,
                                (c.purchaseId)
                            ),
                            x.readGas
                        )
                    ) != commitment
                || keccak256(
                        StreamConservationFloorReads.read(
                            adapter,
                            abi.encodeCall(
                                IStreamNativeClearingSaleBinding.clearingPurchaseFacts,
                                (c.purchaseId)
                            ),
                            448,
                            x.readGas
                        )
                    ) != keccak256(abi.encode(c.purchase))
                || StreamConservationFloorReads.word(
                        n.mintManager,
                        abi.encodeWithSignature(
                            "isOperationRootUsed(bytes32)", n.operationIdentityCommitment
                        ),
                        x.readGas
                    ) != 1
        ) revert IStreamConservationFloor.ConservationFloorAuthority(adapter);
    }
}
