// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamClearingSaleSupport.sol";
import "./StreamClearingClock.sol";

/// @notice Explicit new-consumer storage and bounded reads shared by typed linked execution.
library StreamClearingSaleState {
    struct State {
        StreamClearingSaleBook.State financial;
        StreamClearingClock.History clock;
        mapping(bytes32 => IStreamNativeClearingSale.ClearingSaleRecord) sales;
        mapping(bytes32 => IStreamNativeClearingSale.ClearingPurchaseRecord) purchases;
        mapping(bytes32 => StreamNativeSupplementalTypes.NativeSupplementalResult)
            supplementalResults;
        bytes32 activeCandidate;
        mapping(address => mapping(bytes32 => bool)) authorizationUsed;
        mapping(bytes32 => mapping(uint256 => bytes32)) executionIdByNonce;
        mapping(bytes32 => uint8) executionStatus;
    }

    struct Context {
        StreamDutchSaleSupport.Context support;
        IStreamSplitFactory factory;
        address registry;
        address recorder;
        bytes32 coreHash;
        bytes32 registryHash;
        bytes32 resolverHash;
        bytes32 factoryHash;
        bytes32 managerHash;
        bytes32 recorderHash;
        uint256 revealCap;
    }

    function deadlines(State storage state, bytes32 id)
        public
        view
        returns (
            uint64 referenceTime,
            uint64 nominalFinalizeBy,
            uint64 effectiveFinalizeBy,
            uint64 pauseToll
        )
    {
        IStreamNativeClearingSale.ClearingSaleRecord storage sale = state.sales[id];
        if (sale.saleNonce == 0) revert IStreamNativeClearingSale.ClearingSaleUnavailable(id);
        referenceTime = sale.soldOutAt != 0
            ? sale.soldOutAt
            : (sale.earlyCloseAt != 0 ? sale.earlyCloseAt : sale.config.closesAt);
        nominalFinalizeBy = referenceTime + sale.config.finalizationWindowSeconds;
        if (sale.terminalAt != 0) {
            pauseToll = sale.terminalToll;
        } else if (referenceTime <= block.timestamp) {
            pauseToll = StreamClearingClock.tollSince(state.clock, id, referenceTime);
        }
        uint256 extended = uint256(nominalFinalizeBy) + pauseToll;
        effectiveFinalizeBy = extended < sale.config.absoluteEscapeDeadline
            ? uint64(extended)
            : sale.config.absoluteEscapeDeadline;
    }

    function purchaseFacts(State storage state, bytes32 purchaseId)
        public
        view
        returns (StreamNativeSupplementalTypes.ClearingPurchaseFacts memory facts)
    {
        IStreamNativeClearingSale.ClearingPurchaseRecord storage p = state.purchases[purchaseId];
        if (p.tokenId == 0) {
            revert IStreamNativeClearingSale.ClearingPurchaseUnavailable(purchaseId);
        }
        bytes32 id = p.originalFloor.sale.settlementId;
        StreamClearingSaleBook.Sale storage sale = state.financial.sales[id];
        StreamClearingSaleBook.Purchase storage basis = state.financial.purchases[purchaseId];
        (,, uint64 deadline,) = deadlines(state, id);
        uint256 uniform = sale.clearingPrice < basis.normalizedCeiling
            ? sale.clearingPrice
            : basis.normalizedCeiling;
        uint8 status =
            sale.status == 2 && !basis.supplementalSettled && uniform > sale.floorPrice ? 1 : 0;
        facts = StreamNativeSupplementalTypes.ClearingPurchaseFacts(
            p.floorSettlementKey,
            p.floorCandidateCommitment,
            p.originalFloor.executionBinding.saleAuthorizationDigest,
            p.purchaseNonce,
            p.tokenId,
            p.originalFloor.operationId,
            basis.paidPrice,
            sale.floorPrice,
            sale.clearingPrice,
            p.hasPriceOverride,
            p.priceOverride,
            uniform,
            deadline,
            status
        );
    }

    function freezeTerminalClock(State storage state, bytes32 id) public {
        (,,, uint64 toll) = deadlines(state, id);
        state.sales[id].terminalToll = toll;
        state.sales[id].terminalAt = StreamClearingClock.now64();
    }

    function isPaused(State storage state, bytes32 id) public view returns (bool) {
        return StreamClearingClock.globalPaused(state.clock)
            || StreamClearingClock.localPaused(state.clock, id);
    }
}
