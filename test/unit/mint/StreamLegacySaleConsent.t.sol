// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RevenueV1TestBase.sol";
import "../../helpers/RevenueResolverTestMocks.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../../smart-contracts/domains/mint/StreamFixedPriceSaleAdapter.sol";
import "../../../smart-contracts/domains/mint/StreamERC20FixedPriceSaleAdapter.sol";
import "../../../smart-contracts/domains/auctions/StreamEnglishAuctionHouse.sol";
import "../../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";
import "../../../smart-contracts/domains/revenue/StreamRevenueEscrow.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEconomicsAuthority.sol";
import "../../mocks/MockStreamPaymentToken.sol";

/// @dev Explicit mutable authority read boundary; it is not an artist record implementation.
contract LegacySaleArtistBoundary {
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

    uint256 public scopeMode;

    function setScopeMode(uint256 value) external {
        scopeMode = value;
    }

    function saleConsentScope(uint256 collectionId) external view returns (uint8) {
        require(collectionId == 1, "unknown collection");
        uint256 mode = scopeMode;
        if (mode == 2) {
            assembly {
                mstore(0, 0)
                return(0, 31)
            }
        }
        if (mode == 3) {
            assembly {
                mstore(0, 0)
                return(0, 64)
            }
        }
        if (mode == 4) {
            assembly {
                mstore(0, 256)
                return(0, 32)
            }
        }
        if (mode == 5) revert("scope unavailable");
        return uint8(mode);
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

/// @dev NFT custody and callback boundary. Actual Core/Manager integration belongs to current tests.
contract LegacySaleCoreBoundary is RevenueResolverCoreMock {
    mapping(uint256 => address) public ownerOf;

    function mintBoundary(address to, uint256 tokenId) external {
        ownerOf[tokenId] = to;
        if (to.code.length != 0) {
            require(
                IERC721Receiver(to).onERC721Received(msg.sender, address(0), tokenId, "")
                    == IERC721Receiver.onERC721Received.selector,
                "receiver"
            );
        }
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        require(msg.sender == from && ownerOf[tokenId] == from, "custody");
        ownerOf[tokenId] = to;
        if (to.code.length != 0) {
            require(
                IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, "")
                    == IERC721Receiver.onERC721Received.selector,
                "receiver"
            );
        }
    }
}

contract LegacySaleManagerBoundary {
    LegacySaleCoreBoundary public immutable core;
    bytes32 public constant POLICY = keccak256("legacy guard manager policy");
    uint256 public minted;
    address public callbackTarget;
    bytes public callbackData;

    constructor(LegacySaleCoreBoundary core_) {
        core = core_;
    }

    function configureCallback(address target, bytes calldata data) external {
        callbackTarget = target;
        callbackData = data;
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
        (root, ids) = _identity(batch);
        tokens = new uint256[](1);
        tokens[0] = ++minted;
        core.mintBoundary(batch.initialRecipients[0], tokens[0]);
        if (callbackTarget != address(0)) {
            (bool ok,) = callbackTarget.call(callbackData);
            require(ok, "boundary callback");
        }
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

/// @notice Real legacy consumers, resolver, split factory/wallet, escrow and official threshold Safe.
/// @dev Mutable artist/Core/Manager reads and governance context are explicit unit boundaries.
contract StreamLegacySaleConsentTest is RevenueV1TestBase, OfficialSafeFixture {
    uint256 private constant PAYER_KEY = 0xA11CE;
    uint256 private constant PLATFORM_KEY = 0xB0B;
    uint256 private constant ARTIST_KEY = 0xCAFE;
    bytes32 private constant PHASE = keccak256("legacy guard phase");
    bytes32 private constant REVENUE = keccak256("PRIMARY_SALE");
    bytes private constant DATA = "legacy guard artwork";
    address private payer;
    address private artist;
    address private constant RECIPIENT = address(0xC011EC7);
    LegacySaleCoreBoundary private core;
    LegacySaleManagerBoundary private manager;
    LegacySaleArtistBoundary private artists;
    StreamAssetPolicyRegistry private assets;
    StreamSplitFactory private factory;
    StreamRevenueResolver private resolver;
    StreamRevenueEscrow private escrow;
    StreamFixedPriceSaleAdapter private nativeSale;
    StreamERC20FixedPriceSaleAdapter private erc20Sale;
    StreamEnglishAuctionHouse private auction;
    MockStreamPaymentToken private token;
    bytes32 private profile;
    address private wallet;
    bytes32 private saleId;
    uint256[] private safeKeys;

    function setUp() public {
        payer = vm.addr(PAYER_KEY);
        artist = vm.addr(ARTIST_KEY);
        core = new LegacySaleCoreBoundary();
        manager = new LegacySaleManagerBoundary(core);
        artists = new LegacySaleArtistBoundary(address(core));
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
        nativeSale = new StreamFixedPriceSaleAdapter(
            IStreamMintManager(address(manager)),
            resolver,
            vm.addr(PLATFORM_KEY),
            IStreamArtistAttribution(address(artists)),
            escrow
        );
        erc20Sale = new StreamERC20FixedPriceSaleAdapter(
            IStreamMintManager(address(manager)),
            resolver,
            vm.addr(PLATFORM_KEY),
            IStreamArtistAttribution(address(artists)),
            escrow
        );
        auction = new StreamEnglishAuctionHouse(
            IStreamCore(address(core)),
            IStreamMintManager(address(manager)),
            resolver,
            vm.addr(PLATFORM_KEY),
            IStreamArtistAttribution(address(artists)),
            escrow
        );
        _admit(address(nativeSale));
        _admit(address(erc20Sale));
        _admit(address(auction));
        vm.prank(payer);
        token.approve(address(erc20Sale), 10_000);
        (bytes32 policy,,) = erc20Sale.primaryPolicy(1, REVENUE);
        saleId = erc20Sale.registerSale(
            IStreamERC20FixedPriceSaleAdapter.SaleConfig(
                1,
                PHASE,
                address(token),
                REVENUE,
                100,
                manager.POLICY(),
                policy,
                0,
                uint64(block.timestamp + 1 days)
            )
        );
        vm.deal(payer, 100 ether);
    }

    function testNativeRequiredRejectsBeforeFundsThenSameAuthorizationSucceeds() public {
        _requiredAndRetry(0);
    }

    function testERC20RequiredRejectsBeforePullThenSameAuthorizationSucceeds() public {
        _requiredAndRetry(1);
    }

    function testAuctionRequiredRejectsBeforeMintThenSameAuthorizationSucceeds() public {
        _requiredAndRetry(2);
    }

    function testMalformedUnknownAndFailedScopeReadsFailClosedOnAllLanes() public {
        for (uint8 lane; lane < 3; ++lane) {
            (address target, uint256 value, bytes memory data) = _callData(lane);
            for (uint256 mode = 2; mode <= 6; ++mode) {
                artists.setScopeMode(mode);
                _reject(
                    target,
                    value,
                    data,
                    abi.encodeWithSelector(
                        StreamLegacySaleConsent.LegacySaleConsentReadFailed.selector,
                        address(artists),
                        1
                    )
                );
                _unchanged();
            }
        }
        artists.setScopeMode(0);
        (address target, uint256 value, bytes memory data) = _callData(0);
        _call(target, value, data);
        require(manager.minted() == 1 && wallet.balance == 1 ether, "same context positive control");
    }

    function testERC20PaymentCallbackRequiredScopeRollsBackFundsAndReplay() public {
        (address target, uint256 value, bytes memory data) = _callData(1);
        token.configureCallback(address(artists), abi.encodeCall(artists.setScopeMode, (1)), 1);
        _reject(target, value, data, _required());
        _unchanged();
        require(artists.scopeMode() == 0 && !token.callbackSucceeded(), "callback reverted");
        token.configureCallback(address(0), "", 0);
        _call(target, value, data);
        require(token.rawBalance(wallet) == 100 && manager.minted() == 1, "same payment retries");
    }

    function testNativeFinalMintCallbackScopeChangeRollsBack() public {
        _lateMint(0);
    }

    function testERC20FinalMintCallbackScopeChangeRollsBack() public {
        _lateMint(1);
    }

    function testAuctionMintCallbackScopeChangeRollsBack() public {
        _lateMint(2);
    }

    function testFinalMintCallbackCannotSubstituteCoreSelectedFacade() public {
        (address target, uint256 value, bytes memory data) = _callData(0);
        manager.configureCallback(
            address(core), abi.encodeCall(core.selectArtist, (address(0xBAD), bytes32(0)))
        );
        _reject(
            target,
            value,
            data,
            abi.encodeWithSelector(
                StreamSaleArtist.ArtistRegistryBindingChanged.selector, address(0xBAD)
            )
        );
        _unchanged();
        require(core.selectedArtist() == address(artists), "pointer mutation rolled back");
        manager.configureCallback(address(0), "");
        _call(target, value, data);
        require(manager.minted() == 1, "same authorization retries");
    }

    function testNoneAuctionKeepsBidsRefundsAndSettlementAfterLaterRequiredScope() public {
        (address target, uint256 value, bytes memory data) = _callData(2);
        _call(target, value, data);
        artists.setScopeMode(1); // Qualified authority boundary; production binding scope is immutable.
        address bidder2 = address(0xB1D2);
        vm.deal(bidder2, 2 ether);
        vm.prank(payer);
        auction.bid{ value: 1 ether }(1, RECIPIENT);
        vm.prank(bidder2);
        auction.bid{ value: 1.1 ether }(1, RECIPIENT);
        vm.prank(payer);
        auction.withdrawRefund(payable(payer));
        require(
            auction.refundCredit(payer) == 0 && payer.balance == 100 ether, "refund remains live"
        );
        vm.warp(auction.auction(1).endTime);
        auction.settle(1);
        require(
            core.ownerOf(1) == RECIPIENT && wallet.balance == 1.1 ether, "accrued auction settled"
        );
        require(auction.totalOwed() == 0 && auction.auction(1).settled, "liabilities discharged");
    }

    function testActualSafeNativeCallerAndArtistRejectRequiredThenExecuteNone() public {
        _safeLane(0);
    }

    function testActualSafeERC20CallerAndArtistRejectRequiredThenExecuteNone() public {
        _safeLane(1);
    }

    function testActualSafeAuctionCallerAndArtistRejectRequiredThenExecuteNone() public {
        _safeLane(2);
    }

    function _safeLane(uint8 lane) private {
        safeKeys.push(0x12345);
        safeKeys.push(0x23456);
        OfficialSafe account = createOfficialSafe(
            deploySafeComponents("1.4.1"), safeOwnerAddresses(safeKeys), 2, 991
        );
        payer = address(account);
        artist = address(account);
        artists.setArtist(artist);
        vm.deal(payer, 100 ether);
        token.mint(payer, 10_000);
        require(
            executeSafe(
                account,
                safeKeys,
                address(token),
                0,
                abi.encodeCall(token.approve, (address(erc20Sale), 10_000)),
                0
            ),
            "Safe allowance"
        );
        (address target, uint256 value, bytes memory data) = _callData(lane);
        artists.setScopeMode(1);
        uint256 nonce = account.nonce();
        bytes memory safeSignature = safeThresholdSignature(
            safeKeys,
            account.getTransactionHash(
                target, value, data, 0, 0, 0, 0, address(0), address(0), nonce
            )
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        account.execTransaction(
            target, value, data, 0, 0, 0, 0, address(0), payable(address(0)), safeSignature
        );
        require(account.nonce() == nonce && manager.minted() == 0, "Safe failure atomic");
        artists.setScopeMode(0);
        require(
            executeSafe(account, safeKeys, target, value, data, 0), "actual threshold Safe success"
        );
        require(manager.minted() == 1, "Safe purchase executed");
    }

    function _lateMint(uint8 lane) private {
        (address target, uint256 value, bytes memory data) = _callData(lane);
        manager.configureCallback(address(artists), abi.encodeCall(artists.setScopeMode, (1)));
        _reject(target, value, data, _required());
        _unchanged();
        require(
            artists.scopeMode() == 0 && core.ownerOf(1) == address(0),
            "callback and custody rollback"
        );
        manager.configureCallback(address(0), "");
        _call(target, value, data);
        require(manager.minted() == 1, "same mint retries");
    }

    function _requiredAndRetry(uint8 lane) private {
        (address target, uint256 value, bytes memory data) = _callData(lane);
        artists.setScopeMode(1);
        _reject(target, value, data, _required());
        _unchanged();
        artists.setScopeMode(0);
        _call(target, value, data);
        require(manager.minted() == 1, "exact same authorization succeeds with NONE");
    }

    function _callData(uint8 lane)
        private
        returns (address target, uint256 value, bytes memory data)
    {
        uint64 deadline = uint64(block.timestamp + 1 hours);
        if (lane == 0) {
            (bytes32 policy,,) = nativeSale.primaryPolicy(1);
            IStreamFixedPriceSaleAdapter.SaleAuthorization memory a =
                IStreamFixedPriceSaleAdapter.SaleAuthorization(
                    1,
                    PHASE,
                    payer,
                    RECIPIENT,
                    artist,
                    profile,
                    policy,
                    keccak256(DATA),
                    keccak256("mint"),
                    manager.POLICY(),
                    1 ether,
                    bytes32(uint256(1)),
                    deadline,
                    nativeSale.signerEpoch()
                );
            bytes32 digest = nativeSale.authorizationDigest(a);
            return (
                address(nativeSale),
                1 ether,
                abi.encodeCall(
                    nativeSale.buy, (a, DATA, _sign(PLATFORM_KEY, digest), _artistSignature(digest))
                )
            );
        }
        if (lane == 1) {
            IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory a =
                IStreamERC20FixedPriceSaleAdapter.SaleAuthorization(
                    saleId,
                    erc20Sale.saleRecord(saleId).configHash,
                    payer,
                    RECIPIENT,
                    artist,
                    keccak256(DATA),
                    keccak256("mint"),
                    bytes32(uint256(1)),
                    deadline,
                    erc20Sale.signerEpoch()
                );
            bytes32 digest = erc20Sale.authorizationDigest(a);
            IStreamPaymentIntentVerifier.PaymentIntent memory intent;
            return (
                address(erc20Sale),
                0,
                abi.encodeCall(
                    erc20Sale.buy,
                    (
                        a,
                        DATA,
                        _sign(PLATFORM_KEY, digest),
                        _artistSignature(digest),
                        intent,
                        bytes("")
                    )
                )
            );
        }
        (bytes32 policy,,) = auction.primaryPolicy(1);
        IStreamEnglishAuctionHouse.AuctionAuthorization memory a =
            IStreamEnglishAuctionHouse.AuctionAuthorization(
                1,
                PHASE,
                artist,
                profile,
                policy,
                keccak256(DATA),
                keccak256("mint"),
                manager.POLICY(),
                1 ether,
                uint64(block.timestamp),
                uint64(block.timestamp + 1 hours),
                300,
                500,
                bytes32(uint256(1)),
                deadline,
                auction.signerEpoch()
            );
        bytes32 digest = auction.authorizationDigest(a);
        return (
            address(auction),
            0,
            abi.encodeCall(
                auction.createAuction,
                (a, DATA, _sign(PLATFORM_KEY, digest), _artistSignature(digest))
            )
        );
    }

    function _artistSignature(bytes32 digest) private returns (bytes memory) {
        if (artist.code.length == 0) return _sign(ARTIST_KEY, digest);
        return safeThresholdSignature(
            safeKeys, safeMessageDigest(OfficialSafe(artist), abi.encode(digest))
        );
    }

    function _sign(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _required() private pure returns (bytes memory) {
        return abi.encodeWithSelector(StreamLegacySaleConsent.LegacySaleConsentRequired.selector, 1);
    }

    function _reject(address target, uint256 value, bytes memory data, bytes memory expected)
        private
    {
        vm.prank(payer);
        (bool ok, bytes memory result) = target.call{ value: value }(data);
        require(!ok && keccak256(result) == keccak256(expected), "exact target rejection");
    }

    function _call(address target, uint256 value, bytes memory data) private {
        vm.prank(payer);
        (bool ok, bytes memory result) = target.call{ value: value }(data);
        if (!ok) assembly { revert(add(result, 32), mload(result)) }
    }

    function _unchanged() private view {
        require(manager.minted() == 0 && core.ownerOf(1) == address(0), "mint rollback");
        require(
            wallet.balance == 0 && payer.balance == 100 ether && address(nativeSale).balance == 0,
            "native funds rollback"
        );
        require(
            token.rawBalance(wallet) == 0 && token.rawBalance(payer) == 10_000
                && token.transferCalls() == 0,
            "token funds rollback"
        );
        require(
            nativeSale.totalNativeProceeds() == 0 && erc20Sale.totalProceeds(address(token)) == 0,
            "proceeds rollback"
        );
        require(
            !nativeSale.authorizationUsed(artist, bytes32(uint256(1)))
                && !erc20Sale.authorizationUsed(artist, bytes32(uint256(1)))
                && !auction.authorizationUsed(artist, bytes32(uint256(1))),
            "authorization rollback"
        );
        require(
            !erc20Sale.isPaymentIntentNonceUsed(payer, bytes32(uint256(1))), "payer replay rollback"
        );
    }

    function _admit(address producer) private {
        (bytes32 scope, bytes32 oldState, bytes32 newState) =
            escrow.creditProducerTransitionHashes(producer, true);
        revenueAuthority.setCurrentAction(
            true, keccak256(abi.encode(producer)), 1, scope, oldState, newState
        );
        vm.prank(address(revenueAuthority));
        escrow.setCreditProducer(producer, true);
        revenueAuthority.setCurrentAction(false, bytes32(0), 0, bytes32(0), bytes32(0), bytes32(0));
    }
}
