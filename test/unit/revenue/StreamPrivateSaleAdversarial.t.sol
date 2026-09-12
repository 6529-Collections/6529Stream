// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/PrivateSaleTestBase.sol";

contract PrivateSaleForcedValue {
    constructor(address payable target) payable {
        selfdestruct(target);
    }
}

contract StreamPrivateSaleAdversarialTest is PrivateSaleTestBase {
    function testEveryBoundAuthorizationFieldRejectsFreshValidSignatureDrift() external {
        bytes32 id = sale.registerSale(_config(5, 1, buyer, 0));
        _deposit(id);
        StreamPrivateSaleTypes.SaleAuthorization memory original = _authorization(id, buyer, 1000);
        for (uint256 i; i < 24; ++i) {
            if (i == 21) continue; // A genuinely new nonce is a new authorization, not invalid field drift.
            StreamPrivateSaleTypes.SaleAuthorization memory a =
                abi.decode(abi.encode(original), (StreamPrivateSaleTypes.SaleAuthorization));
            assembly ("memory-safe") {
                let ptr := add(a, mul(i, 32))
                mstore(ptr, add(mload(ptr), 1))
            }
            IStreamPrivateSaleAdapter.Signature memory proof = _platformProof(a);
            vm.prank(buyer);
            (bool ok,) =
                address(sale).call{ value: 1000 }(abi.encodeCall(sale.purchasePrivate, (a, proof)));
            require(!ok && !sale.digestConsumed(sale.authorizationDigest(a)));
            require(sale.saleDetails(id).status == 2 && address(sale).balance == 0);
        }
        _purchase(id, 1000);
        require(core.ownerOf(1) == buyer);
    }

    function testGuardianPauseUnpauseSeparationKeepsCreditsAndAbsoluteExpiryLive() external {
        address guardian = address(0x810);
        address unpauser = address(0x811);
        roles.grant(keccak256("ROLE_PAUSE_GUARDIAN"), guardian);
        roles.grant(keccak256("ROLE_UNPAUSE"), unpauser);
        bytes32 id = sale.registerSale(_config(5, 1, buyer, 0));
        _deposit(id);
        vm.prank(guardian);
        sale.pauseSale(id, keccak256("review"));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamPrivateSaleAdapter.PrivateSaleRoleNotAuthorized.selector,
                keccak256("ROLE_UNPAUSE"),
                guardian
            )
        );
        vm.prank(guardian);
        sale.unpauseSale(id, 0);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(id, buyer, 1000);
        IStreamPrivateSaleAdapter.Signature memory proof = _platformProof(a);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamPrivateSaleAdapter.PrivateSalePaused.selector, id)
        );
        vm.prank(buyer);
        sale.purchasePrivate{ value: 1000 }(a, proof);
        vm.prank(unpauser);
        sale.unpauseSale(id, 0);
        _purchase(id, 1009);
        vm.prank(guardian);
        sale.pauseAdapter(0);
        vm.prank(buyer);
        sale.claimRefund(id, buyer);
        require(
            sale.refundableBalance(id, buyer) == 0 && sale.refundableBalance(id, consignor) == 900
        );
        vm.prank(unpauser);
        sale.unpauseAdapter(0);
        core.mint(consignor, 2);
        bytes32 second = sale.registerSale(_config(5, 2, buyer, 0));
        _deposit(second);
        vm.prank(guardian);
        sale.pauseAdapter(0);
        vm.warp(2000);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamPrivateSaleAdapter.PrivateSaleUnavailable.selector, second
            )
        );
        sale.expireSale(second);
        vm.warp(2001);
        sale.expireSale(second);
        require(sale.retryNft(second));
        require(core.ownerOf(2) == consignor && sale.saleDetails(second).config.deadline == 2000);
    }

    function testKnownIncidentBlocksPurchaseAndClaimsRemainIndependent() external {
        bytes32 id = sale.registerSale(_config(5, 1, buyer, 0));
        _deposit(id);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(id, buyer, 1000);
        IStreamPrivateSaleAdapter.Signature memory proof = _platformProof(a);
        _status(ModuleRegistryStatus.INCIDENT_REVOKED);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamPrivateSaleAdapter.PrivateSaleModuleNotAdmitted.selector)
        );
        vm.prank(buyer);
        sale.purchasePrivate{ value: 1000 }(a, proof);
        require(!sale.digestConsumed(sale.authorizationDigest(a)) && sale.totalLiabilities() == 0);
        _status(ModuleRegistryStatus.ACTIVE);
        vm.prank(buyer);
        sale.purchasePrivate{ value: 1007 }(a, proof);
        _status(ModuleRegistryStatus.INCIDENT_REVOKED);
        vm.prank(consignor);
        sale.claimRefund(id, consignor);
        vm.prank(buyer);
        sale.claimRefund(id, buyer);
        require(sale.totalLiabilities() == 0 && core.ownerOf(1) == buyer);
    }

    function enterIncident() external {
        require(msg.sender == address(royalty));
        _status(ModuleRegistryStatus.INCIDENT_REVOKED);
    }

    function testRoyaltyCallbackIncidentRollsBackCustodyMoneyAndSameProofRetries() external {
        bytes32 cap = keccak256("6529STREAM_GGP_SALE_ROYALTY_DELIVERY_GAS_LIMIT");
        _raiseGas(cap, 200000);
        _raiseGas(cap, 400000);
        bytes32 id = sale.registerSale(_config(5, 1, buyer, 0));
        _deposit(id);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(id, buyer, 1000);
        IStreamPrivateSaleAdapter.Signature memory proof = _platformProof(a);
        // Registry mutation uses the explicit target-side governance context fixture.
        royalty.configureCallback(address(this), abi.encodeCall(this.enterIncident, ()));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamPrivateSaleAdapter.PrivateSaleModuleNotAdmitted.selector)
        );
        vm.prank(buyer);
        sale.purchasePrivate{ value: 1000 }(a, proof);
        require(registry.moduleRecord(address(sale)).status == ModuleRegistryStatus.ACTIVE);
        require(
            sale.saleDetails(id).status == 2 && !sale.digestConsumed(sale.authorizationDigest(a))
        );
        require(address(royalty).balance == 0 && core.ownerOf(1) == address(sale));
        royalty.configureCallback(address(0), "");
        vm.prank(buyer);
        sale.purchasePrivate{ value: 1000 }(a, proof);
        require(core.ownerOf(1) == buyer);
    }

    function testRoyaltyCreditorHasValidReentrantClaimButGuardRejectsExactError() external {
        core.mint(address(royalty), 2);
        royalty.execute(
            address(core), 0, abi.encodeCall(core.setApprovalForAll, (address(sale), true))
        );
        IStreamPrivateSaleAdapter.SaleConfig memory c = _config(5, 2, buyer, 0);
        c.consignor = address(royalty);
        bytes32 id = sale.registerSale(c);
        StreamPrivateSaleTypes.SaleCustodyGrant memory g = _grant(2, id);
        g.owner = address(royalty);
        royalty.execute(
            address(sale), 0, abi.encodeCall(sale.depositCustody, (id, g, uint8(2), bytes("")))
        );
        royalty.configureCallback(
            address(sale), abi.encodeCall(sale.claimRefund, (id, address(royalty)))
        );
        _purchase(id, 1000);
        require(!royalty.callbackSucceeded());
        require(
            keccak256(royalty.callbackResult())
                == keccak256(abi.encodeWithSignature("ReentrancyGuardReentrantCall()"))
        );
        require(
            sale.refundableBalance(id, address(royalty)) == 900 && address(royalty).balance == 100
        );
        royalty.configureCallback(address(0), "");
        royalty.execute(address(sale), 0, abi.encodeCall(sale.claimRefund, (id, address(royalty))));
        require(address(royalty).balance == 1000 && sale.totalLiabilities() == 0);
    }

    function testCoincidentBuyerConsignorRoyaltyClaimsAllBucketsAndIsolatesOtherSale() external {
        PrivateSaleRecipient account = new PrivateSaleRecipient();
        account.configure(true, false);
        vm.deal(address(account), 3000);
        core.setRoyalty(address(account), 1000, false);
        core.mint(address(account), 2);
        core.mint(address(account), 3);
        account.execute(
            address(core), 0, abi.encodeCall(core.setApprovalForAll, (address(sale), true))
        );
        bytes32[2] memory ids;
        for (uint256 i; i < 2; ++i) {
            IStreamPrivateSaleAdapter.SaleConfig memory c = _config(5, i + 2, address(account), 0);
            c.consignor = address(account);
            bytes32 id = sale.registerSale(c);
            ids[i] = id;
            StreamPrivateSaleTypes.SaleCustodyGrant memory g = _grant(i + 2, id);
            g.owner = address(account);
            account.execute(
                address(sale), 0, abi.encodeCall(sale.depositCustody, (id, g, uint8(2), bytes("")))
            );
            StreamPrivateSaleTypes.SaleAuthorization memory a =
                _authorization(id, address(account), 1000);
            account.execute(
                address(sale), 1017, abi.encodeCall(sale.purchasePrivate, (a, _platformProof(a)))
            );
            require(sale.refundableBalance(id, address(account)) == 1017);
        }
        vm.deal(address(this), 77);
        new PrivateSaleForcedValue{ value: 77 }(payable(address(sale)));
        require(address(sale).balance == 2111 && sale.totalLiabilities() == 2034);
        account.execute(address(sale), 0, abi.encodeCall(sale.claimRefund, (ids[0], buyer)));
        require(sale.refundableBalance(ids[0], address(account)) == 0);
        require(
            sale.refundableBalance(ids[1], address(account)) == 1017
                && sale.totalLiabilities() == 1017
        );
        require(address(sale).balance == 1094);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamPrivateSaleAdapter.PrivateSaleClaimUnavailable.selector)
        );
        sale.retryRoyalty(ids[0]);
        account.configure(false, false);
        require(sale.retryRoyalty(ids[1]));
        require(
            sale.refundableBalance(ids[1], address(account)) == 917
                && sale.totalLiabilities() == 917
        );
        account.execute(
            address(sale), 0, abi.encodeCall(sale.claimRefund, (ids[1], address(account)))
        );
        require(sale.totalLiabilities() == 0 && address(sale).balance == 77);
    }

    function testUnsoldOriginalOwnerCanDirectRecoveryButPermissionlessRetryCannotRedirect()
        external
    {
        PrivateSaleRecipient account = new PrivateSaleRecipient();
        account.configure(false, true);
        core.mint(address(account), 2);
        account.execute(
            address(core), 0, abi.encodeCall(core.setApprovalForAll, (address(sale), true))
        );
        IStreamPrivateSaleAdapter.SaleConfig memory c = _config(5, 2, buyer, 0);
        c.consignor = address(account);
        bytes32 id = sale.registerSale(c);
        StreamPrivateSaleTypes.SaleCustodyGrant memory g = _grant(2, id);
        g.owner = address(account);
        account.execute(
            address(sale), 0, abi.encodeCall(sale.depositCustody, (id, g, uint8(2), bytes("")))
        );
        account.execute(
            address(sale), 0, abi.encodeCall(sale.revokeCustodyGrant, (g, uint8(2), bytes("")))
        );
        require(!sale.retryNft(id) && core.ownerOf(2) == address(sale));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamPrivateSaleAdapter.PrivateSaleClaimUnavailable.selector)
        );
        sale.claimNft(id, buyer);
        account.execute(address(sale), 0, abi.encodeCall(sale.claimNft, (id, buyer)));
        require(core.ownerOf(2) == buyer && sale.saleDetails(id).nftClaim == 0);
    }

    function testPreMintIdentityCannotEnterCustodyAndSameConfigSucceedsWhenMinted() external {
        core.setLifecycle(1, 1);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamPrivateSaleAdapter.PrivateSaleTokenInvalid.selector, 1)
        );
        sale.registerSale(_config(5, 1, buyer, 0));
        require(sale.nextSaleNonce() == 1);
        core.setLifecycle(1, 2);
        bytes32 id = sale.registerSale(_config(5, 1, buyer, 0));
        _deposit(id);
        _purchase(id, 1000);
        require(core.ownerOf(1) == buyer);
    }
}
