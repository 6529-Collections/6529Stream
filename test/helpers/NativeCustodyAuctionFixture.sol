// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./NativeEnglishAuctionFixture.sol";

/// @dev Reuses actual Core/Manager/Ledger/Registry/9/rights/Safe setup. Governance, Artist and
/// entropy remain the declared target-side semantic boundaries of NativeEnglishAuctionFixture.
abstract contract NativeCustodyAuctionFixture is NativeEnglishAuctionFixture {
    /// @dev This fixture explicitly participates as a consenting poster and funding account.
    receive() external payable { }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }

    bytes32 internal constant CUSTODY_PHASE = keccak256("unpaid original custody phase");
    bytes32 internal constant CUSTODY_COUNTER = keccak256("unpaid original custody context");
    uint256 private custodyNonce;

    struct Plan {
        IStreamNativeEnglishAuction.Configuration config;
        IStreamNativeCustodyAuction.Acquisition auth;
        bytes artwork;
        bytes platformSignature;
        bytes artistSignature;
    }

    function setUp() public virtual override {
        super.setUp();
        _custodyPhase(CUSTODY_PHASE, IStreamMintManager.CounterKeyMode.CONTEXT);
        vm.deal(address(this), 100 ether);
    }

    function _custodyPhase(bytes32 phase, IStreamMintManager.CounterKeyMode mode) internal {
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = CUSTODY_COUNTER;
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            mode,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            20,
            1,
            keccak256("custody context counter")
        );
        IStreamMintManager.MintGateConfig memory gate;
        manager.configurePhase(
            1,
            phase,
            IStreamMintManager.MintPhaseConfig(false, 0, 0, 1, MANIFEST, MANIFEST),
            gate,
            ids,
            counters
        );
        manager.setPhaseExecutor(1, phase, address(house), true);
    }

    function _bindCustody() internal {
        (bytes32 scope, bytes32 old_, bytes32 next) =
            recorder.custodyHouseTransition(address(house));
        _context(scope, old_, next, 1);
        vm.prank(address(revenueAuthority));
        recorder.bindCanonicalCustodyHouse(address(house));
        _clearContext();
    }

    function _custodyProof(uint256 key, bytes32 digest) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    /// @dev External observation defeats the optimizer's transaction-stable timestamp assumption
    /// when the test intentionally advances the VM clock between two independent openings.
    function custodyFixtureTime() external view returns (uint64) {
        return uint64(block.timestamp);
    }

    function _custodyPlan(bool first, address poster, address executor)
        internal
        returns (Plan memory p)
    {
        uint64 now_ = this.custodyFixtureTime();
        p.artwork = bytes("original unpaid custody work");
        p.config.collectionId = 1;
        p.config.phaseId = CUSTODY_PHASE;
        p.config.tokenId = core.lastAllocatedTokenId() + 1;
        p.config.mintCommitment = keccak256("custody original commitment");
        p.config.poster = poster;
        p.config.reservePrice = 1000;
        p.config.minIncrementBps = 500;
        p.config.clock = StreamEnglishAuctionClock.Configuration(
            now_, first ? 0 : now_ + 3600, first ? 3600 : 0, 600, 600, 3600, first, false
        );
        p.config.expectedPrimaryPolicyHash =
            StreamNativeEnglishAuctionSupport.profilePolicy(resolver, 1);
        p.config.primaryPolicyMode = 1;
        p.config.settlementWindow = 86400;
        p.config.mintPolicyHash = manager.phasePolicyHash(1, CUSTODY_PHASE);
        (uint256 saleNonce,) = house.nextCuratedSaleId(1, CUSTODY_PHASE);
        p.auth = IStreamNativeCustodyAuction.Acquisition(
            house.auctionConfigurationHash(p.config),
            keccak256(p.artwork),
            saleNonce,
            p.config.tokenId,
            core.collectionNextSerial(1),
            manager.nextOperationNonce(),
            keccak256(abi.encode("custody context", ++custodyNonce)),
            executor,
            150,
            vm.addr(SIGNER_KEY),
            bytes32(custodyNonce),
            now_ + 1000
        );
        _signCustody(p);
    }

    function _signCustody(Plan memory p) internal {
        p.auth.configHash = house.auctionConfigurationHash(p.config);
        bytes32 hash = house.custodyAcquisitionDigest(p.auth);
        p.platformSignature = _custodyProof(AUCTION_PLATFORM_KEY, hash);
        p.artistSignature = _custodyProof(SIGNER_KEY, hash);
    }

    function _custodyCall(Plan memory p) internal view returns (bytes memory) {
        return abi.encodeCall(
            house.registerCustodyAuction,
            (p.config, p.auth, p.artwork, p.platformSignature, p.artistSignature)
        );
    }

    function _openCustody(Plan memory p) internal returns (bytes32) {
        return house.registerCustodyAuction{ value: p.auth.revealFeeDeposit }(
            p.config, p.auth, p.artwork, p.platformSignature, p.artistSignature
        );
    }

    function _custodyBid(bytes32 id, address who, uint256 amount) internal {
        vm.deal(who, 1 ether);
        vm.prank(who);
        house.bid{ value: amount }(id, address(0));
        IStreamNativeEnglishAuction.WinningBid memory w = house.auction(id).winner;
        require(
            w.payer == who && w.executor == who && w.deliverTo == who && w.amount == amount
                && w.revealFee == 0,
            "actual zero-fee custody bid"
        );
    }

    function _custodyEnd(bytes32 id) internal {
        (uint64 end,,,) = house.auctionDeadlines(id);
        vm.warp(end);
    }

    function _custodyCounter(Plan memory p) internal view returns (uint64) {
        bytes32 subject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.CONTEXT,
            1,
            p.config.phaseId,
            CUSTODY_COUNTER,
            p.auth.executor,
            address(house),
            address(house),
            address(0),
            p.auth.contextHash
        );
        return ledger.counterValue(
            manager.previewCounterValueKey(1, p.config.phaseId, CUSTODY_COUNTER, subject)
        );
    }
}
