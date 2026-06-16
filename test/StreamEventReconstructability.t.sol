// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/AuctionContract.sol";
import "../smart-contracts/StreamCore.sol";
import "../smart-contracts/StreamDrops.sol";
import "../smart-contracts/StreamMinter.sol";
import "./helpers/Assertions.sol";
import "./helpers/DropAuthTestHelper.sol";
import "./helpers/StreamFixture.sol";

contract StreamEventReconstructabilityTest is DropAuthTestHelper, StreamFixture {
    using Assertions for address;
    using Assertions for bool;
    using Assertions for bytes32;
    using Assertions for uint256;

    bytes32 private constant DROP_AUTHORIZATION_CONSUMED_TOPIC = keccak256(
        "DropAuthorizationConsumed(bytes32,address,address,address,address,uint256,uint8,bytes32,uint256,uint256)"
    );
    bytes32 private constant FIXED_PRICE_CREDIT_CREATED_TOPIC =
        keccak256("FixedPriceCreditCreated(address,bytes32,uint8,uint256)");
    bytes32 private constant TRANSFER_TOPIC = keccak256("Transfer(address,address,uint256)");
    bytes32 private constant MINTER_TOKENS_MINTED_TOPIC =
        keccak256("MinterTokensMinted(uint256,uint256,address,uint256,uint256)");
    bytes32 private constant MINTER_AUCTION_MINTED_TOPIC =
        keccak256("MinterAuctionMinted(uint256,uint256,address,uint256)");
    bytes32 private constant COLLECTION_PHASES_UPDATED_TOPIC =
        keccak256("CollectionPhasesUpdated(uint256,uint256,uint256,uint256,uint256,address)");
    bytes32 private constant MINTER_CONTRACT_REFERENCE_UPDATED_TOPIC =
        keccak256("MinterContractReferenceUpdated(uint8,address,address,address)");
    bytes32 private constant AUCTION_REGISTERED_TOPIC =
        keccak256("AuctionRegistered(bytes32,uint256,uint256,address,address,uint256,uint256)");
    bytes32 private constant AUCTION_CUSTODY_CONFIRMED_TOPIC =
        keccak256("AuctionCustodyConfirmed(uint256,address)");
    bytes32 private constant AUCTION_STATUS_CHANGED_TOPIC =
        keccak256("AuctionStatusChanged(uint256,uint8)");
    bytes32 private constant AUCTION_EXTENDED_TOPIC =
        keccak256("AuctionExtended(uint256,uint256,uint256)");
    bytes32 private constant PARTICIPATE_TOPIC = keccak256("Participate(address,uint256,uint256)");
    bytes32 private constant OUTBID_CREDIT_CREATED_TOPIC =
        keccak256("OutbidCreditCreated(address,uint256,uint256)");
    bytes32 private constant AUCTION_PROCEEDS_CREDIT_CREATED_TOPIC =
        keccak256("AuctionProceedsCreditCreated(address,uint256,uint8,uint256)");
    bytes32 private constant CLAIM_AUCTION_TOPIC = keccak256("ClaimAuction(uint256,uint256)");

    uint256 private constant COLLECTION_ID = 1;
    uint256 private constant FIRST_TOKEN_ID = 10_000_000_000;
    address private constant PAYOUT = address(0x2002);
    address private constant CURATORS_POOL = address(0x3003);
    address private constant POSTER = address(0x4004);
    address private constant RECIPIENT = address(0x5005);
    address private constant PAYER = address(0x6006);
    address private constant BIDDER = address(0x7007);
    address private constant SECOND_BIDDER = address(0x8008);
    uint256 private constant FIXED_PRICE = 4 ether;
    uint256 private constant RESERVE_PRICE = 5 ether;
    uint256 private constant SECOND_BID = 6 ether;

    struct FixedPriceReadModel {
        bool consumed;
        bool transferMinted;
        bool minterRange;
        bytes32 dropId;
        address signer;
        address poster;
        address recipient;
        address payer;
        uint256 collectionId;
        uint256 saleMode;
        bytes32 tokenDataHash;
        uint256 deadline;
        uint256 signerEpoch;
        uint256 tokenId;
        uint256 lastTokenId;
        uint256 quantity;
        uint256 posterCredit;
        uint256 protocolCredit;
        uint256 curatorReserveCredit;
        uint256 fixedPriceCreditEvents;
    }

    struct AuctionReadModel {
        bool consumed;
        bool bridgeMinted;
        bool registered;
        bool custodyConfirmed;
        bool active;
        bool settledWithBid;
        bool claimed;
        bytes32 dropId;
        address poster;
        address custody;
        uint256 tokenId;
        uint256 collectionId;
        uint256 reservePrice;
        uint256 bridgeEndTime;
        uint256 registeredEndTime;
        uint256 extendedEndTime;
        address highestBidder;
        uint256 highestBid;
        address outbidBidder;
        uint256 outbidCredit;
        uint256 posterProceeds;
        uint256 protocolProceeds;
        uint256 curatorProceeds;
    }

    struct AdminReadModel {
        bool phaseUpdated;
        uint256 collectionId;
        uint256 oldStart;
        uint256 oldEnd;
        uint256 newStart;
        uint256 newEnd;
        address phaseAdmin;
        uint256 referenceUpdates;
        uint256 option;
        address oldContract;
        address newContract;
        address referenceAdmin;
    }

    function testFixedPriceDropLogsReconstructMintAndCredits() public {
        DeployedStream memory deployed =
            deployStreamWithSigner(PAYOUT, CURATORS_POOL, signerAddress());
        string memory tokenData = "fixed-price-reconstructable";
        StreamDrops.DropAuthorization memory authorization = buildFixedPriceAuthorization(
            deployed.drops,
            POSTER,
            RECIPIENT,
            PAYER,
            tokenData,
            COLLECTION_ID,
            FIXED_PRICE,
            101,
            202,
            block.timestamp + 1 days
        );
        bytes memory signature = signAuthorization(deployed.drops, authorization);

        vm.deal(PAYER, FIXED_PRICE);
        vm.recordLogs();
        vm.prank(PAYER);
        deployed.drops.mintDrop{ value: FIXED_PRICE }(authorization, tokenData, signature);
        FixedPriceReadModel memory model = _reconstructFixedPrice(vm.getRecordedLogs(), deployed);

        model.consumed.assertTrue("drop consumed event");
        model.transferMinted.assertTrue("erc721 mint transfer");
        model.minterRange.assertTrue("minter range event");
        model.dropId.assertEq(authorization.dropId, "drop id");
        model.signer.assertEq(signerAddress(), "signer");
        model.poster.assertEq(POSTER, "poster");
        model.recipient.assertEq(RECIPIENT, "recipient");
        model.payer.assertEq(PAYER, "payer");
        model.collectionId.assertEq(COLLECTION_ID, "collection");
        model.saleMode.assertEq(deployed.drops.SALE_MODE_FIXED_PRICE(), "sale mode");
        model.tokenDataHash.assertEq(keccak256(bytes(tokenData)), "token data hash");
        model.deadline.assertEq(authorization.deadline, "deadline");
        model.signerEpoch.assertEq(authorization.signerEpoch, "signer epoch");
        model.tokenId.assertEq(FIRST_TOKEN_ID, "token id");
        model.lastTokenId.assertEq(FIRST_TOKEN_ID, "last token id");
        model.quantity.assertEq(1, "quantity");
        model.posterCredit.assertEq(2 ether, "poster credit");
        model.protocolCredit.assertEq(1 ether, "protocol credit");
        model.curatorReserveCredit.assertEq(1 ether, "curator reserve");
        model.fixedPriceCreditEvents.assertEq(3, "credit event count");

        deployed.core.ownerOf(FIRST_TOKEN_ID).assertEq(RECIPIENT, "owner read");
        deployed.drops.retrieveTokenID(authorization.dropId).assertEq(FIRST_TOKEN_ID, "drop token");
        deployed.drops.isDropConsumed(authorization.dropId).assertTrue("consumed read");
        deployed.drops.fixedPricePosterCredits(POSTER).assertEq(2 ether, "poster owed");
        deployed.drops.fixedPriceProtocolCredits(PAYOUT).assertEq(1 ether, "protocol owed");
        deployed.drops.fixedPriceCuratorReserveCredits(CURATORS_POOL)
            .assertEq(1 ether, "curator owed");
        deployed.drops.totalFixedPriceOwed().assertEq(FIXED_PRICE, "total owed");
    }

    function testAuctionLogsReconstructRegistrationBidExtensionAndSettlement() public {
        DeployedStream memory deployed =
            deployStreamWithSigner(PAYOUT, CURATORS_POOL, signerAddress());
        StreamAuctions auctions = new StreamAuctions(
            address(deployed.minter),
            address(deployed.core),
            address(deployed.admins),
            address(deployed.drops),
            PAYOUT,
            CURATORS_POOL
        );
        deployed.drops.updateAuctionContract(address(auctions));
        uint256 auctionEndTime = block.timestamp + 601;
        string memory tokenData = "auction-reconstructable";
        StreamDrops.DropAuthorization memory authorization = buildAuctionAuthorization(
            deployed.drops,
            POSTER,
            address(0),
            tokenData,
            COLLECTION_ID,
            RESERVE_PRICE,
            auctionEndTime,
            303,
            404,
            block.timestamp + 1 days
        );

        vm.deal(BIDDER, RESERVE_PRICE);
        vm.deal(SECOND_BIDDER, SECOND_BID);
        vm.recordLogs();
        deployed.drops
            .mintDrop(authorization, tokenData, signAuthorization(deployed.drops, authorization));
        vm.warp(auctionEndTime - 299);
        vm.prank(BIDDER);
        auctions.participateToAuction{ value: RESERVE_PRICE }(FIRST_TOKEN_ID);
        vm.prank(SECOND_BIDDER);
        auctions.participateToAuction{ value: SECOND_BID }(FIRST_TOKEN_ID);
        vm.warp(auctionEndTime + 301);
        auctions.claimAuction(FIRST_TOKEN_ID);
        AuctionReadModel memory model =
            _reconstructAuction(vm.getRecordedLogs(), deployed, address(auctions));

        model.consumed.assertTrue("drop consumed");
        model.bridgeMinted.assertTrue("bridge minted");
        model.registered.assertTrue("auction registered");
        model.custodyConfirmed.assertTrue("custody confirmed");
        model.active.assertTrue("active status");
        model.settledWithBid.assertTrue("settled status");
        model.claimed.assertTrue("claim event");
        model.dropId.assertEq(authorization.dropId, "drop id");
        model.poster.assertEq(POSTER, "poster");
        model.custody.assertEq(address(auctions), "custody");
        model.tokenId.assertEq(FIRST_TOKEN_ID, "token id");
        model.collectionId.assertEq(COLLECTION_ID, "collection");
        model.reservePrice.assertEq(RESERVE_PRICE, "reserve");
        model.bridgeEndTime.assertEq(auctionEndTime, "bridge end");
        model.registeredEndTime.assertEq(auctionEndTime, "registered end");
        model.extendedEndTime.assertEq(auctionEndTime + 300, "extended end");
        model.highestBidder.assertEq(SECOND_BIDDER, "highest bidder");
        model.highestBid.assertEq(SECOND_BID, "highest bid");
        model.outbidBidder.assertEq(BIDDER, "outbid bidder");
        model.outbidCredit.assertEq(RESERVE_PRICE, "outbid credit");
        model.posterProceeds.assertEq(3 ether, "poster proceeds");
        model.protocolProceeds.assertEq(15e17, "protocol proceeds");
        model.curatorProceeds.assertEq(15e17, "curator proceeds");

        auctions.retrieveAuctionEndTime(FIRST_TOKEN_ID)
            .assertEq(auctionEndTime + 300, "authoritative end");
        deployed.minter.getAuctionEndTime(FIRST_TOKEN_ID).assertEq(auctionEndTime, "bridge end");
        uint256 status = uint256(auctions.retrieveAuctionStatus(FIRST_TOKEN_ID));
        status.assertEq(uint256(StreamAuctions.AuctionStatus.SettledWithBid), "status read");
        auctions.auctionHighestBid(FIRST_TOKEN_ID).assertEq(SECOND_BID, "bid read");
        auctions.auctionHighestBidder(FIRST_TOKEN_ID).assertEq(SECOND_BIDDER, "bidder read");
        auctions.auctionBidderCredits(BIDDER).assertEq(RESERVE_PRICE, "bidder credit read");
        auctions.totalAuctionBidEscrow().assertEq(0, "escrow cleared");
        auctions.totalProceedsOwed().assertEq(SECOND_BID, "proceeds owed");
        deployed.core.ownerOf(FIRST_TOKEN_ID).assertEq(SECOND_BIDDER, "owner read");
    }

    function testAdminBridgeLogsReconstructPhaseAndReferenceUpdates() public {
        DeployedStream memory deployed = deployStream(PAYOUT, CURATORS_POOL);
        StreamCore newCore = new StreamCore(
            "6529 Stream Replacement",
            "STREAM2",
            address(deployed.admins),
            address(deployed.dependencyRegistry)
        );
        (uint256 oldStart, uint256 oldEnd) = deployed.minter.retrieveCollectionPhases(COLLECTION_ID);
        uint256 newStart = block.timestamp + 2 hours;
        uint256 newEnd = block.timestamp + 20 days;

        vm.recordLogs();
        deployed.minter.setCollectionPhases(COLLECTION_ID, newStart, newEnd);
        deployed.minter.updateContracts(99, address(0xBADC0DE));
        deployed.minter.updateContracts(1, address(deployed.core));
        deployed.minter.updateContracts(1, address(newCore));
        AdminReadModel memory model =
            _reconstructAdminBridge(vm.getRecordedLogs(), address(deployed.minter));

        model.phaseUpdated.assertTrue("phase event");
        model.collectionId.assertEq(COLLECTION_ID, "phase collection");
        model.oldStart.assertEq(oldStart, "old start");
        model.oldEnd.assertEq(oldEnd, "old end");
        model.newStart.assertEq(newStart, "new start");
        model.newEnd.assertEq(newEnd, "new end");
        model.phaseAdmin.assertEq(address(this), "phase admin");
        model.referenceUpdates.assertEq(1, "reference update count");
        model.option.assertEq(1, "reference option");
        model.oldContract.assertEq(address(deployed.core), "old core");
        model.newContract.assertEq(address(newCore), "new core");
        model.referenceAdmin.assertEq(address(this), "reference admin");

        (uint256 actualStart, uint256 actualEnd) =
            deployed.minter.retrieveCollectionPhases(COLLECTION_ID);
        actualStart.assertEq(newStart, "phase start read");
        actualEnd.assertEq(newEnd, "phase end read");
        address(deployed.minter.gencore()).assertEq(address(newCore), "core reference read");
    }

    function _reconstructFixedPrice(Vm.Log[] memory logs, DeployedStream memory deployed)
        private
        pure
        returns (FixedPriceReadModel memory model)
    {
        for (uint256 i; i < logs.length; i++) {
            Vm.Log memory log = logs[i];
            if (log.emitter == address(deployed.drops)) {
                if (log.topics[0] == DROP_AUTHORIZATION_CONSUMED_TOPIC) {
                    model.consumed = true;
                    model.dropId = log.topics[1];
                    model.signer = _topicAddress(log.topics[2]);
                    model.poster = _topicAddress(log.topics[3]);
                    (
                        address recipient,
                        address payer,
                        uint256 collectionId,
                        uint8 saleMode,
                        bytes32 tokenDataHash,
                        uint256 deadline,
                        uint256 signerEpoch
                    ) = abi.decode(
                        log.data, (address, address, uint256, uint8, bytes32, uint256, uint256)
                    );
                    model.recipient = recipient;
                    model.payer = payer;
                    model.collectionId = collectionId;
                    model.saleMode = saleMode;
                    model.tokenDataHash = tokenDataHash;
                    model.deadline = deadline;
                    model.signerEpoch = signerEpoch;
                } else if (log.topics[0] == FIXED_PRICE_CREDIT_CREATED_TOPIC) {
                    model.fixedPriceCreditEvents++;
                    address account = _topicAddress(log.topics[1]);
                    uint256 creditType = uint256(log.topics[3]);
                    uint256 funds = abi.decode(log.data, (uint256));
                    if (account == model.poster && creditType == 0) {
                        model.posterCredit += funds;
                    } else if (account == PAYOUT && creditType == 1) {
                        model.protocolCredit += funds;
                    } else if (account == CURATORS_POOL && creditType == 2) {
                        model.curatorReserveCredit += funds;
                    }
                }
            } else if (log.emitter == address(deployed.core) && log.topics[0] == TRANSFER_TOPIC) {
                if (
                    _topicAddress(log.topics[1]) == address(0)
                        && _topicAddress(log.topics[2]) == model.recipient
                ) {
                    model.transferMinted = true;
                    model.tokenId = uint256(log.topics[3]);
                }
            } else if (
                log.emitter == address(deployed.minter)
                    && log.topics[0] == MINTER_TOKENS_MINTED_TOPIC
            ) {
                model.minterRange = true;
                model.collectionId = uint256(log.topics[1]);
                model.tokenId = uint256(log.topics[2]);
                model.recipient = _topicAddress(log.topics[3]);
                (model.lastTokenId, model.quantity) = abi.decode(log.data, (uint256, uint256));
            }
        }
    }

    function _reconstructAuction(
        Vm.Log[] memory logs,
        DeployedStream memory deployed,
        address auctions
    ) private pure returns (AuctionReadModel memory model) {
        for (uint256 i; i < logs.length; i++) {
            Vm.Log memory log = logs[i];
            if (
                log.emitter == address(deployed.drops)
                    && log.topics[0] == DROP_AUTHORIZATION_CONSUMED_TOPIC
            ) {
                model.consumed = true;
                model.dropId = log.topics[1];
                model.poster = _topicAddress(log.topics[3]);
            } else if (
                log.emitter == address(deployed.minter)
                    && log.topics[0] == MINTER_AUCTION_MINTED_TOPIC
            ) {
                model.bridgeMinted = true;
                model.collectionId = uint256(log.topics[1]);
                model.tokenId = uint256(log.topics[2]);
                model.custody = _topicAddress(log.topics[3]);
                model.bridgeEndTime = abi.decode(log.data, (uint256));
            } else if (log.emitter == auctions) {
                _applyAuctionLog(model, log);
            }
        }
    }

    function _applyAuctionLog(AuctionReadModel memory model, Vm.Log memory log) private pure {
        if (log.topics[0] == AUCTION_REGISTERED_TOPIC) {
            model.registered = true;
            model.dropId = log.topics[1];
            model.tokenId = uint256(log.topics[2]);
            model.collectionId = uint256(log.topics[3]);
            (model.poster, model.custody, model.reservePrice, model.registeredEndTime) =
                abi.decode(log.data, (address, address, uint256, uint256));
        } else if (log.topics[0] == AUCTION_CUSTODY_CONFIRMED_TOPIC) {
            model.custodyConfirmed = true;
            model.tokenId = uint256(log.topics[1]);
            model.custody = _topicAddress(log.topics[2]);
        } else if (log.topics[0] == AUCTION_STATUS_CHANGED_TOPIC) {
            uint256 status = uint256(log.topics[2]);
            if (status == uint256(StreamAuctions.AuctionStatus.Active)) {
                model.active = true;
            } else if (status == uint256(StreamAuctions.AuctionStatus.SettledWithBid)) {
                model.settledWithBid = true;
            }
        } else if (log.topics[0] == AUCTION_EXTENDED_TOPIC) {
            model.extendedEndTime = uint256(log.topics[3]);
        } else if (log.topics[0] == PARTICIPATE_TOPIC) {
            model.highestBidder = _topicAddress(log.topics[1]);
            model.highestBid = uint256(log.topics[3]);
        } else if (log.topics[0] == OUTBID_CREDIT_CREATED_TOPIC) {
            model.outbidBidder = _topicAddress(log.topics[1]);
            model.outbidCredit = uint256(log.topics[3]);
        } else if (log.topics[0] == AUCTION_PROCEEDS_CREDIT_CREATED_TOPIC) {
            address account = _topicAddress(log.topics[1]);
            uint256 creditType = uint256(log.topics[3]);
            uint256 funds = abi.decode(log.data, (uint256));
            if (account == model.poster && creditType == 0) {
                model.posterProceeds += funds;
            } else if (account == PAYOUT && creditType == 1) {
                model.protocolProceeds += funds;
            } else if (account == CURATORS_POOL && creditType == 2) {
                model.curatorProceeds += funds;
            }
        } else if (log.topics[0] == CLAIM_AUCTION_TOPIC) {
            model.claimed = true;
            model.highestBid = uint256(log.topics[2]);
        }
    }

    function _reconstructAdminBridge(Vm.Log[] memory logs, address minter)
        private
        pure
        returns (AdminReadModel memory model)
    {
        for (uint256 i; i < logs.length; i++) {
            Vm.Log memory log = logs[i];
            if (log.emitter != minter) {
                continue;
            }
            if (log.topics[0] == COLLECTION_PHASES_UPDATED_TOPIC) {
                model.phaseUpdated = true;
                model.collectionId = uint256(log.topics[1]);
                model.phaseAdmin = _topicAddress(log.topics[2]);
                (model.oldStart, model.oldEnd, model.newStart, model.newEnd) =
                    abi.decode(log.data, (uint256, uint256, uint256, uint256));
            } else if (log.topics[0] == MINTER_CONTRACT_REFERENCE_UPDATED_TOPIC) {
                model.referenceUpdates++;
                model.option = uint256(log.topics[1]);
                model.newContract = _topicAddress(log.topics[2]);
                model.referenceAdmin = _topicAddress(log.topics[3]);
                model.oldContract = abi.decode(log.data, (address));
            }
        }
    }

    function _topicAddress(bytes32 topic) private pure returns (address) {
        return address(uint160(uint256(topic)));
    }
}
