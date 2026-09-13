// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentStackFixture.sol";

/// @notice Product tests use the deployable Core and every included protocol satellite.
/// @dev Only the external randomness service is substituted by a controllable provider.
contract StreamCurrentStackTest is StreamCurrentStackFixture {
    function setUp() public {
        vm.deal(address(this), 100 ether);
        _deployCurrentStack(vm.addr(ARTIST_KEY), vm.addr(PLATFORM_KEY));
    }

    function testPaidMintEntropyMetadataTransferBurnAndWithdrawals() public {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory authorization = _saleAuthorization();
        bytes32 digest = sale.authorizationDigest(authorization);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        bytes memory platformSignature = abi.encodePacked(r, s, v);
        (v, r, s) = vm.sign(ARTIST_KEY, digest);
        bytes memory artistSignature = abi.encodePacked(r, s, v);

        (uint256 tokenId, bytes32 operationRoot) = sale.buy{ value: authorization.price }(
            authorization, TOKEN_DATA, platformSignature, artistSignature
        );
        require(core.ownerOf(tokenId) == BUYER, "owner after paid mint");
        require(core.totalSupply() == 1 && core.collectionMintedEver(1) == 1, "mint supply");
        require(manager.isOperationRootUsed(operationRoot), "ledger records paid mint");
        require(wallet.balance == authorization.price, "split funded");
        require(artists.acceptedArtist(1) == artist, "artist accepted attribution");
        (address royaltyWallet, uint256 royaltyAmount) = core.royaltyInfo(tokenId, 1 ether);
        require(royaltyWallet == wallet && royaltyAmount == 0.069 ether, "live royalty disclosure");
        require(core.coordinatorAtMint(tokenId) == address(entropy), "coordinator pinned");
        require(
            entropy.tokenEntropyStatus(tokenId) == StreamEntropyStatus.REGISTERED,
            "entropy registered"
        );
        bytes32 pendingURIHash = keccak256(bytes(core.tokenURI(tokenId)));

        (, uint256 providerRequestId) = entropy.requestEntropy(tokenId);
        provider.fulfill(providerRequestId, keccak256("external provider randomness"));
        require(
            entropy.tokenEntropyStatus(tokenId) == StreamEntropyStatus.FINALIZED,
            "entropy finalized"
        );
        (bytes32 seed, bool finalized) = entropy.tokenSeed(tokenId);
        require(finalized && seed != bytes32(0), "final token seed");
        require(
            keccak256(bytes(core.tokenURI(tokenId))) != pendingURIHash,
            "metadata follows final entropy"
        );
        require(
            keccak256(bytes(core.tokenURI(tokenId)))
                == keccak256(bytes(router.tokenURI(address(core), tokenId))),
            "Core returns actual router metadata"
        );

        IStreamSplitWallet(wallet).release(address(0), artist, payable(artist));
        IStreamSplitWallet(wallet).release(address(0), PROTOCOL, payable(PROTOCOL));
        require(artist.balance == 0.009 ether, "artist withdrawal");
        require(PROTOCOL.balance == 0.001 ether && wallet.balance == 0, "protocol withdrawal");

        vm.prank(BUYER);
        core.transferFrom(BUYER, SECOND_OWNER, tokenId);
        require(core.ownerOf(tokenId) == SECOND_OWNER, "transfer");
        vm.prank(SECOND_OWNER);
        core.burn(tokenId);
        (bool exists, uint256 collectionId, uint256 serial, bool burned) =
            core.tokenCollectionIdentity(tokenId);
        require(
            exists && collectionId == 1 && serial == 1 && burned, "permanent identity after burn"
        );
        require(
            core.totalSupply() == 0 && core.collectionMintedEver(1) == 1,
            "burn does not restore mint supply"
        );
        require(executor.genesisInitialized(), "atomic genesis consumed");
    }

    function testReceiverRejectionRollsBackPaymentAndEverySatellite() public {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory authorization = _saleAuthorization();
        authorization.recipient = address(new RejectCurrentStackNFT());
        bytes32 digest = sale.authorizationDigest(authorization);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        bytes memory platformSignature = abi.encodePacked(r, s, v);
        (v, r, s) = vm.sign(ARTIST_KEY, digest);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "receiver rejected"));
        sale.buy{ value: authorization.price }(
            authorization, TOKEN_DATA, platformSignature, abi.encodePacked(r, s, v)
        );
        require(core.totalSupply() == 0 && core.lastAllocatedTokenId() == 0, "Core rolled back");
        require(wallet.balance == 0 && sale.totalNativeProceeds() == 0, "payment rolled back");
        require(!sale.authorizationUsed(artist, authorization.nonce), "sale nonce rolled back");
        require(manager.nextOperationNonce() == 0, "ledger nonce rolled back");
        require(entropy.tokenEntropyStatus(1) == StreamEntropyStatus.NONE, "entropy rolled back");
    }

    function testAuctionCustodyEntropySettlementAndRefund() public {
        IStreamEnglishAuctionHouse.AuctionAuthorization memory authorization =
            IStreamEnglishAuctionHouse.AuctionAuthorization({
                collectionId: 1,
                phaseId: AUCTION_PHASE,
                artist: artist,
                profileId: profile,
                expectedPrimaryPolicyHash: _nativePrimaryPolicyHash(),
                tokenDataHash: keccak256(TOKEN_DATA),
                mintCommitment: keccak256("auction artwork"),
                mintPolicyHash: manager.phasePolicyHash(1, AUCTION_PHASE),
                reservePrice: 0.01 ether,
                startTime: uint64(block.timestamp),
                endTime: uint64(block.timestamp + 1 days),
                extensionWindow: 300,
                minBidIncrementBps: 500,
                nonce: keccak256("auction one"),
                deadline: uint64(block.timestamp + 1 days),
                signerEpoch: auction.signerEpoch()
            });
        bytes32 digest = auction.authorizationDigest(authorization);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        bytes memory platformSignature = abi.encodePacked(r, s, v);
        (v, r, s) = vm.sign(ARTIST_KEY, digest);
        uint256 tokenId = auction.createAuction(
            authorization, TOKEN_DATA, platformSignature, abi.encodePacked(r, s, v)
        );
        require(core.ownerOf(tokenId) == address(auction), "auction custody");
        auction.bid{ value: 0.01 ether }(tokenId, BUYER);
        vm.deal(SECOND_OWNER, 1 ether);
        vm.prank(SECOND_OWNER);
        auction.bid{ value: 0.02 ether }(tokenId, SECOND_OWNER);
        require(auction.refundCredit(address(this)) == 0.01 ether, "outbid credit");
        auction.withdrawRefund(payable(BUYER));
        require(BUYER.balance == 0.01 ether, "outbid refund claimed");
        (, uint256 requestId) = entropy.requestEntropy(tokenId);
        provider.fulfill(requestId, keccak256("auction randomness"));
        vm.warp(authorization.endTime + 1);
        auction.settle(tokenId);
        require(core.ownerOf(tokenId) == SECOND_OWNER && wallet.balance == 0.02 ether, "settlement");
        require(
            auction.auctionStatus(tokenId)
                == IStreamEnglishAuctionHouse.AuctionStatus.SettledWithBid,
            "settled status"
        );
    }

    function testPostGenesisOperatingPoliciesAllowPauseAndSignerRotationWithDelay() public {
        _executeDelayed(address(sale), abi.encodeCall(sale.setPaused, (true)));
        require(sale.paused(), "governed pause");
        _executeDelayed(address(sale), abi.encodeCall(sale.setPaused, (false)));
        require(!sale.paused(), "governed unpause");
        _executeDelayed(address(sale), abi.encodeCall(sale.setPlatformSigner, (SECOND_OWNER)));
        require(
            sale.platformSigner() == SECOND_OWNER && sale.signerEpoch() == 2,
            "governed signer rotation"
        );
    }

    function testGovernanceControllerCanRotateAfterGenesis() public {
        StreamGovernanceActor successor = new StreamGovernanceActor(address(this));
        (address priorRoot, bytes32 priorCodeHash, uint64 priorRevision) =
            executor.governanceRootState();
        bytes memory data = abi.encodeCall(
            executor.rotateGovernanceRoot, (address(successor), address(successor).codehash)
        );
        GovernanceActionRequest memory request = _operatingRequest(address(executor), data);
        request.actionClass = 3;
        request.scopeHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_ROOT_SCOPE_V1"), block.chainid, address(executor)
            )
        );
        request.oldValueHash = _rootStateHash(priorRoot, priorCodeHash, priorRevision);
        request.newValueHash =
            _rootStateHash(address(successor), address(successor).codehash, priorRevision + 1);
        _executeRequest(request);
        (address actualRoot, bytes32 actualCodeHash, uint64 actualRevision) =
            executor.governanceRootState();
        require(
            actualRoot == address(successor) && actualCodeHash == address(successor).codehash
                && actualRevision == priorRevision + 1,
            "root rotation"
        );
        request = _operatingRequest(address(sale), abi.encodeCall(sale.setPaused, (true)));
        vm.expectRevert();
        governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (request))
        );
        governanceRoot = successor;
        _executeRequest(request);
        require(sale.paused(), "successor controls operation");
    }

    function _rootStateHash(address root, bytes32 codeHash, uint64 revision)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_ROOT_STATE_V1"),
                block.chainid,
                address(executor),
                root,
                codeHash,
                revision
            )
        );
    }

    function _executeDelayed(address target, bytes memory data) private {
        _executeRequest(_operatingRequest(target, data));
    }

    function _operatingRequest(address target, bytes memory data)
        private
        view
        returns (GovernanceActionRequest memory)
    {
        bytes4 selector;
        assembly ("memory-safe") { selector := mload(add(data, 32)) }
        return GovernanceActionRequest({
            actionClass: 1,
            target: target,
            value: 0,
            selector: selector,
            callData: data,
            scopeHash: keccak256(abi.encode(target, selector)),
            oldValueHash: bytes32(0),
            newValueHash: keccak256(data),
            notBefore: uint64(block.timestamp + 48 hours),
            expiresAfter: uint64(block.timestamp + 9 days),
            reasonHash: keccak256("operating policy test"),
            reasonURI: "urn:6529stream:test:operation",
            manifestHash: DEPLOYMENT_HASH
        });
    }

    function _executeRequest(GovernanceActionRequest memory request) private {
        bytes memory result = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (request))
        );
        bytes32 actionId = abi.decode(result, (bytes32));
        vm.expectRevert();
        executor.executeGovernanceAction(actionId, request.callData);
        vm.warp(request.notBefore);
        executor.executeGovernanceAction(actionId, request.callData);
    }

    function _saleAuthorization()
        private
        view
        returns (IStreamFixedPriceSaleAdapter.SaleAuthorization memory)
    {
        return IStreamFixedPriceSaleAdapter.SaleAuthorization({
            collectionId: 1,
            phaseId: PHASE,
            payer: address(this),
            recipient: BUYER,
            artist: artist,
            profileId: profile,
            expectedPrimaryPolicyHash: _nativePrimaryPolicyHash(),
            tokenDataHash: keccak256(TOKEN_DATA),
            mintCommitment: keccak256("current-stack artwork commitment"),
            mintPolicyHash: manager.phasePolicyHash(1, PHASE),
            price: 0.01 ether,
            nonce: keccak256("first current-stack sale"),
            deadline: uint64(block.timestamp + 1 days),
            signerEpoch: sale.signerEpoch()
        });
    }
}

contract RejectCurrentStackNFT {
    fallback() external {
        revert("receiver rejected");
    }
}
