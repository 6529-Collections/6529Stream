// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./helpers/StreamSaleTestBase.sol";
import "../smart-contracts/domains/auctions/StreamEnglishAuctionHouse.sol";

contract AuctionTestReceiver is IERC721Receiver {
    bool public reject;
    StreamEnglishAuctionHouse public house;
    address public wallet;
    uint256 public observedPaid;
    uint256 public observedProceeds;
    uint256 public observedEscrow;
    bool public observedSettled;
    bool public reentered;

    function configure(StreamEnglishAuctionHouse house_, address wallet_, bool reject_) external {
        house = house_;
        wallet = wallet_;
        reject = reject_;
    }

    function onERC721Received(address, address, uint256 tokenId, bytes calldata)
        external
        returns (bytes4)
    {
        if (reject) revert("reject NFT");
        observedPaid = wallet.balance;
        observedProceeds = house.totalNativeProceeds();
        observedEscrow = house.totalBidEscrow();
        observedSettled = house.auction(tokenId).settled;
        (reentered,) = address(house).call(abi.encodeCall(house.settle, (tokenId)));
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract RejectAuctionRefund {
    receive() external payable {
        revert("reject ETH");
    }
}

contract AuctionContractArtist {
    address private immutable _owner = msg.sender;
    bytes32 private _digest;

    function authorize(bytes32 digest) external {
        require(msg.sender == _owner);
        _digest = digest;
    }

    function isValidSignature(bytes32 digest, bytes calldata) external view returns (bytes4) {
        return digest == _digest ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
    }

    function claim(StreamEnglishAuctionHouse house, uint256 tokenId, address recipient) external {
        require(msg.sender == _owner);
        house.claimNoBidNFT(tokenId, recipient);
    }
}

contract StreamEnglishAuctionHouseTest is StreamSaleTestBase {
    bytes32 private constant PHASE = keccak256("native-english-auction");
    address private constant FIRST_BIDDER = address(0xB1D1);
    address private constant SECOND_BIDDER = address(0xB1D2);
    StreamEnglishAuctionHouse private house;

    function setUp() public {
        _setUpSaleFixture();
        house = new StreamEnglishAuctionHouse(core, manager, factory, platform, artistRegistry);
        _configureSalePhase(PHASE, address(house));
        vm.deal(FIRST_BIDDER, 100 ether);
        vm.deal(SECOND_BIDDER, 100 ether);
    }

    function testSignedCreationCustodiesActualCoreNFTAndConsumesReplay() public {
        IStreamEnglishAuctionHouse.AuctionAuthorization memory authorization = _authorization();
        vm.recordLogs();
        uint256 tokenId = _create(authorization);
        require(core.ownerOf(tokenId) == address(house), "minted into auction custody");
        require(
            core.totalSupply() == 1 && manager.nextOperationNonce() == 1, "actual mint accounting"
        );
        require(house.authorizationUsed(artist, authorization.nonce), "signed nonce consumed");
        require(
            manager.isAuthorizationUsed(house.authorizationId(artist, authorization.nonce)),
            "ledger consumes authorization"
        );
        IStreamEnglishAuctionHouse.Auction memory item = house.auction(tokenId);
        require(
            item.artist == artist && item.wallet == wallet && item.profileId == profile,
            "immutable split"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool created;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(house)
                    && logs[i].topics[0]
                        == keccak256(
                            "AuctionCreated(uint256,address,bytes32,bytes32,bytes32,bytes32,address)"
                        )
            ) {
                created = true;
                require(logs[i].topics[1] == bytes32(tokenId), "creation token event");
            }
        }
        require(created, "observable creation");
        (bytes memory platformSig, bytes memory artistSig) = _sign(authorization);
        vm.expectRevert();
        house.createAuction(authorization, tokenData, platformSig, artistSig);
        require(core.totalSupply() == 1, "no replay mint");
    }

    function testOutbidCreditsPullRefundAndExtendsNearDeadline() public {
        uint256 tokenId = _create(_authorization());
        _bid(FIRST_BIDDER, tokenId, FIRST_BIDDER, 1 ether);
        require(house.minimumBid(tokenId) == 1.05 ether, "five percent increment");
        vm.prank(SECOND_BIDDER);
        vm.expectRevert();
        house.bid{ value: 1.05 ether - 1 }(tokenId, SECOND_BIDDER);
        uint64 initialEnd = house.auction(tokenId).endTime;
        vm.warp(uint256(initialEnd) - 60);
        _bid(SECOND_BIDDER, tokenId, SECOND_BIDDER, 1.1 ether);
        require(house.auction(tokenId).endTime == block.timestamp + 300, "anti-snipe extension");
        require(house.refundCredit(FIRST_BIDDER) == 1 ether, "outbid refund recorded");
        require(
            house.totalBidEscrow() == 1.1 ether && house.totalRefundOwed() == 1 ether,
            "separate liabilities"
        );
        require(address(house).balance == house.totalOwed(), "solvent auction");
        vm.prank(FIRST_BIDDER);
        house.withdrawRefund(payable(FIRST_BIDDER));
        require(
            FIRST_BIDDER.balance == 100 ether && house.refundCredit(FIRST_BIDDER) == 0,
            "pull refund delivered"
        );
        require(
            address(house).balance == 1.1 ether && house.totalOwed() == 1.1 ether,
            "winner remains escrowed"
        );
    }

    function testSettlementPaysSplitBeforeReceiverAndCanWithdrawShares() public {
        uint256 tokenId = _create(_authorization());
        AuctionTestReceiver receiver = new AuctionTestReceiver();
        receiver.configure(house, wallet, false);
        _bid(FIRST_BIDDER, tokenId, address(receiver), 1 ether);
        vm.expectRevert();
        house.settle(tokenId);
        vm.warp(house.auction(tokenId).endTime);
        house.settle(tokenId);
        require(core.ownerOf(tokenId) == address(receiver), "NFT delivered");
        require(
            receiver.observedPaid() == 1 ether && receiver.observedProceeds() == 1 ether,
            "paid before receiver callback"
        );
        require(
            receiver.observedEscrow() == 0 && receiver.observedSettled() && !receiver.reentered(),
            "settled effects before callback"
        );
        require(
            house.nativeProceeds(profile) == 1 ether && house.totalOwed() == 0,
            "official sale recorded"
        );
        IStreamSplitWallet(wallet).release(address(0), artist, payable(artist));
        IStreamSplitWallet(wallet).release(address(0), protocol, payable(protocol));
        require(
            artist.balance == 0.9 ether && protocol.balance == 0.1 ether, "90/10 split withdrawals"
        );
        vm.expectRevert();
        house.settle(tokenId);
    }

    function testRejectingRecipientRollsBackSettlementAndWinnerCanRetry() public {
        uint256 tokenId = _create(_authorization());
        AuctionTestReceiver receiver = new AuctionTestReceiver();
        receiver.configure(house, wallet, true);
        _bid(FIRST_BIDDER, tokenId, address(receiver), 1 ether);
        vm.warp(house.auction(tokenId).endTime);
        vm.expectRevert();
        house.settle(tokenId);
        require(
            !house.auction(tokenId).settled && core.ownerOf(tokenId) == address(house),
            "NFT and settlement rollback"
        );
        require(wallet.balance == 0 && house.totalNativeProceeds() == 0, "payment rollback");
        require(
            house.totalBidEscrow() == 1 ether && address(house).balance == 1 ether,
            "escrow preserved"
        );
        vm.prank(SECOND_BIDDER);
        vm.expectRevert();
        house.setDeliveryRecipient(tokenId, SECOND_BIDDER);
        vm.prank(FIRST_BIDDER);
        house.setDeliveryRecipient(tokenId, FIRST_BIDDER);
        house.settle(tokenId);
        require(
            core.ownerOf(tokenId) == FIRST_BIDDER && wallet.balance == 1 ether, "retry succeeds"
        );
    }

    function testNoBidExpiryReturnsNFTAndPreBidArtistCanCancel() public {
        IStreamEnglishAuctionHouse.AuctionAuthorization memory authorization = _authorization();
        uint256 first = _create(authorization);
        vm.prank(artist);
        house.cancel(first);
        require(
            core.ownerOf(first) == artist && house.auction(first).settled,
            "artist cancelled before bid"
        );
        authorization.nonce = keccak256("second");
        uint256 second = _create(authorization);
        vm.warp(authorization.endTime);
        house.settle(second);
        require(core.ownerOf(second) == artist && house.auction(second).settled, "unsold returned");
        require(wallet.balance == 0 && house.totalNativeProceeds() == 0, "no invented proceeds");
    }

    function testRejectingRefundPreservesCreditAndPauseLeavesExitsAvailable() public {
        uint256 tokenId = _create(_authorization());
        _bid(FIRST_BIDDER, tokenId, FIRST_BIDDER, 1 ether);
        _bid(SECOND_BIDDER, tokenId, SECOND_BIDDER, 2 ether);
        RejectAuctionRefund rejecting = new RejectAuctionRefund();
        vm.prank(FIRST_BIDDER);
        vm.expectRevert();
        house.withdrawRefund(payable(address(rejecting)));
        require(
            house.refundCredit(FIRST_BIDDER) == 1 ether && house.totalRefundOwed() == 1 ether,
            "failed refund retained"
        );
        house.setPaused(true);
        vm.prank(FIRST_BIDDER);
        vm.expectRevert();
        house.bid{ value: 3 ether }(tokenId, FIRST_BIDDER);
        vm.prank(FIRST_BIDDER);
        house.withdrawRefund(payable(FIRST_BIDDER));
        vm.warp(house.auction(tokenId).endTime);
        house.settle(tokenId);
        require(
            house.totalOwed() == 0 && address(house).balance == 0 && wallet.balance == 2 ether,
            "paused exits drain liabilities"
        );
    }

    function testSignatureTermsDeadlineAndPolicyCannotBeChanged() public {
        IStreamEnglishAuctionHouse.AuctionAuthorization memory authorization = _authorization();
        (bytes memory platformSig, bytes memory artistSig) = _sign(authorization);
        authorization.reservePrice = 2 ether;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamEnglishAuctionHouse.InvalidAuctionSignature.selector, platform
            )
        );
        house.createAuction(authorization, tokenData, platformSig, artistSig);
        authorization = _authorization();
        vm.expectRevert();
        house.createAuction(authorization, tokenData, platformSig, platformSig);
        authorization.mintPolicyHash = keccak256("stale policy");
        (platformSig, artistSig) = _sign(authorization);
        vm.expectRevert();
        house.createAuction(authorization, tokenData, platformSig, artistSig);
        authorization = _authorization();
        authorization.deadline = uint64(block.timestamp);
        (platformSig, artistSig) = _sign(authorization);
        vm.warp(block.timestamp + 1);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamEnglishAuctionHouse.InvalidAuctionAuthorization.selector)
        );
        house.createAuction(authorization, tokenData, platformSig, artistSig);
        require(
            core.totalSupply() == 0 && manager.nextOperationNonce() == 0,
            "invalid authorizations do not mint"
        );
        require(
            !house.authorizationUsed(artist, authorization.nonce),
            "nonce restored after manager failure"
        );
    }

    function testBidWindowCancellationAndRecipientAuthorization() public {
        IStreamEnglishAuctionHouse.AuctionAuthorization memory authorization = _authorization();
        authorization.startTime += 100;
        uint256 tokenId = _create(authorization);
        vm.prank(FIRST_BIDDER);
        vm.expectRevert();
        house.bid{ value: 1 ether }(tokenId, FIRST_BIDDER);
        vm.warp(authorization.startTime);
        _bid(FIRST_BIDDER, tokenId, FIRST_BIDDER, 1 ether);
        vm.prank(artist);
        vm.expectRevert();
        house.cancel(tokenId);
        vm.prank(artist);
        vm.expectRevert();
        house.setDeliveryRecipient(tokenId, artist);
        vm.warp(authorization.endTime);
        vm.prank(SECOND_BIDDER);
        vm.expectRevert();
        house.bid{ value: 2 ether }(tokenId, SECOND_BIDDER);
        require(house.totalOwed() == 1 ether, "boundary checks preserve winner");
    }

    function testEntropyFailureRollsBackAuctionNonceAndMint() public {
        entropy.setBehavior(true, false);
        IStreamEnglishAuctionHouse.AuctionAuthorization memory authorization = _authorization();
        (bytes memory platformSig, bytes memory artistSig) = _sign(authorization);
        vm.expectRevert();
        house.createAuction(authorization, tokenData, platformSig, artistSig);
        require(core.totalSupply() == 0 && manager.nextOperationNonce() == 0, "mint rolled back");
        require(!house.authorizationUsed(artist, authorization.nonce), "auction nonce rolled back");
        require(
            !manager.isAuthorizationUsed(house.authorizationId(artist, authorization.nonce)),
            "ledger rolled back"
        );
    }

    function testContractArtistUnsoldNFTStaysEscrowedUntilAuthorizedPullClaim() public {
        AuctionContractArtist contractArtist = new AuctionContractArtist();
        _bindFixtureArtist(address(contractArtist));
        house = new StreamEnglishAuctionHouse(core, manager, factory, platform, artistRegistry);
        manager.setPhaseExecutor(1, PHASE, address(house), true);
        IStreamEnglishAuctionHouse.AuctionAuthorization memory authorization = _authorization();
        authorization.artist = address(contractArtist);
        contractArtist.authorize(house.authorizationDigest(authorization));
        uint256 tokenId = _create(authorization);
        vm.warp(authorization.endTime);
        house.settle(tokenId);
        house.settle(tokenId);
        require(core.ownerOf(tokenId) == address(house), "pending NFT stays in escrow");
        require(
            house.auction(tokenId).pendingNoBidNftClaimant == address(contractArtist),
            "artist owns claim"
        );
        require(
            house.auctionStatus(tokenId) == IStreamEnglishAuctionHouse.AuctionStatus.EndedNoBid,
            "pending claim is not settled"
        );
        vm.expectRevert();
        house.claimNoBidNFT(tokenId, FIRST_BIDDER);
        AuctionTestReceiver receiver = new AuctionTestReceiver();
        receiver.configure(house, wallet, true);
        vm.expectRevert();
        contractArtist.claim(house, tokenId, address(receiver));
        require(
            house.auction(tokenId).pendingNoBidNftClaimant == address(contractArtist),
            "failed claim preserved"
        );
        contractArtist.claim(house, tokenId, artist);
        require(
            core.ownerOf(tokenId) == artist
                && house.auction(tokenId).pendingNoBidNftClaimant == address(0),
            "authorized pull completed"
        );
        require(
            house.auctionStatus(tokenId) == IStreamEnglishAuctionHouse.AuctionStatus.SettledNoBid,
            "terminal no-bid status"
        );
    }

    function testFullySignedAuctionCannotAttributeAnotherArtist() public {
        IStreamEnglishAuctionHouse.AuctionAuthorization memory authorization = _authorization();
        authorization.artist = vm.addr(999);
        bytes32 digest = house.authorizationDigest(authorization);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        bytes memory platformSignature = abi.encodePacked(r, s, v);
        (v, r, s) = vm.sign(999, digest);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionArtistRegistry.ArtistRegistryArtistMismatch.selector,
                1,
                artist,
                authorization.artist
            )
        );
        house.createAuction(authorization, tokenData, platformSignature, abi.encodePacked(r, s, v));
        require(
            core.totalSupply() == 0 && manager.nextOperationNonce() == 0,
            "no unauthorized attribution minted"
        );
    }

    function testCanonicalStatusAndInterfacesExposeCustodyLifecycle() public {
        require(
            house.supportsInterface(type(IStreamEnglishAuctionHouse).interfaceId),
            "auction interface"
        );
        require(house.supportsInterface(type(IERC165).interfaceId), "ERC165 interface");
        require(
            !house.supportsInterface(0xffffffff) && !house.supportsInterface(0x12345678),
            "strict ERC165"
        );
        require(house.auctionStatus(999) == IStreamEnglishAuctionHouse.AuctionStatus.None, "absent");
        IStreamEnglishAuctionHouse.AuctionAuthorization memory authorization = _authorization();
        authorization.startTime += 100;
        uint256 tokenId = _create(authorization);
        require(
            house.auctionStatus(tokenId) == IStreamEnglishAuctionHouse.AuctionStatus.Created
                && core.ownerOf(tokenId) == address(house),
            "created and custodied"
        );
        vm.warp(authorization.startTime);
        require(
            house.auctionStatus(tokenId) == IStreamEnglishAuctionHouse.AuctionStatus.Active,
            "active"
        );
        _bid(FIRST_BIDDER, tokenId, FIRST_BIDDER, 1 ether);
        vm.warp(authorization.endTime);
        require(
            house.auctionStatus(tokenId) == IStreamEnglishAuctionHouse.AuctionStatus.EndedWithBid,
            "ended with bid"
        );
        house.settle(tokenId);
        require(
            house.auctionStatus(tokenId) == IStreamEnglishAuctionHouse.AuctionStatus.SettledWithBid,
            "settled with bid"
        );
        authorization = _authorization();
        authorization.nonce = keccak256("cancelled");
        tokenId = _create(authorization);
        vm.prank(artist);
        house.cancel(tokenId);
        require(
            house.auctionStatus(tokenId) == IStreamEnglishAuctionHouse.AuctionStatus.Cancelled,
            "cancelled distinction stored"
        );
    }

    function _authorization()
        private
        view
        returns (IStreamEnglishAuctionHouse.AuctionAuthorization memory item)
    {
        item = IStreamEnglishAuctionHouse.AuctionAuthorization({
            collectionId: 1,
            phaseId: PHASE,
            artist: artist,
            profileId: profile,
            tokenDataHash: keccak256(tokenData),
            mintCommitment: keccak256("auction commitment"),
            mintPolicyHash: manager.phasePolicyHash(1, PHASE),
            reservePrice: 1 ether,
            startTime: uint64(block.timestamp),
            endTime: uint64(block.timestamp + 1 hours),
            extensionWindow: 300,
            minBidIncrementBps: 500,
            nonce: keccak256("auction-one"),
            deadline: uint64(block.timestamp + 1 hours),
            signerEpoch: house.signerEpoch()
        });
    }

    function _sign(IStreamEnglishAuctionHouse.AuctionAuthorization memory authorization)
        private
        returns (bytes memory platformSig, bytes memory artistSig)
    {
        bytes32 digest = house.authorizationDigest(authorization);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        platformSig = abi.encodePacked(r, s, v);
        (v, r, s) = vm.sign(ARTIST_KEY, digest);
        artistSig = abi.encodePacked(r, s, v);
    }

    function _create(IStreamEnglishAuctionHouse.AuctionAuthorization memory authorization)
        private
        returns (uint256)
    {
        (bytes memory platformSig, bytes memory artistSig) = _sign(authorization);
        return house.createAuction(authorization, tokenData, platformSig, artistSig);
    }

    function _bid(address bidder, uint256 tokenId, address recipient, uint256 amount) private {
        vm.prank(bidder);
        house.bid{ value: amount }(tokenId, recipient);
    }
}
