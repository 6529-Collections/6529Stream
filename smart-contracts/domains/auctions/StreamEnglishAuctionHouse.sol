// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../mint/StreamSaleArtist.sol";
import "../mint/StreamLegacySaleConsent.sol";
import "../mint/StreamSaleFunding.sol";

import "../../interfaces/stream/mint/IStreamMintReads.sol";

import "../../interfaces/stream/auctions/IStreamEnglishAuctionHouse.sol";
import "../../interfaces/stream/core/IStreamCore.sol";
import "../../interfaces/stream/mint/IStreamMintManager.sol";
import "../../interfaces/stream/revenue/IStreamSplitFactory.sol";
import "../../interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../vendor/openzeppelin/ERC165.sol";
import "../../vendor/openzeppelin/IERC721Receiver.sol";
import "../../vendor/openzeppelin/Math.sol";
import "../../vendor/openzeppelin/Ownable.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../mint/StreamSaleSignatures.sol";

/// @notice Current-Core English auctions with NFT custody, pull refunds and immutable sale splits.
contract StreamEnglishAuctionHouse is
    IStreamEnglishAuctionHouse,
    IERC721Receiver,
    ERC165,
    Ownable,
    ReentrancyGuard,
    StreamSaleFunding
{
    bytes32 public constant AUCTION_AUTHORIZATION_TYPEHASH = keccak256(
        "AuctionAuthorization(uint256 collectionId,bytes32 phaseId,address artist,bytes32 profileId,bytes32 expectedPrimaryPolicyHash,bytes32 tokenDataHash,bytes32 mintCommitment,bytes32 mintPolicyHash,uint256 reservePrice,uint64 startTime,uint64 endTime,uint32 extensionWindow,uint16 minBidIncrementBps,bytes32 nonce,uint64 deadline,uint64 signerEpoch)"
    );
    bytes32 private constant DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 private constant NONCE_DOMAIN = keccak256("6529STREAM_ENGLISH_AUCTION_NONCE_V1");
    bytes32 public constant REVENUE_CLASS = keccak256("PRIMARY_SALE");
    bytes32 public constant PRIMARY_POLICY_DOMAIN = keccak256("6529STREAM_PRIMARY_POLICY_V1");
    IStreamCore public immutable core;
    IStreamMintManager public immutable mintManager;
    IStreamSplitFactory public immutable splitFactory;
    IStreamRevenueResolver public immutable override revenueResolver;
    IStreamArtistAttribution public immutable artistRegistry;
    bytes32 public immutable artistRegistryCodeHash;
    address public platformSigner;
    uint64 public signerEpoch = 1;
    bool public paused;
    bool private _acceptingMint;
    mapping(uint256 => Auction) private _auctions;
    mapping(address => mapping(bytes32 => bool)) public authorizationUsed;
    mapping(address => uint256) public refundCredit;
    mapping(bytes32 => uint256) public nativeProceeds;
    uint256 public totalBidEscrow;
    uint256 public totalRefundOwed;
    uint256 public totalNativeProceeds;

    constructor(
        IStreamCore core_,
        IStreamMintManager mintManager_,
        IStreamRevenueResolver resolver_,
        address platformSigner_,
        IStreamArtistAttribution artistRegistry_,
        IStreamRevenueEscrow escrow_
    ) StreamSaleFunding(IStreamSplitFactory(resolver_.splitFactory()), escrow_) {
        IStreamSplitFactory splitFactory_ = IStreamSplitFactory(resolver_.splitFactory());
        if (
            address(core_).code.length == 0 || address(mintManager_).code.length == 0
                || address(splitFactory_).code.length == 0 || platformSigner_ == address(0)
                || !resolver_.isStreamRevenueResolver() || resolver_.core() != address(core_)
                || resolver_.artistRegistry() != address(artistRegistry_)
        ) revert InvalidAuctionConfiguration();
        if (
            !StreamSaleArtist.supportsAttribution(artistRegistry_)
                || artistRegistry_.core() != address(core_)
        ) revert InvalidAuctionConfiguration();
        if (address(IStreamMintReads(address(mintManager_)).core()) != address(core_)) {
            revert InvalidAuctionConfiguration();
        }
        core = core_;
        mintManager = mintManager_;
        splitFactory = splitFactory_;
        revenueResolver = resolver_;
        platformSigner = platformSigner_;
        artistRegistry = artistRegistry_;
        artistRegistryCodeHash = address(artistRegistry_).codehash;
    }

    function supportsInterface(bytes4 id) public view override(ERC165, IERC165) returns (bool) {
        return id == type(IStreamEnglishAuctionHouse).interfaceId || super.supportsInterface(id);
    }

    function setPlatformSigner(address signer) external onlyOwner nonReentrant {
        if (signer == address(0)) revert InvalidAuctionConfiguration();
        platformSigner = signer;
        signerEpoch += 1;
        emit AuctionPlatformSignerChanged(signer, signerEpoch);
    }

    /// @notice Pausing stops new exposure. Existing settlement and refund exits remain available.
    function setPaused(bool paused_) external onlyOwner nonReentrant {
        paused = paused_;
        emit AuctionsPauseChanged(paused_);
    }

    function cancelAuthorization(bytes32 nonce) external nonReentrant {
        if (nonce == bytes32(0)) revert InvalidAuctionAuthorization();
        if (authorizationUsed[msg.sender][nonce]) {
            revert AuctionAuthorizationUsed(msg.sender, nonce);
        }
        authorizationUsed[msg.sender][nonce] = true;
        emit AuctionAuthorizationCancelled(msg.sender, nonce);
    }

    function domainSeparator() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256("6529StreamEnglishAuction"),
                keccak256("2"),
                block.chainid,
                address(this)
            )
        );
    }

    function authorizationDigest(AuctionAuthorization calldata authorization)
        public
        view
        override
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                hex"1901",
                domainSeparator(),
                keccak256(abi.encode(AUCTION_AUTHORIZATION_TYPEHASH, authorization))
            )
        );
    }

    function authorizationId(address artist, bytes32 nonce) public view returns (bytes32) {
        return keccak256(abi.encode(NONCE_DOMAIN, block.chainid, address(this), artist, nonce));
    }

    function primaryPolicy(uint256 collectionId)
        public
        view
        override
        returns (bytes32 policyHash, bytes32 profileId, address wallet)
    {
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a =
            revenueResolver.resolvePrimaryAssignment(collectionId, 0, REVENUE_CLASS);
        if (
            !a.exists || a.assignmentType != 1 || a.scope != 1 || a.scopeId != collectionId
                || a.templateId != bytes32(0) || a.profileId == bytes32(0)
                || a.assignmentHash == bytes32(0)
        ) revert AuctionPrimaryAssignmentUnsupported();
        profileId = a.profileId;
        wallet = splitFactory.walletFor(profileId);
        _requireFundingWallet(profileId, wallet);
        policyHash = keccak256(
            abi.encode(
                PRIMARY_POLICY_DOMAIN,
                block.chainid,
                address(revenueResolver),
                REVENUE_CLASS,
                collectionId,
                uint256(0),
                bytes32(0),
                profileId,
                wallet,
                a.assignmentHash
            )
        );
    }

    function _requirePrimaryPolicy(AuctionAuthorization calldata a)
        private
        view
        returns (address wallet)
    {
        (bytes32 policy, bytes32 profile, address target) = primaryPolicy(a.collectionId);
        if (profile != a.profileId) revert InvalidAuctionSplitProfile(a.profileId);
        if (policy != a.expectedPrimaryPolicyHash) {
            revert AuctionPrimaryPolicyMismatch(a.expectedPrimaryPolicyHash, policy);
        }
        return target;
    }

    function createAuction(
        AuctionAuthorization calldata authorization,
        bytes calldata tokenData,
        bytes calldata platformSignature,
        bytes calldata artistSignature
    ) external override nonReentrant returns (uint256 tokenId) {
        if (paused) revert AuctionsPaused();
        _validateAuthorization(authorization, tokenData);
        StreamLegacySaleConsent.requireNone(
            artistRegistry, artistRegistryCodeHash, authorization.collectionId, authorization.artist
        );
        bytes32 digest = authorizationDigest(authorization);
        _requireSignature(platformSigner, digest, platformSignature);
        _requireSignature(authorization.artist, digest, artistSignature);
        address wallet = _requirePrimaryPolicy(authorization);
        bytes32 id = authorizationId(authorization.artist, authorization.nonce);
        bytes32 operationRoot;
        (tokenId, operationRoot) = _mintAuctionToken(authorization, tokenData, digest, id);
        StreamLegacySaleConsent.requireNone(
            artistRegistry, artistRegistryCodeHash, authorization.collectionId, authorization.artist
        );
        _storeAuction(tokenId, authorization, wallet, id, operationRoot);
        _emitAuctionCreated(tokenId, authorization, id, operationRoot, digest, wallet);
    }

    function _emitAuctionCreated(
        uint256 tokenId,
        AuctionAuthorization calldata authorization,
        bytes32 id,
        bytes32 operationRoot,
        bytes32 digest,
        address wallet
    ) private {
        emit AuctionCreated(
            tokenId,
            authorization.artist,
            id,
            operationRoot,
            digest,
            authorization.profileId,
            wallet
        );
        emit AuctionTerms(
            tokenId,
            authorization.reservePrice,
            authorization.startTime,
            authorization.endTime,
            authorization.extensionWindow,
            authorization.minBidIncrementBps
        );
    }

    function _mintAuctionToken(
        AuctionAuthorization calldata authorization,
        bytes calldata tokenData,
        bytes32 digest,
        bytes32 id
    ) private returns (uint256 tokenId, bytes32 operationRoot) {
        IStreamMintManager.MintBatch memory batch = _mintBatch(authorization, tokenData, digest, id);
        (bytes32 expectedRoot, bytes32[] memory expectedIds) =
            IStreamMintReads(address(mintManager)).previewSingleStepMintOperation(batch, "");
        if (expectedRoot == bytes32(0) || expectedIds.length != 1 || expectedIds[0] == bytes32(0)) {
            revert AuctionMintResultInvalid();
        }
        authorizationUsed[authorization.artist][authorization.nonce] = true;
        _acceptingMint = true;
        uint256[] memory tokenIds;
        bytes32[] memory operationIds;
        (tokenIds, operationRoot, operationIds) = mintManager.executeSingleStepMint(batch, "");
        _acceptingMint = false;
        if (
            tokenIds.length != 1 || tokenIds[0] == 0 || operationRoot != expectedRoot
                || operationIds.length != 1 || operationIds[0] != expectedIds[0]
        ) revert AuctionMintResultInvalid();
        tokenId = tokenIds[0];
        if (core.ownerOf(tokenId) != address(this) || _auctions[tokenId].artist != address(0)) {
            revert AuctionMintResultInvalid();
        }
    }

    function auction(uint256 tokenId) external view override returns (Auction memory) {
        return _requireAuction(tokenId);
    }

    function auctionStatus(uint256 tokenId) external view override returns (AuctionStatus) {
        Auction storage item = _auctions[tokenId];
        if (item.artist == address(0)) return AuctionStatus.None;
        if (item.cancelled) return AuctionStatus.Cancelled;
        if (item.settled) {
            return item.highestBid == 0 ? AuctionStatus.SettledNoBid : AuctionStatus.SettledWithBid;
        }
        if (block.timestamp < item.startTime) return AuctionStatus.Created;
        if (block.timestamp < item.endTime) return AuctionStatus.Active;
        return item.highestBid == 0 ? AuctionStatus.EndedNoBid : AuctionStatus.EndedWithBid;
    }

    function minimumBid(uint256 tokenId) public view override returns (uint256) {
        Auction storage item = _requireAuction(tokenId);
        if (item.highestBid == 0) return item.reservePrice == 0 ? 1 : item.reservePrice;
        return item.highestBid
            + Math.mulDiv(item.highestBid, item.minBidIncrementBps, 10_000, Math.Rounding.Up);
    }

    function bid(uint256 tokenId, address recipient) external payable override nonReentrant {
        if (paused) revert AuctionsPaused();
        Auction storage item = _requireAuction(tokenId);
        if (item.settled || block.timestamp < item.startTime || block.timestamp >= item.endTime) {
            revert AuctionNotActive(tokenId);
        }
        if (recipient == address(0)) revert InvalidAuctionRecipient();
        uint256 required = minimumBid(tokenId);
        if (msg.value < required) revert BidTooLow(required, msg.value);
        uint256 previousBid = item.highestBid;
        if (previousBid != 0) {
            refundCredit[item.highestBidder] += previousBid;
            totalRefundOwed += previousBid;
            emit AuctionRefundCredited(item.highestBidder, tokenId, previousBid);
        }
        totalBidEscrow = totalBidEscrow - previousBid + msg.value;
        item.highestBid = msg.value;
        item.highestBidder = msg.sender;
        item.deliveryRecipient = recipient;
        if (uint256(item.endTime) - block.timestamp < item.extensionWindow) {
            uint256 extended = block.timestamp + item.extensionWindow;
            if (extended > type(uint64).max) revert InvalidAuctionConfiguration();
            item.endTime = uint64(extended);
        }
        emit AuctionBidPlaced(tokenId, msg.sender, recipient, msg.value, item.endTime);
    }

    function setDeliveryRecipient(uint256 tokenId, address recipient)
        external
        override
        nonReentrant
    {
        Auction storage item = _requireAuction(tokenId);
        if (item.settled) revert AuctionAlreadySettled(tokenId);
        address claimant = item.highestBidder == address(0) ? item.artist : item.highestBidder;
        if (msg.sender != claimant) revert UnauthorizedAuctionClaimant(msg.sender);
        if (recipient == address(0)) revert InvalidAuctionRecipient();
        item.deliveryRecipient = recipient;
        emit AuctionRecipientChanged(tokenId, recipient);
    }

    function settle(uint256 tokenId) external override nonReentrant {
        Auction storage item = _requireAuction(tokenId);
        if (item.settled) revert AuctionAlreadySettled(tokenId);
        if (block.timestamp < item.endTime) revert AuctionNotEnded(tokenId);
        if (item.highestBid == 0 && item.deliveryRecipient.code.length != 0) {
            if (item.pendingNoBidNftClaimant == address(0)) {
                item.pendingNoBidNftClaimant = item.artist;
                emit NoBidAuctionNFTClaimPending(tokenId, item.artist);
            }
            return;
        }
        item.settled = true;
        item.pendingNoBidNftClaimant = address(0);
        uint256 amount = item.highestBid;
        bool escrowed;
        if (amount != 0) {
            totalBidEscrow -= amount;
            totalNativeProceeds += amount;
            nativeProceeds[item.profileId] += amount;
            escrowed = _fundNative(REVENUE_CLASS, item.profileId, item.wallet, amount);
        }
        core.safeTransferFrom(address(this), item.deliveryRecipient, tokenId);
        emit AuctionSettled(
            tokenId, item.highestBidder, item.deliveryRecipient, item.wallet, amount
        );
        if (amount != 0) {
            emit SaleRevenueFunded(
                1,
                item.authorizationId,
                item.operationRoot,
                item.profileId,
                item.wallet,
                address(0),
                amount,
                escrowed
            );
        }
    }

    /// @notice A signed artist controls delivery when an unsold NFT needs a contract receiver.
    function claimNoBidNFT(uint256 tokenId, address recipient) external override nonReentrant {
        Auction storage item = _requireAuction(tokenId);
        if (item.settled || item.pendingNoBidNftClaimant == address(0)) {
            revert NoPendingAuctionNFTClaim(tokenId);
        }
        if (msg.sender != item.pendingNoBidNftClaimant) {
            revert UnauthorizedAuctionClaimant(msg.sender);
        }
        if (recipient == address(0)) revert InvalidAuctionRecipient();
        item.settled = true;
        item.pendingNoBidNftClaimant = address(0);
        item.deliveryRecipient = recipient;
        core.safeTransferFrom(address(this), recipient, tokenId);
        emit AuctionSettled(tokenId, address(0), recipient, item.wallet, 0);
    }

    function cancel(uint256 tokenId) external override nonReentrant {
        Auction storage item = _requireAuction(tokenId);
        if (msg.sender != item.artist) revert UnauthorizedAuctionClaimant(msg.sender);
        if (item.settled || item.highestBid != 0 || block.timestamp >= item.endTime) {
            revert AuctionNotCancellable(tokenId);
        }
        item.settled = true;
        item.cancelled = true;
        core.safeTransferFrom(address(this), item.deliveryRecipient, tokenId);
        emit AuctionCancelled(tokenId, item.deliveryRecipient);
    }

    function withdrawRefund(address payable recipient) external override nonReentrant {
        if (recipient == address(0)) revert InvalidAuctionRecipient();
        uint256 amount = refundCredit[msg.sender];
        if (amount == 0) revert NoAuctionRefund();
        refundCredit[msg.sender] = 0;
        totalRefundOwed -= amount;
        _sendNative(recipient, amount);
        emit AuctionRefundWithdrawn(msg.sender, recipient, amount);
    }

    function totalOwed() public view returns (uint256) {
        return totalBidEscrow + totalRefundOwed;
    }

    function surplus() external view returns (uint256) {
        return address(this).balance - totalOwed();
    }

    function onERC721Received(address, address from, uint256, bytes calldata)
        external
        view
        override
        returns (bytes4)
    {
        if (msg.sender != address(core) || from != address(0) || !_acceptingMint) {
            revert UnexpectedAuctionNFT();
        }
        return IERC721Receiver.onERC721Received.selector;
    }

    function _validateAuthorization(AuctionAuthorization calldata item, bytes calldata tokenData)
        private
        view
    {
        if (
            item.collectionId == 0 || item.phaseId == bytes32(0) || item.artist == address(0)
                || item.profileId == bytes32(0) || item.expectedPrimaryPolicyHash == bytes32(0)
                || item.tokenDataHash != keccak256(tokenData) || item.mintCommitment == bytes32(0)
                || item.mintPolicyHash == bytes32(0) || item.nonce == bytes32(0)
                || item.signerEpoch != signerEpoch || block.timestamp > item.deadline
                || item.endTime <= item.startTime || item.endTime <= block.timestamp
                || item.endTime > block.timestamp + 365 days || item.extensionWindow > 1 days
                || item.minBidIncrementBps == 0 || item.minBidIncrementBps > 10_000
        ) revert InvalidAuctionAuthorization();
        if (authorizationUsed[item.artist][item.nonce]) {
            revert AuctionAuthorizationUsed(item.artist, item.nonce);
        }
    }

    function _mintBatch(
        AuctionAuthorization calldata item,
        bytes calldata tokenData,
        bytes32 digest,
        bytes32 id
    ) private view returns (IStreamMintManager.MintBatch memory batch) {
        batch.collectionId = item.collectionId;
        batch.phaseId = item.phaseId;
        batch.initialRecipients = new address[](1);
        batch.beneficiaries = new address[](1);
        batch.tokenData = new bytes[](1);
        batch.mintCommitments = new bytes32[](1);
        batch.initialRecipients[0] = address(this);
        batch.beneficiaries[0] = item.artist;
        batch.tokenData[0] = tokenData;
        batch.mintCommitments[0] = item.mintCommitment;
        batch.expectedPolicyHash = item.mintPolicyHash;
        batch.authorizationId = id;
        batch.contextHash = digest;
    }

    function _storeAuction(
        uint256 tokenId,
        AuctionAuthorization calldata item,
        address wallet,
        bytes32 id,
        bytes32 operationRoot
    ) private {
        Auction storage created = _auctions[tokenId];
        created.artist = item.artist;
        created.wallet = wallet;
        created.profileId = item.profileId;
        created.reservePrice = item.reservePrice;
        created.startTime = item.startTime;
        created.endTime = item.endTime;
        created.extensionWindow = item.extensionWindow;
        created.minBidIncrementBps = item.minBidIncrementBps;
        created.deliveryRecipient = item.artist;
        created.authorizationId = id;
        created.operationRoot = operationRoot;
        created.primaryPolicyHash = item.expectedPrimaryPolicyHash;
    }

    function _requireAuction(uint256 tokenId) private view returns (Auction storage item) {
        item = _auctions[tokenId];
        if (item.artist == address(0)) revert AuctionUnknown(tokenId);
    }

    function _requireSignature(address signer, bytes32 digest, bytes calldata signature)
        private
        view
    {
        if (!StreamSaleSignatures.isValid(signer, digest, signature)) {
            revert InvalidAuctionSignature(signer);
        }
    }

    function _sendNative(address payable recipient, uint256 amount) private {
        (bool ok,) = recipient.call{ value: amount }("");
        if (!ok) revert AuctionNativeTransferFailed(recipient);
    }
}
