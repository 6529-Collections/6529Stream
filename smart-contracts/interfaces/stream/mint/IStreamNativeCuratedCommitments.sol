// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Native curated-selection deposit facts shared by a sale host and its linked book.
/// @dev The host owns immutable sale terms, effective clocks, entry admission and ETH transfers.
interface IStreamNativeCuratedCommitments {
    enum Status {
        NONE,
        PENDING,
        CONSUMED,
        REFUND_CREDITED
    }

    /// @dev Both intervals are half-open. The commit interval cannot overlap the reveal interval.
    struct Windows {
        uint64 commitOpen;
        uint64 commitClose;
        uint64 revealOpen;
        uint64 revealClose;
    }

    /// @dev Host-derived effective windows; never accept this structure as unverified user input.
    ///      refundMatured admits a host-validated terminal/escape refund before effective revealClose,
    ///      including an absolute escape that collapses the effective reveal interval.
    struct Admission {
        Windows windows;
        bool stopped;
        bool refundMatured;
    }

    struct CommitRecord {
        uint256 amount;
        uint256 committedBlock;
        Status status;
    }

    error ContentWindowsInvalid();
    error ContentPriceInvalid(uint256 price);
    error ContentPaymentMismatch(uint256 required, uint256 supplied);
    error ContentBuyerInvalid(address expected, address supplied);
    error ContentCommitmentInvalid(bytes32 selectionCommitment);
    error ContentCommitmentAlreadyExists(bytes32 selectionCommitment);
    error ContentCommitmentTerminal(bytes32 selectionCommitment, Status status);
    error ContentCommitWindowInvalid(bytes32 saleId);
    error ContentRevealWindowInvalid(bytes32 selectionCommitment);
    error ContentRevealSameBlock(uint256 committedBlock, uint256 currentBlock);
    error ContentRefundNotReady(bytes32 selectionCommitment);
    error ContentRefundMatured(bytes32 saleId);
    error ContentRefundEmpty(bytes32 saleId, address buyer);
    error ContentRefundRecipientInvalid(address recipient);
    error ContentEscrowInsolvent(uint256 balance, uint256 liabilities);
    error SaleEntryPaused();

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

    /// @dev The host must transfer this debit to recipient in the same guarded transaction.
    ///      An authenticated delegated debit fixes recipient to the original credited buyer.
    event ContentRefundDebited(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed buyer,
        address indexed recipient,
        uint256 amount
    );
}
