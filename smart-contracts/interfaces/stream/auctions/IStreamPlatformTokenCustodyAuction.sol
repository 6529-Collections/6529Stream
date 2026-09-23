// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamNativeEnglishAuction.sol";
import "../revenue/StreamPlatformTokenCustodyTypes.sol";

/// @notice Known-token PLATFORM_WORKS rights appended before any bid, retaining original custody.
interface IStreamPlatformTokenCustodyAuction {
    error InvalidPlatformTokenCustody();
    error PlatformTokenCustodyEntryRequired(bytes32 auctionId);
    event PlatformTokenCustodyActivated(
        uint16 schemaVersion,
        bytes32 indexed auctionId,
        uint256 indexed tokenId,
        bytes32 indexed authorizationDigest,
        StreamPlatformTokenCustodyTypes.Activation activation
    );
    function platformTokenCustodyDigest(
        StreamPlatformTokenCustodyTypes.Authorization calldata authorization
    ) external view returns (bytes32);
    function activatePlatformTokenCustody(
        StreamPlatformTokenCustodyTypes.Authorization calldata authorization,
        bytes calldata platformSignature
    ) external;
    function platformTokenCustodyActivation(bytes32 auctionId)
        external
        view
        returns (StreamPlatformTokenCustodyTypes.Activation memory);
    function platformTokenCustodyConfigurationHash(bytes32 auctionId)
        external
        view
        returns (bytes32);
    function platformTokenCustodyNonceUsed(bytes32 nonce) external view returns (bool);
    function bidPlatformTokenCustody(bytes32 auctionId, address deliverTo) external payable;
    function bidSignedPlatformTokenCustody(
        IStreamNativeEnglishAuction.BidAuthorization calldata authorization,
        bytes calldata signature
    ) external payable;
    function settlePlatformTokenCustody(bytes32 auctionId)
        external
        returns (uint256 tokenId, bytes32 settlementKey);
}
