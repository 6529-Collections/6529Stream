// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RevenueV1TestBase.sol";
import "../../helpers/RevenueResolverTestMocks.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBeneficiaryFacts.sol";
import "../../helpers/SaleFundingTestMocks.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";
import "../../../smart-contracts/domains/revenue/StreamRevenueEscrow.sol";
import "../../../smart-contracts/domains/mint/StreamFixedPriceSaleAdapter.sol";
import "../../../smart-contracts/domains/mint/StreamERC20FixedPriceSaleAdapter.sol";

contract SaleTemplateArtistMock is SaleFundingArtistMock, IStreamArtistBeneficiaryFacts {
    bytes32 public identity = keccak256("template identity");
    bytes32 public designation = keccak256("first designation");
    address public payout;

    constructor(address core_, address payout_) SaleFundingArtistMock(core_) {
        payout = payout_;
    }

    function changePayout(address next) external {
        payout = next;
        designation = keccak256(abi.encode(next));
    }

    function collectionArtistBeneficiary(uint256)
        external
        view
        returns (bytes32, address, bytes32)
    {
        require(artist != address(0), "unaccepted");
        return (identity, payout, designation);
    }
}

/// @dev Real resolver/factory/wallet/escrow/adapters, explicit artist/Core/manager domain seams.
contract StreamTemplateSaleFundingTest is RevenueV1TestBase, OfficialSafeFixture {
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
    SaleTemplateArtistMock private artists;
    bytes32 private template;
    address private constant NEXT_PAYOUT = address(0xD00D);
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
        artists = new SaleTemplateArtistMock(address(core), artist);
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
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](2);
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), keccak256("COLLECTION_ARTIST"), 900_000, keccak256("artist")
        );
        entries[1] = IStreamRevenueResolver.PrimaryTemplateEntry(
            platform, bytes32(0), 100_000, keccak256("protocol")
        );
        template = resolver.createPrimaryTemplate(entries, keccak256("template sale terms"));
        resolver.setPrimaryTemplateAssignment(CLASS, 1, 1, template, bytes32(0));
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
        (bytes32 primary, bytes32 concrete, address target) = tokenSale.primaryPolicy(1, CLASS);
        profile = concrete;
        wallet = target;
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

    function testPreviewHasNoRegistrationAndCanonicalTemplatePolicyTuple() public view {
        (bytes32 concrete, address target, bytes32 entries) =
            resolver.previewCollectionPrimaryProfile(template, 1, address(0));
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a =
            resolver.resolvePrimaryAssignment(1, 0, CLASS);
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_POLICY_V1"),
                block.chainid,
                address(resolver),
                CLASS,
                uint256(1),
                uint256(0),
                template,
                concrete,
                target,
                a.assignmentHash
            )
        );
        (bytes32 nativePolicy, bytes32 nativeProfile, address nativeWallet) =
            nativeSale.primaryPolicy(1);
        (bytes32 tokenPolicy, bytes32 tokenProfile, address tokenWallet) =
            tokenSale.primaryPolicy(1, CLASS);
        require(
            nativePolicy == expected && tokenPolicy == expected && nativeProfile == concrete
                && tokenProfile == concrete && nativeWallet == target && tokenWallet == target,
            "canonical signed policy tuple"
        );
        require(
            factory.profileCount() == 0 && !factory.profileExists(concrete)
                && target.code.length == 0 && entries != bytes32(0),
            "preview is no cache effect"
        );
    }

    function testNativeUndeployedTemplateEscrowBeforeMintThenActualWalletPayout() public {
        vm.deal(wallet, 0.2 ether);
        SaleFundingReceiver receiver = new SaleFundingReceiver();
        receiver.configure(wallet, address(0), escrow, CLASS, profile, false);
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a = _native(address(receiver));
        vm.recordLogs();
        bytes32 root = _buyNative(a);
        _fundingEvent(
            vm.getRecordedLogs(),
            address(nativeSale),
            address(0),
            1 ether,
            true,
            nativeSale.authorizationId(artist, a.nonce),
            root
        );
        require(
            receiver.observedWallet() == 0.2 ether && receiver.observedEscrow() == 1 ether
                && wallet.code.length == 0,
            "owed before callback, prefunding untouched"
        );
        require(
            factory.profileExists(profile) && nativeSale.nativeProceeds(profile) == 1 ether
                && escrow.totalOwed(address(0)) == 1 ether,
            "official amount excludes prefunding"
        );
        escrow.flushEscrow(CLASS, profile, wallet, address(0));
        require(
            factory.splitWalletExists(profile) && escrow.totalOwed(address(0)) == 0
                && wallet.balance == 1.2 ether,
            "deploy and flush exact"
        );
        IStreamSplitWallet(wallet).release(address(0), artist, payable(artist));
        IStreamSplitWallet(wallet).release(address(0), platform, payable(platform));
        require(
            artist.balance == 1.08 ether && platform.balance == 0.12 ether && wallet.balance == 0,
            "actual immutable payouts including donation"
        );
    }

    function testERC20UndeployedTemplateEscrowsWithoutTokenTransferToPrediction() public {
        token.mint(wallet, 200);
        token.configure(3); // A successful no-op transfer would fail direct funding, but no direct call is allowed here.
        IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory a = _erc20(address(0xBEEF));
        vm.recordLogs();
        bytes32 root = _buyToken(a, true);
        _fundingEvent(
            vm.getRecordedLogs(),
            address(tokenSale),
            address(token),
            1000,
            true,
            tokenSale.authorizationId(artist, a.nonce),
            root
        );
        require(
            token.transferGas() == 0 && token.balanceOf(wallet) == 200 && wallet.code.length == 0
                && token.balanceOf(payer) == 9000,
            "no unowned prediction receives official funds"
        );
        require(
            token.allowance(address(tokenSale), address(escrow)) == 0
                && escrow.totalOwed(address(token)) == 1000,
            "exact producer pull and zero residual approval"
        );
        token.configure(0);
        escrow.flushEscrow(CLASS, profile, wallet, address(token));
        IStreamSplitWallet(wallet).syncAsset(address(token));
        IStreamSplitWallet(wallet).release(address(token), artist, payable(artist));
        IStreamSplitWallet(wallet).release(address(token), platform, payable(platform));
        require(
            token.balanceOf(artist) == 1080 && token.balanceOf(platform) == 120
                && token.balanceOf(wallet) == 0,
            "real token release"
        );
    }

    function testPredeployedTemplateUsesBothDirectFundingRoutes() public {
        resolver.materializeCollectionPrimaryProfile(template, 1, address(0), true);
        _admit(address(nativeSale), false);
        _admit(address(tokenSale), false);
        _buyNative(_native(address(0xBEEF)));
        _buyToken(_erc20(address(0xBEEF)), false);
        require(
            wallet.balance == 1 ether && token.balanceOf(wallet) == 1000
                && escrow.totalOwed(address(0)) == 0 && escrow.totalOwed(address(token)) == 0,
            "direct route independent of producer admission"
        );
    }

    function testPayoutRevisionBeforeExecutionInvalidatesNativeAndERC20StrictTerms() public {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a = _native(address(0xBEEF));
        (bytes memory ps, bytes memory as_) = _nativeSignatures(a);
        IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory t = _erc20(address(0xBEEF));
        (bytes memory ts, bytes memory ta) = _tokenSignatures(t);
        bytes32 prior = tokenSale.saleRecord(saleId).config.expectedPrimaryPolicyHash;
        artists.changePayout(NEXT_PAYOUT);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFixedPriceSaleAdapter.InvalidSplitProfile.selector, a.profileId
            )
        );
        vm.prank(payer);
        nativeSale.buy{ value: a.price }(a, hex"1234", ps, as_);
        (bytes32 current,,) = tokenSale.primaryPolicy(1, CLASS);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamERC20FixedPriceSaleAdapter.PrimaryPolicyMismatch.selector, prior, current
            )
        );
        vm.prank(payer);
        tokenSale.buy(t, hex"1234", ts, ta, _emptyIntent(), "");
        require(
            factory.profileCount() == 0 && payer.balance == 10 ether
                && token.balanceOf(payer) == 10_000 && manager.nonce() == 0,
            "stale commercial rights have no effects"
        );
    }

    function testPaymentCallbackPayoutRevisionKeepsAlreadyMaterializedRights() public {
        resolver.materializeCollectionPrimaryProfile(template, 1, address(0), true);
        token.setCallback(
            address(artists), abi.encodeCall(SaleTemplateArtistMock.changePayout, (NEXT_PAYOUT))
        );
        _buyToken(_erc20(address(0xBEEF)), true);
        require(
            artists.payout() == NEXT_PAYOUT && token.balanceOf(wallet) == 1000
                && tokenSale.proceeds(profile, address(token)) == 1000,
            "single settlement payout moment"
        );
        (bytes32 nextProfile, address nextWallet,) =
            resolver.previewCollectionPrimaryProfile(template, 1, address(0));
        require(
            nextProfile != profile && nextWallet != wallet && !factory.profileExists(nextProfile),
            "next settlement preview changed, prior wallet immutable"
        );
        token.setCallback(address(0), "");
        IStreamSplitWallet(wallet).syncAsset(address(token));
        IStreamSplitWallet(wallet).release(address(token), artist, payable(artist));
        require(
            token.balanceOf(artist) == 900 && token.balanceOf(NEXT_PAYOUT) == 0,
            "old rights payable"
        );
        _buyNative(_native(address(0xBEEF)));
        require(
            escrow.escrowOwed(CLASS, nextProfile, nextWallet, address(0)) == 1 ether,
            "next execution new payout"
        );
        escrow.flushEscrow(CLASS, nextProfile, nextWallet, address(0));
        IStreamSplitWallet(nextWallet).release(address(0), NEXT_PAYOUT, payable(NEXT_PAYOUT));
        require(NEXT_PAYOUT.balance == 0.9 ether, "new explicit payee");
    }

    function testInvalidRelayedIntentCannotRegisterTemplateOrPullAllowance() public {
        IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory a = _erc20(address(0xBEEF));
        (bytes memory ps, bytes memory as_) = _tokenSignatures(a);
        IStreamPaymentIntentVerifier.PaymentIntent memory intent = _intent(payer);
        bytes memory wrong = _sign(ARTIST_KEY, tokenSale.paymentIntentDigest(intent));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamPaymentIntentVerifier.InvalidPaymentSignature.selector, payer
            )
        );
        tokenSale.buy(a, hex"1234", ps, as_, intent, wrong);
        require(
            factory.profileCount() == 0 && !factory.profileExists(profile)
                && token.allowance(payer, address(tokenSale)) == 10_000
                && !tokenSale.isPaymentIntentNonceUsed(payer, intent.nonce),
            "consent before materialization or funds"
        );
    }

    function testRecipientFailureRollsBackFirstRegistrationAndEscrowThenExactRetry() public {
        SaleFundingReceiver receiver = new SaleFundingReceiver();
        receiver.configure(wallet, address(token), escrow, CLASS, profile, true);
        IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory a = _erc20(address(receiver));
        (bytes memory ps, bytes memory as_) = _tokenSignatures(a);
        IStreamPaymentIntentVerifier.PaymentIntent memory intent = _intent(payer);
        bytes memory signature = _sign(PAYER_KEY, tokenSale.paymentIntentDigest(intent));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "receiver rejected"));
        tokenSale.buy(a, hex"1234", ps, as_, intent, signature);
        require(
            factory.profileCount() == 0 && !factory.profileExists(profile)
                && token.balanceOf(payer) == 10_000 && escrow.totalOwed(address(token)) == 0
                && !tokenSale.isPaymentIntentNonceUsed(payer, intent.nonce) && manager.nonce() == 0,
            "whole registration/payment/mint rollback"
        );
        receiver.configure(wallet, address(token), escrow, CLASS, profile, false);
        tokenSale.buy(a, hex"1234", ps, as_, intent, signature);
        require(
            receiver.observedEscrow() == 1000 && factory.profileCount() == 1
                && manager.nonce() == 1,
            "identical retry"
        );
    }

    function testWrongCodePredictionAndFixedUndeployedNeverBecomeEscrow() public {
        vm.etch(wallet, hex"60006000fd");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueResolver.UnverifiedSplitProfile.selector, profile)
        );
        nativeSale.primaryPolicy(1);
        vm.etch(wallet, hex"");
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] = IStreamSplitWallet.SplitEntry(artist, 1_000_000, keccak256("artist"));
        (bytes32 fixedProfile, address fixedWallet) =
            factory.createProfile(entries, keccak256("fixed"));
        SaleFundingArtistMock fixedArtist = new SaleFundingArtistMock(address(core));
        core.selectArtist(address(fixedArtist), address(fixedArtist).codehash);
        StreamRevenueResolver fixedResolver = new StreamRevenueResolver(
            IStreamCore(address(core)),
            factory,
            address(revenueAuthority),
            fixedArtist,
            IStreamGasParameterHost.GasParameterConfig(
                "ARTIST_BENEFICIARY_READ_GAS", 200_000, 50_000, 2
            )
        );
        vm.prank(address(revenueAuthority));
        fixedResolver.transferOwnership(address(this));
        fixedResolver.setPrimaryProfileAssignment(CLASS, 1, 2, fixedProfile, bytes32(0));
        fixedArtist.accept(artist);
        StreamFixedPriceSaleAdapter fixedSale = new StreamFixedPriceSaleAdapter(
            IStreamMintManager(address(manager)), fixedResolver, platform, fixedArtist, escrow
        );
        vm.etch(fixedWallet, hex"");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamSaleFunding.SaleFundingProfileInvalid.selector, fixedProfile, fixedWallet
            )
        );
        fixedSale.primaryPolicy(2);
        require(
            escrow.totalOwed(address(0)) == 0 && escrow.totalOwed(address(token)) == 0,
            "no malformed credit"
        );
    }

    function testUnadmittedEmptyTemplateCannotRetainRegistrationOrFunds() public {
        _admit(address(tokenSale), false);
        IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory a = _erc20(address(0xBEEF));
        (bytes memory ps, bytes memory as_) = _tokenSignatures(a);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueEscrow.InvalidEscrowProducer.selector, address(tokenSale)
            )
        );
        vm.prank(payer);
        tokenSale.buy(a, hex"1234", ps, as_, _emptyIntent(), "");
        require(
            factory.profileCount() == 0 && token.balanceOf(payer) == 10_000
                && token.allowance(address(tokenSale), address(escrow)) == 0,
            "producer failure atomic"
        );
    }

    function testCallbackPointerRemovalRollsBackMaterializationPaymentAndPointer() public {
        resolver.materializeCollectionPrimaryProfile(template, 1, address(0), true);
        token.setCallback(
            address(core),
            abi.encodeCall(RevenueResolverCoreMock.selectArtist, (address(0), bytes32(0)))
        );
        IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory a = _erc20(address(0xBEEF));
        (bytes memory ps, bytes memory as_) = _tokenSignatures(a);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.InvalidPrimaryArtistRegistry.selector, address(0)
            )
        );
        vm.prank(payer);
        tokenSale.buy(a, hex"1234", ps, as_, _emptyIntent(), "");
        require(
            core.selectedArtist() == address(artists) && token.balanceOf(payer) == 10_000
                && token.balanceOf(wallet) == 0 && tokenSale.totalProceeds(address(token)) == 0,
            "current binding remains admission after callback"
        );
    }

    function testActualSafePayerPayeeAndPreviewExecution() public {
        SafeComponents memory components = deploySafeComponents("1.4.1");
        safeKeys = new uint256[](3);
        safeKeys[0] = 0xABC;
        safeKeys[1] = 0xDEF;
        safeKeys[2] = 0x123;
        safe = createOfficialSafe(
            components, safeOwnerAddresses(safeKeys), 2, uint256(keccak256("template safe"))
        );
        artists.changePayout(address(safe));
        payer = address(safe);
        vm.deal(payer, 2 ether);
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a = _native(address(0xBEEF));
        (bytes memory ps, bytes memory as_) = _nativeSignatures(a);
        uint256 nonce = safe.nonce();
        require(
            executeSafe(
                safe,
                safeKeys,
                address(nativeSale),
                a.price,
                abi.encodeCall(nativeSale.buy, (a, hex"1234", ps, as_)),
                0
            ),
            "Safe execution success"
        );
        require(
            safe.nonce() == nonce + 1 && manager.nonce() == 1
                && nativeSale.authorizationUsed(artist, a.nonce),
            "actual Safe transaction executed"
        );
        (bytes32 concrete, address target,) =
            resolver.previewCollectionPrimaryProfile(template, 1, address(0));
        escrow.flushEscrow(CLASS, concrete, target, address(0));
        IStreamSplitWallet(target).release(address(0), payer, payable(payer));
        require(payer.balance == 1.9 ether, "Safe receives actual template payout");
        nonce = safe.nonce();
        require(
            executeSafe(
                safe,
                safeKeys,
                address(resolver),
                0,
                abi.encodeCall(resolver.previewCollectionPrimaryProfile, (template, 1, address(0))),
                0
            ),
            "Safe execution success"
        );
        require(safe.nonce() == nonce + 1, "new view selector through actual Safe");
    }

    function testFuzzDeferredNativePreservesOfficialAndPassiveAmounts(
        uint96 rawPrice,
        uint96 rawDonation
    ) public {
        uint256 price = uint256(rawPrice) % 2 ether + 1;
        uint256 donation = uint256(rawDonation) % 1 ether;
        vm.deal(wallet, donation);
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a = _native(address(0xBEEF));
        a.price = price;
        _buyNative(a);
        require(
            escrow.escrowOwed(CLASS, profile, wallet, address(0)) == price
                && wallet.balance == donation && nativeSale.totalNativeProceeds() == price,
            "owed excludes passive"
        );
        escrow.flushEscrow(CLASS, profile, wallet, address(0));
        require(
            wallet.balance == price + donation && escrow.totalOwed(address(0)) == 0, "conservation"
        );
    }

    function testActualSafeRelayedERC20IntentAndTemplateTokenPayout() public {
        SafeComponents memory components = deploySafeComponents("1.4.1");
        safeKeys = new uint256[](3);
        safeKeys[0] = 0xABC;
        safeKeys[1] = 0xDEF;
        safeKeys[2] = 0x123;
        safe = createOfficialSafe(components, safeOwnerAddresses(safeKeys), 2, 991);
        payer = address(safe);
        artists.changePayout(payer);
        (bytes32 primary, bytes32 concrete, address target) = tokenSale.primaryPolicy(1, CLASS);
        IStreamERC20FixedPriceSaleAdapter.SaleConfig memory config =
        tokenSale.saleRecord(saleId).config;
        config.expectedPrimaryPolicyHash = primary;
        saleId = tokenSale.registerSale(config);
        token.mint(payer, 1000);
        require(
            executeSafe(
                safe,
                safeKeys,
                address(token),
                0,
                abi.encodeCall(token.approve, (address(tokenSale), 1000)),
                0
            ),
            "actual Safe approval"
        );
        IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory a = _erc20(address(0xBEEF));
        (bytes memory ps, bytes memory as_) = _tokenSignatures(a);
        IStreamPaymentIntentVerifier.PaymentIntent memory intent = _intent(payer);
        bytes32 digest = tokenSale.paymentIntentDigest(intent);
        bytes memory invalid = safeThresholdSignature(safeKeys, digest);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamPaymentIntentVerifier.InvalidPaymentSignature.selector, payer
            )
        );
        tokenSale.buy(a, hex"1234", ps, as_, intent, invalid);
        require(
            factory.profileCount() == 0 && token.balanceOf(payer) == 1000,
            "Safe raw digest rejected before materialization"
        );
        bytes memory signature =
            safeThresholdSignature(safeKeys, safeMessageDigest(safe, abi.encode(digest)));
        tokenSale.buy(a, hex"1234", ps, as_, intent, signature);
        require(
            tokenSale.isPaymentIntentNonceUsed(payer, intent.nonce) && token.balanceOf(payer) == 0
                && escrow.escrowOwed(CLASS, concrete, target, address(token)) == 1000,
            "actual Safe handler permits exact producer funding"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamERC20FixedPriceSaleAdapter.SaleAuthorizationUsed.selector, artist, a.nonce
            )
        );
        tokenSale.buy(a, hex"1234", ps, as_, intent, signature);
        escrow.flushEscrow(CLASS, concrete, target, address(token));
        IStreamSplitWallet(target).syncAsset(address(token));
        IStreamSplitWallet(target).release(address(token), payer, payable(payer));
        require(token.balanceOf(payer) == 900, "Safe template token payout");
    }

    function testUnavailableDesignationFailsBeforePreviewRegistrationOrPayment() public {
        artists.changePayout(address(0));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueResolver.UnresolvableArtistBeneficiary.selector, 1)
        );
        nativeSale.primaryPolicy(1);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueResolver.UnresolvableArtistBeneficiary.selector, 1)
        );
        tokenSale.primaryPolicy(1, CLASS);
        require(
            factory.profileCount() == 0 && token.balanceOf(payer) == 10_000
                && payer.balance == 10 ether,
            "unset no fallback"
        );
    }

    function _emptyIntent()
        private
        pure
        returns (IStreamPaymentIntentVerifier.PaymentIntent memory i)
    {
        return i;
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

    function _native(address recipient)
        private
        view
        returns (IStreamFixedPriceSaleAdapter.SaleAuthorization memory a)
    {
        (bytes32 primary, bytes32 currentProfile,) = nativeSale.primaryPolicy(1);
        a = IStreamFixedPriceSaleAdapter.SaleAuthorization(
            1,
            PHASE,
            payer,
            recipient,
            artist,
            currentProfile,
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
