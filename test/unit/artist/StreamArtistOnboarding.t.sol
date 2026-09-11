// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../../smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol";
import "../../../smart-contracts/domains/artist/StreamArtistArchiveV2.sol";
import "../../../smart-contracts/domains/artist/StreamArtistBindingLifecycle.sol";
import "../../../smart-contracts/domains/artist/StreamArtistCollaboratorLifecycle.sol";
import "../../../smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol";
import "../../../smart-contracts/domains/artist/StreamArtistAcceptanceLifecycle.sol";
import "../../../smart-contracts/domains/artist/StreamArtistAttributionLifecycle.sol";
import "../../../smart-contracts/domains/artist/StreamArtistPayoutLifecycle.sol";
import "../../../smart-contracts/domains/artist/StreamArtistConsentFinalityLifecycle.sol";
import "../../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";
import "../../../smart-contracts/domains/revenue/StreamRoyaltyResolver.sol";
import "../../../smart-contracts/domains/revenue/StreamSplitFactory.sol";
import "../../../smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol";
import "../../../smart-contracts/domains/mint/StreamMintManager.sol";
import "../../../smart-contracts/domains/mint/StreamMintLedger.sol";

interface ArtistTestVm {
    function getNonce(address account) external view returns (uint64);
    function computeCreateAddress(address deployer, uint256 nonce) external pure returns (address);
    function expectRevert(bytes4 selector) external;
    function expectPartialRevert(bytes4 selector) external;
    function mockCallRevert(address callee, bytes calldata data, bytes calldata returnData) external;
    function mockCall(address callee, bytes calldata data, bytes calldata returnData) external;
    function clearMockedCalls() external;
}

/// @dev Unit boundary double. These tests do not establish real Core/metadata/royalty integration.
contract ArtistUnitCore {
    mapping(bytes32 => address) public targets;
    mapping(bytes32 => bool) public frozen;

    function set(bytes32 kind, address target, bool frozen_) external {
        targets[kind] = target;
        frozen[kind] = frozen_;
    }

    function collectionExists(uint256 id) external pure returns (bool) {
        return id == 1 || id == 2;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x80ac58cd || id == 0x01ffc9a7;
    }

    function getSatellitePointer(bytes32 kind)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        return (
            targets[kind],
            targets[kind].codehash,
            frozen[kind],
            bytes32(0),
            bytes4(0),
            address(0),
            1,
            bytes32(0),
            bytes32(0),
            1
        );
    }
}

contract ArtistUnitMarker { }

contract ArtistUnitModuleRegistry {
    address public immutable governanceExecutor;

    constructor(address authority) {
        governanceExecutor = authority;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamModuleRegistry).interfaceId || id == type(IERC165).interfaceId;
    }
}

contract ArtistUnitGovernance {
    bool private active;
    bytes32 private scope;
    bytes32 private oldState;
    bytes32 private newState;

    function isStreamGovernedParameterAuthority() external pure returns (bool) {
        return true;
    }

    function currentAction()
        external
        view
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return (
            active,
            active ? keccak256("unit authority gas raise") : bytes32(0),
            active ? 1 : 0,
            scope,
            oldState,
            newState
        );
    }

    /// @dev Exact host-context unit double, not proof of actual delayed governance.
    function raise(IStreamGasParameterHost host, bytes32 id, uint256 value) external {
        (uint256 previous, uint256 floor, uint8 failure, uint64 revision) =
            host.gasParameterInfo(id);
        scope = keccak256(
            abi.encode(
                bytes32(0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71),
                block.chainid,
                address(host),
                id
            )
        );
        bytes32 domain = 0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c;
        oldState = keccak256(abi.encode(domain, scope, previous, floor, failure, revision));
        newState = keccak256(abi.encode(domain, scope, value, floor, failure, revision + 1));
        active = true;
        host.raiseGasParameter(id, value);
        active = false;
        scope = bytes32(0);
        oldState = bytes32(0);
        newState = bytes32(0);
    }
}

contract ArtistUnitRoles {
    address public immutable admin;

    constructor(address admin_) {
        admin = admin_;
    }

    function hasRole(bytes32 role, address account) external view returns (bool) {
        return role == keccak256("ROLE_ARTIST_REGISTRY_ADMIN") && account == admin;
    }

    function roleMutationState(bytes32 role) external view returns (bytes32, uint64) {
        return (keccak256(abi.encode(role, admin)), 1);
    }
}

contract ArtistUnitMetadata {
    bytes32 public content = keccak256("initial unit content");

    function setContent(bytes32 value) external {
        content = value;
    }

    function currentArtistContentState(uint256 id) external view returns (address, bytes32) {
        return (address(this), keccak256(abi.encode(id, content)));
    }
}

