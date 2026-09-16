// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./NativePlatformRightsFixture.sol";
import "../../smart-contracts/domains/revenue/StreamRoyaltyResolver.sol";

/// @dev Actual Core/Manager/Ledger/Resolver/royalty/recorder/Safe; typed Artist/governance/entropy.
abstract contract NativePlatformCustodyFixture is NativePlatformRightsFixture {
    bytes32 internal constant PLATFORM_CUSTODY_PHASE = keccak256("platform prepared custody");
    StreamRoyaltyResolver internal royalty;
    bool internal rejectDelivery;

    struct Plan {
        IStreamNativeEnglishAuction.Configuration config;
        StreamPreparedNativeRightsTypes.OriginalPolicy original;
        IStreamPlatformCustodyAuction.PlatformCustodyAuthorization auth;
        bytes artwork;
        bytes signature;
    }
    receive() external payable { }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        view
        returns (bytes4)
    {
        require(!rejectDelivery, "poster delivery rejection");
        return IERC721Receiver.onERC721Received.selector;
    }

    function setUp() public virtual override {
        super.setUp();
        vm.deal(address(this), 100 ether);
        (bytes32 scope, bytes32 old_, bytes32 next) =
            recorder.custodyHouseTransition(address(house));
        _context(scope, old_, next, 1);
        vm.prank(address(revenueAuthority));
        recorder.bindCanonicalCustodyHouse(address(house));
        _clearContext();
        royalty = new StreamRoyaltyResolver(core, factory, address(revenueAuthority), artists);
        vm.prank(address(revenueAuthority));
        royalty.transferOwnership(address(this));
        _register(
            address(ledger), keccak256("MINT_LEDGER"), type(IStreamMintLedger).interfaceId, MANIFEST
        );
        _pointer(keccak256("MINT_LEDGER"), address(ledger));
        _register(
            address(royalty),
            keccak256("REVENUE_RESOLVER"),
            type(IStreamRoyaltyResolver).interfaceId,
            MANIFEST
        );
        _pointer(keccak256("ROYALTY_RESOLVER"), address(royalty));
        royalty.electCollectionRoyaltyMode(2, 2);
        royalty.configureCollectionRoyalty(2, profile, 350);
        IStreamRoyaltySnapshot.Source memory original = royalty.currentRoyaltySnapshotSource(2);
        bytes32 wrapped = manager.registerPhaseRoyaltyPolicy(
            2,
            PLATFORM_CUSTODY_PHASE,
            IStreamMintRoyaltyPolicy.Policy(
                true,
                MANIFEST,
                address(royalty),
                address(royalty).codehash,
                original.electionHash,
                original.modeAssignmentHash,
                original.sourceRoyaltyPolicyHash
            )
        );
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = COUNTER;
        IStreamMintManager.MintCounterConfig[] memory counts =
            new IStreamMintManager.MintCounterConfig[](1);
        counts[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            20,
            1,
            keccak256("unpaid platform original supply")
        );
        IStreamMintManager.MintGateConfig memory gate;
        manager.configurePhase(
            2,
            PLATFORM_CUSTODY_PHASE,
            IStreamMintManager.MintPhaseConfig(false, 0, 0, 1, wrapped, MANIFEST),
            gate,
            ids,
            counts
        );
        manager.setPhaseExecutor(2, PLATFORM_CUSTODY_PHASE, address(house), true);
    }

    function _fixed(uint8 mode, address recipient) internal returns (bytes32 id, address account) {
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] =
            IStreamSplitWallet.SplitEntry(recipient, 1000000, keccak256("platform recipient"));
        (id, account) = factory.createProfile(
            entries, keccak256(abi.encode("custody platform terms", mode, recipient))
        );
        if (mode == 11) {
            IStreamRevenueResolver.ResolvedPrimaryAssignment memory old =
                resolver.resolvePrimaryAssignment(2, 0, CLASS);
            if (old.exists && old.scope == 1) resolver.clearPrimaryAssignment(CLASS, 1, 2);
        }
        resolver.setPrimaryProfileAssignment(CLASS, mode == 10 ? 1 : 0, mode == 10 ? 2 : 0, id, 0);
    }

    function _plan(uint8 mode, address executor, uint256 value) internal returns (Plan memory p) {
        p.config = _config(mode);
        p.config.phaseId = PLATFORM_CUSTODY_PHASE;
        p.config.mintAtSettlement = false;
        p.config.tokenId = core.lastAllocatedTokenId() + 1;
        p.config.artworkCommitment = 0;
        p.config.mintPolicyHash = manager.phasePolicyHash(2, PLATFORM_CUSTODY_PHASE);
        p.artwork = bytes("platform custody original artwork");
        StreamSaleTemplate.Selection memory s = _selected(mode);
        p.original =
            StreamPreparedNativeRightsTypes.OriginalPolicy(mode, s.assignmentHash, s.templateId);
        (, bytes32 declaration,) = platform.platformWorksDeclaration(2);
        p.auth = IStreamPlatformCustodyAuction.PlatformCustodyAuthorization(
            house.platformRightsConfigurationHash(p.config, p.original, declaration),
            declaration,
            keccak256(p.artwork),
            core.lastAllocatedTokenId() + 1,
            p.config.tokenId,
            core.collectionNextSerial(2),
            manager.nextOperationNonce(),
            keccak256("platform acquisition context"),
            executor,
            value,
            bytes32(++creationNonce),
            this.timeNow() + 1 days
        );
        // Each fixture opening acquires exactly one token and no deferred sale is registered.
        p.signature = _proof(AUCTION_PLATFORM_KEY, _independentDigest(p.auth));
    }

    function _independentDigest(IStreamPlatformCustodyAuction.PlatformCustodyAuthorization memory a)
        internal
        view
        returns (bytes32 digest)
    {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamPlatformPreparedCustodyAuction"),
                keccak256("1"),
                block.chainid,
                address(house)
            )
        );
        digest = keccak256(
            abi.encodePacked(
                hex"1901",
                domain,
                keccak256(
                    abi.encode(
                        keccak256(
                            "PlatformPreparedCustodyAcquisition(bytes32 configHash,bytes32 declarationHash,bytes32 tokenDataHash,uint256 expectedSaleNonce,uint256 expectedTokenId,uint256 expectedCollectionSerial,uint256 expectedOperationNonce,bytes32 contextHash,address executor,uint256 revealFeeDeposit,bytes32 nonce,uint64 deadline)"
                        ),
                        a
                    )
                )
            )
        );
        require(
            digest == house.platformCustodyAcquisitionDigest(a),
            "complete independent domain and all fields"
        );
    }

    function _call(Plan memory p) internal pure returns (bytes memory) {
        return abi.encodeCall(
            IStreamPlatformCustodyAuction.registerPlatformCustodyAuction,
            (p.config, p.original, p.artwork, p.auth, p.signature)
        );
    }

    function _acquire(Plan memory p) internal returns (bytes32 id) {
        (bool ok, bytes memory out) =
            address(house).call{ value: p.auth.revealFeeDeposit }(_call(p));
        require(ok, "platform original prepared acquisition");
        return abi.decode(out, (bytes32));
    }

    function _custodyBid(bytes32 id, address who) internal {
        vm.deal(who, 1 ether);
        vm.prank(who);
        house.bid{ value: 1000 }(id, who);
    }

    function _counter() internal view returns (uint256) {
        bytes32 subject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.CONSTANT,
            2,
            PLATFORM_CUSTODY_PHASE,
            COUNTER,
            address(this),
            address(house),
            address(house),
            address(0),
            0
        );
        return ledger.counterValue(
            manager.previewCounterValueKey(2, PLATFORM_CUSTODY_PHASE, COUNTER, subject)
        );
    }

    function _safeCall(OfficialSafe safe, uint256[] memory keys, uint256 value, bytes memory data)
        internal
        returns (bytes memory)
    {
        bytes32 digest = safe.getTransactionHash(
            address(house), value, data, 0, 0, 0, 0, address(0), address(0), safe.nonce()
        );
        return abi.encodeCall(
            safe.execTransaction,
            (
                address(house),
                value,
                data,
                uint8(0),
                uint256(0),
                uint256(0),
                uint256(0),
                address(0),
                payable(address(0)),
                safeThresholdSignature(keys, digest)
            )
        );
    }
}
