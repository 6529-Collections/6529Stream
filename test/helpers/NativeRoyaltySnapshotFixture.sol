// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./NativeCuratedAuctionFixture.sol";
import "./NativeRightsAuctionFixture.sol";
import "../../smart-contracts/domains/revenue/StreamRoyaltyResolver.sol";

/// @dev Explicit exact royalty-consent boundary; this is not the actual Artist operation-15 suite.
contract NativeSnapshotArtist is NativeRightsAuctionArtist {
    address public royaltyResolver;
    bytes32 public royaltyApproval;
    uint256 public rejectingToken;
    address public royaltyFundingTrigger;
    constructor(address c, address m) NativeRightsAuctionArtist(c, m) { }
    function approveRoyalty(address source, bytes32 hash) external { royaltyResolver = source; royaltyApproval = hash; }
    function rejectSnapshot(uint256 token, address trigger) external { rejectingToken = token; royaltyFundingTrigger = trigger; }
    function requireEconomicsConsent(uint256 collection, bytes32 revenueClass, uint8 scope, uint256 scopeId, bytes32 hash)
        external view override
    {
        require(consent, "typed current Artist consent");
        if (revenueClass == keccak256("ROYALTY_ERC2981")) {
            require(msg.sender == royaltyResolver && collection == 1 && scope == 1 && scopeId == 1
                && hash == royaltyApproval && hash != 0, "exact current mode-bound royalty consent");
            require(rejectingToken == 0 || IStreamCore(core).lastAllocatedTokenId() != rejectingToken, "later token royalty rejected");
            require(royaltyFundingTrigger == address(0) || royaltyFundingTrigger.balance == 0, "royalty changed after funding");
        }
    }
}

