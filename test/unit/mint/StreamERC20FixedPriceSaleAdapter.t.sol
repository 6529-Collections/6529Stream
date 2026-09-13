// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RevenueV1TestBase.sol";
import "../../helpers/RevenueResolverTestMocks.sol";
import "../../helpers/SaleFundingTestMocks.sol";
import "../../../smart-contracts/domains/revenue/StreamRevenueEscrow.sol";
import "../../../smart-contracts/domains/mint/StreamERC20FixedPriceSaleAdapter.sol";
import "../../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";
import "../../../smart-contracts/domains/revenue/StreamSplitFactory.sol";
import "../../../smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol";
import "../../mocks/MockStreamPaymentToken.sol";

/// @dev Lightweight manager boundary for domain failures. The current suite uses the real manager/Core.
contract ERC20SaleManagerBoundary {
    address public immutable core;
    bytes32 public constant POLICY = keccak256("manager policy");
    uint256 public minted;
    uint256 public mode;

    constructor(address core_) {
        core = core_;
    }

    function setMode(uint256 value) external {
        mode = value;
    }

    function phasePolicyHash(uint256, bytes32) external pure returns (bytes32) {
        return POLICY;
    }

    function previewSingleStepMintOperation(
        IStreamMintManager.MintBatch calldata batch,
        bytes calldata
    ) external view returns (bytes32 root, bytes32[] memory ids) {
        return _identity(batch);
    }

    function executeSingleStepMint(IStreamMintManager.MintBatch calldata batch, bytes calldata)
        external
        returns (uint256[] memory tokens, bytes32 root, bytes32[] memory ids)
    {
        require(mode != 1, "mint failed");
        (root, ids) = _identity(batch);
        tokens = new uint256[](1);
        tokens[0] = ++minted;
        if (mode == 2) root = bytes32(uint256(root) + 1);
        if (mode == 3) ids[0] = bytes32(uint256(ids[0]) + 1);
        if (mode == 4) tokens[0] = 0;
    }

    function _identity(IStreamMintManager.MintBatch calldata batch)
        private
        view
        returns (bytes32 root, bytes32[] memory ids)
    {
        root = keccak256(abi.encode(batch, msg.sender, minted));
        ids = new bytes32[](1);
        ids[0] = keccak256(abi.encode(root, uint256(0)));
    }
}

/// @dev Exact attribution/economics read seam for adapter failures; not an artist authorization implementation.
contract ERC20SaleArtistBoundary {
    address public immutable core;
    address public artist;
    address private _consentedResolver;
    bytes32 private _consentedAssignment;

    constructor(address core_) {
        core = core_;
    }

    function setArtist(address value) external {
        artist = value;
    }

    /// @dev This domain fixture explicitly elects NONE; the separate legacy guard suite
    /// exercises REQUIRED, malformed reads and callback changes at this authority boundary.
    function saleConsentScope(uint256 collectionId) external pure returns (uint8) {
        require(collectionId == 1, "unknown collection");
        return 0;
    }

    function approveAssignmentRead(address resolver, bytes32 assignment) external {
        _consentedResolver = resolver;
        _consentedAssignment = assignment;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamArtistAttribution).interfaceId
            || id == type(IStreamArtistEconomicsAuthority).interfaceId
            || id == type(IERC165).interfaceId;
    }

    function acceptedArtist(uint256 collectionId) external view returns (address) {
        return collectionId == 1 ? artist : address(0);
    }

    function attribution(uint256 collectionId)
        external
        view
        returns (IStreamCollectionArtistRegistry.Attribution memory a)
    {
        if (collectionId != 1) return a;
        a.artist = artist;
        if (artist != address(0)) {
            a.nominationHash = keccak256("adapter domain nomination");
            a.acceptanceHash = keccak256("adapter domain acceptance");
        }
    }

    function requireEconomicsConsent(
        uint256 collection,
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        bytes32 assignment
    ) external view {
        require(
            msg.sender == _consentedResolver && collection == 1 && scope == 1 && scopeId == 1
                && revenueClass == keccak256("PRIMARY_SALE") && assignment == _consentedAssignment
                && assignment != bytes32(0),
            "exact economics read only"
        );
    }
}

