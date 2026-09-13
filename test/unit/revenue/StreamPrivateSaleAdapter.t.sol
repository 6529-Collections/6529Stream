// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/PrivateSaleTestBase.sol";

contract StreamPrivateSaleAdapterTest is PrivateSaleTestBase {
    function testPrivateCustodyRoyaltyAndPerSaleCreditsConserveValue() external {
        bytes32 id = sale.registerSale(_config(5, 1, buyer, 0));
        (address receiver, uint256 amount, bool secondary, bool outside) = sale.royaltyQuote(id);
        require(receiver == address(royalty) && amount == 100 && secondary && outside);
        _deposit(id);
        require(core.ownerOf(1) == address(sale));
        _purchase(id, 1007);
        IStreamPrivateSaleAdapter.Sale memory record = sale.saleDetails(id);
        require(record.status == 3 && record.nftClaim == 0 && record.royaltyAmount == 100);
        require(record.royaltyReceiver == address(royalty) && core.ownerOf(1) == buyer);
        require(address(royalty).balance == 100 && sale.totalLiabilities() == 907);
        require(
            sale.refundableBalance(id, consignor) == 900 && sale.refundableBalance(id, buyer) == 7
        );
        require(address(sale).balance == 907);
        uint256 beforeBuyer = buyer.balance;
        vm.prank(buyer);
        sale.claimRefund(id, buyer);
        require(buyer.balance == beforeBuyer + 7 && sale.totalLiabilities() == 900);
        vm.prank(consignor);
        sale.claimRefund(id, consignor);
        require(sale.totalLiabilities() == 0 && address(sale).balance == 0);
    }

    function testOfferConsumesBothDigestsAndOwnerGrantAtomically() external {
        StreamPrivateSaleTypes.SaleOffer memory o = _offer(1, buyer, 1000);
        bytes32 od = sale.offerDigest(o);
        bytes32 id = sale.registerSale(_config(6, 1, buyer, od));
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(id, buyer, 1000);
        StreamPrivateSaleTypes.SaleCustodyGrant memory g = _grant(1, od);
        IStreamPrivateSaleAdapter.Signature memory ap = _platformProof(a);
        IStreamPrivateSaleAdapter.Signature memory bp =
            IStreamPrivateSaleAdapter.Signature(buyer, 1, _signature(BUYER_KEY, od));
        bytes memory gp = _signature(OWNER_KEY, sale.custodyGrantDigest(g));
        vm.prank(buyer);
        sale.acceptOffer{ value: 1000 }(a, ap, o, bp, g, 1, gp);
        require(core.ownerOf(1) == buyer && sale.digestConsumed(od));
        require(
            sale.digestConsumed(sale.authorizationDigest(a))
                && sale.digestConsumed(sale.custodyGrantDigest(g))
        );
        require(sale.refundableBalance(id, consignor) == 900 && address(royalty).balance == 100);
    }

    function testRevokedOfferCannotUseFreshAuthorizationAndRollsBackOtherDigest() external {
        StreamPrivateSaleTypes.SaleOffer memory o = _offer(1, buyer, 1000);
        bytes32 od = sale.offerDigest(o);
        bytes32 id = sale.registerSale(_config(6, 1, buyer, od));
        vm.prank(buyer);
        sale.revokeOffer(o, 1, "");
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(id, buyer, 1000);
        a.nonce = keccak256("fresh opposing proof");
        StreamPrivateSaleTypes.SaleCustodyGrant memory g = _grant(1, od);
        IStreamPrivateSaleAdapter.Signature memory ap = _platformProof(a);
        IStreamPrivateSaleAdapter.Signature memory bp =
            IStreamPrivateSaleAdapter.Signature(buyer, 1, _signature(BUYER_KEY, od));
        bytes memory gp = _signature(OWNER_KEY, sale.custodyGrantDigest(g));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamPrivateSaleAdapter.PrivateSaleDigestConsumed.selector, od)
        );
        vm.prank(buyer);
        sale.acceptOffer{ value: 1000 }(a, ap, o, bp, g, 1, gp);
        require(!sale.digestConsumed(sale.authorizationDigest(a)) && core.ownerOf(1) == consignor);
        require(address(sale).balance == 0 && sale.totalLiabilities() == 0);
    }

    function testFullAuthorizationDirectRevocationBlocksItsOriginalProof() external {
        bytes32 id = sale.registerSale(_config(5, 1, buyer, 0));
        _deposit(id);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(id, buyer, 1000);
        IStreamPrivateSaleAdapter.Signature memory proof = _platformProof(a);
        vm.prank(platform);
        sale.revokeAuthorization(a, IStreamPrivateSaleAdapter.Signature(platform, 1, ""));
        bytes32 digest = sale.authorizationDigest(a);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamPrivateSaleAdapter.PrivateSaleDigestConsumed.selector, digest
            )
        );
        vm.prank(buyer);
        sale.purchasePrivate{ value: 1000 }(a, proof);
        require(sale.digestRevoked(digest) && core.ownerOf(1) == address(sale));
        a.nonce = keccak256("distinct authorization");
        proof = _platformProof(a);
        vm.prank(buyer);
        sale.purchasePrivate{ value: 1000 }(a, proof);
        require(core.ownerOf(1) == buyer);
    }

    function testDepositedGrantRevocationStagesOneWayOwnerClaim() external {
        bytes32 id = sale.registerSale(_config(5, 1, buyer, 0));
        _deposit(id);
        StreamPrivateSaleTypes.SaleCustodyGrant memory g = _grant(1, id);
        vm.prank(consignor);
        sale.revokeCustodyGrant(g, 1, "");
        IStreamPrivateSaleAdapter.Sale memory record = sale.saleDetails(id);
        require(record.status == 4 && record.nftClaim == 2 && core.ownerOf(1) == address(sale));
        require(sale.digestRevoked(sale.custodyGrantDigest(g)));
        require(sale.retryNft(id));
        require(core.ownerOf(1) == consignor && sale.saleDetails(id).nftClaim == 0);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamPrivateSaleAdapter.PrivateSaleClaimUnavailable.selector)
        );
        sale.retryNft(id);
    }

    function testRejectingRoyaltyCreatesExactBucketAndPullPreventsRetryDoublePayment() external {
        royalty.configure(true, false);
        bytes32 id = sale.registerSale(_config(5, 1, buyer, 0));
        _deposit(id);
        _purchase(id, 1011);
        require(
            sale.refundableBalance(id, address(royalty)) == 100 && sale.totalLiabilities() == 1011
        );
        require(core.ownerOf(1) == buyer && address(royalty).balance == 0);
        require(!sale.retryRoyalty(id));
        address recipient = address(0x123);
        royalty.execute(address(sale), 0, abi.encodeCall(sale.claimRefund, (id, recipient)));
        require(recipient.balance == 100 && sale.refundableBalance(id, address(royalty)) == 0);
        royalty.configure(false, false);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamPrivateSaleAdapter.PrivateSaleClaimUnavailable.selector)
        );
        sale.retryRoyalty(id);
        require(
            sale.refundableBalance(id, consignor) == 900 && sale.refundableBalance(id, buyer) == 11
        );
    }

    function testRejectingNftPreservesSettlementAndBuyerCanDirectExactClaim() external {
        PrivateSaleRecipient recipient = new PrivateSaleRecipient();
        recipient.configure(false, true);
        vm.deal(address(recipient), 2000);
        bytes32 id = sale.registerSale(_config(5, 1, address(recipient), 0));
        _deposit(id);
        StreamPrivateSaleTypes.SaleAuthorization memory a =
            _authorization(id, address(recipient), 1000);
        IStreamPrivateSaleAdapter.Signature memory proof = _platformProof(a);
        recipient.execute(address(sale), 1037, abi.encodeCall(sale.purchasePrivate, (a, proof)));
        require(sale.saleDetails(id).status == 3 && sale.saleDetails(id).nftClaim == 1);
        require(core.ownerOf(1) == address(sale) && address(royalty).balance == 100);
        require(
            sale.refundableBalance(id, address(recipient)) == 37
                && sale.refundableBalance(id, consignor) == 900
        );
        require(!sale.retryNft(id));
        address selected = address(0x456);
        recipient.execute(address(sale), 0, abi.encodeCall(sale.claimNft, (id, selected)));
        require(core.ownerOf(1) == selected && sale.saleDetails(id).nftClaim == 0);
    }

    function testInvalidRoyaltyRollsBackConsumedAuthorizationAndIdenticalRetrySucceeds() external {
        bytes32 id = sale.registerSale(_config(5, 1, buyer, 0));
        _deposit(id);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(id, buyer, 1000);
        IStreamPrivateSaleAdapter.Signature memory proof = _platformProof(a);
        core.setRoyalty(address(royalty), 11000, false);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamPrivateSaleAdapter.PrivateSaleRoyaltyInvalid.selector, 1)
        );
        vm.prank(buyer);
        sale.purchasePrivate{ value: 1000 }(a, proof);
        require(
            !sale.digestConsumed(sale.authorizationDigest(a)) && sale.saleDetails(id).status == 2
        );
        require(
            sale.totalLiabilities() == 0 && address(sale).balance == 0
                && core.ownerOf(1) == address(sale)
        );
        core.setRoyalty(address(royalty), 1000, false);
        vm.prank(buyer);
        sale.purchasePrivate{ value: 1000 }(a, proof);
        require(core.ownerOf(1) == buyer);
    }

    function testLaterCollectionDelegationCannotChangeExistingSignerSet() external {
        bytes32 id = sale.registerSale(_config(5, 1, buyer, 0));
        _deposit(id);
        bytes32 original = sale.saleDetails(id).configHash;
        sale.configureCollectionSigner(1, keccak256("later disabled delegation"), false);
        _purchase(id, 1000);
        require(core.ownerOf(1) == buyer && sale.saleDetails(id).configHash == original);
        core.mint(consignor, 2);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamPrivateSaleAdapter.InvalidPrivateSale.selector)
        );
        sale.registerSale(_config(5, 2, buyer, 0));
    }
}
