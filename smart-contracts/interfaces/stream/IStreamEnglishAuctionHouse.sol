// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../vendor/openzeppelin/IERC165.sol";

interface IStreamEnglishAuctionHouse is IERC165 {
    enum AuctionStatus {
        None,
        Created,
        Active,
        EndedNoBid,
        EndedWithBid,
        SettledNoBid,
        SettledWithBid,
        Cancelled
    }

    struct AuctionAuthorization {
        uint256 collectionId;
        bytes32 phaseId;
        address artist;
        bytes32 profileId;
        bytes32 tokenDataHash;
        bytes32 mintCommitment;
        bytes32 mintPolicyHash;
        uint256 reservePrice;
        uint64 startTime;
        uint64 endTime;
        uint32 extensionWindow;
        uint16 minBidIncrementBps;
        bytes32 nonce;
        uint64 deadline;
        uint64 signerEpoch;
    }

    struct Auction {
        address artist;
        address wallet;
        bytes32 profileId;
        uint256 reservePrice;
        uint64 startTime;
        uint64 endTime;
        uint32 extensionWindow;
        uint16 minBidIncrementBps;
        address highestBidder;
        address deliveryRecipient;
        uint256 highestBid;
        bool settled;
        bool cancelled;
        address pendingNoBidNftClaimant;
    }

    error InvalidAuctionConfiguration();
    error AuctionsPaused();
    error InvalidAuctionAuthorization();
    error InvalidAuctionSignature(address signer);
    error AuctionAuthorizationUsed(address artist, bytes32 nonce);
    error AuctionUnknown(uint256 tokenId);
    error AuctionNotActive(uint256 tokenId);
    error AuctionNotEnded(uint256 tokenId);
    error AuctionAlreadySettled(uint256 tokenId);
    error AuctionNotCancellable(uint256 tokenId);
    error UnauthorizedAuctionClaimant(address caller);
    error BidTooLow(uint256 required, uint256 supplied);
    error InvalidAuctionRecipient();
    error UnexpectedAuctionNFT();
    error AuctionMintResultInvalid();
    error InvalidAuctionSplitProfile(bytes32 profileId);
    error AuctionNativeTransferFailed(address recipient);
    error NoAuctionRefund();
    error NoPendingAuctionNFTClaim(uint256 tokenId);

    event AuctionCreated(
        uint256 indexed tokenId,
        address indexed artist,
        bytes32 indexed authorizationId,
        bytes32 operationRoot,
        bytes32 authorizationDigest,
        bytes32 profileId,
        address wallet
    );
    event AuctionTerms(
        uint256 indexed tokenId,
        uint256 reservePrice,
        uint64 startTime,
        uint64 endTime,
        uint32 extensionWindow,
        uint16 minBidIncrementBps
    );
    event AuctionBidPlaced(
        uint256 indexed tokenId,
        address indexed bidder,
        address recipient,
        uint256 amount,
        uint64 endTime
    );
    event AuctionRefundCredited(address indexed bidder, uint256 indexed tokenId, uint256 amount);
    event AuctionRefundWithdrawn(address indexed bidder, address indexed recipient, uint256 amount);
    event AuctionSettled(
        uint256 indexed tokenId,
        address indexed bidder,
        address indexed recipient,
        address wallet,
        uint256 amount
    );
    event AuctionCancelled(uint256 indexed tokenId, address indexed recipient);
    event NoBidAuctionNFTClaimPending(uint256 indexed tokenId, address indexed claimant);
    event AuctionRecipientChanged(uint256 indexed tokenId, address indexed recipient);
    event AuctionAuthorizationCancelled(address indexed artist, bytes32 indexed nonce);
    event AuctionPlatformSignerChanged(address indexed signer, uint64 epoch);
    event AuctionsPauseChanged(bool paused);

    function createAuction(
        AuctionAuthorization calldata authorization,
        bytes calldata tokenData,
        bytes calldata platformSignature,
        bytes calldata artistSignature
    ) external returns (uint256 tokenId);

    function bid(uint256 tokenId, address recipient) external payable;
    function settle(uint256 tokenId) external;
    function cancel(uint256 tokenId) external;
    function setDeliveryRecipient(uint256 tokenId, address recipient) external;
    function claimNoBidNFT(uint256 tokenId, address recipient) external;
    function withdrawRefund(address payable recipient) external;
    function auction(uint256 tokenId) external view returns (Auction memory);
    function auctionStatus(uint256 tokenId) external view returns (AuctionStatus);
    function minimumBid(uint256 tokenId) external view returns (uint256);
    function authorizationDigest(AuctionAuthorization calldata authorization)
        external
        view
        returns (bytes32);
}
