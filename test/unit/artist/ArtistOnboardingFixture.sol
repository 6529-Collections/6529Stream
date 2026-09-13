// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "./ArtistEstateArchivalFixture.sol";
import "./ArtistSaleRegistryFixture.sol";
import "./ArtistPublicationHostFixture.sol";
import "./ArtistCanonicalPublicationFixture.sol";
import "./ArtistSanctionFinalityFixture.sol";
import "./ArtistIdentityReadEncodingFixture.sol";
import "./ArtistRecoveryIntentFixture.sol";
import "../../../smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol";
import "../../../smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol";
import "../../../smart-contracts/domains/revenue/StreamRevenueEscrow.sol";
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
    function collectionHasMaxSupply(uint256 id) external pure returns (bool) {
        return id == 1;
    }

    function collectionStatus(uint256 id) external pure returns (uint8) {
        return id == 1 ? 2 : 0;
    }

    function collectionSupplyMode(uint256) external pure returns (uint8) {
        return 0;
    }

    function collectionMaxSupply(uint256 id) external pure returns (uint256) {
        return id == 1 ? 1 : 0;
    }

    function collectionMintedEver(uint256 id) external pure returns (uint256) {
        return id == 1 ? 1 : 0;
    }

    function collectionNextSerial(uint256 id) external pure returns (uint256) {
        return id == 1 ? 2 : 0;
    }

    function totalSupplyOfCollection(uint256 id) external pure returns (uint256) {
        return id == 1 ? 1 : 0;
    }

    function tokenLifecycle(uint256) external pure returns (uint8) {
        return 0;
    }

    function collectionBurnsBlocked(uint256 id) external pure returns (bool) {
        return id == 1;
    }

    function collectionFreezeStatus(uint256 id) external pure returns (bool) {
        return id == 1;
    }
    mapping(bytes32 => address) public targets;
    mapping(bytes32 => bool) public frozen;
    mapping(uint256 => uint256) private tokenCollections;

    function setTokenCollection(uint256 tokenId, uint256 collectionId) external {
        tokenCollections[tokenId] = collectionId;
    }

    function tokenCollectionIdentity(uint256 tokenId)
        external
        view
        returns (bool, uint256, uint256, bool)
    {
        uint256 collectionId = tokenCollections[tokenId];
        return (collectionId != 0, collectionId, 1, false);
    }

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
            kind,
            kind == keccak256("MODULE_REGISTRY")
                ? type(IStreamModuleRegistry).interfaceId
                : bytes4(0),
            targets[keccak256("MODULE_REGISTRY")],
            1,
            keccak256("unit pointer manifest"),
            keccak256("unit pointer deployment"),
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
    uint8 private selectedClass = 1;
    address public roleRegistry;
    address private contestProposer;
    bytes32 private contestReason;
    string private contestURI;

    /// @dev Exact governance read boundary, not actual staging, proposer admission or timelock evidence.
    function configureContestReads(
        address roles,
        address proposer,
        bytes32 reason,
        string calldata uri
    ) external {
        roleRegistry = roles;
        contestProposer = proposer;
        contestReason = reason;
        contestURI = uri;
    }

    function governanceAction(bytes32) external view returns (GovernanceAction memory action) {
        action.status = GovernanceActionStatus.EXECUTED;
        action.actionClass = selectedClass;
        action.proposer = contestProposer;
        action.reasonHash = contestReason;
        action.reasonURI = contestURI;
        // Deliberately differs from the current call: batches index their first call here.
        action.target = address(0x1234);
        action.selector = bytes4(0x12345678);
        action.scopeHash = keccak256("first batch call");
    }

    /// @dev An exact target context only. This does not simulate a real Executor's authorization or delay.
    function executeModuleContext(
        address target,
        bytes calldata data,
        uint8 actionClass,
        bytes32 scope_,
        bytes32 oldState_,
        bytes32 newState_
    ) external {
        active = true;
        selectedClass = actionClass;
        scope = scope_;
        oldState = oldState_;
        newState = newState_;
        (bool ok, bytes memory reason) = target.call(data);
        if (!ok) assembly ("memory-safe") { revert(add(reason, 32), mload(reason)) }
        active = false;
        scope = 0;
        oldState = 0;
        newState = 0;
    }

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
            active ? selectedClass : 0,
            scope,
            oldState,
            newState
        );
    }

    /// @dev Exact host-context unit double, not proof of actual delayed governance.
    function raise(IStreamGasParameterHost host, bytes32 id, uint256 value) external {
        selectedClass = 1;
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

    /// @dev Exact AA seconds-host context only; this is not an actual timelock/governance proof.
    function configureWindow(
        IStreamArtistWindows host,
        bytes32 parameter,
        uint64 value,
        uint64 expectedRevision,
        uint8 actionClass,
        bool wrongScope
    ) external {
        (uint64 previous,, uint64 revision) = host.artistWindowInfo(parameter);
        scope =
            wrongScope ? keccak256("wrong artist window scope") : host.artistWindowScope(parameter);
        oldState = host.artistWindowStateHash(parameter, previous, revision);
        newState = host.artistWindowStateHash(parameter, value, revision + 1);
        selectedClass = actionClass;
        active = true;
        host.setArtistWindow(parameter, value, expectedRevision);
        active = false;
        scope = bytes32(0);
        oldState = bytes32(0);
        newState = bytes32(0);
    }
}

