// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/NativeSettlementTestBase.sol";

/// @dev Deliberately has no requireSaleConsent implementation. The empty fallback reproduces
///      the unknown-void-selector boundary without changing code after any immutable pin.
contract AttributionOnlyEmptyConsentFallback is IStreamArtistAttribution, IERC165 {
    address public immutable override core;
    address public artist;

    constructor(address core_) {
        core = core_;
    }

    function accept(address value) external {
        artist = value;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamArtistAttribution).interfaceId || id == type(IERC165).interfaceId;
    }

    function acceptedArtist(uint256) external view returns (address) {
        return artist;
    }

    function attribution(uint256)
        external
        view
        returns (IStreamCollectionArtistRegistry.Attribution memory a)
    {
        a.artist = artist;
        if (artist != address(0)) {
            a.nominationHash = keccak256("binding");
            a.acceptanceHash = keccak256("acceptance");
        }
    }

    fallback() external { }
}

    contract StreamSaleConsentCapabilityTest is NativeSettlementTestBase {
        function _failure(bytes32 id) private view returns (bytes memory) {
            return abi.encodeWithSelector(
                StreamSaleConsent.SaleConsentNotSatisfied.selector, address(artists), uint256(1), id
            );
        }

        function _bindAttributionOnlyFacade() private {
            core = new UniversalCoreMock();
            artists =
                SaleFundingArtistMock(
                address(new AttributionOnlyEmptyConsentFallback(address(core)))
            );
            core.configure(address(artists), address(registry));
            manager = new UniversalManagerMock(address(core), address(registry));
            resolver = new StreamRevenueResolver(
                IStreamCore(address(core)),
                factory,
                address(revenueAuthority),
                artists,
                IStreamGasParameterHost.GasParameterConfig(
                    "ARTIST_BENEFICIARY_READ_GAS", 200_000, 50_000, 2
                )
            );
            vm.prank(address(revenueAuthority));
            resolver.transferOwnership(address(this));
            resolver.setPrimaryProfileAssignment(CLASS, 1, 1, profile, 0);
            artists.accept(artist);
            recorder = new StreamPrimarySaleSettlement(resolver, address(registry), escrow);
            _producer(true);
            payment = new StreamERC20PrimarySettlementAdapter(recorder, permit2, permit2.codehash);
            sale = new StreamUniversalFixedPriceSaleAdapter(
                IStreamMintManager(address(manager)), recorder, vm.addr(PLATFORM_KEY), artists
            );
            _register(
                address(payment),
                keccak256("ERC20_PRIMARY_SETTLEMENT_ADAPTER"),
                type(IStreamERC20PrimarySettlementAdapter).interfaceId
            );
            _register(
                address(sale),
                keccak256("FIXED_PRICE_SALE_ADAPTER"),
                type(IStreamERC20SaleExecution).interfaceId
            );
            saleId = sale.registerSale(
                IStreamUniversalFixedPriceSaleAdapter.SaleConfig(
                    address(payment),
                    1,
                    PHASE,
                    address(token),
                    1000,
                    0,
                    10_000,
                    manager.POLICY(),
                    _primaryPolicy()
                )
            );
            vm.prank(payer);
            token.approve(address(payment), 10_000);
            _nativeSale();
        }

        function _nativeWithoutPreview()
            private
            returns (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e)
        {
            e.tokenData = abi.encode("native artwork", uint256(1));
            e.authorization = IStreamNativeFixedPriceSaleAdapter.SaleAuthorization(
                nativeId,
                nativeSale.saleRecord(nativeId).configHash,
                payer,
                payer,
                payer,
                artist,
                keccak256(e.tokenData),
                keccak256("native commitment"),
                1,
                bytes32(uint256(1)),
                uint64(block.timestamp + 1 hours),
                StreamSaleTemplate.policyHash(
                    resolver, 1, StreamNativeSettlementSupport.rights(resolver, 1)
                )
            );
            _nativeSign(e);
        }

        function _universalWithoutPreview()
            private
            returns (IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e)
        {
            e.tokenData = abi.encode("universal artwork", uint256(1));
            e.authorization = IStreamUniversalFixedPriceSaleAdapter.SaleAuthorization(
                saleId,
                sale.saleRecord(saleId).configHash,
                payer,
                payer,
                payer,
                artist,
                keccak256(e.tokenData),
                keccak256("universal commitment"),
                1,
                bytes32(uint256(1)),
                uint64(block.timestamp + 1 hours)
            );
            bytes32 digest = sale.authorizationDigest(e.authorization);
            e.platformSignature = _sign(PLATFORM_KEY, digest);
            e.artistSignature = _sign(ARTIST_KEY, digest);
        }

        function testActualPinnedAttributionOnlyEmptyFallbackCannotAuthorizeEitherConsumer()
            public
        {
            _bindAttributionOnlyFacade();
            require(
                IERC165(address(artists))
                    .supportsInterface(type(IStreamArtistAttribution).interfaceId),
                "attribution capability admitted"
            );
            require(
                !IERC165(address(artists)).supportsInterface(0x606af4b9), "sale capability absent"
            );
            require(
                nativeSale.artistRegistryCodeHash() == address(artists).codehash
                    && sale.artistRegistryCodeHash() == address(artists).codehash
                    && resolver.artistRegistry() == address(artists),
                "actual immutable facade pins"
            );
            (bool ok, bytes memory out) = address(artists)
                .staticcall(
                    abi.encodeWithSelector(
                        bytes4(0x96ca91c5),
                        uint256(1),
                        nativeId,
                        nativeSale.saleRecord(nativeId).configHash
                    )
                );
            require(ok && out.length == 0, "unknown consent really returns empty success");
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory n = _nativeWithoutPreview();
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory u =
                _universalWithoutPreview();
            vm.expectRevert(_failure(nativeId));
            nativeSale.previewExecution(n);
            vm.expectRevert(_failure(saleId));
            sale.previewExecution(u);
            uint256 beforeBalance = payer.balance;
            vm.prank(payer);
            vm.expectRevert(_failure(nativeId));
            nativeSale.purchase{ value: 1000 }(n);
            require(
                payer.balance == beforeBalance && manager.nonce() == 0 && wallet.balance == 0
                    && recorder.totalOfficialSettled(address(0)) == 0,
                "no native money/mint/accounting"
            );
            require(
                !nativeSale.authorizationUsed(artist, n.authorization.nonce)
                    && nativeSale.executionIdByNonce(nativeId, 1) == 0,
                "no replay consumption"
            );
        }

        function testOnlyCanonicalTrueCapabilityPermitsHealthyNoneAndExactRetries() public {
            (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory n,) =
                _nativeExecution(payer, payer, 1);
            (IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory u,) =
                _execution(payer, payer, payer, 1);
            for (uint256 fault = 1; fault <= 7; ++fault) {
                artists.configureSaleCapability(fault);
                vm.expectRevert(_failure(nativeId));
                nativeSale.previewExecution(n);
                vm.expectRevert(_failure(saleId));
                sale.previewExecution(u);
                vm.prank(payer);
                vm.expectRevert(_failure(nativeId));
                nativeSale.purchase{ value: 1000 }(n);
                require(
                    manager.nonce() == 0 && wallet.balance == 0
                        && !nativeSale.authorizationUsed(artist, n.authorization.nonce),
                    "capability failure before effects"
                );
            }
            artists.configureSaleCapability(0);
            vm.prank(payer);
            nativeSale.purchase{ value: 1000 }(n);
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c = sale.previewExecution(
                u
            );
            vm.prank(payer);
            payment.settleERC20PrimarySaleByPayer(c, abi.encode(u));
            require(
                !artists.saleConsentRequired() && manager.nonce() == 2 && wallet.balance == 1000
                    && token.balanceOf(wallet) == 1000,
                "same proofs healthy explicit NONE money controls"
            );
            require(
                recorder.totalOfficialSettled(address(0)) == 1000
                    && recorder.totalOfficialSettled(address(token)) == 1000,
                "both official accounting controls"
            );
        }
    }
