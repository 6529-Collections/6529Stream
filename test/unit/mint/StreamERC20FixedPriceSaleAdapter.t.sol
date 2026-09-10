// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
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

contract ERC20SaleArtistBoundary {
    address public immutable core;
    address public artist;

    constructor(address core_, address artist_) {
        core = core_;
        artist = artist_;
    }

    function setArtist(address value) external {
        artist = value;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return
            id == type(IStreamCollectionArtistRegistry).interfaceId
                || id == type(IERC165).interfaceId;
    }

    function requireArtist(uint256, address candidate) external view {
        require(candidate == artist, "artist not approved");
    }
}

contract StreamERC20FixedPriceSaleAdapterTest is CharacterizationTestBase {
    uint256 private constant PAYER_KEY = 0xA11CE;
    uint256 private constant PLATFORM_KEY = 0xB0B;
    uint256 private constant ARTIST_KEY = 0xCAFE;
    bytes32 private constant PHASE = keccak256("erc20 phase");
    bytes32 private constant REVENUE = keccak256("primary sale");
    bytes private constant DATA = "erc20 artwork";
    address private payer;
    address private artist;
    StreamERC20FixedPriceSaleAdapter private sale;
    StreamAssetPolicyRegistry private assets;
    StreamSplitFactory private factory;
    StreamRevenueResolver private resolver;
    ERC20SaleManagerBoundary private manager;
    ERC20SaleArtistBoundary private artists;
    MockStreamPaymentToken private token;
    bytes32 private profile;
    address private wallet;
    bytes32 private saleId;

    function setUp() public {
        payer = vm.addr(PAYER_KEY);
        artist = vm.addr(ARTIST_KEY);
        manager = new ERC20SaleManagerBoundary(address(0xC0E));
        artists = new ERC20SaleArtistBoundary(manager.core(), artist);
        assets = new StreamAssetPolicyRegistry();
        factory = new StreamSplitFactory(assets);
        resolver = new StreamRevenueResolver(factory);
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](2);
        entries[0] = IStreamSplitWallet.SplitEntry(artist, 900_000, keccak256("artist"));
        entries[1] = IStreamSplitWallet.SplitEntry(address(0xFEE), 100_000, keccak256("protocol"));
        (profile, wallet) = factory.createProfile(entries, keccak256("metadata"));
        resolver.setPrimaryProfileAssignment(REVENUE, 0, 0, profile, keccak256("assignment policy"));
        token = new MockStreamPaymentToken();
        token.mint(payer, 10_000);
        assets.setAssetStatus(address(token), 1, keccak256("standard token"));
        sale = new StreamERC20FixedPriceSaleAdapter(
            IStreamMintManager(address(manager)),
            resolver,
            vm.addr(PLATFORM_KEY),
            IStreamCollectionArtistRegistry(address(artists))
        );
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
        resolver.freezePrimaryAssignment(REVENUE, 0, 0);
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
                    == keccak256(abi.encodeWithSignature("Error(string)", "artist not approved")),
            "artist attribution ignored"
        );
        _assertUnchanged();
    }

    function testCollectionAssignmentOverridesDefaultAndTemplatesAreExplicitlyUnsupported() public {
        bytes32 beforeHash = _config().expectedPrimaryPolicyHash;
        resolver.setPrimaryProfileAssignment(REVENUE, 1, 1, profile, keccak256("collection policy"));
        (bytes32 afterHash,,) = sale.primaryPolicy(1, REVENUE);
        require(beforeHash != afterHash, "collection scope commitment");
        bytes memory callData = _buyData(_authorization(1), true);
        (bool ok,) = address(sale).call(callData);
        require(!ok, "stale collection policy accepted");
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](1);
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            artist, bytes32(0), 1_000_000, keccak256("artist")
        );
        bytes32 templateId = resolver.createPrimaryTemplate(entries, keccak256("template"));
        resolver.setPrimaryTemplateAssignment(
            REVENUE, 1, 1, templateId, keccak256("template policy")
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamERC20FixedPriceSaleAdapter.UnsupportedPrimaryAssignment.selector
            )
        );
        sale.primaryPolicy(1, REVENUE);
    }

    function testNonstandardTokenAndBothTransferLegFailuresRollbackEverything() public {
        bytes memory callData = _buyData(_authorization(1), true);
        for (uint8 leg = 1; leg <= 2; ++leg) {
            for (uint8 mode = 1; mode <= 9; ++mode) {
                token.configure(mode, leg);
                (bool ok,) = address(sale).call(callData);
                require(!ok, "nonstandard token accepted");
                _assertUnchanged();
            }
        }
        token.configure(0, 0);
        _buy(_authorization(1), true);
        require(manager.minted() == 1, "same intent succeeds after rollback");
    }

    function testInactiveAssetRejectsBeforePull() public {
        assets.setAssetStatus(address(token), 2, keccak256("inactive"));
        bytes memory callData = _buyData(_authorization(1), true);
        (bool ok,) = address(sale).call(callData);
        require(!ok, "inactive asset");
        _assertUnchanged();
    }

    function testMintFailureOrReturnedIdentityMismatchRollsBackPaymentAndNonces() public {
        bytes memory callData = _buyData(_authorization(1), true);
        for (uint256 mode = 1; mode <= 4; ++mode) {
            manager.setMode(mode);
            (bool ok,) = address(sale).call(callData);
            require(!ok, "bad mint result accepted");
            _assertUnchanged();
        }
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

    function _sign(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }
}
