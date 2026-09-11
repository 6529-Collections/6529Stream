// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RevenueV1TestBase.sol";
import "../../helpers/AuctionFundingTestMocks.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";
import "../../../smart-contracts/domains/revenue/StreamRevenueEscrow.sol";
import "../../../smart-contracts/domains/auctions/StreamEnglishAuctionHouse.sol";

contract StreamAuctionFundingTest is RevenueV1TestBase, OfficialSafeFixture {
    struct LegacyAuctionAuthorization {
        uint256 collectionId;
        bytes32 phaseId;
        address artist;
        bytes32 profileId;
        bytes32 tokenDataHash;
        bytes32 mintCommitment;
        bytes32 mintPolicyHash;
        uint256 reservePrice;
        uint64 startTime;
        uint64 endTime;
        uint32 extensionWindow;
        uint16 minBidIncrementBps;
        bytes32 nonce;
        uint64 deadline;
        uint64 signerEpoch;
    }
    uint256 private constant ARTIST_KEY = 0x222;
    uint256 private constant PLATFORM_KEY = 0x333;
    bytes32 private constant CLASS = keccak256("PRIMARY_SALE");
    bytes32 private constant PHASE = keccak256("auction phase");
    address private artist;
    address private platform;
    address private bidder = address(0xB1);
    address private rival = address(0xB2);
    AuctionFundingCoreMock private core;
    AuctionFundingManagerMock private manager;
    SaleFundingArtistMock private artists;
    StreamAssetPolicyRegistry private assets;
    StreamSplitFactory private factory;
    StreamRevenueResolver private resolver;
    StreamRevenueEscrow private escrow;
    StreamEnglishAuctionHouse private house;
    bytes32 private profile;
    address private wallet;
    uint256 private actionNonce;
    OfficialSafe private safe;
    uint256[] private safeKeys;
    event SafeSelectorObserved(address indexed target, bytes4 indexed selector, uint8 result);
    SaleFundingFaultVm private constant fault = SaleFundingFaultVm(address(vm));

    function setUp() public {
        vm.warp(1000);
        artist = vm.addr(ARTIST_KEY);
        platform = vm.addr(PLATFORM_KEY);
        assets = new StreamAssetPolicyRegistry(address(_revenueAuthority()));
        factory = new StreamSplitFactory(assets, address(revenueAuthority), _walletGasConfigs());
        core = new AuctionFundingCoreMock();
        manager = new AuctionFundingManagerMock(core);
        core.setManager(address(manager));
        artists = new SaleFundingArtistMock(address(core));
        core.selectArtist(address(artists), address(artists).codehash);
        resolver =
            new StreamRevenueResolver(IStreamCore(address(core)), factory, address(this), artists);
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] = IStreamSplitWallet.SplitEntry(artist, 1_000_000, keccak256("artist"));
        (profile, wallet) = factory.createProfile(entries, keccak256("auction profile"));
        resolver.setPrimaryProfileAssignment(CLASS, 1, 1, profile, bytes32(0));
        artists.accept(artist);
        escrow = new StreamRevenueEscrow(
            factory,
            address(revenueAuthority),
            IStreamGasParameterHost.GasParameterConfig("FLUSH_GAS_FLOOR", 12_000_000, 12_000_000, 3)
        );
        house = new StreamEnglishAuctionHouse(
            IStreamCore(address(core)),
            IStreamMintManager(address(manager)),
            resolver,
            platform,
            artists,
            escrow
        );
        _admit(true);
        vm.deal(bidder, 10 ether);
        vm.deal(rival, 10 ether);
    }

    function testPaidSettlementFundsWalletBeforeNFTAndExactFundingEvent() public {
        uint256 id = _create();
        SaleFundingReceiver receiver = new SaleFundingReceiver();
        receiver.configure(wallet, address(0), escrow, CLASS, profile, false);
        receiver.reenter(address(house), abi.encodeCall(house.settle, (id)));
        _bid(id, bidder, address(receiver), 1 ether);
        vm.warp(house.auction(id).endTime);
        vm.recordLogs();
        house.settle(id);
        _event(vm.getRecordedLogs(), id, 1 ether, false);
        require(
            receiver.observedWallet() == 1 ether && receiver.observedEscrow() == 0
                && core.ownerOf(id) == address(receiver) && house.totalOwed() == 0,
            "fund before winner transfer"
        );
        IStreamSplitWallet(wallet).release(address(0), artist, payable(artist));
        require(artist.balance == 1 ether, "actual split payout");
        require(
            bytes4(receiver.reentryReason())
                == ReentrancyGuard.ReentrancyGuardReentrantCall.selector,
            "winner callback cannot repeat settlement"
        );
    }

    function testCreatedRightsSurviveLaterPrimaryAssignmentChange() public {
        uint256 id = _create();
        IStreamEnglishAuctionHouse.Auction memory created = house.auction(id);
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] =
            IStreamSplitWallet.SplitEntry(address(0xCAFE), 1_000_000, keccak256("later profile"));
        (bytes32 laterProfile, address laterWallet) =
            factory.createProfile(entries, keccak256("later"));
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory changed =
            resolver.resolvePrimaryAssignment(1, 0, CLASS);
        changed.profileId = laterProfile;
        changed.assignmentHash = keccak256("later prospective assignment");
        // Exact read seam models an independently accepted later prospective change; no mutation bypass claim.
        AuctionFundingFaultVm(address(vm))
            .mockCall(
                address(resolver),
                abi.encodeCall(resolver.resolvePrimaryAssignment, (1, 0, CLASS)),
                abi.encode(changed)
            );
        (bytes32 laterPolicy, bytes32 selected,) = house.primaryPolicy(1);
        require(
            selected == laterProfile && laterPolicy != created.primaryPolicyHash,
            "actual policy read changed"
        );
        _bid(id, bidder, bidder, 1 ether);
        vm.warp(created.endTime);
        house.settle(id);
        require(
            wallet.balance == 1 ether && laterWallet.balance == 0
                && house.auction(id).primaryPolicyHash == created.primaryPolicyHash,
            "creation proceeds rights preserved"
        );
    }

    function testPausedAndReplacedArtistPointerDoNotBlockExistingSettlementOrRefund() public {
        uint256 id = _create();
        _bid(id, bidder, bidder, 1 ether);
        _bid(id, rival, rival, 2 ether);
        house.setPaused(true);
        core.selectArtist(address(0), bytes32(0));
        vm.prank(bidder);
        house.withdrawRefund(payable(bidder));
        vm.warp(house.auction(id).endTime);
        house.settle(id);
        require(
            bidder.balance == 10 ether && core.ownerOf(id) == rival && wallet.balance == 2 ether
                && house.totalOwed() == 0,
            "existing liabilities and NFT remain exit-able"
        );
    }

    function testRevertedDirectDepositEscrowsOriginalProfileAndReceiverSeesOwed() public {
        uint256 id = _create();
        SaleFundingReceiver receiver = new SaleFundingReceiver();
        receiver.configure(wallet, address(0), escrow, CLASS, profile, false);
        _bid(id, bidder, address(receiver), 1 ether);
        fault.mockCallRevert(wallet, 1 ether, "", "value-specific deposit fault");
        vm.warp(house.auction(id).endTime);
        vm.recordLogs();
        house.settle(id);
        _event(vm.getRecordedLogs(), id, 1 ether, true);
        require(
            receiver.observedWallet() == 0 && receiver.observedEscrow() == 1 ether
                && house.totalBidEscrow() == 0 && house.totalNativeProceeds() == 1 ether
                && address(house).balance == 0,
            "sale paid as exact original-profile debt"
        );
        fault.clearMockedCalls();
        escrow.flushToVerifiedWalletBestEffort(CLASS, profile, wallet, address(0));
        require(
            wallet.balance == 1 ether && escrow.totalOwed(address(0)) == 0, "later real delivery"
        );
    }

    function testRecipientFailureRollsBackAuctionEscrowAndRefundsThenRetrySucceeds() public {
        uint256 id = _create();
        SaleFundingReceiver receiver = new SaleFundingReceiver();
        receiver.configure(wallet, address(0), escrow, CLASS, profile, true);
        _bid(id, bidder, bidder, 1 ether);
        _bid(id, rival, address(receiver), 2 ether);
        fault.mockCallRevert(wallet, 2 ether, "", "value-specific deposit fault");
        vm.warp(house.auction(id).endTime);
        bytes32 beforeState = keccak256(abi.encode(house.auction(id)));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "receiver rejected"));
        house.settle(id);
        require(
            keccak256(abi.encode(house.auction(id))) == beforeState
                && core.ownerOf(id) == address(house) && house.totalOwed() == 3 ether
                && house.refundCredit(bidder) == 1 ether && house.totalNativeProceeds() == 0
                && address(house).balance == 3 ether && escrow.totalOwed(address(0)) == 0
                && address(escrow).balance == 0,
            "whole settlement rollback"
        );
        vm.prank(rival);
        house.setDeliveryRecipient(id, rival);
        house.settle(id);
        require(
            core.ownerOf(id) == rival && escrow.totalOwed(address(0)) == 2 ether
                && house.totalOwed() == 1 ether && house.refundCredit(bidder) == 1 ether,
            "exact successful retry"
        );
    }

    function testProducerRevocationAffectsOnlyNeededFallback() public {
        uint256 id = _create();
        _bid(id, bidder, bidder, 1 ether);
        _admit(false);
        fault.mockCallRevert(wallet, 1 ether, "", "value-specific deposit fault");
        vm.warp(house.auction(id).endTime);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueEscrow.InvalidEscrowProducer.selector, address(house)
            )
        );
        house.settle(id);
        require(
            house.totalBidEscrow() == 1 ether && !house.auction(id).settled,
            "revocation cannot erase bid"
        );
        fault.clearMockedCalls();
        house.settle(id);
        require(
            wallet.balance == 1 ether && core.ownerOf(id) == bidder,
            "direct payment needs no producer fallback permission"
        );
    }

    function testMintPreviewAndResultFailuresRollBackCustodyAndAuthorization() public {
        IStreamEnglishAuctionHouse.AuctionAuthorization memory a = _authorization();
        (bytes memory ps, bytes memory as_) = _signatures(a);
        for (uint256 mode = 1; mode <= 5; ++mode) {
            manager.configure(mode);
            bytes memory error = mode == 5
                ? abi.encodeWithSignature("Error(string)", "fixture mint rejected")
                : abi.encodeWithSelector(
                    IStreamEnglishAuctionHouse.AuctionMintResultInvalid.selector
                );
            vm.expectRevert(error);
            house.createAuction(a, hex"1234", ps, as_);
            require(
                manager.nonce() == 0 && core.minted() == 0
                    && !house.authorizationUsed(artist, a.nonce),
                "preview/mint mismatch cannot create custody or consume authorization"
            );
        }
    }

    function testSignedWrongPrimaryPolicyRejectsCreation() public {
        IStreamEnglishAuctionHouse.AuctionAuthorization memory a = _authorization();
        bytes32 actual = a.expectedPrimaryPolicyHash;
        a.expectedPrimaryPolicyHash = keccak256("wrong current policy");
        (bytes memory ps, bytes memory as_) = _signatures(a);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamEnglishAuctionHouse.AuctionPrimaryPolicyMismatch.selector,
                a.expectedPrimaryPolicyHash,
                actual
            )
        );
        house.createAuction(a, hex"1234", ps, as_);
        require(core.minted() == 0, "wrong signed economics cannot mint");
    }

    function testCancelExitSurvivesPauseAndArtistPointerRemoval() public {
        uint256 id = _create();
        house.setPaused(true);
        core.selectArtist(address(0), bytes32(0));
        vm.prank(artist);
        house.cancel(id);
        require(
            core.ownerOf(id) == artist && house.auction(id).cancelled,
            "cancel original artist rights"
        );
    }

    function testUnsoldEOAExitDoesNotDependOnEscrowOrCurrentArtistPointer() public {
        uint256 id = _create();
        house.setPaused(true);
        core.selectArtist(address(0), bytes32(0));
        vm.etch(address(escrow), hex"60006000fd");
        vm.warp(house.auction(id).endTime);
        house.settle(id);
        require(
            core.ownerOf(id) == artist && house.auction(id).settled
                && house.totalNativeProceeds() == 0 && house.totalOwed() == 0,
            "no-bid exit retains original claimant"
        );
    }

    function testCompleteLegacySignatureAndABICallCannotAuthorizeV2Auction() public {
        IStreamEnglishAuctionHouse.AuctionAuthorization memory a = _authorization();
        LegacyAuctionAuthorization memory old = abi.decode(
            bytes.concat(
                abi.encode(a.collectionId, a.phaseId, a.artist, a.profileId),
                abi.encode(
                    a.tokenDataHash,
                    a.mintCommitment,
                    a.mintPolicyHash,
                    a.reservePrice,
                    a.startTime,
                    a.endTime
                ),
                abi.encode(
                    a.extensionWindow, a.minBidIncrementBps, a.nonce, a.deadline, a.signerEpoch
                )
            ),
            (LegacyAuctionAuthorization)
        );
        bytes32 typeHash = keccak256(
            "AuctionAuthorization(uint256 collectionId,bytes32 phaseId,address artist,bytes32 profileId,bytes32 tokenDataHash,bytes32 mintCommitment,bytes32 mintPolicyHash,uint256 reservePrice,uint64 startTime,uint64 endTime,uint32 extensionWindow,uint16 minBidIncrementBps,bytes32 nonce,uint64 deadline,uint64 signerEpoch)"
        );
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamEnglishAuction"),
                keccak256("1"),
                block.chainid,
                address(house)
            )
        );
        bytes32 digest =
            keccak256(abi.encodePacked(hex"1901", domain, keccak256(abi.encode(typeHash, old))));
        bytes memory ps = _sign(PLATFORM_KEY, digest);
        bytes memory as_ = _sign(ARTIST_KEY, digest);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamEnglishAuctionHouse.InvalidAuctionSignature.selector, platform
            )
        );
        house.createAuction(a, hex"1234", ps, as_);
        bytes4 selector = bytes4(
            keccak256(
                "createAuction((uint256,bytes32,address,bytes32,bytes32,bytes32,bytes32,uint256,uint64,uint64,uint32,uint16,bytes32,uint64,uint64),bytes,bytes,bytes)"
            )
        );
        (bool ok, bytes memory reason) =
            address(house).call(abi.encodeWithSelector(selector, old, hex"1234", ps, as_));
        require(
            !ok && reason.length == 0 && core.minted() == 0
                && !house.authorizationUsed(artist, a.nonce),
            "complete legacy ABI and domain have no fallback"
        );
    }

    function testActualSafeCreatesBidsRedirectsRefundsSettlesAndReceivesProceeds() public {
        _setupSafe();
        uint256 id = _safeCreate();
        _safeExec(address(house), 1 ether, abi.encodeCall(house.bid, (id, address(safe))));
        _bid(id, rival, rival, 2 ether);
        _safeExec(address(house), 3 ether, abi.encodeCall(house.bid, (id, address(0xBEEF))));
        _safeExec(address(house), 0, abi.encodeCall(house.withdrawRefund, (payable(address(safe)))));
        _safeExec(
            address(house), 0, abi.encodeCall(house.setDeliveryRecipient, (id, address(safe)))
        );
        vm.warp(house.auction(id).endTime);
        _safeExec(address(house), 0, abi.encodeCall(house.settle, (id)));
        IStreamSplitWallet(wallet).release(address(0), address(safe), payable(address(safe)));
        vm.prank(rival);
        house.withdrawRefund(payable(rival));
        require(
            core.ownerOf(id) == address(safe) && address(safe).balance == 10 ether
                && rival.balance == 10 ether && house.totalOwed() == 0
                && house.totalNativeProceeds() == 3 ether,
            "actual Safe controls every paid money/NFT leg"
        );
    }

    function testActualSafeUnsoldClaimAndCancelSurvivePauseAndPointerRemoval() public {
        _setupSafe();
        uint256 cancelled = _safeCreate();
        _safeExec(address(house), 0, abi.encodeCall(house.cancel, (cancelled)));
        uint256 unsold = _safeCreate();
        house.setPaused(true);
        core.selectArtist(address(0), bytes32(0));
        vm.warp(house.auction(unsold).endTime);
        _safeExec(address(house), 0, abi.encodeCall(house.settle, (unsold)));
        require(
            !house.auction(unsold).settled
                && house.auction(unsold).pendingNoBidNftClaimant == address(safe),
            "contract artist chooses explicit recovery"
        );
        _safeExec(address(house), 0, abi.encodeCall(house.claimNoBidNFT, (unsold, address(safe))));
        require(
            core.ownerOf(cancelled) == address(safe) && core.ownerOf(unsold) == address(safe)
                && house.totalNativeProceeds() == 0,
            "actual Safe no-bid and cancellation exits"
        );
    }

    function testActualSafeAllPublicReadsOwnerWritesAndProtocolOnlyRejection() public {
        _setupSafe();
        uint256 id = _safeCreate();
        bytes[] memory calls = _reads(id);
        for (uint256 i; i < calls.length; ++i) {
            (bool ok, bytes memory expected) = address(house).staticcall(calls[i]);
            require(ok, "valid view baseline");
            vm.prank(address(safe));
            (bool safeOk, bytes memory actual) = address(house).staticcall(calls[i]);
            require(safeOk && keccak256(actual) == keccak256(expected), "Safe read parity");
            _safeExec(address(house), 0, calls[i]);
        }
        _safeReject(
            abi.encodeCall(house.onERC721Received, (address(0), address(0), 1, bytes(""))),
            abi.encodeWithSelector(IStreamEnglishAuctionHouse.UnexpectedAuctionNFT.selector)
        );
        _safeReject(
            abi.encodeCall(house.setPaused, (true)),
            abi.encodeWithSignature("Error(string)", "Ownable: caller is not the owner")
        );
        house.transferOwnership(address(safe));
        _safeExec(address(house), 0, abi.encodeCall(house.setPaused, (true)));
        _safeExec(address(house), 0, abi.encodeCall(house.setPaused, (false)));
        _safeExec(address(house), 0, abi.encodeCall(house.setPlatformSigner, (address(safe))));
        _safeExec(
            address(house), 0, abi.encodeCall(house.cancelAuthorization, (bytes32(uint256(77))))
        );
        require(
            house.signerEpoch() == 2
                && house.authorizationUsed(address(safe), bytes32(uint256(77))),
            "Safe exact owner and creator operations"
        );
        _safeExec(address(house), 0, abi.encodeCall(house.transferOwnership, (address(safe))));
        _safeExec(address(house), 0, abi.encodeCall(house.renounceOwnership, ()));
        require(house.owner() == address(0), "actual Safe renunciation");
    }

    function _setupSafe() private {
        uint256[] memory owners = new uint256[](3);
        owners[0] = 0x501;
        owners[1] = 0x502;
        owners[2] = 0x503;
        safeKeys.push(owners[0]);
        safeKeys.push(owners[1]);
        safe = createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(owners), 2, 600);
        artist = address(safe);
        platform = address(safe);
        artists = new SaleFundingArtistMock(address(core));
        core.selectArtist(address(artists), address(artists).codehash);
        resolver =
            new StreamRevenueResolver(IStreamCore(address(core)), factory, address(this), artists);
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] = IStreamSplitWallet.SplitEntry(artist, 1_000_000, keccak256("Safe artist"));
        (profile, wallet) = factory.createProfile(entries, keccak256("Safe auction"));
        resolver.setPrimaryProfileAssignment(CLASS, 1, 1, profile, bytes32(0));
        artists.accept(artist);
        house = new StreamEnglishAuctionHouse(
            IStreamCore(address(core)),
            IStreamMintManager(address(manager)),
            resolver,
            platform,
            artists,
            escrow
        );
        _admit(true);
        vm.deal(address(safe), 10 ether);
    }

    function _safeCreate() private returns (uint256 id) {
        IStreamEnglishAuctionHouse.AuctionAuthorization memory a = _authorization();
        a.nonce = keccak256(abi.encode("Safe auction", core.minted() + 1));
        bytes memory signature = safeThresholdSignature(
            safeKeys, safeMessageDigest(safe, abi.encode(house.authorizationDigest(a)))
        );
        _safeExec(
            address(house),
            0,
            abi.encodeCall(house.createAuction, (a, hex"1234", signature, signature))
        );
        id = core.minted();
        require(core.ownerOf(id) == address(house), "actual Safe authorized custody mint");
    }

    function _safeExec(address target, uint256 value, bytes memory data) private {
        uint256 nonce = safe.nonce();
        vm.recordLogs();
        require(executeSafe(safe, safeKeys, target, value, data, 0), "actual Safe execution");
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

    function _safeReject(bytes memory data, bytes memory expected) private {
        vm.prank(address(safe));
        (bool ok, bytes memory reason) = address(house).call(data);
        require(!ok && keccak256(reason) == keccak256(expected), "exact target rejection");
        uint256 nonce = safe.nonce();
        bytes32 digest = safe.getTransactionHash(
            address(house), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory signature = safeThresholdSignature(safeKeys, digest);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        safe.execTransaction(
            address(house), 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signature
        );
        require(safe.nonce() == nonce, "failed Safe call retains nonce");
        emit SafeSelectorObserved(address(house), bytes4(data), 2);
    }

    function _reads(uint256 id) private view returns (bytes[] memory c) {
        c = new bytes[](32);
        uint256 i;
        c[i++] = abi.encodeCall(house.AUCTION_AUTHORIZATION_TYPEHASH, ());
        c[i++] = abi.encodeCall(house.PRIMARY_POLICY_DOMAIN, ());
        c[i++] = abi.encodeCall(house.REVENUE_CLASS, ());
        c[i++] = abi.encodeCall(house.artistRegistry, ());
        c[i++] = abi.encodeCall(house.artistRegistryCodeHash, ());
        c[i++] = abi.encodeCall(house.auction, (id));
        c[i++] = abi.encodeCall(house.auctionStatus, (id));
        c[i++] = abi.encodeCall(house.authorizationDigest, (_authorization()));
        c[i++] = abi.encodeCall(house.authorizationId, (artist, bytes32(uint256(1))));
        c[i++] = abi.encodeCall(house.authorizationUsed, (artist, bytes32(uint256(1))));
        c[i++] = abi.encodeCall(house.core, ());
        c[i++] = abi.encodeCall(house.domainSeparator, ());
        c[i++] = abi.encodeCall(house.fundingEscrowCodeHash, ());
        c[i++] = abi.encodeCall(house.fundingFactoryCodeHash, ());
        c[i++] = abi.encodeCall(house.minimumBid, (id));
        c[i++] = abi.encodeCall(house.mintManager, ());
        c[i++] = abi.encodeCall(house.nativeProceeds, (profile));
        c[i++] = abi.encodeCall(house.owner, ());
        c[i++] = abi.encodeCall(house.paused, ());
        c[i++] = abi.encodeCall(house.platformSigner, ());
        c[i++] = abi.encodeCall(house.primaryPolicy, (1));
        c[i++] = abi.encodeCall(house.refundCredit, (bidder));
        c[i++] = abi.encodeCall(house.revenueEscrow, ());
        c[i++] = abi.encodeCall(house.revenueResolver, ());
        c[i++] = abi.encodeCall(house.signerEpoch, ());
        c[i++] = abi.encodeCall(house.splitFactory, ());
        c[i++] =
            abi.encodeCall(house.supportsInterface, (type(IStreamEnglishAuctionHouse).interfaceId));
        c[i++] = abi.encodeCall(house.surplus, ());
        c[i++] = abi.encodeCall(house.totalBidEscrow, ());
        c[i++] = abi.encodeCall(house.totalNativeProceeds, ());
        c[i++] = abi.encodeCall(house.totalOwed, ());
        c[i++] = abi.encodeCall(house.totalRefundOwed, ());
        require(i == c.length, "all permissionless auction reads");
    }

    function testRefundFailureAndReentryPreserveOnlyItsOwedLiability() public {
        uint256 id = _create();
        _bid(id, bidder, bidder, 1 ether);
        _bid(id, rival, rival, 2 ether);
        AuctionFundingMoneyReceiver receiver = new AuctionFundingMoneyReceiver();
        receiver.configure(true, address(0), "");
        vm.prank(bidder);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamEnglishAuctionHouse.AuctionNativeTransferFailed.selector, address(receiver)
            )
        );
        house.withdrawRefund(payable(address(receiver)));
        require(
            house.refundCredit(bidder) == 1 ether && house.totalOwed() == 3 ether,
            "failed refund retains liability"
        );
        receiver.configure(
            false,
            address(house),
            abi.encodeCall(house.withdrawRefund, (payable(address(receiver))))
        );
        vm.prank(bidder);
        house.withdrawRefund(payable(address(receiver)));
        require(
            address(receiver).balance == 1 ether && house.totalOwed() == 2 ether
                && bytes4(receiver.reentryReason())
                    == ReentrancyGuard.ReentrancyGuardReentrantCall.selector,
            "one refund only and retained winner liability"
        );
    }

    function testFuzzBidRefundFundingConservation(uint96 firstRaw, uint96 secondRaw) public {
        uint256 first = uint256(firstRaw) % 1 ether + 1 ether;
        uint256 second = uint256(secondRaw) % 1 ether + 3 ether;
        uint256 id = _create();
        _bid(id, bidder, bidder, first);
        _bid(id, rival, rival, second);
        vm.warp(house.auction(id).endTime);
        house.settle(id);
        vm.prank(bidder);
        house.withdrawRefund(payable(bidder));
        require(
            wallet.balance == second && bidder.balance == 10 ether
                && rival.balance == 10 ether - second && house.totalOwed() == 0
                && address(house).balance == 0 && house.totalNativeProceeds() == second,
            "bid, refund and proceeds conservation"
        );
    }

    function _authorization()
        private
        view
        returns (IStreamEnglishAuctionHouse.AuctionAuthorization memory a)
    {
        (bytes32 policy,,) = house.primaryPolicy(1);
        a = IStreamEnglishAuctionHouse.AuctionAuthorization(
            1,
            PHASE,
            artist,
            profile,
            policy,
            keccak256(hex"1234"),
            keccak256("mint commitment"),
            manager.POLICY(),
            1 ether,
            uint64(block.timestamp),
            uint64(block.timestamp + 1 days),
            0,
            500,
            keccak256("auction nonce"),
            uint64(block.timestamp + 1 days),
            1
        );
    }

    function _create() private returns (uint256) {
        IStreamEnglishAuctionHouse.AuctionAuthorization memory a = _authorization();
        (bytes memory ps, bytes memory as_) = _signatures(a);
        return house.createAuction(a, hex"1234", ps, as_);
    }

    function _signatures(IStreamEnglishAuctionHouse.AuctionAuthorization memory a)
        private
        returns (bytes memory, bytes memory)
    {
        bytes32 digest = house.authorizationDigest(a);
        return (_sign(PLATFORM_KEY, digest), _sign(ARTIST_KEY, digest));
    }

    function _sign(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _bid(uint256 id, address who, address recipient, uint256 amount) private {
        vm.prank(who);
        house.bid{ value: amount }(id, recipient);
    }

    function _event(Vm.Log[] memory logs, uint256 id, uint256 amount, bool escrowed) private view {
        IStreamEnglishAuctionHouse.Auction memory a = house.auction(id);
        bytes32 topic = keccak256(
            "SaleRevenueFunded(uint16,bytes32,bytes32,bytes32,address,address,uint256,bool)"
        );
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(house) || logs[i].topics[0] != topic) continue;
            ++count;
            require(
                logs[i].topics[1] == a.authorizationId && logs[i].topics[2] == a.operationRoot
                    && logs[i].topics[3] == profile
                    && keccak256(logs[i].data)
                        == keccak256(abi.encode(uint16(1), wallet, address(0), amount, escrowed)),
                "exact funding event identity"
            );
        }
        require(count == 1, "one official paid settlement");
    }

    function _admit(bool enabled) private {
        (bytes32 scope, bytes32 oldState, bytes32 newState) =
            escrow.creditProducerTransitionHashes(address(house), enabled);
        revenueAuthority.setCurrentAction(
            true, bytes32(++actionNonce), 1, scope, oldState, newState
        );
        vm.prank(address(revenueAuthority));
        escrow.setCreditProducer(address(house), enabled);
        revenueAuthority.setCurrentAction(false, bytes32(0), 0, bytes32(0), bytes32(0), bytes32(0));
    }
}
