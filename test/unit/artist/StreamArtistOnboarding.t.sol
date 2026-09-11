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
    mapping(address => bool) private extraAdmins;
    uint64 private revision = 1;
    bytes32 private changes;

    constructor(address admin_) {
        admin = admin_;
    }

    function hasRole(bytes32 role, address account) external view returns (bool) {
        return role == keccak256("ROLE_ARTIST_REGISTRY_ADMIN")
            && (account == admin || extraAdmins[account]);
    }

    function setAdmin(address account, bool enabled) external {
        require(msg.sender == admin, "unit admin");
        extraAdmins[account] = enabled;
        changes = keccak256(abi.encode(changes, account, enabled));
        ++revision;
    }

    function roleMutationState(bytes32 role) external view returns (bytes32, uint64) {
        return (
            changes == bytes32(0)
                ? keccak256(abi.encode(role, admin))
                : keccak256(abi.encode(role, admin, changes)),
            revision
        );
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

/// @dev Algorithm fixture only: clearing the account simulates a future completed rotation.
/// It is not a production rotation entrypoint or a substitute for Coordinator authentication.
contract ArtistCollaboratorAccountReplayHarness {
    StreamArtistIdentityState.State private identities;
    StreamArtistCollaboratorIdentityState.State private accounts;
    mapping(bytes32 => T.ReplayCell) private replay;
    uint64 private revision;

    function context() private view returns (StreamArtistIdentityState.OwnerContext memory) {
        return StreamArtistIdentityState.OwnerContext(
            StreamArtistHashes.Environment(block.chainid, address(this), address(1), address(2)),
            address(3),
            address(4),
            keccak256("domain:identity_authority"),
            revision
        );
    }

    function allocate(address account, uint256 nonce, bool direct) external returns (bytes32) {
        bytes memory doc = bytes("persistent account replay fixture");
        C.IdentityProposal memory p = C.IdentityProposal(
            account, keccak256(doc), "urn:fixture", keccak256("fixture"), "urn:reason"
        );
        T.Authorization memory a =
            T.Authorization(nonce, 2000, direct ? bytes("") : bytes("validated fixture proof"));
        StreamArtistIdentityState.OwnerContext memory o = context();
        T.SignerApproval memory proof = T.SignerApproval(
            account,
            StreamArtistCollaboratorHashes.identityDigest(
                o.environment, account, p.identityRecordHash, a
            ),
            direct
        );
        T.Snapshot memory snapshot;
        StreamArtistIdentityState.Mutation memory m = StreamArtistCollaboratorIdentityState.register(
            identities,
            accounts,
            replay,
            o,
            T.ActionContext(6, account, snapshot),
            p,
            a,
            proof,
            doc,
            "Replay Fixture"
        );
        ++revision;
        return m.record;
    }

    function simulateCompletedRotation(address account) external {
        identities.activeIdentity[account] = bytes32(0);
    }

    function facts(address account, uint256 nonce)
        external
        view
        returns (bool, uint256, uint256, bytes32)
    {
        (bool used, uint256 hint) = StreamArtistCollaboratorIdentityState.nonceState(
            accounts, replay, context(), account, nonce
        );
        return (used, hint, identities.nextRegistrationNonce, identities.activeIdentity[account]);
    }
}

/// @notice Real artist owners, both economics providers, split profiles and official Safe signatures.
/// @dev Core, metadata and governance boundaries are explicit unit doubles;
///      a separate current-stack test owns integration and eligible token mint proof.
contract StreamArtistOnboardingTest is CharacterizationTestBase, OfficialSafeFixture {
    event CollaboratorBoundMeasurement(uint256 rows, uint256 entries, uint256 gasUsed);
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
    bytes32 private collaboratorId;
    uint8 private templateFixtureKind;
    bytes32 private templateFixtureId;

    function _freshTemplateFixture(uint8 kind) private {
        // A separate deployment with a prebinding template; no existing assignment or history is reset.
        templateFixtureKind = kind;
        setUp();
    }

    function _installInitialPrimary(address governance, bytes32 profile) private {
        if (templateFixtureKind == 0) {
            vm.prank(governance);
            primary.setPrimaryProfileAssignment(PRIMARY, 1, 1, profile, bytes32(0));
            return;
        }
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](2);
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            templateFixtureKind == 3 ? address(artist) : address(0),
            templateFixtureKind == 3
                ? bytes32(0)
                : keccak256(
                    templateFixtureKind == 2 ? bytes("SALE_POSTER") : bytes("COLLECTION_ARTIST")
                ),
            templateFixtureKind == 4 ? 400_000 : 900_000,
            keccak256("artist")
        );
        entries[1] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0xFEE),
            bytes32(0),
            templateFixtureKind == 4 ? 600_000 : 100_000,
            keccak256("protocol")
        );
        vm.prank(governance);
        templateFixtureId =
            primary.createPrimaryTemplate(entries, keccak256("unit immutable primary template"));
        vm.prank(governance);
        primary.setPrimaryTemplateAssignment(PRIMARY, 1, 1, templateFixtureId, bytes32(0));
    }

    function testCurrentTemplateSafeConsentMaterializesLatestPayoutAndOldWalletStillPaysOldAccount()
        public
    {
        _freshTemplateFixture(1);
        _all();
        ingress.requireMintConsent(1, PHASE, POLICY);
        (T.AssignmentFact memory fact,) = coordinator.reads().currentAssignments(1);
        T.EconomicsConsent memory p = T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
        bytes32 record = IStreamArtistConsentOwner(suite.owners[6]).economicsRecord(p);
        (bytes32 oldProfile, address oldWallet,) =
            primary.materializeCollectionPrimaryProfile(templateFixtureId, 1, address(this), true);
        require(
            IStreamSplitWallet(oldWallet).aggregateSharePpm(address(artist)) == 900_000,
            "initial dynamic artist account"
        );
        (, bytes32 previous) = ingress.artistPayoutAccount(artistId);
        T.PayoutDesignation memory update = T.PayoutDesignation(artistId, address(0xCAFE), previous);
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.payoutDesignationDigest(update, a));
        ingress.recordPayoutDesignation(update, a);
        ingress.requireMintConsent(1, PHASE, POLICY);
        require(
            IStreamArtistConsentOwner(suite.owners[6]).economicsRecord(p) == record,
            "same immutable template consent"
        );
        (bytes32 newProfile, address newWallet,) =
            primary.materializeCollectionPrimaryProfile(templateFixtureId, 1, address(this), true);
        require(
            newProfile != oldProfile && newWallet != oldWallet
                && IStreamSplitWallet(newWallet).aggregateSharePpm(address(0xCAFE)) == 900_000,
            "future materialization uses new operative designation"
        );
        vm.deal(address(this), 1 ether);
        (bool paid,) = oldWallet.call{ value: 1 ether }("");
        require(paid, "fund old wallet");
        uint256 before_ = address(artist).balance;
        IStreamSplitWallet(oldWallet).release(address(0), address(artist), payable(address(artist)));
        require(
            address(artist).balance == before_ + 0.9 ether
                && IStreamSplitWallet(oldWallet).aggregateSharePpm(address(0xCAFE)) == 0,
            "old wallet rights immutable"
        );
    }

    function _cancelAuthorization(StreamArtistAuthorizationTypes.Revocation memory p)
        private
        returns (bytes32)
    {
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.authorizationRevocationDigest(p, a));
        return ingress.revokeArtistAuthorization(p, a);
    }

    function testAuthorizationRevocationConfigurationPinsEverySupportedOperationAndRuntime()
        public
    {
        bytes32[16] memory runtimeHashes;
        for (uint256 i; i < 7; ++i) {
            runtimeHashes[i] = suite.owners[i].codehash;
        }
        runtimeHashes[7] = suite.registry.codehash;
        runtimeHashes[8] = suite.archive.codehash;
        runtimeHashes[9] = suite.core.codehash;
        runtimeHashes[10] = suite.mintManager.codehash;
        runtimeHashes[11] = suite.roleRegistry.codehash;
        runtimeHashes[12] = suite.metadata.codehash;
        runtimeHashes[13] = suite.primaryResolver.codehash;
        runtimeHashes[14] = suite.royaltyResolver.codehash;
        runtimeHashes[15] = suite.validator.codehash;
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_CONFIGURATION_V1"),
                block.chainid,
                address(coordinator),
                suite,
                runtimeHashes,
                uint16(1),
                uint16(2),
                uint16(3),
                uint16(4),
                uint16(5),
                uint16(6),
                uint16(7),
                uint16(14),
                uint16(15),
                uint16(18),
                uint16(20),
                uint16(24),
                uint16(26),
                uint16(27),
                uint16(52),
                uint16(54)
            )
        );
        require(coordinator.configurationHash() == expected, "full executable operation commitment");
    }

    function testAuthorizationRevocationDelayedDirectSafeHasExactRecordEventAndAdjacentHint()
        public
    {
        StreamArtistAuthorizationTypes.Revocation memory p =
            StreamArtistAuthorizationTypes.Revocation(artistId, bytes32(0), 1);
        T.Authorization memory a = T.Authorization(0, 2000, "");
        bytes32 digest = ingress.authorizationRevocationDigest(p, a);
        bytes memory prepared =
            abi.encodeCall(IStreamArtistAuthorizationRevocation.revokeArtistAuthorization, (p, a));
        T.Snapshot[7] memory before_;
        for (uint256 i; i < 7; ++i) {
            before_[i] = IStreamArtistOwner(suite.owners[i]).ownerStateSnapshotV2();
        }
        vm.warp(1100);
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_AUTH_REVOCATION_RECORD_V1"),
                block.chainid,
                address(ingress),
                artistId,
                bytes32(0),
                uint256(1),
                uint256(0),
                uint64(1100)
            )
        );
        vm.recordLogs();
        this.executeTargetSafe(address(ingress), prepared);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool found;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != suite.owners[2]
                    || logs[i].topics[0]
                        != keccak256(
                            "ArtistAuthorizationRevoked(uint16,bytes32,bytes32,uint256,uint256,uint64,bytes32)"
                        )
            ) continue;
            require(
                logs[i].topics.length == 2 && logs[i].topics[1] == artistId,
                "exact revocation topics"
            );
            (
                uint16 schema,
                bytes32 revokedDigest,
                uint256 target,
                uint256 nonce,
                uint64 observed,
                bytes32 record
            ) = abi.decode(logs[i].data, (uint16, bytes32, uint256, uint256, uint64, bytes32));
            require(
                schema == 1 && revokedDigest == 0 && target == 1 && nonce == 0 && observed == 1100
                    && record == expected,
                "canonical event and observed time"
            );
            found = true;
        }
        require(found, "Identity emits exact record");
        StreamArtistAuthorizationTypes.State memory s =
            ingress.artistAuthorizationState(artistId, digest, 1);
        require(
            s.digestObserved && !s.digestRevoked && s.nonceConsumed && s.nonceRevoked
                && s.nextUnusedNonce == 2,
            "own nonce followed by adjacent target"
        );
        for (uint256 i; i < 7; ++i) {
            if (i != 2) {
                require(
                    keccak256(abi.encode(before_[i]))
                        == keccak256(
                            abi.encode(IStreamArtistOwner(suite.owners[i]).ownerStateSnapshotV2())
                        ),
                    "defensive Identity-only mutation"
                );
            }
        }
        (
            StreamArtistAuthorizationTypes.Revocation memory submitted,
            T.Authorization memory auth,
            T.SignerApproval memory proof
        ) = abi.decode(
            _operationPayload(54, address(artist), expected),
            (StreamArtistAuthorizationTypes.Revocation, T.Authorization, T.SignerApproval)
        );
        require(
            submitted.revokedNonce == 1 && auth.time == 2000 && proof.direct
                && proof.digest == digest,
            "archive original authorization"
        );
        this.executeTargetSafe(
            address(ingress),
            abi.encodeCall(
                IStreamArtistAuthorizationRevocation.artistAuthorizationState, (artistId, digest, 1)
            )
        );
    }

    function testAuthorizationRevocationCancelsFuturePolicyNonceAndExactDigest() public {
        _accept();
        T.PolicyConsent memory p = T.PolicyConsent(1, PHASE, POLICY);
        T.Authorization memory a = T.Authorization(71, 2000, "");
        a.signature = _signature(ingress.policyConsentDigest(p, a));
        _cancelAuthorization(StreamArtistAuthorizationTypes.Revocation(artistId, bytes32(0), 71));
        bytes32 before_ = _roots();
        avm.expectPartialRevert(T.Replay.selector);
        ingress.recordPolicyConsent(p, a);
        require(_roots() == before_, "revoked nonce leaves record unchanged");
        a.nonce = 72;
        bytes32 digest = ingress.policyConsentDigest(p, a);
        a.signature = _signature(digest);
        _cancelAuthorization(StreamArtistAuthorizationTypes.Revocation(artistId, digest, 0));
        before_ = _roots();
        avm.expectPartialRevert(T.Replay.selector);
        ingress.recordPolicyConsent(p, a);
        StreamArtistAuthorizationTypes.State memory s =
            ingress.artistAuthorizationState(artistId, digest, 72);
        require(
            _roots() == before_ && s.digestRevoked && !s.digestObserved && !s.nonceConsumed,
            "digest revocation does not consume target nonce"
        );
        _policy();
    }

    function testAuthorizationRevocationCanCancelNonceZeroAcceptanceByItsExactDigest() public {
        T.Authorization memory acceptance = T.Authorization(0, 2000, "");
        bytes32 digest = ingress.acceptanceDigest(1, acceptance);
        acceptance.signature = _signature(digest);
        StreamArtistAuthorizationTypes.Revocation memory target =
            StreamArtistAuthorizationTypes.Revocation(artistId, digest, 0);
        T.Authorization memory cancel = T.Authorization(99, 2000, "");
        cancel.signature = _signature(ingress.authorizationRevocationDigest(target, cancel));
        ingress.revokeArtistAuthorization(target, cancel);
        bytes32 before_ = _roots();
        avm.expectPartialRevert(T.Replay.selector);
        ingress.acceptArtistBinding(1, acceptance);
        StreamArtistAuthorizationTypes.State memory s =
            ingress.artistAuthorizationState(artistId, digest, 0);
        require(
            _roots() == before_ && s.digestRevoked && !s.nonceConsumed && s.nextUnusedNonce == 0
                && ingress.acceptedArtist(1) == address(0),
            "nonce zero cancellation is exact digest scoped"
        );
    }

    function testAuthorizationRevocationRejectsPreviouslyExecutedDigestAndNonce() public {
        _accept();
        T.PolicyConsent memory p = T.PolicyConsent(1, PHASE, POLICY);
        T.Authorization memory old =
            T.Authorization(nextNonce, uint64(block.timestamp + 1 days), "");
        bytes32 digest = ingress.policyConsentDigest(p, old);
        _policy();
        StreamArtistAuthorizationTypes.Revocation memory target =
            StreamArtistAuthorizationTypes.Revocation(artistId, digest, 0);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.authorizationRevocationDigest(target, a));
        bytes32 before_ = _roots();
        avm.expectPartialRevert(T.Replay.selector);
        ingress.revokeArtistAuthorization(target, a);
        target.revokedDigest = 0;
        target.revokedNonce = old.nonce;
        a.signature = _signature(ingress.authorizationRevocationDigest(target, a));
        avm.expectPartialRevert(T.Replay.selector);
        ingress.revokeArtistAuthorization(target, a);
        require(
            _roots() == before_
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "preventive only and own nonce rolls back"
        );
    }

    function testAuthorizationRevocationLateArchiveFailureRollsBackDenyObservationAndIndex()
        public
    {
        StreamArtistAuthorizationTypes.Revocation memory p =
            StreamArtistAuthorizationTypes.Revocation(artistId, bytes32(0), 1);
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.authorizationRevocationDigest(p, a);
        a.signature = _signature(digest);
        bytes32 before_ = _roots();
        avm.mockCallRevert(
            address(archive),
            abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(T.InvalidRecord.selector)
        );
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.revokeArtistAuthorization(p, a);
        StreamArtistAuthorizationTypes.State memory s =
            ingress.artistAuthorizationState(artistId, digest, 1);
        require(
            _roots() == before_ && !s.digestObserved && !s.nonceConsumed && !s.nonceRevoked
                && s.nextUnusedNonce == 0,
            "all late effects rolled back"
        );
        avm.clearMockedCalls();
        ingress.revokeArtistAuthorization(p, a);
        before_ = _roots();
        avm.expectPartialRevert(T.Replay.selector);
        ingress.revokeArtistAuthorization(p, a);
        require(_roots() == before_, "exact repeat cannot revoke twice");
    }

    function testAuthorizationRevocationSafeApprovedEmptyAndProtocolOnlyGuards() public {
        StreamArtistAuthorizationTypes.Revocation memory p =
            StreamArtistAuthorizationTypes.Revocation(artistId, bytes32(0), 90);
        T.Authorization memory a = T.Authorization(0, 2000, "");
        bytes32 digest = ingress.authorizationRevocationDigest(p, a);
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.revokeArtistAuthorization(p, a);
        _approveMessage(digest);
        ingress.revokeArtistAuthorization(p, a);
        require(
            ingress.artistAuthorizationState(artistId, digest, 90).nonceRevoked,
            "real preapproved empty Safe relay"
        );
        T.ActionContext memory c = T.ActionContext(
            54, address(artist), IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2()
        );
        T.SignerApproval memory proof = T.SignerApproval(address(artist), digest, true);
        bytes memory ownerCall =
            abi.encodeCall(IStreamArtistAuthorizationOwner.revokeAuthorization, (c, p, a, proof));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(suite.owners[2], ownerCall);
        bytes memory coordinatorCall = abi.encodeCall(
            IStreamArtistAuthorizationCoordinator.coordinateRevokeArtistAuthorization,
            (address(artist), p, a)
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(address(coordinator), coordinatorCall);
    }

    function testAuthorizationRevocationRejectsBadTargetsAuthorityDomainAndExpiry() public {
        StreamArtistAuthorizationTypes.Revocation memory p =
            StreamArtistAuthorizationTypes.Revocation(artistId, bytes32(0), 33);
        T.Authorization memory a = T.Authorization(0, 2000, "");
        address ownerEoa = vm.addr(keys[0]);
        vm.prank(ownerEoa);
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.revokeArtistAuthorization(p, a);
        a.signature = _signature(keccak256("wrong domain"));
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.revokeArtistAuthorization(p, a);
        a.time = 999;
        a.signature = _signature(ingress.authorizationRevocationDigest(p, a));
        vm.expectRevert(abi.encodeWithSelector(T.ExpiredAuthorization.selector, uint64(999)));
        ingress.revokeArtistAuthorization(p, a);
        a.time = 2000;
        p.revokedDigest = keccak256("both targets");
        a.signature = _signature(ingress.authorizationRevocationDigest(p, a));
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.revokeArtistAuthorization(p, a);
        p.revokedDigest = 0;
        p.revokedNonce = 0;
        a.signature = _signature(ingress.authorizationRevocationDigest(p, a));
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.revokeArtistAuthorization(p, a);
        p.revokedNonce = 1;
        a.nonce = 1;
        a.signature = _signature(ingress.authorizationRevocationDigest(p, a));
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.revokeArtistAuthorization(p, a);
        require(
            ingress.artistAuthorizationState(artistId, 0, 0).nextUnusedNonce == 0,
            "all invalid branches preserve allocator"
        );
    }

    function testAuthorizationRevocationSparseMaximumAndReversePrefixKeepDirectHintBounded()
        public
    {
        for (uint256 i = 16; i != 0; --i) {
            StreamArtistAuthorizationTypes.Revocation memory p =
                StreamArtistAuthorizationTypes.Revocation(artistId, bytes32(0), i);
            T.Authorization memory a = T.Authorization(100 + i, 2000, "");
            a.signature = _signature(ingress.authorizationRevocationDigest(p, a));
            ingress.revokeArtistAuthorization(p, a);
        }
        StreamArtistAuthorizationTypes.Revocation memory p =
            StreamArtistAuthorizationTypes.Revocation(artistId, bytes32(0), type(uint256).max);
        T.Authorization memory a = T.Authorization(0, 2000, "");
        a.signature = _signature(ingress.authorizationRevocationDigest(p, a));
        ingress.revokeArtistAuthorization(p, a);
        require(
            ingress.artistAuthorizationState(artistId, 0, type(uint256).max).nextUnusedNonce == 17,
            "bounded prefix and maximum leaf"
        );
        p.revokedNonce = 18;
        a.nonce = 17;
        a.signature = "";
        this.executeTargetSafe(
            address(ingress),
            abi.encodeCall(IStreamArtistAuthorizationRevocation.revokeArtistAuthorization, (p, a))
        );
        require(
            ingress.artistAuthorizationState(artistId, 0, 18).nextUnusedNonce == 19,
            "direct exact hint after reverse ordered signatures"
        );
    }

    function testAuthorizationRevocationDelayedEoaIsIdentityScopedWithoutAcceptance() public {
        address account = vm.addr(0xA54);
        T.BindingProposal memory proposal = _proposal(bytes32(0));
        proposal.artistAddress = account;
        (bytes32 second,) = ingress.proposeArtistBinding(
            2, proposal, bytes("unit identity document"), "Artist Safe"
        );
        StreamArtistAuthorizationTypes.Revocation memory p =
            StreamArtistAuthorizationTypes.Revocation(second, bytes32(0), 19);
        T.Authorization memory a = T.Authorization(0, 2000, "");
        bytes memory prepared =
            abi.encodeCall(IStreamArtistAuthorizationRevocation.revokeArtistAuthorization, (p, a));
        vm.warp(1200);
        vm.prank(account);
        (bool ok,) = address(ingress).call(prepared);
        require(
            ok && ingress.artistAuthorizationState(second, 0, 19).nonceRevoked,
            "delayed direct EOA defensive action"
        );
        require(
            !ingress.artistAuthorizationState(artistId, 0, 19).nonceConsumed
                && ingress.acceptedArtist(2) == address(0),
            "no cross identity or acceptance prerequisite"
        );
        p.artistId = artistId;
        p.revokedNonce = 20;
        a.nonce = 1;
        vm.prank(account);
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.revokeArtistAuthorization(p, a);
    }

    function testAuthorizationRevocationDelegatedDigestObservationPreservesSeparateLanes() public {
        _accept();
        _payout();
        _delegateSetup();
        bytes32 firstGrant = _grant(_delegation(1, 4, 1000, 2000, 0));
        uint256[] memory otherKeys = new uint256[](2);
        otherKeys[0] = 0xED1;
        otherKeys[1] = 0xED2;
        OfficialSafe other =
            createOfficialSafe(safeComponents, safeOwnerAddresses(otherKeys), 2, 540);
        D.Grant memory otherTerms = _delegation(1, 4, 1000, 2000, 0);
        otherTerms.delegate = address(other);
        bytes32 secondGrant = _grant(otherTerms);
        T.EconomicsConsent memory p = _currentEconomics(address(primary));
        T.Authorization memory a = T.Authorization(40, 2000, "");
        bytes32 digest = ingress.economicsConsentDigest(p, a);
        a.signature = _delegateSignature(digest);
        bytes32 first = ingress.recordDelegatedEconomicsConsent(p, firstGrant, a);
        a.signature =
            safeThresholdSignature(otherKeys, safeMessageDigest(other, abi.encode(digest)));
        bytes32 consentKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                address(ingress),
                address(coordinator),
                address(archive),
                suite.owners[6],
                keccak256("domain:consent_finality"),
                keccak256("consent_finality.replay.consent_key"),
                keccak256(abi.encode(p))
            )
        );
        bytes32 unchanged = _roots();
        vm.expectRevert(abi.encodeWithSelector(T.Replay.selector, consentKey));
        ingress.recordDelegatedEconomicsConsent(p, secondGrant, a);
        require(_roots() == unchanged, "existing duplicate economics record rule preserved");
        // Explicit unit protocol boundary: isolate Identity's replay lane from
        // Consent's independent one-record-per-assignment rule after verifying
        // the second actual Safe proof. This is not a second full consent record.
        bytes32 second = _consumeDelegateIdentityOnly(p, a, secondGrant, address(other), digest);
        require(
            first != second && ingress.artistAuthorizationState(artistId, digest, 40).digestObserved
                && !ingress.artistAuthorizationState(artistId, digest, 40).nonceConsumed,
            "same digest succeeds in distinct Identity lanes"
        );
        StreamArtistAuthorizationTypes.Revocation memory target =
            StreamArtistAuthorizationTypes.Revocation(artistId, digest, 0);
        T.Authorization memory cancel = _authorization(false);
        cancel.signature = _signature(ingress.authorizationRevocationDigest(target, cancel));
        avm.expectPartialRevert(T.Replay.selector);
        ingress.revokeArtistAuthorization(target, cancel);
        a.nonce = 41;
        digest = ingress.economicsConsentDigest(p, a);
        target.revokedDigest = digest;
        cancel.signature = _signature(ingress.authorizationRevocationDigest(target, cancel));
        ingress.revokeArtistAuthorization(target, cancel);
        bytes32 before_ = _roots();
        bytes32 denyKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                address(ingress),
                address(coordinator),
                address(archive),
                suite.owners[2],
                keccak256("domain:identity_authority"),
                keccak256("identity_authority.replay.digest_revocation"),
                keccak256(abi.encode(artistId, digest))
            )
        );
        a.signature = _delegateSignature(digest);
        vm.expectRevert(abi.encodeWithSelector(T.Replay.selector, denyKey));
        ingress.recordDelegatedEconomicsConsent(p, firstGrant, a);
        a.signature =
            safeThresholdSignature(otherKeys, safeMessageDigest(other, abi.encode(digest)));
        vm.expectRevert(abi.encodeWithSelector(T.Replay.selector, denyKey));
        ingress.recordDelegatedEconomicsConsent(p, secondGrant, a);
        (bool used,) = ingress.delegatedNonceState(artistId, address(delegateSafe), 41);
        require(
            !used && _roots() == before_ && ingress.delegationRecord(firstGrant).uses == 1
                && ingress.delegationRecord(secondGrant).uses == 1,
            "deny does not consume delegate nonce or grant use"
        );
    }

    function _consumeDelegateIdentityOnly(
        T.EconomicsConsent memory p,
        T.Authorization memory a,
        bytes32 grant,
        address signer,
        bytes32 digest
    ) private returns (bytes32) {
        require(
            StreamArtistRegistryValidatorBase(suite.validator)
                .validateSignerProof(signer, digest, a.signature, 150_000),
            "actual second Safe proof"
        );
        T.Binding memory binding_ = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        (, bytes32 designation) = ingress.artistPayoutAccount(artistId);
        T.ActionContext memory c = T.ActionContext(
            15, address(this), IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2()
        );
        T.SignerApproval memory proof = T.SignerApproval(signer, digest, false);
        vm.prank(address(coordinator));
        return IStreamArtistDelegationOwner(suite.owners[2])
            .consumeDelegatedEconomics(c, binding_, p, designation, grant, a, proof);
    }

    function testCurrentTemplateSupplementaryTermsAndCanonicalRecordAreBothReconstructable()
        public
    {
        _freshTemplateFixture(1);
        _accept();
        _payout();
        (T.AssignmentFact memory fact,) = coordinator.reads().currentAssignments(1);
        (bytes32 entriesHash, bytes32 metadataHash, uint32 share) = IStreamArtistPrimaryTemplateFacts(
                address(primary)
            ).primaryTemplateEconomicsFacts(templateFixtureId);
        bytes memory evidence =
            coordinator.reads().requireCurrentArtistEconomics(1, address(primary), address(artist));
        require(
            keccak256(evidence)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CURRENT_PRIMARY_TEMPLATE_ECONOMICS_EVIDENCE_V1"),
                        templateFixtureId,
                        entriesHash,
                        metadataHash,
                        share
                    )
                ),
            "actual immutable template facts"
        );
        T.EconomicsConsent memory p = T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
        (, bytes32 designation) = ingress.artistPayoutAccount(artistId);
        bytes32 expected = StreamArtistEconomicsHashes.economicsRecord(
            StreamArtistHashes.Environment(
                block.chainid, address(ingress), suite.core, suite.mintManager
            ),
            p,
            designation,
            artistId,
            address(artist),
            a.nonce,
            uint64(block.timestamp)
        );
        this.executeTargetSafe(
            address(coordinator.reads()),
            abi.encodeCall(
                StreamArtistOnboardingReads.requireCurrentArtistEconomics,
                (1, address(primary), address(artist))
            )
        );
        a.signature = "";
        this.executeTargetSafe(
            address(ingress), abi.encodeCall(IStreamArtistOnboarding.recordEconomicsConsent, (p, a))
        );
        require(
            IStreamArtistConsentOwner(suite.owners[6]).economicsRecord(p) == expected,
            "direct Safe unchanged canonical op15 record"
        );
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
        bytes32 before_ = _roots();
        avm.expectPartialRevert(T.Replay.selector);
        ingress.recordEconomicsConsent(p, a);
        require(_roots() == before_, "same replay lane");
        StreamArtistOnboardingReads reads = coordinator.reads();
        avm.expectRevert(T.UnsupportedProfile.selector);
        reads.requireStaticArtistPayout(1, address(primary), address(artist));
        avm.expectPartialRevert(T.MissingMintPrerequisite.selector);
        reads.requireCurrentArtistEconomics(1, address(primary), address(0xBAD));
    }

    function testCurrentTemplateAllowsExplicitUnpaidCollaborator() public {
        _freshTemplateFixture(1);
        _collaboratorIdentity(false);
        C.BindingAcceptance memory row = _collaborativeProposal(false);
        _accept();
        _collaboratorAcceptance(row, false);
        _policy();
        _payout();
        _economics();
        _ratify();
        _attestations();
        ingress.requireMintConsent(1, PHASE, POLICY);
    }

    function testCurrentTemplateDelegatedSafeConsentKeepsPrincipalReplayAndLivenessSeparate()
        public
    {
        _freshTemplateFixture(1);
        _accept();
        _payout();
        _delegateSetup();
        bytes32 grant = _grant(_delegation(1, 4, 1000, 2000, 1));
        T.Identity memory before_ = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        (T.AssignmentFact memory fact,) = coordinator.reads().currentAssignments(1);
        T.EconomicsConsent memory p = T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
        vm.warp(1100);
        bytes32 record = _delegateEconomics(p, grant, 0);
        T.Identity memory after_ = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        require(
            ingress.recordDelegation(record) == grant && ingress.delegationRecord(grant).uses == 1,
            "actual template consent carries consumed grant witness"
        );
        require(
            before_.nonceHint == after_.nonceHint
                && before_.lastAuthorityActionAt == after_.lastAuthorityActionAt,
            "delegate template consent does not become a principal action"
        );
    }

    function testCurrentTemplateRejectsPaidCollaboratorWithoutConsumingConsentNonce() public {
        _freshTemplateFixture(1);
        _collaboratorIdentity(false);
        C.BindingAcceptance memory row = _collaborativeProposal(true);
        _accept();
        _collaboratorAcceptance(row, false);
        _payout();
        _collaboratorPayout(address(delegateSafe));
        (T.AssignmentFact memory fact,) = coordinator.reads().currentAssignments(1);
        T.EconomicsConsent memory p = T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
        bytes32 before_ = _roots();
        avm.expectRevert(T.UnsupportedProfile.selector);
        ingress.recordEconomicsConsent(p, a);
        require(
            _roots() == before_
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "paid collaborator never silently omitted"
        );
    }

    function testCurrentTemplateRejectsUnsupportedSalePosterStaticArtistAndBelowFloor() public {
        for (uint8 kind = 2; kind <= 4; ++kind) {
            _freshTemplateFixture(kind);
            _accept();
            _payout();
            StreamArtistOnboardingReads reads = coordinator.reads();
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamArtistPrimaryTemplateFacts.UnsupportedArtistPrimaryTemplate.selector,
                    templateFixtureId
                )
            );
            reads.requireCurrentArtistEconomics(1, address(primary), address(artist));
        }
    }

    function testCurrentTemplateCannotBecomeFixedProspectiveCandidateOrAuthorizeReplacement()
        public
    {
        _freshTemplateFixture(1);
        _all();
        (T.AssignmentFact memory fact,) = coordinator.reads().currentAssignments(1);
        T.EconomicsConsent memory p = T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
        T.FixedEconomicsCandidate memory candidate =
            T.FixedEconomicsCandidate(templateFixtureId, bytes32(0), 0, false);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
        bytes32 before_ = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.UnverifiedSplitProfile.selector, templateFixtureId
            )
        );
        ingress.recordProspectiveEconomicsConsent(p, candidate, a);
        require(_roots() == before_, "template ID not a fixed profile alias");
        address governor = primary.owner();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.PrimaryArtistConsentRequired.selector, uint256(1)
            )
        );
        vm.prank(governor);
        primary.setPrimaryTemplateAssignment(PRIMARY, 1, 1, templateFixtureId, bytes32(0));
    }

    function _collaboratorIdentity(bool direct) private {
        _delegateSetup();
        bytes memory document = bytes("collaborator unit document");
        C.IdentityProposal memory p = C.IdentityProposal(
            address(delegateSafe),
            keccak256(document),
            "urn:collaborator:identity",
            keccak256("collaborator registration"),
            "urn:collaborator:reason"
        );
        ingress.proposeCollaboratorIdentity(p);
        T.Authorization memory a = T.Authorization(0, 2000, "");
        if (direct) {
            require(
                executeSafe(
                    delegateSafe,
                    delegateKeys,
                    address(ingress),
                    0,
                    abi.encodeCall(
                        IStreamArtistCollaboratorLifecycle.acceptCollaboratorIdentity,
                        (p.account, p.identityRecordHash, a, document, "Collaborator Safe")
                    ),
                    0
                ),
                "direct Safe identity"
            );
            collaboratorId = IStreamArtistIdentityOwner(suite.owners[2]).activeIdentity(p.account);
        } else {
            a.signature = safeThresholdSignature(
                delegateKeys,
                safeMessageDigest(
                    delegateSafe,
                    abi.encode(
                        ingress.collaboratorIdentityDigest(p.account, p.identityRecordHash, a)
                    )
                )
            );
            collaboratorId = ingress.acceptCollaboratorIdentity(
                p.account, p.identityRecordHash, a, document, "Collaborator Safe"
            );
        }
        require(collaboratorId != bytes32(0), "real collaborator identity");
    }

    function _collaborativeProposal(bool paid) private returns (C.BindingAcceptance memory p) {
        ingress.withdrawArtistBinding(_termination(1));
        T.BindingProposal memory proposal = _proposal(artistId);
        proposal.collaborators = new T.CollaboratorRecord[](1);
        proposal.collaborators[0] = T.CollaboratorRecord(
            address(delegateSafe),
            keccak256("composer"),
            paid ? keccak256("composer-share") : bytes32(0)
        );
        ingress.proposeArtistBinding(1, proposal, bytes("unit identity document"), "Artist Safe");
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        p = C.BindingAcceptance(
            1,
            b.generation,
            b.bindingHash,
            address(delegateSafe),
            proposal.collaborators[0].role,
            proposal.collaborators[0].shareLabelId
        );
    }

    function _collaboratorAcceptance(C.BindingAcceptance memory p, bool direct)
        private
        returns (bytes32 record)
    {
        uint256 nonce =
            IStreamArtistIdentityOwner(suite.owners[2]).identity(collaboratorId).nonceHint;
        T.Authorization memory a = T.Authorization(nonce, 2000, "");
        if (direct) {
            require(
                executeSafe(
                    delegateSafe,
                    delegateKeys,
                    address(ingress),
                    0,
                    abi.encodeCall(IStreamArtistCollaboratorLifecycle.acceptCollaborator, (p, a)),
                    0
                ),
                "direct Safe row"
            );
            record = ingress.collaboratorAt(p.collectionId, p.generation, 0).acceptanceRecordHash;
        } else {
            a.signature = safeThresholdSignature(
                delegateKeys,
                safeMessageDigest(
                    delegateSafe, abi.encode(ingress.collaboratorAcceptanceDigest(p, a))
                )
            );
            record = ingress.acceptCollaborator(p, a);
        }
    }

    function testCollaboratorSafeIdentityIsTwoSidedAndConsumesBothNonceLanes() public {
        uint256 before_ = IStreamArtistIdentityOwner(suite.owners[2]).nextRegistrationNonce();
        _collaboratorIdentity(true);
        require(
            collaboratorId
                == StreamArtistHashes.identity(
                    StreamArtistHashes.Environment(
                        block.chainid, address(ingress), suite.core, suite.mintManager
                    ),
                    address(delegateSafe),
                    keccak256("collaborator unit document"),
                    before_
                ),
            "permanent identity allocation"
        );
        (bool used, uint256 hint) =
            ingress.collaboratorRegistrationNonceState(address(delegateSafe), 0);
        require(
            used && hint == 1
                && IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(collaboratorId, 0),
            "both persistent nonce lanes"
        );
        require(
            !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, 0),
            "primary nonce isolated"
        );
        C.IdentityProposalState memory proposal = ingress.collaboratorIdentityProposal(
            address(delegateSafe), keccak256("collaborator unit document")
        );
        require(proposal.acceptedArtistId == collaboratorId, "proposal completed");
        require(
            keccak256(
                IStreamArtistIdentityOwner(suite.owners[2])
                    .identityDocumentBytes(proposal.proposal.identityRecordHash)
            ) == proposal.proposal.identityRecordHash,
            "actual stored identity bytes"
        );
        vm.expectRevert(
            abi.encodeWithSelector(T.AddressAlreadyRegistered.selector, address(delegateSafe))
        );
        ingress.proposeCollaboratorIdentity(proposal.proposal);
    }

    function testCollaboratorPrimaryFirstStaysClaimedUntilLastSafeAcceptance() public {
        _collaboratorIdentity(false);
        C.BindingAcceptance memory p = _collaborativeProposal(false);
        _accept();
        (uint8 state,) = IStreamArtistAttributionOwner(suite.owners[4]).attributionState(1);
        require(
            state == 1 && ingress.acceptedArtist(1) == address(0), "partial primary remains claimed"
        );
        require(_closed(_mintCall()), "partial cannot mint");
        IStreamCollectionArtistRegistry.Attribution memory evidence = ingress.attribution(1);
        require(
            evidence.artist == address(0) && evidence.acceptanceHash != bytes32(0)
                && evidence.acceptedAt == 1000,
            "partial primary acceptance evidence is not readiness"
        );
        T.Snapshot memory bindingBefore = IStreamArtistOwner(suite.owners[0]).ownerStateSnapshotV2();
        vm.warp(1100);
        _collaboratorAcceptance(p, true);
        require(ingress.acceptedArtist(1) == address(artist), "all parties accepted");
        IStreamCollectionArtistRegistry.Attribution memory completed = ingress.attribution(1);
        require(
            completed.artist == address(artist)
                && completed.acceptanceHash == evidence.acceptanceHash
                && completed.acceptedAt == 1000 && completed.acceptedAt != block.timestamp,
            "primary hash and time remain one event after later completion"
        );
        require(
            IStreamArtistOwner(suite.owners[0]).ownerStateSnapshotV2().revision
                == bindingBefore.revision + 1,
            "one final binding transition"
        );
        C.Row memory row = ingress.collaboratorAt(1, p.generation, 0);
        require(
            row.accepted && row.collaboratorArtistId == collaboratorId
                && row.shareLabelId == bytes32(0),
            "permanent accepted join"
        );
        _policy();
        _payout();
        _economics();
        _ratify();
        _attestations();
        ingress.requireMintConsent(1, PHASE, POLICY);
    }

    function testCollaboratorFirstLeavesBindingAndAttributionReadOnlyUntilPrimary() public {
        _collaboratorIdentity(false);
        C.BindingAcceptance memory p = _collaborativeProposal(false);
        T.Snapshot memory bindingBefore = IStreamArtistOwner(suite.owners[0]).ownerStateSnapshotV2();
        T.Snapshot memory attributionBefore =
            IStreamArtistOwner(suite.owners[4]).ownerStateSnapshotV2();
        _collaboratorAcceptance(p, false);
        require(
            keccak256(abi.encode(bindingBefore))
                == keccak256(
                    abi.encode(IStreamArtistOwner(suite.owners[0]).ownerStateSnapshotV2())
                ),
            "incomplete Binding unchanged"
        );
        require(
            keccak256(abi.encode(attributionBefore))
                == keccak256(
                    abi.encode(IStreamArtistOwner(suite.owners[4]).ownerStateSnapshotV2())
                ),
            "incomplete Attribution unchanged"
        );
        require(ingress.acceptedArtist(1) == address(0), "primary still absent");
        _accept();
        require(ingress.acceptedArtist(1) == address(artist), "primary completes set");
    }

    function testCollaboratorPartialPrimaryCanWithdrawButPriorEvidenceCannotCompleteReplacement()
        public
    {
        _collaboratorIdentity(false);
        C.BindingAcceptance memory old = _collaborativeProposal(false);
        _accept();
        bytes32 primaryRecord =
            IStreamArtistAcceptanceOwner(suite.owners[3]).acceptanceRecord(old.bindingHash);
        ingress.withdrawArtistBinding(_termination(1));
        require(
            primaryRecord != bytes32(0)
                && IStreamArtistAcceptanceOwner(suite.owners[3]).acceptanceRecord(old.bindingHash)
                    == primaryRecord,
            "partial evidence preserved"
        );
        T.BindingProposal memory proposal = _proposal(artistId);
        proposal.collaborators = new T.CollaboratorRecord[](1);
        proposal.collaborators[0] = T.CollaboratorRecord(old.account, old.role, old.shareLabelId);
        ingress.proposeArtistBinding(1, proposal, bytes("unit identity document"), "Artist Safe");
        T.Authorization memory a = T.Authorization(1, 2000, "");
        a.signature = safeThresholdSignature(
            delegateKeys,
            safeMessageDigest(
                delegateSafe, abi.encode(ingress.collaboratorAcceptanceDigest(old, a))
            )
        );
        bytes32 before_ = _roots();
        vm.expectRevert(abi.encodeWithSelector(T.InvalidAttribution.selector, uint256(1)));
        ingress.acceptCollaborator(old, a);
        require(
            _roots() == before_ && !ingress.collaboratorAt(1, 3, 0).accepted,
            "stale row cannot migrate"
        );
    }

    function testCollaboratorPaidLabelNeedsExplicitDesignationAndMatchingActualProfile() public {
        _collaboratorIdentity(false);
        C.BindingAcceptance memory p = _collaborativeProposal(true);
        _accept();
        _collaboratorAcceptance(p, false);
        _payout();
        (T.AssignmentFact memory fact,) = coordinator.reads().currentAssignments(1);
        T.EconomicsConsent memory consent = T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(consent, a));
        vm.expectRevert(
            abi.encodeWithSelector(
                T.MissingMintPrerequisite.selector, keccak256("collaborator_payout")
            )
        );
        ingress.recordEconomicsConsent(consent, a);
        T.PayoutDesignation memory payout =
            T.PayoutDesignation(collaboratorId, address(delegateSafe), bytes32(0));
        T.Authorization memory ca = T.Authorization(2, 1000, "");
        ca.signature = safeThresholdSignature(
            delegateKeys,
            safeMessageDigest(delegateSafe, abi.encode(ingress.payoutDesignationDigest(payout, ca)))
        );
        ingress.recordPayoutDesignation(payout, ca);
        (address account, bytes32 record) =
            ingress.collaboratorPayoutAccount(collaboratorId, address(delegateSafe));
        require(account == address(delegateSafe) && record != bytes32(0), "typed payout joined");
        (account, record) = ingress.collaboratorPayoutAccount(artistId, address(delegateSafe));
        require(
            account == address(0) && record == bytes32(0), "wrong identity has no acceptance link"
        );
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        ingress.recordEconomicsConsent(consent, a);
    }

    function _collaboratorPayout(address account) private {
        (, bytes32 previous) = ingress.artistPayoutAccount(collaboratorId);
        T.PayoutDesignation memory p = T.PayoutDesignation(collaboratorId, account, previous);
        T.Authorization memory a = T.Authorization(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(collaboratorId).nonceHint, 1000, ""
        );
        a.signature = safeThresholdSignature(
            delegateKeys,
            safeMessageDigest(delegateSafe, abi.encode(ingress.payoutDesignationDigest(p, a)))
        );
        ingress.recordPayoutDesignation(p, a);
    }

    function _collaboratorCandidate(address resolver, address collaboratorAccount)
        private
        returns (T.EconomicsConsent memory p, T.FixedEconomicsCandidate memory candidate)
    {
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](3);
        entries[0] = IStreamSplitWallet.SplitEntry(address(artist), 700_000, keccak256("artist"));
        entries[1] = IStreamSplitWallet.SplitEntry(
            collaboratorAccount, 200_000, keccak256("composer-share")
        );
        entries[2] = IStreamSplitWallet.SplitEntry(address(0xFEE), 100_000, keccak256("protocol"));
        IStreamSplitFactory selected =
            resolver == address(primary) ? IStreamSplitFactory(factory) : royalty.splitFactory();
        (bytes32 profile,) = selected.createProfile(
            entries, keccak256(abi.encode("collaborator profile", collaboratorAccount))
        );
        candidate = T.FixedEconomicsCandidate(
            profile, bytes32(0), resolver == address(primary) ? 0 : 500, false
        );
        T.AssignmentFact memory fact = resolver == address(primary)
            ? IStreamArtistPrimaryFacts(resolver)
                .previewArtistPrimaryAssignment(1, profile, bytes32(0), false)
            : IStreamArtistRoyaltyPreview(resolver)
                .previewArtistRoyaltyAssignment(1, profile, 500, false);
        p = T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
    }

    function testCollaboratorRealProfilesConsentAndOldWalletSurvivePayoutRevision() public {
        _collaboratorIdentity(false);
        C.BindingAcceptance memory row = _collaborativeProposal(true);
        _accept();
        _collaboratorAcceptance(row, false);
        _payout();
        _collaboratorPayout(address(delegateSafe));
        (T.EconomicsConsent memory p, T.FixedEconomicsCandidate memory candidate) =
            _collaboratorCandidate(address(primary), address(delegateSafe));
        _prospectiveConsent(p, candidate);
        vm.prank(primary.owner());
        primary.setPrimaryProfileAssignment(PRIMARY, 1, 1, candidate.profileHash, bytes32(0));
        address wallet = factory.walletFor(candidate.profileHash);
        (p, candidate) = _collaboratorCandidate(address(royalty), address(delegateSafe));
        _prospectiveConsent(p, candidate);
        vm.prank(royalty.owner());
        royalty.configureCollectionRoyalty(1, candidate.profileHash, 500);
        _policy();
        _ratify();
        _attestations();
        ingress.requireMintConsent(1, PHASE, POLICY);
        _collaboratorPayout(address(0xCAFE));
        ingress.requireMintConsent(1, PHASE, POLICY);
        vm.deal(address(this), 1 ether);
        (bool sent,) = wallet.call{ value: 1 ether }("");
        require(sent, "fund real fixed wallet");
        uint256 before_ = address(delegateSafe).balance;
        IStreamSplitWallet(wallet)
            .release(address(0), address(delegateSafe), payable(address(delegateSafe)));
        require(
            address(delegateSafe).balance == before_ + 0.2 ether
                && IStreamSplitWallet(wallet).aggregateSharePpm(address(0xCAFE)) == 0,
            "old collaborator immutable account still paid"
        );
        (p, candidate) = _collaboratorCandidate(address(primary), address(delegateSafe));
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.recordProspectiveEconomicsConsent(p, candidate, a);
        (p, candidate) = _collaboratorCandidate(address(primary), address(0xCAFE));
        _prospectiveConsent(p, candidate);
    }

    function testCollaboratorIdentityBadSafeProofAndLateArchiveFailureLeaveBothLanesUnused()
        public
    {
        _delegateSetup();
        bytes memory doc = bytes("collaborator negative identity");
        C.IdentityProposal memory p = C.IdentityProposal(
            address(delegateSafe), keccak256(doc), "urn:negative", keccak256("reason"), "urn:reason"
        );
        ArtistUnitRoles(suite.roleRegistry).setAdmin(address(artist), true);
        this.executeTargetSafe(
            address(ingress),
            abi.encodeCall(IStreamArtistCollaboratorLifecycle.proposeCollaboratorIdentity, (p))
        );
        T.Authorization memory a = T.Authorization(0, 2000, "");
        bytes32 digest = ingress.collaboratorIdentityDigest(p.account, p.identityRecordHash, a);
        a.signature = safeThresholdSignature(delegateKeys, digest); // Deliberately omits actual SafeMessage domain.
        bytes32 before_ = _roots();
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.acceptCollaboratorIdentity(p.account, p.identityRecordHash, a, doc, "Collaborator");
        require(_roots() == before_, "wrong domain no owner mutation");
        a.signature = safeThresholdSignature(
            delegateKeys, safeMessageDigest(delegateSafe, abi.encode(digest))
        );
        avm.mockCallRevert(
            address(archive),
            abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(T.InvalidRecord.selector)
        );
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.acceptCollaboratorIdentity(p.account, p.identityRecordHash, a, doc, "Collaborator");
        (bool used, uint256 hint) = ingress.collaboratorRegistrationNonceState(p.account, 0);
        require(
            _roots() == before_ && !used && hint == 0
                && IStreamArtistIdentityOwner(suite.owners[2]).activeIdentity(p.account)
                    == bytes32(0),
            "late archive registration rollback"
        );
        avm.clearMockedCalls();
        require(
            ingress.acceptCollaboratorIdentity(
                p.account, p.identityRecordHash, a, doc, "Collaborator"
            ) != bytes32(0),
            "exact retry after failure"
        );
    }

    function testCollaboratorRowExactEventAndLateArchiveRollbackThenReplayRejection() public {
        _collaboratorIdentity(false);
        C.BindingAcceptance memory p = _collaborativeProposal(false);
        _accept();
        T.Authorization memory a = T.Authorization(1, 2000, "");
        a.signature = safeThresholdSignature(
            delegateKeys,
            safeMessageDigest(delegateSafe, abi.encode(ingress.collaboratorAcceptanceDigest(p, a)))
        );
        bytes32 before_ = _roots();
        avm.mockCallRevert(
            address(archive),
            abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(T.InvalidRecord.selector)
        );
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.acceptCollaborator(p, a);
        require(
            _roots() == before_ && !ingress.collaboratorAt(1, p.generation, 0).accepted
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(collaboratorId, 1),
            "final transition atomically rolled back"
        );
        avm.clearMockedCalls();
        vm.recordLogs();
        bytes32 record = ingress.acceptCollaborator(p, a);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool found;
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ACCEPTANCE_RECORD_V1"),
                block.chainid,
                address(ingress),
                address(core),
                uint256(1),
                p.generation,
                p.bindingHash,
                uint8(2),
                p.account,
                uint8(1),
                a.nonce,
                uint64(1000)
            )
        );
        require(record == expected, "canonical kind2 acceptance record");
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == suite.owners[3]
                    && logs[i].topics[0]
                        == keccak256(
                            "CollaboratorAccepted(uint16,uint256,address,bytes32,uint64,bytes32,bytes32,uint8,uint256,uint64,bytes32,bytes32)"
                        )
            ) {
                require(
                    logs[i].topics[1] == bytes32(uint256(1))
                        && logs[i].topics[2] == bytes32(uint256(uint160(p.account)))
                        && logs[i].topics[3] == collaboratorId,
                    "canonical collaborator topics"
                );
                require(
                    keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                p.generation,
                                p.role,
                                p.shareLabelId,
                                uint8(1),
                                uint256(1),
                                uint64(1000),
                                record,
                                p.bindingHash
                            )
                        ),
                    "canonical collaborator event body"
                );
                found = true;
            }
        }
        require(found, "Acceptance owner emitted exact event");
        before_ = _roots();
        vm.expectRevert(abi.encodeWithSelector(T.InvalidAttribution.selector, uint256(1)));
        ingress.acceptCollaborator(p, a);
        require(_roots() == before_, "accepted generation cannot replay");
    }

    function testCollaboratorPartialRowCanBeRefusedAndNeverUnlocksProviders() public {
        _collaboratorIdentity(false);
        C.BindingAcceptance memory p = _collaborativeProposal(false);
        _collaboratorAcceptance(p, false);
        L.Termination memory termination = _termination(1);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.bindingRefusalDigest(termination, a));
        ingress.refuseArtistBinding(termination, a);
        require(
            ingress.collaboratorAt(1, p.generation, 0).accepted
                && ingress.acceptedArtist(1) == address(0),
            "partial row evidence survives refusal"
        );
        address governor = primary.owner();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.PrimaryArtistConsentRequired.selector, uint256(1)
            )
        );
        vm.prank(governor);
        primary.clearPrimaryAssignment(PRIMARY, 1, 1);
    }

    function testCollaboratorRejectsUnsortedDuplicateAndOverBoundTermsAtomically() public {
        _delegateSetup();
        ingress.withdrawArtistBinding(_termination(1));
        T.BindingProposal memory p = _proposal(artistId);
        p.collaborators = new T.CollaboratorRecord[](2);
        p.collaborators[0] =
            T.CollaboratorRecord(address(delegateSafe), bytes32(uint256(2)), bytes32(0));
        p.collaborators[1] =
            T.CollaboratorRecord(address(delegateSafe), bytes32(uint256(1)), bytes32(0));
        bytes32 before_ = _roots();
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.proposeArtistBinding(1, p, bytes("unit identity document"), "Artist Safe");
        p.collaborators[1] = T.CollaboratorRecord(
            address(delegateSafe), bytes32(uint256(2)), keccak256("different label same pair")
        );
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.proposeArtistBinding(1, p, bytes("unit identity document"), "Artist Safe");
        p.collaborators = new T.CollaboratorRecord[](33);
        vm.expectRevert(abi.encodeWithSelector(T.BoundExceeded.selector, uint256(33), uint256(32)));
        ingress.proposeArtistBinding(1, p, bytes("unit identity document"), "Artist Safe");
        require(_roots() == before_, "invalid sets leave all owner roots unchanged");
    }

    function testCollaboratorThirtyTwoRolesCompleteExactlyOnce() public {
        _collaboratorIdentity(false);
        ingress.withdrawArtistBinding(_termination(1));
        T.BindingProposal memory p = _proposal(artistId);
        p.collaborators = new T.CollaboratorRecord[](32);
        for (uint256 i; i < 32; ++i) {
            p.collaborators[i] =
                T.CollaboratorRecord(address(delegateSafe), bytes32(i + 1), bytes32(i + 1));
        }
        ingress.proposeArtistBinding(1, p, bytes("unit identity document"), "Artist Safe");
        _accept();
        T.Binding memory binding_ = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        C.BindingTerms memory terms = IStreamArtistCollaboratorBindingOwner(suite.owners[0])
            .bindingTerms(1, binding_.generation);
        require(
            terms.count == 32
                && terms.collaboratorSetHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_COLLABORATOR_SET_V1"), p.collaborators
                        )
                    ),
            "exact sorted array commitment"
        );
        uint64 before_ = IStreamArtistOwner(suite.owners[0]).ownerStateSnapshotV2().revision;
        for (uint256 i; i < 32; ++i) {
            C.BindingAcceptance memory row = C.BindingAcceptance(
                1,
                binding_.generation,
                binding_.bindingHash,
                address(delegateSafe),
                bytes32(i + 1),
                bytes32(i + 1)
            );
            _collaboratorAcceptance(row, false);
            require(
                (ingress.acceptedArtist(1) != address(0)) == (i == 31),
                "only final required row changes attribution"
            );
            require(
                ingress.collaboratorAt(1, binding_.generation, i).accepted, "row joined exact index"
            );
        }
        require(
            IStreamArtistOwner(suite.owners[0]).ownerStateSnapshotV2().revision == before_ + 1,
            "one completion for32 roles"
        );
        _payout();
        _collaboratorPayout(address(delegateSafe));
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](64);
        entries[0] = IStreamSplitWallet.SplitEntry(address(artist), 649_000, keccak256("artist"));
        for (uint256 i; i < 32; ++i) {
            entries[i + 1] =
                IStreamSplitWallet.SplitEntry(address(delegateSafe), 10_000, bytes32(i + 1));
        }
        for (uint256 i; i < 31; ++i) {
            entries[i + 33] = IStreamSplitWallet.SplitEntry(address(0xFEE), 1000, bytes32(i + 1000));
        }
        (bytes32 profile,) =
            factory.createProfile(entries, keccak256("maximum supported collaborator profile"));
        T.AssignmentFact memory fact = IStreamArtistPrimaryFacts(address(primary))
            .previewArtistPrimaryAssignment(1, profile, bytes32(0), false);
        T.EconomicsConsent memory consent = T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
        T.FixedEconomicsCandidate memory candidate =
            T.FixedEconomicsCandidate(profile, bytes32(0), 0, false);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(consent, a));
        uint256 start = gasleft();
        ingress.recordProspectiveEconomicsConsent(consent, candidate, a);
        uint256 consumed = start - gasleft();
        emit CollaboratorBoundMeasurement(32, 64, consumed);
        require(
            consumed < 16_777_216,
            "bounded unit observation; separate fresh-transaction gas admission still required"
        );
    }

    function testCollaboratorAccountReplaySurvivesSimulatedFutureIdentityReuse() public {
        ArtistCollaboratorAccountReplayHarness harness =
            new ArtistCollaboratorAccountReplayHarness();
        address account = address(0xA77157);
        bytes32 first = harness.allocate(account, 0, true);
        harness.simulateCompletedRotation(account);
        avm.expectPartialRevert(T.Replay.selector);
        harness.allocate(account, 0, false);
        (bool used, uint256 hint, uint256 next, bytes32 active) = harness.facts(account, 0);
        require(
            used && hint == 1 && next == 1 && active == bytes32(0),
            "old payload cannot allocate new identity after account reuse"
        );
        bytes32 second = harness.allocate(account, 1, true);
        require(second != first, "new nonce permits separate allocation");
        harness.simulateCompletedRotation(account);
        harness.allocate(account, type(uint256).max, false);
        (used, hint, next,) = harness.facts(account, type(uint256).max);
        require(used && hint == 2 && next == 3, "sparse maximum nonce leaves bounded direct hint");
    }

    function testCollaboratorApprovedEmptySafeProofWorksWithoutGivingOwnersTheSafeRole() public {
        _delegateSetup();
        bytes memory doc = bytes("approved empty collaborator");
        C.IdentityProposal memory p = C.IdentityProposal(
            address(delegateSafe), keccak256(doc), "urn:approved", keccak256("reason"), "urn:reason"
        );
        ingress.proposeCollaboratorIdentity(p);
        T.Authorization memory a = T.Authorization(0, 2000, "");
        bytes32 digest = ingress.collaboratorIdentityDigest(p.account, p.identityRecordHash, a);
        bytes32 before_ = _roots();
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.acceptCollaboratorIdentity(p.account, p.identityRecordHash, a, doc, "Collaborator");
        vm.prank(vm.addr(delegateKeys[0]));
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.acceptCollaboratorIdentity(p.account, p.identityRecordHash, a, doc, "Collaborator");
        require(_roots() == before_, "Safe owner and unapproved empty relay cannot register");
        require(
            executeSafe(
                delegateSafe,
                delegateKeys,
                safeComponents.signMessage,
                0,
                abi.encodeWithSignature("signMessage(bytes)", abi.encode(digest)),
                1
            ),
            "Safe approves identity message"
        );
        collaboratorId = ingress.acceptCollaboratorIdentity(
            p.account, p.identityRecordHash, a, doc, "Collaborator"
        );
        C.BindingAcceptance memory row = _collaborativeProposal(false);
        a.nonce = 1;
        digest = ingress.collaboratorAcceptanceDigest(row, a);
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.acceptCollaborator(row, a);
        require(
            executeSafe(
                delegateSafe,
                delegateKeys,
                safeComponents.signMessage,
                0,
                abi.encodeWithSignature("signMessage(bytes)", abi.encode(digest)),
                1
            ),
            "Safe approves row message"
        );
        ingress.acceptCollaborator(row, a);
        require(
            ingress.collaboratorAt(1, row.generation, 0).accepted, "approved empty row recorded"
        );
    }

    function testCollaboratorEoaIdentityAcceptsUnorderedNonceButRejectsWrongKey() public {
        uint256 key = 0xC011AB;
        address account = vm.addr(key);
        bytes memory doc = bytes("EOA collaborator");
        C.IdentityProposal memory p = C.IdentityProposal(
            account, keccak256(doc), "urn:eoa", keccak256("reason"), "urn:reason"
        );
        ingress.proposeCollaboratorIdentity(p);
        T.Authorization memory a = T.Authorization(91, 2000, "");
        bytes32 digest = ingress.collaboratorIdentityDigest(account, p.identityRecordHash, a);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xBAD, digest);
        a.signature = abi.encodePacked(r, s, v);
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.acceptCollaboratorIdentity(
            account, p.identityRecordHash, a, doc, "EOA Collaborator"
        );
        (v, r, s) = vm.sign(key, digest);
        a.signature = abi.encodePacked(r, s, v);
        bytes32 id = ingress.acceptCollaboratorIdentity(
            account, p.identityRecordHash, a, doc, "EOA Collaborator"
        );
        (bool used, uint256 hint) = ingress.collaboratorRegistrationNonceState(account, 91);
        require(
            used && hint == 0 && IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(id, 91)
                && IStreamArtistIdentityOwner(suite.owners[2]).identity(id).nonceHint == 0,
            "unordered91 consumed in both lanes, lowest hint0"
        );
    }

    function _termination(uint256 collectionId) private view returns (L.Termination memory p) {
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(collectionId);
        p = L.Termination(
            collectionId,
            b.generation,
            b.bindingHash,
            keccak256("incorrect proposed terms"),
            "urn:binding:reason"
        );
    }

    function _repropose(uint256 collectionId) private {
        ingress.proposeArtistBinding(
            collectionId, _proposal(artistId), bytes("unit identity document"), "Artist Safe"
        );
    }

    function testBindingRefusalSafeSignatureCanonicalRecordAndEvents() public {
        L.Termination memory p = _termination(1);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.bindingRefusalDigest(p, a));
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_BINDING_REFUSAL_RECORD_V1"),
                block.chainid,
                address(ingress),
                suite.core,
                uint256(1),
                p.generation,
                p.bindingHash,
                artistId,
                address(artist),
                uint8(1),
                p.reasonHash,
                a.nonce,
                uint64(1000)
            )
        );
        vm.recordLogs();
        require(ingress.refuseArtistBinding(p, a) == expected, "canonical refusal record");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool contextFound;
        bool stateFound;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != suite.owners[4]) continue;
            if (
                logs[i].topics[0]
                    == keccak256(
                        "ArtistBindingTerminationContext(uint16,uint256,uint64,bytes32,bytes32,bytes32,address,uint256,uint64)"
                    )
            ) {
                require(
                    logs[i].topics[1] == bytes32(uint256(1))
                        && logs[i].topics[2] == bytes32(uint256(1))
                        && logs[i].topics[3] == expected,
                    "refusal context topics"
                );
                (
                    uint16 schema,
                    bytes32 bh,
                    bytes32 id,
                    address signer,
                    uint256 nonce,
                    uint64 observed
                ) = abi.decode(logs[i].data, (uint16, bytes32, bytes32, address, uint256, uint64));
                require(
                    schema == 1 && bh == p.bindingHash && id == artistId
                        && signer == address(artist) && nonce == a.nonce && observed == 1000
                        && observed != a.time,
                    "exact refusal context"
                );
                contextFound = true;
            }
            if (
                logs[i].topics[0]
                    == keccak256(
                        "ArtistAttributionStateChanged(uint16,uint256,uint8,uint64,uint8,address,uint8,bytes32,bytes32,string)"
                    )
            ) {
                (
                    uint16 schema,
                    uint64 generation,
                    uint8 old,
                    address actor,
                    uint8 auth,
                    bytes32 record,
                    bytes32 reason,
                    string memory uri
                ) = abi.decode(
                    logs[i].data, (uint16, uint64, uint8, address, uint8, bytes32, bytes32, string)
                );
                require(
                    schema == 1 && generation == 1 && old == 1 && actor == address(this)
                        && auth == 1 && record == expected && reason == p.reasonHash
                        && keccak256(bytes(uri)) == keccak256(bytes(p.reasonURI)),
                    "state event record"
                );
                stateFound = true;
            }
        }
        require(contextFound && stateFound, "both events");
        require(ingress.bindingTermination(1, 1).recordHash == expected, "historical refusal");
        bytes32 before_ = _roots();
        vm.expectRevert(abi.encodeWithSelector(T.InvalidAttribution.selector, uint256(1)));
        ingress.refuseArtistBinding(p, a);
        require(before_ == _roots(), "refusal replay rollback");
        T.Snapshot memory identityBefore =
            IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2();
        _repropose(1);
        require(
            keccak256(abi.encode(identityBefore))
                == keccak256(
                    abi.encode(IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2())
                ),
            "reproposal reuses identity read-only"
        );
        require(
            IStreamArtistBindingOwner(suite.owners[0]).binding(1).generation == 2
                && ingress.bindingTermination(1, 1).recordHash == expected,
            "generation history"
        );
    }

    function testBindingSafeDirectRefusalRejectsOwnerEoaAndExpiredProof() public {
        L.Termination memory p = _termination(1);
        T.Authorization memory a = T.Authorization(0, 999, "");
        a.signature = _signature(ingress.bindingRefusalDigest(p, a));
        vm.expectRevert(abi.encodeWithSelector(T.ExpiredAuthorization.selector, uint64(999)));
        ingress.refuseArtistBinding(p, a);
        a = T.Authorization(0, 2000, "");
        vm.expectRevert(abi.encodeWithSelector(T.InvalidSignature.selector));
        vm.prank(vm.addr(keys[0]));
        ingress.refuseArtistBinding(p, a);
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistBindingLifecycle.refuseArtistBinding, (p, a)),
                0
            ),
            "real Safe direct refusal"
        );
        require(ingress.bindingTermination(1, 1).kind == 1, "refused");
    }

    function testBindingTwoWithdrawalsHaveDistinctEvidenceAndNoIdentityOrRecordMutation() public {
        T.Snapshot memory identityBefore =
            IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2();
        bytes32 first;
        for (uint256 i; i < 2; ++i) {
            L.Termination memory p = _termination(1);
            T.Snapshot memory before_ = IStreamArtistOwner(suite.owners[0]).ownerStateSnapshotV2();
            ingress.withdrawArtistBinding(p);
            T.Snapshot memory after_ = IStreamArtistOwner(suite.owners[0]).ownerStateSnapshotV2();
            require(
                after_.revision == before_.revision + 1
                    && after_.recordChainTip == before_.recordChainTip,
                "withdraw no new normative record"
            );
            require(
                ingress.bindingTermination(1, p.generation).kind == 2
                    && ingress.bindingTermination(1, p.generation).recordHash == bytes32(0),
                "withdraw terminal history"
            );
            require(
                _operationPayload(4, address(this), p.bindingHash).length != 0,
                "distinct archive evidence exists"
            );
            if (i == 0) first = p.bindingHash;
            else require(first != p.bindingHash, "per-generation reference");
            _repropose(1);
        }
        require(
            keccak256(abi.encode(identityBefore))
                == keccak256(
                    abi.encode(IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2())
                ),
            "withdraw/reuse preserve identity"
        );
        require(
            IStreamArtistBindingOwner(suite.owners[0]).binding(1).generation == 3,
            "third generation"
        );
    }

    function testBindingSafeStoredProposerWithdrawalSurvivesRoleRemoval() public {
        ArtistUnitRoles roles = ArtistUnitRoles(suite.roleRegistry);
        roles.setAdmin(address(artist), true);
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistOnboarding.proposeArtistBinding,
                    (2, _proposal(artistId), bytes("unit identity document"), "Artist Safe")
                ),
                0
            ),
            "Safe proposer"
        );
        roles.setAdmin(address(artist), false);
        L.Termination memory p = _termination(2);
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(this)));
        ingress.withdrawArtistBinding(p);
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistBindingLifecycle.withdrawArtistBinding, (p)),
                0
            ),
            "stored Safe proposer retains withdrawal"
        );
        require(ingress.bindingTermination(2, 1).kind == 2, "withdrawn");
    }

    function testBindingQueuedSafeAcceptanceCannotDriftToReplacementGeneration() public {
        L.Termination memory old = _termination(1);
        T.Authorization memory a = T.Authorization(0, 2000, "");
        bytes memory queued = abi.encodeCall(IStreamArtistOnboarding.acceptArtistBinding, (1, a));
        bytes memory pinned = abi.encodeCall(
            IStreamArtistBindingLifecycle.acceptArtistBindingExpected,
            (1, old.generation, old.bindingHash, a)
        );
        ingress.withdrawArtistBinding(old);
        _repropose(1);
        bytes32 before_ = _roots();
        uint256 safeNonce = artist.nonce();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(address(ingress), queued);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(address(ingress), pinned);
        require(
            _roots() == before_ && artist.nonce() == safeNonce,
            "queued failure preserves all roots/Safe nonce"
        );
        require(
            !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, 0),
            "artist nonce unused"
        );
        L.Termination memory current = _termination(1);
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistBindingLifecycle.acceptArtistBindingExpected,
                    (1, current.generation, current.bindingHash, a)
                ),
                0
            ),
            "exact new terms accepted"
        );
        require(ingress.acceptedArtist(1) == address(artist), "accepted replacement");
    }

    function testBindingStaleSignedAcceptanceAndRefusalRejectAfterReplacement() public {
        L.Termination memory old = _termination(1);
        T.Authorization memory accept_ = T.Authorization(0, 2000, "");
        accept_.signature = _signature(ingress.acceptanceDigest(1, accept_));
        T.Authorization memory refuse_ = T.Authorization(1, 2000, "");
        refuse_.signature = _signature(ingress.bindingRefusalDigest(old, refuse_));
        ingress.withdrawArtistBinding(old);
        _repropose(1);
        bytes32 before_ = _roots();
        vm.expectRevert(abi.encodeWithSelector(T.InvalidSignature.selector));
        ingress.acceptArtistBinding(1, accept_);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidAttribution.selector, uint256(1)));
        ingress.refuseArtistBinding(old, refuse_);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidAttribution.selector, uint256(1)));
        ingress.withdrawArtistBinding(old);
        require(before_ == _roots(), "stale actions rollback");
        accept_.signature = _signature(ingress.acceptanceDigest(1, accept_));
        ingress.acceptArtistBinding(1, accept_);
        require(
            ingress.acceptedArtist(1) == address(artist),
            "legacy signed API still supports generation2"
        );
        L.Termination memory current = _termination(1);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidAttribution.selector, uint256(1)));
        ingress.withdrawArtistBinding(current);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidAttribution.selector, uint256(1)));
        ingress.refuseArtistBinding(current, refuse_);
    }

    function testBindingTerminationLateArchiveFailureRollsBackAllState() public {
        L.Termination memory p = _termination(1);
        T.Authorization memory a = T.Authorization(0, 2000, "");
        a.signature = _signature(ingress.bindingRefusalDigest(p, a));
        avm.mockCallRevert(
            address(archive),
            abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(T.InvalidRecord.selector)
        );
        bytes32 before_ = _roots();
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        ingress.refuseArtistBinding(p, a);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        ingress.withdrawArtistBinding(p);
        require(
            _roots() == before_ && ingress.bindingTermination(1, 1).kind == 0
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, 0),
            "atomic archive failures"
        );
        avm.clearMockedCalls();
        ingress.refuseArtistBinding(p, a);
    }

    function testRevokedNominationNeverUnlocksActualProviders() public {
        L.Termination memory p = _termination(1);
        ingress.withdrawArtistBinding(p);
        require(
            ingress.attribution(1).nominationHash == p.bindingHash
                && ingress.acceptedArtist(1) == address(0),
            "persistent nomination without attribution"
        );
        bytes32 profile = royalty.collectionRoyalty(1).profileId;
        address governor = ingress.governanceAuthority();
        vm.expectRevert(abi.encodeWithSelector(T.InvalidAttribution.selector, uint256(1)));
        vm.prank(governor);
        royalty.configureCollectionRoyalty(1, profile, 600);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.PrimaryArtistConsentRequired.selector, uint256(1)
            )
        );
        vm.prank(governor);
        primary.clearPrimaryAssignment(PRIMARY, 1, 1);
        _repropose(1);
        require(ingress.attribution(1).nominationHash != bytes32(0), "new nomination stays guarded");
    }

    function testCollectionArtistBeneficiaryUsesAcceptedIdentityAndOperativePayout() public {
        require(
            ingress.supportsInterface(type(IStreamArtistBeneficiaryFacts).interfaceId),
            "beneficiary capability"
        );
        vm.expectRevert(abi.encodeWithSelector(T.InvalidAttribution.selector, uint256(1)));
        ingress.collectionArtistBeneficiary(1);
        _accept();
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        ingress.collectionArtistBeneficiary(1);
        _payout();
        (bytes32 id, address account, bytes32 record) = ingress.collectionArtistBeneficiary(1);
        require(
            id == artistId && account == address(artist) && record != bytes32(0),
            "explicit accepted payout"
        );
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistBeneficiaryFacts.collectionArtistBeneficiary, (1)),
                0
            ),
            "actual Safe read"
        );
        T.PayoutDesignation memory p = T.PayoutDesignation(artistId, address(0x987), record);
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.payoutDesignationDigest(p, a));
        ingress.recordPayoutDesignation(p, a);
        bytes32 nextRecord;
        (, account, nextRecord) = ingress.collectionArtistBeneficiary(1);
        require(
            account == address(0x987) && nextRecord != record,
            "operative designation follows actual record"
        );
        core.set(keccak256("ARTIST_REGISTRY"), address(primary), false);
        require(
            _closed(abi.encodeCall(IStreamArtistBeneficiaryFacts.collectionArtistBeneficiary, (1))),
            "removed facade cannot provide current beneficiary"
        );
    }

    function _directTimeExercise(bool useSafe) private {
        address account = useSafe ? address(artist) : vm.addr(0xE0A123);
        uint256 collectionId = useSafe ? 1 : 2;
        if (useSafe) {
            _accept();
        } else {
            T.BindingProposal memory proposal = _proposal(bytes32(0));
            proposal.artistAddress = account;
            (artistId,) = ingress.proposeArtistBinding(
                2, proposal, bytes("unit identity document"), "Artist Safe"
            );
            vm.prank(account);
            ingress.acceptArtistBinding(2, T.Authorization(0, 2000, ""));
        }
        T.PayoutDesignation memory payout = T.PayoutDesignation(artistId, account, bytes32(0));
        T.Authorization memory prepared = T.Authorization(1, 0, "");
        bytes memory data =
            abi.encodeCall(IStreamArtistOnboarding.recordPayoutDesignation, (payout, prepared));
        vm.warp(1010);
        if (useSafe) {
            require(executeSafe(artist, keys, address(ingress), 0, data, 0), "queued Safe payout");
        } else {
            vm.prank(account);
            (bool ok,) = address(ingress).call(data);
            require(ok, "queued EOA payout");
        }
        (, bytes32 record) = ingress.artistPayoutAccount(artistId);
        require(
            record
                == StreamArtistHashes.payoutRecord(
                    StreamArtistHashes.Environment(
                        block.chainid, address(ingress), suite.core, suite.mintManager
                    ),
                    payout,
                    account,
                    1,
                    1010
                ),
            "payout uses inclusion timestamp"
        );
        bytes memory payload = _operationPayload(18, account, record);
        (
            ,
            T.Authorization memory submitted,
            T.SignerApproval memory proof,
            T.Authorization memory effective
        ) = abi.decode(
            payload, (T.PayoutDesignation, T.Authorization, T.SignerApproval, T.Authorization)
        );
        require(
            submitted.time == 0 && effective.time == 1010 && proof.direct
                && proof.digest == ingress.payoutDesignationDigest(payout, effective),
            "archive preserves submitted sentinel and canonical authorization"
        );
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(collectionId);
        bytes memory statement = bytes("explicit personhood waiver");
        T.Attestation memory attestation = T.Attestation(
            collectionId,
            10,
            artistId,
            b.identityRecordHash,
            keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1"),
            keccak256(statement),
            "urn:queued:waiver"
        );
        prepared.nonce = 2;
        data = abi.encodeCall(
            IStreamArtistOnboarding.recordArtistAttestation, (attestation, prepared, statement)
        );
        vm.warp(1020);
        if (useSafe) {
            require(
                executeSafe(artist, keys, address(ingress), 0, data, 0), "queued Safe attestation"
            );
        } else {
            vm.prank(account);
            (bool ok,) = address(ingress).call(data);
            require(ok, "queued EOA attestation");
        }
        T.AttestationRecord memory actual =
            IStreamArtistAttributionOwner(suite.owners[4]).attestation(collectionId, 10, artistId);
        require(
            actual.signedAt == 1020 && actual.signer == account,
            "attestation observed inclusion time"
        );
        payload = _operationPayload(24, account, actual.recordHash);
        (,, submitted,, proof, effective) = abi.decode(
            payload,
            (T.Binding, T.Attestation, T.Authorization, bytes, T.SignerApproval, T.Authorization)
        );
        require(
            submitted.time == 0 && effective.time == 1020 && proof.direct
                && proof.digest == ingress.attestationDigest(attestation, effective),
            "attestation exact archive normalization"
        );
    }

    function _operationPayload(uint16 op, address actor, bytes32 record)
        private
        view
        returns (bytes memory payload)
    {
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(ingress),
                address(coordinator),
                op,
                actor,
                record
            )
        );
        bytes32 configuration;
        (, configuration,,,,,, payload) = abi.decode(
            archive.artistEvidenceBytesV2(id, 1),
            (uint16, bytes32, uint16, address, bytes32, T.Snapshot[7], T.Snapshot[7], bytes)
        );
        require(
            configuration == coordinator.configurationHash(),
            "archived supported operation configuration"
        );
    }

    function testQueuedDirectSafePayoutAndAttestationObserveInclusionTime() public {
        _directTimeExercise(true);
    }

    function testQueuedDirectEoaPayoutAndAttestationObserveInclusionTime() public {
        _directTimeExercise(false);
    }

    function testObservedTimeSentinelNeverAppliesToRelayedApprovedEmptySafeProof() public {
        _accept();
        T.PayoutDesignation memory p = T.PayoutDesignation(artistId, address(artist), bytes32(0));
        T.Authorization memory a = T.Authorization(nextNonce, 0, "");
        _approveMessage(ingress.payoutDesignationDigest(p, a));
        bytes32 before_ = _roots();
        vm.expectRevert(abi.encodeWithSelector(T.InvalidTimestamp.selector, uint64(0)));
        ingress.recordPayoutDesignation(p, a);
        require(_roots() == before_, "relayed zero signedAt is not direct sentinel");
        a.time = uint64(block.timestamp + 100);
        a.signature = _signature(ingress.payoutDesignationDigest(p, a));
        vm.expectRevert(abi.encodeWithSelector(T.InvalidTimestamp.selector, a.time));
        ingress.recordPayoutDesignation(p, a);
        a.time = 900;
        a.signature = _signature(ingress.payoutDesignationDigest(p, a));
        bytes32 digest = ingress.payoutDesignationDigest(p, a);
        bytes32 record = ingress.recordPayoutDesignation(p, a);
        (, T.Authorization memory submitted, T.SignerApproval memory proof) = abi.decode(
            _operationPayload(18, address(this), record),
            (T.PayoutDesignation, T.Authorization, T.SignerApproval)
        );
        require(
            submitted.time == 900 && proof.digest == digest && !proof.direct,
            "signed relay time/digest unchanged"
        );
    }
    OfficialSafe private delegateSafe;
    uint256[] private delegateKeys;

    function _delegateSetup() private {
        delegateKeys = new uint256[](2);
        delegateKeys[0] = 0xDE1;
        delegateKeys[1] = 0xDE2;
        delegateSafe = createOfficialSafe(safeComponents, safeOwnerAddresses(delegateKeys), 2, 29);
    }

    function _delegation(uint256 scope, uint32 caps, uint64 start, uint64 expiry, uint64 uses)
        private
        view
        returns (D.Grant memory)
    {
        return D.Grant(
            artistId,
            address(delegateSafe),
            scope,
            caps,
            start,
            expiry,
            uses,
            keccak256("narrative evidence only")
        );
    }

    function _grant(D.Grant memory p) private returns (bytes32 record) {
        T.Authorization memory a = _authorization(false);
        a.time = 0;
        a.signature = _signature(ingress.delegationGrantDigest(p, a));
        if (directArtistCalls) {
            _artistCall(abi.encodeCall(IStreamArtistDelegation.grantArtistDelegation, (p, a)));
            record = _grantRecord(p, a.nonce);
        } else {
            record = ingress.grantArtistDelegation(p, a);
        }
        require(record == _grantRecord(p, a.nonce), "canonical grant record");
    }

    function _grantRecord(D.Grant memory p, uint256 nonce) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DELEGATION_RECORD_V1"),
                block.chainid,
                address(ingress),
                p.artistId,
                p.delegate,
                p.collectionId,
                p.capabilities,
                p.notBefore,
                p.expiresAt,
                p.maxUses,
                p.constraintsHash,
                nonce
            )
        );
    }

    function _revoke(bytes32 record) private returns (bytes32 revoked) {
        D.Revocation memory p =
            D.Revocation(artistId, address(delegateSafe), record, keccak256("artist revocation"));
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.delegationRevocationDigest(p, a));
        if (directArtistCalls) {
            _artistCall(abi.encodeCall(IStreamArtistDelegation.revokeArtistDelegation, (p, a)));
        } else {
            revoked = ingress.revokeArtistDelegation(p, a);
        }
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DELEGATION_REVOCATION_RECORD_V1"),
                block.chainid,
                address(ingress),
                artistId,
                address(delegateSafe),
                record,
                address(artist),
                uint8(1),
                p.reasonHash,
                a.nonce,
                uint64(block.timestamp)
            )
        );
        if (directArtistCalls) revoked = ingress.delegationRecord(record).revocationRecordHash;
        require(revoked == expected, "canonical revocation record");
    }

    function _delegateSignature(bytes32 digest) private returns (bytes memory) {
        return
            safeThresholdSignature(
                delegateKeys, safeMessageDigest(delegateSafe, abi.encode(digest))
            );
    }

    function _currentEconomics(address resolver)
        private
        view
        returns (T.EconomicsConsent memory p)
    {
        (T.AssignmentFact memory first, T.AssignmentFact memory second) =
            coordinator.reads().currentAssignments(1);
        T.AssignmentFact memory fact = resolver == first.resolver ? first : second;
        return T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
    }

    function _delegateEconomics(T.EconomicsConsent memory p, bytes32 grant, uint256 nonce)
        private
        returns (bytes32)
    {
        T.Authorization memory a = T.Authorization(nonce, uint64(block.timestamp + 1 days), "");
        a.signature = _delegateSignature(ingress.economicsConsentDigest(p, a));
        return ingress.recordDelegatedEconomicsConsent(p, grant, a);
    }

    function executeDelegate(address target, bytes calldata data) external returns (bool) {
        require(msg.sender == address(this), "test only");
        return executeSafe(delegateSafe, delegateKeys, target, 0, data, 0);
    }

    /// @dev Encloses digest/provider reads so expectRevert observes the actual failed operation.
    function relayDelegateEconomics(address resolver, bytes32 grant, uint256 nonce)
        external
        returns (bytes32)
    {
        require(msg.sender == address(this), "test only");
        return _delegateEconomics(_currentEconomics(resolver), grant, nonce);
    }

    function testDelegationSafeGrantCurrentEconomicsHasCanonicalClassAndIndependentReplay() public {
        _accept();
        _payout();
        _delegateSetup();
        bytes32 grant = _grant(_delegation(1, 36, 1000, 2000, 3));
        T.Identity memory prior = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        vm.warp(1001);
        T.EconomicsConsent memory p = _currentEconomics(address(primary));
        bytes32 record = _delegateEconomics(p, grant, 0);
        (, bytes32 designation) = ingress.artistPayoutAccount(artistId);
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_ECONOMICS_CONSENT_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        p.resolver,
                        p.revenueClass,
                        p.scope,
                        p.scopeId,
                        p.assignmentHash,
                        designation,
                        artistId,
                        address(delegateSafe),
                        uint8(2),
                        uint256(0),
                        uint64(block.timestamp)
                    )
                ),
            "delegated canonical record"
        );
        require(
            ingress.recordDelegation(record) == grant && ingress.delegationRecord(grant).uses == 1,
            "permanent grant witness/use"
        );
        T.Identity memory after_ = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        require(
            after_.nonceHint == prior.nonceHint
                && after_.lastAuthorityActionAt == prior.lastAuthorityActionAt,
            "delegate cannot consume principal nonce/liveness"
        );
        (bool used, uint256 hint) = ingress.delegatedNonceState(artistId, address(delegateSafe), 0);
        require(used && hint == 1, "independent delegate replay lane");
        (bool active,,,,,, uint64 remaining) = ingress.delegationState(grant);
        require(active && remaining == 2, "finite remaining");
    }

    function testDelegationSafeProspectiveConsentAppliesActualProvider() public {
        _accept();
        _payout();
        _delegateSetup();
        bytes32 grant = _grant(_delegation(0, 4, 1000, 2000, 0));
        (T.EconomicsConsent memory p, T.FixedEconomicsCandidate memory candidate) =
            _candidate(address(primary), address(artist), 0, false);
        T.Authorization memory a = T.Authorization(0, 2000, "");
        a.signature = _delegateSignature(ingress.economicsConsentDigest(p, a));
        bytes32 record = ingress.recordDelegatedProspectiveEconomicsConsent(p, candidate, grant, a);
        vm.prank(primary.owner());
        primary.transferOwnership(address(artist));
        require(
            executeSafe(
                artist,
                keys,
                address(primary),
                0,
                abi.encodeCall(
                    IStreamRevenueResolver.setPrimaryProfileAssignment,
                    (PRIMARY, uint8(1), uint256(1), candidate.profileHash, bytes32(0))
                ),
                0
            ),
            "Safe applies delegated-consented primary"
        );
        require(
            primary.resolvePrimaryAssignment(1, 0, PRIMARY).assignmentHash == p.assignmentHash
                && ingress.recordDelegation(record) == grant,
            "actual assignment matches consent"
        );
        (bool active,,,,,, uint64 remaining) = ingress.delegationState(grant);
        require(active && remaining == type(uint64).max, "unlimited within finite window");
    }

    function testDelegationSafeDirectFreezeNoMintFloorsAndActualApply() public {
        _accept();
        _delegateSetup();
        directArtistCalls = true;
        bytes32 grant = _grant(_delegation(1, 32, 1000, 2000, 1));
        T.RoyaltyFreeze memory p = _freezePayload();
        T.Authorization memory a = T.Authorization(0, 2000, "");
        vm.recordLogs();
        require(
            executeSafe(
                delegateSafe,
                delegateKeys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistDelegation.authorizeDelegatedRoyaltyFreeze, (p, grant, a)
                ),
                0
            ),
            "direct Safe delegate freeze"
        );
        bytes32 record = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ROYALTY_FREEZE_RECORD_V1"),
                block.chainid,
                address(ingress),
                p.resolver,
                p.collectionId,
                p.revenueClass,
                p.expectedAssignmentHash,
                artistId,
                address(delegateSafe),
                uint8(2),
                uint256(0),
                uint64(block.timestamp)
            )
        );
        require(
            ingress.recordDelegation(record) == grant
                && ingress.isRoyaltyFreezeAuthorized(1, p.expectedAssignmentHash),
            "delegated freeze is operative"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool witness;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == suite.owners[6]
                    && logs[i].topics[0]
                        == keccak256(
                            "ArtistRecordDelegation(uint16,bytes32,bytes32,bytes32,address,bytes32,uint8)"
                        )
            ) {
                (uint16 schema, address resolver, bytes32 class_, uint8 authority) =
                    abi.decode(logs[i].data, (uint16, address, bytes32, uint8));
                require(
                    schema == 1 && logs[i].topics[1] == record && logs[i].topics[2] == grant
                        && logs[i].topics[3] == artistId && resolver == address(royalty)
                        && class_ == keccak256("ROYALTY_ERC2981") && authority == 2,
                    "reconstructible grant witness"
                );
                witness = true;
            }
        }
        require(witness, "witness event");
        _revoke(grant);
        require(
            ingress.isRoyaltyFreezeAuthorized(1, p.expectedAssignmentHash),
            "revocation does not erase successful authority"
        );
        require(
            executeSafe(
                delegateSafe,
                delegateKeys,
                address(royalty),
                0,
                abi.encodeCall(
                    IStreamRoyaltyFreeze.applyArtistRoyaltyFreeze,
                    (uint256(1), p.expectedAssignmentHash)
                ),
                0
            ),
            "actual defensive freeze application"
        );
        require(
            royalty.collectionRoyalty(1).frozen && _closed(_mintCall()),
            "frozen without inventing mint floors"
        );
    }

    function testDelegationWindowCapabilityScopeAndExhaustionRejectionsAreAtomic() public {
        _accept();
        _payout();
        _delegateSetup();
        bytes32 future = _grant(_delegation(1, 4, 1100, 1200, 1));
        T.EconomicsConsent memory p = _currentEconomics(address(primary));
        bytes32 before_ = _roots();
        vm.expectRevert(abi.encodeWithSelector(D.DelegationUnavailable.selector, future));
        this.relayDelegateEconomics(address(primary), future, 0);
        require(_roots() == before_, "notBefore rollback");
        vm.warp(1100);
        _delegateEconomics(p, future, 0);
        before_ = _roots();
        vm.expectRevert(abi.encodeWithSelector(D.DelegationUnavailable.selector, future));
        this.relayDelegateEconomics(address(royalty), future, 1);
        require(_roots() == before_, "finite use rollback");
        bytes32 wrongScope = _grant(_delegation(2, 4, 1100, 1200, 0));
        before_ = _roots();
        vm.expectRevert(abi.encodeWithSelector(D.DelegationScope.selector, wrongScope));
        this.relayDelegateEconomics(address(royalty), wrongScope, 1);
        require(_roots() == before_, "scope rollback");
        _revoke(wrongScope);
        bytes32 wrongCap = _grant(_delegation(0, 32, 1100, 1200, 0));
        before_ = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(D.DelegationCapability.selector, wrongCap, uint32(4))
        );
        this.relayDelegateEconomics(address(royalty), wrongCap, 1);
        require(_roots() == before_, "capability rollback");
        vm.warp(1200);
        (bool active,,,,,,) = ingress.delegationState(wrongCap);
        require(!active, "exclusive expiry");
        vm.expectRevert(abi.encodeWithSelector(D.DelegationUnavailable.selector, wrongCap));
        this.relayDelegateEconomics(address(royalty), wrongCap, 1);
    }

    function testDelegationReplacementCannotResetNoncesAndUnusedProofRemainsValid() public {
        _accept();
        _payout();
        _delegateSetup();
        bytes32 first = _grant(_delegation(1, 4, 1000, 1100, 0));
        _delegateEconomics(_currentEconomics(address(primary)), first, 1);
        T.EconomicsConsent memory p = _currentEconomics(address(royalty));
        T.Authorization memory unused = T.Authorization(0, 2000, "");
        unused.signature = _delegateSignature(ingress.economicsConsentDigest(p, unused));
        _revoke(first);
        bytes32 second = _grant(_delegation(0, 4, 1000, 2000, 0));
        bytes32 before_ = _roots();
        avm.expectPartialRevert(T.Replay.selector);
        this.relayDelegateEconomics(address(royalty), second, 1);
        require(
            _roots() == before_ && ingress.delegationRecord(second).uses == 0,
            "replacement preserves replay and use atomicity"
        );
        ingress.recordDelegatedEconomicsConsent(p, second, unused);
        (bool used, uint256 hint) = ingress.delegatedNonceState(artistId, address(delegateSafe), 0);
        require(
            used && hint == 2 && ingress.delegationRecord(first).uses == 1
                && ingress.delegationRecord(second).uses == 1,
            "unused digest accepts new authority; reverse nonces bounded"
        );
    }

    function testDelegationRevocationImmediatelyBlocksUnusedActionAndKeepsExactRecord() public {
        _accept();
        _delegateSetup();
        bytes32 grant = _grant(_delegation(1, 32, 1000, 2000, 0));
        T.RoyaltyFreeze memory p = _freezePayload();
        T.Authorization memory a = T.Authorization(0, 2000, "");
        a.signature = _delegateSignature(ingress.royaltyFreezeDigest(p, a));
        vm.recordLogs();
        bytes32 revocation = _revoke(grant);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool found;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == suite.owners[2]
                    && logs[i].topics[0]
                        == keccak256(
                            "ArtistDelegationRevoked(uint16,bytes32,address,bytes32,bytes32,address,uint8,uint256,uint64)"
                        )
            ) {
                (
                    uint16 schema,
                    bytes32 reason,
                    address signer,
                    uint8 class_,
                    uint256 nonce,
                    uint64 time
                ) = abi.decode(logs[i].data, (uint16, bytes32, address, uint8, uint256, uint64));
                require(
                    schema == 1 && reason == keccak256("artist revocation")
                        && signer == address(artist) && class_ == 1 && nonce == nextNonce - 1
                        && time == block.timestamp && logs[i].topics[1] == artistId
                        && logs[i].topics[2] == bytes32(uint256(uint160(address(delegateSafe))))
                        && logs[i].topics[3] == grant,
                    "exact reconstructible revoke event"
                );
                found = true;
            }
        }
        require(
            found && ingress.delegationRecord(grant).revocationRecordHash == revocation,
            "historical revocation"
        );
        bytes32 before_ = _roots();
        vm.expectRevert(abi.encodeWithSelector(D.DelegationUnavailable.selector, grant));
        ingress.authorizeDelegatedRoyaltyFreeze(p, grant, a);
        require(_roots() == before_, "revocation blocks later use");
    }

    function testDelegationRejectsForbiddenUnknownCapsAndConflictingFutureGrant() public {
        _delegateSetup();
        uint32[6] memory invalid =
            [uint32(0), uint32(256), uint32(512), uint32(2048), uint32(2), uint32(1 << 31)];
        for (uint256 i; i < invalid.length; ++i) {
            D.Grant memory p = _delegation(0, invalid[i], 1000, 2000, 0);
            T.Authorization memory a = T.Authorization(nextNonce, 0, "");
            a.signature = _signature(ingress.delegationGrantDigest(p, a));
            bytes32 before_ = _roots();
            avm.expectRevert(T.UnsupportedProfile.selector);
            ingress.grantArtistDelegation(p, a);
            require(_roots() == before_, "invalid cap no mutation");
        }
        bytes32 first = _grant(_delegation(1, 36, 1100, 2000, 0));
        D.Grant memory conflict = _delegation(2, 4, 1000, 1200, 0);
        T.Authorization memory a = T.Authorization(nextNonce, 0, "");
        a.signature = _signature(ingress.delegationGrantDigest(conflict, a));
        vm.expectRevert(abi.encodeWithSelector(D.ConflictingDelegation.selector, first));
        ingress.grantArtistDelegation(conflict, a);
        vm.warp(2000);
        bytes32 replacement = _grant(_delegation(0, 4, 2000, 2200, 0));
        require(replacement != first, "expired key reusable; old history retained");
    }

    function testDelegationLateConsentAndArchiveFailuresRollBackUseNonceAndWitness() public {
        _accept();
        _payout();
        _delegateSetup();
        bytes32 grant = _grant(_delegation(1, 36, 1000, 2000, 0));
        T.EconomicsConsent memory p = _currentEconomics(address(primary));
        _economicsRecord(coordinator.reads().currentRoyaltyAssignment(1));
        bytes32 before_ = _roots();
        avm.expectPartialRevert(T.Replay.selector);
        this.relayDelegateEconomics(address(royalty), grant, 0);
        require(
            _roots() == before_ && ingress.delegationRecord(grant).uses == 0,
            "late record replay atomic"
        );
        avm.mockCallRevert(
            address(archive),
            abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(T.InvalidRecord.selector)
        );
        avm.expectRevert(T.InvalidRecord.selector);
        this.relayDelegateEconomics(address(primary), grant, 0);
        (bool used,) = ingress.delegatedNonceState(artistId, address(delegateSafe), 0);
        require(
            !used && _roots() == before_ && ingress.delegationRecord(grant).uses == 0,
            "archive reverts all owners/use/index"
        );
        avm.clearMockedCalls();
        _delegateEconomics(p, grant, 0);
    }

    function testDelegationSafeThresholdWrongDomainAndOwnersCannotInheritRoles() public {
        _accept();
        _delegateSetup();
        D.Grant memory p = _delegation(1, 32, 1000, 2000, 0);
        T.Authorization memory a = T.Authorization(nextNonce, 0, "");
        bytes32 digest = ingress.delegationGrantDigest(p, a);
        a.signature = safeThresholdSignature(
            keys, safeMessageDigest(artist, abi.encode(keccak256(abi.encode(digest))))
        );
        bytes32 before_ = _roots();
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.grantArtistDelegation(p, a);
        a.signature = "";
        vm.prank(vm.addr(keys[0]));
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.grantArtistDelegation(p, a);
        require(_roots() == before_, "wrong domain/unapproved owner no mutation");
        bytes32 grant = _grant(p);
        T.RoyaltyFreeze memory freeze = _freezePayload();
        a = T.Authorization(0, 2000, "");
        uint256[] memory one = new uint256[](1);
        one[0] = delegateKeys[0];
        a.signature = safeThresholdSignature(
            one, safeMessageDigest(delegateSafe, abi.encode(ingress.royaltyFreezeDigest(freeze, a)))
        );
        before_ = _roots();
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.authorizeDelegatedRoyaltyFreeze(freeze, grant, a);
        a.signature = "";
        vm.prank(vm.addr(delegateKeys[0]));
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.authorizeDelegatedRoyaltyFreeze(freeze, grant, a);
        require(_roots() == before_, "missing threshold/owner never delegate");
        D.Revocation memory revoke =
            D.Revocation(artistId, address(delegateSafe), grant, bytes32(0));
        a = T.Authorization(nextNonce, 2000, "");
        a.signature = _delegateSignature(ingress.delegationRevocationDigest(revoke, a));
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.revokeArtistDelegation(revoke, a);
    }

    function testDelegationApprovedEmptySafeGrantUseAndRevokeAndProtocolRejection() public {
        _accept();
        _delegateSetup();
        D.Grant memory p = _delegation(1, 32, 1000, 2000, 0);
        T.Authorization memory a = _authorization(false);
        a.time = 0;
        _approveMessage(ingress.delegationGrantDigest(p, a));
        bytes32 grant = ingress.grantArtistDelegation(p, a);
        T.RoyaltyFreeze memory freeze = _freezePayload();
        a = T.Authorization(0, 2000, "");
        bytes32 digest = ingress.royaltyFreezeDigest(freeze, a);
        require(
            executeSafe(
                delegateSafe,
                delegateKeys,
                safeComponents.signMessage,
                0,
                abi.encodeWithSignature("signMessage(bytes)", abi.encode(digest)),
                1
            ),
            "delegate Safe approval"
        );
        bytes32 record = ingress.authorizeDelegatedRoyaltyFreeze(freeze, grant, a);
        require(ingress.recordDelegation(record) == grant, "approved empty delegate proof");
        D.Revocation memory revoke =
            D.Revocation(artistId, address(delegateSafe), grant, bytes32(0));
        a = _authorization(false);
        _approveMessage(ingress.delegationRevocationDigest(revoke, a));
        ingress.revokeArtistDelegation(revoke, a);
        bytes32 before_ = _roots();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeDelegate(
            address(coordinator),
            abi.encodeCall(
                IStreamArtistDelegationCoordinator.coordinateGrantArtistDelegation,
                (address(delegateSafe), p, a)
            )
        );
        T.ActionContext memory c = T.ActionContext(
            26, address(delegateSafe), IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2()
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeDelegate(
            suite.owners[2],
            abi.encodeCall(
                IStreamArtistDelegationOwner.grantDelegation,
                (c, p, a, T.SignerApproval(address(artist), bytes32(0), false))
            )
        );
        require(_roots() == before_, "direct Safe cannot impersonate protocol callbacks");
        require(
            executeSafe(
                delegateSafe,
                delegateKeys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistDelegation.delegationState, (grant)),
                0
            ),
            "actual Safe delegation view"
        );
    }

    function testDelegationWildcardUsesSameIdentityOnSecondAcceptedCollection() public {
        _accept();
        _payout();
        _delegateSetup();
        bytes32 grant = _grant(_delegation(0, 4, 1000, 2000, 0));
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory assignment =
            primary.resolvePrimaryAssignment(1, 0, PRIMARY);
        vm.prank(primary.owner());
        primary.setPrimaryProfileAssignment(PRIMARY, 1, 2, assignment.profileId, bytes32(0));
        IStreamRoyaltyResolver.RoyaltyConfig memory royaltyConfig = royalty.collectionRoyalty(1);
        vm.prank(royalty.owner());
        royalty.configureCollectionRoyalty(2, royaltyConfig.profileId, royaltyConfig.royaltyBps);
        ingress.proposeArtistBinding(
            2, _proposal(artistId), bytes("unit identity document"), "Artist Safe"
        );
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.acceptanceDigest(2, a));
        ingress.acceptArtistBinding(2, a);
        assignment = primary.resolvePrimaryAssignment(2, 0, PRIMARY);
        T.EconomicsConsent memory p =
            T.EconomicsConsent(2, address(primary), PRIMARY, 1, 2, assignment.assignmentHash);
        bytes32 record = _delegateEconomics(p, grant, 0);
        require(
            ingress.recordDelegation(record) == grant && ingress.delegationRecord(grant).uses == 1,
            "wildcard follows accepted same artist identity"
        );
    }

    function setUp() public {
        nextNonce = 0;
        directArtistCalls = false;
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
        primary = new StreamRevenueResolver(
            IStreamCore(address(core)),
            factory,
            governance,
            ingress,
            IStreamGasParameterHost.GasParameterConfig(
                "ARTIST_BENEFICIARY_READ_GAS", 200_000, 50_000, 2
            )
        );
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
        _installInitialPrimary(governance, profile);
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
