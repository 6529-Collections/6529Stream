// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/PrivateSaleTestBase.sol";

contract StreamPrivateSaleRevocationsTest is PrivateSaleTestBase {
    function _domainDigest(bytes32 body) private view returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream Sales"),
                keccak256("1"),
                block.chainid,
                address(sale)
            )
        );
        return keccak256(abi.encodePacked(hex"1901", domain, body));
    }

    function testRelayedFullAuthorizationRevocationRequiresItsDistinctSignatureFamily() external {
        bytes32 id = sale.registerSale(_config(5, 1, buyer, 0));
        _deposit(id);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(id, buyer, 1000);
        bytes32 digest = sale.authorizationDigest(a);
        IStreamPrivateSaleAdapter.Signature memory proof = _platformProof(a);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamPrivateSaleAdapter.PrivateSaleAuthorityInvalid.selector, platform
            )
        );
        sale.revokeAuthorization(a, proof);
        require(!sale.digestConsumed(digest));
        bytes32 revocation = _domainDigest(
            keccak256(
                abi.encode(
                    bytes32(0x41d0d127fea4cbca0630f242fe7375e83ff775d8215636ae1fdd92b3d481a455),
                    block.chainid,
                    address(sale),
                    platform,
                    digest
                )
            )
        );
        proof.signature = _signature(PLATFORM_KEY, revocation);
        sale.revokeAuthorization(a, proof);
        require(sale.digestConsumed(digest) && sale.digestRevoked(digest));
        proof = _platformProof(a);
        vm.prank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamPrivateSaleAdapter.PrivateSaleDigestConsumed.selector, digest
            )
        );
        sale.purchasePrivate{ value: 1000 }(a, proof);
        require(core.ownerOf(1) == address(sale) && sale.totalLiabilities() == 0);
        a.nonce = keccak256("new explicit platform authorization");
        proof = _platformProof(a);
        vm.prank(buyer);
        sale.purchasePrivate{ value: 1000 }(a, proof);
        require(core.ownerOf(1) == buyer);
    }

    function testRelayedFullOfferRevocationConsumesExactOriginalBuyerLane() external {
        StreamPrivateSaleTypes.SaleOffer memory offer = _offer(1, buyer, 1000);
        bytes32 digest = sale.offerDigest(offer);
        bytes memory original = _signature(BUYER_KEY, digest);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamPrivateSaleAdapter.PrivateSaleAuthorityInvalid.selector, buyer
            )
        );
        sale.revokeOffer(offer, 1, original);
        bytes32 revocation = _domainDigest(
            keccak256(
                abi.encode(
                    bytes32(0xb80f6e5d7ac663ccfb28bbcfae73c4b3111804ebe80d7ac845e1eb88a44d191c),
                    block.chainid,
                    address(sale),
                    digest
                )
            )
        );
        sale.revokeOffer(offer, 1, _signature(BUYER_KEY, revocation));
        require(sale.digestRevoked(digest) && sale.digestConsumed(digest));
        bytes32 id = sale.registerSale(_config(6, 1, buyer, digest));
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(id, buyer, 1000);
        IStreamPrivateSaleAdapter.Signature memory proof = _platformProof(a);
        IStreamPrivateSaleAdapter.Signature memory buyerProof =
            IStreamPrivateSaleAdapter.Signature(buyer, 1, original);
        StreamPrivateSaleTypes.SaleCustodyGrant memory g = _grant(1, digest);
        bytes memory grantSignature = _signature(OWNER_KEY, sale.custodyGrantDigest(g));
        bytes32 ad = sale.authorizationDigest(a);
        vm.prank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamPrivateSaleAdapter.PrivateSaleDigestConsumed.selector, digest
            )
        );
        sale.acceptOffer{ value: 1000 }(a, proof, offer, buyerProof, g, 1, grantSignature);
        require(
            !sale.digestConsumed(ad) && core.ownerOf(1) == consignor && sale.totalLiabilities() == 0
        );
    }

    function testRelayedFullOwnerGrantRevocationAfterDepositCannotRedirectRecovery() external {
        bytes32 id = sale.registerSale(_config(5, 1, buyer, 0));
        StreamPrivateSaleTypes.SaleCustodyGrant memory g = _grant(1, id);
        bytes32 digest = sale.custodyGrantDigest(g);
        bytes memory original = _signature(OWNER_KEY, digest);
        sale.depositCustody(id, g, 1, original);
        require(core.ownerOf(1) == address(sale));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamPrivateSaleAdapter.PrivateSaleAuthorityInvalid.selector, consignor
            )
        );
        sale.revokeCustodyGrant(g, 1, original);
        bytes32 revocation = _domainDigest(
            keccak256(
                abi.encode(
                    bytes32(0x56747c6d524c5e2b5568c382f06c2f3c787067868f362f65933656e7a67e8344),
                    block.chainid,
                    address(sale),
                    consignor,
                    digest
                )
            )
        );
        sale.revokeCustodyGrant(g, 1, _signature(OWNER_KEY, revocation));
        require(
            sale.digestRevoked(digest) && sale.saleDetails(id).status == 4
                && sale.saleDetails(id).nftClaim == 2
        );
        sale.retryNft(id);
        require(core.ownerOf(1) == consignor && sale.saleDetails(id).nftClaim == 0);
    }
}
