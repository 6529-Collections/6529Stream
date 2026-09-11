// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RevenueV1TestBase.sol";
import "../../helpers/RevenueResolverTestMocks.sol";
import "../../helpers/SaleFundingTestMocks.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";
import "../../../smart-contracts/domains/revenue/StreamRevenueEscrow.sol";
import "../../../smart-contracts/domains/mint/StreamFixedPriceSaleAdapter.sol";
import "../../../smart-contracts/domains/mint/StreamERC20FixedPriceSaleAdapter.sol";

/// @dev Actual sale/factory/resolver/escrow/wallet, lightweight manager/Core/artist seams.
contract StreamSaleFundingTest is RevenueV1TestBase, OfficialSafeFixture {
    struct LegacyNativeAuthorization {
        uint256 collectionId;
        bytes32 phaseId;
        address payer;
        address recipient;
        address artist;
        bytes32 profileId;
        bytes32 tokenDataHash;
        bytes32 mintCommitment;
        bytes32 mintPolicyHash;
        uint256 price;
        bytes32 nonce;
        uint64 deadline;
        uint64 signerEpoch;
    }
    uint256 private constant PAYER_KEY = 0x111;
    uint256 private constant ARTIST_KEY = 0x222;
    uint256 private constant PLATFORM_KEY = 0x333;
    bytes32 private constant CLASS = keccak256("PRIMARY_SALE");
    bytes32 private constant PHASE = keccak256("funding phase");
    SaleFundingFaultVm private constant faultVm = SaleFundingFaultVm(address(vm));
    address private payer;
    address private artist;
    address private platform;
    StreamSplitFactory private factory;
    StreamRevenueResolver private resolver;
    StreamAssetPolicyRegistry private policy;
    StreamRevenueEscrow private escrow;
    StreamFixedPriceSaleAdapter private nativeSale;
    StreamERC20FixedPriceSaleAdapter private tokenSale;
    SaleFundingManagerMock private manager;
    RevenueResolverCoreMock private core;
    SaleFundingArtistMock private artists;
    SaleFundingTokenMock private token;
    bytes32 private profile;
    address private wallet;
    bytes32 private saleId;
    uint256 private actionNonce;
    OfficialSafe private safe;
    uint256[] private safeKeys;
    event SafeSelectorObserved(address indexed target, bytes4 indexed selector, uint8 result);
    event SafeSaleGas(uint256 nativeGas, uint256 tokenGas);

    function setUp() public {
        payer = vm.addr(PAYER_KEY);
        artist = vm.addr(ARTIST_KEY);
        platform = vm.addr(PLATFORM_KEY);
        policy = new StreamAssetPolicyRegistry(address(_revenueAuthority()));
        IStreamGasParameterHost.GasParameterConfig[3] memory configs = _walletGasConfigs();
        configs[2].genesisValue = 300_000;
        configs[2].floor = 100_000;
        factory = new StreamSplitFactory(policy, address(revenueAuthority), configs);
        core = new RevenueResolverCoreMock();
        artists = new SaleFundingArtistMock(address(core));
        core.selectArtist(address(artists), address(artists).codehash);
        manager = new SaleFundingManagerMock(address(core));
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
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] = IStreamSplitWallet.SplitEntry(artist, 1_000_000, keccak256("artist"));
        (profile, wallet) = factory.createProfile(entries, keccak256("funding"));
        resolver.setPrimaryProfileAssignment(CLASS, 1, 1, profile, bytes32(0));
        // Prebinding assignment exists but is outside this artist profile's economics authority.
        resolver.setPrimaryProfileAssignment(keccak256("OTHER_CLASS"), 1, 1, profile, bytes32(0));
        artists.accept(artist);
        escrow = new StreamRevenueEscrow(
            factory,
            address(revenueAuthority),
            IStreamGasParameterHost.GasParameterConfig("FLUSH_GAS_FLOOR", 12_000_000, 12_000_000, 3)
        );
        nativeSale = new StreamFixedPriceSaleAdapter(
            IStreamMintManager(address(manager)), resolver, platform, artists, escrow
        );
        tokenSale = new StreamERC20FixedPriceSaleAdapter(
            IStreamMintManager(address(manager)), resolver, platform, artists, escrow
        );
        _admit(address(nativeSale), true);
        _admit(address(tokenSale), true);
        token = new SaleFundingTokenMock();
        _setAssetPolicy(policy, address(token), 1, keccak256("test token"), 0);
        (bytes32 primary,,) = tokenSale.primaryPolicy(1, CLASS);
        saleId = tokenSale.registerSale(
            IStreamERC20FixedPriceSaleAdapter.SaleConfig(
                1,
                PHASE,
                address(token),
                CLASS,
                1000,
                manager.POLICY(),
                primary,
                0,
                uint64(block.timestamp + 1 days)
            )
        );
        token.mint(payer, 10_000);
        vm.prank(payer);
        token.approve(address(tokenSale), 10_000);
        vm.deal(payer, 10 ether);
    }

    function testFixedProfilePolicyAndV2DigestPreimagesRemainExact() public view {
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a =
            resolver.resolvePrimaryAssignment(1, 0, CLASS);
        bytes32 policyHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_POLICY_V1"),
                block.chainid,
                address(resolver),
                CLASS,
                uint256(1),
                uint256(0),
                bytes32(0),
                profile,
                wallet,
                a.assignmentHash
            )
        );
        (bytes32 nativePolicy,,) = nativeSale.primaryPolicy(1);
        (bytes32 tokenPolicy,,) = tokenSale.primaryPolicy(1, CLASS);
        require(nativePolicy == policyHash && tokenPolicy == policyHash, "unchanged PROFILE tuple");
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory sale = _native(address(0xBEEF));
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamFixedPriceSale"),
                keccak256("2"),
                block.chainid,
                address(nativeSale)
            )
        );
        bytes32 typeHash = keccak256(
            "SaleAuthorization(uint256 collectionId,bytes32 phaseId,address payer,address recipient,address artist,bytes32 profileId,bytes32 expectedPrimaryPolicyHash,bytes32 tokenDataHash,bytes32 mintCommitment,bytes32 mintPolicyHash,uint256 price,bytes32 nonce,uint64 deadline,uint64 signerEpoch)"
        );
        require(
            nativeSale.authorizationDigest(sale)
                == keccak256(
                    abi.encodePacked(hex"1901", domain, keccak256(abi.encode(typeHash, sale)))
                ),
            "unchanged V2 typed digest"
        );
    }

    function testNativeDirectFundingAndActualWalletPayout() public {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a = _native(address(0xBEEF));
        vm.recordLogs();
        bytes32 root = _buyNative(a);
        _fundingEvent(
            vm.getRecordedLogs(),
            address(nativeSale),
            address(0),
            1 ether,
            false,
            nativeSale.authorizationId(a.artist, a.nonce),
            root
        );
        require(
            wallet.balance == 1 ether && escrow.totalOwed(address(0)) == 0
                && nativeSale.totalNativeProceeds() == 1 ether
                && manager.ownerOf(1) == address(0xBEEF),
            "native funded mint"
        );
        IStreamSplitWallet(wallet).release(address(0), artist, payable(artist));
        require(artist.balance == 1 ether, "actual native payout");
    }

    function testNativeRevertedDepositEscrowsBeforeRecipientAndCanFlush() public {
        SaleFundingReceiver receiver = new SaleFundingReceiver();
        receiver.configure(wallet, address(0), escrow, CLASS, profile, false);
        // Value-specific failure injection leaves actual official runtime/metadata checks intact.
        faultVm.mockCallRevert(
            wallet, 1 ether, "", abi.encodeWithSignature("Error(string)", "deposit failed")
        );
        _buyNative(_native(address(receiver)));
        require(
            receiver.observedWallet() == 0 && receiver.observedEscrow() == 1 ether
                && escrow.totalOwed(address(0)) == 1 ether && address(nativeSale).balance == 0,
            "funded as owed before callback"
        );
        faultVm.clearMockedCalls();
        escrow.flushToVerifiedWalletBestEffort(CLASS, profile, wallet, address(0));
        require(
            wallet.balance == 1 ether && escrow.totalOwed(address(0)) == 0,
            "actual later wallet delivery"
        );
    }

    function testERC20EscrowRoutePreservesActualPullerAllowance() public {
        SaleFundingReceiver receiver = new SaleFundingReceiver();
        receiver.configure(wallet, address(token), escrow, CLASS, profile, false);
        token.configure(1);
        _buyToken(_erc20(address(receiver)), false);
        require(
            receiver.observedWallet() == 0 && receiver.observedEscrow() == 1000
                && token.balanceOf(payer) == 9000 && token.balanceOf(address(tokenSale)) == 0
                && token.allowance(payer, address(tokenSale)) == 9000
                && token.allowance(payer, address(escrow)) == 0
                && token.allowance(address(tokenSale), address(escrow)) == 0,
            "exact producer escrow route"
        );
        token.configure(0);
        escrow.flushToVerifiedWalletBestEffort(CLASS, profile, wallet, address(token));
        IStreamSplitWallet(wallet).release(address(token), artist, payable(artist));
        require(token.balanceOf(artist) == 1000, "actual token recipient payout");
    }

    function testERC20DirectRoutePreservesSurplusAndEventsAndPaysActualWallet() public {
        token.mint(address(tokenSale), 17);
        token.mint(address(escrow), 23);
        SaleFundingReceiver receiver = new SaleFundingReceiver();
        receiver.configure(wallet, address(token), escrow, CLASS, profile, false);
        vm.recordLogs();
        IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory a = _erc20(address(receiver));
        bytes32 root = _buyToken(a, false);
        _fundingEvent(
            vm.getRecordedLogs(),
            address(tokenSale),
            address(token),
            1000,
            false,
            tokenSale.authorizationId(a.artist, a.nonce),
            root
        );
        require(
            receiver.observedWallet() == 1000 && receiver.observedEscrow() == 0,
            "actual wallet funded before callback"
        );
        require(
            token.balanceOf(address(tokenSale)) == 17 && token.balanceOf(address(escrow)) == 23
                && escrow.totalOwed(address(token)) == 0
                && tokenSale.totalProceeds(address(token)) == 1000,
            "donations excluded from official payment"
        );
        require(
            token.transferGas() > 200_000 && token.transferGas() <= 300_000,
            "actual token frame uses governed deposit cap"
        );
        IStreamSplitWallet(wallet).release(address(token), artist, payable(artist));
        require(token.balanceOf(artist) == 1000, "real direct token payout");
    }

    function testERC20AllGasBurnAndRevertBombRollBackAttemptBeforeEscrow() public {
        for (uint8 mode = 7; mode <= 8; ++mode) {
            token.configure(mode);
            IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory a = _erc20(address(0xBEEF));
            a.nonce = bytes32(uint256(mode));
            vm.recordLogs();
            bytes32 root = _buyToken(a, false);
            _fundingEvent(
                vm.getRecordedLogs(),
                address(tokenSale),
                address(token),
                1000,
                true,
                tokenSale.authorizationId(a.artist, a.nonce),
                root
            );
            require(
                token.balanceOf(wallet) == 0 && token.transferGas() == 0,
                "failed token frame and partial movement truly reverted"
            );
        }
        require(
            token.balanceOf(payer) == 8000 && token.balanceOf(address(escrow)) == 2000
                && escrow.totalOwed(address(token)) == 2000 && manager.nonce() == 2,
            "adequate outer budget continues after capped failed calls"
        );
    }

    function testERC20FailedApprovalAndResidualAllowanceCannotEscapeAtomicity() public {
        token.configure(1);
        for (uint8 mode = 1; mode <= 3; ++mode) {
            token.configureApproval(mode < 3 ? mode : 0);
            if (mode == 3) token.setAllowance(address(tokenSale), address(escrow), 1);
            IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory a = _erc20(address(0xBEEF));
            (bytes memory ps, bytes memory as_) = _tokenSignatures(a);
            IStreamPaymentIntentVerifier.PaymentIntent memory intent;
            bytes memory error = mode == 1
                ? abi.encodeWithSelector(
                    IStreamSaleFunding.SaleFundingTokenCallFailed.selector,
                    address(token),
                    IERC20.approve.selector
                )
                : abi.encodeWithSelector(
                    IStreamSaleFunding.SaleFundingAllowanceMismatch.selector,
                    address(token),
                    mode == 2 ? 0 : 1,
                    mode == 2 ? 1000 : 0
                );
            vm.prank(payer);
            vm.expectRevert(error);
            tokenSale.buy(a, hex"1234", ps, as_, intent, "");
            require(
                token.balanceOf(payer) == 10_000 && token.balanceOf(address(escrow)) == 0
                    && token.allowance(payer, address(tokenSale)) == 10_000
                    && token.allowance(address(tokenSale), address(escrow)) == (mode == 3 ? 1 : 0)
                    && !tokenSale.authorizationUsed(artist, a.nonce),
                "approval failure fully atomic"
            );
        }
    }

    function testERC20MintFailureRootAndOperationMismatchRollBackPayerIntentAndEscrow() public {
        token.configure(1);
        IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory a = _erc20(address(0xBEEF));
        (bytes memory ps, bytes memory as_) = _tokenSignatures(a);
        IStreamPaymentIntentVerifier.PaymentIntent memory intent = _intent(payer);
        bytes memory payerSig = _sign(PAYER_KEY, tokenSale.paymentIntentDigest(intent));
        for (uint256 mode = 1; mode <= 3; ++mode) {
            manager.configure(mode);
            bytes memory error = mode == 1
                ? abi.encodeWithSignature("Error(string)", "mint rejected")
                : abi.encodeWithSelector(
                    IStreamERC20FixedPriceSaleAdapter.SaleMintResultInvalid.selector
                );
            vm.expectRevert(error);
            tokenSale.buy(a, hex"1234", ps, as_, intent, payerSig);
            require(
                !tokenSale.isPaymentIntentNonceUsed(payer, intent.nonce)
                    && !tokenSale.authorizationUsed(artist, a.nonce)
                    && tokenSale.totalProceeds(address(token)) == 0 && manager.nonce() == 0
                    && token.balanceOf(payer) == 10_000 && token.balanceOf(address(tokenSale)) == 0
                    && token.balanceOf(address(escrow)) == 0
                    && escrow.totalOwed(address(token)) == 0
                    && token.allowance(payer, address(tokenSale)) == 10_000
                    && token.allowance(address(tokenSale), address(escrow)) == 0,
                "payer, artist, preview, allowance, money all revert"
            );
        }
    }

    function testRejectingRecipientRollsBackNativeAndTokenBothFundingRoutes() public {
        SaleFundingReceiver receiver = new SaleFundingReceiver();
        for (uint256 route; route < 2; ++route) {
            receiver.configure(wallet, address(0), escrow, CLASS, profile, true);
            if (route == 1) faultVm.mockCallRevert(wallet, 1 ether, "", "fault injected deposit");
            IStreamFixedPriceSaleAdapter.SaleAuthorization memory n = _native(address(receiver));
            (bytes memory ps, bytes memory as_) = _nativeSignatures(n);
            vm.prank(payer);
            vm.expectRevert(abi.encodeWithSignature("Error(string)", "receiver rejected"));
            nativeSale.buy{ value: n.price }(n, hex"1234", ps, as_);
            require(
                payer.balance == 10 ether && wallet.balance == 0
                    && escrow.totalOwed(address(0)) == 0
                    && !nativeSale.authorizationUsed(artist, n.nonce),
                "native recipient rollback"
            );
            faultVm.clearMockedCalls();
            receiver.configure(wallet, address(token), escrow, CLASS, profile, true);
            token.configure(uint8(route));
            IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory a = _erc20(address(receiver));
            (ps, as_) = _tokenSignatures(a);
            IStreamPaymentIntentVerifier.PaymentIntent memory intent;
            vm.prank(payer);
            vm.expectRevert(abi.encodeWithSignature("Error(string)", "receiver rejected"));
            tokenSale.buy(a, hex"1234", ps, as_, intent, "");
            require(
                token.balanceOf(payer) == 10_000 && token.balanceOf(wallet) == 0
                    && escrow.totalOwed(address(token)) == 0
                    && !tokenSale.authorizationUsed(artist, a.nonce) && manager.nonce() == 0,
                "token recipient rollback"
            );
        }
    }

    function testRecipientCannotReenterEitherAdapterAfterDirectOrEscrowFunding() public {
        SaleFundingReceiver receiver = new SaleFundingReceiver();
        for (uint256 route; route < 2; ++route) {
            receiver.configure(wallet, address(0), escrow, CLASS, profile, false);
            receiver.reenter(
                address(nativeSale),
                abi.encodeCall(nativeSale.cancelAuthorization, (bytes32(uint256(77))))
            );
            if (route == 1) faultVm.mockCallRevert(wallet, 1 ether, "", "fault injected deposit");
            IStreamFixedPriceSaleAdapter.SaleAuthorization memory n = _native(address(receiver));
            n.nonce = bytes32(route + 1);
            _buyNative(n);
            require(
                keccak256(receiver.reentryReason())
                    == keccak256(
                        abi.encodeWithSelector(
                            ReentrancyGuard.ReentrancyGuardReentrantCall.selector
                        )
                    ),
                "native guard exact error"
            );
            require(
                !nativeSale.authorizationUsed(address(receiver), bytes32(uint256(77))),
                "native no redirect"
            );
            faultVm.clearMockedCalls();
            receiver.configure(wallet, address(token), escrow, CLASS, profile, false);
            receiver.reenter(
                address(tokenSale),
                abi.encodeCall(tokenSale.cancelAuthorization, (bytes32(uint256(88))))
            );
            token.configure(uint8(route));
            IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory a = _erc20(address(receiver));
            a.nonce = bytes32(route + 1);
            _buyToken(a, false);
            require(
                keccak256(receiver.reentryReason())
                    == keccak256(
                        abi.encodeWithSelector(
                            ReentrancyGuard.ReentrancyGuardReentrantCall.selector
                        )
                    ),
                "token guard exact error"
            );
            require(
                !tokenSale.authorizationUsed(address(receiver), bytes32(uint256(88))),
                "token no redirect"
            );
        }
        require(
            wallet.balance == 1 ether && escrow.totalOwed(address(0)) == 1 ether
                && token.balanceOf(wallet) == 1000 && escrow.totalOwed(address(token)) == 1000,
            "one exact payment per committed operation"
        );
    }

    function testCallbackCorePointerDriftRollsBackPaymentAndPointer() public {
        token.setCallback(
            address(core), abi.encodeCall(core.selectArtist, (address(0), bytes32(0)))
        );
        IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory a = _erc20(address(0xBEEF));
        (bytes memory ps, bytes memory as_) = _tokenSignatures(a);
        IStreamPaymentIntentVerifier.PaymentIntent memory intent;
        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.InvalidPrimaryArtistRegistry.selector, address(0)
            )
        );
        tokenSale.buy(a, hex"1234", ps, as_, intent, "");
        require(
            core.selectedArtist() == address(artists) && token.balanceOf(payer) == 10_000
                && token.balanceOf(wallet) == 0 && manager.nonce() == 0,
            "post-payment selected authority recheck"
        );
    }

    function testFundingCodeDriftRejectsBeforePayment() public {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a = _native(address(0xBEEF));
        (bytes memory ps, bytes memory as_) = _nativeSignatures(a);
        vm.etch(address(escrow), hex"60006000fd");
        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamSaleFunding.SaleFundingBindingChanged.selector, address(escrow)
            )
        );
        nativeSale.buy{ value: a.price }(a, hex"1234", ps, as_);
        require(payer.balance == 10 ether && wallet.balance == 0, "pinned escrow code drift");
    }

    function testLowOuterGasDoesNotSilentlyUnderforwardLiveDepositBudget() public {
        IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory a = _erc20(address(0xBEEF));
        (bytes memory ps, bytes memory as_) = _tokenSignatures(a);
        IStreamPaymentIntentVerifier.PaymentIntent memory intent;
        bytes memory data =
            abi.encodeCall(tokenSale.buy, (a, hex"1234", ps, as_, intent, bytes("")));
        vm.prank(payer);
        (bool ok, bytes memory reason) = address(tokenSale).call{ gas: 330_000 }(data);
        require(
            !ok && reason.length == 68
                && bytes4(reason) == IStreamSaleFunding.InsufficientSaleFundingGas.selector,
            "explicit budget admission, not clipped token call"
        );
        require(token.balanceOf(payer) == 10_000 && manager.nonce() == 0, "underfunding atomic");
    }

    function testNextPurchaseReadsRaisedFactoryDepositBudget() public {
        bytes32 id = keccak256("6529STREAM_GGP_WALLET_DEPOSIT_GAS_LIMIT");
        (uint256 prior, uint256 floor, uint8 kind, uint64 revision) = factory.gasParameterInfo(id);
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71),
                block.chainid,
                address(factory),
                id
            )
        );
        bytes32 domain = 0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c;
        revenueAuthority.setCurrentAction(
            true,
            keccak256("funding deposit raise"),
            1,
            scope,
            keccak256(abi.encode(domain, scope, prior, floor, kind, revision)),
            keccak256(abi.encode(domain, scope, uint256(500_000), floor, kind, revision + 1))
        );
        vm.prank(address(revenueAuthority));
        factory.raiseGasParameter(id, 500_000);
        revenueAuthority.setCurrentAction(false, bytes32(0), 0, bytes32(0), bytes32(0), bytes32(0));
        _buyToken(_erc20(address(0xBEEF)), false);
        require(
            token.transferGas() > 400_000 && token.transferGas() <= 500_000
                && token.balanceOf(wallet) == 1000,
            "live governed cap, no immutable fallback"
        );
    }

    function testLegacyNativeStructSignatureAndSelectorHaveNoFallback() public {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a = _native(address(0xBEEF));
        bytes32 legacyType = keccak256(
            "SaleAuthorization(uint256 collectionId,bytes32 phaseId,address payer,address recipient,address artist,bytes32 profileId,bytes32 tokenDataHash,bytes32 mintCommitment,bytes32 mintPolicyHash,uint256 price,bytes32 nonce,uint64 deadline,uint64 signerEpoch)"
        );
        bytes32 legacyStruct = keccak256(
            bytes.concat(
                abi.encode(
                    legacyType,
                    a.collectionId,
                    a.phaseId,
                    a.payer,
                    a.recipient,
                    a.artist,
                    a.profileId
                ),
                abi.encode(
                    a.tokenDataHash,
                    a.mintCommitment,
                    a.mintPolicyHash,
                    a.price,
                    a.nonce,
                    a.deadline,
                    a.signerEpoch
                )
            )
        );
        bytes32 oldDomain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamFixedPriceSale"),
                keccak256("1"),
                block.chainid,
                address(nativeSale)
            )
        );
        bytes32 oldDigest = keccak256(abi.encodePacked(hex"1901", oldDomain, legacyStruct));
        bytes memory ps = _sign(PLATFORM_KEY, oldDigest);
        bytes memory as_ = _sign(ARTIST_KEY, oldDigest);
        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFixedPriceSaleAdapter.InvalidSaleSignature.selector, platform
            )
        );
        nativeSale.buy{ value: a.price }(a, hex"1234", ps, as_);
        bytes memory legacyCall = _legacyNativeCall(a, ps, as_);
        vm.prank(payer);
        (bool ok, bytes memory reason) = address(nativeSale).call{ value: a.price }(legacyCall);
        require(
            !ok && reason.length == 0 && payer.balance == 10 ether && wallet.balance == 0
                && !nativeSale.authorizationUsed(artist, a.nonce),
            "legacy entry is absent, full old signature rejected"
        );
    }

    function _legacyNativeCall(
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a,
        bytes memory ps,
        bytes memory as_
    ) private pure returns (bytes memory) {
        LegacyNativeAuthorization memory old = abi.decode(
            bytes.concat(
                abi.encode(a.collectionId, a.phaseId, a.payer, a.recipient, a.artist, a.profileId),
                abi.encode(
                    a.tokenDataHash,
                    a.mintCommitment,
                    a.mintPolicyHash,
                    a.price,
                    a.nonce,
                    a.deadline,
                    a.signerEpoch
                )
            ),
            (LegacyNativeAuthorization)
        );
        bytes4 selector = bytes4(
            keccak256(
                "buy((uint256,bytes32,address,address,address,bytes32,bytes32,bytes32,bytes32,uint256,bytes32,uint64,uint64),bytes,bytes,bytes)"
            )
        );
        return abi.encodeWithSelector(selector, old, hex"1234", ps, as_);
    }

    function testFuzzNativeExactFundingConservation(uint96 rawPrice) public {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a = _native(address(0xBEEF));
        a.price = uint256(rawPrice) % 5 ether;
        vm.deal(address(nativeSale), 17);
        _buyNative(a);
        require(
            payer.balance + wallet.balance == 10 ether && wallet.balance == a.price
                && address(nativeSale).balance == 17 && nativeSale.totalNativeProceeds() == a.price
                && escrow.totalOwed(address(0)) == 0,
            "signed exact amount and passive surplus"
        );
    }

    function _intent(address who)
        private
        view
        returns (IStreamPaymentIntentVerifier.PaymentIntent memory)
    {
        (bytes32 primary,,) = tokenSale.primaryPolicy(1, CLASS);
        return IStreamPaymentIntentVerifier.PaymentIntent(
            who,
            address(token),
            1000,
            saleId,
            primary,
            keccak256("payer nonce"),
            uint64(block.timestamp + 1 days)
        );
    }

    function _fundingEvent(
        Vm.Log[] memory logs,
        address emitter,
        address asset,
        uint256 amount,
        bool escrowed,
        bytes32 expectedId,
        bytes32 expectedRoot
    ) private view {
        bytes32 topic = keccak256(
            "SaleRevenueFunded(uint16,bytes32,bytes32,bytes32,address,address,uint256,bool)"
        );
        uint256 matches;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != emitter || logs[i].topics[0] != topic) continue;
            ++matches;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == expectedId
                    && logs[i].topics[2] == expectedRoot && logs[i].topics[3] == profile,
                "funding identity"
            );
            require(
                keccak256(logs[i].data)
                    == keccak256(abi.encode(uint16(1), wallet, asset, amount, escrowed)),
                "exact funding record"
            );
        }
        require(matches == 1, "exactly one official funding event");
    }

    function testERC20SuccessfulFalseMalformedNoopAndFeeNeverBecomeEscrow() public {
        IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory a = _erc20(address(0xBEEF));
        for (uint8 mode = 2; mode <= 6; ++mode) {
            token.configure(mode);
            bytes4 selector = mode == 3 || mode == 4
                ? IStreamSaleFunding.SaleFundingAmountMismatch.selector
                : IStreamSaleFunding.SaleFundingTokenCallFailed.selector;
            bytes memory error = mode == 3 || mode == 4
                ? abi.encodeWithSelector(selector, address(token))
                : abi.encodeWithSelector(selector, address(token), IERC20.transfer.selector);
            (bytes memory ps, bytes memory as_) = _tokenSignatures(a);
            IStreamPaymentIntentVerifier.PaymentIntent memory intent;
            vm.prank(payer);
            vm.expectRevert(error);
            tokenSale.buy(a, hex"1234", ps, as_, intent, "");
            require(
                token.balanceOf(payer) == 10_000 && token.balanceOf(wallet) == 0
                    && token.balanceOf(address(escrow)) == 0
                    && escrow.totalOwed(address(token)) == 0
                    && !tokenSale.authorizationUsed(artist, a.nonce) && manager.nonce() == 0,
                "all token effects and replay roll back, no partial payment plus escrow"
            );
        }
    }

    function testAlternatePreconfiguredRevenueClassCannotAuthorizeERC20Purchase() public {
        bytes32 other = keccak256("OTHER_CLASS");
        require(
            resolver.resolvePrimaryAssignment(1, 0, other).exists,
            "alternate assignment truly exists"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamERC20FixedPriceSaleAdapter.UnsupportedPrimaryAssignment.selector
            )
        );
        tokenSale.primaryPolicy(1, other);
        IStreamERC20FixedPriceSaleAdapter.SaleConfig memory config =
        tokenSale.saleRecord(saleId).config;
        config.revenueClass = other;
        uint256 nonce = tokenSale.nextSaleNonce();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamERC20FixedPriceSaleAdapter.InvalidSaleConfiguration.selector
            )
        );
        tokenSale.registerSale(config);
        require(tokenSale.nextSaleNonce() == nonce, "unsupported economics cannot make sale record");
    }

    function testNativeSignedWrongPolicyAndWrongProfileRejectBeforeFunding() public {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a = _native(address(0xBEEF));
        bytes32 actual = a.expectedPrimaryPolicyHash;
        a.expectedPrimaryPolicyHash = keccak256("wrong signed current policy");
        (bytes memory ps, bytes memory as_) = _nativeSignatures(a);
        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFixedPriceSaleAdapter.NativePrimaryPolicyMismatch.selector,
                a.expectedPrimaryPolicyHash,
                actual
            )
        );
        nativeSale.buy{ value: a.price }(a, hex"1234", ps, as_);
        a.expectedPrimaryPolicyHash = actual;
        a.profileId = bytes32(uint256(1));
        (ps, as_) = _nativeSignatures(a);
        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFixedPriceSaleAdapter.InvalidSplitProfile.selector, a.profileId
            )
        );
        nativeSale.buy{ value: a.price }(a, hex"1234", ps, as_);
        require(
            wallet.balance == 0 && payer.balance == 10 ether && manager.nonce() == 0
                && !nativeSale.authorizationUsed(artist, a.nonce),
            "signed mismatch leaves no effects"
        );
    }

    function testNativeV1DomainSignatureDoesNotAuthorizeV2Payload() public {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a = _native(address(0xBEEF));
        bytes32 oldDomain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamFixedPriceSale"),
                keccak256("1"),
                block.chainid,
                address(nativeSale)
            )
        );
        bytes32 wrongDigest = keccak256(
            abi.encodePacked(
                hex"1901",
                oldDomain,
                keccak256(abi.encode(nativeSale.SALE_AUTHORIZATION_TYPEHASH(), a))
            )
        );
        bytes memory ps = _sign(PLATFORM_KEY, wrongDigest);
        bytes memory as_ = _sign(ARTIST_KEY, wrongDigest);
        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFixedPriceSaleAdapter.InvalidSaleSignature.selector, platform
            )
        );
        nativeSale.buy{ value: a.price }(a, hex"1234", ps, as_);
        (,, string memory version,,,,) = nativeSale.eip712Domain();
        require(
            keccak256(bytes(version)) == keccak256("2") && wallet.balance == 0,
            "no version1 fallback"
        );
    }

    function testNativeMintFailureAndIdentityMismatchRollBackEscrowAndNonce() public {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a = _native(address(0xBEEF));
        (bytes memory ps, bytes memory as_) = _nativeSignatures(a);
        faultVm.mockCallRevert(wallet, 1 ether, "", "wallet refusal");
        for (uint256 mode = 1; mode <= 3; ++mode) {
            manager.configure(mode);
            bytes memory error = mode == 1
                ? abi.encodeWithSignature("Error(string)", "mint rejected")
                : abi.encodeWithSelector(
                    IStreamFixedPriceSaleAdapter.SaleMintResultInvalid.selector
                );
            vm.prank(payer);
            vm.expectRevert(error);
            nativeSale.buy{ value: a.price }(a, hex"1234", ps, as_);
            require(
                escrow.totalOwed(address(0)) == 0 && address(escrow).balance == 0
                    && payer.balance == 10 ether && wallet.balance == 0
                    && nativeSale.totalNativeProceeds() == 0
                    && !nativeSale.authorizationUsed(artist, a.nonce) && manager.nonce() == 0,
                "all escrow payment/replay/mint state rolls back"
            );
        }
    }

    function testERC20CallbackPreviewNonceRaceRollsBackBothManagerChangeAndPayment() public {
        token.setCallback(address(manager), abi.encodeCall(SaleFundingManagerMock.advanceNonce, ()));
        IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory a = _erc20(address(0xBEEF));
        (bytes memory ps, bytes memory as_) = _tokenSignatures(a);
        IStreamPaymentIntentVerifier.PaymentIntent memory intent;
        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamERC20FixedPriceSaleAdapter.SaleMintResultInvalid.selector)
        );
        tokenSale.buy(a, hex"1234", ps, as_, intent, "");
        require(
            manager.nonce() == 0 && token.balanceOf(payer) == 10_000 && token.balanceOf(wallet) == 0
                && tokenSale.totalProceeds(address(token)) == 0
                && !tokenSale.authorizationUsed(artist, a.nonce),
            "preview prevents callback from replacing execution identity"
        );
    }

    function testRelayedPayerIntentStillBindsActualPullerAndConsumesOnlyOnce() public {
        IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory a = _erc20(address(0xBEEF));
        token.configure(1);
        _buyToken(a, true);
        require(
            tokenSale.isPaymentIntentNonceUsed(payer, keccak256("payer nonce"))
                && tokenSale.authorizationUsed(artist, a.nonce)
                && escrow.totalOwed(address(token)) == 1000 && token.balanceOf(payer) == 9000,
            "actual puller verifies relayed intent"
        );
        (bytes memory ps, bytes memory as_) = _tokenSignatures(a);
        IStreamPaymentIntentVerifier.PaymentIntent memory intent;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamERC20FixedPriceSaleAdapter.SaleAuthorizationUsed.selector, artist, a.nonce
            )
        );
        tokenSale.buy(a, hex"1234", ps, as_, intent, "");
        require(escrow.totalOwed(address(token)) == 1000, "no repeat credit");
    }

    function testUnadmittedProducerFallbackRollsBackPayerPullAndEscrowApproval() public {
        _admit(address(tokenSale), false);
        token.configure(1);
        IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory a = _erc20(address(0xBEEF));
        (bytes memory ps, bytes memory as_) = _tokenSignatures(a);
        IStreamPaymentIntentVerifier.PaymentIntent memory intent;
        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueEscrow.InvalidEscrowProducer.selector, address(tokenSale)
            )
        );
        tokenSale.buy(a, hex"1234", ps, as_, intent, "");
        require(
            token.balanceOf(payer) == 10_000 && token.allowance(payer, address(tokenSale)) == 10_000
                && token.allowance(address(tokenSale), address(escrow)) == 0
                && escrow.totalOwed(address(token)) == 0
                && !tokenSale.authorizationUsed(artist, a.nonce),
            "failed producer admission is fully atomic"
        );
    }

    function testActualSafeNativeAndERC20PayerPlatformArtistAndRecipientPayout() public {
        _setupSaleSafe();
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory n = _native(address(0xBEEF));
        bytes memory sig = _safeSignature(nativeSale.authorizationDigest(n));
        uint256 beforeGas = gasleft();
        _safeExec(
            address(nativeSale), n.price, abi.encodeCall(nativeSale.buy, (n, hex"1234", sig, sig))
        );
        uint256 nativeGas = beforeGas - gasleft();
        IStreamSplitWallet(wallet).release(address(0), address(safe), payable(address(safe)));
        require(
            address(safe).balance == 10 ether && manager.ownerOf(1) == address(0xBEEF),
            "actual Safe funded native purchase and got native payout"
        );
        _safeExec(address(token), 0, abi.encodeCall(token.approve, (address(tokenSale), 10_000)));
        IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory a = _erc20(address(0xBEEF));
        sig = _safeSignature(tokenSale.authorizationDigest(a));
        IStreamPaymentIntentVerifier.PaymentIntent memory empty;
        beforeGas = gasleft();
        _safeExec(
            address(tokenSale),
            0,
            abi.encodeCall(tokenSale.buy, (a, hex"1234", sig, sig, empty, bytes("")))
        );
        uint256 tokenGas = beforeGas - gasleft();
        require(
            !tokenSale.isPaymentIntentNonceUsed(address(safe), bytes32(0)),
            "actual caller exemption only"
        );
        IStreamSplitWallet(wallet).release(address(token), address(safe), payable(address(safe)));
        require(
            token.balanceOf(address(safe)) == 10_000 && manager.ownerOf(2) == address(0xBEEF),
            "actual Safe token allowance, mint and payout"
        );
        emit SafeSaleGas(nativeGas, tokenGas);
    }

    function testActualSafeRelayedPayerIntentEscrowAndRevocationWithThresholdDomainNegative()
        public
    {
        _setupSaleSafe();
        _safeExec(address(token), 0, abi.encodeCall(token.approve, (address(tokenSale), 10_000)));
        IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory a = _erc20(address(0xBEEF));
        bytes memory creatorSig = _safeSignature(tokenSale.authorizationDigest(a));
        IStreamPaymentIntentVerifier.PaymentIntent memory intent = _intent(address(safe));
        bytes memory payerSig = _safeSignature(tokenSale.paymentIntentDigest(intent));
        // Owner signatures on the raw Stream digest are not SafeMessage proofs.
        bytes memory wrong = safeThresholdSignature(safeKeys, tokenSale.paymentIntentDigest(intent));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamPaymentIntentVerifier.InvalidPaymentSignature.selector, address(safe)
            )
        );
        tokenSale.buy(a, hex"1234", creatorSig, creatorSig, intent, wrong);
        require(
            !tokenSale.isPaymentIntentNonceUsed(address(safe), intent.nonce)
                && token.balanceOf(address(safe)) == 10_000,
            "wrong Safe domain cannot spend"
        );
        token.configure(1);
        tokenSale.buy(a, hex"1234", creatorSig, creatorSig, intent, payerSig);
        require(
            tokenSale.isPaymentIntentNonceUsed(address(safe), intent.nonce)
                && token.balanceOf(address(safe)) == 9000
                && escrow.totalOwed(address(token)) == 1000
                && token.allowance(address(tokenSale), address(escrow)) == 0,
            "relayed Safe funding exact"
        );
        bytes32 revoked = keccak256("Safe revocation");
        uint64 deadline = uint64(block.timestamp + 1 days);
        bytes memory revokeSig = _safeSignature(
            tokenSale.paymentIntentRevocationDigest(address(safe), revoked, deadline)
        );
        // Permissionless relaying can itself be an actual Safe call.
        _safeExec(
            address(tokenSale),
            0,
            abi.encodeCall(
                tokenSale.revokePaymentIntentBySignature,
                (address(safe), revoked, deadline, revokeSig)
            )
        );
        require(
            tokenSale.isPaymentIntentNonceUsed(address(safe), revoked),
            "real Safe revocation persisted"
        );
        _safeReject(
            address(tokenSale),
            abi.encodeCall(
                tokenSale.revokePaymentIntentBySignature,
                (address(safe), revoked, deadline, revokeSig)
            ),
            abi.encodeWithSelector(
                IStreamPaymentIntentVerifier.PaymentIntentNonceUsed.selector, address(safe), revoked
            )
        );
    }

    function testActualSafeAllPublicReadsAndOwnedAdministrativeSelectors() public {
        _setupSaleSafe();
        _safeReads(address(nativeSale), _nativeReads());
        _safeReads(address(tokenSale), _tokenReads());
        // Safe signer ownership does not grant adapter ownership. Its literal caller must own the role.
        _safeReject(
            address(nativeSale),
            abi.encodeCall(nativeSale.setPaused, (true)),
            abi.encodeWithSignature("Error(string)", "Ownable: caller is not the owner")
        );
        _safeReject(
            address(tokenSale),
            abi.encodeCall(tokenSale.setPaused, (true)),
            abi.encodeWithSignature("Error(string)", "Ownable: caller is not the owner")
        );
        nativeSale.transferOwnership(address(safe));
        tokenSale.transferOwnership(address(safe));
        _safeExec(address(nativeSale), 0, abi.encodeCall(nativeSale.setPaused, (true)));
        _safeExec(address(nativeSale), 0, abi.encodeCall(nativeSale.setPaused, (false)));
        _safeExec(
            address(nativeSale), 0, abi.encodeCall(nativeSale.setPlatformSigner, (address(safe)))
        );
        _safeExec(
            address(nativeSale),
            0,
            abi.encodeCall(nativeSale.cancelAuthorization, (bytes32(uint256(11))))
        );
        _safeExec(address(tokenSale), 0, abi.encodeCall(tokenSale.setPaused, (true)));
        _safeExec(address(tokenSale), 0, abi.encodeCall(tokenSale.setPaused, (false)));
        _safeExec(
            address(tokenSale), 0, abi.encodeCall(tokenSale.setPlatformSigner, (address(safe)))
        );
        _safeExec(
            address(tokenSale), 0, abi.encodeCall(tokenSale.raiseSignatureGasLimit, (500_000))
        );
        _safeExec(
            address(tokenSale),
            0,
            abi.encodeCall(tokenSale.cancelAuthorization, (bytes32(uint256(12))))
        );
        _safeExec(
            address(tokenSale),
            0,
            abi.encodeCall(tokenSale.revokePaymentIntent, (bytes32(uint256(13))))
        );
        IStreamERC20FixedPriceSaleAdapter.SaleConfig memory config =
        tokenSale.saleRecord(saleId).config;
        uint256 next = tokenSale.nextSaleNonce();
        bytes32 nextId = tokenSale.saleIdFor(config.collectionId, config.phaseId, next);
        _safeExec(address(tokenSale), 0, abi.encodeCall(tokenSale.registerSale, (config)));
        _safeExec(address(tokenSale), 0, abi.encodeCall(tokenSale.cancelSale, (nextId)));
        require(
            nativeSale.signerEpoch() == 2 && tokenSale.signerEpoch() == 2
                && tokenSale.signatureGasLimit() == 500_000
                && nativeSale.authorizationUsed(address(safe), bytes32(uint256(11)))
                && tokenSale.authorizationUsed(address(safe), bytes32(uint256(12)))
                && tokenSale.isPaymentIntentNonceUsed(address(safe), bytes32(uint256(13)))
                && tokenSale.saleRecord(nextId).cancelled,
            "actual Safe role writes applied"
        );
        _safeExec(
            address(nativeSale), 0, abi.encodeCall(nativeSale.transferOwnership, (address(safe)))
        );
        _safeExec(
            address(tokenSale), 0, abi.encodeCall(tokenSale.transferOwnership, (address(safe)))
        );
        _safeExec(address(nativeSale), 0, abi.encodeCall(nativeSale.renounceOwnership, ()));
        _safeExec(address(tokenSale), 0, abi.encodeCall(tokenSale.renounceOwnership, ()));
        require(
            nativeSale.owner() == address(0) && tokenSale.owner() == address(0),
            "renunciation by actual owner Safe"
        );
    }

    function _setupSaleSafe() private {
        uint256[] memory owners = new uint256[](3);
        owners[0] = 0x501;
        owners[1] = 0x502;
        owners[2] = 0x503;
        safeKeys.push(owners[0]);
        safeKeys.push(owners[1]);
        safe = createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(owners), 2, 501);
        payer = address(safe);
        artist = address(safe);
        platform = address(safe);
        core = new RevenueResolverCoreMock();
        artists = new SaleFundingArtistMock(address(core));
        core.selectArtist(address(artists), address(artists).codehash);
        manager = new SaleFundingManagerMock(address(core));
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
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] = IStreamSplitWallet.SplitEntry(artist, 1_000_000, keccak256("Safe artist"));
        (profile, wallet) = factory.createProfile(entries, keccak256("Safe funded sale"));
        resolver.setPrimaryProfileAssignment(CLASS, 1, 1, profile, bytes32(0));
        artists.accept(artist);
        nativeSale = new StreamFixedPriceSaleAdapter(
            IStreamMintManager(address(manager)), resolver, platform, artists, escrow
        );
        tokenSale = new StreamERC20FixedPriceSaleAdapter(
            IStreamMintManager(address(manager)), resolver, platform, artists, escrow
        );
        _admit(address(nativeSale), true);
        _admit(address(tokenSale), true);
        (bytes32 primary,,) = tokenSale.primaryPolicy(1, CLASS);
        saleId = tokenSale.registerSale(
            IStreamERC20FixedPriceSaleAdapter.SaleConfig(
                1,
                PHASE,
                address(token),
                CLASS,
                1000,
                manager.POLICY(),
                primary,
                0,
                uint64(block.timestamp + 1 days)
            )
        );
        token.mint(payer, 10_000);
        vm.deal(payer, 10 ether);
    }

    function _safeSignature(bytes32 digest) private returns (bytes memory) {
        return safeThresholdSignature(safeKeys, safeMessageDigest(safe, abi.encode(digest)));
    }

    function _safeExec(address target, uint256 value, bytes memory data) private {
        uint256 nonce = safe.nonce();
        vm.recordLogs();
        require(executeSafe(safe, safeKeys, target, value, data, 0), "actual Safe call");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool success;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(safe) && logs[i].topics.length != 0
                    && logs[i].topics[0] == keccak256("ExecutionSuccess(bytes32,uint256)")
            ) success = true;
        }
        require(success && safe.nonce() == nonce + 1, "actual Safe success event and nonce");
        emit SafeSelectorObserved(target, bytes4(data), 1);
    }

    function _safeReject(address target, bytes memory data, bytes memory expected) private {
        vm.prank(address(safe));
        (bool ok, bytes memory reason) = target.call(data);
        require(!ok && keccak256(reason) == keccak256(expected), "exact target rejection");
        uint256 nonce = safe.nonce();
        bytes32 digest =
            safe.getTransactionHash(target, 0, data, 0, 0, 0, 0, address(0), address(0), nonce);
        bytes memory signature = safeThresholdSignature(safeKeys, digest);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        safe.execTransaction(
            target, 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signature
        );
        require(safe.nonce() == nonce, "Safe failure preserves nonce");
        emit SafeSelectorObserved(target, bytes4(data), 2);
    }

    function _safeReads(address target, bytes[] memory calls) private {
        for (uint256 i; i < calls.length; ++i) {
            (bool ok, bytes memory baseline) = target.staticcall(calls[i]);
            require(ok && calls[i].length >= 4, "valid actual public read");
            vm.prank(address(safe));
            (ok, baseline) = _sameRead(target, calls[i], baseline);
            require(ok, "Safe read parity");
            _safeExec(target, 0, calls[i]);
        }
    }

    function _sameRead(address target, bytes memory data, bytes memory expected)
        private
        view
        returns (bool, bytes memory)
    {
        (bool ok, bytes memory actual) = target.staticcall(data);
        return (ok && keccak256(actual) == keccak256(expected), actual);
    }

    function _nativeReads() private view returns (bytes[] memory c) {
        c = new bytes[](24);
        uint256 i;
        c[i++] = abi.encodeCall(nativeSale.PRIMARY_POLICY_DOMAIN, ());
        c[i++] = abi.encodeCall(nativeSale.REVENUE_CLASS, ());
        c[i++] = abi.encodeCall(nativeSale.SALE_AUTHORIZATION_TYPEHASH, ());
        c[i++] = abi.encodeCall(nativeSale.artistRegistry, ());
        c[i++] = abi.encodeCall(nativeSale.artistRegistryCodeHash, ());
        c[i++] = abi.encodeCall(nativeSale.authorizationDigest, (_native(address(0xBEEF))));
        c[i++] = abi.encodeCall(nativeSale.authorizationId, (artist, bytes32(uint256(1))));
        c[i++] = abi.encodeCall(nativeSale.authorizationUsed, (artist, bytes32(uint256(1))));
        c[i++] = abi.encodeCall(nativeSale.domainSeparator, ());
        c[i++] = abi.encodeCall(nativeSale.eip712Domain, ());
        c[i++] = abi.encodeCall(nativeSale.fundingEscrowCodeHash, ());
        c[i++] = abi.encodeCall(nativeSale.fundingFactoryCodeHash, ());
        c[i++] = abi.encodeCall(nativeSale.mintManager, ());
        c[i++] = abi.encodeCall(nativeSale.nativeProceeds, (profile));
        c[i++] = abi.encodeCall(nativeSale.owner, ());
        c[i++] = abi.encodeCall(nativeSale.paused, ());
        c[i++] = abi.encodeCall(nativeSale.platformSigner, ());
        c[i++] = abi.encodeCall(nativeSale.primaryPolicy, (1));
        c[i++] = abi.encodeCall(nativeSale.revenueEscrow, ());
        c[i++] = abi.encodeCall(nativeSale.revenueResolver, ());
        c[i++] = abi.encodeCall(nativeSale.signerEpoch, ());
        c[i++] = abi.encodeCall(nativeSale.splitFactory, ());
        c[i++] = abi.encodeCall(
            nativeSale.supportsInterface, (type(IStreamFixedPriceSaleAdapter).interfaceId)
        );
        c[i++] = abi.encodeCall(nativeSale.totalNativeProceeds, ());
        require(i == c.length, "all native reads");
    }

    function _tokenReads() private view returns (bytes[] memory c) {
        c = new bytes[](35);
        uint256 i;
        c[i++] = abi.encodeCall(tokenSale.PAYMENT_INTENT_REVOCATION_TYPEHASH, ());
        c[i++] = abi.encodeCall(tokenSale.PAYMENT_INTENT_TYPEHASH, ());
        c[i++] = abi.encodeCall(tokenSale.PRIMARY_POLICY_DOMAIN, ());
        c[i++] = abi.encodeCall(tokenSale.REVENUE_CLASS, ());
        c[i++] = abi.encodeCall(tokenSale.SALE_AUTHORIZATION_TYPEHASH, ());
        c[i++] = abi.encodeCall(tokenSale.STREAM_SALE_V1, ());
        c[i++] = abi.encodeCall(tokenSale.artistRegistry, ());
        c[i++] = abi.encodeCall(tokenSale.artistRegistryCodeHash, ());
        c[i++] = abi.encodeCall(tokenSale.assetPolicyRegistry, ());
        c[i++] = abi.encodeCall(tokenSale.authorizationDigest, (_erc20(address(0xBEEF))));
        c[i++] = abi.encodeCall(tokenSale.authorizationId, (artist, bytes32(uint256(1))));
        c[i++] = abi.encodeCall(tokenSale.authorizationUsed, (artist, bytes32(uint256(1))));
        c[i++] = abi.encodeCall(tokenSale.domainSeparator, ());
        c[i++] = abi.encodeCall(tokenSale.eip712Domain, ());
        c[i++] = abi.encodeCall(tokenSale.fundingEscrowCodeHash, ());
        c[i++] = abi.encodeCall(tokenSale.fundingFactoryCodeHash, ());
        c[i++] = abi.encodeCall(tokenSale.isPaymentIntentNonceUsed, (payer, bytes32(uint256(1))));
        c[i++] = abi.encodeCall(tokenSale.mintManager, ());
        c[i++] = abi.encodeCall(tokenSale.nextSaleNonce, ());
        c[i++] = abi.encodeCall(tokenSale.owner, ());
        c[i++] = abi.encodeCall(tokenSale.paused, ());
        c[i++] = abi.encodeCall(tokenSale.paymentIntentDigest, (_intent(payer)));
        c[i++] = abi.encodeCall(
            tokenSale.paymentIntentRevocationDigest, (payer, bytes32(uint256(1)), uint64(1))
        );
        c[i++] = abi.encodeCall(tokenSale.platformSigner, ());
        c[i++] = abi.encodeCall(tokenSale.primaryPolicy, (1, CLASS));
        c[i++] = abi.encodeCall(tokenSale.proceeds, (profile, address(token)));
        c[i++] = abi.encodeCall(tokenSale.revenueEscrow, ());
        c[i++] = abi.encodeCall(tokenSale.revenueResolver, ());
        c[i++] = abi.encodeCall(tokenSale.saleIdFor, (1, PHASE, 1));
        c[i++] = abi.encodeCall(tokenSale.saleRecord, (saleId));
        c[i++] = abi.encodeCall(tokenSale.signatureGasLimit, ());
        c[i++] = abi.encodeCall(tokenSale.signerEpoch, ());
        c[i++] = abi.encodeCall(tokenSale.splitFactory, ());
        c[i++] = abi.encodeCall(
            tokenSale.supportsInterface, (type(IStreamERC20FixedPriceSaleAdapter).interfaceId)
        );
        c[i++] = abi.encodeCall(tokenSale.totalProceeds, (address(token)));
        require(i == c.length, "all core token reads");
    }

    function _native(address recipient)
        private
        view
        returns (IStreamFixedPriceSaleAdapter.SaleAuthorization memory a)
    {
        (bytes32 primary,,) = nativeSale.primaryPolicy(1);
        a = IStreamFixedPriceSaleAdapter.SaleAuthorization(
            1,
            PHASE,
            payer,
            recipient,
            artist,
            profile,
            primary,
            keccak256(hex"1234"),
            keccak256("commitment"),
            manager.POLICY(),
            1 ether,
            keccak256("native nonce"),
            uint64(block.timestamp + 1 days),
            1
        );
    }

    function _erc20(address recipient)
        private
        view
        returns (IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory a)
    {
        a = IStreamERC20FixedPriceSaleAdapter.SaleAuthorization(
            saleId,
            tokenSale.saleRecord(saleId).configHash,
            payer,
            recipient,
            artist,
            keccak256(hex"1234"),
            keccak256("commitment"),
            keccak256("token nonce"),
            uint64(block.timestamp + 1 days),
            1
        );
    }

    function _buyNative(IStreamFixedPriceSaleAdapter.SaleAuthorization memory a)
        private
        returns (bytes32 root)
    {
        (bytes memory ps, bytes memory as_) = _nativeSignatures(a);
        vm.prank(payer);
        (, root) = nativeSale.buy{ value: a.price }(a, hex"1234", ps, as_);
    }

    function _nativeSignatures(IStreamFixedPriceSaleAdapter.SaleAuthorization memory a)
        private
        returns (bytes memory, bytes memory)
    {
        bytes32 digest = nativeSale.authorizationDigest(a);
        return (_sign(PLATFORM_KEY, digest), _sign(ARTIST_KEY, digest));
    }

    function _tokenSignatures(IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory a)
        private
        returns (bytes memory, bytes memory)
    {
        bytes32 digest = tokenSale.authorizationDigest(a);
        return (_sign(PLATFORM_KEY, digest), _sign(ARTIST_KEY, digest));
    }

    function _buyToken(IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory a, bool relayed)
        private
        returns (bytes32 root)
    {
        (bytes memory ps, bytes memory as_) = _tokenSignatures(a);
        IStreamPaymentIntentVerifier.PaymentIntent memory intent;
        bytes memory signature;
        if (relayed) {
            (bytes32 primary,,) = tokenSale.primaryPolicy(1, CLASS);
            intent = IStreamPaymentIntentVerifier.PaymentIntent(
                payer,
                address(token),
                1000,
                saleId,
                primary,
                keccak256("payer nonce"),
                uint64(block.timestamp + 1 days)
            );
            signature = _sign(PAYER_KEY, tokenSale.paymentIntentDigest(intent));
        } else {
            vm.prank(payer);
        }
        (, root) = tokenSale.buy(a, hex"1234", ps, as_, intent, signature);
    }

    function _sign(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _admit(address producer, bool enabled) private {
        (bytes32 scope, bytes32 oldState, bytes32 newState) =
            escrow.creditProducerTransitionHashes(producer, enabled);
        revenueAuthority.setCurrentAction(
            true, bytes32(++actionNonce), 1, scope, oldState, newState
        );
        vm.prank(address(revenueAuthority));
        escrow.setCreditProducer(producer, enabled);
        revenueAuthority.setCurrentAction(false, bytes32(0), 0, bytes32(0), bytes32(0), bytes32(0));
    }
}
