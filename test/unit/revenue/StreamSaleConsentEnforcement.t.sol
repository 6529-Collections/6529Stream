// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/NativeSettlementTestBase.sol";

/// @dev Real sale/recorder/payment/Safe contracts with the explicit artist-consent domain seam.
///      Canonical op16 signatures, archive records and current Core remain integration proof.
contract StreamSaleConsentEnforcementTest is NativeSettlementTestBase {
    function _config(uint8 kind, uint256 minimum, uint256 maximum, uint64 limit)
        internal
        view
        returns (IStreamNativePricePrograms.PriceProgramConfig memory c)
    {
        c = IStreamNativePricePrograms.PriceProgramConfig(
            1, PHASE, kind, minimum, maximum, limit, 0, 10_000, 1, manager.POLICY(), bytes32(0)
        );
        if (kind != 12) {
            c.primaryAssignmentHash = resolver.resolvePrimaryAssignment(1, 0, CLASS).assignmentHash;
        }
    }

    function _program(uint8 kind, uint256 minimum, uint256 maximum, uint64 limit)
        internal
        returns (bytes32)
    {
        return nativeSale.registerPriceProgram(_config(kind, minimum, maximum, limit));
    }

    function _execution(bytes32 id, uint256 number, uint256 chosen, uint256 signedPrice)
        internal
        returns (IStreamNativePricePrograms.PriceProgramExecution memory e)
    {
        e.chosenUnitPrice = chosen;
        e.tokenData = abi.encode("price artwork", number);
        bytes32 primary;
        if (nativeSale.priceProgramRecord(id).config.kind != 12) {
            primary = StreamSaleTemplate.policyHash(
                resolver, 1, StreamNativeSettlementSupport.rights(resolver, 1)
            );
        }
        e.authorization = IStreamNativePricePrograms.PriceProgramAuthorization(
            id,
            nativeSale.priceProgramRecord(id).configHash,
            payer,
            payer,
            payer,
            artist,
            keccak256(e.tokenData),
            keccak256(abi.encode("price mint", number)),
            number,
            bytes32(number),
            uint64(block.timestamp + 1 hours),
            primary,
            signedPrice
        );
        _programSign(e);
    }

    function _programSign(IStreamNativePricePrograms.PriceProgramExecution memory e) internal {
        bytes32 digest = nativeSale.priceProgramAuthorizationDigest(e.authorization);
        e.platformSignature = _sign(PLATFORM_KEY, digest);
        e.artistSignature = _sign(ARTIST_KEY, digest);
    }

    function _execute(IStreamNativePricePrograms.PriceProgramExecution memory e)
        internal
        returns (IStreamNativePricePrograms.PriceProgramResult memory)
    {
        vm.prank(e.authorization.payer);
        return nativeSale.executePriceProgram{ value: e.chosenUnitPrice }(e);
    }

    function _consentError(bytes32 id) private view returns (bytes memory) {
        return abi.encodeWithSelector(
            StreamSaleConsent.SaleConsentNotSatisfied.selector, address(artists), uint256(1), id
        );
    }

    function _allow(address adapter, bytes32 id, bytes32 hash) private {
        artists.recordTestSaleConsent(adapter, 1, id, hash, true);
    }

    function testFixedRequiredConsentPrecedesSignatureAndExactCallerHashCannotBeSubstituted()
        public
    {
        (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,) =
            _nativeExecution(payer, payer, 1);
        bytes memory signature = e.platformSignature;
        e.platformSignature = hex"00";
        artists.configureSaleConsent(true, 0);
        _allow(address(sale), nativeId, e.authorization.saleConfigHash);
        _allow(address(nativeSale), nativeId, bytes32(uint256(7)));
        vm.expectRevert(_consentError(nativeId));
        nativeSale.previewExecution(e);
        require(
            manager.nonce() == 0 && wallet.balance == 0
                && !nativeSale.authorizationUsed(artist, e.authorization.nonce),
            "precheck before effects"
        );
        _allow(address(nativeSale), nativeId, e.authorization.saleConfigHash);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeFixedPriceSaleAdapter.NativeSaleSignatureInvalid.selector,
                vm.addr(PLATFORM_KEY)
            )
        );
        nativeSale.previewExecution(e);
        e.platformSignature = signature;
        vm.prank(payer);
        nativeSale.purchase{ value: 1000 }(e);
        require(
            manager.nonce() == 1 && wallet.balance == 1000,
            "same authentic signed execution succeeds"
        );
    }

    function testEveryImmediateProgramIncludingFreeAndPWYWEnforcesElection() public {
        uint8[4] memory kinds = [uint8(0), 1, 12, 13];
        artists.configureSaleConsent(true, 0);
        for (uint256 i; i < kinds.length; ++i) {
            bool free = kinds[i] == 12;
            bytes32 id = _program(kinds[i], free ? 0 : 1000, free ? 0 : 1000, kinds[i] == 1 ? 0 : 3);
            IStreamNativePricePrograms.PriceProgramExecution memory e =
                _execution(id, i + 1, free ? 0 : 1000, free ? 0 : 1000);
            vm.prank(payer);
            vm.expectRevert(_consentError(id));
            nativeSale.executePriceProgram{ value: e.chosenUnitPrice }(e);
            require(
                !nativeSale.authorizationUsed(artist, e.authorization.nonce),
                "blocked program nonce untouched"
            );
            _allow(address(nativeSale), id, e.authorization.saleConfigHash);
            _execute(e);
        }
        require(
            manager.nonce() == 4 && wallet.balance == 3000
                && recorder.totalOfficialSettled(address(0)) == 3000,
            "free and three paid paths"
        );
    }

    function testNativeReceiverCallbackCannotElectRequiredAfterMoneyWithoutRollback() public {
        NativeSettlementReceiver receiver = new NativeSettlementReceiver();
        receiver.configure(
            false,
            address(artists),
            abi.encodeCall(SaleFundingArtistMock.configureSaleConsent, (true, 0)),
            wallet
        );
        (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,) =
            _nativeExecution(payer, address(receiver), 1);
        uint256 payerBefore = payer.balance;
        vm.prank(payer);
        vm.expectRevert(_consentError(nativeId));
        nativeSale.purchase{ value: 1000 }(e);
        require(
            payer.balance == payerBefore && wallet.balance == 0 && manager.nonce() == 0
                && recorder.totalOfficialSettled(address(0)) == 0,
            "entire funding/mint rollback"
        );
        require(
            !artists.saleConsentRequired() && receiver.observedBalance() == 0,
            "callback effects rolled back"
        );
        _allow(address(nativeSale), nativeId, e.authorization.saleConfigHash);
        vm.prank(payer);
        nativeSale.purchase{ value: 1000 }(e);
        require(
            receiver.observedBalance() == 1000 && artists.saleConsentRequired()
                && manager.nonce() == 1,
            "same bytes exact retry"
        );
    }

    function testFreeReceiverCallbackAlsoRechecksConsentAndRestoresNonce() public {
        bytes32 id = _program(12, 0, 0, 3);
        NativeSettlementReceiver receiver = new NativeSettlementReceiver();
        receiver.configure(
            false,
            address(artists),
            abi.encodeCall(SaleFundingArtistMock.configureSaleConsent, (true, 0)),
            wallet
        );
        IStreamNativePricePrograms.PriceProgramExecution memory e = _execution(id, 1, 0, 0);
        e.authorization.recipient = address(receiver);
        _programSign(e);
        vm.prank(payer);
        vm.expectRevert(_consentError(id));
        nativeSale.executePriceProgram(e);
        require(
            manager.nonce() == 0 && nativeSale.priceProgramRecord(id).mintedQuantity == 0
                && !nativeSale.authorizationUsed(artist, e.authorization.nonce),
            "free branch rollback"
        );
        _allow(address(nativeSale), id, e.authorization.saleConfigHash);
        _execute(e);
        require(
            manager.nonce() == 1 && recorder.totalOfficialSettled(address(0)) == 0,
            "free exact retry no official revenue"
        );
    }

    function testRevertingAndMalformedConsentReadsNeverBecomeNone() public {
        (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,) =
            _nativeExecution(payer, payer, 1);
        for (uint256 fault = 1; fault <= 3; ++fault) {
            artists.configureSaleConsent(false, fault);
            vm.prank(payer);
            vm.expectRevert(_consentError(nativeId));
            nativeSale.purchase{ value: 1000 }(e);
            require(manager.nonce() == 0 && wallet.balance == 0, "malformed read failed closed");
        }
        artists.configureSaleConsent(false, 0);
        vm.prank(payer);
        nativeSale.purchase{ value: 1000 }(e);
        require(manager.nonce() == 1, "healthy NONE is explicitly accepted");
    }

    function testUniversalConsentBeforeActualPayerPullAndExactFacts() public {
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, payer, payer, 1);
        (uint256 collection, bytes32 hash) = sale.saleConsentFacts(saleId);
        require(
            collection == 1 && hash == e.authorization.saleConfigHash
                && sale.streamModuleType() == keccak256("FIXED_PRICE_SALE_ADAPTER")
                && sale.streamModuleInterfaceId() == type(IStreamERC20SaleExecution).interfaceId,
            "actual universal facts/declaration"
        );
        artists.configureSaleConsent(true, 0);
        vm.expectRevert(_consentError(saleId));
        sale.previewExecution(e);
        uint256 beforeBalance = token.balanceOf(payer);
        vm.prank(payer);
        (bool ok,) = address(payment)
            .call(
                abi.encodeCall(
                    IStreamERC20PrimarySettlementAdapter.settleERC20PrimarySaleByPayer,
                    (c, abi.encode(e))
                )
            );
        require(
            !ok && token.balanceOf(payer) == beforeBalance && token.balanceOf(wallet) == 0
                && manager.nonce() == 0 && recorder.totalOfficialSettled(address(token)) == 0,
            "20 callback failure rolls back without pull"
        );
        _allow(address(sale), saleId, hash);
        vm.prank(payer);
        payment.settleERC20PrimarySaleByPayer(c, abi.encode(e));
        require(
            token.balanceOf(payer) == beforeBalance - 1000 && manager.nonce() == 1,
            "same exact candidate succeeds"
        );
    }

    function testUniversalRecipientCallbackCannotInvalidateConsentAfterMint() public {
        NativeSettlementReceiver receiver = new NativeSettlementReceiver();
        receiver.configure(
            false,
            address(artists),
            abi.encodeCall(SaleFundingArtistMock.configureSaleConsent, (true, 0)),
            wallet
        );
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, payer, address(receiver), 1);
        vm.prank(payer);
        (bool ok,) = address(payment)
            .call(
                abi.encodeCall(
                    IStreamERC20PrimarySettlementAdapter.settleERC20PrimarySaleByPayer,
                    (c, abi.encode(e))
                )
            );
        require(
            !ok && manager.nonce() == 0 && token.balanceOf(wallet) == 0
                && recorder.totalOfficialSettled(address(token)) == 0
                && !sale.authorizationUsed(artist, e.authorization.nonce),
            "post-mint gate atomic rollback"
        );
        _allow(address(sale), saleId, e.authorization.saleConfigHash);
        vm.prank(payer);
        payment.settleERC20PrimarySaleByPayer(c, abi.encode(e));
        require(
            manager.nonce() == 1 && token.balanceOf(wallet) == 1000
                && artists.saleConsentRequired(),
            "callback permitted with exact record"
        );
    }

    function testActualSafeRequiredNativePurchaseAndUniversalFactSelectors() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x6529;
        keys[1] = 0xB0B;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 556);
        vm.deal(address(safe), 1000);
        (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,) =
            _nativeExecution(address(safe), address(safe), 1);
        artists.configureSaleConsent(true, 0);
        _allow(address(nativeSale), nativeId, e.authorization.saleConfigHash);
        require(
            executeSafe(
                safe,
                keys,
                address(nativeSale),
                1000,
                abi.encodeCall(IStreamNativeFixedPriceSaleAdapter.purchase, (e)),
                0
            ),
            "actual threshold Safe purchase"
        );
        require(
            manager.ownerOf(1) == address(safe) && address(safe).balance == 0
                && wallet.balance == 1000,
            "Safe protocol state changed"
        );
        bytes[3] memory calls = [
            abi.encodeCall(IStreamArtistSaleFacts.saleConsentFacts, (saleId)),
            abi.encodeCall(StreamUniversalFixedPriceSaleAdapter.streamModuleType, ()),
            abi.encodeCall(StreamUniversalFixedPriceSaleAdapter.streamModuleInterfaceId, ())
        ];
        for (uint256 i; i < calls.length; ++i) {
            (bool ok, bytes memory ordinary) = address(sale).staticcall(calls[i]);
            vm.prank(address(safe));
            (bool safeOk, bytes memory actual) = address(sale).staticcall(calls[i]);
            require(
                ok && safeOk && ordinary.length == (i == 0 ? 64 : 32)
                    && keccak256(actual) == keccak256(ordinary),
                "Safe exact fact read"
            );
            require(
                executeSafe(safe, keys, address(sale), 0, calls[i], 0), "actual Safe fact execution"
            );
        }
        require(safe.nonce() == 4 && manager.nonce() == 1, "only one protocol mint");
    }
}
