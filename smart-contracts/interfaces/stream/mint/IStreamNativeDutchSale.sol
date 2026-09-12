// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamDutchPriceSchedule.sol";
import "../revenue/StreamNativeSettlementTypes.sol";

/// @notice Signed standard native Dutch mints; clearing rebates use a separate profile.
interface IStreamNativeDutchSale is IStreamDutchPriceSchedule {
    struct DutchSaleConfig {
        uint256 collectionId;
        bytes32 phaseId;
        DutchPriceSchedule schedule;
        uint64 maxSaleQuantity;
        uint64 closesAt;
        bool declaredFree;
        bytes32 mintPolicyHash;
    }

    struct DutchSaleRecord {
        DutchSaleConfig config;
        uint256 saleNonce;
        bytes32 configHash;
        bytes32 priceScheduleHash;
        bytes32 expectedPrimaryPolicyHash;
        bytes32 primaryAssignmentHash;
        StreamNativeSettlementTypes.SaleLifecycleBinding lifecycle;
        uint64 mintedQuantity;
        bool closed;
        bool paused;
    }

    struct DutchAuthorization {
        bytes32 saleId;
        bytes32 saleConfigHash;
        address payer;
        address executor;
        address recipient;
        address artist;
        bytes32 tokenDataHash;
        bytes32 mintCommitment;
        uint256 executionNonce;
        bytes32 nonce;
        uint64 deadline;
        bytes32 expectedPrimaryPolicyHash;
        uint256 unitPrice; // Signed maximum; never replaced by the execution-time charge.
    }

    struct DutchPurchaseData {
        DutchAuthorization authorization;
        bytes tokenData;
        bytes platformSignature;
        bytes artistSignature;
    }

    struct DutchPurchaseResult {
        uint8 revenueOutcome; // FREE1 or PAID2; no zero-valued official settlement.
        uint256 tokenId;
        uint256 chargedAmount;
        uint256 revealFeeForwarded;
        uint256 excessCredited;
        bytes32 executionId;
        bytes32 operationRoot;
        bytes32 operationId;
        bytes32 settlementKey;
        bool escrowed;
    }

    error InvalidDutchSale();
    error DutchSaleUnavailable(bytes32 saleId);
    error DutchPaymentBelowPrice(uint256 maximum, uint256 price);
    error SaleRevealFeeBelowRequired(uint256 suppliedAllowance, uint256 requiredFee);
    error DutchSignatureInvalid(address signer);
    error DutchAuthorizationUsed(address artist, bytes32 nonce);
    error DutchExecutionUsed(bytes32 saleId, uint256 executionNonce);
    error DutchMintResultInvalid();
    error DutchAccountingMismatch();
    error DutchCreditEmpty(bytes32 saleId, address payer);
    error DutchTransferFailed(address recipient);
    error DutchRoleNotAuthorized(bytes32 role, address actor);
    error DutchDependencyInvalid(address dependency);
    error DutchDependencyReadMalformed(address dependency, uint256 size);

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
    event DutchSaleConfigured(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 saleNonce,
        bytes32 priceScheduleHash,
        bytes32 primaryAssignmentHash,
        DutchSaleConfig config
    );
    event SaleConsentRecorded(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 indexed collectionId,
        bytes32 saleConfigHash,
        bytes32 consentEvidenceHash
    );
    event SalePaymentExcessCredited(
        uint16 schemaVersion, bytes32 indexed saleId, address indexed payer, uint256 amount
    );
    event DutchRefundClaimed(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed payer,
        address indexed recipient,
        uint256 amount
    );
    event DutchPurchaseCompleted(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        bytes32 indexed executionId,
        address indexed payer,
        DutchPurchaseResult result
    );

    function registerDutchSale(DutchSaleConfig calldata config) external returns (bytes32 saleId);
    function saleIdFor(uint256 collectionId, bytes32 phaseId, uint256 nonce)
        external
        view
        returns (bytes32);
    function saleRecord(bytes32 saleId) external view returns (DutchSaleRecord memory);
    function currentPrice(bytes32 saleId) external view returns (uint256);
    function authorizationDigest(DutchAuthorization calldata authorization)
        external
        view
        returns (bytes32);
    function purchase(DutchPurchaseData calldata data)
        external
        payable
        returns (DutchPurchaseResult memory);
    function refundableBalance(bytes32 saleId, address payer) external view returns (uint256);
    function claimRefund(bytes32 saleId, address recipient) external;
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
