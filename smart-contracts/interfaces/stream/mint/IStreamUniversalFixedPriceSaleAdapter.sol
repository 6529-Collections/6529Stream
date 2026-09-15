// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../revenue/StreamPrimarySettlementTypes.sol";

/// @notice First universal consumer: signed fixed-PROFILE, one-token immediate mint.
interface IStreamUniversalFixedPriceSaleAdapter {
    struct SaleConfig {
        address paymentAdapter;
        uint256 collectionId;
        bytes32 phaseId;
        address asset;
        uint256 price;
        uint64 startsAt;
        uint64 endsAt;
        bytes32 mintPolicyHash;
        bytes32 expectedPrimaryPolicyHash;
    }

    struct SaleAuthorization {
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
    }

    struct SaleExecutionData {
        SaleAuthorization authorization;
        bytes tokenData;
        bytes platformSignature;
        bytes artistSignature;
    }

    struct SaleRecord {
        SaleConfig config;
        uint256 saleNonce;
        bytes32 configHash;
        StreamPrimarySettlementTypes.SaleLifecycleBinding lifecycle;
        bool cancelled;
    }
    error InvalidUniversalSale();
    error UniversalSaleUnavailable(bytes32 saleId);
    error UniversalAuthorizationUsed(address artist, bytes32 nonce);
    error UniversalExecutionUsed(bytes32 saleId, uint256 executionNonce);
    error UniversalSaleSignatureInvalid(address signer);
    error UniversalCandidateMismatch();
    error UniversalSettlementFailed();
    error UniversalMintResultInvalid();

    event UniversalSaleConfigured(
        bytes32 indexed saleId,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        uint16 schemaVersion,
        uint256 saleNonce,
        bytes32 configHash,
        address paymentAdapter
    );
    event UniversalSaleCancelled(bytes32 indexed saleId, uint16 schemaVersion);
    event UniversalSalesPaused(uint16 schemaVersion, bool paused);
    event UniversalAuthorizationCancelled(
        address indexed artist, bytes32 indexed nonce, uint16 schemaVersion
    );
    event UniversalSaleExecution(
        bytes32 indexed saleId,
        bytes32 indexed executionId,
        bytes32 indexed operationRoot,
        uint16 schemaVersion,
        uint8 status,
        bytes32 settlementKey,
        uint256 tokenId
    );

    function registerSale(SaleConfig calldata config) external returns (bytes32 saleId);
    function saleRecord(bytes32 saleId) external view returns (SaleRecord memory);
    function saleIdFor(uint256 collectionId, bytes32 phaseId, uint256 saleNonce)
        external
        view
        returns (bytes32);
    function authorizationDigest(SaleAuthorization calldata authorization)
        external
        view
        returns (bytes32);
    function previewExecution(SaleExecutionData calldata execution)
        external
        view
        returns (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory);
    function cancelSale(bytes32 saleId) external;
    function cancelAuthorization(bytes32 nonce) external;
    function setPaused(bool paused) external;
}
