// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/AuctionContract.sol";
import "../smart-contracts/RandomizerRNG.sol";
import "../smart-contracts/StreamAdmins.sol";
import "../smart-contracts/StreamDrops.sol";
import "./helpers/Assertions.sol";
import "./helpers/DropAuthTestHelper.sol";
import "./helpers/StreamFixture.sol";

contract StreamPauseControlsTest is DropAuthTestHelper, StreamFixture {
    using Assertions for address;
    using Assertions for bool;
    using Assertions for uint256;

    event PauseUpdated(
        bytes32 indexed domain, bool paused, address indexed admin, bytes32 indexed reason
    );

    address private constant POSTER = address(0x1001);
    address private constant RECIPIENT = address(0x5005);
    address private constant PAYOUT = address(0x2002);
    address private constant CURATORS_POOL = address(0x3003);
    address private constant WITHDRAW_RECIPIENT = address(0x4004);
    address private constant PAUSE_GUARDIAN = address(0x6006);
    address private constant UNPAUSE_ADMIN = address(0x7007);
    address private constant CORE = address(0xC0DE);
    uint256 private constant TOKEN_ID = 10_000_000_000;
    bytes32 private constant REASON = keccak256("pause-regression");

    function testPauseGuardianCanPauseButCannotUnpause() public {
        StreamAdmins admins = new StreamAdmins(address(this));
        bytes32 domain = admins.PAUSE_DOMAIN_MINT();

        admins.registerPauseGuardian(PAUSE_GUARDIAN, true);
        admins.registerUnpauseAdmin(UNPAUSE_ADMIN, true);

        vm.expectEmit(true, true, true, true);
        emit PauseUpdated(domain, true, PAUSE_GUARDIAN, REASON);
        vm.prank(PAUSE_GUARDIAN);
        admins.setPaused(domain, true, REASON);

        admins.isPaused(domain).assertTrue("domain not paused");

        vm.prank(PAUSE_GUARDIAN);
        (bool guardianUnpaused,) = address(admins)
            .call(abi.encodeWithSelector(admins.setPaused.selector, domain, false, REASON));
        guardianUnpaused.assertFalse("guardian unpaused domain");
        admins.isPaused(domain).assertTrue("guardian changed pause state");

        vm.prank(UNPAUSE_ADMIN);
        (bool unpauseAdminPaused,) = address(admins)
            .call(abi.encodeWithSelector(admins.setPaused.selector, domain, true, REASON));
        unpauseAdminPaused.assertFalse("unpause admin paused domain");

        vm.prank(UNPAUSE_ADMIN);
        admins.setPaused(domain, false, REASON);

        admins.isPaused(domain).assertFalse("domain still paused");
    }

    function testDropExecutionPauseBlocksSignedDropsUntilUnpaused() public {
        DeployedStream memory deployed =
            deployStreamWithSigner(PAYOUT, CURATORS_POOL, signerAddress());
        StreamDrops.DropAuthorization memory authorization = buildFixedPriceAuthorization(
            deployed.drops,
            POSTER,
            RECIPIENT,
            address(0),
            "data",
            1,
            0,
            1,
            2,
            block.timestamp + 1 days
        );
        bytes memory signature = signAuthorization(deployed.drops, authorization);

        _setPaused(deployed.admins, deployed.admins.PAUSE_DOMAIN_DROP_EXECUTION(), true);

        (bool pausedMint,) = address(deployed.drops)
            .call(
                abi.encodeWithSelector(
                    deployed.drops.mintDrop.selector, authorization, "data", signature
                )
            );

        pausedMint.assertFalse("drop execution succeeded while paused");
        deployed.drops.isDropConsumed(authorization.dropId).assertFalse("paused drop consumed");
        deployed.core.totalSupply().assertEq(0, "paused drop minted");

        _setPaused(deployed.admins, deployed.admins.PAUSE_DOMAIN_DROP_EXECUTION(), false);
        deployed.drops.mintDrop(authorization, "data", signature);

        deployed.drops.isDropConsumed(authorization.dropId).assertTrue("drop not consumed");
        deployed.core.ownerOf(TOKEN_ID).assertEq(RECIPIENT, "recipient changed");
    }

    function testDropExecutionPauseSupportsSignerCompromiseResponse() public {
        DeployedStream memory deployed =
            deployStreamWithSigner(PAYOUT, CURATORS_POOL, signerAddress());
        StreamDrops.DropAuthorization memory authorization = buildFixedPriceAuthorization(
            deployed.drops,
            POSTER,
            RECIPIENT,
            address(0),
            "data",
            1,
            0,
            9,
            10,
            block.timestamp + 1 days
        );
        bytes memory signature = signAuthorization(deployed.drops, authorization);

        _setPaused(deployed.admins, deployed.admins.PAUSE_DOMAIN_DROP_EXECUTION(), true);
        deployed.drops.incrementSignerEpoch();
        deployed.drops.cancelDrop(authorization.dropId);
        _setPaused(deployed.admins, deployed.admins.PAUSE_DOMAIN_DROP_EXECUTION(), false);

        (bool staleOrCancelledMint,) = address(deployed.drops)
            .call(
                abi.encodeWithSelector(
                    deployed.drops.mintDrop.selector, authorization, "data", signature
                )
            );

        staleOrCancelledMint.assertFalse("stale cancelled drop executed");
        deployed.drops.isDropCancelled(authorization.dropId).assertTrue("drop not cancelled");
        deployed.drops.isDropConsumed(authorization.dropId).assertFalse("drop consumed");
        deployed.core.totalSupply().assertEq(0, "compromised drop minted");
    }

    function testMintPauseBlocksMinterPathWithoutConsumingDrop() public {
        DeployedStream memory deployed =
            deployStreamWithSigner(PAYOUT, CURATORS_POOL, signerAddress());
        StreamDrops.DropAuthorization memory authorization = buildFixedPriceAuthorization(
            deployed.drops,
            POSTER,
            RECIPIENT,
            address(0),
            "data",
            1,
            0,
            3,
            4,
            block.timestamp + 1 days
        );
        bytes memory signature = signAuthorization(deployed.drops, authorization);

        _setPaused(deployed.admins, deployed.admins.PAUSE_DOMAIN_MINT(), true);

        (bool pausedMint,) = address(deployed.drops)
            .call(
                abi.encodeWithSelector(
                    deployed.drops.mintDrop.selector, authorization, "data", signature
                )
            );

        pausedMint.assertFalse("mint succeeded while paused");
        deployed.drops.isDropConsumed(authorization.dropId).assertFalse("failed mint consumed drop");
        deployed.core.totalSupply().assertEq(0, "paused mint changed supply");

        _setPaused(deployed.admins, deployed.admins.PAUSE_DOMAIN_MINT(), false);
        deployed.drops.mintDrop(authorization, "data", signature);

        deployed.core.ownerOf(TOKEN_ID).assertEq(RECIPIENT, "recipient changed");
    }

    function testAuctionBidPauseBlocksOnlyNewBids() public {
        AuctionSetup memory setup = _createAuctionDrop(1 days, 1 ether);

        _setPaused(setup.deployed.admins, setup.deployed.admins.PAUSE_DOMAIN_AUCTION_BID(), true);

        (bool pausedBid,) = address(setup.auctions).call{ value: 1 ether }(
            abi.encodeWithSelector(setup.auctions.participateToAuction.selector, setup.tokenId)
        );

        pausedBid.assertFalse("bid succeeded while paused");
        setup.auctions.auctionHighestBid(setup.tokenId).assertEq(0, "paused bid recorded");

        _setPaused(setup.deployed.admins, setup.deployed.admins.PAUSE_DOMAIN_AUCTION_BID(), false);
        setup.auctions.participateToAuction{ value: 1 ether }(setup.tokenId);

        setup.auctions.auctionHighestBid(setup.tokenId).assertEq(1 ether, "bid not recorded");
    }

    function testAuctionSettlementPauseBlocksEndedAuctionSettlementUntilUnpaused() public {
        AuctionSetup memory setup = _createAuctionDrop(1 days, 1 ether);
        vm.warp(setup.auctionEndTime + 1);

        _setPaused(
            setup.deployed.admins, setup.deployed.admins.PAUSE_DOMAIN_AUCTION_SETTLEMENT(), true
        );

        (bool pausedSettlement,) = address(setup.auctions)
            .call(abi.encodeWithSelector(setup.auctions.claimAuction.selector, setup.tokenId));

        pausedSettlement.assertFalse("settlement succeeded while paused");
        uint256(StreamAuctions.AuctionStatus.EndedNoBid)
            .assertEq(
                uint256(setup.auctions.retrieveAuctionStatus(setup.tokenId)), "status changed"
            );

        _setPaused(
            setup.deployed.admins, setup.deployed.admins.PAUSE_DOMAIN_AUCTION_SETTLEMENT(), false
        );
        setup.auctions.claimAuction(setup.tokenId);

        uint256(StreamAuctions.AuctionStatus.SettledNoBid)
            .assertEq(uint256(setup.auctions.retrieveAuctionStatus(setup.tokenId)), "not settled");
        setup.deployed.core.ownerOf(setup.tokenId).assertEq(POSTER, "poster did not receive token");
    }

    function testMetadataMutationPauseBlocksMutableMetadataOnly() public {
        DeployedStream memory deployed = deployStream(PAYOUT, CURATORS_POOL);

        _setPaused(deployed.admins, deployed.admins.PAUSE_DOMAIN_METADATA_MUTATION(), true);

        (bool pausedMetadata,) = address(deployed.core)
            .call(abi.encodeWithSelector(deployed.core.changeMetadataView.selector, 1, true));

        pausedMetadata.assertFalse("metadata changed while paused");
        deployed.core.onchainMetadata(1).assertFalse("metadata flag changed");

        _setPaused(deployed.admins, deployed.admins.PAUSE_DOMAIN_METADATA_MUTATION(), false);
        deployed.core.changeMetadataView(1, true);

        deployed.core.onchainMetadata(1).assertTrue("metadata flag not changed");
    }

    function testRandomnessRequestPauseBlocksNewRequestsUntilUnpaused() public {
        StreamAdmins admins = new StreamAdmins(address(this));
        PauseMockArrngController controller = new PauseMockArrngController();
        NextGenRandomizerRNG randomizer =
            new NextGenRandomizerRNG(CORE, address(admins), address(controller));

        _setPaused(admins, admins.PAUSE_DOMAIN_RANDOMNESS_REQUEST(), true);

        vm.prank(CORE);
        (bool pausedRequest,) = address(randomizer)
            .call(abi.encodeWithSelector(randomizer.calculateTokenHash.selector, 1, TOKEN_ID, 123));

        pausedRequest.assertFalse("randomness request succeeded while paused");
        randomizer.tokenToRequest(TOKEN_ID).assertEq(0, "paused request recorded");

        _setPaused(admins, admins.PAUSE_DOMAIN_RANDOMNESS_REQUEST(), false);
        vm.prank(CORE);
        randomizer.calculateTokenHash(1, TOKEN_ID, 123);

        randomizer.tokenToRequest(TOKEN_ID).assertEq(1, "request not recorded");
        controller.lastRefundAddress().assertEq(address(randomizer), "refund address changed");
    }

    function testUserWithdrawalsRemainAvailableDuringOperationalPauses() public {
        DeployedStream memory deployed =
            deployStreamWithSigner(PAYOUT, CURATORS_POOL, signerAddress());
        vm.deal(address(this), 10 ether);
        StreamDrops.DropAuthorization memory authorization = buildFixedPriceAuthorization(
            deployed.drops,
            POSTER,
            RECIPIENT,
            address(this),
            "data",
            1,
            4 ether,
            5,
            6,
            block.timestamp + 1 days
        );
        bytes memory signature = signAuthorization(deployed.drops, authorization);
        deployed.drops.mintDrop{ value: 4 ether }(authorization, "data", signature);

        _pauseAllOperationalDomains(deployed.admins);
        uint256 recipientBalanceBefore = WITHDRAW_RECIPIENT.balance;

        vm.prank(POSTER);
        deployed.drops.withdrawFixedPriceCreditTo(payable(WITHDRAW_RECIPIENT));

        WITHDRAW_RECIPIENT.balance
            .assertEq(recipientBalanceBefore + 2 ether, "withdrawal was paused");
        deployed.drops.fixedPricePosterCredits(POSTER).assertEq(0, "poster credit not cleared");
    }

    function _createAuctionDrop(uint256 duration, uint256 reservePrice)
        private
        returns (AuctionSetup memory setup)
    {
        setup.deployed = deployStreamWithSigner(PAYOUT, CURATORS_POOL, signerAddress());
        setup.auctions = new StreamAuctions(
            address(setup.deployed.minter),
            address(setup.deployed.core),
            address(setup.deployed.admins),
            address(setup.deployed.drops),
            PAYOUT,
            CURATORS_POOL
        );
        setup.deployed.drops.updateAuctionContract(address(setup.auctions));
        setup.auctionEndTime = block.timestamp + duration;

        StreamDrops.DropAuthorization memory authorization = buildAuctionAuthorization(
            setup.deployed.drops,
            POSTER,
            address(0),
            "auction-data",
            1,
            reservePrice,
            setup.auctionEndTime,
            7,
            8,
            block.timestamp + 1 days
        );
        setup.deployed.drops
            .mintDrop(
                authorization,
                "auction-data",
                signAuthorization(setup.deployed.drops, authorization)
            );
        setup.tokenId = TOKEN_ID;
    }

    function _pauseAllOperationalDomains(StreamAdmins admins) private {
        _setPaused(admins, admins.PAUSE_DOMAIN_DROP_EXECUTION(), true);
        _setPaused(admins, admins.PAUSE_DOMAIN_MINT(), true);
        _setPaused(admins, admins.PAUSE_DOMAIN_AUCTION_BID(), true);
        _setPaused(admins, admins.PAUSE_DOMAIN_AUCTION_SETTLEMENT(), true);
        _setPaused(admins, admins.PAUSE_DOMAIN_METADATA_MUTATION(), true);
        _setPaused(admins, admins.PAUSE_DOMAIN_RANDOMNESS_REQUEST(), true);
    }

    function _setPaused(StreamAdmins admins, bytes32 domain, bool paused) private {
        admins.setPaused(domain, paused, REASON);
    }
}

struct AuctionSetup {
    StreamFixture.DeployedStream deployed;
    StreamAuctions auctions;
    uint256 tokenId;
    uint256 auctionEndTime;
}

contract PauseMockArrngController {
    uint256 public nextRequestId = 1;
    address public lastRefundAddress;

    function requestRandomWords(uint256, address refundAddress)
        external
        returns (uint256 requestId)
    {
        require(refundAddress != address(0), "Zero refund");
        lastRefundAddress = refundAddress;
        requestId = nextRequestId;
        nextRequestId++;
    }
}
