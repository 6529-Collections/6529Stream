// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentStackFixture.sol";

contract CurrentStackRejectingRecipient {
    error DeliveryRejected();

    fallback() external payable {
        revert DeliveryRejected();
    }
}

/// @notice Failure/retry tests across actual Core, sealed governance and all product satellites.
/// @dev The shared fixture mocks only the external entropy service. No protocol state is etched,
///      storage-patched, or privileged by impersonating the governance executor.
contract StreamCurrentStackAdversarialTest is StreamCurrentStackFixture {
    uint256 private constant NEXT_PLATFORM_KEY = 0x652902;

    function setUp() public {
        vm.deal(address(this), 100 ether);
        vm.deal(BUYER, 1 ether);
        vm.deal(SECOND_OWNER, 1 ether);
        _deployCurrentStack(vm.addr(ARTIST_KEY), vm.addr(PLATFORM_KEY));
    }

    function testAuctionDeliveryAndRefundFailuresPreserveCrossDomainAccounting() public {
        uint256 tokenId = _create(_auctionAuthorization(1), PLATFORM_KEY);
        _buy(_saleAuthorization(2), PLATFORM_KEY);
        CurrentStackRejectingRecipient rejected = new CurrentStackRejectingRecipient();
        vm.prank(BUYER);
        auction.bid{ value: 0.02 ether }(tokenId, BUYER);
        vm.prank(SECOND_OWNER);
        auction.bid{ value: 0.03 ether }(tokenId, address(rejected));
        _assertAuctionLiabilities(0.03 ether, 0.02 ether);

        vm.prank(BUYER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamEnglishAuctionHouse.AuctionNativeTransferFailed.selector, address(rejected)
            )
        );
        auction.withdrawRefund(payable(address(rejected)));
        require(auction.refundCredit(BUYER) == 0.02 ether, "failed refund remains claimable");
        _assertAuctionLiabilities(0.03 ether, 0.02 ether);
        vm.prank(BUYER);
        auction.withdrawRefund(payable(BUYER));
        require(BUYER.balance == 1 ether, "outbid buyer receives full refund");
        _assertAuctionLiabilities(0.03 ether, 0);

        (, uint256 requestId) = entropy.requestEntropy(tokenId);
        provider.fulfill(requestId, keccak256("auction result"));
        (bytes32 seed, bool finalized) = entropy.tokenSeed(tokenId);
        require(finalized, "auction entropy finalized before delivery");
        vm.warp(auction.auction(tokenId).endTime);
        vm.expectRevert(
            abi.encodeWithSelector(CurrentStackRejectingRecipient.DeliveryRejected.selector)
        );
        auction.settle(tokenId);
        require(core.ownerOf(tokenId) == address(auction), "failed delivery preserves custody");
        require(!auction.auction(tokenId).settled, "failed delivery remains retryable");
        require(
            wallet.balance == 0.01 ether, "failed auction payment cannot alter fixed-sale proceeds"
        );
        require(
            auction.totalNativeProceeds() == 0 && sale.totalNativeProceeds() == 0.01 ether,
            "sale accounting is atomic"
        );
        require(
            manager.nextOperationNonce() == 2 && core.totalSupply() == 2, "delivery never remints"
        );
        (bytes32 retainedSeed,) = entropy.tokenSeed(tokenId);
        require(retainedSeed == seed, "failed delivery cannot reroll entropy");
        _assertAuctionLiabilities(0.03 ether, 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamEnglishAuctionHouse.UnauthorizedAuctionClaimant.selector, address(this)
            )
        );
        auction.setDeliveryRecipient(tokenId, address(this));
        vm.prank(SECOND_OWNER);
        auction.setDeliveryRecipient(tokenId, BUYER);
        auction.settle(tokenId);
        require(
            core.ownerOf(tokenId) == BUYER && wallet.balance == 0.04 ether, "winner retry pays once"
        );
        require(auction.totalNativeProceeds() == 0.03 ether, "winning amount recorded once");
        _assertAuctionLiabilities(0, 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamEnglishAuctionHouse.AuctionAlreadySettled.selector, tokenId
            )
        );
        auction.settle(tokenId);
        vm.prank(BUYER);
        vm.expectRevert(abi.encodeWithSelector(IStreamEnglishAuctionHouse.NoAuctionRefund.selector));
        auction.withdrawRefund(payable(BUYER));

        (address royaltyWallet, uint256 royaltyAmount) = core.royaltyInfo(tokenId, 1 ether);
        require(
            royaltyWallet == wallet && royaltyAmount == 0.069 ether,
            "auction token has live royalty route"
        );
        (bool paid,) = royaltyWallet.call{ value: royaltyAmount }("");
        require(paid, "marketplace can fund disclosed royalty wallet");
        require(
            IStreamSplitWallet(wallet).observedReceived(address(0)) == 0.109 ether,
            "sales and voluntary royalties share immutable split"
        );
        IStreamSplitWallet(wallet).release(address(0), artist, payable(artist));
        IStreamSplitWallet(wallet).release(address(0), PROTOCOL, payable(PROTOCOL));
        require(
            artist.balance == 0.0981 ether && PROTOCOL.balance == 0.0109 ether,
            "all proceeds conserved across split withdrawals"
        );
        require(wallet.balance == 0, "no stranded proceeds or duplicate releases");
    }

    function testSaleAndAuctionSharePermanentSupplyEvenAfterCancellationAndBurn() public {
        uint256 auctionToken = _create(_auctionAuthorization(10), PLATFORM_KEY);
        for (uint256 i; i < 9; ++i) {
            _buy(_saleAuthorization(100 + i), PLATFORM_KEY);
        }
        require(
            core.collectionMintedEver(1) == 10 && manager.nextOperationNonce() == 10,
            "both phases consume actual collection supply"
        );
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory saleTerms = _saleAuthorization(200);
        IStreamEnglishAuctionHouse.AuctionAuthorization memory auctionTerms =
            _auctionAuthorization(201);
        _expectSupplyRejections(saleTerms, auctionTerms);
        require(
            wallet.balance == 0.09 ether && sale.totalNativeProceeds() == 0.09 ether,
            "exhaustion rolls back payment"
        );
        require(
            !sale.authorizationUsed(artist, saleTerms.nonce), "failed sale nonce remains unconsumed"
        );
        require(
            !auction.authorizationUsed(artist, auctionTerms.nonce),
            "failed auction nonce remains unconsumed"
        );
        require(
            core.lastAllocatedTokenId() == 10 && manager.nextOperationNonce() == 10,
            "failed allocations cannot advance Core or ledger"
        );
        require(
            entropy.tokenEntropyStatus(11) == StreamEntropyStatus.NONE,
            "failed allocation cannot leave entropy identity"
        );

        vm.prank(artist);
        auction.cancel(auctionToken);
        vm.prank(artist);
        core.burn(auctionToken);
        require(
            core.totalSupply() == 9 && core.collectionMintedEver(1) == 10,
            "cancelled burned auction does not reopen supply"
        );
        _expectSupplyRejections(saleTerms, auctionTerms);
    }

    function testSignerRotationRequiresFreshArtistConsentAndCancellationRemainsFinal() public {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory saleTerms = _saleAuthorization(300);
        IStreamEnglishAuctionHouse.AuctionAuthorization memory auctionTerms =
            _auctionAuthorization(301);
        bytes memory oldSaleArtist = _signature(ARTIST_KEY, sale.authorizationDigest(saleTerms));
        bytes memory oldAuctionArtist =
            _signature(ARTIST_KEY, auction.authorizationDigest(auctionTerms));
        _executeDelayed(
            address(sale), abi.encodeCall(sale.setPlatformSigner, (vm.addr(NEXT_PLATFORM_KEY)))
        );
        _executeDelayed(
            address(auction),
            abi.encodeCall(auction.setPlatformSigner, (vm.addr(NEXT_PLATFORM_KEY)))
        );
        bytes memory salePlatform =
            _signature(NEXT_PLATFORM_KEY, sale.authorizationDigest(saleTerms));
        bytes memory auctionPlatform =
            _signature(NEXT_PLATFORM_KEY, auction.authorizationDigest(auctionTerms));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamFixedPriceSaleAdapter.InvalidSaleAuthorization.selector)
        );
        sale.buy{ value: saleTerms.price }(saleTerms, TOKEN_DATA, salePlatform, oldSaleArtist);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamEnglishAuctionHouse.InvalidAuctionAuthorization.selector)
        );
        auction.createAuction(auctionTerms, TOKEN_DATA, auctionPlatform, oldAuctionArtist);

        saleTerms.signerEpoch = sale.signerEpoch();
        auctionTerms.signerEpoch = auction.signerEpoch();
        salePlatform = _signature(NEXT_PLATFORM_KEY, sale.authorizationDigest(saleTerms));
        auctionPlatform = _signature(NEXT_PLATFORM_KEY, auction.authorizationDigest(auctionTerms));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFixedPriceSaleAdapter.InvalidSaleSignature.selector, artist
            )
        );
        sale.buy{ value: saleTerms.price }(saleTerms, TOKEN_DATA, salePlatform, oldSaleArtist);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamEnglishAuctionHouse.InvalidAuctionSignature.selector, artist
            )
        );
        auction.createAuction(auctionTerms, TOKEN_DATA, auctionPlatform, oldAuctionArtist);
        require(
            core.totalSupply() == 0 && wallet.balance == 0,
            "platform alone cannot reauthorize artist terms"
        );
        _buy(saleTerms, NEXT_PLATFORM_KEY);
        _create(auctionTerms, NEXT_PLATFORM_KEY);

        saleTerms = _saleAuthorization(302);
        auctionTerms = _auctionAuthorization(303);
        vm.prank(artist);
        sale.cancelAuthorization(saleTerms.nonce);
        vm.prank(artist);
        auction.cancelAuthorization(auctionTerms.nonce);
        bytes memory saleArtist = _signature(ARTIST_KEY, sale.authorizationDigest(saleTerms));
        bytes memory auctionArtist =
            _signature(ARTIST_KEY, auction.authorizationDigest(auctionTerms));
        salePlatform = _signature(NEXT_PLATFORM_KEY, sale.authorizationDigest(saleTerms));
        auctionPlatform = _signature(NEXT_PLATFORM_KEY, auction.authorizationDigest(auctionTerms));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFixedPriceSaleAdapter.SaleAlreadyConsumed.selector, artist, saleTerms.nonce
            )
        );
        sale.buy{ value: saleTerms.price }(saleTerms, TOKEN_DATA, salePlatform, saleArtist);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamEnglishAuctionHouse.AuctionAuthorizationUsed.selector,
                artist,
                auctionTerms.nonce
            )
        );
        auction.createAuction(auctionTerms, TOKEN_DATA, auctionPlatform, auctionArtist);
        require(
            core.totalSupply() == 2 && manager.nextOperationNonce() == 2,
            "cancelled terms cannot allocate identities"
        );
    }

    function testChangedPhasePoliciesInvalidateSignedTermsWithoutConsumingPayments() public {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory saleTerms = _saleAuthorization(400);
        IStreamEnglishAuctionHouse.AuctionAuthorization memory auctionTerms =
            _auctionAuthorization(401);
        _consentAdditionalExecutor(PHASE, address(sale));
        _executeDelayed(
            address(manager),
            abi.encodeCall(manager.setPhaseExecutor, (1, PHASE, SECOND_OWNER, true))
        );
        _consentAdditionalExecutor(AUCTION_PHASE, address(auction));
        _executeDelayed(
            address(manager),
            abi.encodeCall(manager.setPhaseExecutor, (1, AUCTION_PHASE, SECOND_OWNER, true))
        );
        bytes memory salePlatform = _signature(PLATFORM_KEY, sale.authorizationDigest(saleTerms));
        bytes memory saleArtist = _signature(ARTIST_KEY, sale.authorizationDigest(saleTerms));
        bytes memory auctionPlatform =
            _signature(PLATFORM_KEY, auction.authorizationDigest(auctionTerms));
        bytes memory auctionArtist =
            _signature(ARTIST_KEY, auction.authorizationDigest(auctionTerms));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintManager.MintPolicyHashMismatch.selector,
                saleTerms.mintPolicyHash,
                manager.phasePolicyHash(1, PHASE)
            )
        );
        sale.buy{ value: saleTerms.price }(saleTerms, TOKEN_DATA, salePlatform, saleArtist);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintManager.MintPolicyHashMismatch.selector,
                auctionTerms.mintPolicyHash,
                manager.phasePolicyHash(1, AUCTION_PHASE)
            )
        );
        auction.createAuction(auctionTerms, TOKEN_DATA, auctionPlatform, auctionArtist);
        require(
            core.lastAllocatedTokenId() == 0 && manager.nextOperationNonce() == 0,
            "stale policy has no mint effects"
        );
        require(
            wallet.balance == 0 && sale.totalNativeProceeds() == 0,
            "stale policy rolls back native deposit"
        );
        require(
            !sale.authorizationUsed(artist, saleTerms.nonce)
                && !auction.authorizationUsed(artist, auctionTerms.nonce),
            "stale policy preserves nonces"
        );
        saleTerms.mintPolicyHash = manager.phasePolicyHash(1, PHASE);
        auctionTerms.mintPolicyHash = manager.phasePolicyHash(1, AUCTION_PHASE);
        _buy(saleTerms, PLATFORM_KEY);
        _create(auctionTerms, PLATFORM_KEY);
        require(
            core.totalSupply() == 2 && wallet.balance == 0.01 ether,
            "fresh platform and artist consent restores both paths"
        );
    }

    /// @dev The governance change must first have actual artist approval. The stale sale
    ///      signatures below remain unchanged so this still tests mint-policy drift rejection.
    function _consentAdditionalExecutor(bytes32 phaseId, address existingExecutor) private {
        (, IStreamMintManager.MintPhaseConfig memory config) = manager.phase(1, phaseId);
        bytes32[] memory ids = manager.phaseCounterIds(1, phaseId);
        IStreamMintManager.MintCounterConfig[] memory configs =
            new IStreamMintManager.MintCounterConfig[](ids.length);
        for (uint256 i; i < ids.length; ++i) {
            configs[i] = manager.counterConfig(1, phaseId, ids[i]);
        }
        address[] memory executors = new address[](2);
        executors[0] = existingExecutor;
        executors[1] = SECOND_OWNER;
        _recordFixturePolicy(
            phaseId,
            manager.previewPhasePolicyHash(
                1, phaseId, config, manager.phaseGate(1, phaseId), ids, configs, executors
            )
        );
    }

    function _expectSupplyRejections(
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory saleTerms,
        IStreamEnglishAuctionHouse.AuctionAuthorization memory auctionTerms
    ) private {
        bytes memory platformSignature =
            _signature(PLATFORM_KEY, sale.authorizationDigest(saleTerms));
        bytes memory artistSignature = _signature(ARTIST_KEY, sale.authorizationDigest(saleTerms));
        vm.expectRevert(
            abi.encodeWithSelector(StreamCore.CollectionSupplyReached.selector, uint256(1))
        );
        sale.buy{ value: saleTerms.price }(
            saleTerms, TOKEN_DATA, platformSignature, artistSignature
        );
        platformSignature = _signature(PLATFORM_KEY, auction.authorizationDigest(auctionTerms));
        artistSignature = _signature(ARTIST_KEY, auction.authorizationDigest(auctionTerms));
        vm.expectRevert(
            abi.encodeWithSelector(StreamCore.CollectionSupplyReached.selector, uint256(1))
        );
        auction.createAuction(auctionTerms, TOKEN_DATA, platformSignature, artistSignature);
    }

    function _assertAuctionLiabilities(uint256 escrow, uint256 refunds) private view {
        require(
            auction.totalBidEscrow() == escrow && auction.totalRefundOwed() == refunds,
            "separate auction liabilities"
        );
        require(
            address(auction).balance == escrow + refunds && auction.totalOwed() == escrow + refunds,
            "escrow and refunds exactly conserved"
        );
    }

    function _buy(IStreamFixedPriceSaleAdapter.SaleAuthorization memory terms, uint256 platformKey)
        private
        returns (uint256 tokenId)
    {
        bytes32 digest = sale.authorizationDigest(terms);
        bytes memory platformSignature = _signature(platformKey, digest);
        bytes memory artistSignature = _signature(ARTIST_KEY, digest);
        (tokenId,) =
            sale.buy{ value: terms.price }(terms, TOKEN_DATA, platformSignature, artistSignature);
    }

    function _create(
        IStreamEnglishAuctionHouse.AuctionAuthorization memory terms,
        uint256 platformKey
    ) private returns (uint256 tokenId) {
        bytes32 digest = auction.authorizationDigest(terms);
        bytes memory platformSignature = _signature(platformKey, digest);
        bytes memory artistSignature = _signature(ARTIST_KEY, digest);
        return auction.createAuction(terms, TOKEN_DATA, platformSignature, artistSignature);
    }

    function _signature(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _saleAuthorization(uint256 nonce)
        private
        view
        returns (IStreamFixedPriceSaleAdapter.SaleAuthorization memory)
    {
        return IStreamFixedPriceSaleAdapter.SaleAuthorization(
            1,
            PHASE,
            address(this),
            BUYER,
            artist,
            profile,
            _nativePrimaryPolicyHash(),
            keccak256(TOKEN_DATA),
            keccak256(abi.encode("sale commitment", nonce)),
            manager.phasePolicyHash(1, PHASE),
            0.01 ether,
            bytes32(nonce),
            uint64(block.timestamp + 7 days),
            sale.signerEpoch()
        );
    }

    function _auctionAuthorization(uint256 nonce)
        private
        view
        returns (IStreamEnglishAuctionHouse.AuctionAuthorization memory)
    {
        return IStreamEnglishAuctionHouse.AuctionAuthorization(
            1,
            AUCTION_PHASE,
            artist,
            profile,
            _nativePrimaryPolicyHash(),
            keccak256(TOKEN_DATA),
            keccak256(abi.encode("auction commitment", nonce)),
            manager.phasePolicyHash(1, AUCTION_PHASE),
            0.01 ether,
            uint64(block.timestamp),
            uint64(block.timestamp + 7 days),
            300,
            500,
            bytes32(nonce),
            uint64(block.timestamp + 7 days),
            auction.signerEpoch()
        );
    }

    function _executeDelayed(address target, bytes memory data) private {
        bytes4 selector;
        assembly ("memory-safe") { selector := mload(add(data, 32)) }
        GovernanceActionRequest memory request = GovernanceActionRequest({
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
            reasonHash: keccak256("cross-domain test"),
            reasonURI: "urn:6529stream:test:cross-domain",
            manifestHash: DEPLOYMENT_HASH
        });
        bytes memory result = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (request))
        );
        vm.warp(request.notBefore);
        executor.executeGovernanceAction(abi.decode(result, (bytes32)), data);
    }
}
