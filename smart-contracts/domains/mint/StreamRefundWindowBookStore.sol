// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamNativeRefundWindowSale
} from "../../interfaces/stream/mint/IStreamNativeRefundWindowSale.sol";
import "./StreamRefundClock.sol";
import "../../interfaces/stream/revenue/StreamNativeSettlementTypes.sol";

/// @notice Linked buyer-liability book; executes in the calling consumer's storage and balance context.
/// @dev The consumer owns authentication and reentrancy exclusion around every mutation.
library StreamRefundWindowBookStore {
    struct State {
        StreamRefundClock.GlobalClock _globalPause;
        mapping(bytes32 => StreamRefundClock.SaleClock) _salePause;
        mapping(bytes32 => IStreamNativeRefundWindowSale.RefundSaleRecord) _refundSales;
        mapping(bytes32 => IStreamNativeRefundWindowSale.RefundPurchaseRecord) _purchases;
        mapping(bytes32 => IStreamNativeRefundWindowSale.RefundFinalizationResult)
            _finalizationResults;
        mapping(address => uint256) refundCredit;
        mapping(address => mapping(bytes32 => bool)) purchaseAuthorizationUsed;
        uint256 totalBuyerLiabilities;
        uint256 totalPendingDeposits;
        mapping(bytes32 => mapping(address => uint256)) saleRefundCredit;
        mapping(bytes32 => mapping(address => uint256)) lastPurchaseNonce;
    }

    event RefundWindowPurchase(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        bytes32 indexed purchaseId,
        address indexed payer,
        uint256 quantity,
        uint256 amount,
        uint64 refundDeadline
    );
    event RefundWindowRefunded(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        bytes32 indexed purchaseId,
        address indexed payer,
        uint256 amount
    );
    event RefundWindowFinalized(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        bytes32 indexed purchaseId,
        uint256 firstTokenId,
        uint256 quantity
    );
    event RefundWindowRefundUnlocked(
        uint16 schemaVersion, bytes32 indexed saleId, bytes32 indexed purchaseId, bytes32 reasonHash
    );
    event RefundSaleConfigured(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 saleNonce,
        bytes32 configHash,
        bytes32 windowPolicyHash,
        IStreamNativeRefundWindowSale.RefundSaleConfig config,
        uint64 createdAt,
        uint64 registryRevision
    );
    event SaleConfigured(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        uint8 saleKind,
        address asset,
        bytes32 saleConfigHash,
        bytes32 expectedPrimaryPolicyHash,
        uint8 primaryPolicyMode
    );
    event RefundPurchaseEnvelopeBound(
        uint16 schemaVersion,
        bytes32 indexed purchaseId,
        bytes32 purchaseRecordHash,
        bytes32 authorizationDigest,
        uint256 savedRevealFee,
        uint64 nominalRefundDeadline,
        uint64 nominalFinalizeBy,
        uint64 maximumNominalFinalizeBy,
        uint64 absoluteEscapeDeadline,
        uint64 pauseBaseline
    );
    event RefundPurchaseWindowObserved(
        uint16 schemaVersion,
        bytes32 indexed purchaseId,
        uint64 pauseToll,
        uint64 refundDeadline,
        uint64 finalizeBy
    );
    event RefundCreditClaimed(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed payer,
        address indexed recipient,
        uint256 amount
    );
    event SalePaymentExcessCredited(
        uint16 schemaVersion, bytes32 indexed saleId, address indexed payer, uint256 amount
    );

    event RefundAdapterPauseUpdated(
        uint16 schemaVersion,
        bool paused,
        address indexed actor,
        bytes32 reasonHash,
        uint64 globalPauseTotal
    );
    event RefundSalePauseUpdated(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        bool paused,
        address indexed actor,
        bytes32 reasonHash,
        uint64 unionPauseTotal
    );

    function setGlobalPause(State storage state, bool paused, bytes32 reason) public {
        StreamRefundClock.setGlobal(state._globalPause, paused);
        emit RefundAdapterPauseUpdated(
            1, paused, msg.sender, reason, StreamRefundClock.globalTotal(state._globalPause)
        );
    }

    function setSalePause(State storage state, bytes32 id, bool paused, bytes32 reason) public {
        StreamRefundClock.setSale(state._globalPause, state._salePause[id], paused);
        emit RefundSalePauseUpdated(
            1,
            id,
            paused,
            msg.sender,
            reason,
            StreamRefundClock.unionTotal(state._globalPause, state._salePause[id])
        );
    }

    function configure(
        State storage state,
        IStreamNativeRefundWindowSale.RefundSaleConfig memory c,
        StreamNativeSettlementTypes.SaleLifecycleBinding memory lifecycle,
        uint256 nonce,
        bytes32 window,
        bytes32 baselinePolicyHash
    ) public returns (bytes32 id) {
        id = keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_V1"),
                block.chainid,
                address(this),
                uint8(7),
                c.collectionId,
                c.phaseId,
                nonce
            )
        );
        bytes32 hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_REFUND_SALE_CONFIG_V1"), id, c, baselinePolicyHash
            )
        );
        state._refundSales[id] = IStreamNativeRefundWindowSale.RefundSaleRecord(
            c, nonce, hash, window, lifecycle, 0, baselinePolicyHash
        );
        emit SaleConfigured(
            1,
            id,
            c.collectionId,
            c.phaseId,
            7,
            address(0),
            hash,
            baselinePolicyHash,
            c.primaryPolicyMode
        );
        emit RefundSaleConfigured(
            1,
            id,
            nonce,
            hash,
            window,
            c,
            lifecycle.saleCreatedAt,
            lifecycle.saleAdapterRegistryRevision
        );
    }

    function purchaseDeadlines(State storage state, bytes32 id)
        public
        view
        returns (uint64 refundDeadline, uint64 finalizeBy, uint64 pauseToll)
    {
        IStreamNativeRefundWindowSale.RefundPurchaseRecord storage p = _requirePurchase(state, id);
        pauseToll = p.status == 1
            ? StreamRefundClock.unionTotal(
                    state._globalPause, state._salePause[p.authorization.saleId]
                ) - p.pauseBaseline
            : p.terminalToll;
        refundDeadline = StreamRefundClock.cappedDeadline(
            p.nominalRefundDeadline, pauseToll, p.authorization.absoluteEscapeDeadline
        );
        finalizeBy = StreamRefundClock.cappedDeadline(
            p.nominalFinalizeBy, pauseToll, p.authorization.absoluteEscapeDeadline
        );
    }

    function synchronizePurchaseWindow(State storage state, bytes32 id) public {
        _emitWindow(state, id);
    }

    function refundPurchase(State storage state, bytes32 id) public {
        IStreamNativeRefundWindowSale.RefundPurchaseRecord storage p = _requirePurchase(state, id);
        if (msg.sender != p.authorization.payer) {
            revert IStreamNativeRefundWindowSale.RefundCallerNotPayer(
                msg.sender, p.authorization.payer
            );
        }
        if (p.status == 3) return;
        if (p.status != 1) revert IStreamNativeRefundWindowSale.RefundWindowPurchaseTerminal(id);
        (uint64 refundDeadline,,) = purchaseDeadlines(state, id);
        if (block.timestamp >= refundDeadline) {
            revert IStreamNativeRefundWindowSale.RefundWindowClosed(id, refundDeadline);
        }
        _closeToRefund(state, id, p, 3);
        emit RefundWindowRefunded(
            1,
            p.authorization.saleId,
            id,
            p.authorization.payer,
            p.authorization.price + p.savedRevealFee
        );
    }

    function claimRefund(State storage state, bytes32 saleId, address payable recipient)
        public
        returns (uint256 amount)
    {
        if (recipient == address(0) || recipient == address(this)) {
            revert IStreamNativeRefundWindowSale.RefundTransferFailed(recipient);
        }
        _requireSolvent(state);
        amount = state.saleRefundCredit[saleId][msg.sender];
        if (amount == 0) revert IStreamNativeRefundWindowSale.RefundCreditEmpty(msg.sender);
        state.saleRefundCredit[saleId][msg.sender] = 0;
        state.refundCredit[msg.sender] -= amount;
        state.totalBuyerLiabilities -= amount;
        uint256 beforeBalance = address(this).balance;
        bool ok;
        // A payer-chosen pull recipient gets available gas. No returndata is allocated.
        assembly ("memory-safe") { ok := call(gas(), recipient, amount, 0, 0, 0, 0) }
        if (!ok) revert IStreamNativeRefundWindowSale.RefundTransferFailed(recipient);
        if (address(this).balance != beforeBalance - amount) {
            revert IStreamNativeRefundWindowSale.RefundAccountingMismatch();
        }
        _requireSolvent(state);
        emit RefundCreditClaimed(1, saleId, msg.sender, recipient, amount);
    }

    function _capturePurchase(
        State storage state,
        IStreamNativeRefundWindowSale.RefundPurchaseData calldata data,
        bytes32 digest,
        IStreamNativeRefundWindowSale.PurchaseCapture memory facts
    ) public returns (bytes32 id) {
        IStreamNativeRefundWindowSale.RefundPurchaseAuthorization calldata a = data.authorization;
        id = keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_PURCHASE_V1"),
                block.chainid,
                address(this),
                a.saleId,
                a.payer,
                a.purchaseNonce
            )
        );
        if (state._purchases[id].status != 0 || state.purchaseAuthorizationUsed[a.artist][a.nonce])
        {
            revert IStreamNativeRefundWindowSale.RefundPurchaseAlreadyUsed(id);
        }
        {
            uint256 expectedNonce = state.lastPurchaseNonce[a.saleId][a.payer] + 1;
            if (a.purchaseNonce != expectedNonce) {
                revert IStreamNativeRefundWindowSale.RefundPurchaseNonceMismatch(
                    a.saleId, a.payer, expectedNonce, a.purchaseNonce
                );
            }
        }
        if (facts.artistId == 0 || facts.bindingGeneration == 0 || facts.bindingHash == 0) {
            revert IStreamNativeRefundWindowSale.InvalidRefundSale();
        }
        _requireSolvent(state);
        IStreamNativeRefundWindowSale.RefundSaleRecord storage sale = state._refundSales[a.saleId];
        if (sale.saleNonce == 0 || a.price != sale.config.price || msg.value < a.price) {
            revert IStreamNativeRefundWindowSale.InvalidRefundSale();
        }
        uint64 purchasedAt = StreamRefundClock.now64();
        uint64 refundDeadline = purchasedAt + sale.config.refundWindowSeconds;
        uint64 finalizeBy = refundDeadline + sale.config.finalizationWindowSeconds;
        if (finalizeBy > a.maximumNominalFinalizeBy || finalizeBy > a.absoluteEscapeDeadline) {
            revert IStreamNativeRefundWindowSale.InvalidRefundSale();
        }
        uint256 deposit = a.price + facts.savedRevealFee;
        if (msg.value < deposit) {
            revert IStreamNativeRefundWindowSale.SaleRevealFeeBelowRequired(
                msg.value - a.price, facts.savedRevealFee
            );
        }
        uint64 baseline =
            StreamRefundClock.unionTotal(state._globalPause, state._salePause[a.saleId]);
        IStreamNativeRefundWindowSale.RefundPurchaseRecord storage p = state._purchases[id];
        p.authorization = a;
        p.authorizationDigest = digest;
        p.artistId = facts.artistId;
        p.bindingGeneration = facts.bindingGeneration;
        p.bindingHash = facts.bindingHash;
        p.referencedGate = facts.referencedGate;
        p.tokenData = data.tokenData;
        p.savedRevealFee = facts.savedRevealFee;
        p.purchasedAt = purchasedAt;
        p.pauseBaseline = baseline;
        p.nominalRefundDeadline = refundDeadline;
        p.nominalFinalizeBy = finalizeBy;
        p.status = 1;
        p.purchaseRecordHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_REFUND_PURCHASE_RECORD_V1"),
                block.chainid,
                address(this),
                id,
                a,
                digest,
                facts,
                purchasedAt,
                baseline,
                refundDeadline,
                finalizeBy
            )
        );
        state.purchaseAuthorizationUsed[a.artist][a.nonce] = true;
        state.lastPurchaseNonce[a.saleId][a.payer] = a.purchaseNonce;
        ++sale.purchasedQuantity;
        state.totalPendingDeposits += deposit;
        state.totalBuyerLiabilities += msg.value;
        uint256 excess = msg.value - deposit;
        state.refundCredit[a.payer] += excess;
        state.saleRefundCredit[a.saleId][a.payer] += excess;
        if (excess != 0) emit SalePaymentExcessCredited(1, a.saleId, a.payer, excess);
        _requireSolvent(state);
        _emitPurchase(state, id, p);
    }

    function _emitPurchase(
        State storage,
        bytes32 id,
        IStreamNativeRefundWindowSale.RefundPurchaseRecord storage p
    ) private {
        IStreamNativeRefundWindowSale.RefundPurchaseAuthorization storage a = p.authorization;
        emit RefundWindowPurchase(1, a.saleId, id, a.payer, 1, a.price, p.nominalRefundDeadline);
        emit RefundPurchaseEnvelopeBound(
            1,
            id,
            p.purchaseRecordHash,
            p.authorizationDigest,
            p.savedRevealFee,
            p.nominalRefundDeadline,
            p.nominalFinalizeBy,
            a.maximumNominalFinalizeBy,
            a.absoluteEscapeDeadline,
            p.pauseBaseline
        );
    }

    function _closeToRefund(
        State storage state,
        bytes32 id,
        IStreamNativeRefundWindowSale.RefundPurchaseRecord storage p,
        uint8 status
    ) public {
        if (p.status != 1 || (status != 3 && status != 4)) {
            revert IStreamNativeRefundWindowSale.RefundWindowPurchaseTerminal(id);
        }
        _requireSolvent(state);
        (,, uint64 toll) = purchaseDeadlines(state, id);
        p.terminalToll = toll;
        p.status = status;
        uint256 amount = p.authorization.price + p.savedRevealFee;
        state.totalPendingDeposits -= amount;
        state.refundCredit[p.authorization.payer] += amount;
        state.saleRefundCredit[p.authorization.saleId][p.authorization.payer] += amount;
        // Converting pending principal/fee to credit does not change total liabilities.
        _emitWindow(state, id);
    }

    function _beginFinalization(
        State storage state,
        bytes32 id,
        IStreamNativeRefundWindowSale.RefundPurchaseRecord storage p
    ) public {
        if (p.status != 1) {
            revert IStreamNativeRefundWindowSale.RefundWindowPurchaseTerminal(id);
        }
        _requireSolvent(state);
        (,, uint64 toll) = purchaseDeadlines(state, id);
        p.terminalToll = toll;
        p.status = 2;
        uint256 amount = p.authorization.price + p.savedRevealFee;
        state.totalPendingDeposits -= amount;
        state.totalBuyerLiabilities -= amount;
        // The concrete finalizer must spend price/fee and re-credit the unused saved fee.
        _emitWindow(state, id);
    }

    function _creditFeeRemainder(
        State storage state,
        IStreamNativeRefundWindowSale.RefundPurchaseRecord storage p,
        uint256 amount
    ) public {
        if (p.status != 2 || amount > p.savedRevealFee) {
            revert IStreamNativeRefundWindowSale.RefundAccountingMismatch();
        }
        if (amount != 0) {
            state.totalBuyerLiabilities += amount;
            state.refundCredit[p.authorization.payer] += amount;
            state.saleRefundCredit[p.authorization.saleId][p.authorization.payer] += amount;
            emit SalePaymentExcessCredited(1, p.authorization.saleId, p.authorization.payer, amount);
        }
    }

    function _timeUnlockable(
        State storage state,
        bytes32 id,
        IStreamNativeRefundWindowSale.RefundPurchaseRecord storage p
    ) public view returns (bool) {
        (, uint64 finalizationDeadline,) = purchaseDeadlines(state, id);
        return block.timestamp > finalizationDeadline
            || (block.timestamp == p.authorization.absoluteEscapeDeadline
                && _isPaused(state, p.authorization.saleId));
    }

    function _requirePurchase(State storage state, bytes32 id)
        private
        view
        returns (IStreamNativeRefundWindowSale.RefundPurchaseRecord storage p)
    {
        p = state._purchases[id];
        if (p.status == 0) revert IStreamNativeRefundWindowSale.RefundPurchaseUnavailable(id);
    }

    function _isPaused(State storage state, bytes32 saleId) private view returns (bool) {
        return state._globalPause.paused || state._salePause[saleId].paused;
    }

    function _requireSolvent(State storage state) private view {
        if (address(this).balance < state.totalBuyerLiabilities) {
            revert IStreamNativeRefundWindowSale.RefundAccountingMismatch();
        }
    }

    function _emitWindow(State storage state, bytes32 id) private {
        (uint64 refundDeadline, uint64 finalizeBy, uint64 toll) = purchaseDeadlines(state, id);
        emit RefundPurchaseWindowObserved(1, id, toll, refundDeadline, finalizeBy);
    }
}
