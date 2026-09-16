// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/PrivateSaleTestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";

interface PrivateSafeMockVm {
    function mockCall(address target, bytes calldata data, bytes calldata result) external;
    function clearMockedCalls() external;
}

contract StreamPrivateSaleSafeTest is PrivateSaleTestBase, OfficialSafeFixture {
    OfficialSafe private sellerSafe;
    OfficialSafe private buyerSafe;
    uint256[] private sellerKeys;
    uint256[] private buyerKeys;

    function _safes() private {
        SafeComponents memory c = deploySafeComponents("1.4.1");
        uint256[] memory owners = new uint256[](3);
        owners[0] = 0xA51;
        owners[1] = 0xA52;
        owners[2] = 0xA53;
        sellerSafe = createOfficialSafe(c, safeOwnerAddresses(owners), 2, 120);
        sellerKeys = new uint256[](2);
        sellerKeys[0] = owners[0];
        sellerKeys[1] = owners[2];
        owners[0] = 0xB51;
        owners[1] = 0xB52;
        owners[2] = 0xB53;
        buyerSafe = createOfficialSafe(c, safeOwnerAddresses(owners), 2, 121);
        buyerKeys = new uint256[](2);
        buyerKeys[0] = owners[0];
        buyerKeys[1] = owners[1];
        sale = _newSale(address(sellerSafe), address(sellerSafe));
        _register();
        _exec(
            sellerSafe,
            sellerKeys,
            0,
            abi.encodeCall(
                sale.configureCollectionSigner,
                (uint256(1), keccak256("explicit collection signer authority"), true)
            )
        );
        vm.prank(consignor);
        core.transferFrom(consignor, address(sellerSafe), 1);
        consignor = address(sellerSafe);
        buyer = address(buyerSafe);
        platform = address(sellerSafe);
        require(
            executeSafe(
                sellerSafe,
                sellerKeys,
                address(core),
                0,
                abi.encodeCall(core.setApprovalForAll, (address(sale), true)),
                0
            )
        );
        vm.deal(address(buyerSafe), 10000);
    }

    function _exec(OfficialSafe who, uint256[] memory keys, uint256 value, bytes memory data)
        private
    {
        uint256 nonce = who.nonce();
        require(executeSafe(who, keys, address(sale), value, data, 0));
        require(who.nonce() == nonce + 1);
    }

    // Foundry must observe this outer call, before the Safe helper's nonce/hash reads.
    function executeSafeFailure(uint256 value, bytes calldata data) external {
        require(msg.sender == address(this));
        require(executeSafe(buyerSafe, buyerKeys, address(sale), value, data, 0));
    }

    function _registerSafeSale(uint8 kind, bytes32 offerHash) private returns (bytes32 id) {
        IStreamPrivateSaleAdapter.SaleConfig memory config = _config(kind, 1, buyer, offerHash);
        config.signerAuthority = address(sellerSafe);
        id = sale.saleIdFor(kind, 1, sale.nextSaleNonce());
        _exec(sellerSafe, sellerKeys, 0, abi.encodeCall(sale.registerSale, (config)));
        require(sale.saleDetails(id).config.signerAuthority == address(sellerSafe));
    }

    function _wrapped(OfficialSafe account, uint256[] memory keys, bytes32 digest)
        private
        returns (bytes memory)
    {
        return safeThresholdSignature(keys, safeMessageDigest(account, abi.encode(digest)));
    }

    function testActualTwoOfThreeSafesSignBothOfferSidesAndOwnerGrantWithNativeCustodyPayment()
        external
    {
        _safes();
        StreamPrivateSaleTypes.SaleOffer memory offer = _offer(1, buyer, 1000);
        bytes32 od = sale.offerDigest(offer);
        bytes32 id = _registerSafeSale(6, od);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(id, buyer, 1000);
        StreamPrivateSaleTypes.SaleCustodyGrant memory g = _grant(1, od);
        bytes32 ad = sale.authorizationDigest(a);
        IStreamPrivateSaleAdapter.Signature memory ap = IStreamPrivateSaleAdapter.Signature(
            platform, 2, safeThresholdSignature(sellerKeys, ad)
        );
        IStreamPrivateSaleAdapter.Signature memory bp =
            IStreamPrivateSaleAdapter.Signature(buyer, 2, _wrapped(buyerSafe, buyerKeys, od));
        bytes memory gp = _wrapped(sellerSafe, sellerKeys, sale.custodyGrantDigest(g));
        uint256 nonce = buyerSafe.nonce();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeSafeFailure(
            1000, abi.encodeCall(sale.acceptOffer, (a, ap, offer, bp, g, uint8(2), gp))
        );
        require(
            buyerSafe.nonce() == nonce && core.ownerOf(1) == consignor && !sale.digestConsumed(ad)
        );
        ap.signature = _wrapped(sellerSafe, sellerKeys, ad);
        _exec(
            buyerSafe,
            buyerKeys,
            1027,
            abi.encodeCall(sale.acceptOffer, (a, ap, offer, bp, g, uint8(2), gp))
        );
        require(core.ownerOf(1) == buyer && sale.digestConsumed(ad) && sale.digestConsumed(od));
        require(
            sale.refundableBalance(id, consignor) == 900 && sale.refundableBalance(id, buyer) == 27
        );
        _exec(buyerSafe, buyerKeys, 0, abi.encodeCall(sale.claimRefund, (id, buyer)));
        _exec(sellerSafe, sellerKeys, 0, abi.encodeCall(sale.claimRefund, (id, consignor)));
        require(
            sale.totalLiabilities() == 0 && address(sellerSafe).balance == 900
                && address(royalty).balance == 100
        );
    }

    function testActualSafeDirectFullPayloadRevocationsAndUnsoldRecovery() external {
        _safes();
        bytes32 id = _registerSafeSale(5, 0);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(id, buyer, 1000);
        _exec(
            sellerSafe,
            sellerKeys,
            0,
            abi.encodeCall(
                sale.revokeAuthorization, (a, IStreamPrivateSaleAdapter.Signature(platform, 2, ""))
            )
        );
        require(sale.digestRevoked(sale.authorizationDigest(a)));
        StreamPrivateSaleTypes.SaleOffer memory offer = _offer(1, buyer, 1000);
        _exec(
            buyerSafe, buyerKeys, 0, abi.encodeCall(sale.revokeOffer, (offer, uint8(2), bytes("")))
        );
        require(sale.digestRevoked(sale.offerDigest(offer)));
        StreamPrivateSaleTypes.SaleCustodyGrant memory g = _grant(1, id);
        _exec(
            sellerSafe,
            sellerKeys,
            0,
            abi.encodeCall(sale.depositCustody, (id, g, uint8(2), bytes("")))
        );
        _exec(
            sellerSafe,
            sellerKeys,
            0,
            abi.encodeCall(sale.revokeCustodyGrant, (g, uint8(2), bytes("")))
        );
        require(sale.saleDetails(id).nftClaim == 2 && core.ownerOf(1) == address(sale));
        _exec(sellerSafe, sellerKeys, 0, abi.encodeCall(sale.claimNft, (id, address(buyerSafe))));
        require(core.ownerOf(1) == address(buyerSafe));
    }

    function testActualSafeCallerSensitiveDomainAndAccountingReadsMatchTheirReturnValues()
        external
    {
        _safes();
        bytes32 id = _registerSafeSale(5, 0);
        bytes[] memory calls = new bytes[](39);
        calls[0] = abi.encodeCall(sale.FAILURE_CLASS_FAIL_CLOSED_PRECHECK, ());
        calls[1] = abi.encodeCall(sale.FAILURE_CLASS_FORWARDING_CAP, ());
        calls[2] = abi.encodeCall(sale.FAILURE_CLASS_MIN_GAS_GATE, ());
        calls[3] = abi.encodeCall(sale.FAILURE_CLASS_NONE, ());
        calls[4] = abi.encodeCall(sale.GAS_PARAMETER_SCHEMA_VERSION, ());
        calls[5] = abi.encodeCall(sale.authorizationDigest, (_authorization(id, buyer, 1000)));
        calls[6] = abi.encodeCall(sale.collectionSigner, (uint256(1)));
        calls[7] = abi.encodeCall(sale.core, ());
        calls[8] = abi.encodeCall(sale.coreCodeHash, ());
        calls[9] = abi.encodeCall(sale.creditBreakdown, (id, buyer));
        calls[10] = abi.encodeCall(sale.custodyGrantDigest, (_grant(1, id)));
        calls[11] = abi.encodeCall(sale.custodySaleLifecycle, (id));
        calls[12] = abi.encodeCall(sale.digestConsumed, (bytes32(uint256(1))));
        calls[13] = abi.encodeCall(sale.digestRevoked, (bytes32(uint256(1))));
        calls[14] = abi.encodeCall(sale.eip712Domain, ());
        calls[15] =
            abi.encodeCall(sale.gasParameter, (keccak256("6529STREAM_GGP_SALE_ERC1271_GAS_LIMIT")));
        calls[16] = abi.encodeCall(sale.gasParameterIds, ());
        calls[17] = abi.encodeCall(
            sale.gasParameterInfo, (keccak256("6529STREAM_GGP_SALE_ERC1271_GAS_LIMIT"))
        );
        calls[18] = abi.encodeCall(sale.governanceAuthority, ());
        calls[19] = abi.encodeCall(sale.moduleRegistry, ());
        calls[20] = abi.encodeCall(sale.nextSaleNonce, ());
        calls[21] = abi.encodeCall(sale.offerDigest, (_offer(1, buyer, 1000)));
        calls[22] = abi.encodeCall(sale.owner, ());
        calls[23] = abi.encodeCall(sale.paused, ());
        calls[24] = abi.encodeCall(sale.platformSigner, ());
        calls[25] = abi.encodeCall(sale.refundableBalance, (id, buyer));
        calls[26] = abi.encodeCall(sale.registryCodeHash, ());
        calls[27] = abi.encodeCall(sale.roleRegistry, ());
        calls[28] = abi.encodeCall(sale.roleRegistryCodeHash, ());
        calls[29] = abi.encodeCall(sale.royaltyQuote, (id));
        calls[30] = abi.encodeCall(sale.saleDetails, (id));
        calls[31] = abi.encodeCall(sale.saleIdFor, (uint8(5), uint256(1), uint256(1)));
        calls[32] = abi.encodeCall(sale.salePaused, (id));
        calls[33] = abi.encodeCall(sale.saleRecord, (id));
        calls[34] = abi.encodeCall(sale.streamModuleInterfaceId, ());
        calls[35] = abi.encodeCall(sale.streamModuleType, ());
        calls[36] = abi.encodeCall(sale.streamModuleVersion, ());
        calls[37] =
            abi.encodeCall(sale.supportsInterface, (type(IStreamPrivateSaleAdapter).interfaceId));
        calls[38] = abi.encodeCall(sale.totalLiabilities, ());
        for (uint256 i; i < calls.length; ++i) {
            (bool ok, bytes memory expected) = address(sale).staticcall(calls[i]);
            vm.prank(address(sellerSafe));
            (bool actual, bytes memory result) = address(sale).staticcall(calls[i]);
            require(ok && actual && keccak256(result) == keccak256(expected));
            _exec(sellerSafe, sellerKeys, 0, calls[i]);
        }
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeSafeFailure(
            0,
            abi.encodeCall(
                sale.configureCollectionSigner, (uint256(1), keccak256("unauthorized"), true)
            )
        );
    }

    function testActualSafePrivatePurchaseAndPermissionlessRoyaltyAndNftRetries() external {
        _safes();
        bytes32 id = _registerSafeSale(5, 0);
        StreamPrivateSaleTypes.SaleCustodyGrant memory g = _grant(1, id);
        _exec(
            sellerSafe,
            sellerKeys,
            0,
            abi.encodeCall(sale.depositCustody, (id, g, uint8(2), bytes("")))
        );
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(id, buyer, 1000);
        IStreamPrivateSaleAdapter.Signature memory proof = IStreamPrivateSaleAdapter.Signature(
            platform, 2, _wrapped(sellerSafe, sellerKeys, sale.authorizationDigest(a))
        );
        royalty.configure(true, false);
        // Only the receiver acknowledgement is fault-injected. Payment and Safe execution are real.
        PrivateSafeMockVm(address(vm))
            .mockCall(buyer, abi.encodeWithSelector(bytes4(0x150b7a02)), abi.encode(bytes4(0)));
        _exec(buyerSafe, buyerKeys, 1000, abi.encodeCall(sale.purchasePrivate, (a, proof)));
        require(sale.saleDetails(id).nftClaim == 1 && core.ownerOf(1) == address(sale));
        require(sale.refundableBalance(id, address(royalty)) == 100);
        PrivateSafeMockVm(address(vm)).clearMockedCalls();
        _exec(sellerSafe, sellerKeys, 0, abi.encodeCall(sale.retryNft, (id)));
        require(core.ownerOf(1) == buyer && sale.saleDetails(id).nftClaim == 0);
        _exec(buyerSafe, buyerKeys, 0, abi.encodeCall(sale.retryRoyalty, (id)));
        require(sale.refundableBalance(id, address(royalty)) == 100);
        royalty.configure(false, false);
        _exec(buyerSafe, buyerKeys, 0, abi.encodeCall(sale.retryRoyalty, (id)));
        require(
            sale.refundableBalance(id, address(royalty)) == 0 && address(royalty).balance == 100
        );
        _exec(sellerSafe, sellerKeys, 0, abi.encodeCall(sale.claimRefund, (id, consignor)));
        require(sale.totalLiabilities() == 0);
    }

    function testActualSafePauseOwnershipCancellationExpiryAndRejectedDirectGasRaise() external {
        _safes();
        bytes32 id = _registerSafeSale(5, 0);
        roles.grant(keccak256("ROLE_PAUSE_GUARDIAN"), address(sellerSafe));
        roles.grant(keccak256("ROLE_UNPAUSE"), address(buyerSafe));
        _exec(sellerSafe, sellerKeys, 0, abi.encodeCall(sale.pauseAdapter, (bytes32(uint256(1)))));
        require(sale.paused());
        _exec(buyerSafe, buyerKeys, 0, abi.encodeCall(sale.unpauseAdapter, (bytes32(uint256(2)))));
        _exec(sellerSafe, sellerKeys, 0, abi.encodeCall(sale.pauseSale, (id, bytes32(uint256(3)))));
        require(sale.salePaused(id));
        _exec(buyerSafe, buyerKeys, 0, abi.encodeCall(sale.unpauseSale, (id, bytes32(uint256(4)))));
        _exec(sellerSafe, sellerKeys, 0, abi.encodeCall(sale.cancelSale, (id)));
        require(sale.saleDetails(id).status == 4 && !sale.paused() && !sale.salePaused(id));
        bytes32 expiring = _registerSafeSale(5, 0);
        vm.warp(2001);
        _exec(buyerSafe, buyerKeys, 0, abi.encodeCall(sale.expireSale, (expiring)));
        require(sale.saleDetails(expiring).status == 5);
        uint256 nonce = buyerSafe.nonce();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeSafeFailure(
            0,
            abi.encodeCall(
                sale.raiseGasParameter,
                (keccak256("6529STREAM_GGP_SALE_ERC1271_GAS_LIMIT"), uint256(800000))
            )
        );
        require(buyerSafe.nonce() == nonce);
        _exec(sellerSafe, sellerKeys, 0, abi.encodeCall(sale.transferOwnership, (buyer)));
        require(sale.owner() == buyer);
        _exec(buyerSafe, buyerKeys, 0, abi.encodeCall(sale.renounceOwnership, ()));
        require(sale.owner() == address(0));
    }
}
