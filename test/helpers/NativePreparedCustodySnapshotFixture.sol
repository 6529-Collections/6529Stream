// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./NativeRoyaltySnapshotFixture.sol";

abstract contract NativePreparedCustodySnapshotFixture is NativeRoyaltySnapshotFixture {
    bytes32 internal constant PREPARED_CUSTODY_PHASE = keccak256("prepared custody snapshot phase");
    bytes32 internal constant PREPARED_CUSTODY_COUNTER = keccak256("prepared custody context counter");
    struct PreparedPlan {
        IStreamNativeEnglishAuction.Configuration config;
        IStreamNativeCustodyAuction.Acquisition authorization;
        bytes artwork;
        bytes platformSignature;
        bytes artistSignature;
    }

    receive() external payable { }
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function setUp() public virtual override {
        super.setUp();
        bytes32 wrapped = manager.registerPhaseRoyaltyPolicy(1, PREPARED_CUSTODY_PHASE, _royaltyPolicy());
        bytes32[] memory ids = new bytes32[](1); ids[0] = PREPARED_CUSTODY_COUNTER;
        IStreamMintManager.MintCounterConfig[] memory counters = new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(true, IStreamMintManager.CounterKeyMode.CONTEXT,
            IStreamMintLedger.CounterCapMode.STATIC, IStreamMintLedger.CounterDeltaMode.STATIC,
            20, 1, keccak256("prepared custody context config"));
        IStreamMintManager.MintGateConfig memory gate;
        manager.configurePhase(1, PREPARED_CUSTODY_PHASE,
            IStreamMintManager.MintPhaseConfig(false, 0, 0, 1, wrapped, MANIFEST), gate, ids, counters);
        manager.setPhaseExecutor(1, PREPARED_CUSTODY_PHASE, address(house), true);
        (bytes32 scope, bytes32 oldState, bytes32 next) = recorder.custodyHouseTransition(address(house));
        _context(scope, oldState, next, 1);
        vm.prank(address(revenueAuthority)); recorder.bindCanonicalCustodyHouse(address(house));
        _clearContext();
        vm.deal(address(this), 10 ether);
    }

    function _preparedCustodyPlan(address executor) internal returns (PreparedPlan memory p) {
        p.config = _snapshotConfiguration(PREPARED_CUSTODY_PHASE);
        p.config.mintAtSettlement = false;
        p.config.artworkCommitment = 0;
        p.config.tokenId = core.lastAllocatedTokenId() + 1;
        p.artwork = bytes("prepared custody original artwork");
        (uint256 saleNonce,) = house.nextCuratedSaleId(1, PREPARED_CUSTODY_PHASE);
        p.authorization = IStreamNativeCustodyAuction.Acquisition(
            house.auctionConfigurationHash(p.config), keccak256(p.artwork), saleNonce,
            p.config.tokenId, core.collectionNextSerial(1), manager.nextOperationNonce(),
            keccak256("prepared custody original context"), executor, 150, vm.addr(SIGNER_KEY),
            keccak256("prepared custody original commercial nonce"), this.snapshotTime() + 1000);
        bytes32 hash = house.preparedCustodyAcquisitionDigest(p.authorization);
        p.platformSignature = _sig(AUCTION_PLATFORM_KEY, hash);
        p.artistSignature = _sig(SIGNER_KEY, hash);
    }

    function _preparedCustodyCall(PreparedPlan memory p) internal view returns (bytes memory) {
        return abi.encodeCall(house.registerPreparedCustodyAuction,
            (p.config, p.authorization, p.artwork, p.platformSignature, p.artistSignature));
    }

    function _preparedCustodyCounter(PreparedPlan memory p) internal view returns (uint64) {
        bytes32 subject = manager.previewSubjectKey(IStreamMintManager.CounterKeyMode.CONTEXT,
            1, PREPARED_CUSTODY_PHASE, PREPARED_CUSTODY_COUNTER, p.authorization.executor,
            address(house), address(house), address(0), p.authorization.contextHash);
        return ledger.counterValue(manager.previewCounterValueKey(1, PREPARED_CUSTODY_PHASE, PREPARED_CUSTODY_COUNTER, subject));
    }
}
