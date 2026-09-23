// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../revenue/StreamNativeSettlementTypes.sol";

/// @notice First universal consumer: signed native PROFILE/COLLECTION_ARTIST, one-token immediate mint.
interface IStreamNativeFixedPriceSaleAdapter {
    struct SaleConfig {
        uint256 collectionId;
        bytes32 phaseId;
        uint256 price;
        uint64 startsAt;
        uint64 endsAt;
        bytes32 mintPolicyHash;
        bytes32 primaryAssignmentHash;
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
        bytes32 expectedPrimaryPolicyHash;
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
        StreamNativeSettlementTypes.SaleLifecycleBinding lifecycle;
        bool cancelled;
    }
    error InvalidNativeSale();
    error NativeSaleUnavailable(bytes32 saleId);
    error NativeAuthorizationUsed(address artist, bytes32 nonce);
    error NativeExecutionUsed(bytes32 saleId, uint256 executionNonce);
    error NativeSaleSignatureInvalid(address signer);
    error NativeCandidateMismatch();
    error NativeSettlementFailed();
    error NativeMintResultInvalid();

    event NativeSaleConfigured(
        bytes32 indexed saleId,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        uint16 schemaVersion,
        uint256 saleNonce,
        bytes32 configHash
    );
    event NativeSaleCancelled(bytes32 indexed saleId, uint16 schemaVersion);
    event NativeSalesPaused(uint16 schemaVersion, bool paused);
    event NativeAuthorizationCancelled(
        address indexed artist, bytes32 indexed nonce, uint16 schemaVersion
    );
    event NativeSaleExecution(
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
        returns (StreamNativeSettlementTypes.NativeSettlementCandidate memory);
    function purchase(SaleExecutionData calldata execution)
        external
        payable
        returns (
            StreamPrimarySettlementTypes.PrimarySettlementResult memory result,
            uint256 tokenId
        );
    function nativeSaleLifecycleBinding(bytes32 saleId)
        external
        view
        returns (StreamNativeSettlementTypes.SaleLifecycleBinding memory);
    function cancelSale(bytes32 saleId) external;
    function cancelAuthorization(bytes32 nonce) external;
    function setPaused(bool paused) external;
}
