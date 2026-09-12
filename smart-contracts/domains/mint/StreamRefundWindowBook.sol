// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/mint/IStreamNativeRefundWindowSale.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "./StreamRefundClock.sol";
import "./StreamRefundWindowBookStore.sol";

/// @notice Buyer liabilities and time-based exits, independent of current external authorities.
/// @dev The concrete adapter authenticates purchases, pauses, permanent reasons and minting.
abstract contract StreamRefundWindowBook is IStreamNativeRefundWindowSale, ReentrancyGuard {
    StreamRefundWindowBookStore.State internal _book;

    function refundSaleRecord(bytes32 id) external view override returns (RefundSaleRecord memory) {
        return _book._refundSales[id];
    }

    function refundPurchaseRecord(bytes32 id)
        external
        view
        override
        returns (RefundPurchaseRecord memory)
    {
        return _book._purchases[id];
    }

    function purchaseDeadlines(bytes32 id)
        public
        view
        override
        returns (uint64 refundDeadline, uint64 finalizeBy, uint64 pauseToll)
    {
        return StreamRefundWindowBookStore.purchaseDeadlines(_book, id);
    }

    function synchronizePurchaseWindow(bytes32 id) external override nonReentrant {
        StreamRefundWindowBookStore.synchronizePurchaseWindow(_book, id);
    }

    function refundPurchase(bytes32 id) external override nonReentrant {
        StreamRefundWindowBookStore.refundPurchase(_book, id);
    }

    function claimRefund(bytes32 saleId, address payable recipient)
        external
        override
        nonReentrant
        returns (uint256 amount)
    {
        return StreamRefundWindowBookStore.claimRefund(_book, saleId, recipient);
    }

    function _capturePurchase(
        RefundPurchaseData calldata data,
        bytes32 digest,
        PurchaseCapture memory facts
    ) internal returns (bytes32 id) {
        return StreamRefundWindowBookStore._capturePurchase(_book, data, digest, facts);
    }

    function _closeToRefund(bytes32 id, RefundPurchaseRecord storage p, uint8 status) internal {
        StreamRefundWindowBookStore._closeToRefund(_book, id, p, status);
    }

    function _beginFinalization(bytes32 id, RefundPurchaseRecord storage p) internal {
        StreamRefundWindowBookStore._beginFinalization(_book, id, p);
    }

    function _creditFeeRemainder(RefundPurchaseRecord storage p, uint256 amount) internal {
        StreamRefundWindowBookStore._creditFeeRemainder(_book, p, amount);
    }

    function _timeUnlockable(bytes32 id, RefundPurchaseRecord storage p)
        internal
        view
        returns (bool)
    {
        return StreamRefundWindowBookStore._timeUnlockable(_book, id, p);
    }

    function _requirePurchase(bytes32 id) internal view returns (RefundPurchaseRecord storage p) {
        p = _book._purchases[id];
        if (p.status == 0) revert RefundPurchaseUnavailable(id);
    }

    function _isPaused(bytes32 saleId) internal view returns (bool) {
        return _book._globalPause.paused || _book._salePause[saleId].paused;
    }

    function _requireSolvent() internal view {
        if (address(this).balance < _book.totalBuyerLiabilities) revert RefundAccountingMismatch();
    }

    function refundCredit(address account) external view override returns (uint256) {
        return _book.refundCredit[account];
    }

    function refundableBalance(bytes32 saleId, address account)
        external
        view
        override
        returns (uint256)
    {
        return _book.saleRefundCredit[saleId][account];
    }

    function nextPurchaseNonce(bytes32 saleId, address payer)
        external
        view
        override
        returns (uint256)
    {
        return _book.lastPurchaseNonce[saleId][payer] + 1;
    }

    function purchaseAuthorizationUsed(address signer, bytes32 nonce) external view returns (bool) {
        return _book.purchaseAuthorizationUsed[signer][nonce];
    }

    function totalBuyerLiabilities() external view returns (uint256) {
        return _book.totalBuyerLiabilities;
    }

    function totalPendingDeposits() external view returns (uint256) {
        return _book.totalPendingDeposits;
    }
}
