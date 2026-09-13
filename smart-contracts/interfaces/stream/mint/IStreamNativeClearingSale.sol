// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamDutchPriceSchedule.sol";
import "../revenue/StreamNativeSupplementalTypes.sol";

/// @notice Signed native Dutch floor mints and independently processed clearing financial legs.
interface IStreamNativeClearingSale is IStreamDutchPriceSchedule {
    struct ClearingSaleConfig {
        uint256 collectionId;
        bytes32 phaseId;
        DutchPriceSchedule schedule;
        uint64 maxSaleQuantity;
        uint64 closesAt;
        uint64 finalizationWindowSeconds;
        uint64 absoluteEscapeDeadline;
        uint8 primaryPolicyMode; // ALLOW_CURRENT1 for the later financial leg.
        bytes32 mintPolicyHash;
    }

    struct ClearingSaleRecord {
        ClearingSaleConfig config;
        uint256 saleNonce;
        bytes32 configHash;
        bytes32 priceScheduleHash;
        bytes32 windowPolicyHash;
        bytes32 expectedPrimaryPolicyHash; // Registration baseline, never substituted for a purchase proof.
        StreamNativeSettlementTypes.SaleLifecycleBinding lifecycle;
        uint64 soldOutAt;
        uint64 earlyCloseAt;
        uint64 priceFixedAt;
        uint64 terminalAt;
        uint64 terminalToll;
        bytes32 artistId;
        uint64 bindingGeneration;
        bytes32 bindingHash;
    }

    struct ClearingAuthorization {
        bytes32 saleId;
        bytes32 saleConfigHash;
        address payer;
        address executor;
        address recipient;
        address artist;
        bytes32 tokenDataHash;
        bytes32 mintCommitment;
        uint256 purchaseNonce;
        uint256 executionNonce;
        bytes32 nonce;
        uint64 deadline;
        bytes32 expectedPrimaryPolicyHash;
        uint256 unitPrice; // Signed maximum remains unchanged at both signature and Manager boundaries.
        bool hasPriceOverride;
        uint256 priceOverride; // Authenticated full-width ceiling; not narrowed to the aggregate key.
        bytes32 windowPolicyHash;
        uint64 maximumNominalFinalizeBy;
        uint64 absoluteEscapeDeadline;
    }

    struct ClearingPurchaseData {
        ClearingAuthorization authorization;
        bytes tokenData;
        bytes platformSignature;
        bytes artistSignature;
    }

    struct ClearingPurchaseRecord {
        StreamNativeSettlementTypes.NativeSettlementCandidate originalFloor;
        bytes32 floorSettlementKey;
        bytes32 floorCandidateCommitment;
        uint256 tokenId;
        uint256 purchaseNonce;
        uint64 purchasedAt;
        bool hasPriceOverride;
        uint256 priceOverride;
    }

    struct ClearingPurchaseResult {
        bytes32 purchaseId;
        uint256 tokenId;
        uint256 chargedAmount;
        uint256 floorRevenue;
        uint256 heldOverage;
        uint256 revealFeeForwarded;
        uint256 excessCredited;
        bytes32 executionId;
        bytes32 operationRoot;
        bytes32 operationId;
        bytes32 settlementKey;
        bool escrowed;
    }