contract SnapshotReceiver is IERC721Receiver {
    StreamRoyaltyResolver public immutable royalty;
    StreamCore public immutable source;
    uint256 public seen;
    uint256 public rejectedToken;
    constructor(StreamRoyaltyResolver r, StreamCore c) { royalty = r; source = c; }
    function reject(uint256 token) external { rejectedToken = token; }
    function onERC721Received(address operator, address, uint256 token, bytes calldata) external returns (bytes4) {
        IStreamRoyaltySnapshot.Snapshot memory snap = royalty.royaltySnapshot(token);
        require(msg.sender == address(source) && snap.exists && snap.manager == operator
            && snap.tokenId == token && snap.tokenRoyaltyPolicyHash != 0, "snapshot before actual ERC721 receiver");
        require(royalty.tokenRoyalty(token).frozen, "actual token key frozen before delivery");
        (bool ok,) = address(royalty).call(abi.encodeCall(royalty.snapshotTokenRoyaltyAtMint,
            (token, uint256(1), snap.operationRoot, snap.operationId, keccak256("ROYALTY_ERC2981"), snap.sourceRoyaltyPolicyHash)));
        require(!ok, "receiver cannot impersonate original Manager proof");
        require(token != rejectedToken, "later receiver rejects");
        ++seen;
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @dev Actual Core/Registry/Manager/Ledger/Resolver/Factory/9/house; typed Artist/entropy/governance.
abstract contract NativeRoyaltySnapshotFixture is NativeCuratedAuctionFixture {
    StreamRoyaltyResolver internal royalty;
    NativeSnapshotArtist internal snapshotArtist;
    IStreamRoyaltySnapshot.Source internal originalRoyalty;
    uint256 internal snapshotNonce;
    bytes32 internal constant SNAP_PHASE = keccak256("snapshot actual prepared phase");

    function _deployAuctionArtist() internal override returns (NativeAuctionArtist) {
        snapshotArtist = new NativeSnapshotArtist(address(core), address(manager));
        return snapshotArtist;
    }

    function setUp() public virtual override {
        super.setUp();
        snapshotArtist.setPayout(vm.addr(SIGNER_KEY));
        royalty = new StreamRoyaltyResolver(core, factory, address(revenueAuthority), artists);
        vm.prank(address(revenueAuthority));
        royalty.transferOwnership(address(this));
        _register(address(ledger), keccak256("MINT_LEDGER"), type(IStreamMintLedger).interfaceId, MANIFEST);
        _pointer(keccak256("MINT_LEDGER"), address(ledger));
        _register(address(royalty), keccak256("REVENUE_RESOLVER"), type(IStreamRoyaltyResolver).interfaceId, MANIFEST);
        _pointer(keccak256("ROYALTY_RESOLVER"), address(royalty));
        royalty.electCollectionRoyaltyMode(1, 2);
        bytes32 approved = royalty.previewArtistSnapshotRoyaltyAssignment(1, profile, 350, false).assignmentHash;
        snapshotArtist.approveRoyalty(address(royalty), approved);
        royalty.configureCollectionRoyalty(1, profile, 350);
        originalRoyalty = royalty.currentRoyaltySnapshotSource(1);
        require(originalRoyalty.modeAssignmentHash == approved && approved != originalRoyalty.sourceAssignmentHash,
            "mode consent separate from original canonical assignment");
        _snapshotPhase(SNAP_PHASE, 2, address(this));
        require(address(royalty).code.length <= 24576 && address(manager).code.length <= 24576,
            "actual snapshot products fit EIP170");
    }

    function _royaltyPolicy() internal view returns (IStreamMintRoyaltyPolicy.Policy memory p) {
        p = IStreamMintRoyaltyPolicy.Policy(true, MANIFEST, address(royalty), address(royalty).codehash,
            originalRoyalty.electionHash, originalRoyalty.modeAssignmentHash, originalRoyalty.sourceRoyaltyPolicyHash);
    }

    function _snapshotPhase(bytes32 phaseId, uint32 quantity, address executor) internal returns (bytes32 configHash) {
        configHash = manager.registerPhaseRoyaltyPolicy(1, phaseId, _royaltyPolicy());
        IStreamMintManager.MintGateConfig memory gate;
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = keccak256("snapshot payer counter");
        IStreamMintManager.MintCounterConfig[] memory counters = new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(true, IStreamMintManager.CounterKeyMode.PAYER,
            IStreamMintLedger.CounterCapMode.STATIC, IStreamMintLedger.CounterDeltaMode.STATIC,
            20, 1, keccak256("snapshot payer counter config"));
        manager.configurePhase(1, phaseId, IStreamMintManager.MintPhaseConfig(false, 0, 0, quantity, configHash, MANIFEST),
            gate, ids, counters);
        manager.setPhaseExecutor(1, phaseId, executor, true);
    }

    function _snapshotBatch(bytes32 phaseId, address recipient, uint256 quantity) internal view returns (IStreamMintManager.MintBatch memory b) {
        b.collectionId = 1; b.phaseId = phaseId; b.payer = payer;
        b.initialRecipients = new address[](quantity); b.beneficiaries = new address[](quantity);
        b.tokenData = new bytes[](quantity); b.mintCommitments = new bytes32[](quantity);
        for (uint256 i; i < quantity; ++i) {
            b.initialRecipients[i] = recipient; b.beneficiaries[i] = payer;
            b.tokenData[i] = abi.encode("snapshot actual artwork", i);
            b.mintCommitments[i] = keccak256(abi.encode("snapshot commitment", i));
        }
        b.expectedPolicyHash = manager.phasePolicyHash(1, phaseId);
        b.authorizationId = keccak256("original snapshot authorization");
    }

    function _assertSnapshot(uint256 token) internal view returns (IStreamRoyaltySnapshot.Snapshot memory s) {
        s = royalty.royaltySnapshot(token);
        IStreamRoyaltyResolver.RoyaltyConfig memory c = royalty.tokenRoyalty(token);
        require(s.exists && s.collectionId == 1 && s.tokenId == token && s.manager == address(manager)
            && s.electionHash == originalRoyalty.electionHash && s.modeAssignmentHash == originalRoyalty.modeAssignmentHash
            && s.sourceAssignmentHash == originalRoyalty.sourceAssignmentHash
            && s.sourceRoyaltyPolicyHash == originalRoyalty.sourceRoyaltyPolicyHash
            && ledger.isManagerOperationRootUsed(address(manager), s.operationRoot)
            && c.configured && c.frozen && c.revision == 1 && c.royaltyBps == 350 && c.profileId == profile,
            "full original authority/source and frozen token receipt");
        (StreamArtistOnboardingTypes.AssignmentFact memory fact,, bytes32 policyHash) = royalty.resolveRoyaltyAssignment(1, token);
        require(fact.scope == 2 && fact.scopeId == token && fact.assignmentHash == s.tokenAssignmentHash
            && policyHash == s.tokenRoyaltyPolicyHash && s.tokenConfigHash == keccak256(abi.encode(c)),
            "actual canonical per-token source and policy hashes");
    }

    function _snapshotConfiguration(bytes32 phaseId) internal view returns (IStreamNativeEnglishAuction.Configuration memory c) {
        uint64 observed = this.snapshotTime();
        c.collectionId = 1; c.phaseId = phaseId; c.mintAtSettlement = true;
        c.artworkCommitment = keccak256("snapshot paid artwork"); c.mintCommitment = keccak256("snapshot paid commitment");
        c.poster = address(this); c.reservePrice = 1000; c.minIncrementBps = 500;
        c.clock = StreamEnglishAuctionClock.Configuration(observed, observed + 3600, 0, 600, 600, 3600, false, false);
        c.expectedPrimaryPolicyHash = StreamNativeEnglishAuctionSupport.profilePolicy(resolver, 1);
        c.primaryPolicyMode = 1; c.settlementWindow = 86400; c.mintPolicyHash = manager.phasePolicyHash(1, phaseId);
    }

    function _openSnapshot(IStreamNativeEnglishAuction.Configuration memory c) internal returns (bytes32) {
        IStreamNativeEnglishAuction.CreationAuthorization memory a = IStreamNativeEnglishAuction.CreationAuthorization(
            house.auctionConfigurationHash(c), vm.addr(SIGNER_KEY), bytes32(++snapshotNonce), this.snapshotTime() + 1000);
        bytes32 digest = house.creationAuthorizationDigest(a);
        return house.registerAuction(c, bytes("snapshot paid artwork"), a, _sig(AUCTION_PLATFORM_KEY, digest), _sig(SIGNER_KEY, digest));
    }

    function _snapshotCuratedPlan() internal returns (Plan memory p) {
        p = _unconfiguredPlan(false);
        // Same actual publication/CONTEXT cap-one configuration; the royalty wrapper is explicit.
        StreamModuleRegistration memory r = StreamModuleRegistration(address(p.gate), keccak256("6529STREAM_MINT_GATE_V1"),
            keccak256("NATIVE_CURATED_GATE_V1"), type(IStreamMintGate).interfaceId, 800000, address(p.gate).codehash,
            MANIFEST, p.gate.gateConfigHash(), "urn:curated:complete-manifest");
        (bytes32 scope, bytes32 oldState, bytes32 next) = _registrationTransition(r);
        _context(scope, oldState, next, 1); vm.prank(address(revenueAuthority)); registry.registerModule(r); _clearContext();
        bytes32 wrapped = manager.registerPhaseRoyaltyPolicy(1, p.config.phaseId, _royaltyPolicy());
        bytes32[] memory ids = new bytes32[](1); ids[0] = p.counter;
        IStreamMintManager.MintCounterConfig[] memory counters = new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(true, IStreamMintManager.CounterKeyMode.CONTEXT,
            IStreamMintLedger.CounterCapMode.STATIC, IStreamMintLedger.CounterDeltaMode.STATIC, 1, 1,
            keccak256(abi.encode("curated cap", p.config.phaseId, uint64(1))));
        IStreamMintManager.MintGateConfig memory gate;
        gate.gate = address(p.gate); gate.gateConfigHash = p.gate.gateConfigHash();
        manager.configurePhase(1, p.config.phaseId, IStreamMintManager.MintPhaseConfig(false, 0, 0, 1, wrapped, MANIFEST), gate, ids, counters);
        manager.setPhaseExecutor(1, p.config.phaseId, address(house), true);
        p.config.mintPolicyHash = manager.phasePolicyHash(1, p.config.phaseId);
    }

    function snapshotTime() external view returns (uint64) { return uint64(block.timestamp); }
}
