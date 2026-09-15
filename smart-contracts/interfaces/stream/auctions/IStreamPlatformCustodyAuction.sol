// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamNativeEnglishAuction.sol";
import "../revenue/StreamPreparedNativeRightsTypes.sol";
import "../revenue/StreamNativeCustodySettlementTypes.sol";

/// @notice Platform-only prepared acquisition, followed by an ALLOW_CURRENT fixed-profile transfer.
interface IStreamPlatformCustodyAuction {
    struct PlatformCustodyAuthorization {
        bytes32 configHash;
        bytes32 declarationHash;
        bytes32 tokenDataHash;
        uint256 expectedSaleNonce;
        uint256 expectedTokenId;
        uint256 expectedCollectionSerial;
        uint256 expectedOperationNonce;
        bytes32 contextHash;
        address executor;
        uint256 revealFeeDeposit;
        bytes32 nonce;
        uint64 deadline;
    }
    event PlatformCustodyAcquired(
        uint16 schemaVersion,
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        uint256 indexed tokenId,
        PlatformCustodyAuthorization authorization,
        StreamNativeCustodySettlementTypes.Origin origin
    );
    function platformCustodyAcquisitionDigest(PlatformCustodyAuthorization calldata authorization)
        external
        view
        returns (bytes32);
    function registerPlatformCustodyAuction(
        IStreamNativeEnglishAuction.Configuration calldata config,
        StreamPreparedNativeRightsTypes.OriginalPolicy calldata original,
        bytes calldata tokenData,
        PlatformCustodyAuthorization calldata authorization,
        bytes calldata platformSignature
    ) external payable returns (bytes32 auctionId);
}
