// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamMintManager.sol";

/// @notice SSA-AIRDROP operator execution and perpetual failed-delivery claims.
interface IStreamOperatorDistribution {
    enum DeliveryMode {
        DIRECT,
        FAILURE_ISOLATED
    }

    /// @dev Committed by the V1 or additive Merkle phase/application config hash.
    struct Program {
        address operator;
        bytes32 slicesRoot;
        bytes32 supplyCounterId;
        bytes32 recipientCounterId;
        uint64 totalQuantity;
        // STATIC recipient cap, or registered ceiling for MERKLE_STATIC leaves.
        uint64 perRecipientCap;
        DeliveryMode deliveryMode;
        bool prepared;
    }

    struct NftClaim {
        uint256 collectionId;
        bytes32 phaseId;
        address beneficiary;
    }

    event AirdropDeliveryDiverted(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        uint256 indexed tokenId,
        address beneficiary
    );
    event AirdropNftClaimCompleted(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint256 indexed tokenId,
        address indexed receiver
    );
    event DistributionSliceExecuted(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        uint256 indexed sliceIndex,
        bytes32 sliceHash,
        bytes32 operationRoot,
        uint256 quantity
    );

    error InvalidDistribution();
    error DistributionNotActive();
    error DistributionNotOperator(address caller);
    error DistributionSliceUsed(uint256 sliceIndex);
    error DistributionCommitmentMismatch();
    error DistributionFeeMismatch(uint256 supplied, uint256 required);
    error DistributionClaimUnavailable(uint256 tokenId);
    error DistributionInsufficientGas(uint256 available, uint256 required);

    function programHash(uint256 collectionId, bytes32 phaseId, Program calldata program)
        external
        view
        returns (bytes32);
    function sliceHash(uint256 sliceIndex, IStreamMintManager.MintBatch calldata batch)
        external
        view
        returns (bytes32);
    function sliceAuthorization(uint256 collectionId, bytes32 phaseId, uint256 sliceIndex)
        external
        view
        returns (bytes32);
    function distribute(
        Program calldata program,
        uint256 sliceIndex,
        bytes32[] calldata proof,
        IStreamMintManager.MintBatch calldata batch,
        bytes calldata gateData
    ) external payable returns (uint256[] memory tokenIds, bytes32 operationRoot);
    function sliceUsed(uint256 collectionId, bytes32 phaseId, uint256 sliceIndex)
        external
        view
        returns (bool);
    function nftClaim(uint256 tokenId) external view returns (NftClaim memory);
    function claimNft(uint256 tokenId, address receiver) external returns (bool delivered);
    /// @notice A live delegate may only trigger delivery to the original beneficiary.
    function claimNftFor(uint256 tokenId, bool walletWide, uint256 delegationIndex)
        external
        returns (bool delivered);
}
