// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativeSettlementAdmission.sol";
import "./StreamNativeSettlementHash.sol";
import "./StreamPrimarySettlementHash.sol";
import "./StreamDeferredNativeSettlementValidation.sol";
import "./StreamNativeSupplementalHash.sol";
import "../../interfaces/stream/revenue/IStreamNativeSupplementalSettlement.sol";
import "../../interfaces/stream/revenue/IStreamNativeClearingSaleBinding.sol";
import "../../interfaces/stream/core/IStreamCoreIdentity.sol";

/// @notice Bounded financial admission over an actual prior floor settlement and consumed mint root.
/// @dev Token-to-operation association is the admitted consumer's atomic purchase record.
library StreamNativeSupplementalValidation {
    function validate(
        StreamDeferredNativeSettlementValidation.Bindings memory x,
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c,
        StreamPrimarySettlementTypes.PrimarySettlementResult memory original
    ) public view returns (uint256 amount) {
        StreamNativeSettlementTypes.NativeSettlementCandidate memory n = c.originalFloor;
        StreamNativeSupplementalTypes.ClearingPurchaseFacts memory p = c.purchase;
        if (
            msg.sender != n.saleAdapter || n.saleAdapter == address(0) || c.executor == address(0)
                || c.purchaseId == 0 || p.purchaseNonce == 0 || p.tokenId == 0
                || c.purchaseId != StreamNativeSupplementalHash.purchaseId(c)
                || p.status != StreamNativeSupplementalTypes.SUPPLEMENTAL_OWED
                || p.effectiveFinalizeBy == 0 || block.timestamp > p.effectiveFinalizeBy
                || p.floorPrice == 0 || p.floorPrice != n.sale.amount || p.paidPrice < p.floorPrice
                || p.globalClearingPrice < p.floorPrice || p.originalOperationId != n.operationId
                || p.originalAuthorizationDigest != n.executionBinding.saleAuthorizationDigest
                || n.sale.revenueClass != keccak256("PRIMARY_SALE") || n.sale.policyMode != 0
                || n.sale.tokenId != 0 || n.sale.collectionId == 0 || n.orchestrationOrder != 1
                || n.executionBinding.executionId != StreamNativeSettlementHash.executionId(n)
                || c.currentPrimaryPolicyHash == 0
        ) revert IStreamNativeSupplementalSettlement.InvalidNativeSupplementalSettlement();
        uint256 uniform = p.globalClearingPrice;
        if (p.hasPriceOverride) {
            if (p.priceOverride < p.floorPrice) {
                revert IStreamNativeSupplementalSettlement.InvalidNativeSupplementalSettlement();
            }
            if (p.priceOverride < uniform) uniform = p.priceOverride;
        } else if (p.priceOverride != 0) {
            revert IStreamNativeSupplementalSettlement.InvalidNativeSupplementalSettlement();
        }
        if (uniform != p.buyerUniformPrice || uniform > p.paidPrice || uniform <= p.floorPrice) {
            revert IStreamNativeSupplementalSettlement.InvalidNativeSupplementalSettlement();
        }
        amount = uniform - p.floorPrice;
        if (msg.value != amount) {
            revert IStreamNativeSupplementalSettlement.InvalidNativeSupplementalSettlement();
        }
        bytes32 key = StreamPrimarySettlementHash.settlementKey(
            address(this), n.saleAdapter, n.executionBinding.executionId
        );
        bytes32 commitment = StreamNativeSettlementHash.candidateCommitment(address(this), n);
        if (
            p.floorSettlementKey != key || p.floorCandidateCommitment != commitment
                || original.candidateCommitment != commitment || original.settlementKey != key
                || original.profileId != n.rights.profileId || original.wallet != n.rights.wallet
                || original.asset != address(0) || original.amount != p.floorPrice
                || original.executor != n.executor
                || original.executionId != n.executionBinding.executionId
                || original.operationIdentityCommitment != n.operationIdentityCommitment
                || original.currentPolicyHash != n.currentPolicyHash
                || original.boundPolicyHash != n.boundPolicyHash
        ) {
            revert IStreamNativeSupplementalSettlement.InvalidNativeSupplementalSettlement();
        }
        requireCurrent(x, c);
        if (
            _word(
                    n.mintManager,
                    abi.encodeWithSignature(
                        "isOperationRootUsed(bytes32)", n.operationIdentityCommitment
                    )
                ) != 1
        ) {
            revert IStreamNativeSupplementalSettlement.InvalidNativeSupplementalSettlement();
        }
        uint256 lifecycle =
            _word(x.core, abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (p.tokenId)));
        if (lifecycle != 2 && lifecycle != 3) {
            revert IStreamNativeSupplementalSettlement.InvalidNativeSupplementalSettlement();
        }
        uint256[4] memory identity;
        bytes memory data = abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (p.tokenId));
        bool ok;
        uint256 size;
        address core = x.core;
        assembly ("memory-safe") {
            ok := staticcall(gas(), core, add(data, 32), mload(data), identity, 128)
            size := returndatasize()
        }
        if (
            !ok || size != 128 || identity[0] != 1 || identity[1] != n.sale.collectionId
                || identity[3] > 1
        ) {
            revert IStreamNativeSupplementalSettlement.InvalidNativeSupplementalSettlement();
        }
    }

    function requireCurrent(
        StreamDeferredNativeSettlementValidation.Bindings memory x,
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c
    ) public view {
        StreamNativeSettlementTypes.NativeSettlementCandidate memory n = c.originalFloor;
        StreamNativeSettlementAdmission.requireAdmission(x.registry, n);
        StreamDeferredNativeSettlementValidation.requireBindings(x, n);
        if (
            _word(
                        n.saleAdapter,
                        abi.encodeWithSelector(
                            bytes4(0x01ffc9a7), type(IStreamNativeClearingSaleBinding).interfaceId
                        )
                    ) != 1
                || _word(n.saleAdapter, abi.encodeWithSignature("mintManagerCodeHash()"))
                    != uint256(n.mintManager.codehash)
                || _word(
                        n.saleAdapter,
                        abi.encodeCall(
                            IStreamNativeClearingSaleBinding.activeNativeSupplementalSettlement,
                            (c.purchaseId)
                        )
                    ) != uint256(StreamNativeSupplementalHash.candidateCommitment(address(this), c))
        ) {
            revert IStreamNativeSupplementalSettlement.InvalidNativeSupplementalSettlement();
        }
        bytes memory data =
            abi.encodeCall(IStreamNativeClearingSaleBinding.clearingPurchaseFacts, (c.purchaseId));
        uint256[14] memory words;
        bool ok;
        uint256 size;
        address adapter = n.saleAdapter;
        assembly ("memory-safe") {
            ok := staticcall(gas(), adapter, add(data, 32), mload(data), words, 448)
            size := returndatasize()
        }
        if (
            !ok || size != 448 || words[9] > 1 || words[12] > type(uint64).max
                || words[13] > type(uint8).max
        ) {
            revert IStreamNativeSupplementalSettlement.SupplementalFactsReadFailed(adapter, size);
        }
        if (keccak256(abi.encode(words)) != keccak256(abi.encode(c.purchase))) {
            revert IStreamNativeSupplementalSettlement.InvalidNativeSupplementalSettlement();
        }
    }

    function _word(address target, bytes memory data) private view returns (uint256 word) {
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        if (!ok || size != 32) {
            revert IStreamNativeSupplementalSettlement.InvalidNativeSupplementalSettlement();
        }
    }
}
