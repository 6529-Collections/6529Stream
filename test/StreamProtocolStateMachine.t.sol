// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./helpers/Assertions.sol";
import "./helpers/ProtocolStateMachine.sol";

contract StreamProtocolStateMachineTest is ProtocolStateMachine {
    using Assertions for bool;
    using Assertions for bytes32;
    using Assertions for uint256;

    function setUp() public {
        _deployProtocolStateMachine();
    }

    function testProtocolStateMachineExecutesDeterministicSmokeSequence() public {
        FixedPriceMintResult memory fixedMint =
            _mintProtocolFixedPriceDrop(4 ether, "fixed-price-state-machine");
        _assertProtocolFixedPriceCredits(fixedMint.price);

        AuctionMintResult memory auctionMint =
            _mintProtocolAuctionDrop(5 ether, "auction-state-machine");
        _bidProtocolAuction(auctionMint.tokenId, PROTOCOL_FIRST_BIDDER, 5 ether);
        _bidProtocolAuction(auctionMint.tokenId, PROTOCOL_SECOND_BIDDER, 6 ether);
        protocolAuctions.auctionBidderCredits(PROTOCOL_FIRST_BIDDER)
            .assertEq(5 ether, "outbid credit");

        _settleProtocolAuctionWithBid(auctionMint.tokenId, PROTOCOL_SECOND_BIDDER);
        _assertProtocolAuctionCredits(6 ether);

        _finalizeProtocolTokenMetadata(fixedMint.tokenId, 101);
        _finalizeProtocolTokenMetadata(auctionMint.tokenId, 202);
        _assertProtocolMetadataPauseBlocksMutation(fixedMint.tokenId);
        _mutateProtocolTokenMetadata(fixedMint.tokenId, "fixed-price-state-machine-updated");

        bytes32 cancelledDropId = _exerciseProtocolPauseSignerAndCancellation();
        protocolDeployed.drops.isDropCancelled(cancelledDropId).assertTrue("cancelled drop");
        protocolModel.signerRotated.assertTrue("signer not rotated");

        _withdrawProtocolFixedPriceCredit(PROTOCOL_POSTER);
        _withdrawProtocolFixedPriceCredit(PROTOCOL_PAYOUT);
        _withdrawProtocolBidderCredit(PROTOCOL_FIRST_BIDDER);
        _withdrawProtocolAuctionProceedsCredit(PROTOCOL_POSTER);
        _withdrawProtocolAuctionProceedsCredit(PROTOCOL_PAYOUT);
        _withdrawProtocolAuctionProceedsCredit(PROTOCOL_CURATORS_POOL);
        _assertProtocolAccountingCoversOwed();

        bytes32 freezeManifest = _freezeProtocolCollection();
        (freezeManifest == bytes32(0)).assertFalse("empty freeze manifest");
        protocolModel.collectionFrozen.assertTrue("collection not frozen");
        protocolModel.finalizedTokens.assertEq(2, "finalized token count");
        protocolDeployed.core.totalSupply().assertEq(2, "live supply");
    }
}
