// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamNativeRightsAuction.sol";

/// @notice Explicit declaration-authorized PLATFORM_WORKS deferred auctions; no Artist signature.
interface IStreamPlatformNativeRightsAuction {
    struct PlatformCreationAuthorization {
        bytes32 configHash;
        bytes32 declarationHash;
        bytes32 nonce;
        uint64 deadline;
    }
    event PlatformNativeAuctionBound(
        uint16 schemaVersion,
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        bytes32 indexed declarationHash,
        uint8 mode,
        bytes32 configHash,
        bytes32 creationDigest
    );
    function platformRightsConfigurationHash(
        IStreamNativeEnglishAuction.Configuration calldata config,
        StreamPreparedNativeRightsTypes.OriginalPolicy calldata original,
        bytes32 declarationHash
    ) external view returns (bytes32);
    function platformRightsCreationDigest(PlatformCreationAuthorization calldata authorization)
        external
        view
        returns (bytes32);
    function registerPlatformRightsAuction(
        IStreamNativeEnglishAuction.Configuration calldata config,
        StreamPreparedNativeRightsTypes.OriginalPolicy calldata original,
        bytes calldata tokenData,
        PlatformCreationAuthorization calldata authorization,
        bytes calldata platformSignature
    ) external returns (bytes32 auctionId);
    /// @notice Original declaration retained by sale id; zero means this is not the platform family.
    function platformAuctionDeclaration(bytes32 saleId) external view returns (bytes32);
}