/// @notice Real artist owners, both economics providers, split profiles and official Safe signatures.
/// @dev Core, metadata and governance boundaries are explicit unit doubles;
///      a separate current-stack test owns integration and eligible token mint proof.
contract StreamArtistOnboardingTest is CharacterizationTestBase, OfficialSafeFixture {
    ArtistTestVm private constant avm =
        ArtistTestVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant PHASE = keccak256("artist unit phase");
    bytes32 private POLICY;
    bytes32 private constant PRIMARY = keccak256("PRIMARY_SALE");
    uint256[] private keys;
    OfficialSafe private artist;
    SafeComponents private safeComponents;
    StreamArtistOnboardingRegistry private ingress;
    StreamArtistOnboardingCoordinator private coordinator;
    StreamArtistArchiveV2 private archive;
    T.SuiteConfiguration private suite;
    bytes32 private artistId;
    ArtistUnitCore private core;
    ArtistUnitMetadata private metadata;
    StreamRoyaltyResolver private royalty;
    StreamRevenueResolver private primary;
    StreamSplitFactory private factory;
    StreamMintManager private manager;
    StreamMintLedger private ledger;
    uint256 private nextNonce;
    bool private directArtistCalls;

    function setUp() public {
        vm.warp(1000);
        keys = new uint256[](2);
        keys[0] = 0xA11CE;
        keys[1] = 0xB0B;
        safeComponents = deploySafeComponents("1.4.1");
        artist = createOfficialSafe(safeComponents, safeOwnerAddresses(keys), 2, 17);
        core = new ArtistUnitCore();
        address governance = address(new ArtistUnitGovernance());
        ArtistUnitModuleRegistry modules = new ArtistUnitModuleRegistry(governance);
        core.set(keccak256("MODULE_REGISTRY"), address(modules), false);
        ledger = new StreamMintLedger();
        manager =
            new StreamMintManager(IStreamCore(address(core)), ledger, IERC165(address(modules)));
        // Match the integrated live-provider profile; the real delayed Executor
        // raise is integration-owned. This fixture exercises the actual host checks.
        ArtistUnitGovernance(governance)
            .raise(manager, manager.GGP_ARTIST_AUTHORITY_GAS_LIMIT(), 300_000);
        ledger.setLedgerWriter(address(manager), true);
        suite.core = address(core);
        suite.mintManager = address(manager);
        suite.roleRegistry = address(new ArtistUnitRoles(address(this)));
        suite.validator = address(new StreamArtistRegistryValidatorBase());
        metadata = new ArtistUnitMetadata();
        suite.metadata = address(metadata);
        factory = new StreamSplitFactory(
            new StreamAssetPolicyRegistry(governance), governance, _walletGasConfigs()
        );
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](2);
        entries[0] = IStreamSplitWallet.SplitEntry(address(artist), 900_000, keccak256("artist"));
        entries[1] = IStreamSplitWallet.SplitEntry(address(0xFEE), 100_000, keccak256("protocol"));
        (bytes32 profile, address wallet) =
            factory.createProfile(entries, keccak256("artist unit split"));
        suite.primaryRevenueClass = PRIMARY;
        uint256 nonce = avm.getNonce(address(this));
        address predictedRegistry = avm.computeCreateAddress(address(this), nonce);
        address predictedArchive = avm.computeCreateAddress(address(this), nonce + 1);
        address predictedCoordinator = avm.computeCreateAddress(address(this), nonce + 12);
        ingress = new StreamArtistOnboardingRegistry(
            suite.core,
            suite.mintManager,
            predictedCoordinator,
            governance,
            keccak256("unit deployment"),
            "urn:artist-unit",
            keccak256("unit manifest")
        );
        archive = new StreamArtistArchiveV2(address(ingress), predictedCoordinator);
        suite.registry = address(ingress);
        suite.archive = address(archive);
        suite.owners[0] = address(
            new StreamArtistBindingLifecycle(
                predictedRegistry,
                predictedCoordinator,
                predictedArchive,
                suite.core,
                suite.mintManager
            )
        );
        suite.owners[1] = address(
            new StreamArtistCollaboratorLifecycle(
                predictedRegistry,
                predictedCoordinator,
                predictedArchive,
                suite.core,
                suite.mintManager
            )
        );
        suite.owners[2] = address(
            new StreamArtistIdentityAuthority(
                predictedRegistry,
                predictedCoordinator,
                predictedArchive,
                suite.core,
                suite.mintManager
            )
        );
        suite.owners[3] = address(
            new StreamArtistAcceptanceLifecycle(
                predictedRegistry,
                predictedCoordinator,
                predictedArchive,
                suite.core,
                suite.mintManager
            )
        );
        suite.owners[4] = address(
            new StreamArtistAttributionLifecycle(
                predictedRegistry,
                predictedCoordinator,
                predictedArchive,
                suite.core,
                suite.mintManager
            )
        );
        suite.owners[5] = address(
            new StreamArtistPayoutLifecycle(
                predictedRegistry,
                predictedCoordinator,
                predictedArchive,
                suite.core,
                suite.mintManager
            )
        );
        suite.owners[6] = address(
            new StreamArtistConsentFinalityLifecycle(
                predictedRegistry,
                predictedCoordinator,
                predictedArchive,
                suite.core,
                suite.mintManager
            )
        );
        primary =
            new StreamRevenueResolver(IStreamCore(address(core)), factory, governance, ingress);
        // Separate real factory/profile proves royalty payout reads cannot substitute
        // the primary resolver's factory, even when both profiles name the same artist.
        StreamSplitFactory royaltyFactory = new StreamSplitFactory(
            factory.assetPolicyRegistry(), governance, _walletGasConfigs()
        );
        (profile, wallet) = royaltyFactory.createProfile(entries, keccak256("royalty unit split"));
        royalty = new StreamRoyaltyResolver(
            IStreamCore(address(core)), royaltyFactory, governance, ingress
        );
        bytes32 royaltyProfile = profile;
        suite.primaryResolver = address(primary);
        suite.royaltyResolver = address(royalty);
        coordinator = new StreamArtistOnboardingCoordinator(suite);
        require(address(coordinator) == predictedCoordinator, "fixed constructor pins");
        core.set(keccak256("ARTIST_REGISTRY"), address(ingress), false);
        core.set(keccak256("METADATA_ROUTER"), address(metadata), false);
        core.set(keccak256("ROYALTY_RESOLVER"), address(royalty), false);
        (profile,) = factory.createProfile(entries, keccak256("artist unit split"));
        vm.prank(governance);
        primary.setPrimaryProfileAssignment(PRIMARY, 1, 1, profile, bytes32(0));
        vm.prank(governance);
        royalty.configureCollectionRoyalty(1, royaltyProfile, 500);
        (artistId,) = ingress.proposeArtistBinding(
            1, _proposal(bytes32(0)), bytes("unit identity document"), "Artist Safe"
        );
        POLICY = _prospective(false);
    }

    function _proposal(bytes32 id) private view returns (T.BindingProposal memory p) {
        p.artistId = id;
        p.artistAddress = address(artist);
        p.identityRecordHash = keccak256("unit identity document");
        // Exercise the normative maximum URI in every capped consent-read scenario.
        bytes memory uri = new bytes(2048);
        bytes memory prefix = bytes("urn:artist:");
        for (uint256 i; i < uri.length; ++i) {
            uri[i] = i < prefix.length ? prefix[i] : bytes1("a");
        }
        p.identityRecordURI = string(uri);
        p.consentMode = 1;
        p.collaborators = new T.CollaboratorRecord[](0);
        p.capabilityPolicyOverrides = new T.CapabilityPolicyOverride[](0);
    }

    /// @dev Matches the integrated wallet-line planning configuration; cold sizing is a separate gate.
    function _walletGasConfigs()
        private
        pure
        returns (IStreamGasParameterHost.GasParameterConfig[3] memory configs)
    {
        configs[0] = IStreamGasParameterHost.GasParameterConfig(
            "ERC_1271_GAS_LIMIT", 400_000, 350_000, 2
        );
        configs[1] =
            IStreamGasParameterHost.GasParameterConfig("ASSET_POLICY_GAS_LIMIT", 30_000, 15_000, 2);
        configs[2] = IStreamGasParameterHost.GasParameterConfig(
            "WALLET_DEPOSIT_GAS_LIMIT", 50_000, 25_000, 2
        );
    }

    function _authorization(bool signedAt) private returns (T.Authorization memory) {
        return T.Authorization(
            nextNonce++, uint64(signedAt ? block.timestamp : block.timestamp + 1 days), ""
        );
    }

    function _signature(bytes32 digest) private returns (bytes memory) {
        if (directArtistCalls) return "";
        return safeThresholdSignature(keys, safeMessageDigest(artist, abi.encode(digest)));
    }

    function _artistCall(bytes memory data) private {
        if (directArtistCalls) {
            require(
                executeSafe(artist, keys, address(ingress), 0, data, 0), "direct Safe artist call"
            );
        } else {
            (bool ok, bytes memory reason) = address(ingress).call(data);
            if (!ok) assembly ("memory-safe") { revert(add(reason, 32), mload(reason)) }
        }
    }

    function _accept() private {
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.acceptanceDigest(1, a));
        _artistCall(abi.encodeCall(IStreamArtistOnboarding.acceptArtistBinding, (1, a)));
    }

    function _policy() private {
        T.PolicyConsent memory p = T.PolicyConsent(1, PHASE, POLICY);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.policyConsentDigest(p, a));
        _artistCall(abi.encodeCall(IStreamArtistOnboarding.recordPolicyConsent, (p, a)));
    }

    function _payout() private {
        T.PayoutDesignation memory p = T.PayoutDesignation(artistId, address(artist), bytes32(0));
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.payoutDesignationDigest(p, a));
        _artistCall(abi.encodeCall(IStreamArtistOnboarding.recordPayoutDesignation, (p, a)));
    }

    function _economics() private {
        (T.AssignmentFact memory first, T.AssignmentFact memory second) =
            coordinator.reads().currentAssignments(1);
        _economicsRecord(first);
        _economicsRecord(second);
    }

    function _economicsRecord(T.AssignmentFact memory fact) private {
        T.EconomicsConsent memory p = T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
        _artistCall(abi.encodeCall(IStreamArtistOnboarding.recordEconomicsConsent, (p, a)));
    }

    function _ratify() private {
        (, bytes32 state) = metadata.currentArtistContentState(1);
        T.Ratification memory p = T.Ratification(1, address(metadata), state);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.contentRatificationDigest(p, a));
        _artistCall(abi.encodeCall(IStreamArtistOnboarding.recordContentRatification, (p, a)));
    }

    function _attestations() private {
        T.Binding memory binding_ = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        bytes32 facts = StreamArtistHashes.deploymentFacts(
            StreamArtistHashes.Environment(
                block.chainid, address(ingress), suite.core, suite.mintManager
            ),
            1,
            binding_
        );
        _attest(
            9,
            bytes32(uint256(uint160(suite.core))),
            facts,
            keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1")
        );
        _attest(
            10,
            artistId,
            binding_.identityRecordHash,
            keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")
        );
    }

    function _attest(uint8 kind, bytes32 subject, bytes32 state, bytes32 schema) private {
        bytes memory statement = abi.encode(kind, subject, state, schema);
        T.Attestation memory p = T.Attestation(
            1, kind, subject, state, schema, keccak256(statement), "urn:unit:statement"
        );
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.attestationDigest(p, a));
        _artistCall(
            abi.encodeCall(IStreamArtistOnboarding.recordArtistAttestation, (p, a, statement))
        );
    }

    function _all() private {
        _accept();
        _policy();
        _payout();
        _economics();
        _ratify();
        _attestations();
    }

    function _roots() private view returns (bytes32) {
        T.Snapshot[7] memory snapshots;
        for (uint256 i; i < 7; ++i) {
            snapshots[i] = IStreamArtistOwner(suite.owners[i]).ownerStateSnapshotV2();
        }
        return keccak256(abi.encode(snapshots));
    }

    function _closed(bytes memory data) private view returns (bool) {
        (bool ok,) = address(ingress).staticcall(data);
        return !ok;
    }

    function _mintCall() private view returns (bytes memory) {
        return abi.encodeCall(IStreamArtistMintConsent.requireMintConsent, (1, PHASE, POLICY));
    }

    function _phaseConfig() private pure returns (IStreamMintManager.MintPhaseConfig memory) {
        return IStreamMintManager.MintPhaseConfig(
            false, 0, 0, 1, keccak256("phase config"), keccak256("phase metadata")
        );
    }

    function _counters()
        private
        pure
        returns (bytes32[] memory ids, IStreamMintManager.MintCounterConfig[] memory configs)
    {
        ids = new bytes32[](1);
        ids[0] = keccak256("supply");
        configs = new IStreamMintManager.MintCounterConfig[](1);
        configs[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            10,
            1,
            keccak256("counter config")
        );
    }

    function _prospective(bool withExecutor) private view returns (bytes32) {
        (bytes32[] memory ids, IStreamMintManager.MintCounterConfig[] memory configs) = _counters();
        IStreamMintManager.MintGateConfig memory gate;
        address[] memory executors = new address[](withExecutor ? 1 : 0);
        if (withExecutor) executors[0] = address(this);
        return
            manager.previewPhasePolicyHash(1, PHASE, _phaseConfig(), gate, ids, configs, executors);
    }

    function _configureData() private pure returns (bytes memory) {
        (bytes32[] memory ids, IStreamMintManager.MintCounterConfig[] memory configs) = _counters();
        IStreamMintManager.MintGateConfig memory gate;
        return abi.encodeCall(
            IStreamMintManager.configurePhase, (1, PHASE, _phaseConfig(), gate, ids, configs)
        );
    }

    function testSafeRecordsAllSevenOperationsAndActualFloorComposition() public {
        require(_closed(_mintCall()), "unaccepted fails");
        _accept();
        _policy();
        (bool recorded, bytes32 record) = ingress.isPolicyConsented(1, PHASE, POLICY);
        require(recorded && record != bytes32(0), "prospective policy is real");
        require(_closed(_mintCall()), "policy alone insufficient");
        _payout();
        _economics();
        require(_closed(_mintCall()), "missing ratification");
        _ratify();
        require(_closed(_mintCall()), "missing attestations");
        _attestations();
        ingress.requireMintConsent(1, PHASE, POLICY);
        require(ingress.acceptedArtist(1) == address(artist), "Safe is artist");
        require(
            IStreamArtistCollaboratorOwner(suite.owners[1]).ownerStateSnapshotV2().revision == 0,
            "empty collaborator owner unchanged"
        );
    }

    function testPolicyReplayWrongDomainAndMissingSafeOwnerRollback() public {
        _accept();
        T.PolicyConsent memory p = T.PolicyConsent(1, PHASE, POLICY);
        T.Authorization memory a = _authorization(false);
        a.signature = safeThresholdSignature(keys, ingress.policyConsentDigest(p, a));
        bytes32 before_ = _roots();
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordPolicyConsent(p, a);
        require(before_ == _roots(), "wrong domain rollback");
        uint256[] memory one = new uint256[](1);
        one[0] = keys[0];
        a.signature = safeThresholdSignature(
            one, safeMessageDigest(artist, abi.encode(ingress.policyConsentDigest(p, a)))
        );
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordPolicyConsent(p, a);
        require(before_ == _roots(), "threshold rollback");
        a.signature = _signature(ingress.policyConsentDigest(p, a));
        ingress.recordPolicyConsent(p, a);
        before_ = _roots();
        avm.expectPartialRevert(T.Replay.selector);
        ingress.recordPolicyConsent(p, a);
        require(before_ == _roots(), "replay rollback");
    }

    function testSafeDirectAcceptanceAndOwnerEoaDoesNotInheritAuthority() public {
        T.Authorization memory a = _authorization(false);
        vm.prank(safeVm.addr(keys[0]));
        vm.expectRevert();
        ingress.acceptArtistBinding(1, a);
        executeSafe(
            artist,
            keys,
            address(ingress),
            0,
            abi.encodeCall(IStreamArtistOnboarding.acceptArtistBinding, (1, a)),
            0
        );
        require(ingress.acceptedArtist(1) == address(artist), "direct Safe accepted");
    }

    function testSafePreapprovedEmptySignatureIsValidRelayedAuthorization() public {
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.acceptanceDigest(1, a);
        bytes32 before_ = _roots();
        vm.expectRevert();
        ingress.acceptArtistBinding(1, a);
        require(_roots() == before_, "unapproved empty rollback");
        require(
            executeSafe(
                artist,
                keys,
                safeComponents.signMessage,
                0,
                abi.encodeWithSignature("signMessage(bytes)", abi.encode(digest)),
                1
            ),
            "actual Safe approval"
        );
        ingress.acceptArtistBinding(1, a);
        require(ingress.acceptedArtist(1) == address(artist), "relayed empty Safe proof");
    }

    function testDesignatedAccountOwnKeyProofIsCanonical() public {
        StreamArtistRegistryValidatorBase validator =
            StreamArtistRegistryValidatorBase(suite.validator);
        address signer = vm.addr(0x7702);
        bytes32 digest = keccak256("designated artist");
        vm.etch(signer, abi.encodePacked(hex"ef0100", address(artist)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0x7702, digest);
        require(
            validator.validateSignerProof(signer, digest, abi.encodePacked(r, s, v), 150_000),
            "designated own-key proof"
        );
        (v, r, s) = vm.sign(0xBAD, digest);
        require(
            !validator.validateSignerProof(signer, digest, abi.encodePacked(r, s, v), 150_000),
            "wrong key rejected"
        );
    }

    function testCrossCollectionReuseDoesNotMutateIdentityAllocatorRootOrLiveness() public {
        _accept();
        T.Snapshot memory prior = IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2();
        T.Identity memory identity_ = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        uint256 allocator = IStreamArtistIdentityOwner(suite.owners[2]).nextRegistrationNonce();
        vm.warp(2000);
        (bytes32 reused,) = ingress.proposeArtistBinding(
            2, _proposal(artistId), bytes("unit identity document"), "Artist Safe"
        );
        require(
            reused == artistId
                && keccak256(abi.encode(prior))
                    == keccak256(
                        abi.encode(IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2())
                    ),
            "identity owner untouched"
        );
        require(
            allocator == IStreamArtistIdentityOwner(suite.owners[2]).nextRegistrationNonce(),
            "allocator unchanged"
        );
        require(
            identity_.lastAuthorityActionAt
                == IStreamArtistIdentityOwner(suite.owners[2])
                .identity(artistId)
                .lastAuthorityActionAt,
            "liveness unchanged"
        );
    }

    function testCurrentContentRoyaltyAndPointerChangesInvalidateNextMint() public {
        _all();
        ingress.requireMintConsent(1, PHASE, POLICY);
        uint256 snapshot = vm.snapshotState();
        metadata.setContent(keccak256("changed"));
        require(_closed(_mintCall()), "changed current content");
        require(vm.revertToState(snapshot), "restore");
        IStreamRoyaltyResolver.RoyaltyConfig memory r = royalty.collectionRoyalty(1);
        vm.prank(royalty.owner());
        avm.expectPartialRevert(T.MissingMintPrerequisite.selector);
        royalty.configureCollectionRoyalty(1, r.profileId, 600);
        require(
            royalty.collectionRoyalty(1).royaltyBps == r.royaltyBps,
            "unconsented royalty mutation rejected"
        );
        ingress.requireMintConsent(1, PHASE, POLICY);
        core.set(keccak256("ROYALTY_RESOLVER"), address(primary), false);
        require(_closed(_mintCall()), "changed selected royalty identity");
    }

    function testLateArchiveFailureRollsBackEveryOwnerAndNonce() public {
        _accept();
        T.PolicyConsent memory p = T.PolicyConsent(1, PHASE, POLICY);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.policyConsentDigest(p, a));
        bytes32 record = StreamArtistHashes.policyRecord(
            StreamArtistHashes.Environment(
                block.chainid, address(ingress), suite.core, suite.mintManager
            ),
            p,
            artistId,
            address(artist),
            a.nonce,
            uint64(block.timestamp)
        );
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(ingress),
                address(coordinator),
                uint16(14),
                address(this),
                record
            )
        );
        vm.prank(address(coordinator));
        archive.appendArtistEvidenceV2(id, 1, bytes("pre-existing conflicting evidence"));
        bytes32 before_ = _roots();
        vm.expectRevert();
        ingress.recordPolicyConsent(p, a);
        require(_roots() == before_, "all owner writes rollback");
        require(
            !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "nonce rollback"
        );
    }

    function testOwnerAndCoordinatorDirectSafeCallsAreRejected() public {
        bytes32 before_ = _roots();
        T.Authorization memory a = _authorization(false);
        vm.prank(address(artist));
        vm.expectRevert();
        coordinator.coordinateAcceptArtistBinding(address(artist), 1, a);
        T.ActionContext memory context = T.ActionContext(
            2, address(artist), IStreamArtistOwner(suite.owners[0]).ownerStateSnapshotV2()
        );
        vm.prank(address(artist));
        vm.expectRevert();
        IStreamArtistBindingOwner(suite.owners[0]).accept(context, 1, bytes32(0), bytes32(0));
        require(_roots() == before_, "protocol-only rejection");
    }

    function testManagerRegistrationRequiresEveryFloorAndPausePreservesPolicyWhenRegistryUnavailable()
        public
    {
        _accept();
        _policy();
        (bool ok,) = address(manager).call(_configureData());
        require(!ok, "policy-only registration must fail");
        (bool exists,) = manager.phase(1, PHASE);
        require(!exists, "phase rollback");
        require(
            ledger.registeredPhasePolicyHash(address(manager), 1, PHASE) == bytes32(0),
            "no ledger registration"
        );
        _payout();
        _economics();
        _ratify();
        _attestations();
        manager.transferOwnership(address(artist));
        require(
            executeSafe(artist, keys, address(manager), 0, _configureData(), 0),
            "actual Safe phase configuration"
        );
        require(manager.phasePolicyHash(1, PHASE) == POLICY, "prospective equals registration");
        vm.etch(address(ingress), "");
        require(
            executeSafe(
                artist,
                keys,
                address(manager),
                0,
                abi.encodeCall(IStreamMintManager.setPhasePaused, (1, PHASE, true)),
                0
            ),
            "Safe pause while unavailable"
        );
        require(
            manager.phasePolicyHash(1, PHASE) == POLICY
                && ledger.registeredPhasePolicyHash(address(manager), 1, PHASE) == POLICY,
            "pause preserves policy"
        );
        require(
            executeSafe(
                artist,
                keys,
                address(manager),
                0,
                abi.encodeCall(IStreamMintManager.setPhasePaused, (1, PHASE, false)),
                0
            ),
            "Safe unpause while unavailable"
        );
        require(manager.phasePolicyHash(1, PHASE) == POLICY, "unpause preserves policy");
    }

    function testManagerExecutorReregistrationNeedsNewExactPolicyAndMintFailureHasNoEffects()
        public
    {
        _all();
        (bool configured, bytes memory reason) = address(manager).call(_configureData());
        if (!configured) assembly ("memory-safe") { revert(add(reason, 32), mload(reason)) }
        vm.expectRevert();
        manager.setPhaseExecutor(1, PHASE, address(this), true);
        require(!manager.phaseExecutor(1, PHASE, address(this)), "executor rollback");
        POLICY = _prospective(true);
        _policy();
        manager.setPhaseExecutor(1, PHASE, address(this), true);
        require(manager.phasePolicyHash(1, PHASE) == POLICY, "new policy registered");
        metadata.setContent(keccak256("unconsented change"));
        IStreamMintManager.MintBatch memory batch;
        batch.collectionId = 1;
        batch.phaseId = PHASE;
        batch.payer = address(this);
        batch.expectedPolicyHash = POLICY;
        batch.initialRecipients = new address[](1);
        batch.initialRecipients[0] = address(this);
        batch.beneficiaries = new address[](1);
        batch.beneficiaries[0] = address(this);
        batch.tokenData = new bytes[](1);
        batch.tokenData[0] = "unit artwork";
        batch.mintCommitments = new bytes32[](1);
        batch.mintCommitments[0] = keccak256("commitment");
        uint256 nonce = manager.nextOperationNonce();
        bytes32 before_ = _roots();
        vm.expectRevert();
        manager.executeSingleStepMint(batch, "");
        require(
            manager.nextOperationNonce() == nonce && _roots() == before_,
            "mint rejected before replay effects"
        );
    }

    function testDirectSafeUsesAllocatorNonceAndCurrentSignedAt() public {
        _accept();
        uint256 hint = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        T.PayoutDesignation memory p = T.PayoutDesignation(artistId, address(artist), bytes32(0));
        T.Authorization memory a = T.Authorization(hint + 100, uint64(block.timestamp), "");
        bytes32 before_ = _roots();
        vm.expectRevert();
        this.executeArtistSafe(
            abi.encodeCall(IStreamArtistOnboarding.recordPayoutDesignation, (p, a))
        );
        require(before_ == _roots(), "direct nonce rejected");
        a.nonce = hint;
        a.time -= 1;
        vm.expectRevert();
        this.executeArtistSafe(
            abi.encodeCall(IStreamArtistOnboarding.recordPayoutDesignation, (p, a))
        );
        require(before_ == _roots(), "direct time rejected");
        a.time = uint64(block.timestamp);
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistOnboarding.recordPayoutDesignation, (p, a)),
                0
            ),
            "direct payout"
        );
    }

    /// @dev External test boundary keeps expectRevert on the complete Safe operation,
    ///      rather than its preliminary nonce/domain read inside executeSafe.
    function executeArtistSafe(bytes calldata data) external returns (bool) {
        require(msg.sender == address(this), "test-only entry");
        return executeSafe(artist, keys, address(ingress), 0, data, 0);
    }

    function testActualSafeDirectCallsCoverAllSixArtistAuthorizedEndpoints() public {
        directArtistCalls = true;
        _all();
        ingress.requireMintConsent(1, PHASE, POLICY);
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint == nextNonce,
            "direct allocator progression"
        );
    }

    function testRotatedSafeOwnerInvalidatesPriorUnusedProofWithoutConsumingArtistNonce() public {
        _accept();
        T.PolicyConsent memory p = T.PolicyConsent(1, PHASE, POLICY);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.policyConsentDigest(p, a));
        address oldOwner = artist.getOwners()[0];
        address replacement = vm.addr(0xCAFE);
        require(
            executeSafe(
                artist,
                keys,
                address(artist),
                0,
                abi.encodeWithSignature(
                    "swapOwner(address,address,address)", address(1), oldOwner, replacement
                ),
                0
            ),
            "Safe owner rotation"
        );
        bytes32 before_ = _roots();
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordPolicyConsent(p, a);
        require(
            _roots() == before_
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "old proof rollback"
        );
        for (uint256 i; i < keys.length; ++i) {
            if (vm.addr(keys[i]) == oldOwner) keys[i] = 0xCAFE;
        }
        a.signature = _signature(ingress.policyConsentDigest(p, a));
        ingress.recordPolicyConsent(p, a);
    }

    function testReverseOrderSignedNoncesAndIndependentSecondIdentity() public {
        _accept();
        T.PolicyConsent memory p = T.PolicyConsent(1, PHASE, POLICY);
        T.Authorization memory high = T.Authorization(900, uint64(block.timestamp + 1 days), "");
        high.signature = _signature(ingress.policyConsentDigest(p, high));
        ingress.recordPolicyConsent(p, high);
        p.policyHash = keccak256("second prospective policy");
        T.Authorization memory low = T.Authorization(2, high.time, "");
        low.signature = _signature(ingress.policyConsentDigest(p, low));
        ingress.recordPolicyConsent(p, low);
        T.Authorization memory gap = T.Authorization(1, high.time, "");
        p.policyHash = keccak256("fill allocator gap");
        gap.signature = _signature(ingress.policyConsentDigest(p, gap));
        ingress.recordPolicyConsent(p, gap);
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint == 3,
            "direct allocator skips previously signed value using bounded index"
        );
        address other = vm.addr(0xA247);
        T.BindingProposal memory proposal = _proposal(bytes32(0));
        proposal.artistAddress = other;
        proposal.identityRecordHash = keccak256("second identity");
        (bytes32 otherId,) =
            ingress.proposeArtistBinding(2, proposal, bytes("second identity"), "Second artist");
        T.Authorization memory acceptance = T.Authorization(0, low.time, "");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xA247, ingress.acceptanceDigest(2, acceptance));
        acceptance.signature = abi.encodePacked(r, s, v);
        ingress.acceptArtistBinding(2, acceptance);
        p.collectionId = 2;
        (v, r, s) = vm.sign(0xA247, ingress.policyConsentDigest(p, low));
        low.signature = abi.encodePacked(r, s, v);
        ingress.recordPolicyConsent(p, low);
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, 2)
                && IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(otherId, 2),
            "identity nonce spaces independent"
        );
    }

    function executeTargetSafe(address target, bytes calldata data) external returns (bool) {
        require(msg.sender == address(this), "test-only entry");
        return executeSafe(artist, keys, target, 0, data, 0);
    }

    function _executorPolicy(address[] memory executors) private {
        (bytes32[] memory ids, IStreamMintManager.MintCounterConfig[] memory configs) = _counters();
        IStreamMintManager.MintGateConfig memory gate;
        POLICY =
            manager.previewPhasePolicyHash(1, PHASE, _phaseConfig(), gate, ids, configs, executors);
        (bool consented,) = ingress.isPolicyConsented(1, PHASE, POLICY);
        if (!consented) _policy();
    }

    function _safeExecutor(address executor, bool allowed) private {
        require(
            executeSafe(
                artist,
                keys,
                address(manager),
                0,
                abi.encodeCall(IStreamMintManager.setPhaseExecutor, (1, PHASE, executor, allowed)),
                0
            ),
            "Safe phase executor change"
        );
        require(
            manager.phasePolicyHash(1, PHASE) == POLICY
                && ledger.registeredPhasePolicyHash(address(manager), 1, PHASE) == POLICY,
            "stored and Ledger policy parity"
        );
    }

    function testManagerLinkedConfigurationPreservesEventsAndDeployableRuntime() public {
        require(address(manager).code.length <= 24_576, "Manager EIP170 deployment limit");
        require(
            suite.owners[2].code.length <= 24_576 && address(coordinator).code.length <= 24_576
                && address(ingress).code.length <= 24_576 && suite.owners[6].code.length <= 24_576
                && address(coordinator.reads()).code.length <= 24_576,
            "artist EIP170 deployment limits"
        );
        _all();
        vm.recordLogs();
        (bool ok, bytes memory reason) = address(manager).call(_configureData());
        if (!ok) assembly ("memory-safe") { revert(add(reason, 32), mload(reason)) }
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32[4] memory expected;
        expected[0] =
            keccak256("MintPhaseConsentRecorded(uint16,uint256,bytes32,bytes32,uint8,bytes32)");
        expected[1] = keccak256(
            "MintPhaseConfigured(uint256,bytes32,bytes32,uint64,uint64,uint32,bytes32,bytes32,address)"
        );
        expected[2] = keccak256(
            "MintCounterConfigured(uint256,bytes32,bytes32,uint8,uint8,uint8,uint64,uint64,bytes32,bytes32)"
        );
        expected[3] = keccak256(
            "MintPhaseGateConfigured(uint256,bytes32,address,bytes32,bytes32,bytes32,uint32,uint32,bytes32)"
        );
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(manager)) continue;
            require(found < 4 && logs[i].topics[0] == expected[found], "Manager event order/topic");
            require(
                logs[i].topics[1] == bytes32(uint256(1)) && logs[i].topics[2] == PHASE,
                "Manager event scope"
            );
            if (found == 0 || found == 1) require(logs[i].topics[3] == POLICY, "event policy");
            if (found == 1) {
                (
                    uint64 start,
                    uint64 end,
                    uint32 limit,
                    bytes32 configHash,
                    bytes32 metadataHash,
                    address admin
                ) = abi.decode(logs[i].data, (uint64, uint64, uint32, bytes32, bytes32, address));
                require(
                    start == 0 && end == 0 && limit == 1 && configHash == keccak256("phase config")
                        && metadataHash == keccak256("phase metadata") && admin == address(this),
                    "delegatecall original admin and payload"
                );
            }
            ++found;
        }
        require(found == 4, "all configuration events emitted by Manager");
        require(manager.phasePolicyHash(1, PHASE) == POLICY, "prospective/stored hash parity");
    }

    function testSafeExecutorSwapRemovalAndLateLedgerFailureRollBackLinkedStorage() public {
        _all();
        (bool ok, bytes memory reason) = address(manager).call(_configureData());
        if (!ok) assembly ("memory-safe") { revert(add(reason, 32), mload(reason)) }
        manager.transferOwnership(address(artist));
        address first = address(0x1111);
        address second = address(0x2222);
        address[] memory intended = new address[](1);
        intended[0] = first;
        _executorPolicy(intended);
        _safeExecutor(first, true);
        intended = new address[](2);
        intended[0] = second;
        intended[1] = first;
        _executorPolicy(intended);
        _safeExecutor(second, true);
        intended = new address[](1);
        intended[0] = second;
        _executorPolicy(intended);
        _safeExecutor(first, false);
        require(
            !manager.phaseExecutor(1, PHASE, first) && manager.phaseExecutor(1, PHASE, second),
            "swap removal retains last executor"
        );
        bytes32 before_ = _roots();
        _safeExecutor(first, false);
        require(_roots() == before_, "unchanged permission no artist replay mutation");
        intended = new address[](0);
        _executorPolicy(intended);
        _safeExecutor(second, false);
        require(!manager.phaseExecutor(1, PHASE, second), "swapped index removal");

        intended = new address[](1);
        intended[0] = first;
        _executorPolicy(intended);
        bytes32 oldHash = manager.phasePolicyHash(1, PHASE);
        before_ = _roots();
        ledger.setLedgerWriter(address(manager), false);
        vm.expectRevert();
        this.executeTargetSafe(
            address(manager),
            abi.encodeCall(IStreamMintManager.setPhaseExecutor, (1, PHASE, first, true))
        );
        require(
            !manager.phaseExecutor(1, PHASE, first) && manager.phasePolicyHash(1, PHASE) == oldHash
                && ledger.registeredPhasePolicyHash(address(manager), 1, PHASE) == oldHash
                && _roots() == before_,
            "late Ledger failure rolls back helper maps/hash/index"
        );
        ledger.setLedgerWriter(address(manager), true);
        _safeExecutor(first, true);
    }

    function _candidate(address resolver, address account, uint16 bps, bool frozen_)
        private
        returns (T.EconomicsConsent memory p, T.FixedEconomicsCandidate memory candidate)
    {
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](2);
        entries[0] = IStreamSplitWallet.SplitEntry(account, 900_000, keccak256("artist"));
        entries[1] = IStreamSplitWallet.SplitEntry(address(0xFEE), 100_000, keccak256("protocol"));
        IStreamSplitFactory selectedFactory =
            resolver == address(primary) ? IStreamSplitFactory(factory) : royalty.splitFactory();
        (bytes32 profile,) =
            selectedFactory.createProfile(entries, keccak256(abi.encode(account, bps)));
        candidate = T.FixedEconomicsCandidate(profile, bytes32(0), bps, frozen_);
        T.AssignmentFact memory fact = resolver == address(primary)
            ? IStreamArtistPrimaryFacts(resolver)
                .previewArtistPrimaryAssignment(1, profile, bytes32(0), frozen_)
            : IStreamArtistRoyaltyPreview(resolver)
                .previewArtistRoyaltyAssignment(1, profile, bps, frozen_);
        p = T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
    }

    function _prospectiveConsent(
        T.EconomicsConsent memory p,
        T.FixedEconomicsCandidate memory candidate
    ) private {
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
        _artistCall(
            abi.encodeCall(
                IStreamArtistEconomicsAuthority.recordProspectiveEconomicsConsent, (p, candidate, a)
            )
        );
    }

    function _freezePayload() private view returns (T.RoyaltyFreeze memory p) {
        T.AssignmentFact memory fact = coordinator.reads().currentRoyaltyAssignment(1);
        p = T.RoyaltyFreeze(address(royalty), 1, fact.revenueClass, fact.assignmentHash);
    }

    function _authorizeFreeze() private returns (T.RoyaltyFreeze memory p) {
        p = _freezePayload();
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.royaltyFreezeDigest(p, a));
        _artistCall(
            abi.encodeCall(IStreamArtistEconomicsAuthority.authorizeArtistRoyaltyFreeze, (p, a))
        );
    }

    function testSafeProspectiveEconomicsUsesActualCandidateAndSharedReplay() public {
        _accept();
        _payout();
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory installed =
            primary.resolvePrimaryAssignment(1, 0, PRIMARY);
        T.EconomicsConsent memory p =
            T.EconomicsConsent(1, address(primary), PRIMARY, 1, 1, installed.assignmentHash);
        T.FixedEconomicsCandidate memory candidate =
            T.FixedEconomicsCandidate(installed.profileId, bytes32(0), 0, false);
        _prospectiveConsent(p, candidate);
        bytes32 record = IStreamArtistConsentOwner(suite.owners[6]).economicsRecord(p);
        require(record != bytes32(0), "prospective owner record");
        // Both ingresses admit this exact active fixed candidate; they must consume
        // the same owner replay key, without any resolver mutation between calls.
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
        bytes32 before_ = _roots();
        avm.expectPartialRevert(T.Replay.selector);
        ingress.recordEconomicsConsent(p, a);
        require(
            _roots() == before_
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "shared consent key late rollback"
        );
        require(
            IStreamArtistConsentOwner(suite.owners[6]).economicsRecord(p) == record,
            "record unchanged"
        );
    }

    function testProspectiveRejectsMissingPayoutWrongHashAndWrongProfileWithoutReplay() public {
        _accept();
        (T.EconomicsConsent memory p, T.FixedEconomicsCandidate memory candidate) =
            _candidate(address(primary), address(artist), 0, false);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
        bytes32 before_ = _roots();
        avm.expectPartialRevert(T.MissingMintPrerequisite.selector);
        ingress.recordProspectiveEconomicsConsent(p, candidate, a);
        require(_roots() == before_, "missing payout unchanged");
        _payout();
        before_ = _roots();
        p.assignmentHash = keccak256("unverified caller claim");
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.recordProspectiveEconomicsConsent(p, candidate, a);
        require(_roots() == before_, "wrong hash unchanged");
        (p, candidate) = _candidate(address(primary), address(0xBAD), 0, false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.recordProspectiveEconomicsConsent(p, candidate, a);
        require(
            _roots() == before_
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "wrong operative payout unchanged"
        );
    }

    function testStaticConsentSurvivesPayoutRevisionAndOldWalletStillPaysOldAccount() public {
        _all();
        (T.AssignmentFact memory old,) = coordinator.reads().currentAssignments(1);
        (, bytes32 designation) = ingress.artistPayoutAccount(artistId);
        address newAccount = address(0xBEEF);
        T.PayoutDesignation memory update = T.PayoutDesignation(artistId, newAccount, designation);
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.payoutDesignationDigest(update, a));
        ingress.recordPayoutDesignation(update, a);
        ingress.requireMintConsent(1, PHASE, POLICY);
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory assignment =
            primary.resolvePrimaryAssignment(1, 0, PRIMARY);
        require(assignment.assignmentHash == old.assignmentHash, "fixed assignment unchanged");
        address wallet = factory.walletFor(assignment.profileId);
        vm.deal(address(this), 1 ether);
        (bool sent,) = wallet.call{ value: 1 ether }("");
        require(sent, "fund immutable wallet");
        uint256 balanceBefore = address(artist).balance;
        IStreamSplitWallet(wallet).release(address(0), address(artist), payable(address(artist)));
        require(
            address(artist).balance == balanceBefore + 0.9 ether
                && IStreamSplitWallet(wallet).aggregateSharePpm(newAccount) == 0,
            "old account retains fixed economics"
        );
        (T.EconomicsConsent memory p, T.FixedEconomicsCandidate memory candidate) =
            _candidate(address(primary), address(artist), 0, false);
        a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.recordProspectiveEconomicsConsent(p, candidate, a);
        (p, candidate) = _candidate(address(primary), newAccount, 0, false);
        _prospectiveConsent(p, candidate);
        require(
            IStreamArtistConsentOwner(suite.owners[6]).economicsRecord(p) != bytes32(0),
            "new designation governs new consent"
        );
    }

    function testSafeDefensiveFreezeHasExactRecordAndNoMintFloorDependency() public {
        _accept();
        // No payout, economics, policy, content or attestation records. An explicitly
        // failing primary read proves the defensive route never consults that provider.
        avm.mockCallRevert(
            address(primary),
            abi.encodePacked(IStreamRevenueResolver.resolvePrimaryAssignment.selector),
            abi.encodeWithSelector(T.InvalidRecord.selector)
        );
        T.RoyaltyFreeze memory p = _freezePayload();
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.royaltyFreezeDigest(p, a));
        vm.recordLogs();
        bytes32 record = ingress.authorizeArtistRoyaltyFreeze(p, a);
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ROYALTY_FREEZE_RECORD_V1"),
                block.chainid,
                address(ingress),
                p.resolver,
                p.collectionId,
                p.revenueClass,
                p.expectedAssignmentHash,
                artistId,
                address(artist),
                uint8(1),
                a.nonce,
                uint64(block.timestamp)
            )
        );
        require(
            record == expected && ingress.isRoyaltyFreezeAuthorized(1, p.expectedAssignmentHash),
            "exact freeze record and read"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool found;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != suite.owners[6]) continue;
            require(
                logs[i].topics[0]
                        == keccak256(
                            "ArtistRoyaltyFreezeAuthorized(uint16,uint256,bytes32,address,uint8,uint256,uint64,bytes32)"
                        ) && logs[i].topics[1] == bytes32(uint256(1))
                    && logs[i].topics[2] == p.expectedAssignmentHash
                    && logs[i].topics[3] == bytes32(uint256(uint160(address(artist)))),
                "exact freeze event"
            );
            (uint16 schema, uint8 authority, uint256 nonce, uint64 time, bytes32 emitted) =
                abi.decode(logs[i].data, (uint16, uint8, uint256, uint64, bytes32));
            require(
                schema == 1 && authority == 1 && nonce == a.nonce && time == block.timestamp
                    && emitted == record,
                "freeze event payload"
            );
            found = true;
        }
        require(found && _closed(_mintCall()), "freeze right independent of mint eligibility");
        IStreamRoyaltyResolver.RoyaltyConfig memory prior = royalty.collectionRoyalty(1);
        royalty.applyArtistRoyaltyFreeze(1, p.expectedAssignmentHash);
        IStreamRoyaltyResolver.RoyaltyConfig memory after_ = royalty.collectionRoyalty(1);
        require(
            after_.frozen && prior.wallet == after_.wallet && prior.profileId == after_.profileId
                && prior.royaltyBps == after_.royaltyBps,
            "only frozen bit changes"
        );
    }

    function testFreezeChangesEconomicsHashAndNeedsSeparateConsentForMint() public {
        _all();
        T.RoyaltyFreeze memory p = _authorizeFreeze();
        royalty.applyArtistRoyaltyFreeze(1, p.expectedAssignmentHash);
        avm.expectPartialRevert(T.MissingMintPrerequisite.selector);
        ingress.requireMintConsent(1, PHASE, POLICY);
        _economicsRecord(coordinator.reads().currentRoyaltyAssignment(1));
        ingress.requireMintConsent(1, PHASE, POLICY);
    }

    function testActualSafeDirectProspectiveFrozenConsentAndFreezeKeepMintEligible() public {
        directArtistCalls = true;
        _all();
        IStreamRoyaltyResolver.RoyaltyConfig memory r = royalty.collectionRoyalty(1);
        T.FixedEconomicsCandidate memory candidate =
            T.FixedEconomicsCandidate(r.profileId, bytes32(0), r.royaltyBps, true);
        T.AssignmentFact memory fact =
            royalty.previewArtistRoyaltyAssignment(1, r.profileId, r.royaltyBps, true);
        T.EconomicsConsent memory p =
            T.EconomicsConsent(1, fact.resolver, fact.revenueClass, 1, 1, fact.assignmentHash);
        _prospectiveConsent(p, candidate);
        T.RoyaltyFreeze memory freeze = _authorizeFreeze();
        royalty.applyArtistRoyaltyFreeze(1, freeze.expectedAssignmentHash);
        ingress.requireMintConsent(1, PHASE, POLICY);
        require(
            ingress.supportsInterface(type(IStreamArtistEconomicsAuthority).interfaceId),
            "narrow economics API advertised"
        );
    }

    function testFreezeRejectsWrongTargetClassHashAndSignatureWithoutMutation() public {
        _accept();
        T.RoyaltyFreeze memory p = _freezePayload();
        T.Authorization memory a = _authorization(false);
        bytes32 correct = p.expectedAssignmentHash;
        bytes32 before_ = _roots();
        p.resolver = address(primary);
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.authorizeArtistRoyaltyFreeze(p, a);
        p.resolver = address(royalty);
        p.revenueClass = PRIMARY;
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.authorizeArtistRoyaltyFreeze(p, a);
        p.revenueClass = keccak256("ROYALTY_ERC2981");
        p.expectedAssignmentHash = keccak256("wrong assignment");
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.authorizeArtistRoyaltyFreeze(p, a);
        a.signature = _signature(ingress.royaltyFreezeDigest(p, a));
        p.expectedAssignmentHash = correct;
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.authorizeArtistRoyaltyFreeze(p, a);
        require(
            _roots() == before_
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "invalid freeze no mutations"
        );
        a.signature = _signature(ingress.royaltyFreezeDigest(p, a));
        ingress.authorizeArtistRoyaltyFreeze(p, a);
        before_ = _roots();
        avm.expectPartialRevert(T.Replay.selector);
        ingress.authorizeArtistRoyaltyFreeze(p, a);
        require(_roots() == before_, "freeze replay unchanged");
    }

    function testFreezeArchiveFailureRollsBackBothOwnersAndAllowsExactRetry() public {
        _accept();
        T.RoyaltyFreeze memory p = _freezePayload();
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.royaltyFreezeDigest(p, a));
        bytes32 before_ = _roots();
        avm.mockCallRevert(
            address(archive),
            abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(T.InvalidRecord.selector)
        );
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.authorizeArtistRoyaltyFreeze(p, a);
        require(
            _roots() == before_ && !ingress.isRoyaltyFreezeAuthorized(1, p.expectedAssignmentHash)
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "late archive atomic rollback"
        );
        avm.clearMockedCalls();
        ingress.authorizeArtistRoyaltyFreeze(p, a);
        require(
            ingress.isRoyaltyFreezeAuthorized(1, p.expectedAssignmentHash),
            "same signed operation retry"
        );
    }

    function _approveMessage(bytes32 digest) private {
        require(
            executeSafe(
                artist,
                keys,
                safeComponents.signMessage,
                0,
                abi.encodeWithSignature("signMessage(bytes)", abi.encode(digest)),
                1
            ),
            "Safe message approval"
        );
    }

    function testSafeApprovedEmptyProofWorksForBothNewEconomicsEndpoints() public {
        _accept();
        _payout();
        (T.EconomicsConsent memory p, T.FixedEconomicsCandidate memory candidate) =
            _candidate(address(primary), address(artist), 0, false);
        T.Authorization memory a = _authorization(false);
        bytes32 before_ = _roots();
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordProspectiveEconomicsConsent(p, candidate, a);
        require(_roots() == before_, "unapproved economics empty proof rejected");
        _approveMessage(ingress.economicsConsentDigest(p, a));
        ingress.recordProspectiveEconomicsConsent(p, candidate, a);
        T.RoyaltyFreeze memory freeze = _freezePayload();
        a = _authorization(false);
        before_ = _roots();
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.authorizeArtistRoyaltyFreeze(freeze, a);
        require(_roots() == before_, "unapproved freeze empty proof rejected");
        _approveMessage(ingress.royaltyFreezeDigest(freeze, a));
        ingress.authorizeArtistRoyaltyFreeze(freeze, a);
        require(
            ingress.isRoyaltyFreezeAuthorized(1, freeze.expectedAssignmentHash),
            "preapproved empty freeze proof"
        );
    }

    function testFreezeAuthorizationCannotFollowAnotherBindingGeneration() public {
        _accept();
        T.RoyaltyFreeze memory p = _authorizeFreeze();
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        ++b.generation;
        b.bindingHash = keccak256("later binding");
        // Model future authoritative owner reads only; no currently unsupported
        // rebind operation is claimed. An old authorization must not follow them.
        avm.mockCall(
            suite.owners[0], abi.encodeCall(IStreamArtistBindingOwner.binding, (1)), abi.encode(b)
        );
        avm.mockCall(
            suite.owners[4],
            abi.encodeCall(IStreamArtistAttributionOwner.attributionState, (1)),
            abi.encode(uint8(2), b.generation)
        );
        require(
            !ingress.isRoyaltyFreezeAuthorized(1, p.expectedAssignmentHash),
            "binding generation isolates freeze authority"
        );
        avm.clearMockedCalls();
        require(
            ingress.isRoyaltyFreezeAuthorized(1, p.expectedAssignmentHash),
            "original binding record preserved"
        );
    }

    function testActualSafeCannotCallNewProtocolOnlyEconomicsCallbacks() public {
        _accept();
        T.RoyaltyFreeze memory p = _freezePayload();
        T.Authorization memory a = _authorization(false);
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        T.SignerApproval memory proof =
            T.SignerApproval(address(artist), ingress.royaltyFreezeDigest(p, a), true);
        bytes32 before_ = _roots();
        vm.expectRevert();
        this.executeTargetSafe(
            address(coordinator),
            abi.encodeCall(
                IStreamArtistEconomicsCoordinator.coordinateAuthorizeArtistRoyaltyFreeze,
                (address(artist), p, a)
            )
        );
        T.ActionContext memory c = T.ActionContext(
            20, address(artist), IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2()
        );
        vm.expectRevert();
        this.executeTargetSafe(
            suite.owners[2],
            abi.encodeCall(IStreamArtistIdentityOwner.consumeRoyaltyFreeze, (c, b, p, a, proof))
        );
        c.expected = IStreamArtistOwner(suite.owners[6]).ownerStateSnapshotV2();
        vm.expectRevert();
        this.executeTargetSafe(
            suite.owners[6],
            abi.encodeCall(
                IStreamArtistConsentOwner.authorizeRoyaltyFreeze,
                (c, b, p, address(artist), a.nonce)
            )
        );
        require(_roots() == before_, "actual Safe has no coordinator privilege");
    }

    function testActualSafeCallsBothRealPreviewsAndFreezeReads() public {
        _accept();
        _payout();
        (T.EconomicsConsent memory p, T.FixedEconomicsCandidate memory candidate) =
            _candidate(address(primary), address(artist), 0, false);
        require(
            executeSafe(
                artist,
                keys,
                address(primary),
                0,
                abi.encodeCall(
                    IStreamArtistPrimaryFacts.previewArtistPrimaryAssignment,
                    (1, candidate.profileHash, bytes32(0), false)
                ),
                0
            ),
            "Safe actual primary preview"
        );
        _prospectiveConsent(p, candidate);
        (p, candidate) = _candidate(address(royalty), address(artist), 650, false);
        require(
            executeSafe(
                artist,
                keys,
                address(royalty),
                0,
                abi.encodeCall(
                    IStreamArtistRoyaltyPreview.previewArtistRoyaltyAssignment,
                    (1, candidate.profileHash, uint16(650), false)
                ),
                0
            ),
            "Safe actual royalty preview"
        );
        _prospectiveConsent(p, candidate);
        T.RoyaltyFreeze memory freeze = _freezePayload();
        T.Authorization memory a = _authorization(false);
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistEconomicsAuthority.royaltyFreezeDigest, (freeze, a)),
                0
            ),
            "Safe freeze digest read"
        );
        require(
            !ingress.isRoyaltyFreezeAuthorized(1, freeze.expectedAssignmentHash),
            "no authorization yet"
        );
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistEconomicsAuthority.isRoyaltyFreezeAuthorized,
                    (1, freeze.expectedAssignmentHash)
                ),
                0
            ),
            "Safe authorization read"
        );
        a.signature = _signature(ingress.royaltyFreezeDigest(freeze, a));
        ingress.authorizeArtistRoyaltyFreeze(freeze, a);
        require(
            executeSafe(
                artist,
                keys,
                address(royalty),
                0,
                abi.encodeCall(
                    IStreamRoyaltyFreeze.applyArtistRoyaltyFreeze,
                    (1, freeze.expectedAssignmentHash)
                ),
                0
            ),
            "Safe relays real exact defensive freeze"
        );
        require(royalty.collectionRoyalty(1).frozen, "real provider freeze applied");
    }

    function testActualSafeOwnerAppliesRealPrimaryCandidateOnlyAfterArtistConsent() public {
        _all();
        (T.EconomicsConsent memory p, T.FixedEconomicsCandidate memory candidate) =
            _candidate(address(primary), address(artist), 0, false);
        // Ownership setup is a fixture action; timelock authorization is separately
        // covered by the actual Executor integration, not by this unit handover.
        vm.prank(primary.owner());
        primary.transferOwnership(address(artist));
        bytes memory data = abi.encodeCall(
            IStreamRevenueResolver.setPrimaryProfileAssignment,
            (PRIMARY, uint8(1), uint256(1), candidate.profileHash, bytes32(0))
        );
        bytes32 before_ = primary.resolvePrimaryAssignment(1, 0, PRIMARY).assignmentHash;
        vm.prank(address(artist));
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("economics"))
        );
        primary.setPrimaryProfileAssignment(PRIMARY, 1, 1, candidate.profileHash, bytes32(0));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(address(primary), data);
        require(
            primary.resolvePrimaryAssignment(1, 0, PRIMARY).assignmentHash == before_,
            "missing consent no mutation"
        );
        _prospectiveConsent(p, candidate);
        require(
            executeSafe(artist, keys, address(primary), 0, data, 0),
            "Safe applies actual primary candidate"
        );
        require(
            primary.resolvePrimaryAssignment(1, 0, PRIMARY).assignmentHash == p.assignmentHash,
            "preview equals applied hash"
        );
        ingress.requireMintConsent(1, PHASE, POLICY);
    }
}
