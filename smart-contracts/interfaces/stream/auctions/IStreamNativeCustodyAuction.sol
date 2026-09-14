// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../revenue/StreamNativeCustodySettlementTypes.sol";

/// @notice Versioned unpaid custody acquisition; old creation and bid signatures are unchanged.
interface IStreamNativeCustodyAuction {
    struct Acquisition {
        bytes32 configHash;
        bytes32 tokenDataHash;
        uint256 expectedSaleNonce;
        uint256 expectedTokenId;
        uint256 expectedCollectionSerial;
        uint256 expectedOperationNonce;
        bytes32 contextHash;
        address executor;
        uint256 revealFeeDeposit;
        address artist;
        bytes32 nonce;
        uint64 deadline;
    }

    error InvalidNativeCustody();
    error NativeCustodyOriginUnavailable(bytes32 auctionId);

    event NativeAuctionCustodyAcquired(
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        uint256 indexed tokenId,
        Acquisition authorization,
        StreamNativeCustodySettlementTypes.Origin origin
    );
    event NativeAuctionCustodyReleased(
        bytes32 indexed auctionId, bytes32 indexed saleId, uint256 indexed tokenId, address to
    );

    event NativeAuctionCustodySaleAborted(
        bytes32 indexed auctionId, bytes32 indexed saleId, bytes32 reasonHash, uint256 refundAmount
    );

    function custodyAcquisitionDigest(Acquisition calldata authorization)
        external
        view
        returns (bytes32);
    function registerCustodyAuction(
        IStreamNativeEnglishAuction.Configuration calldata config,
        Acquisition calldata authorization,
        bytes calldata tokenData,
        bytes calldata platformSignature,
        bytes calldata artistSignature
    ) external payable returns (bytes32 auctionId);
    function unlockCustodySale(bytes32 auctionId, uint8 reason) external;
    function custodyOrigin(bytes32 auctionId)
        external
        view
        returns (StreamNativeCustodySettlementTypes.Origin memory);
    function activeCustodySale(bytes32 auctionId)
        external
        view
        returns (StreamNativeCustodySettlementTypes.Facts memory);
}
