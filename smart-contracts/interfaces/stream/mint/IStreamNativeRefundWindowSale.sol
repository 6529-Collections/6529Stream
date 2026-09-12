// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../revenue/StreamNativeSettlementTypes.sol";

/// @notice Signed one-token native refund purchases, separate from immediate mint schemas.
interface IStreamNativeRefundWindowSale {
    struct PurchaseCapture {
        uint256 savedRevealFee;
        bytes32 artistId;
        uint64 bindingGeneration;
        bytes32 bindingHash;
        address referencedGate;
    }

    struct RefundSaleConfig {
        uint256 collectionId;
        bytes32 phaseId;
        uint256 price;
        uint64 maxSaleQuantity;
        uint64 startsAt;
        uint64 endsAt;
        uint64 refundWindowSeconds;
        uint64 finalizationWindowSeconds;
        uint8 primaryPolicyMode;
        bytes32 mintPolicyHash;
    }

    struct RefundSaleRecord {
        RefundSaleConfig config;
        uint256 saleNonce;
        bytes32 configHash;
        bytes32 windowPolicyHash;
        StreamNativeSettlementTypes.SaleLifecycleBinding lifecycle;
        uint64 purchasedQuantity;
        bytes32 expectedPrimaryPolicyHash;
    }

    struct RefundPurchaseAuthorization {
        bytes32 saleId;
        bytes32 saleConfigHash;
        address payer;
        address recipient;
        address artist;
        bytes32 tokenDataHash;
        bytes32 mintCommitment;
        uint256 purchaseNonce;
        bytes32 nonce;
        uint256 price;
        uint64 deadline;
        bytes32 windowPolicyHash;
        uint64 maximumNominalFinalizeBy;
        uint64 absoluteEscapeDeadline;
        bytes32 expectedPrimaryPolicyHash;
    }

    struct RefundPurchaseData {
        RefundPurchaseAuthorization authorization;
        bytes tokenData;
        bytes platformSignature;
        bytes artistSignature;
    }

    struct RefundPurchaseRecord {
        RefundPurchaseAuthorization authorization;
        bytes32 authorizationDigest;
        bytes32 purchaseRecordHash;
        bytes32 artistId;
        uint64 bindingGeneration;
        bytes32 bindingHash;
        address referencedGate;
        bytes tokenData;
        uint256 savedRevealFee;
        uint64 purchasedAt;
        uint64 pauseBaseline;
        uint64 nominalRefundDeadline;
        uint64 nominalFinalizeBy;
        uint64 terminalToll;
        uint8 status; //0 absent,1 pending,2 finalized,3 refunded,4 unlocked
    }

    struct RefundFinalizationResult {
        bytes32 executionId;
        bytes32 operationRoot;
        bytes32 operationId;
        uint256 tokenId;
        bytes32 settlementKey;
        uint256 amount;
        uint256 revealFeeForwarded;
        uint256 revealFeeRefunded;
        bool escrowed;
    }

    error InvalidRefundSale();
    error RefundSaleUnavailable(bytes32 saleId);
    error RefundPurchaseUnavailable(bytes32 purchaseId);
    error RefundPurchaseAlreadyUsed(bytes32 purchaseId);
    error RefundPurchaseNonceMismatch(
        bytes32 saleId, address payer, uint256 expected, uint256 supplied
    );
    error RefundPurchaseSignatureInvalid(address signer);
    error RefundWindowClosed(bytes32 purchaseId, uint64 refundDeadline);
    error RefundWindowStillOpen(bytes32 purchaseId, uint64 refundDeadline);
    error RefundWindowPurchaseTerminal(bytes32 purchaseId);
    error SaleFinalizeByExpired(uint64 finalizeBy);
    error SaleEnvelopeModeInvalid();
    error SaleEntryPaused();
    error SaleRevealFeeBelowRequired(uint256 suppliedAllowance, uint256 requiredFee);
    error RefundUnlockNotAvailable(bytes32 purchaseId, uint8 reason);
    error RefundCallerNotPayer(address caller, address payer);
    error RefundCreditEmpty(address payer);
    error RefundTransferFailed(address recipient);
    error RefundAccountingMismatch();
    error RefundRoleNotAuthorized(bytes32 role, address actor);
    error RefundDependencyInvalid(address dependency);
    error RefundDependencyReadMalformed(address dependency, uint256 size);

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
        RefundSaleConfig config,
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

    function registerRefundSale(RefundSaleConfig calldata config) external returns (bytes32);
    function refundSaleRecord(bytes32 saleId) external view returns (RefundSaleRecord memory);
    function refundPurchaseRecord(bytes32 purchaseId)
        external
        view
        returns (RefundPurchaseRecord memory);
    function refundPurchaseAuthorizationDigest(RefundPurchaseAuthorization calldata authorization)
        external
        view
        returns (bytes32);
    /// @notice ERC5267 discovery for the sole refund-purchase authorization domain.
    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );
    function purchaseRefundWindow(RefundPurchaseData calldata data)
        external
        payable
        returns (bytes32);
    /// @notice Returns the stored result for an already finalized purchase. Other terminal
    ///         outcomes revert RefundWindowPurchaseTerminal; no zero-result success exists.
    function finalizeRefundWindow(bytes32 purchaseId)
        external
        returns (RefundFinalizationResult memory);
    /// @notice Converts a pending purchase to permanent payer pull credit in its refund window.
    ///         Repeating that same refunded outcome is a no-op for the payer.
    function refundPurchase(bytes32 purchaseId) external;
    /// @notice Credits a permanent refund after an independently authenticated terminal reason.
    ///         Repeating that same unlocked outcome is a no-op; other terminal outcomes reject.
    function unlockRefund(bytes32 purchaseId, uint8 reason) external;
    /// @notice Claims only the caller's credit for this sale, leaving every other sale intact.
    function claimRefund(bytes32 saleId, address payable recipient) external returns (uint256);
    function refundableBalance(bytes32 saleId, address payer) external view returns (uint256);
    function nextPurchaseNonce(bytes32 saleId, address payer) external view returns (uint256);
    /// @notice Aggregate summary of the payer's unclaimed credits across sales.
    function refundCredit(address payer) external view returns (uint256);
    function purchaseDeadlines(bytes32 purchaseId)
        external
        view
        returns (uint64 refundDeadline, uint64 finalizeBy, uint64 pauseToll);
    function synchronizePurchaseWindow(bytes32 purchaseId) external;
    function pauseAdapter(bytes32 reasonHash) external;
    function unpauseAdapter(bytes32 reasonHash) external;
    function pauseRefundSale(bytes32 saleId, bytes32 reasonHash) external;
    function unpauseRefundSale(bytes32 saleId, bytes32 reasonHash) external;
}
