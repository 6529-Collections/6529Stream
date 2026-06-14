// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/AuctionContract.sol";
import "../smart-contracts/StreamAdmins.sol";
import "../smart-contracts/StreamCore.sol";
import "../smart-contracts/StreamCuratorsPool.sol";
import "../smart-contracts/StreamDrops.sol";
import "./helpers/DropAuthTestHelper.sol";
import "./helpers/StreamFixture.sol";

contract StreamGasSnapshotTest is DropAuthTestHelper, StreamFixture {
    address private constant POSTER = address(0x1001);
    address private constant RECIPIENT = address(0x5005);
    address private constant PAYOUT = address(0x2002);
    address private constant CURATORS_POOL = address(0x3003);
    address private constant BIDDER = address(0x4004);
    address private constant CURATOR = address(0x7007);

    uint256 private constant COLLECTION_ID = 1;
    uint256 private constant TOKEN_ID = 10_000_000_000;
    uint256 private constant FIXED_PRICE = 4 ether;
    uint256 private constant RESERVE_PRICE = 5 ether;
    uint256 private constant REWARD_AMOUNT = 3 ether;

    function testGasFixedPriceMint() public {
        vm.pauseGasMetering();
        DeployedStream memory deployed =
            deployStreamWithSigner(PAYOUT, CURATORS_POOL, signerAddress());
        StreamDrops.DropAuthorization memory authorization = buildFixedPriceAuthorization(
            deployed.drops,
            POSTER,
            RECIPIENT,
            address(this),
            "gas-fixed-price",
            COLLECTION_ID,
            FIXED_PRICE,
            1,
            2,
            block.timestamp + 1 days
        );
        bytes memory signature = signAuthorization(deployed.drops, authorization);
        vm.deal(address(this), FIXED_PRICE);

        vm.resumeGasMetering();
        deployed.drops.mintDrop{ value: FIXED_PRICE }(authorization, "gas-fixed-price", signature);
    }

    function testGasAuctionBid() public {
        vm.pauseGasMetering();
        AuctionSetup memory setup = _createAuction();
        vm.deal(BIDDER, RESERVE_PRICE);

        vm.resumeGasMetering();
        vm.prank(BIDDER);
        setup.auctions.participateToAuction{ value: RESERVE_PRICE }(setup.tokenId);
    }

    function testGasAuctionSettlementWithBid() public {
        vm.pauseGasMetering();
        AuctionSetup memory setup = _createAuction();
        vm.deal(BIDDER, RESERVE_PRICE);
        vm.prank(BIDDER);
        setup.auctions.participateToAuction{ value: RESERVE_PRICE }(setup.tokenId);
        vm.warp(setup.auctionEndTime + 1);

        vm.resumeGasMetering();
        setup.auctions.claimAuction(setup.tokenId);
    }

    function testGasCuratorRewardClaim() public {
        vm.pauseGasMetering();
        CuratorSetup memory setup = _deployCuratorPool();
        bytes32[] memory proof = _setSingleLeafRoot(setup.pool, CURATOR, REWARD_AMOUNT);
        vm.deal(address(setup.pool), REWARD_AMOUNT);

        vm.resumeGasMetering();
        vm.prank(CURATOR);
        setup.pool.claimRewards(COLLECTION_ID, REWARD_AMOUNT, proof, address(0));
    }

    function testGasFinalOnchainTokenURI() public {
        vm.pauseGasMetering();
        DeployedStream memory deployed = deployStream(PAYOUT, CURATORS_POOL);
        _mintToken(deployed, TOKEN_ID, 7);
        _setTokenMetadataInputs(deployed.core);
        deployed.core.changeMetadataView(COLLECTION_ID, true);

        vm.resumeGasMetering();
        deployed.core.tokenURI(TOKEN_ID);
    }

    function testGasDependencyScriptRead() public {
        vm.pauseGasMetering();
        DeployedStream memory deployed = deployStream(PAYOUT, CURATORS_POOL);
        bytes32 dependencyKey = keccak256("gas-snapshot-library");
        string[] memory dependencyChunks = new string[](2);
        dependencyChunks[0] = "function dependencyOne(){return 1;}";
        dependencyChunks[1] = "function dependencyTwo(){return 2;}";
        deployed.dependencyRegistry.addDependency(dependencyKey, dependencyChunks);
        _pinCollectionDependency(deployed, dependencyKey);
        _mintToken(deployed, TOKEN_ID, 7);

        vm.resumeGasMetering();
        deployed.core.retrieveGenerativeScript(TOKEN_ID);
    }

    struct AuctionSetup {
        DeployedStream deployed;
        StreamAuctions auctions;
        uint256 tokenId;
        uint256 auctionEndTime;
    }

    struct CuratorSetup {
        StreamAdmins admins;
        GasSnapshotDelegation delegation;
        StreamCuratorsPool pool;
    }

    function _createAuction() private returns (AuctionSetup memory setup) {
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
        setup.auctionEndTime = block.timestamp + 1 days;
        StreamDrops.DropAuthorization memory authorization = buildAuctionAuthorization(
            setup.deployed.drops,
            POSTER,
            address(0),
            "gas-auction",
            COLLECTION_ID,
            RESERVE_PRICE,
            setup.auctionEndTime,
            uint256(uint160(address(setup.auctions))),
            uint256(uint160(address(setup.auctions))) + 1,
            block.timestamp + 1 days
        );
        bytes memory signature = signAuthorization(setup.deployed.drops, authorization);

        setup.deployed.drops.mintDrop(authorization, "gas-auction", signature);
        setup.tokenId = TOKEN_ID;
    }

    function _deployCuratorPool() private returns (CuratorSetup memory setup) {
        setup.admins = new StreamAdmins(address(this));
        setup.delegation = new GasSnapshotDelegation();
        setup.pool = new StreamCuratorsPool(address(setup.admins), address(setup.delegation));
        setup.admins
            .registerFunctionAdmin(
                address(this), address(setup.pool), setup.pool.setMerkleRoot.selector, true
            );
    }

    function _setSingleLeafRoot(StreamCuratorsPool pool, address rewardAddress, uint256 amount)
        private
        returns (bytes32[] memory proof)
    {
        uint256 rootEpoch = pool.collectionMerkleRootEpoch(COLLECTION_ID) + 1;
        bytes32 leaf = pool.hashRewardLeaf(rewardAddress, COLLECTION_ID, amount, rootEpoch);
        pool.setMerkleRoot(COLLECTION_ID, leaf);
        proof = new bytes32[](0);
    }

    function _mintToken(DeployedStream memory deployed, uint256 tokenId, uint256 salt) private {
        vm.prank(address(deployed.minter));
        deployed.core.mint(tokenId, RECIPIENT, "1,2,3", salt, COLLECTION_ID);
    }

    function _setTokenMetadataInputs(StreamCore core) private {
        uint256[] memory tokenIds = new uint256[](1);
        string[] memory images = new string[](1);
        string[] memory attributes = new string[](1);

        tokenIds[0] = TOKEN_ID;
        images[0] = "ipfs://image/10000000000.png";
        attributes[0] = "{\"trait_type\":\"Gas\",\"value\":\"Snapshot\"}";

        core.updateImagesAndAttributes(tokenIds, images, attributes);
    }
}

contract GasSnapshotDelegation {
    function retrieveGlobalStatusOfDelegation(address, address, address, uint256)
        external
        pure
        returns (bool)
    {
        return false;
    }
}