    error InvalidClearingSale();
    error ClearingSaleUnavailable(bytes32 saleId);
    error ClearingPurchaseUnavailable(bytes32 purchaseId);
    error ClearingSignatureInvalid(address signer);
    error ClearingAuthorizationUsed(address signer, bytes32 nonce);
    error ClearingExecutionUsed(bytes32 saleId, uint256 executionNonce);
    error ClearingPriceAboveMaximum(uint256 maximum, uint256 price);
    error SaleRevealFeeBelowRequired(uint256 suppliedAllowance, uint256 requiredFee);
    error ClearingMintResultInvalid();
    error ClearingSettlementResultInvalid();
    error ClearingAccountingMismatch();
    error ClearingTransferFailed(address recipient);
    error ClearingCreditEmpty(bytes32 saleId, address payer);
    error ClearingUnlockUnavailable(bytes32 saleId, uint8 reason);
    error ClearingFinalizeExpired(uint64 finalizeBy);
    error ClearingEntryPaused();
    error ClearingDependencyInvalid(address dependency);
    error ClearingRecorderIncident(address recorder);
    error ClearingDependencyReadMalformed(address dependency, uint256 size);

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
    event ClearingSaleConfigured(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 saleNonce,
        bytes32 priceScheduleHash,
        bytes32 windowPolicyHash,
        ClearingSaleConfig config
    );
    event SaleConsentRecorded(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 indexed collectionId,
        bytes32 saleConfigHash,
        bytes32 consentEvidenceHash
    );
    event ClearingPurchaseCompleted(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        bytes32 indexed purchaseId,
        address indexed payer,
        ClearingPurchaseResult result,
        bool hasPriceOverride,
        uint256 priceOverride,
        uint256 purchaseNonce
    );
    event DutchClearingFinalized(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 clearingPrice,
        uint256 soldCount,
        uint256 supplementalRevenue
    );
    event DutchRebateCredited(
        uint16 schemaVersion, bytes32 indexed saleId, address indexed payer, uint256 amount
    );
    event DutchClearingRefundUnlocked(
        uint16 schemaVersion, bytes32 indexed saleId, bytes32 reasonHash
    );
    event SalePaymentExcessCredited(
        uint16 schemaVersion, bytes32 indexed saleId, address indexed payer, uint256 amount
    );
    event ClearingRefundClaimed(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed payer,
        address indexed recipient,
        uint256 amount
    );
    event ClearingFinancialLegCompleted(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        bytes32 indexed purchaseId,
        StreamNativeSupplementalTypes.NativeSupplementalResult result
    );
    event ClearingSaleClosed(uint16 schemaVersion, bytes32 indexed saleId, uint64 referenceTime);
    event ClearingDeadlineUpdated(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint64 referenceTime,
        uint64 nominalFinalizeBy,
        uint64 effectiveFinalizeBy,
        uint64 pauseToll
    );
    event AdapterPaused(uint16 schemaVersion, address indexed actor, bytes32 reasonHash);
    event AdapterUnpaused(uint16 schemaVersion, address indexed actor, bytes32 reasonHash);
    event SalePaused(
        uint16 schemaVersion, bytes32 indexed saleId, address indexed actor, bytes32 reasonHash
    );
    event SaleUnpaused(
        uint16 schemaVersion, bytes32 indexed saleId, address indexed actor, bytes32 reasonHash
    );
    event ClearingAuthorizationCancelled(
        uint16 schemaVersion, address indexed artist, bytes32 indexed nonce
    );

    function registerClearingSale(ClearingSaleConfig calldata config)
        external
        returns (bytes32 saleId);
    function saleIdFor(uint256 collectionId, bytes32 phaseId, uint256 nonce)
        external
        view
        returns (bytes32);
    function purchaseIdFor(bytes32 saleId, address buyer, uint256 nonce)
        external
        view
        returns (bytes32);
    function saleRecord(bytes32 saleId) external view returns (ClearingSaleRecord memory);
    function purchaseRecord(bytes32 purchaseId)
        external
        view
        returns (ClearingPurchaseRecord memory);
    function currentPrice(bytes32 saleId) external view returns (uint256);
    function authorizationDigest(ClearingAuthorization calldata authorization)
        external
        view
        returns (bytes32);
    function purchase(ClearingPurchaseData calldata data)
        external
        payable
        returns (ClearingPurchaseResult memory);
    function fixClearingPrice(bytes32 saleId) external;
    function settlePurchaseSupplement(bytes32 purchaseId)
        external
        returns (StreamNativeSupplementalTypes.NativeSupplementalResult memory);
    function synchronizeRebate(bytes32 saleId, address payer)
        external
        returns (uint256 newlyAnnounced);
    function synchronizeSaleDeadline(bytes32 saleId) external;
    function unlockRefunds(bytes32 saleId, uint8 reason) external;
    function refundableBalance(bytes32 saleId, address payer) external view returns (uint256);
    function claimRefund(bytes32 saleId, address recipient) external returns (uint256 amount);
    function nextPurchaseNonce(bytes32 saleId, address payer) external view returns (uint256);
    function saleDeadlines(bytes32 saleId)
        external
        view
        returns (
            uint64 referenceTime,
            uint64 nominalFinalizeBy,
            uint64 effectiveFinalizeBy,
            uint64 pauseToll
        );
    function closeSale(bytes32 saleId) external;
    function pauseAdapter(bytes32 reasonHash) external;
    function unpauseAdapter(bytes32 reasonHash) external;
    function pauseSale(bytes32 saleId, bytes32 reasonHash) external;
    function unpauseSale(bytes32 saleId, bytes32 reasonHash) external;
    function cancelAuthorization(bytes32 nonce) external;
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
}
