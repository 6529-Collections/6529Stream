// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../revenue/StreamNativeSettlementTypes.sol";

/// @notice Explicit signed native price kinds, one token per execution, with no reveal-fee line item.
interface IStreamNativePricePrograms {
    struct PriceProgramConfig {
        uint256 collectionId;
        bytes32 phaseId;
        uint8 kind;
        uint256 minUnitPrice;
        uint256 maxUnitPrice;
        uint64 maxSaleQuantity;
        uint64 startsAt;
        uint64 endsAt;
        uint8 closeRule; // 1: end time, 2: terminal manual close
        bytes32 mintPolicyHash;
        bytes32 primaryAssignmentHash;
    }

    struct PriceProgramRecord {
        PriceProgramConfig config;
        uint256 saleNonce;
        bytes32 configHash;
        StreamNativeSettlementTypes.SaleLifecycleBinding lifecycle;
        uint64 mintedQuantity;
        bool closed;
    }

    struct PriceProgramAuthorization {
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
        uint256 unitPrice;
    }

    struct PriceProgramExecution {
        PriceProgramAuthorization authorization;
        uint256 chosenUnitPrice;
        bytes tokenData;
        bytes platformSignature;
        bytes artistSignature;
    }

    struct PriceProgramResult {
        uint8 revenueOutcome; // 1: FREE (no official settlement), 2: PAID
        bytes32 executionId;
        bytes32 operationRoot;
        bytes32 operationId;
        uint256 tokenId; // zero in a preview
        uint256 chargedAmount;
        bytes32 settlementKey; // zero for FREE and previews
        bool escrowed; // false for FREE and previews
    }
    error InvalidNativePriceProgram();
    error NativePriceProgramUnavailable(bytes32 saleId);
    error NativePriceOutsideBand(uint256 chosen, uint256 minimum, uint256 maximum);
    event NativePriceProgramConfigured(
        bytes32 indexed saleId,
        uint16 schemaVersion,
        uint256 saleNonce,
        bytes32 configHash,
        PriceProgramConfig config,
        uint64 createdAt,
        uint64 registryRevision
    );
    event NativePriceProgramClosed(
        bytes32 indexed saleId, uint16 schemaVersion, uint64 mintedQuantity
    );
    event NativePriceProgramFreeMint(
        bytes32 indexed saleId,
        bytes32 indexed executionId,
        bytes32 indexed operationRoot,
        uint16 schemaVersion,
        bytes32 operationId,
        uint256 tokenId,
        address payer,
        address recipient,
        uint64 mintedQuantity
    );
    event NativePriceProgramPaidMint(
        bytes32 indexed saleId,
        bytes32 indexed executionId,
        bytes32 indexed operationRoot,
        uint16 schemaVersion,
        bytes32 operationId,
        uint256 tokenId,
        address payer,
        address recipient,
        uint256 chargedAmount,
        bytes32 settlementKey,
        bool escrowed,
        uint64 mintedQuantity
    );
    function registerPriceProgram(PriceProgramConfig calldata config) external returns (bytes32);
    function priceProgramRecord(bytes32 saleId) external view returns (PriceProgramRecord memory);
    function priceProgramIdFor(uint256 collectionId, bytes32 phaseId, uint8 kind, uint256 saleNonce)
        external
        view
        returns (bytes32);
    function priceProgramAuthorizationDigest(PriceProgramAuthorization calldata authorization)
        external
        view
        returns (bytes32);
    function previewPriceProgram(PriceProgramExecution calldata execution)
        external
        view
        returns (PriceProgramResult memory);
    function executePriceProgram(PriceProgramExecution calldata execution)
        external
        payable
        returns (PriceProgramResult memory);
    function closePriceProgram(bytes32 saleId) external;
}
