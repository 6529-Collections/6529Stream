// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamNativeCuratedCommitments as C
} from "../../interfaces/stream/mint/IStreamNativeCuratedCommitments.sol";

/// @notice Linked native deposit book executing in the sale host's storage, caller and balance context.
/// @dev The host must guard every mutation and transfer, validate sale/proof/admission facts, and keep
///      effective clocks locally. This book never queries Manager, policy, artist or reveal providers.
library StreamNativeCuratedCommitments {
    bytes32 private constant _COMMIT_DOMAIN = keccak256("6529STREAM_CONTENT_COMMIT_V1");

    struct State {
        mapping(bytes32 => mapping(address => mapping(bytes32 => C.CommitRecord))) _records;
        mapping(bytes32 => mapping(address => uint256)) _credits;
        uint256 pendingLiability;
        uint256 refundLiability;
    }

    event ContentSelectionCommitted(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed buyer,
        bytes32 selectionCommitment,
        uint256 amount
    );
    event ContentSelectionConsumed(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed buyer,
        bytes32 indexed selectionCommitment,
        uint256 amount
    );
    event ContentSelectionRefundCredited(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed buyer,
        bytes32 indexed selectionCommitment,
        uint256 amount
    );
    event ContentRefundDebited(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed buyer,
        address indexed recipient,
        uint256 amount
    );

    function validateWindows(C.Windows memory w) public pure {
        if (
            w.commitOpen >= w.commitClose || w.commitClose > w.revealOpen
                || w.revealOpen >= w.revealClose
        ) revert C.ContentWindowsInvalid();
    }

    function commitmentHash(bytes32 saleId, address buyer, bytes32 contentLeaf, bytes32 salt)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                _COMMIT_DOMAIN, block.chainid, address(this), saleId, buyer, contentLeaf, salt
            )
        );
    }

    /// @dev Only the positive purchase price is accepted; the reveal transaction funds its live fee.
    function commit(
        State storage s,
        bytes32 saleId,
        address buyer,
        bytes32 selectionCommitment,
        uint256 price,
        C.Admission memory admission
    ) public {
        _requireBuyer(buyer);
        _requireEntry(saleId, admission);
        if (
            block.timestamp < admission.windows.commitOpen
                || block.timestamp >= admission.windows.commitClose
        ) revert C.ContentCommitWindowInvalid(saleId);
        if (price == 0) revert C.ContentPriceInvalid(price);
        if (msg.value != price) revert C.ContentPaymentMismatch(price, msg.value);
        if (selectionCommitment == bytes32(0)) {
            revert C.ContentCommitmentInvalid(selectionCommitment);
        }
        C.CommitRecord storage r = s._records[saleId][buyer][selectionCommitment];
        if (r.status != C.Status.NONE) {
            revert C.ContentCommitmentAlreadyExists(selectionCommitment);
        }
        _requirePreCallSolvent(s);
        r.amount = price;
        r.committedBlock = block.number;
        r.status = C.Status.PENDING;
        s.pendingLiability += price;
        emit ContentSelectionCommitted(1, saleId, buyer, selectionCommitment, price);
    }

    /// @dev The host verifies the content proof and exact mint data before invoking this primitive.
    ///      The returned amount must settle atomically; any later failure restores this debit.
    function consumeForReveal(
        State storage s,
        bytes32 saleId,
        address buyer,
        bytes32 selectionCommitment,
        bytes32 contentLeaf,
        bytes32 salt,
        C.Admission memory admission
    ) public returns (uint256 amount) {
        _requireBuyer(buyer);
        _requireEntry(saleId, admission);
        if (
            block.timestamp < admission.windows.revealOpen
                || block.timestamp >= admission.windows.revealClose
        ) revert C.ContentRevealWindowInvalid(selectionCommitment);
        if (commitmentHash(saleId, buyer, contentLeaf, salt) != selectionCommitment) {
            revert C.ContentCommitmentInvalid(selectionCommitment);
        }
        C.CommitRecord storage r = _pending(s, saleId, buyer, selectionCommitment);
        if (block.number <= r.committedBlock) {
            revert C.ContentRevealSameBlock(r.committedBlock, block.number);
        }
        _requirePreCallSolvent(s);
        amount = r.amount;
        r.status = C.Status.CONSUMED;
        s.pendingLiability -= amount;
        emit ContentSelectionConsumed(1, saleId, buyer, selectionCommitment, amount);
    }

    /// @notice Permissionless conversion to the original buyer's permanent pull credit.
    /// @dev A stopped entry path never blocks this conversion. Repeated conversion is idempotent.
    function unlockRefund(
        State storage s,
        bytes32 saleId,
        address buyer,
        bytes32 selectionCommitment,
        C.Admission memory admission
    ) public returns (bool newlyCredited, uint256 amount) {
        // An absolute escape can cap commitClose, revealOpen and revealClose to the same second.
        // The trusted host's terminal admission keeps that recovery independent of entry windows.
        if (!admission.refundMatured) validateWindows(admission.windows);
        C.CommitRecord storage r = s._records[saleId][buyer][selectionCommitment];
        if (r.status == C.Status.REFUND_CREDITED) return (false, 0);
        r = _pending(s, saleId, buyer, selectionCommitment);
        if (!admission.refundMatured && block.timestamp < admission.windows.revealClose) {
            revert C.ContentRefundNotReady(selectionCommitment);
        }
        requireSolvent(s);
        amount = r.amount;
        r.status = C.Status.REFUND_CREDITED;
        s.pendingLiability -= amount;
        s.refundLiability += amount;
        s._credits[saleId][buyer] += amount;
        emit ContentSelectionRefundCredited(1, saleId, buyer, selectionCommitment, amount);
        return (true, amount);
    }

    /// @notice Debit all caller-owned credit before a guarded host transfer to the chosen recipient.
    /// @dev No transfer occurs here. The host must revert on transfer failure in the same transaction.
    function debitRefund(State storage s, bytes32 saleId, address buyer, address recipient)
        public
        returns (uint256 amount)
    {
        _requireBuyer(buyer);
        return _debitRefund(s, saleId, buyer, recipient);
    }

    /// @notice Debit a host-authenticated delegate claim payable only to the credited buyer.
    /// @dev The host MUST authenticate live pinned delegation and hold its shared reentrancy guard
    ///      before calling. This primitive performs no delegation/provider reads and grants no token
    ///      or payment-spending authority. The host must transfer to buyer atomically after the debit.
    function debitDelegatedRefund(State storage s, bytes32 saleId, address buyer)
        public
        returns (uint256 amount)
    {
        return _debitRefund(s, saleId, buyer, buyer);
    }

    function _debitRefund(State storage s, bytes32 saleId, address buyer, address recipient)
        private
        returns (uint256 amount)
    {
        if (recipient == address(0) || recipient == address(this)) {
            revert C.ContentRefundRecipientInvalid(recipient);
        }
        amount = s._credits[saleId][buyer];
        if (amount == 0) revert C.ContentRefundEmpty(saleId, buyer);
        requireSolvent(s);
        s._credits[saleId][buyer] = 0;
        s.refundLiability -= amount;
        emit ContentRefundDebited(1, saleId, buyer, recipient, amount);
    }

    function record(State storage s, bytes32 saleId, address buyer, bytes32 selectionCommitment)
        public
        view
        returns (C.CommitRecord memory)
    {
        return s._records[saleId][buyer][selectionCommitment];
    }

    function refundableBalance(State storage s, bytes32 saleId, address buyer)
        public
        view
        returns (uint256)
    {
        return s._credits[saleId][buyer];
    }

    function liabilities(State storage s)
        public
        view
        returns (uint256 pending, uint256 refund, uint256 total)
    {
        pending = s.pendingLiability;
        refund = s.refundLiability;
        total = pending + refund;
    }

    function requireSolvent(State storage s) public view {
        uint256 total = s.pendingLiability + s.refundLiability;
        if (address(this).balance < total) {
            revert C.ContentEscrowInsolvent(address(this).balance, total);
        }
    }

    function _requirePreCallSolvent(State storage s) private view {
        uint256 priorBalance = address(this).balance - msg.value;
        uint256 total = s.pendingLiability + s.refundLiability;
        if (priorBalance < total) revert C.ContentEscrowInsolvent(priorBalance, total);
    }

    function _requireBuyer(address buyer) private view {
        if (buyer != msg.sender) revert C.ContentBuyerInvalid(buyer, msg.sender);
    }

    function _requireEntry(bytes32 saleId, C.Admission memory admission) private pure {
        validateWindows(admission.windows);
        if (admission.stopped) revert C.SaleEntryPaused();
        if (admission.refundMatured) revert C.ContentRefundMatured(saleId);
    }

    function _pending(State storage s, bytes32 saleId, address buyer, bytes32 selectionCommitment)
        private
        view
        returns (C.CommitRecord storage r)
    {
        r = s._records[saleId][buyer][selectionCommitment];
        if (r.status == C.Status.NONE) revert C.ContentCommitmentInvalid(selectionCommitment);
        if (r.status != C.Status.PENDING) {
            revert C.ContentCommitmentTerminal(selectionCommitment, r.status);
        }
    }
}
