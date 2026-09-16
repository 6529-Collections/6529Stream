// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../domains/auctions/StreamEnglishAuctionClock.sol";
import "../revenue/StreamNativeSettlementTypes.sol";
import "../revenue/StreamPrimarySettlementTypes.sol";

/// @notice Versioned deferred native auction. Existing V2 auction signatures are unchanged.
/// @dev Collection PROFILE and exact tokenData commitment. Optional delegated delivery has
/// its own declared interface. Custody-start, curated leaves and other rights remain separate.
interface IStreamNativeEnglishAuction {
    struct Configuration {
        uint256 collectionId;
        bytes32 phaseId;
        uint256 tokenId;
        bool mintAtSettlement;
        bytes32 artworkCommitment;
        bytes32 contentManifestRoot;
        bytes32 mintCommitment;
        address poster;
        uint96 reservePrice;
        uint16 minIncrementBps;
        bool incrementFloorWaived;
        StreamEnglishAuctionClock.Configuration clock;
        bytes32 expectedPrimaryPolicyHash;
        uint8 primaryPolicyMode;
        uint32 settlementWindow;
        bytes32 mintPolicyHash;
    }

    struct CreationAuthorization {
        bytes32 configHash;
        address artist;
        bytes32 nonce;
        uint64 deadline;
    }

    struct BidAuthorization {
        bytes32 auctionId;
        bytes32 configHash;
        address payer;
        address executor;
        address deliverTo;
        uint256 amount;
        uint256 maxRevealFee;
        bytes32 nonce;
        uint64 deadline;
        uint64 finalizeBy;
    }

    struct WinningBid {
        address payer;
        address executor;
        address deliverTo;
        uint256 amount;
        uint256 revealFee;
        uint256 bidIndex;
        bytes32 authorizationDigest;
        uint64 signedFinalizeBy;
        bool signed;
    }

    struct Auction {
        Configuration config;
        bytes32 configHash;
        bytes32 saleId;
        uint256 saleNonce;
        uint256 auctionNonce;
        uint8 status; // 1 ACTIVE, 2 SETTLING, 3 SETTLED, 4 CANCELLED, 5 NO_BIDS, 6 NO_MINT
        StreamEnglishAuctionClock.State clock;
        uint64 pauseBaseline;
        uint64 terminalToll;
        uint64 bindingGeneration;
        bytes32 artistId;
        bytes32 bindingHash;
        bytes32 creationDigest;
        StreamNativeSettlementTypes.SaleLifecycleBinding lifecycle;
        WinningBid winner;
        uint256 tokenId;
        bytes32 settlementKey;
        address nftClaimant;
    }

    error InvalidNativeAuction();
    error UnsupportedNativeAuctionProfile();
    error NativeAuctionUnavailable(bytes32 auctionId);
    error NativeAuctionTerminal(bytes32 auctionId);
    error NativeAuctionPaused();
    error NativeAuctionAuthorizationInvalid(address signer);
    error NativeAuctionAuthorizationUsed(address signer, bytes32 nonce);
    error NativeAuctionArtworkMismatch();
    error NativeAuctionAccountingMismatch();
    error NativeAuctionDeliveryGas(uint256 available, uint256 required);
    error NativeAuctionUnlockUnavailable(bytes32 auctionId, uint8 reason);

    event NativeAuctionCreated(
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        bytes32 indexed configHash,
        Configuration config,
        bytes32 creationDigest
    );
    event AuctionExtended(
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        uint64 previousEndTime,
        uint64 endTime,
        uint32 totalExtensionUsed
    );
    event AuctionExtensionBudgetWarning(
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        uint32 usedSeconds,
        uint32 remainingSeconds
    );
    event AuctionBidDeliveryBound(
        bytes32 indexed auctionId, bytes32 indexed saleId, address indexed bidder, address deliverTo
    );
    event NativeAuctionBid(
        bytes32 indexed auctionId, bytes32 indexed saleId, address indexed payer, WinningBid bid
    );
    event NativeAuctionRefundCredit(
        bytes32 indexed auctionId, bytes32 indexed saleId, address indexed payer, uint256 amount
    );
    event NativeAuctionRefundClaimed(
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        address indexed payer,
        address recipient,
        uint256 amount
    );
    event NativeAuctionSettled(
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        uint256 indexed tokenId,
        bytes32 settlementKey,
        uint256 amount,
        uint256 revealFeeForwarded,
        uint256 revealFeeRefunded
    );
    event NativeAuctionNoMint(
        bytes32 indexed auctionId, bytes32 indexed saleId, bytes32 reasonHash, uint256 refundAmount
    );
    event NativeAuctionCancelled(
        bytes32 indexed auctionId, bytes32 indexed saleId, bytes32 reasonHash
    );
    event NativeAuctionNoBids(
        bytes32 indexed auctionId, bytes32 indexed saleId, bytes32 reasonHash
    );
    event NativeAuctionNFTClaimPending(
        bytes32 indexed auctionId, bytes32 indexed saleId, uint256 indexed tokenId, address claimant
    );
    event NativeAuctionNFTDelivered(
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        uint256 indexed tokenId,
        address recipient
    );
    event NativeAuctionPause(
        bytes32 indexed saleId,
        bool global,
        bool paused,
        address indexed actor,
        bytes32 reasonHash,
        uint64 totalPause
    );

    function registerAuction(
        Configuration calldata config,
        bytes calldata tokenData,
        CreationAuthorization calldata authorization,
        bytes calldata platformSignature,
        bytes calldata artistSignature
    ) external returns (bytes32 auctionId);
    function bid(bytes32 auctionId, address deliverTo) external payable;
    function bidSigned(BidAuthorization calldata authorization, bytes calldata signature)
        external
        payable;
    function settle(bytes32 auctionId) external returns (uint256 tokenId, bytes32 settlementKey);
    function unlockNoMint(bytes32 auctionId, uint8 reason) external;
    function cancel(bytes32 auctionId, bytes32 reason) external;
    function claimRefund(bytes32 saleId, address payable recipient)
        external
        returns (uint256 amount);
    function claimNFT(bytes32 auctionId, address recipient) external;
    function auction(bytes32 auctionId) external view returns (Auction memory);
    function auctionConfig(bytes32 auctionId)
        external
        view
        returns (
            uint16 minIncrementBps,
            bool incrementFloorWaived,
            bool hardClose,
            uint32 antiSnipeWindow,
            uint32 antiSnipeExtension,
            uint32 maxTotalExtension,
            uint32 totalExtensionUsed,
            uint64 endTime
        );
    function auctionDeadlines(bytes32 auctionId)
        external
        view
        returns (uint64 endTime, uint64 finalizeBy, uint64 signedCeiling, uint64 pauseToll);
    function refundableBalance(bytes32 saleId, address account) external view returns (uint256);
    function pauseAdapter(bytes32 reason) external;
    function unpauseAdapter(bytes32 reason) external;
    function pauseSale(bytes32 saleId, bytes32 reason) external;
    function unpauseSale(bytes32 saleId, bytes32 reason) external;
}