contract ArtistUnitRoles {
    address public owner;

    function configureOwner(address value) external {
        require(msg.sender == admin, "unit admin");
        owner = value;
    }
    address public immutable admin;
    mapping(address => bool) private extraAdmins;
    uint64 private revision = 1;
    bytes32 private changes;
    mapping(address => bool) private arbiters;

    constructor(address admin_) {
        admin = admin_;
    }

    function hasRole(bytes32 role, address account) external view returns (bool) {
        return (role == keccak256("ROLE_ATTRIBUTION_ARBITER") && arbiters[account])
            || role == keccak256("ROLE_ARTIST_REGISTRY_ADMIN")
            && (account == admin || extraAdmins[account]);
    }

    function setArbiter(address account, bool enabled) external {
        require(msg.sender == admin, "unit admin");
        arbiters[account] = enabled;
        changes = keccak256(abi.encode(changes, account, enabled, "arbiter"));
        ++revision;
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
    address public core;

    function configureCore(address value) external {
        core = value;
    }
    bytes32 public content = keccak256("initial unit content");
    IStreamArtistContentAuthority public artistContent;
    IStreamArtistContentRatification public artistRatification;
    mapping(bytes32 => bool) public consumedContentRecord;
    mapping(uint256 => mapping(bytes32 => bool)) public contentLocks;
    mapping(uint256 => bytes32) private evolutionRatification;
    mapping(uint256 => bytes32) private evolutionContent;

    function configureArtist(address registry) external {
        artistContent = IStreamArtistContentAuthority(registry);
        artistRatification = IStreamArtistContentRatification(registry);
    }

    function setContent(bytes32 value) external {
        content = value;
    }

    function currentArtistContentState(uint256 id) external view returns (address, bytes32) {
        require(content != bytes32(0), "unit nonempty artwork floor");
        return (address(this), keccak256(abi.encode(id, content)));
    }

    function artistContentFamilyState(uint256 id, bytes32 family)
        external
        view
        returns (bool, bytes32)
    {
        return (family == keccak256("SCRIPT"), familyState(id, content));
    }

    function familyState(uint256 id, bytes32 candidate) public pure returns (bytes32) {
        return keccak256(abi.encode(keccak256("SCRIPT"), id, candidate));
    }

    function artistContentLockState(uint256 id, bytes32 lockClass)
        external
        view
        returns (bool, bool)
    {
        if (lockClass == keccak256("DEPENDENCIES")) return (true, true);
        bool supported = lockClass == keccak256("SCRIPT")
            || lockClass == keccak256("MEDIA_MANIFEST") || lockClass == keccak256("BASE_URI");
        return (supported, contentLocks[id][lockClass]);
    }

    function artistContentFreezeState(uint256 id) external view returns (bytes32) {
        return keccak256(abi.encode(id, content));
    }

    function artistContentEvolution(uint256 id) external view returns (bytes32, bytes32) {
        return (evolutionRatification[id], evolutionContent[id]);
    }

    /// @dev Unit host application boundary, distinct from root's actual current router tests.
    function applyContent(uint256 id, bytes32 candidate) external {
        require(!contentLocks[id][keccak256("SCRIPT")], "unit script locked");
        (bool exists, bytes32 ratified, bytes32 ratification) =
            artistRatification.firstReleaseRatification(id);
        bytes32 before_ = keccak256(abi.encode(id, content));
        require(
            exists
                && (ratified == before_
                    || (evolutionRatification[id] == ratification
                        && evolutionContent[id] == before_)),
            "unit predecessor"
        );
        bytes32 record = artistContent.contentConsentEvidence(
            id, keccak256("SCRIPT"), familyState(id, candidate)
        );
        require(!consumedContentRecord[record], "unit consent consumed");
        require(candidate != content, "unit no-op");
        consumedContentRecord[record] = true;
        content = candidate;
        evolutionRatification[id] = ratification;
        evolutionContent[id] = keccak256(abi.encode(id, candidate));
    }

    function applyFreeze(uint256 id, bytes32 record) external {
        Content.FreezeRecord memory r = artistContent.contentFreezeAuthorization(record);
        require(
            r.recordHash == record && r.expectedStateHash == keccak256(abi.encode(id, content)),
            "unit stale freeze"
        );
        for (uint256 i; i < r.lockClasses.length; ++i) {
            (bool authorized, bytes32 exact) =
                artistContent.isContentFreezeAuthorized(id, r.lockClasses[i]);
            require(authorized && exact == record, "unit freeze authority");
        }
        for (uint256 i; i < r.lockClasses.length; ++i) {
            contentLocks[id][r.lockClasses[i]] = true;
        }
    }

    /// @dev Deliberately forged fixture witness for negative tests, never a production authority.
    function setEvolution(uint256 id, bytes32 ratification, bytes32 resulting) external {
        evolutionRatification[id] = ratification;
        evolutionContent[id] = resulting;
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
/// @dev Test-only simulation of the future operation33 state seam. No public compromise filing is claimed.
contract ArtistRotationContestHarness is StreamArtistIdentityAuthority {
    constructor(
        address registry_,
        address coordinator_,
        address archive_,
        address core_,
        address manager_
    ) StreamArtistIdentityAuthority(registry_, coordinator_, archive_, core_, manager_) { }

    function simulateExecutedTransitionContest(bytes32 record) external {
        R.TransitionState storage transition = _rotations.rotations[record].transition;
        require(
            transition.phase == 2 && transition.contestedAt == 0, "qualified transition fixture"
        );
        transition.contestedAt = _now();
        _identity.identities[transition.artistId].status = 4;
        ++_revision;
        _stateRoot = keccak256(
            abi.encode(keccak256("TEST_ONLY_COMPROMISE_STATE_SEAM"), _stateRoot, transition)
        );
    }
}

abstract contract ArtistOnboardingFixture is
    CharacterizationTestBase,
    ArtistEstateArchivalFixture,
    ArtistSaleRegistryFixture
{
    event EstateCoverageMeasurement(string context, uint256 cap, uint256 measuredSpan);
    event CollaboratorBoundMeasurement(uint256 rows, uint256 entries, uint256 gasUsed);
    ArtistTestVm internal constant avm =
        ArtistTestVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 internal constant PHASE = keccak256("artist unit phase");
    bytes32 internal POLICY;
    bytes32 internal constant PRIMARY = keccak256("PRIMARY_SALE");
    uint256[] internal keys;
    OfficialSafe internal artist;
    SafeComponents internal safeComponents;
    StreamArtistOnboardingRegistry internal ingress;
    StreamArtistOnboardingCoordinator internal coordinator;
    StreamArtistArchiveV2 internal archive;
    T.SuiteConfiguration internal suite;
    bytes32 internal artistId;
    ArtistUnitCore internal core;
    ArtistUnitMetadata internal metadata;
    StreamRoyaltyResolver internal royalty;
    StreamRevenueResolver internal primary;
    StreamSplitFactory internal factory;
    StreamMintManager internal manager;
    StreamMintLedger internal ledger;
    uint256 internal nextNonce;
    bool internal directArtistCalls;
    bytes32 internal collaboratorId;
    uint8 internal templateFixtureKind;
    bytes32 internal templateFixtureId;
    bool internal rotationContestFixture;
    bool internal actualSaleRegistryFixture;
    uint8 internal saleScopeFixture;
    StreamModuleRegistry internal saleModules;
    StreamNativeFixedPriceSaleAdapter internal nativeSale;

    function _unavailabilityFixture()
        internal
        returns (Recovery.FindingRequest memory request, U.Target memory target)
    {
        _accept();
        address authority = StreamArtistIdentityAuthority(suite.owners[2]).artistWindowAuthority();
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(this), true);
        request = Recovery.FindingRequest(
            artistId, 1, keccak256("inability evidence"), keccak256("finding reason")
        );
        ArtistUnitGovernance(authority)
            .configureContestReads(
                suite.roleRegistry, address(this), request.reasonHash, "urn:finding"
            );
        target = U.Target(
            address(
                new ArtistRecoveryIntentFixture(
                    address(core),
                    coordinator.finalityRegistry(),
                    keccak256("original executed finality"),
                    keccak256("exact recovery manifest")
                )
            ),
            keccak256("future scheduled recovery"),
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0),
            keccak256("original executed finality"),
            keccak256("exact recovery manifest")
        );
        core.set(keccak256("ARTWORK_FINALITY_RECOVERY"), target.recoveryRegistry, false);
        _unavailabilityModule(
            keccak256("ARTIST_REGISTRY"),
            address(ingress),
            keccak256("ARTIST_REGISTRY"),
            type(IStreamArtistMintConsent).interfaceId
        );
        _unavailabilityModule(
            keccak256("ARTWORK_FINALITY_RECOVERY"),
            target.recoveryRegistry,
            keccak256("STREAM_ARTWORK_FINALITY_RECOVERY"),
            0x83685f5c
        );
        GovernanceAction memory action;
        action.status = GovernanceActionStatus.SCHEDULED;
        action.actionClass = 2;
        action.target = address(0x1234); // Deliberately the unrelated first batch call.
        action.selector = 0x12345678;
        action.scopeHash = keccak256("first batch scope");
        action.notBefore = uint64(block.timestamp + 91 days);
        action.expiresAfter = uint64(block.timestamp + 100 days);
        action.proposer = address(this);
        action.reasonURI = "urn:scheduled-recovery";
        avm.mockCall(
            authority,
            abi.encodeCall(IStreamGovernanceReads.governanceAction, (target.recoveryActionId)),
            abi.encode(action)
        );
    }

    function _unavailabilityModule(bytes32 key, address target, bytes32 kind, bytes4 interfaceId)
        internal
    {
        address modules = address(manager.moduleRegistry());
        avm.mockCall(
            address(core),
            abi.encodeCall(IStreamCorePointers.getSatellitePointer, (key)),
            abi.encode(
                target,
                target.codehash,
                false,
                kind,
                interfaceId,
                modules,
                uint8(1),
                keccak256("unit module manifest"),
                keccak256("unit deployment manifest"),
                uint64(1)
            )
        );
        avm.mockCall(
            modules,
            abi.encodeCall(IStreamModuleRegistry.isModuleEligible, (target, kind, interfaceId)),
            abi.encode(true)
        );
    }

    function _recordUnavailability(Recovery.FindingRequest memory request, U.Target memory target)
        internal
        returns (bytes32 hash)
    {
        U.Context memory context_ = ingress.unavailabilityFindingContext(request, target);
        ArtistUnitGovernance(StreamArtistIdentityAuthority(suite.owners[2]).artistWindowAuthority())
            .executeModuleContext(
                address(ingress),
                abi.encodeCall(
                    IStreamArtistUnavailability.recordUnavailabilityFinding, (request, target)
                ),
                2,
                context_.scopeHash,
                context_.oldValueHash,
                context_.newValueHash
            );
        hash =
            StreamArtistIdentityAuthority(suite.owners[2]).latestUnavailabilityFinding(artistId, 1);
    }

    function _unavailabilityActivityEvent(
        Vm.Log[] memory logs,
        address signer,
        uint8 class_,
        uint16 operation
    ) internal view {
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == suite.owners[2] && logs[i].topics.length != 0
                    && logs[i].topics[0]
                        == keccak256(
                            "ArtistUnavailabilityActivityRecorded(uint16,bytes32,address,uint8,uint16,uint256,uint256)"
                        )
            ) {
                ++count;
                require(
                    logs[i].topics.length == 3 && logs[i].topics[1] == artistId
                        && logs[i].topics[2] == bytes32(uint256(uint160(signer)))
                        && keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(uint16(1), class_, operation, uint256(0), uint256(1))
                            ),
                    "exact authenticated activity provenance"
                );
            }
        }
        require(count == 1, "one owner activity event");
    }

    function _canonicalPublicationHost() internal returns (ArtistCanonicalPublicationFixture f) {
        actualSaleRegistryFixture = true;
        setUp();
        _accept();
        f = new ArtistCanonicalPublicationFixture();
        f.deploy(address(core), address(ingress));
        StreamCollectionMetadataV1 host = f.metadata();
        _saleRegister(
            saleModules,
            factory.governanceAuthority(),
            address(host),
            keccak256("COLLECTION_METADATA"),
            type(IStreamCollectionMetadataV1).interfaceId
        );
        core.set(keccak256("COLLECTION_METADATA"), address(host), false);
    }

    function _canonicalAttestation(P.Publication memory pub, string memory uri)
        internal
        pure
        returns (T.Attestation memory p, bytes memory statement)
    {
        statement = abi.encode(uint16(1), pub);
        bool intent = pub.recordType == keccak256("ARTIST_INTENT");
        p = T.Attestation(
            1,
            intent ? 7 : 8,
            pub.subjectId,
            intent ? pub.candidateRecordHash : bytes32(0),
            keccak256("6529STREAM_ARTIST_RECORD_PUBLICATION_V1"),
            keccak256(statement),
            uri
        );
    }

    function _canonicalRecordHash(
        IStreamPreservationRecords.CollectionRecord memory r,
        P.Publication memory pub
    ) internal view returns (bytes32) {
        bytes32[14] memory words;
        words[0] = keccak256("6529stream.preservation-record.v2");
        words[1] = bytes32(block.chainid);
        words[2] = bytes32(uint256(uint160(pub.metadataHost)));
        words[3] = bytes32(uint256(uint160(address(core))));
        words[4] = bytes32(uint256(uint160(pub.recorder)));
        words[5] = bytes32(uint256(1));
        words[6] = r.recordType;
        words[7] = r.subjectId;
        words[8] = keccak256(
            abi.encode(
                r.contentHash.algorithm,
                keccak256(r.contentHash.digest),
                r.contentHash.canonicalizationId
            )
        );
        words[9] = keccak256(bytes(r.uri));
        words[10] = r.schemaId;
        words[11] = r.signatureScheme;
        words[12] = keccak256(
            abi.encode(
                r.signatureHash.algorithm,
                keccak256(r.signatureHash.digest),
                r.signatureHash.canonicalizationId
            )
        );
        words[13] = bytes32(uint256(r.effectiveAt));
        return keccak256(abi.encode(words));
    }

    function _publicationHost() internal returns (ArtistPublicationHostFixture host) {
        actualSaleRegistryFixture = true;
        setUp();
        _accept();
        host = new ArtistPublicationHostFixture(address(core));
        _saleRegister(
            saleModules,
            factory.governanceAuthority(),
            address(host),
            keccak256("COLLECTION_METADATA"),
            type(IStreamArtistRecordPublicationHost).interfaceId
        );
        core.set(keccak256("COLLECTION_METADATA"), address(host), false);
    }

    function _publicationTerms(ArtistPublicationHostFixture host, bool intent)
        internal
        view
        returns (P.Publication memory pub, T.Attestation memory p, bytes memory statement)
    {
        pub = P.Publication(
            address(host),
            address(artist),
            1,
            keccak256("exact unit collection subject"),
            intent ? keccak256("ARTIST_INTENT") : keccak256("ARTIST_STATEMENT"),
            intent ? keccak256("STREAM_ARTIST_INTENT_V1") : keccak256("STREAM_ARTIST_INTERVIEW_V1"),
            keccak256("JCS_RFC8785"),
            1,
            keccak256("actual unit publication bytes"),
            keccak256("urn:publication-unit"),
            uint64(block.timestamp),
            bytes32(0)
        );
        pub.candidateRecordHash = host.candidateHash(pub);
        statement = abi.encode(uint16(1), pub);
        p = T.Attestation(
            1,
            intent ? 7 : 8,
            pub.subjectId,
            intent ? pub.candidateRecordHash : bytes32(0),
            keccak256("6529STREAM_ARTIST_RECORD_PUBLICATION_V1"),
            keccak256(statement),
            "urn:publication-unit"
        );
    }

    function _publicationExpected(T.Attestation memory p, T.Authorization memory a, uint8 class_)
        internal
        view
        returns (bytes32)
    {
        bytes32[16] memory words;
        words[0] = keccak256("6529STREAM_ARTIST_ATTESTATION_RECORD_V1");
        words[1] = bytes32(block.chainid);
        words[2] = bytes32(uint256(uint160(address(ingress))));
        words[3] = bytes32(uint256(uint160(address(core))));
        words[4] = bytes32(uint256(1));
        words[5] = bytes32(uint256(p.subjectKind));
        words[6] = p.subjectId;
        words[7] = p.subjectStateHash;
        words[8] = p.schemaId;
        words[9] = p.statementHash;
        words[10] = keccak256(bytes(p.statementURI));
        words[11] = artistId;
        words[12] = bytes32(uint256(uint160(address(artist))));
        words[13] = bytes32(uint256(class_));
        words[14] = bytes32(a.nonce);
        words[15] = bytes32(uint256(a.time));
        return keccak256(abi.encode(words));
    }

    function executePublicationSafe(address target, bytes calldata data) external {
        require(executeSafe(artist, keys, target, 0, data, 0), "actual publication Safe wrapper");
    }

    /// @dev Actual registered native record/facts and actual artist owners. Core and Executor remain unit boundaries.
    function _saleFixture(uint8 scope_) internal returns (Sale.Consent memory p) {
        actualSaleRegistryFixture = true;
        saleScopeFixture = scope_;
        setUp();
        _accept();
        _policy();
        _payout();
        _economics();
        _ratify();
        _attestations();
        (bool configured, bytes memory reason) = address(manager).call(_configureData());
        if (!configured) assembly ("memory-safe") { revert(add(reason, 32), mload(reason)) }
        StreamRevenueEscrow escrow = new StreamRevenueEscrow(
            factory,
            factory.governanceAuthority(),
            IStreamGasParameterHost.GasParameterConfig("FLUSH_GAS_FLOOR", 12_000_000, 12_000_000, 3)
        );
        StreamPrimarySaleSettlement recorder =
            new StreamPrimarySaleSettlement(primary, address(saleModules), escrow);
        nativeSale =
            new StreamNativeFixedPriceSaleAdapter(manager, recorder, address(artist), ingress);
        _saleRegister(
            saleModules,
            factory.governanceAuthority(),
            address(nativeSale),
            keccak256("NATIVE_PRIMARY_SALE_ADAPTER"),
            type(IStreamNativeSaleBinding).interfaceId
        );
        bytes32 id = nativeSale.registerSale(
            IStreamNativeFixedPriceSaleAdapter.SaleConfig(
                1,
                PHASE,
                1000,
                0,
                type(uint64).max,
                POLICY,
                primary.resolvePrimaryAssignment(1, 0, PRIMARY).assignmentHash
            )
        );
        p = Sale.Consent(1, address(nativeSale), id, nativeSale.saleRecord(id).configHash);
    }

    function _saleAuthorization(Sale.Consent memory p) internal returns (T.Authorization memory a) {
        a = _authorization(false);
        a.signature = _signature(ingress.saleConsentDigest(p, a));
    }

    function _requireSale(Sale.Consent memory p) internal {
        vm.prank(p.saleAdapter);
        ingress.requireSaleConsent(p.collectionId, p.saleId, p.saleConfigHash);
    }

    function _freshTemplateFixture(uint8 kind) internal {
        // A separate deployment with a prebinding template; no existing assignment or history is reset.
        templateFixtureKind = kind;
        setUp();
    }

    function _installInitialPrimary(address governance, bytes32 profile) internal {
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

    function _revisionProposal(bytes memory document)
        internal
        view
        returns (StreamArtistIdentityRevisionTypes.Revision memory)
    {
        return StreamArtistIdentityRevisionTypes.Revision(
            artistId,
            ingress.operativeIdentityRecord(artistId),
            keccak256(document),
            "urn:identity:revision"
        );
    }

    function _reviseDocument(bytes memory document) internal returns (bytes32 record) {
        StreamArtistIdentityRevisionTypes.Revision memory p = _revisionProposal(document);
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.identityRevisionDigest(p, a));
        return ingress.recordIdentityRevision(p, a, document, "Revised Artist");
    }

    function _otherOwnerRoots() internal view returns (bytes32) {
        T.Snapshot[7] memory snapshots;
        for (uint256 i; i < 7; ++i) {
            if (i != 2) snapshots[i] = IStreamArtistOwner(suite.owners[i]).ownerStateSnapshotV2();
        }
        return keccak256(abi.encode(snapshots));
    }

    function recordUnitPersonhood(bytes32 state) external {
        require(msg.sender == address(this), "test self only");
        _attest(10, artistId, state, keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1"));
    }

    function _identityRevisionReplayKey(bytes32 surface, bytes32 scope)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                address(ingress),
                address(coordinator),
                address(archive),
                suite.owners[2],
                keccak256("domain:identity_authority"),
                surface,
                scope
            )
        );
    }

    function _contentProposal(bytes32 candidate) internal view returns (Content.Consent memory) {
        return Content.Consent(
            1, address(metadata), keccak256("SCRIPT"), metadata.familyState(1, candidate)
        );
    }

    function _contentConsent(bytes32 candidate) internal returns (bytes32) {
        Content.Consent memory p = _contentProposal(candidate);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.contentConsentDigest(p, a));
        return ingress.recordContentConsent(p, a);
    }

    function _contentFreezeProposal() internal view returns (Content.Freeze memory) {
        bytes32[] memory locks = new bytes32[](1);
        locks[0] = keccak256("SCRIPT");
        return Content.Freeze(1, address(metadata), locks, metadata.artistContentFreezeState(1));
    }

    function _contentFreeze() internal returns (bytes32) {
        Content.Freeze memory p = _contentFreezeProposal();
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.contentFreezeDigest(p, a));
        return ingress.authorizeArtistContentFreeze(p, a);
    }

    function _cancelAuthorization(StreamArtistAuthorizationTypes.Revocation memory p)
        internal
        returns (bytes32)
    {
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.authorizationRevocationDigest(p, a));
        return ingress.revokeArtistAuthorization(p, a);
    }

    function _consumeDelegateIdentityOnly(
        T.EconomicsConsent memory p,
        T.Authorization memory a,
        bytes32 grant,
        address signer,
        bytes32 digest
    ) internal returns (bytes32) {
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

    function _collaboratorIdentity(bool direct) internal {
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

    function _collaborativeProposal(bool paid) internal returns (C.BindingAcceptance memory p) {
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
        internal
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

    function _collaboratorPayout(address account) internal {
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
        internal
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

    function _termination(uint256 collectionId) internal view returns (L.Termination memory p) {
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(collectionId);
        p = L.Termination(
            collectionId,
            b.generation,
            b.bindingHash,
            keccak256("incorrect proposed terms"),
            "urn:binding:reason"
        );
    }

    function _repropose(uint256 collectionId) internal {
        ingress.proposeArtistBinding(
            collectionId, _proposal(artistId), bytes("unit identity document"), "Artist Safe"
        );
    }

    function _directTimeExercise(bool useSafe) internal {
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
        R.AuthorityFact memory currentAuthority;
        (payload, currentAuthority) = abi.decode(payload, (bytes, R.AuthorityFact));
        require(
            currentAuthority.artistId == artistId && currentAuthority.authorityAddress == account
                && currentAuthority.authorityClass == 1 && currentAuthority.status == 1,
            "actual current authority snapshot"
        );
        bytes32 operative;
        (payload, operative) = abi.decode(payload, (bytes, bytes32));
        require(operative == ingress.operativeIdentityRecord(artistId), "snapshotted identity fact");
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
        internal
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

    OfficialSafe internal delegateSafe;
    uint256[] internal delegateKeys;

    function _delegateSetup() internal {
        delegateKeys = new uint256[](2);
        delegateKeys[0] = 0xDE1;
        delegateKeys[1] = 0xDE2;
        delegateSafe = createOfficialSafe(safeComponents, safeOwnerAddresses(delegateKeys), 2, 29);
    }

    function _delegation(uint256 scope, uint32 caps, uint64 start, uint64 expiry, uint64 uses)
        internal
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

    function _grant(D.Grant memory p) internal returns (bytes32 record) {
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

    function _grantRecord(D.Grant memory p, uint256 nonce) internal view returns (bytes32) {
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

    function _revoke(bytes32 record) internal returns (bytes32 revoked) {
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

    function _delegateSignature(bytes32 digest) internal returns (bytes memory) {
        return
            safeThresholdSignature(
                delegateKeys, safeMessageDigest(delegateSafe, abi.encode(digest))
            );
    }

    function _currentEconomics(address resolver)
        internal
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
        internal
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

    uint256[] internal rotationKeys;
    OfficialSafe internal rotationSafe;

    function _rotateCollaboratorToNewSafe() internal returns (bytes32 record) {
        R.Rotation memory p = R.Rotation(
            collaboratorId,
            address(delegateSafe),
            address(rotationSafe),
            keccak256("collaborator rotates"),
            bytes32(0)
        );
        T.Authorization memory oldA = T.Authorization(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(collaboratorId).nonceHint,
            uint64(block.timestamp + 1 days),
            ""
        );
        oldA.signature = safeThresholdSignature(
            delegateKeys,
            safeMessageDigest(delegateSafe, abi.encode(ingress.rotationDigest(p, oldA)))
        );
        T.Authorization memory newA = T.Authorization(0, oldA.time, "");
        newA.signature = safeThresholdSignature(
            rotationKeys,
            safeMessageDigest(rotationSafe, abi.encode(ingress.rotationAcceptanceDigest(p, newA)))
        );
        record = ingress.rotateArtistAddress(p, oldA, newA);
        vm.warp(ingress.rotationRecord(record).transition.contestEndsAt);
        ingress.executeArtistRotation(collaboratorId, record);
    }

    function _newRotationSafe(uint256 salt) internal {
        rotationKeys = new uint256[](2);
        rotationKeys[0] = 0xCA1100 + salt;
        rotationKeys[1] = 0xCA2200 + salt;
        rotationSafe = createOfficialSafe(safeComponents, safeOwnerAddresses(rotationKeys), 2, salt);
    }

    function _rotationTerms(bytes32 previous) internal view returns (R.Rotation memory) {
        return R.Rotation(
            artistId, address(artist), address(rotationSafe), keccak256("artist rotation"), previous
        );
    }

    function _rotationAuthorizations(R.Rotation memory p)
        internal
        returns (T.Authorization memory oldA, T.Authorization memory newA)
    {
        oldA = _authorization(false);
        oldA.signature = safeThresholdSignature(
            keys, safeMessageDigest(artist, abi.encode(ingress.rotationDigest(p, oldA)))
        );
        (, uint256 hint) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, 0);
        newA = T.Authorization(hint, uint64(block.timestamp + 1 days), "");
        newA.signature = safeThresholdSignature(
            rotationKeys,
            safeMessageDigest(rotationSafe, abi.encode(ingress.rotationAcceptanceDigest(p, newA)))
        );
    }

    function _stageRotation(bytes32 previous) internal returns (bytes32 record) {
        R.Rotation memory p = _rotationTerms(previous);
        (T.Authorization memory oldA, T.Authorization memory newA) = _rotationAuthorizations(p);
        record = ingress.rotateArtistAddress(p, oldA, newA);
    }

    function _executeTimedRotation(bytes32 record) internal {
        R.RotationRecord memory r = ingress.rotationRecord(record);
        vm.warp(r.transition.contestEndsAt);
        ingress.executeArtistRotation(artistId, record);
    }

    function _adoptRotatedSafe() internal {
        artist = rotationSafe;
        keys = rotationKeys;
        nextNonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
    }

    function _guardianRecord(
        address[] memory guardians_,
        uint32 threshold,
        uint64 floor,
        uint256 nonce
    ) internal returns (bytes32 record) {
        R.GuardianSet memory p = R.GuardianSet(artistId, guardians_, threshold, floor);
        T.Authorization memory a = T.Authorization(nonce, uint64(block.timestamp), "");
        a.signature = safeThresholdSignature(
            keys, safeMessageDigest(artist, abi.encode(ingress.guardianSetDigest(p, a)))
        );
        record = ingress.setArtistGuardians(p, a);
        nextNonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
    }

    function executeRotationNewSafe(bytes calldata data) external returns (bool) {
        require(msg.sender == address(this), "test only");
        return executeSafe(rotationSafe, rotationKeys, address(ingress), 0, data, 0);
    }

    function _rotationContestMaturityCase(uint256 boundary) internal {
        rotationContestFixture = false;
        setUp();
        _all();
        bytes32 priorIdentity = ingress.operativeIdentityRecord(artistId);
        (address priorPayout, bytes32 priorDesignation) = ingress.artistPayoutAccount(artistId);
        bytes32 priorGuardians = _guardianRecord(new address[](0), 0, 0, nextNonce);
        _newRotationSafe(9200 + boundary);
        bytes32 transition = _stageRotation(bytes32(0));
        _executeTimedRotation(transition);
        OfficialSafe priorSafe = artist;
        uint256[] memory priorKeys = keys;
        _adoptRotatedSafe();
        uint64 end = ingress.rotationRecord(transition).transition.postWindowEndsAt;
        bytes memory document = bytes("provisional contested document");
        StreamArtistIdentityRevisionTypes.Revision memory p =
            StreamArtistIdentityRevisionTypes.Revision(
                artistId, priorIdentity, keccak256(document), "urn:contested"
            );
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.identityRevisionDigest(p, a));
        bytes32 revisionRecord = ingress.recordIdentityRevision(p, a, document, "Provisional");
        T.PayoutDesignation memory payout =
            T.PayoutDesignation(artistId, address(artist), priorDesignation);
        a = _authorization(true);
        a.signature = _signature(ingress.payoutDesignationDigest(payout, a));
        bytes32 payoutRecord = ingress.recordPayoutDesignation(payout, a);
        address[] memory members = new address[](1);
        members[0] = address(artist);
        bytes32 guardianRecord = _guardianRecord(members, 1, 0, nextNonce);
        vm.warp(uint256(end) + boundary - 1);
        require(
            executeSafe(
                priorSafe,
                priorKeys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistIdentityContest.contestArtistIdentity,
                    (
                        artistId,
                        transition,
                        keccak256("actual compromise evidence"),
                        keccak256("actual compromise reason")
                    )
                ),
                0
            ),
            "actual prior Safe files compromise"
        );
        vm.warp(uint256(end) + 2);
        bool mature = boundary != 0;
        require(
            ingress.operativeIdentityRecord(artistId)
                == (mature ? keccak256(document) : priorIdentity),
            "contest identity maturity boundary"
        );
        (address actualPayout,) = ingress.artistPayoutAccount(artistId);
        (,,, bytes32 actualGuardians) = ingress.guardianSet(artistId);
        require(actualPayout == (mature ? address(artist) : priorPayout), "contest payout boundary");
        require(
            actualGuardians == (mature ? guardianRecord : priorGuardians),
            "contest guardian boundary"
        );
        require(
            ingress.identityRevisionRecord(revisionRecord).recordHash == revisionRecord
                && IStreamArtistPayoutOwner(suite.owners[5])
                    .designationRecord(payoutRecord)
                    .artistId == artistId,
            "provisional history never erased"
        );
        require(
            _closed(_mintCall())
                && IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).status == 4,
            "maturity never clears actual contested status"
        );
    }

    function _contestData(bytes32 subject) internal view returns (bytes memory) {
        return abi.encodeCall(
            IStreamArtistIdentityContest.contestArtistIdentity,
            (artistId, subject, keccak256("compromise evidence"), keccak256("compromise reason"))
        );
    }

    function _selfGuardian() internal returns (bytes32 record) {
        address[] memory guardians = new address[](1);
        guardians[0] = address(artist);
        return _guardianRecord(guardians, 1, 0, nextNonce);
    }

    function _pendingContestGuardianCase(bool useCaptured) internal {
        bytes32 setA = _selfGuardian();
        _newRotationSafe(11001);
        bytes32 rotation = _stageRotation(0);
        address[] memory members = new address[](1);
        members[0] = address(rotationSafe);
        bytes32 setB = _guardianRecord(members, 1, 0, nextNonce);
        require(
            executeSafe(
                useCaptured ? artist : rotationSafe,
                useCaptured ? keys : rotationKeys,
                address(ingress),
                0,
                _contestData(rotation),
                0
            ),
            "operative or captured actual Safe"
        );
        Contest.Record memory item =
            ingress.identityContestRecord(ingress.latestIdentityContest(artistId));
        require(
            item.guardianSetRecordHash == setB && item.capturedGuardianSetRecordHash == setA
                && ingress.rotationRecord(rotation).transition.phase == 3,
            "both membership facts and terminal pending"
        );
        (,,,, bytes32 pending) = ingress.pendingRotation(artistId);
        require(pending == 0, "pending cancelled");
    }

    function _governedContest(uint8 actionClass, uint8 fault) internal {
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        bytes32 reason = keccak256("compromise reason");
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:unit:contest"
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = ingress.identityContestGovernanceContext(
            artistId, 0, keccak256("compromise evidence"), reason
        );
        if (fault == 1) scope = keccak256("wrong scope");
        if (fault == 2) oldHash = keccak256("wrong old state");
        if (fault == 3) newHash = keccak256("wrong intent");
        if (fault == 4) {
            authority.configureContestReads(
                suite.roleRegistry, address(artist), keccak256("wrong reason"), "urn:unit"
            );
        }
        if (fault == 5) {
            authority.configureContestReads(address(core), address(artist), reason, "urn:unit");
        }
        if (fault == 6) ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), false);
        authority.executeModuleContext(
            address(ingress), _contestData(0), actionClass, scope, oldHash, newHash
        );
    }

    function executeGovernedContest(uint8 actionClass, uint8 fault) external {
        require(msg.sender == address(this), "test-only");
        _governedContest(actionClass, fault);
    }

    function _successorTerms(address account, uint8 kind)
        internal
        view
        returns (Succ.Designation memory)
    {
        return Succ.Designation(
            artistId, account, kind, 4095, keccak256("estate conditions"), bytes32(0)
        );
    }

    function _successionRecord(Succ.Designation memory p) internal returns (bytes32 record) {
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.successorDesignationDigest(p, a));
        return ingress.recordSuccessorDesignation(p, a);
    }

    function _directiveTerms(uint32 forbidden)
        internal
        view
        returns (Succ.Directive memory, Succ.PublicDocument memory)
    {
        Succ.PublicDocument memory document =
            Succ.PublicDocument(keccak256("legal instrument"), keccak256("payout intent"));
        return (
            Succ.Directive(
                artistId,
                uint32(4095) & ~forbidden,
                forbidden,
                keccak256(
                    ingress.previewEstateDirectivePayload(
                        uint32(4095) & ~forbidden, forbidden, document
                    )
                )
            ),
            document
        );
    }

    function _directiveRecord(uint32 forbidden) internal returns (bytes32 record) {
        (Succ.Directive memory p, Succ.PublicDocument memory document) = _directiveTerms(forbidden);
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.estateDirectiveDigest(p, a));
        return ingress.recordEstateDirective(p, a, document);
    }

    function _successionTyped(bytes32 message) internal view returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamArtistRegistry"),
                keccak256("1"),
                block.chainid,
                address(ingress)
            )
        );
        return keccak256(abi.encodePacked(hex"1901", domain, message));
    }

    function _successionMaturityCase(uint8 boundary) internal {
        bytes32 baseS = _successionRecord(_successorTerms(address(0xAA), 1));
        bytes32 baseD = _directiveRecord(0);
        OfficialSafe prior = artist;
        uint256[] memory priorKeys = keys;
        _newRotationSafe(16020 + boundary);
        bytes32 rotation = _stageRotation(0);
        _executeTimedRotation(rotation);
        _adoptRotatedSafe();
        bytes32 candidateS = _successionRecord(_successorTerms(address(0xBB), 1));
        bytes32 candidateD = _directiveRecord(4);
        uint64 end = ingress.rotationRecord(rotation).transition.postWindowEndsAt;
        require(
            ingress.operativeSuccessorRecord(artistId) == baseS
                && ingress.operativeEstateDirective(artistId) == baseD,
            "candidates not ready"
        );
        vm.warp(uint256(end) + boundary - 1);
        require(
            executeSafe(prior, priorKeys, address(ingress), 0, _contestData(rotation), 0),
            "actual prior Safe contest"
        );
        vm.warp(uint256(end) + 2);
        require(
            ingress.operativeSuccessorRecord(artistId) == (boundary == 0 ? baseS : candidateS)
                && ingress.operativeEstateDirective(artistId)
                    == (boundary == 0 ? baseD : candidateD),
            "exact half-open maturity"
        );
        require(
            ingress.successorDesignationRecord(candidateS).recordHash == candidateS
                && ingress.estateDirectiveRecord(candidateD).recordHash == candidateD,
            "all immutable history retained"
        );
    }

    event SuccessionReaderDeploymentProof(
        address indexed helper,
        bytes helperRuntime,
        address indexed registry,
        address indexed reader
    );

    function _estatePendingFixture(uint32 capabilities)
        internal
        returns (Estate.Execution memory execution)
    {
        if (address(delegateSafe) == address(0)) _delegateSetup();
        Succ.Designation memory d = _successorTerms(address(delegateSafe), 2);
        d.grantedCapabilities = capabilities;
        bytes32 designation = _successionRecord(d);
        (bytes32 evidence, bytes32 coverage) = _estateArchiveEvidence(artistId);
        Estate.Request memory request =
            Estate.Request(artistId, address(delegateSafe), evidence, designation, coverage);
        T.Authorization memory a = T.Authorization(0, uint64(block.timestamp + 1 days), "");
        require(
            executeSafe(
                delegateSafe,
                delegateKeys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistEstateActivation.requestEstateActivation, (request, a)),
                0
            ),
            "actual successor Safe request"
        );
        (,, bytes32 record) = ingress.estateActivationState(artistId);
        return Estate.Execution(artistId, record, coverage);
    }

    function _assertEstateCancellationEvent(
        Vm.Log[] memory logs,
        bytes32 record,
        uint256 expectedCount
    ) internal view {
        bytes32 topic = keccak256(
            "ArtistEstateActivationCancelled(uint16,bytes32,address,uint8,bytes32)"
        );
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != suite.owners[2] || logs[i].topics.length == 0
                    || logs[i].topics[0] != topic
            ) continue;
            require(
                logs[i].topics.length == 3 && logs[i].topics[1] == artistId
                    && logs[i].topics[2] == bytes32(uint256(uint160(address(artist)))),
                "exact living cancellation emitter/topics"
            );
            require(
                keccak256(logs[i].data) == keccak256(abi.encode(uint16(1), uint8(1), record)),
                "exact living cancellation data"
            );
            ++count;
        }
        require(count == expectedCount, "exact cancellation event count");
    }

    function _estateLivingRevisionAt(uint256 boundary) internal {
        Estate.Execution memory p = _estatePendingFixture(4095);
        (Estate.RequestRecord memory before_,,) =
            ingress.estateActivationRecord(p.expectedActivationRecordHash);
        if (boundary == 1) vm.warp(before_.noticeEndsAt);
        if (boundary == 2) vm.warp(uint256(before_.noticeEndsAt) + 1);
        bytes memory document = bytes("living principal cancels active estate");
        StreamArtistIdentityRevisionTypes.Revision memory revision =
            StreamArtistIdentityRevisionTypes.Revision(
                artistId,
                ingress.operativeIdentityRecord(artistId),
                keccak256(document),
                "urn:living-after-estate-request"
            );
        T.Authorization memory a = T.Authorization(nextNonce++, uint64(block.timestamp), "");
        vm.recordLogs();
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistIdentityRevision.recordIdentityRevision,
                    (revision, a, document, "Living artist")
                ),
                0
            ),
            "actual living Safe revision"
        );
        _assertEstateCancellationEvent(vm.getRecordedLogs(), p.expectedActivationRecordHash, 1);
        (,, bytes32 pending) = ingress.estateActivationState(artistId);
        (, uint8 phase,) = ingress.estateActivationRecord(p.expectedActivationRecordHash);
        require(
            pending == 0 && phase == 3
                && ingress.operativeIdentityRecord(artistId) == keccak256(document),
            "cancelling revision is operative and request terminal"
        );
        bytes32 key = _identityRevisionReplayKey(
            keccak256("identity_authority.replay.activation_cancellation_key"),
            p.expectedActivationRecordHash
        );
        T.ReplayCell memory cell = IStreamArtistOwner(suite.owners[2]).replayCell(key);
        require(
            cell.status == 2 && cell.commitment == p.expectedActivationRecordHash,
            "actual cancellation replay"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                Estate.InvalidEstateActivation.selector, p.expectedActivationRecordHash
            )
        );
        ingress.executeEstateActivation(p);
    }

    function _estatePendingContest(bool named) internal {
        _selfGuardian();
        Estate.Execution memory p = _estatePendingFixture(4095);
        bytes32 subject = named ? p.expectedActivationRecordHash : bytes32(0);
        uint64 observed = uint64(block.timestamp);
        T.Identity memory before_ = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        bytes32 unchanged = _roots();
        bytes32 unknown = keccak256("unknown estate subject");
        vm.expectRevert(abi.encodeWithSelector(Contest.InvalidContestSubject.selector, unknown));
        ingress.contestArtistIdentity(
            artistId, unknown, keccak256("compromise evidence"), keccak256("compromise reason")
        );
        require(
            _roots() == unchanged,
            "unknown subject cannot change state before same-context valid control"
        );
        vm.recordLogs();
        require(
            executeSafe(artist, keys, address(ingress), 0, _contestData(subject), 0),
            "guardian Safe contests actual pending estate"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        _assertEstateCancellationEvent(logs, p.expectedActivationRecordHash, 0);
        bytes32 contest = ingress.latestIdentityContest(artistId);
        Contest.Record memory actual = ingress.identityContestRecord(contest);
        require(
            actual.terms.subjectRecordHash == subject
                && actual.pendingTransitionRecordHash == p.expectedActivationRecordHash,
            "contest binds actual named or general pending cohort"
        );
        R.TransitionState memory transition =
            ingress.artistTransitionState(p.expectedActivationRecordHash);
        (, uint8 phase,) = ingress.estateActivationRecord(p.expectedActivationRecordHash);
        (,, bytes32 pending) = ingress.estateActivationState(artistId);
        require(
            phase == 3 && transition.phase == 3 && transition.contestedAt == observed
                && pending == 0,
            "named/general pending cancellation is terminal"
        );
        T.Identity memory after_ = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        require(
            after_.status == 4 && after_.nonceHint == before_.nonceHint
                && after_.lastAuthorityActionAt == before_.lastAuthorityActionAt,
            "guardian filing is not a living authority action"
        );
        bytes32 key = _identityRevisionReplayKey(
            keccak256("identity_authority.replay.activation_cancellation_key"),
            p.expectedActivationRecordHash
        );
        require(
            IStreamArtistOwner(suite.owners[2]).replayCell(key).status == 2,
            "actual cancellation cell consumed"
        );
        _assertDismissalCauseEvent(logs, ingress.currentIdentityContestCause(artistId));
    }

    function _estateActivateAndAdopt(uint32 caps) internal returns (Estate.Execution memory p) {
        p = _estatePendingFixture(caps);
        (Estate.RequestRecord memory item,,) =
            ingress.estateActivationRecord(p.expectedActivationRecordHash);
        vm.warp(item.noticeEndsAt);
        ingress.executeEstateActivation(p);
        artist = delegateSafe;
        keys = delegateKeys;
        nextNonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
    }

    function executeEstateAccelerator(Estate.Execution calldata p, uint8 class_, uint8 fault)
        external
    {
        require(msg.sender == address(this), "test-only");
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        Estate.AccelerationContext memory x = ingress.estateAccelerationContext(p);
        authority.configureContestReads(
            address(estateFixityRoles),
            address(0xB0AD),
            fault == 1 ? keccak256("wrong evidence") : x.evidenceHash,
            "urn:unit:estate"
        );
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(IStreamArtistEstateActivation.executeEstateActivation, (p)),
            class_,
            fault == 2 ? keccak256("wrong scope") : x.scopeHash,
            fault == 3 ? keccak256("wrong old state") : x.oldValueHash,
            fault == 4 ? keccak256("wrong new intent") : x.newValueHash
        );
    }

    function _estatePreparedRequest(uint32 caps) internal returns (Estate.Request memory p) {
        _delegateSetup();
        Succ.Designation memory d = _successorTerms(address(delegateSafe), 2);
        d.grantedCapabilities = caps;
        bytes32 designation = _successionRecord(d);
        (bytes32 evidence, bytes32 coverage) = _estateArchiveEvidence(artistId);
        return Estate.Request(artistId, address(delegateSafe), evidence, designation, coverage);
    }

    // Draft for the next test-only boundary; not part of the immutable225 run.

    function _estateSafeRead(address target, bytes memory data) internal {
        (bool ok, bytes memory actual) = target.staticcall(data);
        require(ok && actual.length != 0, "healthy canonical read before actual Safe call");
        uint256 nonce = artist.nonce();
        require(
            executeSafe(artist, keys, target, 0, data, 0) && artist.nonce() == nonce + 1,
            "actual Safe executes exact read selector"
        );
        (ok, data) = target.staticcall(data);
        require(
            ok && keccak256(data) == keccak256(actual), "Safe read leaves exact result unchanged"
        );
    }

    function _estateCoolCoverageState() internal {
        // Foundry cool(address) marks that account and all its slots cold:
        // https://github.com/foundry-rs/foundry/blob/master/crates/cheatcodes/spec/src/vm.rs
        safeVm.cool(address(core));
        safeVm.cool(address(ingress));
        safeVm.cool(address(estateCoverageProvider));
        safeVm.cool(address(estateCheckpointVerifier));
        safeVm.cool(suite.owners[2]);
    }

    function _estateExactOwnerBytes(bytes memory data, bytes memory expected) internal {
        (bool ok, bytes memory actual) = suite.owners[2].staticcall(data);
        require(
            ok && keccak256(actual) == keccak256(expected), "exact full encoded owner returndata"
        );
        _estateSafeRead(suite.owners[2], data);
    }

    function _scopePayload(uint8 scope, uint256 id, bytes32 profile, bool frozen_)
        internal
        view
        returns (T.EconomicsConsent memory p, T.FixedEconomicsCandidate memory candidate)
    {
        T.AssignmentFact memory fact =
            primary.previewArtistPrimaryAssignmentForScope(1, scope, id, profile, 0, frozen_);
        p = T.EconomicsConsent(1, address(primary), PRIMARY, scope, id, fact.assignmentHash);
        candidate = T.FixedEconomicsCandidate(profile, 0, 0, frozen_);
    }

    function _scopeRecord(T.EconomicsConsent memory p) internal returns (bytes32 record) {
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
        _artistCall(abi.encodeCall(IStreamArtistOnboarding.recordEconomicsConsent, (p, a)));
        T.Binding memory b = coordinator.reads().acceptedBinding(p.collectionId);
        return IStreamArtistEconomicsEvidence(suite.owners[6])
            .economicsRecordForBinding(p, b.artistId, b.generation, b.bindingHash);
    }

    function _clearPrimary(uint8 scope, uint256 id) internal {
        T.EconomicsConsent memory p = T.EconomicsConsent(1, address(primary), PRIMARY, scope, id, 0);
        _prospectiveConsent(p, T.FixedEconomicsCandidate(0, 0, 0, false));
        vm.prank(primary.owner());
        primary.clearPrimaryAssignment(PRIMARY, scope, id);
    }

    function _economicsReplayKey(bytes32 scope) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                address(ingress),
                address(coordinator),
                address(archive),
                suite.owners[6],
                keccak256("domain:consent_finality"),
                keccak256("consent_finality.replay.consent_key"),
                scope
            )
        );
    }

    /// @dev Corrective binding ingress is not implemented here. Only its authoritative Binding/Attribution
    ///      read boundary is replaced; both artists, Safe proofs, Identity/Consent/Archive remain actual.
    function _correctEconomicsBinding(address payout) internal returns (T.Binding memory b) {
        keys = new uint256[](2);
        keys[0] = 0xC0FF01;
        keys[1] = 0xC0FF02;
        artist = createOfficialSafe(safeComponents, safeOwnerAddresses(keys), 2, 24401);
        nextNonce = 0;
        (artistId,) = ingress.proposeArtistBinding(
            2, _proposal(0), bytes("unit identity document"), "Corrected Artist Safe"
        );
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.acceptanceDigest(2, a));
        ingress.acceptArtistBinding(2, a);
        T.PayoutDesignation memory designation = T.PayoutDesignation(artistId, payout, 0);
        a = _authorization(true);
        a.signature = _signature(ingress.payoutDesignationDigest(designation, a));
        ingress.recordPayoutDesignation(designation, a);
        b = IStreamArtistBindingOwner(suite.owners[0]).binding(2);
        b.generation = 2;
        b.bindingHash = keccak256("corrected binding generation 2");
        _mockEconomicsBinding(b);
    }

    function _mockEconomicsBinding(T.Binding memory b) internal {
        avm.mockCall(
            suite.owners[0], abi.encodeCall(IStreamArtistBindingOwner.binding, (1)), abi.encode(b)
        );
        avm.mockCall(
            suite.owners[4],
            abi.encodeCall(IStreamArtistAttributionOwner.attributionState, (1)),
            abi.encode(uint8(2), b.generation)
        );
    }

    function _associationEvent(
        Vm.Log[] memory logs,
        bytes32 record,
        T.EconomicsConsent memory p,
        T.Binding memory b,
        bytes32 original
    ) internal view {
        bytes32 topic = keccak256(
            "ArtistEconomicsConsentAssociated(uint16,bytes32,bytes32,bytes32,uint64,bytes32,bytes32)"
        );
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != suite.owners[6] || logs[i].topics[0] != topic) continue;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == record
                    && logs[i].topics[2] == b.artistId && logs[i].topics[3] == b.bindingHash
                    && keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(uint16(1), b.generation, keccak256(abi.encode(p)), original)
                        ),
                "exact association owner event"
            );
            ++count;
        }
        require(count == 1, "one association event");
    }

    function _literalPrimaryHash(
        uint8 scope,
        uint256 id,
        uint8 kind,
        bytes32 profile,
        bytes32 templateId,
        bytes32 templateEntries,
        bytes32 templateMetadata,
        bool frozen_
    ) internal view returns (bytes32) {
        bytes32 profileContext = kind == 1
            ? keccak256(
                abi.encode(
                    keccak256("6529STREAM_PRIMARY_ASSIGNMENT_PROFILE_CONTEXT_V1"),
                    factory.walletFor(profile),
                    factory.profileEntriesHash(profile),
                    factory.profileMetadataURIHash(profile)
                )
            )
            : bytes32(0);
        bytes32 templateContext = kind == 2
            ? keccak256(
                abi.encode(
                    keccak256("6529STREAM_PRIMARY_ASSIGNMENT_TEMPLATE_CONTEXT_V1"),
                    templateEntries,
                    templateMetadata
                )
            )
            : bytes32(0);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_ASSIGNMENT_V1"),
                block.chainid,
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PRIMARY_ASSIGNMENT_RESOLVER_CONTEXT_V1"),
                        address(primary),
                        address(factory),
                        address(factory.assetPolicyRegistry()),
                        factory.splitWalletRuntimeCodeHash()
                    )
                ),
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PRIMARY_ASSIGNMENT_SCOPE_CONTEXT_V1"),
                        PRIMARY,
                        scope,
                        id,
                        kind
                    )
                ),
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PRIMARY_ASSIGNMENT_POINTER_CONTEXT_V1"),
                        profile,
                        profileContext,
                        templateId,
                        templateContext
                    )
                ),
                bytes32(0),
                frozen_
            )
        );
    }

    function _economicsSafeRead(address target, bytes memory data, bytes memory expected) internal {
        (bool ok, bytes memory raw) = target.staticcall(data);
        require(ok && keccak256(raw) == keccak256(expected), "exact public preparation returndata");
        bytes32 roots = _roots();
        uint256 nonce = artist.nonce();
        this.executeTargetSafe(target, data);
        (ok, raw) = target.staticcall(data);
        require(
            ok && keccak256(raw) == keccak256(expected) && _roots() == roots
                && artist.nonce() == nonce + 1,
            "same complete result and no record effect around actual Safe CALL"
        );
    }

    function _literalRoyaltyHash(uint8 scope, uint256 id, bytes32 profile, uint16 bps, bool frozen_)
        internal
        view
        returns (bytes32)
    {
        IStreamSplitFactory splits = royalty.splitFactory();
        bytes32 profileContext = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_ASSIGNMENT_PROFILE_CONTEXT_V1"),
                profile == 0 ? address(0) : splits.walletFor(profile),
                profile == 0 ? bytes32(0) : splits.profileEntriesHash(profile),
                profile == 0 ? bytes32(0) : splits.profileMetadataURIHash(profile)
            )
        );
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_ASSIGNMENT_V1"),
                block.chainid,
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PRIMARY_ASSIGNMENT_RESOLVER_CONTEXT_V1"),
                        address(royalty),
                        address(splits),
                        address(splits.assetPolicyRegistry()),
                        splits.splitWalletRuntimeCodeHash()
                    )
                ),
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PRIMARY_ASSIGNMENT_SCOPE_CONTEXT_V1"),
                        keccak256("ROYALTY_ERC2981"),
                        scope,
                        id,
                        uint8(1)
                    )
                ),
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ROYALTY_ASSIGNMENT_POINTER_CONTEXT_V1"),
                        profile,
                        profileContext,
                        bps
                    )
                ),
                bytes32(0),
                frozen_
            )
        );
    }

    function _royaltyEvent(Vm.Log[] memory logs, bytes32 topic, uint256 id, bytes memory data)
        internal
        view
    {
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(royalty) || logs[i].topics[0] != topic) continue;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == keccak256("ROYALTY_ERC2981")
                    && logs[i].topics[2] == bytes32(uint256(2)) && logs[i].topics[3] == bytes32(id)
                    && keccak256(logs[i].data) == keccak256(data),
                "exact royalty event"
            );
            ++count;
        }
        require(count == 1, "one royalty event");
    }

    function _royaltyContextEvent(
        Vm.Log[] memory logs,
        uint256 id,
        bytes32 oldHash,
        bytes32 newHash,
        bytes32 policy,
        address actor
    ) internal view {
        bytes32 topic = keccak256(
            "RoyaltyAssignmentContext(uint16,uint256,uint256,bytes32,uint8,uint256,bytes32,bytes32,address)"
        );
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(royalty) || logs[i].topics[0] != topic) continue;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == bytes32(uint256(1))
                    && logs[i].topics[2] == bytes32(id) && logs[i].topics[3] == newHash
                    && keccak256(logs[i].data)
                        == keccak256(abi.encode(uint16(1), uint8(2), id, oldHash, policy, actor)),
                "exact key context including clear0"
            );
            ++count;
        }
        require(count == 1, "one royalty context");
    }

    function _assertRoyaltyCurrentArchive(
        T.EconomicsConsent memory p,
        T.Authorization memory a,
        bytes32 record,
        T.Binding memory b,
        bytes memory expectedEvidence
    ) internal view {
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(ingress),
                address(coordinator),
                uint16(15),
                address(artist),
                record
            )
        );
        (
            uint16 schema,
            bytes32 configuration,
            uint16 op,
            address actor,
            bytes32 archived,
            T.Snapshot[7] memory before_,
            T.Snapshot[7] memory after_,
            bytes memory payload
        ) = abi.decode(
            archive.artistEvidenceBytesV2(id, 1),
            (uint16, bytes32, uint16, address, bytes32, T.Snapshot[7], T.Snapshot[7], bytes)
        );
        (
            T.Binding memory captured,
            T.EconomicsConsent memory terms,
            T.Payout memory payout,
            T.Authorization memory authorization,
            T.SignerApproval memory proof,
            bytes memory current,
            IStreamArtistEconomicsEvidence.Association memory association
        ) = abi.decode(
            payload,
            (
                T.Binding,
                T.EconomicsConsent,
                T.Payout,
                T.Authorization,
                T.SignerApproval,
                bytes,
                IStreamArtistEconomicsEvidence.Association
            )
        );
        require(
            schema == 1 && configuration == coordinator.configurationHash() && op == 15
                && actor == address(artist) && archived == record
                && before_[6].revision + 1 == after_[6].revision
                && before_[2].revision + 1 == after_[2].revision
                && keccak256(abi.encode(captured)) == keccak256(abi.encode(b))
                && keccak256(abi.encode(terms)) == keccak256(abi.encode(p))
                && payout.recordHash != 0 && authorization.nonce == a.nonce && proof.direct
                && proof.signer == address(artist)
                && keccak256(current) == keccak256(expectedEvidence)
                && association.originalRecord == record && association.bindingHash == b.bindingHash
                && association.payloadHash == keccak256(abi.encode(p)),
            "exact current disabled evidence and one owner commit archived"
        );
    }

    function _royaltyScopePayload(
        uint8 scope,
        uint256 id,
        bytes32 profile,
        uint16 bps,
        bool frozen_
    )
        internal
        view
        returns (T.EconomicsConsent memory p, T.FixedEconomicsCandidate memory candidate)
    {
        T.AssignmentFact memory
            fact = royalty.previewArtistRoyaltyAssignmentForScope(
            1, scope, id, profile, bps, frozen_
        );
        p = T.EconomicsConsent(
            1, address(royalty), keccak256("ROYALTY_ERC2981"), scope, id, fact.assignmentHash
        );
        candidate = T.FixedEconomicsCandidate(profile, 0, bps, frozen_);
    }

    function _clearRoyalty(uint8 scope, uint256 id) internal {
        T.EconomicsConsent memory p =
            T.EconomicsConsent(1, address(royalty), keccak256("ROYALTY_ERC2981"), scope, id, 0);
        _prospectiveConsent(p, T.FixedEconomicsCandidate(0, 0, 0, false));
        vm.prank(royalty.owner());
        if (scope == 2) royalty.clearTokenRoyalty(id);
        else royalty.clearCollectionRoyalty(id);
    }

    // Operation13 runs the actual facade/Coordinator/owners/Archive. Only immutable executed
    // Finality return values below are prepared boundary facts: these cases do not execute FIN.
    struct ConfirmationEnvelope {
        uint16 schema;
        bytes32 configuration;
        uint16 operation;
        address actor;
        bytes32 transitionHash;
        T.Snapshot[7] prior;
        T.Snapshot[7] post;
        bytes payload;
    }

    struct ConfirmationPayload {
        T.Binding binding_;
        Confirmation.Transition transition;
        S.Record sanction;
        address finality;
        bytes32 finalityCodeHash;
        Confirmation.FinalityRecordEvidence record;
        StreamFinalityComponentExpectation[] components;
        StreamFinalityExecutionWitness execution;
        StreamFinalitySanctionArchiveWitness archiveWitness;
        bytes32 rawReadHash;
        bytes32 replayKey;
    }

    function _confirmationStored(bytes32 sanctionHash, uint256 count, uint256 uriLength)
        internal
        returns (Confirmation.Transition memory p, Confirmation.Observation memory o)
    {
        address actualFinality = address(sanctionFixture.registry());
        require(
            suite.owners[4].code.length <= 24576 && suite.owners[6].code.length <= 24576
                && StreamArtistConsentFinalityLifecycle(suite.owners[6]).consentWriterExtension()
                        .code.length <= 24576,
            "actual Attribution and Consent host/child EIP170"
        );
        o.binding_ = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        o.priorAttributionState = 2;
        o.sanction = ingress.sanctionRecord(sanctionHash);
        o.components = new StreamFinalityComponentExpectation[](count);
        StreamFinalityComponentState memory artistFact = ingress.finalityState(1);
        o.components[0] = StreamFinalityComponentExpectation(
            artistFact.componentType,
            artistFact.component,
            artistFact.interfaceId,
            artistFact.codeHash,
            artistFact.moduleVersion,
            artistFact.manifestHash,
            artistFact.dataHash
        );
        for (uint256 i = 1; i < count; ++i) {
            o.components[i] = StreamFinalityComponentExpectation(
                bytes32(i),
                address(uint160(i + 100)),
                bytes4(uint32(i)),
                keccak256(abi.encode(i)),
                bytes32(i + 1),
                bytes32(i + 2),
                bytes32(i + 3)
            );
        }
        for (uint256 i; i < count; ++i) {
            for (uint256 j = i + 1; j < count; ++j) {
                if (o.components[j].componentType < o.components[i].componentType) {
                    StreamFinalityComponentExpectation memory e = o.components[i];
                    o.components[i] = o.components[j];
                    o.components[j] = e;
                }
            }
        }
        string memory uri = string(new bytes(uriLength));
        bytes32 finalityHash =
            keccak256(abi.encode("prepared immutable execution boundary", sanctionHash));
        o.finalityRecord = StreamCollectionFinalityRecord(
            true,
            finalityHash,
            keccak256("stored manifest"),
            keccak256(bytes(uri)),
            uri,
            keccak256(abi.encode(keccak256("6529STREAM_FINALITY_COMPONENTS_V1"), o.components)),
            actualFinality,
            1001
        );
        o.executionWitness = StreamFinalityExecutionWitness(
            keccak256("stored executed action"),
            address(artist),
            keccak256("stored reason"),
            keccak256("stored proposer role mutation"),
            1
        );
        o.archiveWitness.proof = StreamFinalitySanctionArchiveProof(
            sanctionHash,
            keccak256("stored whole archive artifact"),
            keccak256("stored original completion")
        );
        o.archiveWitness.evidenceHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_SANCTION_ARCHIVE_EVIDENCE_V1"),
                block.chainid,
                address(core),
                actualFinality,
                IStreamFinalityDeploymentBindings(actualFinality).artifactCoverage(),
                o.archiveWitness.proof
            )
        );
        avm.mockCall(
            actualFinality,
            abi.encodeCall(IStreamArtworkFinalityRegistry.collectionFinalityRecord, (1)),
            abi.encode(o.finalityRecord)
        );
        avm.mockCall(
            actualFinality,
            abi.encodeCall(IStreamArtworkFinalityRegistry.finalityComponentCount, (1)),
            abi.encode(count)
        );
        avm.mockCall(
            actualFinality,
            abi.encodeCall(IStreamArtworkFinalityRegistry.finalityComponents, (1, 0, count)),
            abi.encode(o.components)
        );
        avm.mockCall(
            actualFinality,
            abi.encodeCall(
                IStreamCanonicalArtworkFinality.finalityExecutionWitness, (finalityHash)
            ),
            abi.encode(o.executionWitness)
        );
        avm.mockCall(
            actualFinality,
            abi.encodeCall(
                IStreamFinalitySanctionArchive.finalitySanctionArchiveWitness, (finalityHash)
            ),
            abi.encode(o.archiveWitness)
        );
        o = StreamArtistSanctionConfirmationReads.observe(
            suite,
            StreamArtistSanctionConfirmationReads.Pins(
                actualFinality,
                actualFinality.codehash,
                address(core).codehash,
                address(ingress).codehash,
                2000000
            ),
            1
        );
        p = Confirmation.Transition(
            1, artistId, o.binding_.generation, sanctionHash, finalityHash, 2
        );
    }

    function _confirmationScope(Confirmation.Transition memory p) internal pure returns (bytes32) {
        bytes32[7] memory w;
        w[0] = keccak256("6529STREAM_ARTIST_SANCTION_FINALIZATION_TRANSITION_V1");
        w[1] = bytes32(p.collectionId);
        w[2] = p.artistId;
        w[3] = bytes32(uint256(p.bindingGeneration));
        w[4] = p.sanctionRecordHash;
        w[5] = p.finalityRecordHash;
        w[6] = bytes32(uint256(p.priorAttributionState));
        return keccak256(abi.encode(w));
    }

    function _confirmationKey(Confirmation.Transition memory p) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                address(ingress),
                address(coordinator),
                address(archive),
                suite.owners[6],
                keccak256("domain:consent_finality"),
                keccak256("consent_finality.replay.sanction_finalization_transition_key"),
                _confirmationScope(p)
            )
        );
    }

    function _confirmationId(Confirmation.Transition memory p, address actor)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(ingress),
                address(coordinator),
                uint16(13),
                actor,
                _confirmationScope(p)
            )
        );
    }

    function _confirmationAfter(
        Confirmation.Transition memory p,
        Confirmation.Observation memory o,
        address actor,
        T.Snapshot[7] memory before_
    ) internal view {
        address actualFinality = address(sanctionFixture.registry());
        (uint8 state, uint64 generation) =
            IStreamArtistAttributionOwner(suite.owners[4]).attributionState(1);
        require(
            state == 3 && generation == p.bindingGeneration, "actual sanction-confirmed attribution"
        );
        for (uint256 i; i < 7; ++i) {
            T.Snapshot memory current = IStreamArtistOwner(suite.owners[i]).ownerStateSnapshotV2();
            if (i == 4 || i == 6) {
                require(
                    current.revision == before_[i].revision + 1
                        && current.recordChainTip == before_[i].recordChainTip,
                    "one commit, no primary record"
                );
            } else {
                require(
                    keccak256(abi.encode(current)) == keccak256(abi.encode(before_[i])),
                    "unrelated owner exact"
                );
            }
        }
        T.ReplayCell memory cell =
            IStreamArtistOwner(suite.owners[6]).replayCell(_confirmationKey(p));
        require(
            cell.commitment == p.sanctionRecordHash && cell.kind == 1 && cell.status == 2
                && cell.touchedRevision == before_[6].revision + 1,
            "literal six-field consumed replay lane"
        );
        bytes memory raw = archive.artistEvidenceBytesV2(_confirmationId(p, actor), 1);
        require(
            raw.length == 3744 + 224 * o.components.length && raw.length < 24576,
            "independent exact compact Archive size"
        );
        ConfirmationEnvelope memory e =
            abi.decode(bytes.concat(bytes32(uint256(32)), raw), (ConfirmationEnvelope));
        require(
            e.schema == 1 && e.configuration == coordinator.configurationHash() && e.operation == 13
                && e.actor == actor && e.transitionHash == _confirmationScope(p),
            "actual permissionless archive context"
        );
        ConfirmationPayload memory x =
            abi.decode(bytes.concat(bytes32(uint256(32)), e.payload), (ConfirmationPayload));
        require(
            keccak256(abi.encode(x.binding_)) == keccak256(abi.encode(o.binding_))
                && keccak256(abi.encode(x.transition)) == keccak256(abi.encode(p))
                && keccak256(abi.encode(x.sanction)) == keccak256(abi.encode(o.sanction))
                && x.finality == actualFinality && x.finalityCodeHash == actualFinality.codehash
                && x.record.fullRecordHash == keccak256(abi.encode(o.finalityRecord))
                && x.record.manifestURIHash
                    == keccak256(bytes(o.finalityRecord.finalityManifestURI))
                && x.record.finalityRecordHash == p.finalityRecordHash
                && x.rawReadHash == o.rawReadHash && x.rawReadHash == _confirmationTranscript(o)
                && x.record.manifestContentHash == o.finalityRecord.manifestContentHash
                && x.record.componentsHash == o.finalityRecord.componentsHash
                && x.record.manifestPointer == o.finalityRecord.manifestPointer
                && x.record.finalizedAt == o.finalityRecord.finalizedAt
                && x.replayKey == _confirmationKey(p),
            "exact saved association/record/transcript archival"
        );
        require(
            keccak256(abi.encode(x.components)) == keccak256(abi.encode(o.components))
                && keccak256(abi.encode(x.execution)) == keccak256(abi.encode(o.executionWitness))
                && keccak256(abi.encode(x.archiveWitness))
                    == keccak256(abi.encode(o.archiveWitness)),
            "entire ordered component and both witness facts archived"
        );
    }

    function _confirmationTranscript(Confirmation.Observation memory o)
        internal
        view
        returns (bytes32 h)
    {
        address f = address(sanctionFixture.registry());
        h = _confirmationTraceStep(
            h,
            suite.owners[0],
            abi.encodeCall(IStreamArtistBindingOwner.binding, (1)),
            abi.encode(o.binding_)
        );
        h = _confirmationTraceStep(
            h,
            suite.owners[4],
            abi.encodeCall(IStreamArtistAttributionOwner.attributionState, (1)),
            abi.encode(uint8(2), o.binding_.generation)
        );
        StreamFinalityComponentExpectation memory e;
        for (uint256 i; i < o.components.length; ++i) {
            if (o.components[i].componentType == keccak256("ARTIST_SANCTION")) e = o.components[i];
        }
        h = _confirmationTraceStep(
            h,
            address(ingress),
            abi.encodeCall(IStreamArtworkFinalityComponent.finalityState, (1)),
            abi.encode(
                StreamFinalityComponentState(
                        true,
                        e.componentType,
                        e.component,
                        e.interfaceId,
                        e.codeHash,
                        e.moduleVersion,
                        e.manifestHash,
                        e.dataHash
                    )
            )
        );
        h = _confirmationTraceStep(
            h,
            suite.owners[6],
            abi.encodeCall(IStreamArtistSanctionOwner.sanctionRecord, (o.sanction.recordHash)),
            abi.encode(o.sanction)
        );
        h = _confirmationTraceStep(
            h,
            f,
            abi.encodeCall(IStreamArtworkFinalityRegistry.collectionFinalityRecord, (1)),
            abi.encode(o.finalityRecord)
        );
        h = _confirmationTraceStep(
            h,
            f,
            abi.encodeCall(IStreamArtworkFinalityRegistry.finalityComponentCount, (1)),
            abi.encode(o.components.length)
        );
        h = _confirmationTraceStep(
            h,
            f,
            abi.encodeCall(
                IStreamArtworkFinalityRegistry.finalityComponents, (1, 0, o.components.length)
            ),
            abi.encode(o.components)
        );
        h = _confirmationTraceStep(
            h,
            f,
            abi.encodeWithSelector(IStreamFinalityDeploymentBindings.coreReads.selector),
            abi.encode(address(core))
        );
        h = _confirmationTraceStep(
            h,
            f,
            abi.encodeWithSelector(IStreamFinalityDeploymentBindings.sanctionReads.selector),
            abi.encode(address(ingress))
        );
        h = _confirmationTraceStep(
            h,
            f,
            abi.encodeWithSelector(IStreamFinalityDeploymentBindings.artifactCoverage.selector),
            abi.encode(IStreamFinalityDeploymentBindings(f).artifactCoverage())
        );
        h = _confirmationTraceStep(
            h,
            f,
            abi.encodeCall(
                IStreamCanonicalArtworkFinality.finalityExecutionWitness,
                (o.finalityRecord.finalityRecordHash)
            ),
            abi.encode(o.executionWitness)
        );
        h = _confirmationTraceStep(
            h,
            f,
            abi.encodeCall(
                IStreamFinalitySanctionArchive.finalitySanctionArchiveWitness,
                (o.finalityRecord.finalityRecordHash)
            ),
            abi.encode(o.archiveWitness)
        );
    }

    function _confirmationTraceStep(
        bytes32 previous,
        address target,
        bytes memory callData,
        bytes memory result
    ) internal pure returns (bytes32) {
        bytes32[4] memory words;
        words[0] = previous;
        words[1] = bytes32(uint256(uint160(target)));
        words[2] = keccak256(callData);
        words[3] = keccak256(result);
        return keccak256(abi.encode(words));
    }

    function _confirmationSnapshots() internal view returns (T.Snapshot[7] memory s) {
        for (uint256 i; i < 7; ++i) {
            s[i] = IStreamArtistOwner(suite.owners[i]).ownerStateSnapshotV2();
        }
    }

    function _sanctionPrepared()
        internal
        view
        returns (Q.Request memory q, Q.Prepared memory prepared)
    {
        q = sanctionFixture.request();
        prepared = ingress.prepareArtistSanction(q);
        q.terms.sanctionSubjectHash = StreamArtistSanctionHashes.subject(prepared.subject);
        q.terms.statementHash = keccak256(prepared.ceremony);
    }

    function _sanctionAuthorization(Q.Request memory q) internal returns (T.Authorization memory a) {
        a = _authorization(false);
        // Sanction always retains actual signature bytes, including when submitted by the principal.
        a.signature = safeThresholdSignature(
            keys, safeMessageDigest(artist, abi.encode(ingress.sanctionDigest(q.terms, a)))
        );
    }

    function _assertSavedSanction(bytes32 expected, bytes32 subject, address signer, uint8 class_)
        internal
        view
    {
        (bool valid, bytes32 record, address actualSigner, uint8 actualClass) =
            ingress.verifySanctionForSubject(0, 1, 0, 0, subject);
        require(
            valid && record == expected && actualSigner == signer && actualClass == class_,
            "exact saved sanction verification"
        );
    }

    ArtistSanctionFinalityFixture internal sanctionFixture;

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
        address modules;
        if (actualSaleRegistryFixture) {
            saleModules = new StreamModuleRegistry(
                IStreamGovernanceExecutor(governance),
                keccak256("artist sale registry"),
                "urn:artist-sale-registry"
            );
            modules = address(saleModules);
        } else {
            modules = address(new ArtistUnitModuleRegistry(governance));
        }
        core.set(keccak256("MODULE_REGISTRY"), modules, false);
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
        ArtistUnitRoles(suite.roleRegistry).configureOwner(governance);
        suite.validator = address(new StreamArtistRegistryValidatorBase());
        metadata = new ArtistUnitMetadata();
        metadata.configureCore(address(core));
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
        _deployEstateArchival(address(core), governance);
        sanctionFixture = new ArtistSanctionFinalityFixture();
        uint256 nonce = avm.getNonce(address(this));
        address predictedRegistry = avm.computeCreateAddress(address(this), nonce);
        address predictedArchive = avm.computeCreateAddress(address(this), nonce + 1);
        address predictedCoordinator = avm.computeCreateAddress(address(this), nonce + 12);
        ingress = new StreamArtistOnboardingRegistry(
            suite.core,
            suite.mintManager,
            predictedCoordinator,
            governance,
            address(estateCoverageProvider),
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
        if (rotationContestFixture) {
            suite.owners[2] = address(
                new ArtistRotationContestHarness(
                    predictedRegistry,
                    predictedCoordinator,
                    predictedArchive,
                    suite.core,
                    suite.mintManager
                )
            );
        } else {
            suite.owners[2] = address(
                new StreamArtistIdentityAuthority(
                    predictedRegistry,
                    predictedCoordinator,
                    predictedArchive,
                    suite.core,
                    suite.mintManager
                )
            );
        }
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
        ArtistUnitGovernance(governance)
            .configureContestReads(
                suite.roleRegistry, address(this), keccak256("finality unit"), "urn:unit"
            );
        address finality =
            sanctionFixture.deploy(address(core), address(metadata), address(ingress), governance);
        coordinator = new StreamArtistOnboardingCoordinator(suite, finality);
        ArtistUnitGovernance(governance)
            .configureContestReads(
                address(estateFixityRoles),
                address(this),
                keccak256("archival fixture"),
                "urn:unit:archival"
            );
        core.set(keccak256("ARTWORK_FINALITY_REGISTRY"), finality, false);
        core.set(keccak256("COLLECTION_METADATA"), address(metadata), false);
        require(address(coordinator) == predictedCoordinator, "fixed constructor pins");
        core.set(keccak256("ARTIST_REGISTRY"), address(ingress), false);
        core.set(keccak256("METADATA_ROUTER"), address(metadata), false);
        metadata.configureArtist(address(ingress));
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

    function _proposal(bytes32 id) internal view returns (T.BindingProposal memory p) {
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
        p.saleConsentScope = saleScopeFixture;
        p.collaborators = new T.CollaboratorRecord[](0);
        p.capabilityPolicyOverrides = new T.CapabilityPolicyOverride[](0);
    }

    /// @dev Matches the integrated wallet-line planning configuration; cold sizing is a separate gate.
    function _walletGasConfigs()
        internal
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

    function _authorization(bool signedAt) internal returns (T.Authorization memory) {
        return T.Authorization(
            nextNonce++, uint64(signedAt ? block.timestamp : block.timestamp + 1 days), ""
        );
    }

    function _signature(bytes32 digest) internal returns (bytes memory) {
        if (directArtistCalls) return "";
        return safeThresholdSignature(keys, safeMessageDigest(artist, abi.encode(digest)));
    }

    function _artistCall(bytes memory data) internal {
        if (directArtistCalls) {
            require(
                executeSafe(artist, keys, address(ingress), 0, data, 0), "direct Safe artist call"
            );
        } else {
            (bool ok, bytes memory reason) = address(ingress).call(data);
            if (!ok) assembly ("memory-safe") { revert(add(reason, 32), mload(reason)) }
        }
    }

    function _accept() internal {
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.acceptanceDigest(1, a));
        _artistCall(abi.encodeCall(IStreamArtistOnboarding.acceptArtistBinding, (1, a)));
    }

    function _policy() internal {
        T.PolicyConsent memory p = T.PolicyConsent(1, PHASE, POLICY);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.policyConsentDigest(p, a));
        _artistCall(abi.encodeCall(IStreamArtistOnboarding.recordPolicyConsent, (p, a)));
    }

    function _assertDismissalCauseEvent(Vm.Log[] memory logs, Dismissal.Cause memory cause)
        internal
        view
    {
        bytes32 topic = keccak256(
            "ArtistIdentityContestCauseCaptured(uint16,bytes32,bytes32,uint8,bytes32,address,bytes32,bytes32,uint64,address,uint8,uint8,bytes32,bytes32,bytes32,bytes32,bytes32)"
        );
        uint256 count;
        Dismissal.CauseFacts memory f = cause.facts;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == suite.owners[2] && logs[i].topics.length != 0
                    && logs[i].topics[0] == topic
            ) {
                ++count;
                require(
                    logs[i].topics.length == 3 && logs[i].topics[1] == f.artistId
                        && logs[i].topics[2] == cause.causeHash,
                    "actual cause emitter and indexed tuple"
                );
                require(
                    keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                f.kind,
                                f.referenceHash,
                                f.actor,
                                f.reasonHash,
                                f.evidenceHash,
                                f.enteredAt,
                                f.incumbent,
                                f.authorityClass,
                                f.priorStatus,
                                f.pendingTransitionHash,
                                f.executedTransitionHash,
                                f.previousCauseHash,
                                f.previousResolutionHash,
                                f.actorRetirementHash
                            )
                        ),
                    "exact cause event field order and values"
                );
            }
        }
        require(count == 1, "exactly one cause capture event");
    }

    function _dismissalRequest() internal view returns (Dismissal.Request memory) {
        return Dismissal.Request(
            artistId,
            ingress.currentIdentityContestCause(artistId).causeHash,
            ingress.latestIdentityContestDismissal(artistId),
            keccak256("dismissal evidence"),
            keccak256("dismissal reason"),
            false,
            bytes32(0)
        );
    }

    function _dismissalExecute(Dismissal.Request memory p, uint8 actionClass, uint8 fault)
        internal
        returns (bytes32 record)
    {
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        authority.configureContestReads(
            suite.roleRegistry, address(artist), p.reasonHash, "urn:unit:dismissal"
        );
        Dismissal.Context memory x = ingress.identityContestDismissalContext(p);
        if (fault == 1) x.scopeHash = keccak256("wrong scope");
        if (fault == 2) x.oldValueHash = keccak256("wrong state");
        if (fault == 3) x.newValueHash = keccak256("wrong intent");
        if (fault == 4) {
            authority.configureContestReads(
                suite.roleRegistry, address(artist), keccak256("wrong reason"), "urn:unit"
            );
        }
        if (fault == 5) {
            authority.configureContestReads(
                address(core), address(artist), p.reasonHash, "urn:unit"
            );
        }
        if (fault == 6) ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), false);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(IStreamArtistIdentityDismissal.dismissArtistIdentityContest, (p)),
            actionClass,
            x.scopeHash,
            x.oldValueHash,
            x.newValueHash
        );
        return ingress.latestIdentityContestDismissal(artistId);
    }

    function executeGovernedDismissal(Dismissal.Request calldata p, uint8 actionClass, uint8 fault)
        external
    {
        require(msg.sender == address(this), "test-only");
        _dismissalExecute(p, actionClass, fault);
    }

    function _dismissalPayout(address account) internal returns (bytes32 record) {
        (, bytes32 prior) = ingress.artistPayoutAccount(artistId);
        T.PayoutDesignation memory p = T.PayoutDesignation(artistId, account, prior);
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.payoutDesignationDigest(p, a));
        return ingress.recordPayoutDesignation(p, a);
    }

    function executeDismissalPayout(address account) external {
        require(msg.sender == address(this), "test-only");
        _dismissalPayout(account);
    }

    function _dismissalGuardianCause() internal {
        _selfGuardian();
        require(
            executeSafe(artist, keys, address(ingress), 0, _contestData(0), 0),
            "actual Safe files cause"
        );
    }

    function _dismissalReadParity(bytes memory data, bytes memory expected) internal view {
        (bool hostOk, bytes memory hostData) = suite.owners[2].staticcall(data);
        (bool facadeOk, bytes memory facadeData) = address(ingress).staticcall(data);
        require(
            hostOk && facadeOk && keccak256(hostData) == keccak256(expected)
                && keccak256(facadeData) == keccak256(expected),
            "canonical exact returndata without bytes wrapper"
        );
    }

    event DismissalIdentityDeploymentProof(
        address indexed helper,
        bytes helperRuntime,
        address indexed identity,
        address indexed writer
    );

    struct DismissalCohortFixture {
        bytes32 rotation;
        bytes32 stableRevision;
        bytes32 stableDocument;
        bytes32 childRevision;
        bytes32 stableGuardian;
        bytes32 childGuardian;
        bytes32 stableSuccessor;
        bytes32 childSuccessor;
        bytes32 stableDirective;
        bytes32 childDirective;
        bytes32 stablePayout;
        bytes32 childPayout;
        uint64 end;
    }

    function _dismissalCohort(uint8 boundary) internal returns (DismissalCohortFixture memory f) {
        f.stableGuardian = _selfGuardian();
        f.stableRevision = _reviseDocument(bytes("stable dismissal document"));
        f.stableDocument = ingress.operativeIdentityRecord(artistId);
        f.stableSuccessor = _successionRecord(_successorTerms(address(0xAA), 1));
        f.stableDirective = _directiveRecord(0);
        f.stablePayout = _dismissalPayout(address(0x1001));
        OfficialSafe prior = artist;
        uint256[] memory priorKeys = keys;
        _newRotationSafe(18000 + boundary);
        f.rotation = _stageRotation(0);
        _executeTimedRotation(f.rotation);
        _adoptRotatedSafe();
        address[] memory guardians = new address[](1);
        guardians[0] = address(0xFA11);
        f.childGuardian = _guardianRecord(guardians, 1, 0, nextNonce);
        f.childRevision = _reviseDocument(bytes("provisional rejected or mature document"));
        f.childSuccessor = _successionRecord(_successorTerms(address(0xBB), 1));
        f.childDirective = _directiveRecord(4);
        f.childPayout = _dismissalPayout(address(0x1002));
        f.end = ingress.rotationRecord(f.rotation).transition.postWindowEndsAt;
        vm.warp(uint256(f.end) + boundary - 1);
        require(
            executeSafe(prior, priorKeys, address(ingress), 0, _contestData(f.rotation), 0),
            "prior Safe contests actual cohort"
        );
    }

    function _dismissalAssertSelection(DismissalCohortFixture memory f, bool mature) internal view {
        (,,, bytes32 guardian) = ingress.guardianSet(artistId);
        (, bytes32 payout) = ingress.artistPayoutAccount(artistId);
        require(
            guardian == (mature ? f.childGuardian : f.stableGuardian)
                && ingress.operativeSuccessorRecord(artistId)
                    == (mature ? f.childSuccessor : f.stableSuccessor)
                && ingress.operativeEstateDirective(artistId)
                    == (mature ? f.childDirective : f.stableDirective)
                && payout == (mature ? f.childPayout : f.stablePayout)
                && ingress.operativeIdentityRecord(artistId)
                    == (mature
                            ? keccak256("provisional rejected or mature document")
                            : f.stableDocument),
            "all five operative selections"
        );
    }

    function _dismissalMatureCase(uint8 boundary) internal {
        DismissalCohortFixture memory f = _dismissalCohort(boundary);
        _dismissalAssertSelection(f, true);
        bytes32 before_ = keccak256(abi.encode(ingress.rotationRecord(f.rotation)));
        bytes32 record = _dismissalExecute(_dismissalRequest(), 1, 0);
        Dismissal.Closure memory closure_ = ingress.identityTransitionClosure(artistId, f.rotation);
        require(
            !closure_.abandoned && closure_.dismissalRecordHash == record
                && closure_.contestedAt >= f.end,
            "mature closure"
        );
        require(
            keccak256(abi.encode(ingress.rotationRecord(f.rotation))) == before_,
            "mature transition immutable"
        );
        _dismissalAssertSelection(f, true);
        vm.warp(block.timestamp + 30 days);
        _dismissalAssertSelection(f, true);
        require(
            ingress.identityContestDismissalRecord(record).revisionContinuationHead == 0,
            "no invented abandoned revision"
        );
        _reviseDocument(bytes("new child of mature revision"));
        _dismissalPayout(address(0x1004));
    }

    function _payout() internal {
        T.PayoutDesignation memory p = T.PayoutDesignation(artistId, address(artist), bytes32(0));
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.payoutDesignationDigest(p, a));
        _artistCall(abi.encodeCall(IStreamArtistOnboarding.recordPayoutDesignation, (p, a)));
    }

    function _economics() internal {
        (T.AssignmentFact memory first, T.AssignmentFact memory second) =
            coordinator.reads().currentAssignments(1);
        _economicsRecord(first);
        _economicsRecord(second);
    }

    function _economicsRecord(T.AssignmentFact memory fact) internal {
        T.EconomicsConsent memory p = T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
        _artistCall(abi.encodeCall(IStreamArtistOnboarding.recordEconomicsConsent, (p, a)));
    }

    function _ratify() internal {
        (, bytes32 state) = metadata.currentArtistContentState(1);
        T.Ratification memory p = T.Ratification(1, address(metadata), state);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.contentRatificationDigest(p, a));
        _artistCall(abi.encodeCall(IStreamArtistOnboarding.recordContentRatification, (p, a)));
    }

    function _attestations() internal {
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
            ingress.operativeIdentityRecord(artistId),
            keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")
        );
    }

    function _attest(uint8 kind, bytes32 subject, bytes32 state, bytes32 schema) internal {
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

    function _all() internal {
        _accept();
        _policy();
        _payout();
        _economics();
        _ratify();
        _attestations();
    }

    function _roots() internal view returns (bytes32) {
        T.Snapshot[7] memory snapshots;
        for (uint256 i; i < 7; ++i) {
            snapshots[i] = IStreamArtistOwner(suite.owners[i]).ownerStateSnapshotV2();
        }
        return keccak256(abi.encode(snapshots));
    }

    function _closed(bytes memory data) internal view returns (bool) {
        (bool ok,) = address(ingress).staticcall(data);
        return !ok;
    }

    function _mintCall() internal view returns (bytes memory) {
        return abi.encodeCall(IStreamArtistMintConsent.requireMintConsent, (1, PHASE, POLICY));
    }

    function _phaseConfig() internal pure returns (IStreamMintManager.MintPhaseConfig memory) {
        return IStreamMintManager.MintPhaseConfig(
            false, 0, 0, 1, keccak256("phase config"), keccak256("phase metadata")
        );
    }

    function _counters()
        internal
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

    function _prospective(bool withExecutor) internal view returns (bytes32) {
        (bytes32[] memory ids, IStreamMintManager.MintCounterConfig[] memory configs) = _counters();
        IStreamMintManager.MintGateConfig memory gate;
        address[] memory executors = new address[](withExecutor ? 1 : 0);
        if (withExecutor) executors[0] = address(this);
        return
            manager.previewPhasePolicyHash(1, PHASE, _phaseConfig(), gate, ids, configs, executors);
    }

    function _configureData() internal pure returns (bytes memory) {
        (bytes32[] memory ids, IStreamMintManager.MintCounterConfig[] memory configs) = _counters();
        IStreamMintManager.MintGateConfig memory gate;
        return abi.encodeCall(
            IStreamMintManager.configurePhase, (1, PHASE, _phaseConfig(), gate, ids, configs)
        );
    }

    /// @dev External test boundary keeps expectRevert on the complete Safe operation,
    ///      rather than its preliminary nonce/domain read inside executeSafe.
    function executeArtistSafe(bytes calldata data) external returns (bool) {
        require(msg.sender == address(this), "test-only entry");
        return executeSafe(artist, keys, address(ingress), 0, data, 0);
    }

    function executeTargetSafe(address target, bytes calldata data) external returns (bool) {
        require(msg.sender == address(this), "test-only entry");
        return executeSafe(artist, keys, target, 0, data, 0);
    }

    function _executorPolicy(address[] memory executors) internal {
        (bytes32[] memory ids, IStreamMintManager.MintCounterConfig[] memory configs) = _counters();
        IStreamMintManager.MintGateConfig memory gate;
        POLICY =
            manager.previewPhasePolicyHash(1, PHASE, _phaseConfig(), gate, ids, configs, executors);
        (bool consented,) = ingress.isPolicyConsented(1, PHASE, POLICY);
        if (!consented) _policy();
    }

    function _safeExecutor(address executor, bool allowed) internal {
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

    function _candidate(address resolver, address account, uint16 bps, bool frozen_)
        internal
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
    ) internal {
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
        _artistCall(
            abi.encodeCall(
                IStreamArtistEconomicsAuthority.recordProspectiveEconomicsConsent, (p, candidate, a)
            )
        );
    }

    function _freezePayload() internal view returns (T.RoyaltyFreeze memory p) {
        T.AssignmentFact memory fact = coordinator.reads().currentRoyaltyAssignment(1);
        p = T.RoyaltyFreeze(address(royalty), 1, fact.revenueClass, fact.assignmentHash);
    }

    function _authorizeFreeze() internal returns (T.RoyaltyFreeze memory p) {
        p = _freezePayload();
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.royaltyFreezeDigest(p, a));
        _artistCall(
            abi.encodeCall(IStreamArtistEconomicsAuthority.authorizeArtistRoyaltyFreeze, (p, a))
        );
    }

    function _approveMessage(bytes32 digest) internal {
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

}
