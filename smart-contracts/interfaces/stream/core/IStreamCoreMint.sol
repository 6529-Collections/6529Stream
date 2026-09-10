// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCoreTypes.sol";

/// @notice Manager-only token allocation, prepared mint lifecycle, and token data.
interface IStreamCoreMint {
    event TokenCollectionRegistered(
        uint16 schemaVersion,
        uint256 indexed tokenId,
        uint256 indexed collectionId,
        uint256 collectionSerial
    );

    event TokenCollectionRegistrationReverted(
        uint16 schemaVersion, uint256 indexed tokenId, uint256 indexed collectionId
    );

    /// @notice Allocates and safely mints a token for the installed mint manager.
    /// @dev Only the installed manager may call; receiver rejection rolls back the entire mint.
    /// @param collectionId Existing collection receiving the new token.
    /// @param initialRecipient Address receiving the ERC-721 token and its safe-receiver callback.
    /// @param tokenData_ Artwork bytes whose exact encoding is committed by tokenDataHash.
    /// @param tokenDataHash keccak256 of tokenData_.
    /// @param mintCommitment Per-token commitment passed to the entropy registration boundary.
    /// @return tokenId Globally allocated token identifier.
    /// @return collectionSerial Collection-local serial assigned to this token.
    function mintFromManager(
        uint256 collectionId,
        address initialRecipient,
        bytes calldata tokenData_,
        bytes32 tokenDataHash,
        bytes32 mintCommitment
    ) external returns (uint256 tokenId, uint256 collectionSerial);

    /// @notice Reserves the singleton prepared token without completing its ERC-721 mint.
    /// @dev Only the installed manager may call; at most one prepared token exists at a time.
    /// @param operationId Nonzero identity repeated at completion or by a replacement manager during abort.
    function prepareMintFromManager(
        uint256 collectionId,
        bytes calldata tokenData_,
        bytes32 tokenDataHash,
        bytes32 operationId
    ) external returns (uint256 tokenId, uint256 collectionSerial);

    /// @notice Completes the manager operation that owns the prepared token.
    /// @dev The caller, tokenId, and operationId must match the pending preparation.
    /// @param initialRecipient Address receiving the completed token and safe-receiver callback.
    /// @param mintCommitment Per-token commitment supplied at completion.
    function completePreparedMintFromManager(
        uint256 tokenId,
        address initialRecipient,
        bytes32 operationId,
        bytes32 mintCommitment
    ) external;

    /// @notice Aborts a pending preparation through the installed replacement manager.
    /// @dev The installed caller must differ from the preparing manager. The exact
    ///      token/operation match is required; abort removes its identity/data and
    ///      rewinds the global token and collection serial allocation frontiers.
    function abortPreparedMintFromManager(uint256 tokenId, bytes32 operationId) external;

    /// @notice Returns the public pending-operation record for a token.
    function preparedMint(uint256 tokenId) external view returns (StreamPreparedMintRecord memory);

    /// @notice Returns the singleton pending token identifier, or zero when none exists.
    function pendingPreparedMintTokenId() external view returns (uint256 tokenId);

    /// @notice Returns the token artwork data stored by the mint operation.
    function tokenData(uint256 tokenId) external view returns (bytes memory);
}