contract StreamERC20FixedPriceSaleAdapterTest is RevenueV1TestBase {
    uint256 private constant PAYER_KEY = 0xA11CE;
    uint256 private constant PLATFORM_KEY = 0xB0B;
    uint256 private constant ARTIST_KEY = 0xCAFE;
    bytes32 private constant PHASE = keccak256("erc20 phase");
    bytes32 private constant REVENUE = keccak256("PRIMARY_SALE");
    bytes private constant DATA = "erc20 artwork";
    address private payer;
    address private artist;
    StreamERC20FixedPriceSaleAdapter private sale;
    StreamAssetPolicyRegistry private assets;
    StreamSplitFactory private factory;
    StreamRevenueResolver private resolver;
    StreamRevenueEscrow private escrow;
    RevenueResolverCoreMock private core;
    SaleFundingFaultVm private constant faultVm = SaleFundingFaultVm(address(vm));
    ERC20SaleManagerBoundary private manager;
    ERC20SaleArtistBoundary private artists;
    MockStreamPaymentToken private token;
    bytes32 private profile;
    address private wallet;
    bytes32 private saleId;

    function setUp() public {
        payer = vm.addr(PAYER_KEY);
        artist = vm.addr(ARTIST_KEY);
        core = new RevenueResolverCoreMock();
        manager = new ERC20SaleManagerBoundary(address(core));
        artists = new ERC20SaleArtistBoundary(address(core));
        core.selectArtist(address(artists), address(artists).codehash);
        assets = new StreamAssetPolicyRegistry(address(_revenueAuthority()));
        IStreamGasParameterHost.GasParameterConfig[3] memory configs = _walletGasConfigs();
        configs[2].genesisValue = 300_000;
        factory = new StreamSplitFactory(assets, address(revenueAuthority), configs);
        resolver = new StreamRevenueResolver(
            IStreamCore(address(core)),
            factory,
            address(revenueAuthority),
            IStreamArtistAttribution(address(artists)),
            IStreamGasParameterHost.GasParameterConfig(
                "ARTIST_BENEFICIARY_READ_GAS", 200_000, 50_000, 2
            )
        );
        vm.prank(address(revenueAuthority));
        resolver.transferOwnership(address(this));
        escrow = new StreamRevenueEscrow(
            factory,
            address(revenueAuthority),
            IStreamGasParameterHost.GasParameterConfig("FLUSH_GAS_FLOOR", 12_000_000, 12_000_000, 3)
        );
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](2);
        entries[0] = IStreamSplitWallet.SplitEntry(artist, 900_000, keccak256("artist"));
        entries[1] = IStreamSplitWallet.SplitEntry(address(0xFEE), 100_000, keccak256("protocol"));
        (profile, wallet) = factory.createProfile(entries, keccak256("metadata"));
        resolver.setPrimaryProfileAssignment(REVENUE, 0, 0, profile, bytes32(0));
        resolver.setPrimaryProfileAssignment(REVENUE, 1, 1, profile, bytes32(0));
        artists.setArtist(artist);
        token = new MockStreamPaymentToken();
        token.mint(payer, 10_000);
        _setAssetPolicy(assets, address(token), 1, keccak256("standard token"), 0);
        sale = new StreamERC20FixedPriceSaleAdapter(
            IStreamMintManager(address(manager)),
            resolver,
            vm.addr(PLATFORM_KEY),
            IStreamArtistAttribution(address(artists)),
            escrow
        );
        _admitSale();
        vm.prank(payer);
        token.approve(address(sale), 10_000);
        saleId = sale.registerSale(_config());
    }

    function testRelayedPurchaseCreditsRealWalletAndWithdrawsShares() public {
        IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory authorization = _authorization(1);
        _buy(authorization, true);
        require(
            manager.minted() == 1 && token.rawBalance(wallet) == 100
                && token.rawBalance(payer) == 9_900,
            "paid mint"
        );
        require(
            token.rawBalance(address(sale)) == 0 && sale.proceeds(profile, address(token)) == 100,
            "exact proceeds"
        );
        IStreamSplitWallet(wallet).release(address(token), artist, payable(artist));
        IStreamSplitWallet(wallet).release(address(token), address(0xFEE), payable(address(0xFEE)));
        require(
            token.rawBalance(artist) == 90 && token.rawBalance(address(0xFEE)) == 10,
            "real split release"
        );
    }

    function testCanonicalSaleIdentityAndPrimaryPolicyAreIndependentlyReconstructed() public view {
        bytes32 expectedId = keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_V1"),
                block.chainid,
                address(sale),
                uint8(0),
                uint256(1),
                PHASE,
                uint256(1)
            )
        );
        require(saleId == expectedId, "SSA identity");
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory assignment =
            resolver.resolvePrimaryAssignment(1, 0, REVENUE);
        bytes32 expectedPolicy = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_POLICY_V1"),
                block.chainid,
                address(resolver),
                REVENUE,
                uint256(1),
                uint256(0),
                bytes32(0),
                profile,
                wallet,
                assignment.assignmentHash
            )
        );
        (bytes32 actual,,) = sale.primaryPolicy(1, REVENUE);
        require(expectedPolicy == actual, "canonical actual resolver commitment");
    }

    function testLiteralPayerExemptionAndReplayAreBoundedByCommercialSignatures() public {
        IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory authorization = _authorization(1);
        _buy(authorization, false);
        require(
            manager.minted() == 1 && !sale.isPaymentIntentNonceUsed(payer, bytes32(uint256(1))),
            "direct payer"
        );
        bytes memory callData = _buyData(authorization, false);
        vm.prank(payer);
        (bool ok,) = address(sale).call(callData);
        require(
            !ok && manager.minted() == 1 && token.rawBalance(wallet) == 100,
            "commercial replay prevented"
        );
    }

    function testRelayerCannotUseStandingAllowanceOrCallerExemption() public {
        bytes memory callData = _buyData(_authorization(1), false);
        (bool ok,) = address(sale).call(callData);
        require(!ok, "unsigned relayer accepted");
        _assertUnchanged();
    }

    function testRepeatedPurchasesUseIndependentExecutionIdentitiesWithinOneSale() public {
        _buy(_authorization(1), true);
        _buy(_authorization(2), true);
        require(
            manager.minted() == 2 && sale.totalProceeds(address(token)) == 200,
            "second legitimate purchase"
        );
        require(sale.nextSaleNonce() == 2, "one sale program");
    }

    function testFrozenAssignmentInvalidatesStrictPolicyBeforeTokenCalls() public {
        bytes memory callData = _buyData(_authorization(1), true);
        bytes32 expected = sale.saleRecord(saleId).config.expectedPrimaryPolicyHash;
        bytes32 frozenHash =
            resolver.primaryAssignmentHash(REVENUE, 1, 1, 1, profile, bytes32(0), bytes32(0), true);
        artists.approveAssignmentRead(address(resolver), frozenHash);
        resolver.freezePrimaryAssignment(REVENUE, 1, 1);
        (bytes32 actual,,) = sale.primaryPolicy(1, REVENUE);
        (bool ok, bytes memory result) = address(sale).call(callData);
        require(
            !ok
                && keccak256(result)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamERC20FixedPriceSaleAdapter.PrimaryPolicyMismatch.selector,
                            expected,
                            actual
                        )
                    ),
            "frozen bit drift ignored"
        );
        _assertUnchanged();
    }

    function testStaleSignerEpochRejectsBeforeTokenCalls() public {
        bytes memory callData = _buyData(_authorization(1), true);
        sale.setPlatformSigner(vm.addr(PLATFORM_KEY));
        (bool ok, bytes memory result) = address(sale).call(callData);
        require(
            !ok
                && keccak256(result)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamERC20FixedPriceSaleAdapter.InvalidSaleAuthorization.selector
                        )
                    ),
            "stale epoch ignored"
        );
        _assertUnchanged();
    }

    function testUnapprovedArtistRejectsBeforeTokenCalls() public {
        bytes memory callData = _buyData(_authorization(1), true);
        artists.setArtist(address(0xBAD));
        (bool ok, bytes memory result) = address(sale).call(callData);
        require(
            !ok
                && keccak256(result)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamCollectionArtistRegistry.ArtistRegistryArtistMismatch.selector,
                            uint256(1),
                            address(0xBAD),
                            artist
                        )
                    ),
            "artist attribution ignored"
        );
        _assertUnchanged();
    }

    function testCollectionAssignmentOverridesDefaultAndDefaultOnlySalesAreRejected() public {
        bytes32 beforeHash = _config().expectedPrimaryPolicyHash;
        // Unbound collection 2 inherits the default for resolver reads, but commerce requires its own assignment.
        require(resolver.resolvePrimaryAssignment(2, 0, REVENUE).scope == 0, "inherited default");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamERC20FixedPriceSaleAdapter.UnsupportedPrimaryAssignment.selector
            )
        );
        sale.primaryPolicy(2, REVENUE);
        require(resolver.resolvePrimaryAssignment(1, 0, REVENUE).scope == 1, "collection wins");
        resolver.setPrimaryProfileAssignment(REVENUE, 0, 0, profile, bytes32(0));
        (bytes32 afterHash,,) = sale.primaryPolicy(1, REVENUE);
        require(beforeHash == afterHash, "default mutation changed explicit collection");
        _buy(_authorization(1), true);
        require(manager.minted() == 1, "original collection terms remain valid");
    }

    function testNonstandardTokenAndBothTransferLegFailuresRollbackEverything() public {
        bytes memory callData = _buyData(_authorization(1), true);
        for (uint8 leg = 1; leg <= 2; ++leg) {
            for (uint8 mode = 1; mode <= 9; ++mode) {
                token.configure(mode, leg);
                (bool ok, bytes memory errorData) = address(sale).call(callData);
                bytes4 expected = mode >= 7
                    ? IStreamSaleFunding.SaleFundingTokenReadFailed.selector
                    : (mode == 2 || mode == 3 || mode == 4)
                        ? IStreamSaleFunding.SaleFundingAmountMismatch.selector
                        : IStreamSaleFunding.SaleFundingTokenCallFailed.selector;
                bytes4 observed;
                assembly { observed := mload(add(errorData, 32)) }
                require(!ok && observed == expected, "wrong nonstandard token failure");
                _assertUnchanged();
            }
        }
        token.configure(0, 0);
        _buy(_authorization(1), true);
        require(manager.minted() == 1, "same intent succeeds after rollback");
    }

    function testInactiveAssetRejectsBeforePull() public {
        _setAssetPolicy(assets, address(token), 2, keccak256("inactive"), 0);
        bytes memory callData = _buyData(_authorization(1), true);
        (bool ok,) = address(sale).call(callData);
        require(!ok, "inactive asset");
        _assertUnchanged();
    }

    function testMintFailureOrReturnedIdentityMismatchRollsBackPaymentAndNonces() public {
        bytes memory callData = _buyData(_authorization(1), true);
        for (uint256 mode = 1; mode <= 4; ++mode) {
            manager.setMode(mode);
            (bool ok, bytes memory errorData) = address(sale).call(callData);
            bytes memory expected = mode == 1
                ? abi.encodeWithSignature("Error(string)", "mint failed")
                : abi.encodeWithSelector(
                    IStreamERC20FixedPriceSaleAdapter.SaleMintResultInvalid.selector
                );
            require(!ok && keccak256(errorData) == keccak256(expected), "wrong mint result failure");
            _assertUnchanged();
        }
    }

    function testRevertedPayerPullIsAtomicAndSameIntentCanRetry() public {
        bytes memory callData = _buyData(_authorization(1), true);
        faultVm.mockCallRevert(
            address(token),
            0,
            abi.encodeWithSelector(
                IERC20.transferFrom.selector, payer, address(sale), uint256(100)
            ),
            abi.encodeWithSignature("Error(string)", "payer pull refused")
        );
        (bool ok, bytes memory errorData) = address(sale).call(callData);
        require(
            !ok
                && keccak256(errorData)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamSaleFunding.SaleFundingTokenCallFailed.selector,
                            address(token),
                            IERC20.transferFrom.selector
                        )
                    ),
            "payer pull must fail"
        );
        _assertUnchanged();
        faultVm.clearMockedCalls();
        (ok,) = address(sale).call(callData);
        require(
            ok && manager.minted() == 1 && token.rawBalance(wallet) == 100, "same calldata retry"
        );
    }

    function testRevertedWalletTransferRetainsExactEscrowCreditAndLaterFlushes() public {
        faultVm.mockCallRevert(
            address(token),
            0,
            abi.encodeWithSelector(IERC20.transfer.selector, wallet, uint256(100)),
            abi.encodeWithSignature("Error(string)", "wallet transfer refused")
        );
        _buy(_authorization(1), true);
        require(
            manager.minted() == 1 && token.rawBalance(payer) == 9_900
                && token.rawBalance(wallet) == 0 && token.rawBalance(address(sale)) == 0
                && token.rawBalance(address(escrow)) == 100
                && escrow.escrowOwed(REVENUE, profile, wallet, address(token)) == 100
                && sale.totalProceeds(address(token)) == 100
                && token.allowance(address(sale), address(escrow)) == 0,
            "retained exact escrow rights"
        );
        faultVm.clearMockedCalls();
        escrow.flushToVerifiedWalletBestEffort(REVENUE, profile, wallet, address(token));
        require(
            token.rawBalance(wallet) == 100 && escrow.totalOwed(address(token)) == 0,
            "actual later flush"
        );
    }

    function testTokenCallbacksCannotReenterPurchaseOrRevokeConsumedIntent() public {
        bytes memory callData = _buyData(_authorization(1), true);
        token.configureCallback(address(sale), callData, 1);
        _buy(_authorization(1), true);
        require(
            !token.callbackSucceeded() && manager.minted() == 1 && token.transferCalls() == 2,
            "purchase reentry blocked"
        );
        token.configureCallback(
            address(sale), abi.encodeCall(sale.revokePaymentIntent, (bytes32(uint256(99)))), 2
        );
        _buy(_authorization(2), true);
        require(
            !token.callbackSucceeded()
                && !sale.isPaymentIntentNonceUsed(address(token), bytes32(uint256(99))),
            "revoke reentry blocked"
        );
    }

    function testDonationIsNotCountedAsSaleRevenueAndPausePreservesRevocation() public {
        token.mint(address(sale), 17);
        token.mint(wallet, 23);
        _buy(_authorization(1), true);
        require(
            sale.totalProceeds(address(token)) == 100 && token.rawBalance(address(sale)) == 17
                && token.rawBalance(wallet) == 123,
            "donations excluded"
        );
        sale.setPaused(true);
        vm.prank(payer);
        sale.revokePaymentIntent(bytes32(uint256(2)));
        vm.prank(artist);
        sale.cancelAuthorization(bytes32(uint256(2)));
        require(
            sale.isPaymentIntentNonceUsed(payer, bytes32(uint256(2)))
                && sale.authorizationUsed(artist, bytes32(uint256(2))),
            "pause preserves cancellation"
        );
    }

    function _config()
        private
        view
        returns (IStreamERC20FixedPriceSaleAdapter.SaleConfig memory config)
    {
        (bytes32 policy,,) = sale.primaryPolicy(1, REVENUE);
        return IStreamERC20FixedPriceSaleAdapter.SaleConfig(
            1,
            PHASE,
            address(token),
            REVENUE,
            100,
            manager.POLICY(),
            policy,
            0,
            uint64(block.timestamp + 1 days)
        );
    }

    function _authorization(uint256 nonce)
        private
        view
        returns (IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory)
    {
        return IStreamERC20FixedPriceSaleAdapter.SaleAuthorization(
            saleId,
            sale.saleRecord(saleId).configHash,
            payer,
            address(0xC011EC7),
            artist,
            keccak256(DATA),
            keccak256(abi.encode(nonce)),
            bytes32(nonce),
            uint64(block.timestamp + 1 hours),
            sale.signerEpoch()
        );
    }

    function _buy(
        IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory authorization,
        bool relay
    ) private {
        bytes memory data = _buyData(authorization, relay);
        if (!relay) vm.prank(payer);
        (bool ok, bytes memory result) = address(sale).call(data);
        if (!ok) assembly { revert(add(result, 32), mload(result)) }
    }

    function _buyData(
        IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory authorization,
        bool relay
    ) private returns (bytes memory) {
        bytes32 digest = sale.authorizationDigest(authorization);
        IStreamPaymentIntentVerifier.PaymentIntent memory intent =
            IStreamPaymentIntentVerifier.PaymentIntent(
                payer,
                address(token),
                100,
                saleId,
                sale.saleRecord(saleId).config.expectedPrimaryPolicyHash,
                authorization.nonce,
                authorization.deadline
            );
        bytes memory signature =
            relay ? _sign(PAYER_KEY, sale.paymentIntentDigest(intent)) : bytes("");
        return abi.encodeCall(
            sale.buy,
            (
                authorization,
                DATA,
                _sign(PLATFORM_KEY, digest),
                _sign(ARTIST_KEY, digest),
                intent,
                signature
            )
        );
    }

    function _assertUnchanged() private view {
        require(
            manager.minted() == 0 && token.rawBalance(wallet) == 0
                && token.rawBalance(payer) == 10_000 && token.rawBalance(address(sale)) == 0
                && token.transferCalls() == 0,
            "payment or mint leaked"
        );
        require(
            sale.totalProceeds(address(token)) == 0
                && !sale.isPaymentIntentNonceUsed(payer, bytes32(uint256(1)))
                && !sale.authorizationUsed(artist, bytes32(uint256(1))),
            "accounting or replay leaked"
        );
    }

    function _admitSale() private {
        (bytes32 scope, bytes32 oldState, bytes32 newState) =
            escrow.creditProducerTransitionHashes(address(sale), true);
        revenueAuthority.setCurrentAction(
            true, keccak256("admit ERC20 domain adapter"), 1, scope, oldState, newState
        );
        vm.prank(address(revenueAuthority));
        escrow.setCreditProducer(address(sale), true);
        revenueAuthority.setCurrentAction(false, bytes32(0), 0, bytes32(0), bytes32(0), bytes32(0));
    }

    function _sign(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }
}
