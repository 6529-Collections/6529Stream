// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "./ArtistEstateArchivalFixture.sol";
import "./ArtistSaleRegistryFixture.sol";
import "./ArtistIdentityReadEncodingFixture.sol";
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

contract StreamArtistOnboardingTest is
    CharacterizationTestBase,
    ArtistEstateArchivalFixture,
    ArtistSaleRegistryFixture
{
    event EstateCoverageMeasurement(string context, uint256 cap, uint256 measuredSpan);
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
    bool private rotationContestFixture;
    bool private actualSaleRegistryFixture;
    uint8 private saleScopeFixture;
    StreamModuleRegistry private saleModules;
    StreamNativeFixedPriceSaleAdapter private nativeSale;

    /// @dev Actual registered native record/facts and actual artist owners. Core and Executor remain unit boundaries.
    function _saleFixture(uint8 scope_) private returns (Sale.Consent memory p) {
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

    function _saleAuthorization(Sale.Consent memory p) private returns (T.Authorization memory a) {
        a = _authorization(false);
        a.signature = _signature(ingress.saleConsentDigest(p, a));
    }

    function _requireSale(Sale.Consent memory p) private {
        vm.prank(p.saleAdapter);
        ingress.requireSaleConsent(p.collectionId, p.saleId, p.saleConfigHash);
    }

    function testSaleConsentActualNativeSafeExactDigestRecordEventAndReplay() public {
        Sale.Consent memory p = _saleFixture(1);
        require(ingress.saleConsentScope(1) == 1, "immutable REQUIRED election");
        vm.expectRevert(
            abi.encodeWithSelector(
                Sale.SaleConsentUnavailable.selector, 1, p.saleId, p.saleConfigHash
            )
        );
        _requireSale(p);
        T.Authorization memory a = _saleAuthorization(p);
        bytes32 digest = StreamArtistHashes.typed(
            StreamArtistHashes.Environment(
                block.chainid, address(ingress), address(core), address(manager)
            ),
            keccak256(
                abi.encode(
                    bytes32(0x5a0d2fee9c2248ad2b0735d54beb28b1decdd1adeb65c63c4016da70ec399045),
                    address(core),
                    p.saleAdapter,
                    uint256(1),
                    p.saleId,
                    p.saleConfigHash,
                    a.nonce,
                    a.time
                )
            )
        );
        require(digest == ingress.saleConsentDigest(p, a), "exact permanent digest");
        vm.warp(1017);
        vm.recordLogs();
        bytes32 record = ingress.recordSaleConsent(p, a);
        bytes32 expected = keccak256(
            abi.encode(
                bytes32(0xf30702786801bdda286e4555272eb70024e76bd156af98fab2513886e5bdcfd1),
                block.chainid,
                address(ingress),
                p.saleAdapter,
                address(core),
                uint256(1),
                p.saleId,
                p.saleConfigHash,
                artistId,
                address(artist),
                uint8(1),
                a.nonce,
                uint64(1017)
            )
        );
        require(record == expected, "observed record time distinct from deadline");
        Sale.Record memory saved = ingress.saleConsentRecord(record);
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        require(
            saved.bindingGeneration == b.generation && saved.bindingHash == b.bindingHash
                && saved.artistId == artistId && saved.recordHash == expected,
            "canonical record plus actual applicability"
        );
        uint256 found;
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == suite.owners[6]
                    && logs[i].topics[0]
                        == keccak256(
                            "ArtistSaleConsentRecorded(uint16,uint256,bytes32,address,bytes32,uint8,uint256,uint64,bytes32)"
                        )
            ) {
                require(
                    logs[i].topics[1] == bytes32(uint256(1))
                        && logs[i].topics[2] == p.saleConfigHash
                        && logs[i].topics[3] == bytes32(uint256(uint160(address(artist))))
                        && keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(
                                    uint16(1), p.saleId, uint8(1), a.nonce, uint64(1017), record
                                )
                            ),
                    "exact owner event"
                );
                ++found;
            }
        }
        require(found == 1, "one canonical event");
        (bool exists, bytes32 observed) = ingress.isSaleConsented(1, p.saleId, p.saleConfigHash);
        require(exists && observed == record, "stored evidence");
        _requireSale(p);
        bytes32 roots = _roots();
        avm.expectPartialRevert(T.Replay.selector);
        ingress.recordSaleConsent(p, a);
        require(_roots() == roots, "principal replay atomic");
        T.Authorization memory fresh = _saleAuthorization(p);
        bytes32 replayKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                address(ingress),
                address(coordinator),
                address(archive),
                suite.owners[6],
                keccak256("domain:consent_finality"),
                keccak256("consent_finality.replay.sale_consent_key"),
                keccak256(abi.encode(p, b.generation, b.bindingHash))
            )
        );
        vm.expectRevert(abi.encodeWithSelector(T.Replay.selector, replayKey));
        ingress.recordSaleConsent(p, fresh);
        require(
            _roots() == roots,
            "same-generation consent key and new principal authorization rollback"
        );
    }

    function testSaleConsentDelayedDirectSafeAndCallerBoundRead() public {
        Sale.Consent memory p = _saleFixture(1);
        T.Authorization memory a = _authorization(false);
        bytes memory data = abi.encodeCall(IStreamArtistSaleAuthority.recordSaleConsent, (p, a));
        vm.warp(block.timestamp + 30);
        require(
            executeSafe(artist, keys, address(ingress), 0, data, 0), "actual Safe direct writer"
        );
        (bool exists, bytes32 hash) = ingress.isSaleConsented(1, p.saleId, p.saleConfigHash);
        require(
            exists && ingress.saleConsentRecord(hash).signer == address(artist),
            "Safe remains signer"
        );
        (,,, T.SignerApproval memory proof,,) = abi.decode(
            _operationPayload(16, address(artist), hash),
            (T.Binding, Sale.Consent, T.Authorization, T.SignerApproval, R.AuthorityFact, bytes)
        );
        require(
            proof.direct && proof.signer == address(artist), "archived actual direct Safe proof"
        );
        _requireSale(p);
        vm.expectRevert(
            abi.encodeWithSelector(
                Sale.SaleConsentUnavailable.selector, 1, p.saleId, p.saleConfigHash
            )
        );
        ingress.requireSaleConsent(1, p.saleId, p.saleConfigHash);
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistSaleAuthority.isSaleConsented, (1, p.saleId, p.saleConfigHash)
                ),
                0
            ),
            "Safe historical read"
        );
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistAttributionState.collectionArtistState, (1)),
                0
            ),
            "Safe typed state read"
        );
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistSaleAuthority.saleConsentScope, (1)),
                0
            ),
            "Safe scope read"
        );
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistSaleAuthority.saleConsentDigest, (p, a)),
                0
            ),
            "Safe digest read"
        );
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistSaleAuthority.saleConsentRecord, (hash)),
                0
            ),
            "Safe permanent record read"
        );
    }

    function testSaleConsentApprovedEmptySafeAndOwnerEOACannotSubstitute() public {
        Sale.Consent memory p = _saleFixture(1);
        T.Authorization memory a = _authorization(false);
        bytes32 roots = _roots();
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordSaleConsent(p, a);
        vm.prank(vm.addr(keys[0]));
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordSaleConsent(p, a);
        require(_roots() == roots, "no Safe owner role inheritance");
        bytes32 digest = ingress.saleConsentDigest(p, a);
        require(
            executeSafe(
                artist,
                keys,
                safeComponents.signMessage,
                0,
                abi.encodeWithSignature("signMessage(bytes)", abi.encode(digest)),
                1
            ),
            "actual Safe approved message"
        );
        bytes32 hash = ingress.recordSaleConsent(p, a);
        require(
            ingress.saleConsentRecord(hash).signer == address(artist), "approved-empty relayed Safe"
        );
        _requireSale(p);
    }

    function testSaleConsentLateArchiveFailureAndExactRetry() public {
        Sale.Consent memory p = _saleFixture(1);
        T.Authorization memory a = _saleAuthorization(p);
        bytes32 roots = _roots();
        avm.mockCallRevert(
            address(archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(T.InvalidRecord.selector)
        );
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.recordSaleConsent(p, a);
        require(_roots() == roots, "Identity and Consent roll back on Archive failure");
        avm.clearMockedCalls();
        ingress.recordSaleConsent(p, a);
        _requireSale(p);
    }

    function testSaleConsentNativeScopeNoneAndUnknownBindingAreDistinct() public {
        Sale.Consent memory p = _saleFixture(0);
        require(ingress.saleConsentScope(1) == 0, "actual NONE election");
        ingress.requireSaleConsent(1, p.saleId, p.saleConfigHash);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidAttribution.selector, 2));
        ingress.requireSaleConsent(2, 0, 0);
        ingress.recordSaleConsent(p, _saleAuthorization(p));
        (bool exists,) = ingress.isSaleConsented(1, p.saleId, p.saleConfigHash);
        require(exists, "NONE may record evidence");
    }

    function testSaleConsentMissingChangedForeignFactsAndDeprecatedModuleRollback() public {
        Sale.Consent memory p = _saleFixture(1);
        Sale.Consent memory wrong =
            Sale.Consent(1, p.saleAdapter, keccak256("missing"), p.saleConfigHash);
        T.Authorization memory a = _saleAuthorization(wrong);
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(
                Sale.SaleFactsReadFailed.selector,
                p.saleAdapter,
                IStreamArtistSaleFacts.saleConsentFacts.selector
            )
        );
        ingress.recordSaleConsent(wrong, a);
        wrong = Sale.Consent(1, p.saleAdapter, p.saleId, keccak256("foreign config"));
        a = _saleAuthorization(wrong);
        vm.expectRevert(abi.encodeWithSelector(Sale.InvalidSaleAdapter.selector, p.saleAdapter));
        ingress.recordSaleConsent(wrong, a);
        _saleStatus(
            saleModules,
            factory.governanceAuthority(),
            p.saleAdapter,
            ModuleRegistryStatus.DEPRECATED
        );
        a = _saleAuthorization(p);
        vm.expectRevert(abi.encodeWithSelector(Sale.InvalidSaleAdapter.selector, p.saleAdapter));
        ingress.recordSaleConsent(p, a);
        require(_roots() == roots, "failed facts never consume artist state");
    }

    function testSaleConsentBoundedMalformedAndExhaustedProviderReads() public {
        _saleFixture(1);
        ArtistSaleFactsAdversary bad =
            new ArtistSaleFactsAdversary(address(core), keccak256("boundary config"));
        _saleRegister(
            saleModules,
            factory.governanceAuthority(),
            address(bad),
            bad.streamModuleType(),
            bad.streamModuleInterfaceId()
        );
        Sale.Consent memory p =
            Sale.Consent(1, address(bad), keccak256("boundary sale"), keccak256("boundary config"));
        T.Authorization memory a = _saleAuthorization(p);
        bytes32 roots = _roots();
        for (uint256 mode = 1; mode <= 4; ++mode) {
            bad.setMode(mode);
            vm.expectRevert(
                abi.encodeWithSelector(
                    Sale.SaleFactsReadFailed.selector,
                    address(bad),
                    IStreamArtistSaleFacts.saleConsentFacts.selector
                )
            );
            ingress.recordSaleConsent(p, a);
            require(_roots() == roots, "provider failure bounded and atomic");
        }
        bad.setMode(0);
        bad.setCore(address(0xBAD));
        vm.expectRevert(abi.encodeWithSelector(Sale.InvalidSaleAdapter.selector, address(bad)));
        ingress.recordSaleConsent(p, a);
        require(_roots() == roots, "foreign Core rejected");
        bad.setCore(address(core));
        bytes32 record = ingress.recordSaleConsent(p, a);
        require(
            ingress.saleConsentRecord(record).terms.saleAdapter == address(bad),
            "same admitted context and authorization positive control"
        );
        _requireSale(p);
    }

    function testSaleConsentRotationPreservesStoredRecordAndRejectsUnusedOldProof() public {
        Sale.Consent memory p = _saleFixture(1);
        ingress.recordSaleConsent(p, _saleAuthorization(p));
        T.Authorization memory unused = _saleAuthorization(p);
        unused.time = type(uint64).max;
        unused.signature = _signature(ingress.saleConsentDigest(p, unused));
        _newRotationSafe(9929);
        bytes32 rotation = _stageRotation(0);
        _executeTimedRotation(rotation);
        bytes32 roots = _roots();
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordSaleConsent(p, unused);
        require(_roots() == roots, "old current-principal proof rejected before duplicate consent");
        _requireSale(p);
        (uint8 state, uint64 generation, bytes32 id, uint8 authorityStatus, bytes32 bindingHash) =
            ingress.collectionArtistState(1);
        require(
            state == 2 && generation == 1 && id == artistId && authorityStatus == 1
                && bindingHash != 0,
            "rotation retains accepted generation"
        );
    }

    function testSaleStateReadDistinguishesNoneClaimedWithdrawnAndReproposal() public {
        (uint8 state, uint64 generation, bytes32 id, uint8 status, bytes32 hash) =
            ingress.collectionArtistState(2);
        require(
            state == 0 && generation == 0 && id == 0 && status == 0 && hash == 0,
            "absent actual owners"
        );
        (state, generation, id, status, hash) = ingress.collectionArtistState(1);
        require(
            state == 1 && generation == 1 && id == artistId && status == 1 && hash != 0,
            "CLAIMED is not disputed"
        );
        bytes32 prior = hash;
        ingress.withdrawArtistBinding(_termination(1));
        (state, generation, id, status, hash) = ingress.collectionArtistState(1);
        require(
            state == 5 && generation == 1 && id == artistId && status == 1 && hash == prior,
            "only claimed generation terminated"
        );
        _repropose(1);
        (state, generation, id, status, hash) = ingress.collectionArtistState(1);
        require(
            state == 1 && generation == 2 && id == artistId && status == 1 && hash != prior,
            "later generation has its own facts"
        );
        // Expected-generation endpoint is required for a new direct acceptance; signed helper binds the exact current hash.
        _accept();
        (state, generation, id, status, hash) = ingress.collectionArtistState(1);
        require(state == 2 && generation == 2, "actual complete acceptance");
    }

    function testSaleStateAuthorityContestIsNotAttributionDisputeAndHistoricalEvidenceRemains()
        public
    {
        rotationContestFixture = true;
        Sale.Consent memory p = _saleFixture(1);
        bytes32 record = ingress.recordSaleConsent(p, _saleAuthorization(p));
        _newRotationSafe(9988);
        bytes32 transition = _stageRotation(0);
        _executeTimedRotation(transition);
        ArtistRotationContestHarness(suite.owners[2]).simulateExecutedTransitionContest(transition);
        (uint8 state, uint64 generation, bytes32 id, uint8 status, bytes32 hash) =
            ingress.collectionArtistState(1);
        require(
            state == 2 && generation == 1 && id == artistId && status == 4 && hash != 0,
            "qualified Identity4 never becomes Attribution4"
        );
        (bool exists, bytes32 saved) = ingress.isSaleConsented(1, p.saleId, p.saleConfigHash);
        require(exists && saved == record, "stored evidence is not current applicability");
        vm.expectRevert(abi.encodeWithSelector(T.InvalidAttribution.selector, 1));
        _requireSale(p);
    }

    function testSaleConsentParentGasAndProtocolOnlyCallbacks() public {
        Sale.Consent memory p = _saleFixture(1);
        (bool ok, bytes memory reason) = address(ingress).staticcall{ gas: 120_000 }(
            abi.encodeCall(IStreamArtistSaleAuthority.saleConsentScope, (1))
        );
        require(
            !ok && reason.length == 68 && bytes4(reason) == Sale.SaleFactsParentGas.selector,
            "explicit parent gas rejection"
        );
        T.Authorization memory a = _saleAuthorization(p);
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        T.ActionContext memory context = T.ActionContext(
            16, address(artist), IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2()
        );
        T.SignerApproval memory proof =
            T.SignerApproval(address(artist), ingress.saleConsentDigest(p, a), false);
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(artist)));
        vm.prank(address(artist));
        IStreamArtistSaleIdentityOwner(suite.owners[2]).consumeSaleConsent(context, b, p, a, proof);
        T.ActionContext memory consentContext = T.ActionContext(
            16, address(artist), IStreamArtistOwner(suite.owners[6]).ownerStateSnapshotV2()
        );
        R.AuthorityFact memory emptyAuthority;
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(artist)));
        vm.prank(address(artist));
        IStreamArtistSaleConsentOwner(suite.owners[6])
            .recordSaleConsent(consentContext, b, p, address(artist), a.nonce, emptyAuthority);
        bytes memory rejectedCall = abi.encodeCall(
            IStreamArtistSaleConsentOwner.recordSaleConsent,
            (consentContext, b, p, address(artist), a.nonce, emptyAuthority)
        );
        uint256 safeNonceBefore = artist.nonce();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(suite.owners[6], rejectedCall);
        require(artist.nonce() == safeNonceBefore, "rejected actual Safe callback is atomic");
        address extension = StreamArtistIdentityAuthority(suite.owners[2]).identityWriterExtension();
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistIdentityWriterExtension.ExtensionWrongHost.selector, extension
            )
        );
        IStreamArtistSaleIdentityOwner(extension).consumeSaleConsent(context, b, p, a, proof);
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(artist)));
        vm.prank(address(artist));
        coordinator.coordinateRecordSaleConsent(address(artist), p, a);
        address writer = ingress.registryWriterExtension();
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistRegistryWriterExtension.ExtensionWrongHost.selector, writer
            )
        );
        IStreamArtistSaleAuthority(writer).recordSaleConsent(p, a);
        ingress.recordSaleConsent(p, a);
        _requireSale(p);
    }

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

    function _revisionProposal(bytes memory document)
        private
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

    function _reviseDocument(bytes memory document) private returns (bytes32 record) {
        StreamArtistIdentityRevisionTypes.Revision memory p = _revisionProposal(document);
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.identityRevisionDigest(p, a));
        return ingress.recordIdentityRevision(p, a, document, "Revised Artist");
    }

    function _otherOwnerRoots() private view returns (bytes32) {
        T.Snapshot[7] memory snapshots;
        for (uint256 i; i < 7; ++i) {
            if (i != 2) snapshots[i] = IStreamArtistOwner(suite.owners[i]).ownerStateSnapshotV2();
        }
        return keccak256(abi.encode(snapshots));
    }

    function testIdentityRevisionSafeRecordDigestEventAndImmutableRegistration() public {
        T.Identity memory original = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        bytes memory document = bytes("updated canonical identity");
        StreamArtistIdentityRevisionTypes.Revision memory p = _revisionProposal(document);
        T.Authorization memory a = _authorization(true);
        bytes32 digest = StreamArtistHashes.typed(
            StreamArtistHashes.Environment(
                block.chainid, address(ingress), address(core), address(manager)
            ),
            keccak256(
                abi.encode(
                    bytes32(0xbfb7a5d3bc248c8eefbe4f8dfc2ea7d75d18c5cb3f2ab0d56000fd87f4b58603),
                    artistId,
                    p.previousRecordHash,
                    p.revisedRecordHash,
                    a.nonce,
                    a.time
                )
            )
        );
        require(
            digest == ingress.identityRevisionDigest(p, a),
            "permanent revision typehash and field order"
        );
        a.signature = _signature(digest);
        vm.warp(1015);
        bytes32 other = _otherOwnerRoots();
        vm.recordLogs();
        bytes32 record = ingress.recordIdentityRevision(p, a, document, "Revised Artist");
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_REVISION_RECORD_V1"),
                block.chainid,
                address(ingress),
                artistId,
                p.previousRecordHash,
                p.revisedRecordHash,
                address(artist),
                uint8(1),
                a.nonce,
                a.time
            )
        );
        require(record == expected, "signedAt remains signed time");
        bool found;
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == suite.owners[2]
                    && logs[i].topics[0]
                        == keccak256(
                            "ArtistIdentityRevisionRecorded(uint16,bytes32,address,bytes32,bytes32,string,uint8,uint256,uint64,bytes32)"
                        )
            ) {
                require(
                    logs[i].topics[1] == artistId
                        && logs[i].topics[2] == bytes32(uint256(uint160(address(artist)))),
                    "revision indexed identity"
                );
                require(
                    keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                p.previousRecordHash,
                                p.revisedRecordHash,
                                p.identityRecordURI,
                                uint8(1),
                                a.nonce,
                                a.time,
                                record
                            )
                        ),
                    "exact revision event"
                );
                found = true;
            }
        }
        require(found && _otherOwnerRoots() == other, "sole Identity writer");
        T.Identity memory current = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        require(
            current.identityRecordHash == original.identityRecordHash
                && keccak256(bytes(current.identityRecordURI))
                    == keccak256(bytes(original.identityRecordURI))
                && keccak256(bytes(current.displayName)) == keccak256(bytes(original.displayName)),
            "immutable registration tuple"
        );
        require(
            ingress.operativeIdentityRecord(artistId) == p.revisedRecordHash
                && keccak256(ingress.identityRecordBytes(artistId)) == p.revisedRecordHash
                && keccak256(ingress.identityDocumentBytes(original.identityRecordHash))
                    == original.identityRecordHash,
            "operative and historical document bytes"
        );
        (string memory name, bytes32 hash) = ingress.artistDisplayName(artistId);
        require(
            hash == p.revisedRecordHash && keccak256(bytes(name)) == keccak256("Revised Artist"),
            "operative mirror paired with hash"
        );
        StreamArtistIdentityRevisionTypes.Record memory saved =
            ingress.identityRevisionRecord(record);
        require(
            saved.previousRevisionRecord == bytes32(0) && saved.recordHash == record
                && saved.authorityClass == 1 && saved.signedAt == a.time,
            "historical canonical revision"
        );
        (
            ,
            T.Authorization memory submitted,
            bytes memory bytes_,,
            T.SignerApproval memory proof,
            T.Authorization memory effective
        ) = abi.decode(
            _operationPayload(25, address(this), record),
            (
                StreamArtistIdentityRevisionTypes.Revision,
                T.Authorization,
                bytes,
                string,
                T.SignerApproval,
                T.Authorization
            )
        );
        require(
            !proof.direct && proof.digest == digest && submitted.time == effective.time
                && keccak256(submitted.signature) == keccak256(a.signature)
                && keccak256(bytes_) == hash,
            "exact signed Archive"
        );
        this.executeTargetSafe(
            address(ingress),
            abi.encodeCall(IStreamArtistIdentityRevision.identityRevisionDigest, (p, a))
        );
        this.executeTargetSafe(
            address(ingress),
            abi.encodeCall(IStreamArtistIdentityRevisionReads.operativeIdentityRecord, (artistId))
        );
        this.executeTargetSafe(
            address(ingress),
            abi.encodeCall(IStreamArtistIdentityRevisionReads.identityRecordBytes, (artistId))
        );
        this.executeTargetSafe(
            address(ingress),
            abi.encodeCall(IStreamArtistIdentityRevisionReads.identityDocumentBytes, (hash))
        );
        this.executeTargetSafe(
            address(ingress),
            abi.encodeCall(IStreamArtistIdentityRevisionReads.artistDisplayName, (artistId))
        );
        this.executeTargetSafe(
            address(ingress),
            abi.encodeCall(IStreamArtistIdentityRevisionReads.identityRevisionRecord, (record))
        );
    }

    function testIdentityRevisionDelayedDirectSafeRecordsObservedTimeAndOriginalSentinel() public {
        bytes memory document = bytes("queued Safe revision");
        StreamArtistIdentityRevisionTypes.Revision memory p = _revisionProposal(document);
        T.Authorization memory a = T.Authorization(0, 0, "");
        bytes memory data = abi.encodeCall(
            IStreamArtistIdentityRevision.recordIdentityRevision, (p, a, document, "Queued Safe")
        );
        vm.warp(1050);
        this.executeTargetSafe(address(ingress), data);
        bytes32 record = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_REVISION_RECORD_V1"),
                block.chainid,
                address(ingress),
                artistId,
                p.previousRecordHash,
                p.revisedRecordHash,
                address(artist),
                uint8(1),
                uint256(0),
                uint64(1050)
            )
        );
        require(ingress.identityRevisionRecord(record).signedAt == 1050, "observed inclusion time");
        (
            ,
            T.Authorization memory submitted,,,
            T.SignerApproval memory proof,
            T.Authorization memory effective
        ) = abi.decode(
            _operationPayload(25, address(artist), record),
            (
                StreamArtistIdentityRevisionTypes.Revision,
                T.Authorization,
                bytes,
                string,
                T.SignerApproval,
                T.Authorization
            )
        );
        require(
            submitted.time == 0 && effective.time == 1050 && proof.direct
                && proof.digest == ingress.identityRevisionDigest(p, effective),
            "original and effective direct bytes"
        );
    }

    function testIdentityRevisionDelayedEOAAndCrossIdentityNonceIsolation() public {
        address eoa = vm.addr(9081);
        T.BindingProposal memory proposal = _proposal(bytes32(0));
        proposal.artistAddress = eoa;
        (bytes32 second,) = ingress.proposeArtistBinding(
            2, proposal, bytes("unit identity document"), "Artist Safe"
        );
        bytes memory document = bytes("EOA revised identity");
        StreamArtistIdentityRevisionTypes.Revision memory p =
            StreamArtistIdentityRevisionTypes.Revision(
                second, proposal.identityRecordHash, keccak256(document), "urn:eoa"
            );
        T.Authorization memory a = T.Authorization(0, 0, "");
        bytes memory data = abi.encodeCall(
            IStreamArtistIdentityRevision.recordIdentityRevision, (p, a, document, "EOA")
        );
        vm.warp(1060);
        vm.prank(eoa);
        (bool ok,) = address(ingress).call(data);
        require(
            ok && ingress.operativeIdentityRecord(second) == keccak256(document),
            "delayed EOA direct"
        );
        require(
            !ingress.artistAuthorizationState(artistId, bytes32(0), 0).nonceConsumed,
            "other identity nonce unchanged"
        );
        _reviseDocument(bytes("independent Safe revision"));
        require(
            ingress.artistAuthorizationState(artistId, bytes32(0), 0).nonceConsumed,
            "same nonce other identity works"
        );
    }

    function testIdentityRevisionStalesOnlyPersonhoodThenMatchingAttestationRestoresMint() public {
        _all();
        ingress.requireMintConsent(1, PHASE, POLICY);
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        bytes32 other = _otherOwnerRoots();
        bytes32 newHash = keccak256("identity B");
        _reviseDocument(bytes("identity B"));
        require(
            _otherOwnerRoots() == other
                && coordinator.reads().acceptedBinding(1).bindingHash == b.bindingHash,
            "all prior binding and consent state stays"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                T.MissingMintPrerequisite.selector, keccak256("personhood-attestation")
            )
        );
        ingress.requireMintConsent(1, PHASE, POLICY);
        bytes32 roots = _roots();
        uint256 n = nextNonce;
        avm.expectRevert(T.InvalidRecord.selector);
        this.recordUnitPersonhood(b.identityRecordHash);
        require(_roots() == roots, "obsolete personhood record rolls back");
        nextNonce = n;
        _attest(10, artistId, newHash, keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1"));
        ingress.requireMintConsent(1, PHASE, POLICY);
        require(
            coordinator.reads().acceptedBinding(1).identityRecordHash == b.identityRecordHash,
            "historical binding not rewritten"
        );
        _contentConsent(keccak256("content after identity revision"));
    }

    function recordUnitPersonhood(bytes32 state) external {
        require(msg.sender == address(this), "test self only");
        _attest(10, artistId, state, keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1"));
    }

    function testIdentityRevisionReturnToSameDocumentRestoresHashMatchingEvidence() public {
        _all();
        T.AttestationRecord memory proof =
            IStreamArtistAttributionOwner(suite.owners[4]).attestation(1, 10, artistId);
        bytes32 other = _otherOwnerRoots();
        bytes32 first = _reviseDocument(bytes("identity B"));
        require(_closed(_mintCall()), "A evidence stale at B");
        bytes32 second = _reviseDocument(bytes("unit identity document"));
        ingress.requireMintConsent(1, PHASE, POLICY);
        require(
            ingress.identityRevisionRecord(second).previousRevisionRecord == first
                && ingress.identityRevisionRecord(first).revisedRecordHash
                    == keccak256("identity B"),
            "linear permanent history through repeated content"
        );
        require(
            _otherOwnerRoots() == other
                && IStreamArtistAttributionOwner(suite.owners[4])
                    .attestation(1, 10, artistId)
                    .recordHash == proof.recordHash,
            "same A subject matches without unsolicited revision ordinal"
        );
    }

    function testIdentityRevisionPendingAcceptanceRetainsProposalVersionAndFutureProposalUsesTip()
        public
    {
        StreamArtistIdentityRevisionTypes.Revision memory p = _revisionProposal(bytes("identity B"));
        _reviseDocument(bytes("identity B"));
        _accept();
        require(
            coordinator.reads().acceptedBinding(1).identityRecordHash
                == keccak256("unit identity document"),
            "proposal A accepted after revision B"
        );
        T.BindingProposal memory old = _proposal(artistId);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidIdentity.selector, artistId));
        ingress.proposeArtistBinding(2, old, bytes("unit identity document"), "Artist Safe");
        old.identityRecordHash = p.revisedRecordHash;
        old.identityRecordURI = p.identityRecordURI;
        bytes32 before_ =
            keccak256(abi.encode(IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2()));
        ingress.proposeArtistBinding(2, old, bytes("identity B"), "Revised Artist");
        require(
            keccak256(abi.encode(IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2()))
                == before_,
            "reuse remains read-only"
        );
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.acceptanceDigest(2, a));
        ingress.acceptArtistBinding(2, a);
        require(
            coordinator.reads().acceptedBinding(2).identityRecordHash == p.revisedRecordHash,
            "future accepted binding B"
        );
        require(
            ingress.attribution(2).identityHash == p.revisedRecordHash
                && ingress.attribution(1).identityHash == p.previousRecordHash,
            "compatibility attribution pairs each binding with its ratified document"
        );
        _policy();
        _payout();
        _economics();
        _ratify();
        _attestations();
        ingress.requireMintConsent(1, PHASE, POLICY);
        require(
            IStreamArtistAttributionOwner(suite.owners[4])
            .attestation(1, 10, artistId)
            .subjectStateHash == p.revisedRecordHash,
            "pending historical A acceptance uses operative B personhood"
        );
    }

    function testIdentityRevisionApprovedEmptySafeAndProtocolOnlyCallbacks() public {
        bytes memory document = bytes("approved empty revision");
        StreamArtistIdentityRevisionTypes.Revision memory p = _revisionProposal(document);
        T.Authorization memory a = _authorization(true);
        bytes32 digest = ingress.identityRevisionDigest(p, a);
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordIdentityRevision(p, a, document, "Approved");
        _approveMessage(digest);
        bytes32 record = ingress.recordIdentityRevision(p, a, document, "Approved");
        require(
            ingress.identityRevisionRecord(record).signer == address(artist),
            "real Safe empty-proof relay"
        );
        T.ActionContext memory c = T.ActionContext(
            25, address(artist), IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2()
        );
        T.SignerApproval memory proof = T.SignerApproval(address(artist), digest, true);
        bytes memory call_ = abi.encodeCall(
            IStreamArtistIdentityRevisionOwner.recordIdentityRevision,
            (c, p, a, proof, document, "Approved")
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(suite.owners[2], call_);
        call_ = abi.encodeCall(
            IStreamArtistIdentityRevisionCoordinator.coordinateRecordIdentityRevision,
            (address(artist), p, a, document, "Approved")
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(address(coordinator), call_);
        p = _revisionProposal(bytes("no EOA owner privilege"));
        a = _authorization(true);
        vm.prank(vm.addr(keys[0]));
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordIdentityRevision(p, a, bytes("no EOA owner privilege"), "Owner");
    }

    function testIdentityRevisionLateArchiveFailureRestoresHeadBytesReplayAndRecord() public {
        bytes memory document = bytes("atomic identity revision");
        StreamArtistIdentityRevisionTypes.Revision memory p = _revisionProposal(document);
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.identityRevisionDigest(p, a));
        bytes32 before_ = _roots();
        bytes memory failure = abi.encodeWithSignature("Error(string)", "revision archive failed");
        avm.mockCallRevert(
            address(archive),
            abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            failure
        );
        vm.expectRevert(failure);
        ingress.recordIdentityRevision(p, a, document, "Atomic");
        require(
            _roots() == before_ && ingress.operativeIdentityRecord(artistId) == p.previousRecordHash
                && ingress.identityDocumentBytes(p.revisedRecordHash).length == 0
                && !ingress.artistAuthorizationState(artistId, bytes32(0), a.nonce).nonceConsumed,
            "complete rollback"
        );
        avm.clearMockedCalls();
        ingress.recordIdentityRevision(p, a, document, "Atomic");
    }

    function testIdentityRevisionRejectsForkNoopWrongBytesAndTimestamps() public {
        bytes memory document = bytes("branch B");
        StreamArtistIdentityRevisionTypes.Revision memory p = _revisionProposal(document);
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.identityRevisionDigest(p, a));
        ingress.recordIdentityRevision(p, a, document, "B");
        bytes32 before_ = _roots();
        a = _authorization(true);
        p.revisedRecordHash = keccak256("branch C");
        a.signature = _signature(ingress.identityRevisionDigest(p, a));
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.recordIdentityRevision(p, a, bytes("branch C"), "C");
        p = _revisionProposal(document);
        a.signature = _signature(ingress.identityRevisionDigest(p, a));
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.recordIdentityRevision(p, a, document, "Noop");
        p = _revisionProposal(bytes("branch C"));
        a.signature = _signature(ingress.identityRevisionDigest(p, a));
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.recordIdentityRevision(p, a, document, "Wrong bytes");
        a.time = uint64(block.timestamp + 1);
        a.signature = _signature(ingress.identityRevisionDigest(p, a));
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.recordIdentityRevision(p, a, bytes("branch C"), "Future");
        a.time = 0;
        a.signature = _signature(ingress.identityRevisionDigest(p, a));
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.recordIdentityRevision(p, a, bytes("branch C"), "Relay zero");
        require(_roots() == before_, "all invalid branches preserve roots");
    }

    function testIdentityRevisionExactByteBounds() public {
        bytes memory document = new bytes(8192);
        document[8191] = 0x41;
        StreamArtistIdentityRevisionTypes.Revision memory p = _revisionProposal(document);
        p.identityRecordURI = string(new bytes(2048));
        string memory name = string(new bytes(256));
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.identityRevisionDigest(p, a));
        ingress.recordIdentityRevision(p, a, document, name);
        require(ingress.identityRecordBytes(artistId).length == 8192, "maximum bytes stored");
        document = new bytes(8193);
        p = _revisionProposal(document);
        a = _authorization(true);
        a.signature = _signature(ingress.identityRevisionDigest(p, a));
        vm.expectRevert(
            abi.encodeWithSelector(T.BoundExceeded.selector, uint256(8193), uint256(8192))
        );
        ingress.recordIdentityRevision(p, a, document, "Name");
        document = bytes("bounds");
        p = _revisionProposal(document);
        p.identityRecordURI = string(new bytes(2049));
        a.signature = _signature(ingress.identityRevisionDigest(p, a));
        vm.expectRevert(
            abi.encodeWithSelector(T.BoundExceeded.selector, uint256(2049), uint256(2048))
        );
        ingress.recordIdentityRevision(p, a, document, "Name");
        p.identityRecordURI = "urn:ok";
        vm.expectRevert(
            abi.encodeWithSelector(T.BoundExceeded.selector, uint256(257), uint256(256))
        );
        ingress.recordIdentityRevision(p, a, document, string(new bytes(257)));
    }

    function _identityRevisionReplayKey(bytes32 surface, bytes32 scope)
        private
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

    function testIdentityRevisionRevokedDigestAndUsedNoncePinExactIdentityDenial() public {
        bytes memory document = bytes("prevented revision");
        StreamArtistIdentityRevisionTypes.Revision memory p = _revisionProposal(document);
        T.Authorization memory a = T.Authorization(51, 1000, "");
        bytes32 digest = ingress.identityRevisionDigest(p, a);
        a.signature = _signature(digest);
        StreamArtistAuthorizationTypes.Revocation memory revoke =
            StreamArtistAuthorizationTypes.Revocation(artistId, digest, 0);
        T.Authorization memory cancel = _authorization(false);
        cancel.signature = _signature(ingress.authorizationRevocationDigest(revoke, cancel));
        ingress.revokeArtistAuthorization(revoke, cancel);
        bytes32 before_ = _roots();
        bytes32 key = _identityRevisionReplayKey(
            keccak256("identity_authority.replay.digest_revocation"),
            keccak256(abi.encode(artistId, digest))
        );
        vm.expectRevert(abi.encodeWithSelector(T.Replay.selector, key));
        ingress.recordIdentityRevision(p, a, document, "Denied");
        a.nonce = 0;
        a.signature = _signature(ingress.identityRevisionDigest(p, a));
        key = _identityRevisionReplayKey(
            keccak256("identity_authority.replay.nonce_allocator"),
            keccak256(abi.encode(artistId, uint256(0)))
        );
        vm.expectRevert(abi.encodeWithSelector(T.Replay.selector, key));
        ingress.recordIdentityRevision(p, a, document, "Used nonce");
        require(
            _roots() == before_
                && ingress.operativeIdentityRecord(artistId) == p.previousRecordHash,
            "preventive denial rollback"
        );
    }

    function testIdentityRevisionWrongDomainMissingSafeOwnerAndDirectTimeGuard() public {
        bytes memory document = bytes("invalid signature revision");
        StreamArtistIdentityRevisionTypes.Revision memory p = _revisionProposal(document);
        T.Authorization memory a = _authorization(true);
        a.signature =
            _signature(keccak256(abi.encode("wrong domain", ingress.identityRevisionDigest(p, a))));
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordIdentityRevision(p, a, document, "Wrong domain");
        uint256[] memory oneKey = new uint256[](1);
        oneKey[0] = keys[0];
        a.signature = safeThresholdSignature(
            oneKey, safeMessageDigest(artist, abi.encode(ingress.identityRevisionDigest(p, a)))
        );
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordIdentityRevision(p, a, document, "Missing owner");
        a.signature = "";
        bytes memory queued = abi.encodeCall(
            IStreamArtistIdentityRevision.recordIdentityRevision,
            (p, a, document, "Nonzero stale time")
        );
        vm.warp(1010);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(address(ingress), queued);
        require(
            !ingress.artistAuthorizationState(artistId, bytes32(0), 0).nonceConsumed,
            "bad proofs and direct stale time preserve allocator"
        );
    }

    function testIdentityAttestationLegacyCallbackRejectsPersonhoodAndNewCallbackRejectsSafe()
        public
    {
        _accept();
        T.Binding memory b = coordinator.reads().acceptedBinding(1);
        bytes memory statement = bytes("old callback cannot reintroduce stale facts");
        T.Attestation memory p = T.Attestation(
            1,
            10,
            artistId,
            b.identityRecordHash,
            keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1"),
            keccak256(statement),
            "urn:waiver"
        );
        T.ActionContext memory c = T.ActionContext(
            24, address(artist), IStreamArtistOwner(suite.owners[4]).ownerStateSnapshotV2()
        );
        vm.prank(address(coordinator));
        avm.expectRevert(T.UnsupportedProfile.selector);
        IStreamArtistAttributionOwner(suite.owners[4])
            .recordAttestation(c, b, p, address(artist), 1, 1000, statement);
        bytes memory callback = abi.encodeCall(
            IStreamArtistIdentityAttestationOwner.recordIdentityAttestation,
            (c, b, p, b.identityRecordHash, address(artist), uint256(1), uint64(1000), statement)
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(suite.owners[4], callback);
    }

    function _contentProposal(bytes32 candidate) private view returns (Content.Consent memory) {
        return Content.Consent(
            1, address(metadata), keccak256("SCRIPT"), metadata.familyState(1, candidate)
        );
    }

    function _contentConsent(bytes32 candidate) private returns (bytes32) {
        Content.Consent memory p = _contentProposal(candidate);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.contentConsentDigest(p, a));
        return ingress.recordContentConsent(p, a);
    }

    function _contentFreezeProposal() private view returns (Content.Freeze memory) {
        bytes32[] memory locks = new bytes32[](1);
        locks[0] = keccak256("SCRIPT");
        return Content.Freeze(1, address(metadata), locks, metadata.artistContentFreezeState(1));
    }

    function _contentFreeze() private returns (bytes32) {
        Content.Freeze memory p = _contentFreezeProposal();
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.contentFreezeDigest(p, a));
        return ingress.authorizeArtistContentFreeze(p, a);
    }

    function testContentActualSafeDirectWriterPinsTypedDigestAndProtocolGuards() public {
        _accept();
        Content.Consent memory p = _contentProposal(keccak256("direct Safe artwork"));
        T.Authorization memory a = _authorization(false);
        StreamArtistHashes.Environment memory e = StreamArtistHashes.Environment(
            block.chainid, address(ingress), address(core), address(manager)
        );
        bytes32 expectedDigest = StreamArtistHashes.typed(
            e,
            keccak256(
                abi.encode(
                    bytes32(0x7908964dc70554ffd5c82353690255d1a8c338be77ffc0f8fb925a27d890587d),
                    address(core),
                    address(metadata),
                    uint256(1),
                    p.familyId,
                    p.newStateHash,
                    a.nonce,
                    a.time
                )
            )
        );
        require(
            ingress.contentConsentDigest(p, a) == expectedDigest, "canonical content typehash/order"
        );
        Content.Freeze memory freeze = _contentFreezeProposal();
        bytes32 expectedFreeze = StreamArtistHashes.typed(
            e,
            keccak256(
                abi.encode(
                    bytes32(0xfcb15d96b29996a5852bf06058ae82a7e8acaf7d7601b13fe881ada5d30fc63b),
                    address(core),
                    address(metadata),
                    uint256(1),
                    keccak256(abi.encodePacked(freeze.lockClasses)),
                    freeze.expectedStateHash,
                    a.nonce,
                    a.time
                )
            )
        );
        require(
            ingress.contentFreezeDigest(freeze, a) == expectedFreeze,
            "canonical freeze array/typehash/order"
        );
        bytes memory prepared =
            abi.encodeCall(IStreamArtistContentAuthority.recordContentConsent, (p, a));
        vm.warp(1030);
        require(
            executeSafe(artist, keys, address(ingress), 0, prepared, 0),
            "actual queued Safe direct content writer"
        );
        bytes32 record = ingress.contentConsentEvidence(1, p.familyId, p.newStateHash);
        (,, T.Authorization memory saved, T.SignerApproval memory proof,) = abi.decode(
            _operationPayload(17, address(artist), record),
            (T.Binding, Content.Consent, T.Authorization, T.SignerApproval, bytes32)
        );
        require(
            proof.direct && proof.signer == address(artist) && proof.digest == expectedDigest
                && saved.signature.length == 0 && saved.time == a.time,
            "direct proof distinct from empty relay"
        );
        bytes32 expectedRecord = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_CONTENT_CONSENT_RECORD_V1"),
                block.chainid,
                address(ingress),
                address(metadata),
                address(core),
                uint256(1),
                p.familyId,
                p.newStateHash,
                artistId,
                address(artist),
                uint8(1),
                a.nonce,
                uint64(1030)
            )
        );
        require(record == expectedRecord, "observed inclusion record time");
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        T.ActionContext memory c = T.ActionContext(
            17, address(artist), IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2()
        );
        bytes memory callback = abi.encodeCall(
            IStreamArtistContentIdentityOwner.consumeContentConsent, (c, b, p, a, proof)
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(suite.owners[2], callback);
        c.expected = IStreamArtistOwner(suite.owners[6]).ownerStateSnapshotV2();
        callback = abi.encodeCall(
            IStreamArtistContentRecordsOwner.recordContentConsent,
            (c, b, p, address(artist), a.nonce)
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(suite.owners[6], callback);
        callback = abi.encodeCall(
            IStreamArtistContentCoordinator.coordinateRecordContentConsent, (address(artist), p, a)
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(address(coordinator), callback);
    }

    function testContentSafeConsentEvolutionRepeatedTargetAndOldRecords() public {
        _all();
        bytes32 initial = metadata.content();
        bytes32 candidate = keccak256("artist approved second artwork");
        bytes32 first = _contentConsent(candidate);
        metadata.applyContent(1, candidate);
        ingress.requireMintConsent(1, PHASE, POLICY);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "unit consent consumed"));
        metadata.applyContent(1, candidate);
        bytes32 back = _contentConsent(initial);
        metadata.applyContent(1, initial);
        bytes32 third = _contentConsent(candidate);
        require(first != back && first != third, "fresh one-use record for repeated destination");
        metadata.applyContent(1, candidate);
        ingress.requireMintConsent(1, PHASE, POLICY);
        require(
            metadata.consumedContentRecord(first) && metadata.consumedContentRecord(back)
                && metadata.consumedContentRecord(third),
            "each applied write consumed its own record"
        );
        IStreamArtistContentRecordsOwner.ConsentRecord memory historical =
            IStreamArtistContentRecordsOwner(suite.owners[6]).contentConsentRecord(first);
        require(
            historical.recordHash == first
                && historical.terms.newStateHash == metadata.familyState(1, candidate),
            "history never overwritten"
        );
        _ratify();
        ingress.requireMintConsent(1, PHASE, POLICY);
        bytes32 next = keccak256("after new operative ratification");
        _contentConsent(next);
        metadata.applyContent(1, next);
        ingress.requireMintConsent(1, PHASE, POLICY);
    }

    function testContentRecordCanonicalEventArchiveAndDirectSafeRead() public {
        _accept();
        Content.Consent memory p = _contentProposal(keccak256("new content"));
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.contentConsentDigest(p, a));
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_CONTENT_CONSENT_RECORD_V1"),
                block.chainid,
                address(ingress),
                address(metadata),
                address(core),
                uint256(1),
                p.familyId,
                p.newStateHash,
                artistId,
                address(artist),
                uint8(1),
                a.nonce,
                uint64(block.timestamp)
            )
        );
        vm.recordLogs();
        bytes32 record = ingress.recordContentConsent(p, a);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool eventSeen;
        bool contextSeen;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != suite.owners[6]) continue;
            if (
                logs[i].topics[0]
                    == keccak256(
                        "ArtistContentConsentRecorded(uint16,uint256,bytes32,address,bytes32,uint8,uint256,uint64,bytes32)"
                    )
            ) {
                require(
                    logs[i].topics[1] == bytes32(uint256(1)) && logs[i].topics[2] == p.familyId
                        && logs[i].topics[3] == bytes32(uint256(uint160(address(artist)))),
                    "exact event identity"
                );
                require(
                    keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                p.newStateHash,
                                uint8(1),
                                a.nonce,
                                uint64(block.timestamp),
                                expected
                            )
                        ),
                    "exact observed event preimage"
                );
                eventSeen = true;
            }
            if (
                logs[i].topics[0]
                    == keccak256("ArtistContentRecordContext(uint16,bytes32,address,bytes32)")
            ) {
                require(
                    logs[i].topics[1] == record
                        && keccak256(logs[i].data)
                            == keccak256(abi.encode(uint16(1), address(metadata), artistId)),
                    "reconstruction context"
                );
                contextSeen = true;
            }
        }
        require(
            record == expected && eventSeen && contextSeen, "canonical content record and events"
        );
        (
            ,
            Content.Consent memory archived,
            T.Authorization memory authorization,
            T.SignerApproval memory proof,
        ) = abi.decode(
            _operationPayload(17, address(this), record),
            (T.Binding, Content.Consent, T.Authorization, T.SignerApproval, bytes32)
        );
        require(
            archived.newStateHash == p.newStateHash && authorization.time == a.time
                && proof.signer == address(artist),
            "original signed proof archive"
        );
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistContentAuthority.contentConsentDigest, (p, a)),
                0
            ),
            "Safe digest read"
        );
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistContentAuthority.requireContentConsent,
                    (uint256(1), p.familyId, p.newStateHash)
                ),
                0
            ),
            "Safe canonical require read"
        );
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistContentAuthority.contentConsentEvidence,
                    (uint256(1), p.familyId, p.newStateHash)
                ),
                0
            ),
            "Safe validating evidence read"
        );
    }

    function testContentDelayedDirectSafeDefensiveFreezeNeedsNoMintFloors() public {
        _accept();
        metadata.setContent(bytes32(0));
        Content.Freeze memory p = _contentFreezeProposal();
        T.Authorization memory a = _authorization(false);
        bytes memory prepared =
            abi.encodeCall(IStreamArtistContentAuthority.authorizeArtistContentFreeze, (p, a));
        vm.warp(1050);
        require(
            executeSafe(artist, keys, address(ingress), 0, prepared, 0),
            "queued defensive Safe action"
        );
        (bool valid, bytes32 record) = ingress.isContentFreezeAuthorized(1, keccak256("SCRIPT"));
        Content.FreezeRecord memory r = ingress.contentFreezeAuthorization(record);
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_CONTENT_FREEZE_RECORD_V1"),
                block.chainid,
                address(ingress),
                address(metadata),
                address(core),
                uint256(1),
                p.lockClasses,
                p.expectedStateHash,
                artistId,
                address(artist),
                uint8(1),
                a.nonce,
                uint64(1050)
            )
        );
        require(
            valid && record == expected && r.authorityClass == 1 && r.artistId == artistId
                && r.bindingGeneration == 1,
            "actual verified authority record"
        );
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistContentAuthority.contentFreezeDigest, (p, a)),
                0
            ),
            "Safe freeze digest"
        );
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistContentAuthority.isContentFreezeAuthorized,
                    (uint256(1), keccak256("SCRIPT"))
                ),
                0
            ),
            "Safe freeze authority read"
        );
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistContentAuthority.contentFreezeAuthorization, (record)),
                0
            ),
            "Safe historical freeze read"
        );
        metadata.applyFreeze(1, record);
        require(
            metadata.contentLocks(1, keccak256("SCRIPT")),
            "permissionless one-way application with empty artwork"
        );
        (valid,) = ingress.isContentFreezeAuthorized(1, keccak256("SCRIPT"));
        require(!valid, "already locked cannot be reapplied");
    }

    function testContentStaleFreezeCanRefreshWithoutDeletingHistory() public {
        _accept();
        bytes32 first = _contentFreeze();
        metadata.setContent(keccak256("pre-ratification iteration"));
        (bool valid,) = ingress.isContentFreezeAuthorized(1, keccak256("SCRIPT"));
        require(!valid, "old expected state no longer current");
        bytes32 second = _contentFreeze();
        require(
            first != second && ingress.contentFreezeAuthorization(first).recordHash == first,
            "stale authorization remains historical"
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "unit stale freeze"));
        metadata.applyFreeze(1, first);
        metadata.applyFreeze(1, second);
    }

    function testContentDisputedBoundaryBlocksConsentButPreservesDefensiveFreeze() public {
        _accept();
        // Explicit attribution-owner read boundary; this does not implement a dispute operation.
        avm.mockCall(
            suite.owners[4],
            abi.encodeCall(IStreamArtistAttributionOwner.attributionState, (uint256(1))),
            abi.encode(uint8(4), uint64(1))
        );
        Content.Consent memory p = _contentProposal(keccak256("disputed change"));
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.contentConsentDigest(p, a));
        bytes32 before_ = _roots();
        vm.expectRevert(abi.encodeWithSelector(T.InvalidAttribution.selector, uint256(1)));
        ingress.recordContentConsent(p, a);
        require(_roots() == before_, "dispute rejection atomic");
        bytes32 record = _contentFreeze();
        metadata.applyFreeze(1, record);
        require(
            metadata.contentLocks(1, keccak256("SCRIPT")),
            "defense still available in disputed boundary"
        );
        avm.clearMockedCalls();
    }

    function testContentLateArchiveFailureRollsBackBothOwnersAndLookupPointers() public {
        _accept();
        Content.Consent memory p = _contentProposal(keccak256("late rollback"));
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.contentConsentDigest(p, a));
        bytes32 before_ = _roots();
        bytes memory failure = abi.encodeWithSignature("Error(string)", "content archive failed");
        avm.mockCallRevert(
            address(archive),
            abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            failure
        );
        vm.expectRevert(failure);
        ingress.recordContentConsent(p, a);
        require(
            _roots() == before_
                && !ingress.artistAuthorizationState(artistId, bytes32(0), a.nonce).nonceConsumed,
            "content nonce and both roots restored"
        );
        avm.clearMockedCalls();
        bytes32 record = ingress.recordContentConsent(p, a);
        require(
            ingress.contentConsentEvidence(1, p.familyId, p.newStateHash) == record,
            "exact retry succeeds"
        );
        Content.Freeze memory freeze = _contentFreezeProposal();
        a = _authorization(false);
        a.signature = _signature(ingress.contentFreezeDigest(freeze, a));
        before_ = _roots();
        avm.mockCallRevert(
            address(archive),
            abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            failure
        );
        vm.expectRevert(failure);
        ingress.authorizeArtistContentFreeze(freeze, a);
        require(_roots() == before_, "freeze rollback preserves both owners");
        avm.clearMockedCalls();
        (bool valid,) = ingress.isContentFreezeAuthorized(1, keccak256("SCRIPT"));
        require(!valid, "failed freeze leaves no lookup record");
        ingress.authorizeArtistContentFreeze(freeze, a);
    }

    function testContentBadProofRevocationAndHostSubstitutionHaveNoEffects() public {
        _accept();
        Content.Consent memory p = _contentProposal(keccak256("future denied"));
        T.Authorization memory a = T.Authorization(71, 2000, "");
        bytes32 digest = ingress.contentConsentDigest(p, a);
        address ownerEoa = vm.addr(keys[0]);
        vm.prank(ownerEoa);
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordContentConsent(p, a);
        a.signature = _signature(keccak256("wrong domain"));
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordContentConsent(p, a);
        a.time = 999;
        a.signature = _signature(ingress.contentConsentDigest(p, a));
        vm.expectRevert(abi.encodeWithSelector(T.ExpiredAuthorization.selector, uint64(999)));
        ingress.recordContentConsent(p, a);
        a.time = 2000;
        StreamArtistAuthorizationTypes.Revocation memory revoke =
            StreamArtistAuthorizationTypes.Revocation(artistId, digest, 0);
        T.Authorization memory cancel = _authorization(false);
        cancel.signature = _signature(ingress.authorizationRevocationDigest(revoke, cancel));
        ingress.revokeArtistAuthorization(revoke, cancel);
        bytes32 deny = keccak256(
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
        a.signature = _signature(digest);
        bytes32 before_ = _roots();
        vm.expectRevert(abi.encodeWithSelector(T.Replay.selector, deny));
        ingress.recordContentConsent(p, a);
        p.metadataContract = address(0xBAD);
        vm.expectRevert(abi.encodeWithSelector(T.ComponentChanged.selector, address(0xBAD)));
        ingress.recordContentConsent(p, a);
        require(_roots() == before_, "denied content never changes records");
    }

    function testContentRejectsUnknownNoopAndMalformedLocksBeforeNonce() public {
        _accept();
        Content.Consent memory p = _contentProposal(metadata.content());
        T.Authorization memory a = T.Authorization(nextNonce, 2000, "");
        a.signature = _signature(ingress.contentConsentDigest(p, a));
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.recordContentConsent(p, a);
        p.familyId = keccak256("UNKNOWN");
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.recordContentConsent(p, a);
        Content.Freeze memory freeze = _contentFreezeProposal();
        freeze.lockClasses[0] = keccak256("DEPENDENCIES");
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.authorizeArtistContentFreeze(freeze, a);
        freeze.lockClasses[0] = bytes32(0);
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.authorizeArtistContentFreeze(freeze, a);
        freeze.lockClasses = new bytes32[](2);
        freeze.lockClasses[0] = keccak256("SCRIPT");
        freeze.lockClasses[1] = freeze.lockClasses[0];
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.authorizeArtistContentFreeze(freeze, a);
        freeze.lockClasses[0] = bytes32(uint256(2));
        freeze.lockClasses[1] = bytes32(uint256(1));
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.authorizeArtistContentFreeze(freeze, a);
        freeze.lockClasses = new bytes32[](17);
        vm.expectRevert(abi.encodeWithSelector(T.BoundExceeded.selector, uint256(17), uint256(16)));
        ingress.authorizeArtistContentFreeze(freeze, a);
        require(
            !ingress.artistAuthorizationState(artistId, bytes32(0), a.nonce).nonceConsumed,
            "invalid shape never authorizes"
        );
    }

    function testContentApprovedEmptySafeAndProtocolCallbacksRemainDistinct() public {
        _accept();
        Content.Consent memory p = _contentProposal(keccak256("approved empty content"));
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.contentConsentDigest(p, a);
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordContentConsent(p, a);
        _approveMessage(digest);
        ingress.recordContentConsent(p, a);
        Content.Freeze memory freeze = _contentFreezeProposal();
        a = _authorization(false);
        digest = ingress.contentFreezeDigest(freeze, a);
        _approveMessage(digest);
        bytes32 record = ingress.authorizeArtistContentFreeze(freeze, a);
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        T.ActionContext memory c = T.ActionContext(
            21, address(artist), IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2()
        );
        T.SignerApproval memory proof = T.SignerApproval(address(artist), digest, true);
        bytes memory call_ = abi.encodeCall(
            IStreamArtistContentIdentityOwner.consumeContentFreeze, (c, b, freeze, a, proof)
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(suite.owners[2], call_);
        c.expected = IStreamArtistOwner(suite.owners[6]).ownerStateSnapshotV2();
        call_ = abi.encodeCall(
            IStreamArtistContentRecordsOwner.authorizeContentFreeze,
            (c, b, freeze, address(artist), a.nonce)
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(suite.owners[6], call_);
        call_ = abi.encodeCall(
            IStreamArtistContentCoordinator.coordinateAuthorizeArtistContentFreeze,
            (address(artist), freeze, a)
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(address(coordinator), call_);
        require(
            ingress.contentFreezeAuthorization(record).recordHash == record,
            "direct callback rejection leaves signed record intact"
        );
    }

    function testContentEvolutionWitnessMustMatchActualStateAndCurrentRatification() public {
        _all();
        (, bytes32 ratified, bytes32 record) = ingress.firstReleaseRatification(1);
        bytes32 candidate = keccak256("unconsented drift");
        metadata.setContent(candidate);
        bytes memory failure = abi.encodeWithSelector(
            T.MissingMintPrerequisite.selector, keccak256("content-ratification")
        );
        vm.expectRevert(failure);
        ingress.requireMintConsent(1, PHASE, POLICY);
        metadata.setEvolution(1, record, ratified);
        vm.expectRevert(failure);
        ingress.requireMintConsent(1, PHASE, POLICY);
        metadata.setEvolution(
            1, keccak256("wrong operative record"), metadata.artistContentFreezeState(1)
        );
        vm.expectRevert(failure);
        ingress.requireMintConsent(1, PHASE, POLICY);
        // Even a valid new target signature cannot extend an unconsented predecessor.
        bytes32 next = keccak256("next state");
        _contentConsent(next);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "unit predecessor"));
        metadata.applyContent(1, next);
        _ratify();
        metadata.applyContent(1, next);
        ingress.requireMintConsent(1, PHASE, POLICY);
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
                uint16(16),
                uint16(17),
                uint16(18),
                uint16(20),
                uint16(21),
                uint16(24),
                uint16(25),
                uint16(26),
                uint16(27),
                uint16(28),
                uint16(29),
                uint16(30),
                uint16(31),
                uint16(32),
                uint16(33),
                uint16(36),
                uint16(37),
                uint16(38),
                uint16(39),
                uint16(40),
                uint16(51),
                uint16(52),
                uint16(54),
                uint16(58)
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
        vm.expectRevert(abi.encodeWithSelector(T.InvalidAttribution.selector, uint256(1)));
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
        vm.expectRevert(abi.encodeWithSelector(T.InvalidAttribution.selector, uint256(1)));
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

    uint256[] private rotationKeys;
    OfficialSafe private rotationSafe;

    function _rotateCollaboratorToNewSafe() private returns (bytes32 record) {
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

    function testRotationAcceptedCollaboratorKeepsIdentityJoinAndActualFixedWallet() public {
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
        bytes32 priorRow = keccak256(abi.encode(ingress.collaboratorAt(1, row.generation, 0)));
        _newRotationSafe(9018);
        bytes32 transition = _rotateCollaboratorToNewSafe();
        (address account, bytes32 priorPayout) =
            ingress.collaboratorPayoutAccount(collaboratorId, address(delegateSafe));
        require(
            account == address(delegateSafe) && priorPayout != bytes32(0),
            "accepted row joins identity, not current authority address"
        );
        T.PayoutDesignation memory payout =
            T.PayoutDesignation(collaboratorId, address(rotationSafe), priorPayout);
        T.Authorization memory a = T.Authorization(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(collaboratorId).nonceHint,
            uint64(block.timestamp),
            ""
        );
        a.signature = safeThresholdSignature(
            rotationKeys,
            safeMessageDigest(rotationSafe, abi.encode(ingress.payoutDesignationDigest(payout, a)))
        );
        bytes32 fresh = ingress.recordPayoutDesignation(payout, a);
        (account,) = ingress.collaboratorPayoutAccount(collaboratorId, address(delegateSafe));
        require(account == address(delegateSafe), "provisional designation not operative");
        ingress.requireMintConsent(1, PHASE, POLICY);
        vm.warp(ingress.rotationRecord(transition).transition.postWindowEndsAt);
        (account, priorPayout) =
            ingress.collaboratorPayoutAccount(collaboratorId, address(delegateSafe));
        require(
            account == address(rotationSafe) && priorPayout == fresh,
            "same accepted identity now resolves matured payout"
        );
        require(
            keccak256(abi.encode(ingress.collaboratorAt(1, row.generation, 0))) == priorRow,
            "historical row immutable"
        );
        ingress.requireMintConsent(1, PHASE, POLICY);
        vm.deal(address(this), 1 ether);
        (bool sent,) = wallet.call{ value: 1 ether }("");
        require(sent, "fund prior concrete profile");
        uint256 beforeBalance = address(delegateSafe).balance;
        IStreamSplitWallet(wallet)
            .release(address(0), address(delegateSafe), payable(address(delegateSafe)));
        require(
            address(delegateSafe).balance == beforeBalance + 0.2 ether
                && IStreamSplitWallet(wallet).aggregateSharePpm(address(rotationSafe)) == 0,
            "fixed wallet preserves consent-time collaborator recipient"
        );
    }

    function testRotationPendingCollaboratorTupleCannotSubstituteNewAuthorityButCanRepropose()
        public
    {
        _collaboratorIdentity(false);
        C.BindingAcceptance memory row = _collaborativeProposal(false);
        _accept();
        T.Authorization memory prepared = T.Authorization(1, uint64(block.timestamp + 30 days), "");
        prepared.signature = safeThresholdSignature(
            delegateKeys,
            safeMessageDigest(
                delegateSafe, abi.encode(ingress.collaboratorAcceptanceDigest(row, prepared))
            )
        );
        _newRotationSafe(9019);
        _rotateCollaboratorToNewSafe();
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(T.InvalidIdentity.selector, bytes32(0)));
        ingress.acceptCollaborator(row, prepared);
        C.BindingAcceptance memory substitute = C.BindingAcceptance(
            row.collectionId,
            row.generation,
            row.bindingHash,
            address(rotationSafe),
            row.role,
            row.shareLabelId
        );
        T.Authorization memory a = T.Authorization(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(collaboratorId).nonceHint,
            uint64(block.timestamp + 1 days),
            ""
        );
        a.signature = safeThresholdSignature(
            rotationKeys,
            safeMessageDigest(
                rotationSafe, abi.encode(ingress.collaboratorAcceptanceDigest(substitute, a))
            )
        );
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        ingress.acceptCollaborator(substitute, a);
        require(
            _roots() == roots && !ingress.collaboratorAt(1, row.generation, 0).accepted,
            "pending tuple and old proof stay exact"
        );
        delegateSafe = rotationSafe;
        delegateKeys = rotationKeys;
        C.BindingAcceptance memory replacement = _collaborativeProposal(false);
        require(
            replacement.generation == row.generation + 1
                && replacement.account == address(rotationSafe),
            "new generation names exact current account"
        );
        a.signature = safeThresholdSignature(
            rotationKeys,
            safeMessageDigest(
                rotationSafe, abi.encode(ingress.collaboratorAcceptanceDigest(replacement, a))
            )
        );
        ingress.acceptCollaborator(replacement, a);
        _accept();
        require(
            ingress.acceptedArtist(1) == address(artist), "reproposed row completes actual binding"
        );
    }

    function testRotationRetiredAccountNewIdentityLinksPendingTupleWithoutReusingOldIdentity()
        public
    {
        _collaboratorIdentity(false);
        C.BindingAcceptance memory row = _collaborativeProposal(false);
        _accept();
        bytes32 formerIdentity = collaboratorId;
        _newRotationSafe(9020);
        _rotateCollaboratorToNewSafe();
        bytes memory document = bytes("new identity at retired account");
        C.IdentityProposal memory p = C.IdentityProposal(
            address(delegateSafe),
            keccak256(document),
            "urn:reused",
            keccak256("new identity"),
            "urn:reason"
        );
        ingress.proposeCollaboratorIdentity(p);
        T.Authorization memory a = T.Authorization(1, uint64(block.timestamp + 1 days), "");
        a.signature = safeThresholdSignature(
            delegateKeys,
            safeMessageDigest(
                delegateSafe,
                abi.encode(ingress.collaboratorIdentityDigest(p.account, p.identityRecordHash, a))
            )
        );
        bytes32 newIdentity = ingress.acceptCollaboratorIdentity(
            p.account, p.identityRecordHash, a, document, "Retired account identity"
        );
        require(
            newIdentity != formerIdentity
                && IStreamArtistIdentityOwner(suite.owners[2]).activeIdentity(address(rotationSafe))
                    == formerIdentity,
            "distinct actual identities"
        );
        a.nonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(newIdentity).nonceHint;
        a.signature = safeThresholdSignature(
            delegateKeys,
            safeMessageDigest(
                delegateSafe, abi.encode(ingress.collaboratorAcceptanceDigest(row, a))
            )
        );
        ingress.acceptCollaborator(row, a);
        require(
            ingress.collaboratorAt(1, row.generation, 0).collaboratorArtistId == newIdentity,
            "unaccepted row joins active identity at exact account"
        );
        require(
            ingress.acceptedArtist(1) == address(artist),
            "primary history completes with actual new join"
        );
    }

    function testRotationExecutionRejectsDestinationRegisteredAfterStageAndRollsBack() public {
        _newRotationSafe(9021);
        bytes32 record = _stageRotation(bytes32(0));
        bytes memory document = bytes("independent destination identity");
        C.IdentityProposal memory p = C.IdentityProposal(
            address(rotationSafe),
            keccak256(document),
            "urn:occupied",
            keccak256("registration"),
            "urn:reason"
        );
        ingress.proposeCollaboratorIdentity(p);
        T.Authorization memory a = T.Authorization(0, uint64(block.timestamp + 1 days), "");
        a.signature = safeThresholdSignature(
            rotationKeys,
            safeMessageDigest(
                rotationSafe,
                abi.encode(ingress.collaboratorIdentityDigest(p.account, p.identityRecordHash, a))
            )
        );
        bytes32 otherIdentity = ingress.acceptCollaboratorIdentity(
            p.account, p.identityRecordHash, a, document, "Destination identity"
        );
        vm.warp(ingress.rotationRecord(record).transition.contestEndsAt);
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(T.AddressAlreadyRegistered.selector, address(rotationSafe))
        );
        ingress.executeArtistRotation(artistId, record);
        require(
            _roots() == roots && ingress.rotationRecord(record).transition.phase == 1,
            "execution effects rollback while stage persists"
        );
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).activeIdentity(address(artist)) == artistId
                && IStreamArtistIdentityOwner(suite.owners[2]).activeIdentity(address(rotationSafe))
                == otherIdentity,
            "both actual active-address owners preserved"
        );
    }

    function testRotationBothSafeSidesSupportPreapprovedEmptyProofs() public {
        _newRotationSafe(9022);
        R.Rotation memory p = _rotationTerms(bytes32(0));
        (T.Authorization memory oldA, T.Authorization memory newA) = _rotationAuthorizations(p);
        oldA.signature = "";
        newA.signature = "";
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(T.InvalidSignature.selector));
        ingress.rotateArtistAddress(p, oldA, newA);
        _approveMessage(ingress.rotationDigest(p, oldA));
        vm.expectRevert(abi.encodeWithSelector(T.InvalidSignature.selector));
        ingress.rotateArtistAddress(p, oldA, newA);
        require(_roots() == roots, "both contract approvals required before replay effects");
        bytes32 digest = ingress.rotationAcceptanceDigest(p, newA);
        require(
            executeSafe(
                rotationSafe,
                rotationKeys,
                safeComponents.signMessage,
                0,
                abi.encodeWithSignature("signMessage(bytes)", abi.encode(digest)),
                1
            ),
            "new Safe approves exact Stream digest"
        );
        bytes32 record = ingress.rotateArtistAddress(p, oldA, newA);
        require(
            ingress.rotationRecord(record).oldNonce == oldA.nonce
                && ingress.rotationRecord(record).newNonce == newA.nonce,
            "both approved-empty signatures recorded in exact lanes"
        );
    }

    function testRotationMaximumGuardianSetDirectOldSafeAndDuplicateApproval() public {
        address[] memory guardians_ = new address[](9);
        for (uint256 i; i < 8; ++i) {
            guardians_[i] = address(uint160(i + 1));
        }
        guardians_[8] = address(artist);
        R.GuardianSet memory p = R.GuardianSet(artistId, guardians_, 1, 0);
        T.Authorization memory a = T.Authorization(0, uint64(block.timestamp), "");
        a.signature = _signature(ingress.guardianSetDigest(p, a));
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(R.InvalidGuardianSet.selector));
        ingress.setArtistGuardians(p, a);
        p.guardians = new address[](8);
        for (uint256 i; i < 7; ++i) {
            p.guardians[i] = address(uint160(i + 1));
        }
        p.guardians[7] = address(artist);
        p.guardians[1] = p.guardians[0];
        a.signature = _signature(ingress.guardianSetDigest(p, a));
        vm.expectRevert(abi.encodeWithSelector(R.InvalidGuardianSet.selector));
        ingress.setArtistGuardians(p, a);
        p.guardians[1] = address(2);
        p.approvalThreshold = 9;
        a.signature = _signature(ingress.guardianSetDigest(p, a));
        vm.expectRevert(abi.encodeWithSelector(R.InvalidGuardianSet.selector));
        ingress.setArtistGuardians(p, a);
        p.approvalThreshold = 1;
        p.minContestSeconds = 31 days;
        a.signature = _signature(ingress.guardianSetDigest(p, a));
        vm.expectRevert(abi.encodeWithSelector(R.InvalidGuardianSet.selector));
        ingress.setArtistGuardians(p, a);
        require(_roots() == roots, "invalid guardian terms leave replay and roots untouched");
        p.minContestSeconds = 0;
        a.signature = _signature(ingress.guardianSetDigest(p, a));
        bytes32 guardianRecord = ingress.setArtistGuardians(p, a);
        nextNonce = 1;
        _newRotationSafe(9023);
        R.Rotation memory terms = _rotationTerms(bytes32(0));
        (T.Authorization memory oldA, T.Authorization memory newA) = _rotationAuthorizations(terms);
        oldA.signature = "";
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistRotation.rotateArtistAddress, (terms, oldA, newA)),
                0
            ),
            "old Safe directly stages with signed new threshold Safe"
        );
        (bytes32 record,,) = ingress.activeAuthorityWindow(artistId);
        require(
            ingress.rotationRecord(record).guardianSetRecordHash == guardianRecord,
            "maximum set captured"
        );
        bytes memory approval =
            abi.encodeCall(IStreamArtistRotation.approveArtistRotation, (artistId, record));
        require(
            executeSafe(artist, keys, address(ingress), 0, approval, 0),
            "actual guardian Safe approves"
        );
        bytes32 key = _identityRevisionReplayKey(
            keccak256("identity_authority.replay.guardian_approval_key"),
            keccak256(abi.encode(record, address(artist)))
        );
        roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(T.Replay.selector, key));
        vm.prank(address(artist));
        ingress.approveArtistRotation(artistId, record);
        require(
            _roots() == roots && ingress.rotationRecord(record).guardianApprovals == 1,
            "exact duplicate approval replay rolls back"
        );
        ingress.executeArtistRotation(artistId, record);
    }

    function _newRotationSafe(uint256 salt) private {
        rotationKeys = new uint256[](2);
        rotationKeys[0] = 0xCA1100 + salt;
        rotationKeys[1] = 0xCA2200 + salt;
        rotationSafe = createOfficialSafe(safeComponents, safeOwnerAddresses(rotationKeys), 2, salt);
    }

    function _rotationTerms(bytes32 previous) private view returns (R.Rotation memory) {
        return R.Rotation(
            artistId, address(artist), address(rotationSafe), keccak256("artist rotation"), previous
        );
    }

    function _rotationAuthorizations(R.Rotation memory p)
        private
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

    function _stageRotation(bytes32 previous) private returns (bytes32 record) {
        R.Rotation memory p = _rotationTerms(previous);
        (T.Authorization memory oldA, T.Authorization memory newA) = _rotationAuthorizations(p);
        record = ingress.rotateArtistAddress(p, oldA, newA);
    }

    function _executeTimedRotation(bytes32 record) private {
        R.RotationRecord memory r = ingress.rotationRecord(record);
        vm.warp(r.transition.contestEndsAt);
        ingress.executeArtistRotation(artistId, record);
    }

    function _adoptRotatedSafe() private {
        artist = rotationSafe;
        keys = rotationKeys;
        nextNonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
    }

    function _guardianRecord(
        address[] memory guardians_,
        uint32 threshold,
        uint64 floor,
        uint256 nonce
    ) private returns (bytes32 record) {
        R.GuardianSet memory p = R.GuardianSet(artistId, guardians_, threshold, floor);
        T.Authorization memory a = T.Authorization(nonce, uint64(block.timestamp), "");
        a.signature = safeThresholdSignature(
            keys, safeMessageDigest(artist, abi.encode(ingress.guardianSetDigest(p, a)))
        );
        record = ingress.setArtistGuardians(p, a);
        nextNonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
    }

    function testRotationTwoRealSafesTimedExecutionKeepsBindingAndStoredConsent() public {
        _all();
        T.Binding memory beforeBinding = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        bytes32 payoutBefore;
        (, payoutBefore) = ingress.artistPayoutAccount(artistId);
        address retired = address(artist);
        _newRotationSafe(9001);
        bytes32 record = _stageRotation(bytes32(0));
        R.RotationRecord memory staged = ingress.rotationRecord(record);
        require(
            staged.transition.phase == 1 && staged.effectiveWindow == 7 days, "real staged window"
        );
        require(ingress.acceptedArtist(1) == retired, "staging does not rotate");
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(R.RotationNotExecutable.selector, record));
        ingress.executeArtistRotation(artistId, record);
        require(_roots() == roots, "premature execute rollback");
        T.Identity memory identityBefore =
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        _executeTimedRotation(record);
        T.Identity memory identityAfter =
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        require(
            identityAfter.authorityAddress == address(rotationSafe), "current authority rotated"
        );
        require(
            identityAfter.lastAuthorityActionAt == identityBefore.lastAuthorityActionAt,
            "execute no liveness"
        );
        require(
            keccak256(abi.encode(beforeBinding))
                == keccak256(abi.encode(IStreamArtistBindingOwner(suite.owners[0]).binding(1))),
            "binding immutable"
        );
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).activeIdentity(retired) == bytes32(0),
            "old active lane cleared"
        );
        require(
            ingress.acceptedArtist(1) == address(rotationSafe), "accepted read current principal"
        );
        (, bytes32 payoutAfter) = ingress.artistPayoutAccount(artistId);
        require(
            payoutAfter == payoutBefore && !_closed(_mintCall()),
            "stored consent and payout survive"
        );
        require(
            ingress.lastArtistTransition(artistId) == record, "concurrency guard remains readable"
        );
        R.RotationRecord memory executed = ingress.rotationRecord(record);
        require(
            executed.transition.postWindowEndsAt == block.timestamp + 7 days, "captured post window"
        );
    }

    function testRotationRealSafeGuardianQuorumAndCapturedSet() public {
        _newRotationSafe(9002);
        address[] memory guardians_ = new address[](2);
        guardians_[0] = address(artist);
        guardians_[1] = address(rotationSafe);
        if (guardians_[0] > guardians_[1]) {
            (guardians_[0], guardians_[1]) = (guardians_[1], guardians_[0]);
        }
        bytes32 setRecord = _guardianRecord(guardians_, 2, 8 days, 0);
        bytes32 record = _stageRotation(bytes32(0));
        uint64 beforeTime = uint64(block.timestamp);
        bytes memory approval =
            abi.encodeCall(IStreamArtistRotation.approveArtistRotation, (artistId, record));
        address guardianOwner = vm.addr(keys[0]);
        vm.prank(guardianOwner);
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, guardianOwner));
        ingress.approveArtistRotation(artistId, record);
        require(executeSafe(artist, keys, address(ingress), 0, approval, 0), "old guardian Safe");
        vm.expectRevert(abi.encodeWithSelector(R.RotationNotExecutable.selector, record));
        ingress.executeArtistRotation(artistId, record);
        require(
            executeSafe(rotationSafe, rotationKeys, address(ingress), 0, approval, 0),
            "second guardian Safe"
        );
        ingress.executeArtistRotation(artistId, record);
        R.RotationRecord memory r = ingress.rotationRecord(record);
        require(
            r.guardianSetRecordHash == setRecord && r.guardianApprovals == 2,
            "captured threshold facts"
        );
        require(
            r.transition.executedAt == beforeTime
                && r.transition.postWindowEndsAt == beforeTime + 8 days,
            "quorum exact fast path"
        );
    }

    function testRotationVetoRemainsContestedAndDefensiveOperationsStayUsable() public {
        _all();
        _delegateSetup();
        bytes32 grant = _grant(_delegation(1, 4, 1000, uint64(1000 + 500 days), 0));
        _newRotationSafe(9003);
        bytes32 record = _stageRotation(bytes32(0));
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistRotation.vetoArtistRotation,
                    (artistId, record, keccak256("compromise"))
                ),
                0
            ),
            "actual Safe veto"
        );
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).status == 4,
            "contested status"
        );
        vm.warp(block.timestamp + 365 days);
        require(_closed(_mintCall()), "no contested timeout bypass");
        bytes32 roots = _roots();
        R.GuardianSet memory p = R.GuardianSet(artistId, new address[](0), 0, 0);
        T.Authorization memory a = T.Authorization(nextNonce, uint64(block.timestamp), "");
        a.signature = _signature(ingress.guardianSetDigest(p, a));
        vm.expectRevert(abi.encodeWithSelector(T.InvalidIdentity.selector, artistId));
        ingress.setArtistGuardians(p, a);
        require(_roots() == roots, "normal mutation blocked");
        _authorizeFreeze();
        _contentFreeze();
        _revoke(grant);
        T.Authorization memory revokeA = _authorization(false);
        StreamArtistAuthorizationTypes.Revocation memory revokeP =
            StreamArtistAuthorizationTypes.Revocation(
                artistId, keccak256("unused contested authorization"), 0
            );
        revokeA.signature = _signature(ingress.authorizationRevocationDigest(revokeP, revokeA));
        ingress.revokeArtistAuthorization(revokeP, revokeA);
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).status == 4,
            "defense does not unfreeze"
        );
    }

    function testRotationDirectNewSafeAcceptanceAndLateArchiveRollback() public {
        _newRotationSafe(9004);
        R.Rotation memory p = _rotationTerms(bytes32(0));
        (T.Authorization memory oldA, T.Authorization memory newA) = _rotationAuthorizations(p);
        newA.signature = "";
        bytes memory callData =
            abi.encodeCall(IStreamArtistRotation.rotateArtistAddress, (p, oldA, newA));
        bytes32 roots = _roots();
        bytes32 expected = StreamArtistRotationHashes.rotationRecord(
            StreamArtistHashes.Environment(
                block.chainid, address(ingress), suite.core, suite.mintManager
            ),
            p,
            oldA.nonce,
            uint64(block.timestamp),
            uint64(block.timestamp + 7 days)
        );
        bytes32 evidenceId = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(ingress),
                address(coordinator),
                uint16(29),
                address(rotationSafe),
                expected
            )
        );
        avm.mockCallRevert(
            address(archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(T.InvalidRecord.selector)
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeRotationNewSafe(callData);
        avm.clearMockedCalls();
        (bool used, uint256 hint) =
            ingress.rotationAcceptanceNonceState(artistId, address(rotationSafe), 0);
        require(!used && hint == 0 && _roots() == roots, "both lanes rollback");
        vm.expectRevert(
            abi.encodeWithSignature(
                "ArtistArchiveEvidenceUnavailable(bytes32,uint64)", evidenceId, uint64(1)
            )
        );
        archive.artistEvidenceMetadataV2(evidenceId, 1);
        require(
            executeSafe(rotationSafe, rotationKeys, address(ingress), 0, callData, 0),
            "new side actual direct Safe"
        );
        (used, hint) = ingress.rotationAcceptanceNonceState(artistId, address(rotationSafe), 0);
        require(used && hint == 1, "independent new side consumed");
    }

    function executeRotationNewSafe(bytes calldata data) external returns (bool) {
        require(msg.sender == address(this), "test only");
        return executeSafe(rotationSafe, rotationKeys, address(ingress), 0, data, 0);
    }

    function testRotationProvisionalFactsMatureWithoutMaintenanceAtExactBoundary() public {
        _all();
        bytes32 initialDocument = ingress.operativeIdentityRecord(artistId);
        (address oldPayout, bytes32 oldDesignation) = ingress.artistPayoutAccount(artistId);
        bytes32 oldGuardian = _guardianRecord(new address[](0), 0, 0, nextNonce);
        _newRotationSafe(9005);
        bytes32 transition = _stageRotation(bytes32(0));
        _executeTimedRotation(transition);
        _adoptRotatedSafe();
        uint64 end = ingress.rotationRecord(transition).transition.postWindowEndsAt;
        bytes memory document = bytes("rotated provisional identity");
        StreamArtistIdentityRevisionTypes.Revision memory revision =
            StreamArtistIdentityRevisionTypes.Revision(
                artistId, initialDocument, keccak256(document), "urn:rotated"
            );
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.identityRevisionDigest(revision, a));
        bytes32 identityRecord =
            ingress.recordIdentityRevision(revision, a, document, "Rotated Safe");
        T.PayoutDesignation memory payout =
            T.PayoutDesignation(artistId, address(artist), oldDesignation);
        a = _authorization(true);
        a.signature = _signature(ingress.payoutDesignationDigest(payout, a));
        bytes32 payoutRecord = ingress.recordPayoutDesignation(payout, a);
        address[] memory newGuardians = new address[](1);
        newGuardians[0] = address(artist);
        bytes32 guardian = _guardianRecord(newGuardians, 1, 9 days, nextNonce);
        require(
            ingress.identityRevisionProvisionalAssociation(identityRecord).transitionRecordHash
                == transition,
            "identity cohort"
        );
        require(
            ingress.payoutDesignationProvisionalAssociation(payoutRecord).windowEndsAt == end,
            "payout cohort"
        );
        require(
            ingress.guardianSetRecord(guardian).provisional.windowEndsAt == end, "guardian cohort"
        );
        vm.warp(end - 1);
        require(
            ingress.operativeIdentityRecord(artistId) == initialDocument, "identity provisional"
        );
        (address currentPayout,) = ingress.artistPayoutAccount(artistId);
        (,,, bytes32 currentGuardian) = ingress.guardianSet(artistId);
        require(
            currentPayout == oldPayout && currentGuardian == oldGuardian && !_closed(_mintCall()),
            "prior operative floors"
        );
        bytes32 roots = _roots();
        vm.warp(end);
        require(
            ingress.operativeIdentityRecord(artistId) == keccak256(document),
            "identity matures at equality"
        );
        (currentPayout,) = ingress.artistPayoutAccount(artistId);
        (,,, currentGuardian) = ingress.guardianSet(artistId);
        require(
            currentPayout == address(artist) && currentGuardian == guardian,
            "payout and guardians mature"
        );
        require(
            _roots() == roots
                && ingress.rotationRecord(transition).transition.postWindowEndsAt == end,
            "time-only no maintenance or extension"
        );
        require(_closed(_mintCall()), "personhood tracks operative hash");
        _attest(
            10, artistId, keccak256(document), keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")
        );
        require(!_closed(_mintCall()), "restored personhood and old static consents");
    }

    function testRotationSingleActiveWindowAndPriorStandingTail() public {
        _newRotationSafe(9006);
        address oldAddress = address(artist);
        bytes32 transition = _stageRotation(bytes32(0));
        _executeTimedRotation(transition);
        _adoptRotatedSafe();
        R.RotationRecord memory r = ingress.rotationRecord(transition);
        _newRotationSafe(9007);
        R.Rotation memory p = _rotationTerms(transition);
        (T.Authorization memory oldA, T.Authorization memory newA) = _rotationAuthorizations(p);
        vm.expectRevert(
            abi.encodeWithSelector(
                R.ActiveAuthorityWindow.selector, transition, r.transition.postWindowEndsAt
            )
        );
        ingress.rotateArtistAddress(p, oldA, newA);
        --nextNonce;
        R.StandingRevocation memory revocation =
            R.StandingRevocation(artistId, oldAddress, keccak256("retired"), transition);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.standingRevocationDigest(revocation, a));
        vm.expectRevert(abi.encodeWithSelector(R.InvalidPriorStanding.selector, oldAddress));
        ingress.revokePriorAddressStanding(revocation, a);
        --nextNonce;
        vm.warp(uint256(r.transition.postWindowEndsAt) + r.standingTail);
        (bool revoked,) = ingress.priorAddressStandingRevoked(artistId, oldAddress);
        require(!revoked, "standing survives time alone");
        a = _authorization(false);
        a.signature = _signature(ingress.standingRevocationDigest(revocation, a));
        bytes32 record = ingress.revokePriorAddressStanding(revocation, a);
        (revoked,) = ingress.priorAddressStandingRevoked(artistId, oldAddress);
        require(
            revoked
                && ingress.standingRevocationRecord(record).terms.retiredTransitionRecordHash
                    == transition,
            "exact recorded standing retirement"
        );
        require(_stageRotation(transition) != bytes32(0), "second rotation after window");
    }

    function testRotationNewPrincipalAcceptsHistoricalProposalAndOldProofStopsVerifying() public {
        T.Authorization memory stale = T.Authorization(200, uint64(block.timestamp + 30 days), "");
        stale.signature = _signature(ingress.acceptanceDigest(1, stale));
        bytes32 beforeBinding =
            keccak256(abi.encode(IStreamArtistBindingOwner(suite.owners[0]).binding(1)));
        _newRotationSafe(9008);
        bytes32 transition = _stageRotation(bytes32(0));
        _executeTimedRotation(transition);
        bytes32 roots = _roots();
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.acceptArtistBinding(1, stale);
        require(_roots() == roots, "stale old-key payload rollback");
        _adoptRotatedSafe();
        _accept();
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        require(
            b.accepted && b.artistAddress != address(artist)
                && ingress.acceptedArtist(1) == address(artist),
            "historical proposal current acceptance"
        );
        b.accepted = false;
        require(keccak256(abi.encode(b)) == beforeBinding, "only acceptance bit advanced");
    }

    function testRotationActualExtensionPinsViewsAndOwnerCallerBoundaries() public {
        _all();
        StreamArtistIdentityAuthority identity = StreamArtistIdentityAuthority(suite.owners[2]);
        address writer = identity.identityWriterExtension();
        require(writer == avm.computeCreateAddress(address(identity), 1), "Identity child CREATE");
        require(
            ingress.registryWriterExtension() == avm.computeCreateAddress(address(ingress), 1),
            "facade writer CREATE"
        );
        require(
            ingress.registryReadExtension() == avm.computeCreateAddress(address(ingress), 2),
            "facade reader CREATE"
        );
        require(
            address(identity).code.length <= 24576 && writer.code.length <= 24576
                && address(ingress).code.length <= 24576,
            "production runtimes"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistIdentityWriterExtension.ExtensionWrongHost.selector, writer
            )
        );
        StreamArtistIdentityWriterExtension(writer).ownerStateSnapshotV2();
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistIdentityWriterExtension.ExtensionWrongHost.selector, writer
            )
        );
        StreamArtistIdentityWriterExtension(writer).replayCell(bytes32(0));
        T.ActionContext memory context =
            T.ActionContext(18, address(artist), identity.ownerStateSnapshotV2());
        T.Authorization memory a = T.Authorization(nextNonce, uint64(block.timestamp), "");
        T.PayoutDesignation memory p = T.PayoutDesignation(artistId, address(123), bytes32(0));
        T.SignerApproval memory proof;
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(this)));
        identity.consumePayout(context, p, a, proof);
        address registryWriter = ingress.registryWriterExtension();
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistRegistryWriterExtension.ExtensionWrongHost.selector, registryWriter
            )
        );
        StreamArtistRegistryWriterExtension(registryWriter).recordPayoutDesignation(p, a);
        address reader = ingress.registryReadExtension();
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistRegistryReadExtension.ExtensionWrongHost.selector, address(this)
            )
        );
        StreamArtistRegistryReadExtension(reader).identityRecordBytes(artistId);
    }

    function testRotationDelayedDirectGuardianSafePreservesSubmittedSentinelAndExactEvent() public {
        R.GuardianSet memory p = R.GuardianSet(artistId, new address[](1), 1, 9 days);
        p.guardians[0] = address(artist);
        T.Authorization memory submitted = T.Authorization(0, 0, "");
        bytes memory data = abi.encodeCall(IStreamArtistRotation.setArtistGuardians, (p, submitted));
        vm.warp(1042);
        vm.recordLogs();
        require(executeSafe(artist, keys, address(ingress), 0, data, 0), "delayed guardian Safe");
        (,,, bytes32 record) = ingress.guardianSet(artistId);
        R.GuardianSet memory archivedTerms;
        T.SignerApproval memory proof;
        T.Authorization memory effective;
        R.GuardianRecord memory archivedRecord;
        (archivedTerms, submitted, proof, effective, archivedRecord) = abi.decode(
            _operationPayload(28, address(artist), record),
            (R.GuardianSet, T.Authorization, T.SignerApproval, T.Authorization, R.GuardianRecord)
        );
        require(
            submitted.time == 0 && effective.time == 1042 && proof.direct,
            "original sentinel and effective time distinct"
        );
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
        bytes32 message = keccak256(
            abi.encode(
                keccak256(
                    "StreamArtistGuardianSet(bytes32 artistId,address[] guardians,uint32 approvalThreshold,uint64 minContestSeconds,uint256 nonce,uint64 signedAt)"
                ),
                artistId,
                keccak256(abi.encodePacked(p.guardians)),
                uint32(1),
                uint64(9 days),
                uint256(0),
                uint64(1042)
            )
        );
        require(
            proof.digest == keccak256(abi.encodePacked(hex"1901", domain, message)),
            "independent facade domain and permanent fields"
        );
        require(
            record
                == keccak256(
                    abi.encode(
                        bytes32(0xfb979fce9edd361cf23ba8baee900f7054451db7b563ba0ab11a5ef3621cd297),
                        block.chainid,
                        address(ingress),
                        artistId,
                        p.guardians,
                        uint32(1),
                        uint64(9 days),
                        uint256(0),
                        uint64(1042)
                    )
                ),
            "canonical guardian record"
        );
        require(
            archivedRecord.recordHash == record
                && keccak256(abi.encode(archivedTerms)) == keccak256(abi.encode(p)),
            "retained terms"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 found;
        bytes32 topic = keccak256(
            "ArtistGuardianSetUpdated(uint16,bytes32,address[],uint32,uint64,uint8,uint256,uint64,bytes32)"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics[0] == topic) {
                require(
                    logs[i].emitter == suite.owners[2] && logs[i].topics[1] == artistId,
                    "Identity remains emitter"
                );
                (
                    uint16 schema,
                    address[] memory members,
                    uint32 threshold,
                    uint64 floor,
                    uint8 class_,
                    uint256 nonce,
                    uint64 time,
                    bytes32 emitted
                ) = abi.decode(
                    logs[i].data,
                    (uint16, address[], uint32, uint64, uint8, uint256, uint64, bytes32)
                );
                require(
                    schema == 1 && members[0] == address(artist) && threshold == 1
                        && floor == 9 days && class_ == 1 && nonce == 0 && time == 1042
                        && emitted == record,
                    "exact guardian event"
                );
                ++found;
            }
        }
        require(found == 1, "one normative event");
    }

    function testRotationWindowConfigurationUsesExactExecutorAndKeepsCapturedValues() public {
        _newRotationSafe(9101);
        bytes32 transition = _stageRotation(bytes32(0));
        R.RotationRecord memory captured = ingress.rotationRecord(transition);
        bytes32 parameter = keccak256("ARTIST_ROTATION_CONTEST_SECONDS");
        bytes32 roots = _roots();
        T.Identity memory identityBefore =
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureWindow(ingress, parameter, 10 days, 1, 0, false);
        (uint64 value, uint64 floor, uint64 revision) = ingress.artistWindowInfo(parameter);
        require(
            value == 10 days && floor == 72 hours && revision == 2, "actual seconds configuration"
        );
        require(
            _roots() == roots
                && IStreamArtistIdentityOwner(suite.owners[2])
                    .identity(artistId)
                    .lastAuthorityActionAt == identityBefore.lastAuthorityActionAt,
            "separate config revision no artist liveness/history"
        );
        require(
            ingress.artistWindowScope(parameter)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_WINDOW_SCOPE_V1"),
                        block.chainid,
                        suite.owners[2],
                        parameter
                    )
                ),
            "scope is Identity host"
        );
        vm.expectRevert(abi.encodeWithSelector(R.InvalidArtistWindow.selector, parameter));
        authority.configureWindow(ingress, parameter, 11 days, 1, 0, false);
        vm.expectRevert(abi.encodeWithSelector(R.InvalidArtistWindowContext.selector));
        authority.configureWindow(ingress, parameter, 9 days, 2, 0, false);
        vm.expectRevert(abi.encodeWithSelector(R.InvalidArtistWindowContext.selector));
        authority.configureWindow(ingress, parameter, 11 days, 2, 1, true);
        authority.configureWindow(ingress, parameter, 9 days, 2, 1, false);
        vm.warp(captured.transition.contestEndsAt);
        ingress.executeArtistRotation(artistId, transition);
        R.RotationRecord memory executed = ingress.rotationRecord(transition);
        require(
            executed.timingRevision == 1 && executed.effectiveWindow == 7 days
                && executed.standingTail == 90 days
                && executed.transition.postWindowEndsAt == block.timestamp + 7 days,
            "captured parameters never changed"
        );
    }

    function testRotationWindowRejectsSafeOwnerFallbackNoopFloorAndOverflow() public {
        bytes32 parameter = keccak256("ARTIST_ROTATION_CONTEST_SECONDS");
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(this)));
        ingress.setArtistWindow(parameter, 8 days, 1);
        bytes memory data = abi.encodeCall(
            IStreamArtistWindows.setArtistWindow, (parameter, uint64(8 days), uint64(1))
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeArtistSafe(data);
        vm.expectRevert(abi.encodeWithSelector(R.InvalidArtistWindow.selector, parameter));
        authority.configureWindow(ingress, parameter, 7 days, 1, 1, false);
        vm.expectRevert(abi.encodeWithSelector(R.InvalidArtistWindow.selector, parameter));
        authority.configureWindow(ingress, parameter, 71 hours, 1, 1, false);
        vm.expectRevert(abi.encodeWithSelector(R.InvalidArtistWindow.selector, parameter));
        authority.configureWindow(ingress, parameter, type(uint64).max, 1, 1, false);
        (uint64 value,, uint64 revision) = ingress.artistWindowInfo(parameter);
        require(value == 7 days && revision == 1, "all config failures rollback");
    }

    function _rotationContestMaturityCase(uint256 boundary) private {
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

    function testIdentityContestBeforeExpiryPreventsAllCandidateMaturity() public {
        _rotationContestMaturityCase(0);
    }

    function testIdentityContestAtExpiryDoesNotRewindMatureFacts() public {
        _rotationContestMaturityCase(1);
    }

    function testIdentityContestAfterExpiryDoesNotRewindMatureFacts() public {
        _rotationContestMaturityCase(2);
    }

    function testRotationGuardianMaximumNonceAndProvisionalForkProtection() public {
        _payout();
        bytes32 priorGuardian = _guardianRecord(new address[](0), 0, 0, 100);
        _newRotationSafe(9301);
        bytes32 transition = _stageRotation(bytes32(0));
        _executeTimedRotation(transition);
        _adoptRotatedSafe();
        address[] memory members = new address[](1);
        members[0] = address(artist);
        bytes32 lowRecord = _guardianRecord(members, 1, 0, nextNonce);
        (,,, bytes32 actual) = ingress.guardianSet(artistId);
        require(
            actual == priorGuardian && ingress.guardianSetRecord(lowRecord).nonce < 100,
            "lower nonce never replaces stable guardian"
        );
        (address oldPayout, bytes32 priorDesignation) = ingress.artistPayoutAccount(artistId);
        T.PayoutDesignation memory payout =
            T.PayoutDesignation(artistId, address(artist), priorDesignation);
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.payoutDesignationDigest(payout, a));
        bytes32 record = ingress.recordPayoutDesignation(payout, a);
        payout.payoutAccount = address(0xCAFE);
        a = _authorization(true);
        a.signature = _signature(ingress.payoutDesignationDigest(payout, a));
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(R.ProvisionalChainOccupied.selector, record));
        ingress.recordPayoutDesignation(payout, a);
        require(_roots() == roots, "fork nonce and payout rollback");
        (address currentPayout,) = ingress.artistPayoutAccount(artistId);
        require(currentPayout == oldPayout, "previous payout remains operative");
        vm.warp(ingress.rotationRecord(transition).transition.postWindowEndsAt);
        (,,, actual) = ingress.guardianSet(artistId);
        require(actual == priorGuardian, "highest stable nonce wins after maturity");
    }

    function testRotationRetiredGrantorKeepsRevocationWithoutCurrentLiveness() public {
        _accept();
        _payout();
        _delegateSetup();
        bytes32 grant = _grant(_delegation(1, 4, 1000, uint64(1000 + 40 days), 0));
        OfficialSafe grantor = artist;
        uint256[] memory grantorKeys = keys;
        _newRotationSafe(9302);
        bytes32 transition = _stageRotation(bytes32(0));
        _executeTimedRotation(transition);
        _adoptRotatedSafe();
        T.Identity memory before_ = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        D.Revocation memory p = D.Revocation(
            artistId, address(delegateSafe), grant, keccak256("retired grantor revoke")
        );
        T.Authorization memory a =
            T.Authorization(before_.nonceHint, uint64(block.timestamp + 1 days), "");
        vm.warp(block.timestamp + 1);
        require(
            executeSafe(
                grantor,
                grantorKeys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistDelegation.revokeArtistDelegation, (p, a)),
                0
            ),
            "actual retired grantor Safe revoke"
        );
        T.Identity memory after_ = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        require(
            ingress.delegationRecord(grant).revoked && after_.authorityAddress == address(artist)
                && after_.lastAuthorityActionAt == before_.lastAuthorityActionAt,
            "only grant revocation authority retained"
        );
    }

    function testRotationPersistentNewSideReplayAcrossReturnToEarlierSafe() public {
        OfficialSafe first = artist;
        uint256[] memory firstKeys = keys;
        _newRotationSafe(9401);
        OfficialSafe second = rotationSafe;
        uint256[] memory secondKeys = rotationKeys;
        bytes32 firstTransition = _stageRotation(bytes32(0));
        _executeTimedRotation(firstTransition);
        _adoptRotatedSafe();
        vm.warp(ingress.rotationRecord(firstTransition).transition.postWindowEndsAt);
        rotationSafe = first;
        rotationKeys = firstKeys;
        bytes32 secondTransition = _stageRotation(firstTransition);
        _executeTimedRotation(secondTransition);
        _adoptRotatedSafe();
        vm.warp(ingress.rotationRecord(secondTransition).transition.postWindowEndsAt);
        rotationSafe = second;
        rotationKeys = secondKeys;
        (bool used, uint256 hint) =
            ingress.rotationAcceptanceNonceState(artistId, address(second), 0);
        require(used && hint == 1, "return to address keeps acceptance index");
        R.Rotation memory p = _rotationTerms(secondTransition);
        (T.Authorization memory oldA, T.Authorization memory newA) = _rotationAuthorizations(p);
        newA.nonce = 0;
        newA.signature = safeThresholdSignature(
            secondKeys,
            safeMessageDigest(second, abi.encode(ingress.rotationAcceptanceDigest(p, newA)))
        );
        bytes32 replayKey = _identityRevisionReplayKey(
            keccak256("identity_authority.replay.nonce_allocator"),
            keccak256(
                abi.encode(keccak256("rotation_acceptance"), artistId, address(second), uint256(0))
            )
        );
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(T.Replay.selector, replayKey));
        ingress.rotateArtistAddress(p, oldA, newA);
        require(
            _roots() == roots
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, oldA.nonce),
            "new-side replay rolls back old side"
        );
        newA.nonce = hint;
        newA.signature = safeThresholdSignature(
            secondKeys,
            safeMessageDigest(second, abi.encode(ingress.rotationAcceptanceDigest(p, newA)))
        );
        bytes32 third = ingress.rotateArtistAddress(p, oldA, newA);
        require(
            third != firstTransition && ingress.rotationRecord(third).newNonce == 1,
            "fresh lane nonce stages"
        );
    }

    function testRotationBothActualSafeThresholdsWrongDomainAndExpiredSideRollback() public {
        _newRotationSafe(9402);
        R.Rotation memory p = _rotationTerms(bytes32(0));
        (T.Authorization memory oldA, T.Authorization memory newA) = _rotationAuthorizations(p);
        bytes memory correct = newA.signature;
        uint256[] memory oneKey = new uint256[](1);
        oneKey[0] = rotationKeys[0];
        newA.signature = safeThresholdSignature(
            oneKey,
            safeMessageDigest(rotationSafe, abi.encode(ingress.rotationAcceptanceDigest(p, newA)))
        );
        bytes32 roots = _roots();
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.rotateArtistAddress(p, oldA, newA);
        require(_roots() == roots, "missing new Safe threshold");
        newA.signature = safeThresholdSignature(
            rotationKeys,
            safeMessageDigest(artist, abi.encode(ingress.rotationAcceptanceDigest(p, newA)))
        );
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.rotateArtistAddress(p, oldA, newA);
        require(_roots() == roots, "wrong actual Safe domain");
        newA.signature = correct;
        oldA.signature = safeThresholdSignature(
            oneKey, safeMessageDigest(artist, abi.encode(ingress.rotationDigest(p, oldA)))
        );
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.rotateArtistAddress(p, oldA, newA);
        oldA.signature = _signature(ingress.rotationDigest(p, oldA));
        vm.warp(uint256(newA.time) + 1);
        vm.expectRevert(abi.encodeWithSelector(T.ExpiredAuthorization.selector, oldA.time));
        ingress.rotateArtistAddress(p, oldA, newA);
        require(_roots() == roots, "expired before either replay lane");
        oldA.time = uint64(block.timestamp + 1 days);
        oldA.signature = _signature(ingress.rotationDigest(p, oldA));
        vm.expectRevert(abi.encodeWithSelector(T.ExpiredAuthorization.selector, newA.time));
        ingress.rotateArtistAddress(p, oldA, newA);
        require(_roots() == roots, "live old side cannot waive expired new-side acceptance");
    }

    function _contestData(bytes32 subject) private view returns (bytes memory) {
        return abi.encodeCall(
            IStreamArtistIdentityContest.contestArtistIdentity,
            (artistId, subject, keccak256("compromise evidence"), keccak256("compromise reason"))
        );
    }

    function _selfGuardian() private returns (bytes32 record) {
        address[] memory guardians = new address[](1);
        guardians[0] = address(artist);
        return _guardianRecord(guardians, 1, 0, nextNonce);
    }

    function testIdentityContestGuardianSafeExactRecordReplayEventAndSingleOwnerCommit() public {
        bytes32 guardian = _selfGuardian();
        T.Identity memory prior = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        T.Snapshot[7] memory before_;
        for (uint256 i; i < 7; ++i) {
            before_[i] = IStreamArtistOwner(suite.owners[i]).ownerStateSnapshotV2();
        }
        vm.warp(1077);
        vm.recordLogs();
        require(
            executeSafe(artist, keys, address(ingress), 0, _contestData(0), 0),
            "actual guardian Safe"
        );
        bytes32 record = ingress.latestIdentityContest(artistId);
        bytes32 expected = keccak256(
            abi.encode(
                bytes32(0x26a4221cd1625ab88b1ac279e1708a73efa176e486242b26832cdc94fe25e6bb),
                block.chainid,
                address(ingress),
                artistId,
                address(artist),
                bytes32(0),
                keccak256("compromise evidence"),
                keccak256("compromise reason"),
                uint64(1077)
            )
        );
        require(record == expected, "independent permanent preimage");
        Contest.Record memory saved = ingress.identityContestRecord(record);
        require(
            saved.recordHash == record && saved.guardianSetRecordHash == guardian
                && saved.priorStatus == 1 && saved.contestedAt == 1077,
            "actual record facts"
        );
        T.Identity memory after_ = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        require(
            after_.status == 4 && after_.nonceHint == prior.nonceHint
                && after_.lastAuthorityActionAt == prior.lastAuthorityActionAt,
            "no principal nonce or liveness"
        );
        after_.status = prior.status;
        require(
            keccak256(abi.encode(after_)) == keccak256(abi.encode(prior)), "only status changes"
        );
        for (uint256 i; i < 7; ++i) {
            T.Snapshot memory actual = IStreamArtistOwner(suite.owners[i]).ownerStateSnapshotV2();
            if (i == 2) {
                require(
                    actual.revision == before_[i].revision + 1
                        && actual.recordChainTip != before_[i].recordChainTip,
                    "one Identity record commit"
                );
            } else {
                require(
                    keccak256(abi.encode(actual)) == keccak256(abi.encode(before_[i])),
                    "other owner unchanged"
                );
            }
        }
        bytes32 subjectKey = _identityRevisionReplayKey(
            keccak256("identity_authority.replay.contest_record_hash_and_subject_key"),
            keccak256(
                abi.encode(
                    keccak256("subject"),
                    artistId,
                    bytes32(0),
                    keccak256("compromise evidence"),
                    keccak256("compromise reason")
                )
            )
        );
        T.ReplayCell memory cell = IStreamArtistOwner(suite.owners[2]).replayCell(subjectKey);
        require(cell.status == 2 && cell.commitment == record, "exact subject replay cell");
        (
            Contest.Request memory terms,
            Contest.GovernanceWitness memory witness,
            Contest.Record memory archived
        ) = abi.decode(
            _operationPayload(33, address(artist), record),
            (Contest.Request, Contest.GovernanceWitness, Contest.Record)
        );
        require(
            terms.artistId == artistId && witness.actionId == 0
                && keccak256(abi.encode(archived)) == keccak256(abi.encode(saved)),
            "actual archive payload"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 count;
        bytes32 topic = keccak256(
            "ArtistIdentityContested(uint16,bytes32,address,bytes32,bytes32,bytes32,uint64,bytes32)"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics[0] == topic) {
                require(
                    logs[i].emitter == suite.owners[2] && logs[i].topics[1] == artistId
                        && logs[i].topics[2] == bytes32(uint256(uint160(address(artist)))),
                    "exact owner emitter"
                );
                require(
                    keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                bytes32(0),
                                keccak256("compromise evidence"),
                                keccak256("compromise reason"),
                                uint64(1077),
                                record
                            )
                        ),
                    "exact event fields"
                );
                ++count;
            }
        }
        require(count == 1, "one normative event");
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(Contest.InvalidIdentityContest.selector, artistId));
        vm.prank(address(artist));
        ingress.contestArtistIdentity(
            artistId, 0, keccak256("compromise evidence"), keccak256("compromise reason")
        );
        require(_roots() == roots, "already contested has no successful no-op");
    }

    function testIdentityContestSafeOwnerStrangerAndCurrentPrincipalNeedActualStanding() public {
        bytes memory data = _contestData(0);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeArtistSafe(data);
        _selfGuardian();
        address ownerEOA = vm.addr(keys[0]);
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, ownerEOA));
        vm.prank(ownerEOA);
        ingress.contestArtistIdentity(
            artistId, 0, keccak256("compromise evidence"), keccak256("compromise reason")
        );
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(this)));
        ingress.contestArtistIdentity(
            artistId, 0, keccak256("compromise evidence"), keccak256("compromise reason")
        );
        require(
            executeSafe(artist, keys, address(ingress), 0, data, 0),
            "same call actual guardian succeeds"
        );
    }

    function _pendingContestGuardianCase(bool useCaptured) private {
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

    function testIdentityContestNewOperativeGuardianWhileRotationPending() public {
        _pendingContestGuardianCase(false);
    }

    function testIdentityContestCapturedGuardianStillHasDefensiveStanding() public {
        _pendingContestGuardianCase(true);
    }

    function testIdentityContestRetiredSafeStandingSurvivesTailUntilExplicitRevocation() public {
        _newRotationSafe(11002);
        bytes32 rotation = _stageRotation(0);
        _executeTimedRotation(rotation);
        R.RotationRecord memory r = ingress.rotationRecord(rotation);
        vm.warp(uint256(r.transition.postWindowEndsAt) + r.standingTail + 1);
        require(
            executeSafe(artist, keys, address(ingress), 0, _contestData(rotation), 0),
            "old Safe standing persists"
        );
        require(
            ingress.rotationRecord(rotation).transition.contestedAt == block.timestamp,
            "actual late contest time"
        );
    }

    function testIdentityContestRevokedPriorIndependentGuardianRemains() public {
        _selfGuardian();
        OfficialSafe old = artist;
        uint256[] memory oldKeys = keys;
        _newRotationSafe(11003);
        bytes32 rotation = _stageRotation(0);
        _executeTimedRotation(rotation);
        _adoptRotatedSafe();
        R.RotationRecord memory r = ingress.rotationRecord(rotation);
        vm.warp(uint256(r.transition.postWindowEndsAt) + r.standingTail);
        R.StandingRevocation memory p =
            R.StandingRevocation(artistId, address(old), keccak256("retire"), rotation);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.standingRevocationDigest(p, a));
        ingress.revokePriorAddressStanding(p, a);
        require(
            executeSafe(old, oldKeys, address(ingress), 0, _contestData(0), 0),
            "independent operative guardian remains"
        );
    }

    function testIdentityContestRevokedPriorSafeCannotFileWithoutOtherStanding() public {
        OfficialSafe old = artist;
        uint256[] memory oldKeys = keys;
        _newRotationSafe(11004);
        bytes32 rotation = _stageRotation(0);
        _executeTimedRotation(rotation);
        _adoptRotatedSafe();
        R.RotationRecord memory r = ingress.rotationRecord(rotation);
        vm.warp(uint256(r.transition.postWindowEndsAt) + r.standingTail);
        R.StandingRevocation memory p =
            R.StandingRevocation(artistId, address(old), keccak256("retire"), rotation);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.standingRevocationDigest(p, a));
        ingress.revokePriorAddressStanding(p, a);
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(old)));
        vm.prank(address(old));
        ingress.contestArtistIdentity(
            artistId, rotation, keccak256("compromise evidence"), keccak256("compromise reason")
        );
        artist = old;
        keys = oldKeys;
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeArtistSafe(_contestData(rotation));
        require(_roots() == roots, "revoked prior Safe rejection is atomic");
    }

    function testIdentityContestOlderSubjectCannotLeaveCurrentWindowUncontested() public {
        OfficialSafe old = artist;
        uint256[] memory oldKeys = keys;
        _newRotationSafe(11005);
        bytes32 first = _stageRotation(0);
        _executeTimedRotation(first);
        vm.warp(ingress.rotationRecord(first).transition.postWindowEndsAt);
        _adoptRotatedSafe();
        _newRotationSafe(11006);
        bytes32 second = _stageRotation(first);
        _executeTimedRotation(second);
        uint64 end = ingress.rotationRecord(second).transition.postWindowEndsAt;
        require(
            executeSafe(old, oldKeys, address(ingress), 0, _contestData(first), 0),
            "oldest Safe names historical subject"
        );
        require(
            ingress.rotationRecord(first).transition.contestedAt == block.timestamp
                && ingress.rotationRecord(second).transition.contestedAt == block.timestamp
                && block.timestamp < end,
            "current cohort receives actual contest too"
        );
        vm.warp(end);
        R.ProvisionalAssociation memory association = R.ProvisionalAssociation(second, end);
        require(
            !IStreamArtistRotationOwner(suite.owners[2])
                .provisionalRecordEligible(artistId, association),
            "current cohort remains ineligible"
        );
    }

    function testIdentityContestEmptyAndForeignSubjectsRollbackThenSameSafeCanFile() public {
        _selfGuardian();
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(Contest.InvalidContestSubject.selector, bytes32(uint256(3)))
        );
        vm.prank(address(artist));
        ingress.contestArtistIdentity(artistId, bytes32(uint256(3)), keccak256("e"), keccak256("r"));
        vm.expectRevert(abi.encodeWithSelector(Contest.InvalidIdentityContest.selector, artistId));
        vm.prank(address(artist));
        ingress.contestArtistIdentity(artistId, 0, 0, keccak256("r"));
        vm.expectRevert(abi.encodeWithSelector(Contest.InvalidIdentityContest.selector, artistId));
        vm.prank(address(artist));
        ingress.contestArtistIdentity(artistId, 0, keccak256("e"), 0);
        require(_roots() == roots, "bad requests leave roots");
        _newRotationSafe(11007);
        bytes32 rotation = _stageRotation(0);
        T.BindingProposal memory proposal = _proposal(0);
        proposal.artistAddress = address(rotationSafe);
        (bytes32 otherId,) = ingress.proposeArtistBinding(
            2, proposal, bytes("unit identity document"), "Other identity"
        );
        vm.expectRevert(abi.encodeWithSelector(Contest.InvalidContestSubject.selector, rotation));
        vm.prank(address(artist));
        ingress.contestArtistIdentity(otherId, rotation, keccak256("e"), keccak256("r"));
        require(
            executeSafe(artist, keys, address(ingress), 0, _contestData(0), 0), "positive control"
        );
    }

    function testIdentityContestLateArchiveFailureRollsBackRecordReplayAndSafeNonce() public {
        _selfGuardian();
        bytes32 roots = _roots();
        uint256 safeNonce = artist.nonce();
        avm.mockCallRevert(
            address(archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(T.InvalidRecord.selector)
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeArtistSafe(_contestData(0));
        require(
            _roots() == roots && artist.nonce() == safeNonce
                && ingress.latestIdentityContest(artistId) == 0,
            "late entire transaction rollback"
        );
        avm.clearMockedCalls();
        require(
            executeSafe(artist, keys, address(ingress), 0, _contestData(0), 0),
            "same calldata succeeds after restored archive"
        );
    }

    function testIdentityContestDefensiveFourFamiliesStayAvailableWithoutTimeout() public {
        _all();
        _delegateSetup();
        bytes32 grant = _grant(_delegation(1, 4, 1000, uint64(1000 + 500 days), 0));
        _selfGuardian();
        require(
            executeSafe(artist, keys, address(ingress), 0, _contestData(0), 0), "real compromise"
        );
        vm.warp(block.timestamp + 365 days);
        require(_closed(_mintCall()), "no automatic clearance");
        _authorizeFreeze();
        _contentFreeze();
        _revoke(grant);
        StreamArtistAuthorizationTypes.Revocation memory p =
            StreamArtistAuthorizationTypes.Revocation(
                artistId, keccak256("unused compromised authorization"), 0
            );
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.authorizationRevocationDigest(p, a));
        ingress.revokeArtistAuthorization(p, a);
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).status == 4,
            "defenses never clear status"
        );
    }

    function _governedContest(uint8 actionClass, uint8 fault) private {
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

    function testIdentityContestGovernanceExactContextAndRoleNegativesHavePositiveControl() public {
        bytes32 roots = _roots();
        for (uint8 fault = 1; fault <= 6; ++fault) {
            uint256 checkpoint = vm.snapshotState();
            if (fault == 6) {
                vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(artist)));
            } else {
                vm.expectRevert(abi.encodeWithSelector(Contest.InvalidContestGovernance.selector));
            }
            this.executeGovernedContest(1, fault);
            require(_roots() == roots, "governance fault rollback");
            _governedContest(1, 0);
            require(
                ingress.latestIdentityContest(artistId) != 0,
                "same context restored positive control"
            );
            require(vm.revertToState(checkpoint), "restore test-only checkpoint");
        }
        vm.expectRevert(abi.encodeWithSelector(Contest.InvalidContestGovernance.selector));
        this.executeGovernedContest(0, 0);
        vm.expectRevert(abi.encodeWithSelector(Contest.InvalidContestGovernance.selector));
        this.executeGovernedContest(3, 0);
        _governedContest(1, 0);
        bytes32 record = ingress.latestIdentityContest(artistId);
        (,, Contest.Record memory item) = abi.decode(
            _operationPayload(33, manager.governanceAuthority(), record),
            (Contest.Request, Contest.GovernanceWitness, Contest.Record)
        );
        require(
            item.contester == manager.governanceAuthority() && item.governanceWitnessHash != 0,
            "governed actor and witness"
        );
    }

    function executeGovernedContest(uint8 actionClass, uint8 fault) external {
        require(msg.sender == address(this), "test-only");
        _governedContest(actionClass, fault);
    }

    function testIdentityContestMalformedGovernanceHeaderIsBoundedAndRecoverable() public {
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        authority.configureContestReads(
            suite.roleRegistry, address(artist), keccak256("compromise reason"), "urn:test"
        );
        bytes memory valid = abi.encode(authority.governanceAction(bytes32(0)));
        bytes32 roots = _roots();
        for (uint256 mode; mode < 10; ++mode) {
            uint256 checkpoint = vm.snapshotState();
            bytes memory bad = bytes.concat(valid);
            if (mode == 0) bad = new bytes(639);
            if (mode == 1) assembly ("memory-safe") { mstore(add(bad, 32), 64) }
            if (mode == 2) assembly ("memory-safe") { mstore(add(bad, 576), 608) }
            if (mode == 3) assembly ("memory-safe") { mstore(add(bad, 640), not(0)) }
            if (mode == 4) assembly ("memory-safe") { mstore(add(bad, 416), not(0)) }
            if (mode == 5) assembly ("memory-safe") { mstore(add(bad, 64), 1) }
            if (mode == 6) assembly ("memory-safe") { mstore(add(bad, 96), 257) }
            if (mode == 7) assembly ("memory-safe") { mstore(add(bad, 192), 1) }
            if (mode == 8) bad = bytes.concat(bad, bytes32(0));
            if (mode == 9) assembly ("memory-safe") { mstore(add(bad, 352), not(0)) }
            avm.mockCall(
                address(authority),
                abi.encodeWithSelector(IStreamGovernanceReads.governanceAction.selector),
                bad
            );
            vm.expectRevert(abi.encodeWithSelector(Contest.InvalidContestGovernance.selector));
            this.executeGovernedContest(1, 0);
            require(_roots() == roots, "malformed header leaves owner state");
            avm.clearMockedCalls();
            _governedContest(1, 0);
            require(ingress.latestIdentityContest(artistId) != 0, "same request after restore");
            require(vm.revertToState(checkpoint), "restore malformed test checkpoint");
        }
    }

    function testIdentityContestProtocolCallbacksAndFixedExtensionRejectActualSafe() public {
        _selfGuardian();
        Contest.Request memory p = Contest.Request(artistId, 0, keccak256("e"), keccak256("r"));
        Contest.GovernanceWitness memory empty;
        T.ActionContext memory c = T.ActionContext(
            33, address(artist), IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2()
        );
        bytes memory ownerData =
            abi.encodeCall(IStreamArtistIdentityContestOwner.contestIdentity, (c, p, empty));
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(artist)));
        vm.prank(address(artist));
        IStreamArtistIdentityContestOwner(suite.owners[2]).contestIdentity(c, p, empty);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(suite.owners[2], ownerData);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(
            address(coordinator),
            abi.encodeCall(
                IStreamArtistIdentityContestCoordinator.coordinateContestArtistIdentity,
                (address(artist), p)
            )
        );
        address writer = ingress.registryWriterExtension();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(writer, _contestData(0));
        address reader = ingress.registryReadExtension();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(
            reader, abi.encodeCall(IStreamArtistIdentityContest.latestIdentityContest, (artistId))
        );
        require(
            executeSafe(artist, keys, address(ingress), 0, _contestData(0), 0),
            "normal guarded path"
        );
    }

    function testIdentityContestSafeCallsGovernedBoundaryAndReadCapability() public {
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        authority.configureContestReads(
            suite.roleRegistry,
            address(artist),
            keccak256("compromise reason"),
            string(new bytes(4097))
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = ingress.identityContestGovernanceContext(
            artistId, 0, keccak256("compromise evidence"), keccak256("compromise reason")
        );
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistIdentityContest.identityContestGovernanceContext,
                    (
                        artistId,
                        bytes32(0),
                        keccak256("compromise evidence"),
                        keccak256("compromise reason")
                    )
                ),
                0
            ),
            "real Safe context read"
        );
        require(
            executeSafe(
                artist,
                keys,
                address(authority),
                0,
                abi.encodeCall(
                    ArtistUnitGovernance.executeModuleContext,
                    (address(ingress), _contestData(0), uint8(2), scope, oldHash, newHash)
                ),
                0
            ),
            "actual Safe into qualified governance boundary"
        );
        bytes32 record = ingress.latestIdentityContest(artistId);
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistIdentityContest.identityContestRecord, (record)),
                0
            ),
            "real Safe record read"
        );
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistIdentityContest.latestIdentityContest, (artistId)),
                0
            ),
            "real Safe latest read"
        );
        require(
            ingress.supportsInterface(type(IStreamArtistIdentityContest).interfaceId),
            "narrow capability advertised"
        );
    }

    function _successorTerms(address account, uint8 kind)
        private
        view
        returns (Succ.Designation memory)
    {
        return Succ.Designation(
            artistId, account, kind, 4095, keccak256("estate conditions"), bytes32(0)
        );
    }

    function _successionRecord(Succ.Designation memory p) private returns (bytes32 record) {
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.successorDesignationDigest(p, a));
        return ingress.recordSuccessorDesignation(p, a);
    }

    function _directiveTerms(uint32 forbidden)
        private
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

    function _directiveRecord(uint32 forbidden) private returns (bytes32 record) {
        (Succ.Directive memory p, Succ.PublicDocument memory document) = _directiveTerms(forbidden);
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.estateDirectiveDigest(p, a));
        return ingress.recordEstateDirective(p, a, document);
    }

    function _successionTyped(bytes32 message) private view returns (bytes32) {
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

    function testSuccessionNonceZeroExactDigestRecordReplayAndEvent() public {
        _delegateSetup();
        Succ.Designation memory p = _successorTerms(address(delegateSafe), 2);
        p.grantedCapabilities = 0;
        T.Authorization memory a = _authorization(true);
        bytes32 digest = _successionTyped(
            keccak256(
                abi.encode(
                    keccak256(
                        "StreamArtistSuccessorDesignation(bytes32 artistId,address successor,uint8 successorKind,uint32 grantedCapabilities,bytes32 conditionsHash,bytes32 directiveHash,uint256 nonce,uint64 signedAt)"
                    ),
                    p.artistId,
                    p.successor,
                    p.successorKind,
                    p.grantedCapabilities,
                    p.conditionsHash,
                    p.directiveHash,
                    a.nonce,
                    a.time
                )
            )
        );
        require(
            digest == ingress.successorDesignationDigest(p, a) && a.nonce == 0,
            "independent nonce0 digest"
        );
        a.signature = _signature(digest);
        bytes32 others = _otherOwnerRoots();
        vm.recordLogs();
        bytes32 record = ingress.recordSuccessorDesignation(p, a);
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_SUCCESSION_RECORD_V1"),
                block.chainid,
                address(ingress),
                artistId,
                p.successor,
                p.successorKind,
                p.grantedCapabilities,
                p.conditionsHash,
                p.directiveHash,
                uint256(0),
                uint64(1000)
            )
        );
        require(
            record == expected && ingress.operativeSuccessorRecord(artistId) == record,
            "nonce0 is a real head"
        );
        (address account, uint8 kind, uint32 caps,,, uint256 nonce) =
            ingress.successorDesignation(artistId);
        require(
            account == address(delegateSafe) && kind == 2 && caps == 0 && nonce == 0,
            "canonical six-word read"
        );
        bytes32 key = _identityRevisionReplayKey(
            keccak256("identity_authority.replay.succession_chain"), keccak256(abi.encode(record))
        );
        T.ReplayCell memory cell = IStreamArtistOwner(suite.owners[2]).replayCell(key);
        require(
            cell.status == 2 && cell.commitment == record && _otherOwnerRoots() == others,
            "single owner and exact chain replay"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].topics[0]
                    == keccak256(
                        "ArtistSuccessorDesignated(uint16,bytes32,address,uint8,uint32,bytes32,bytes32,uint256,uint64,bytes32)"
                    )
            ) {
                ++count;
                require(
                    logs[i].emitter == suite.owners[2] && logs[i].topics[1] == artistId
                        && logs[i].topics[2] == bytes32(uint256(uint160(p.successor))),
                    "Identity emitter/indexes"
                );
                require(
                    keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                p.successorKind,
                                p.grantedCapabilities,
                                p.conditionsHash,
                                p.directiveHash,
                                a.nonce,
                                a.time,
                                record
                            )
                        ),
                    "exact designation event"
                );
            }
        }
        require(count == 1, "one designation event");
    }

    function testEstateDirectiveCanonicalPayloadDigestRecordAndEvent() public {
        Succ.PublicDocument memory document;
        bytes memory expectedBytes = bytes(
            '{"forbiddenCapabilities":4,"grantedCapabilities":0,"legalInstrumentHash":"0x0000000000000000000000000000000000000000000000000000000000000000","payoutRoutingIntentHash":"0x0000000000000000000000000000000000000000000000000000000000000000","schema":"6529STREAM_ESTATE_DIRECTIVE_V1"}'
        );
        require(
            keccak256(ingress.previewEstateDirectivePayload(0, 4, document))
                == keccak256(expectedBytes),
            "literal JCS bytes"
        );
        Succ.Directive memory p = Succ.Directive(artistId, 0, 4, keccak256(expectedBytes));
        T.Authorization memory a = _authorization(true);
        bytes32 digest = _successionTyped(
            keccak256(
                abi.encode(
                    keccak256(
                        "StreamArtistEstateDirective(bytes32 artistId,uint32 grantedCapabilities,uint32 forbiddenCapabilities,bytes32 directivePayloadHash,uint256 nonce,uint64 signedAt)"
                    ),
                    p.artistId,
                    p.grantedCapabilities,
                    p.forbiddenCapabilities,
                    p.directivePayloadHash,
                    a.nonce,
                    a.time
                )
            )
        );
        require(digest == ingress.estateDirectiveDigest(p, a), "independent directive digest");
        a.signature = _signature(digest);
        vm.recordLogs();
        bytes32 record = ingress.recordEstateDirective(p, a, document);
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_ESTATE_DIRECTIVE_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        artistId,
                        uint32(0),
                        uint32(4),
                        p.directivePayloadHash,
                        uint256(0),
                        uint64(1000)
                    )
                ),
            "exact directive record"
        );
        require(
            ingress.operativeEstateDirective(artistId) == record
                && keccak256(ingress.estateDirectivePayload(record)) == keccak256(expectedBytes),
            "nonce0 stored bytes/head"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].topics[0]
                    == keccak256(
                        "ArtistEstateDirectiveRecorded(uint16,bytes32,uint32,uint32,bytes32,uint256,uint64,bytes32)"
                    )
            ) {
                ++count;
                require(
                    logs[i].emitter == suite.owners[2] && logs[i].topics[1] == artistId
                        && keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(
                                    uint16(1),
                                    uint32(0),
                                    uint32(4),
                                    p.directivePayloadHash,
                                    a.nonce,
                                    a.time,
                                    record
                                )
                            ),
                    "exact directive event"
                );
            }
        }
        require(count == 1, "one directive event");
    }

    function testSuccessionBothActualSafeDirectWritersObserveDelayedTimeAndArchive() public {
        Succ.Designation memory p = _successorTerms(address(0xAABB), 1);
        T.Authorization memory submitted = T.Authorization(0, 0, "");
        bytes memory data = abi.encodeCall(
            IStreamArtistSuccessionRecords.recordSuccessorDesignation, (p, submitted)
        );
        vm.warp(1042);
        this.executeArtistSafe(data);
        bytes32 record = ingress.operativeSuccessorRecord(artistId);
        (
            Succ.Designation memory terms,
            T.Authorization memory original,
            T.Authorization memory effective,
            T.SignerApproval memory proof,
            Succ.DesignationRecord memory archived
        ) = abi.decode(
            _operationPayload(36, address(artist), record),
            (
                Succ.Designation,
                T.Authorization,
                T.Authorization,
                T.SignerApproval,
                Succ.DesignationRecord
            )
        );
        require(
            original.time == 0 && effective.time == 1042 && proof.direct
                && archived.signedAt == 1042 && terms.successor == p.successor,
            "designation observed/original"
        );
        (Succ.Directive memory d, Succ.PublicDocument memory doc) = _directiveTerms(4);
        submitted.nonce = 1;
        data = abi.encodeCall(
            IStreamArtistSuccessionRecords.recordEstateDirective, (d, submitted, doc)
        );
        vm.warp(1080);
        this.executeArtistSafe(data);
        record = ingress.operativeEstateDirective(artistId);
        require(ingress.estateDirectiveRecord(record).signedAt == 1080, "directive observed time");
        (, original, effective, proof,,,) = abi.decode(
            _operationPayload(37, address(artist), record),
            (
                Succ.Directive,
                T.Authorization,
                T.Authorization,
                T.SignerApproval,
                Succ.PublicDocument,
                Succ.DirectiveRecord,
                bytes
            )
        );
        require(
            original.time == 0 && effective.time == 1080 && proof.direct,
            "directive original/effective archive"
        );
    }

    function testSuccessionApprovedEmptySafeBothFamiliesAndUnapprovedEmptyRejection() public {
        Succ.Designation memory p = _successorTerms(address(0xAA), 1);
        T.Authorization memory a = _authorization(true);
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordSuccessorDesignation(p, a);
        _approveMessage(ingress.successorDesignationDigest(p, a));
        bytes32 first = ingress.recordSuccessorDesignation(p, a);
        (Succ.Directive memory d, Succ.PublicDocument memory doc) = _directiveTerms(0);
        a = _authorization(true);
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordEstateDirective(d, a, doc);
        _approveMessage(ingress.estateDirectiveDigest(d, a));
        bytes32 second = ingress.recordEstateDirective(d, a, doc);
        require(first != 0 && second != 0, "real Safe approved-empty records");
    }

    function testSuccessionWrongDomainMissingOwnerAndProtocolOnlyCallbacks() public {
        Succ.Designation memory p = _successorTerms(address(0xAA), 1);
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(keccak256("wrong domain"));
        bytes32 roots = _roots();
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordSuccessorDesignation(p, a);
        uint256[] memory one = new uint256[](1);
        one[0] = keys[0];
        a.signature = safeThresholdSignature(
            one, safeMessageDigest(artist, abi.encode(ingress.successorDesignationDigest(p, a)))
        );
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordSuccessorDesignation(p, a);
        a.signature = "";
        a.time = 0;
        avm.expectRevert(T.InvalidSignature.selector);
        vm.prank(safeVm.addr(keys[0]));
        ingress.recordSuccessorDesignation(p, a);
        T.ActionContext memory c = T.ActionContext(
            36, address(artist), IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2()
        );
        bytes memory callback = abi.encodeCall(
            IStreamArtistSuccessionOwner.recordSuccessorDesignation,
            (c, p, a, T.SignerApproval(address(artist), 0, true))
        );
        address identityWriter =
            StreamArtistIdentityAuthority(suite.owners[2]).identityWriterExtension();
        address registryWriter = ingress.registryWriterExtension();
        address registryReader = ingress.registryReadExtension();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(suite.owners[2], callback);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(identityWriter, callback);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(
            registryWriter,
            abi.encodeCall(IStreamArtistSuccessionRecords.recordSuccessorDesignation, (p, a))
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(
            registryReader,
            abi.encodeCall(IStreamArtistSuccessionReads.operativeSuccessorRecord, (artistId))
        );
        require(_roots() == roots, "all invalid authority paths atomic");
        this.executeArtistSafe(
            abi.encodeCall(IStreamArtistSuccessionRecords.recordSuccessorDesignation, (p, a))
        );
    }

    function testSuccessionActualSafeCoversEveryNewRead() public {
        bytes32 s = _successionRecord(_successorTerms(address(0xAB), 1));
        bytes32 d = _directiveRecord(0);
        this.executeArtistSafe(
            abi.encodeCall(IStreamArtistSuccessionReads.successorDesignation, (artistId))
        );
        this.executeArtistSafe(
            abi.encodeCall(IStreamArtistSuccessionReads.operativeSuccessorRecord, (artistId))
        );
        this.executeArtistSafe(
            abi.encodeCall(IStreamArtistSuccessionReads.operativeEstateDirective, (artistId))
        );
        this.executeArtistSafe(
            abi.encodeCall(IStreamArtistSuccessionReads.successorDesignationRecord, (s))
        );
        this.executeArtistSafe(
            abi.encodeCall(IStreamArtistSuccessionReads.estateDirectiveRecord, (d))
        );
        this.executeArtistSafe(
            abi.encodeCall(IStreamArtistSuccessionReads.estateDirectivePayload, (d))
        );
        Succ.Designation memory p = _successorTerms(address(0xAA), 1);
        T.Authorization memory a = T.Authorization(7, 1000, "");
        this.executeArtistSafe(
            abi.encodeCall(IStreamArtistSuccessionRecords.successorDesignationDigest, (p, a))
        );
        (Succ.Directive memory directive, Succ.PublicDocument memory doc) = _directiveTerms(0);
        this.executeArtistSafe(
            abi.encodeCall(IStreamArtistSuccessionRecords.estateDirectiveDigest, (directive, a))
        );
        this.executeArtistSafe(
            abi.encodeCall(
                IStreamArtistSuccessionRecords.previewEstateDirectivePayload,
                (uint32(4095), uint32(0), doc)
            )
        );
        require(
            ingress.supportsInterface(type(IStreamArtistSuccessionReads).interfaceId)
                && ingress.supportsInterface(type(IStreamArtistSuccessionRecords).interfaceId),
            "narrow capabilities"
        );
    }

    function testSuccessionRejectsUnknownKindsBitsAndClassifies7702Exclusively() public {
        Succ.Designation memory p = _successorTerms(address(0), 1);
        T.Authorization memory a = T.Authorization(0, 1000, "");
        a.signature = _signature(ingress.successorDesignationDigest(p, a));
        avm.expectRevert(Succ.InvalidSuccessor.selector);
        ingress.recordSuccessorDesignation(p, a);
        p.successor = address(artist);
        p.successorKind = 1;
        a.signature = _signature(ingress.successorDesignationDigest(p, a));
        avm.expectRevert(Succ.InvalidSuccessor.selector);
        ingress.recordSuccessorDesignation(p, a);
        p.successorKind = 3;
        a.signature = _signature(ingress.successorDesignationDigest(p, a));
        avm.expectRevert(Succ.InvalidSuccessor.selector);
        ingress.recordSuccessorDesignation(p, a);
        p.successorKind = 2;
        p.grantedCapabilities = 4096;
        a.signature = _signature(ingress.successorDesignationDigest(p, a));
        avm.expectRevert(Succ.InvalidSuccessor.selector);
        ingress.recordSuccessorDesignation(p, a);
        address delegated = address(0xD7702);
        vm.etch(delegated, abi.encodePacked(hex"ef0100", address(artist)));
        p = _successorTerms(delegated, 2);
        a.signature = _signature(ingress.successorDesignationDigest(p, a));
        avm.expectRevert(Succ.InvalidSuccessor.selector);
        ingress.recordSuccessorDesignation(p, a);
        p.successorKind = 1;
        a.signature = _signature(ingress.successorDesignationDigest(p, a));
        ingress.recordSuccessorDesignation(p, a);
    }

    function testEstateDirectiveRejectsPayloadDivergenceUnknownBitsAndForeignPairing() public {
        (Succ.Directive memory d, Succ.PublicDocument memory doc) = _directiveTerms(4);
        T.Authorization memory a = T.Authorization(0, 1000, "");
        d.directivePayloadHash = keccak256("wrong payload");
        a.signature = _signature(ingress.estateDirectiveDigest(d, a));
        avm.expectRevert(Succ.InvalidDirective.selector);
        ingress.recordEstateDirective(d, a, doc);
        d.forbiddenCapabilities = 4096;
        a.signature = _signature(ingress.estateDirectiveDigest(d, a));
        avm.expectRevert(Succ.InvalidDirective.selector);
        ingress.recordEstateDirective(d, a, doc);
        Succ.Designation memory p = _successorTerms(address(0xAA), 1);
        p.directiveHash = keccak256("missing directive");
        a.signature = _signature(ingress.successorDesignationDigest(p, a));
        avm.expectRevert(Succ.InvalidDirective.selector);
        ingress.recordSuccessorDesignation(p, a);
        (d, doc) = _directiveTerms(4);
        d.artistId = bytes32(uint256(123));
        a.signature = _signature(ingress.estateDirectiveDigest(d, a));
        vm.expectRevert(abi.encodeWithSelector(T.InvalidIdentity.selector, d.artistId));
        ingress.recordEstateDirective(d, a, doc);
        p.directiveHash = 0;
        a.signature = _signature(ingress.successorDesignationDigest(p, a));
        ingress.recordSuccessorDesignation(p, a);
    }

    function testSuccessionHigherNonceWinsBothFamiliesAndLowerHistoryRetained() public {
        Succ.Designation memory p = _successorTerms(address(0xAA), 1);
        T.Authorization memory a = T.Authorization(90, 1000, "");
        a.signature = _signature(ingress.successorDesignationDigest(p, a));
        bytes32 high = ingress.recordSuccessorDesignation(p, a);
        p.successor = address(0xBB);
        a.nonce = 0;
        a.signature = _signature(ingress.successorDesignationDigest(p, a));
        bytes32 low = ingress.recordSuccessorDesignation(p, a);
        require(
            ingress.operativeSuccessorRecord(artistId) == high
                && ingress.successorDesignationRecord(low).terms.successor == p.successor,
            "lower designation retained not operative"
        );
        (Succ.Directive memory d, Succ.PublicDocument memory doc) = _directiveTerms(4);
        a.nonce = 91;
        a.signature = _signature(ingress.estateDirectiveDigest(d, a));
        high = ingress.recordEstateDirective(d, a, doc);
        (d, doc) = _directiveTerms(0);
        a.nonce = 1;
        a.signature = _signature(ingress.estateDirectiveDigest(d, a));
        low = ingress.recordEstateDirective(d, a, doc);
        require(
            ingress.operativeEstateDirective(artistId) == high
                && ingress.estateDirectiveRecord(low).recordHash == low,
            "lower directive retained not operative"
        );
    }

    function testSuccessionLateArchiveRollbackAllowsExactSafeRetry() public {
        Succ.Designation memory p = _successorTerms(address(0xAA), 1);
        T.Authorization memory a = T.Authorization(0, 0, "");
        bytes memory data =
            abi.encodeCall(IStreamArtistSuccessionRecords.recordSuccessorDesignation, (p, a));
        bytes32 roots = _roots();
        uint256 nonce = artist.nonce();
        avm.mockCallRevert(
            address(archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(T.InvalidRecord.selector)
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeArtistSafe(data);
        require(
            _roots() == roots && artist.nonce() == nonce
                && ingress.operativeSuccessorRecord(artistId) == 0,
            "all designation effects rollback"
        );
        avm.clearMockedCalls();
        this.executeArtistSafe(data);
        (Succ.Directive memory d, Succ.PublicDocument memory doc) = _directiveTerms(4);
        a.nonce = 1;
        data = abi.encodeCall(IStreamArtistSuccessionRecords.recordEstateDirective, (d, a, doc));
        roots = _roots();
        nonce = artist.nonce();
        avm.mockCallRevert(
            address(archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(T.InvalidRecord.selector)
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeArtistSafe(data);
        require(
            _roots() == roots && artist.nonce() == nonce
                && ingress.operativeEstateDirective(artistId) == 0,
            "all directive effects rollback"
        );
        avm.clearMockedCalls();
        this.executeArtistSafe(data);
    }

    function testSuccessionOperativeSafeDesigneeVetoesWithoutAuthorship() public {
        _delegateSetup();
        _successionRecord(_successorTerms(address(delegateSafe), 2));
        _newRotationSafe(16001);
        bytes32 rotation = _stageRotation(0);
        bytes memory data = abi.encodeCall(
            IStreamArtistRotation.vetoArtistRotation,
            (artistId, rotation, keccak256("successor veto"))
        );
        uint256 nonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        vm.expectRevert(
            abi.encodeWithSelector(T.Unauthorized.selector, safeVm.addr(delegateKeys[0]))
        );
        vm.prank(safeVm.addr(delegateKeys[0]));
        ingress.vetoArtistRotation(artistId, rotation, keccak256("successor veto"));
        this.executeDelegate(address(ingress), data);
        require(
            ingress.rotationRecord(rotation).transition.phase == 3
                && IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).status == 4
                && IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint
                    == nonce,
            "successor veto only defensive state"
        );
    }

    function testSuccessionOperativeSafeDesigneeContestsAndBindsActualRecord() public {
        _delegateSetup();
        bytes32 successor = _successionRecord(_successorTerms(address(delegateSafe), 2));
        this.executeDelegate(address(ingress), _contestData(0));
        bytes32 record = ingress.latestIdentityContest(artistId);
        (,,, bytes32 archivedSuccessor) = abi.decode(
            _operationPayload(33, address(delegateSafe), record),
            (Contest.Request, Contest.GovernanceWitness, Contest.Record, bytes32)
        );
        require(
            archivedSuccessor == successor
                && ingress.identityContestRecord(record).contester == address(delegateSafe),
            "actual permanent standing witness"
        );
        (Succ.Directive memory d, Succ.PublicDocument memory doc) = _directiveTerms(0);
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.estateDirectiveDigest(d, a));
        vm.expectRevert(abi.encodeWithSelector(T.InvalidIdentity.selector, artistId));
        ingress.recordEstateDirective(d, a, doc);
    }

    function testSuccessionReplacementRemovesOldDesigneeStandingAndStalesGovernanceContext()
        public
    {
        _delegateSetup();
        _successionRecord(_successorTerms(address(delegateSafe), 2));
        (bytes32 scope, bytes32 beforeOld,) = ingress.identityContestGovernanceContext(
            artistId, 0, keccak256("compromise evidence"), keccak256("compromise reason")
        );
        _successionRecord(_successorTerms(address(artist), 2));
        (bytes32 newScope, bytes32 afterOld,) = ingress.identityContestGovernanceContext(
            artistId, 0, keccak256("compromise evidence"), keccak256("compromise reason")
        );
        require(
            scope == newScope && beforeOld != afterOld, "operative successor bound in old-state"
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeDelegate(address(ingress), _contestData(0));
        this.executeArtistSafe(_contestData(0));
    }

    function _successionMaturityCase(uint8 boundary) private {
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

    function testSuccessionContestBeforeExpiryInvalidatesBothCandidates() public {
        _successionMaturityCase(0);
    }

    function testSuccessionContestAtExpiryDoesNotRewindBothMatureHeads() public {
        _successionMaturityCase(1);
    }

    function testSuccessionContestAfterExpiryDoesNotRewindBothMatureHeads() public {
        _successionMaturityCase(2);
    }

    function testSuccessionProvisionalHeadsMatureWithoutMaintenanceAndCannotEvictHigherNonce()
        public
    {
        Succ.Designation memory p = _successorTerms(address(0xAA), 1);
        T.Authorization memory a = T.Authorization(90, 1000, "");
        a.signature = _signature(ingress.successorDesignationDigest(p, a));
        bytes32 high = ingress.recordSuccessorDesignation(p, a);
        _delegateSetup();
        _newRotationSafe(16030);
        bytes32 rotation = _stageRotation(0);
        _executeTimedRotation(rotation);
        _adoptRotatedSafe();
        bytes32 low = _successionRecord(_successorTerms(address(delegateSafe), 2));
        bytes32 d = _directiveRecord(4);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeDelegate(address(ingress), _contestData(rotation));
        vm.warp(ingress.rotationRecord(rotation).transition.postWindowEndsAt);
        require(
            ingress.operativeSuccessorRecord(artistId) == high
                && ingress.successorDesignationRecord(low).recordHash == low
                && ingress.operativeEstateDirective(artistId) == d,
            "highest eligible nonce and time-only directive maturity"
        );
    }

    function testEstateDirectiveImmediatelyBlocksDelegatedGrantAndBothUsesThenLatestRestores()
        public
    {
        _accept();
        _payout();
        _delegateSetup();
        bytes32 oldDirective = _directiveRecord(0);
        bytes32 grant = _grant(_delegation(1, 36, 1000, 2000, 0));
        bytes32 blocked = _directiveRecord(36);
        Succ.Designation memory successor = _successorTerms(address(delegateSafe), 2);
        successor.directiveHash = oldDirective;
        _successionRecord(successor);
        bytes32 roots = _roots();
        T.EconomicsConsent memory p = _currentEconomics(address(primary));
        T.Authorization memory a = T.Authorization(0, 2000, "");
        a.signature = _delegateSignature(ingress.economicsConsentDigest(p, a));
        vm.expectRevert(
            abi.encodeWithSelector(Succ.ForbiddenCapability.selector, artistId, uint32(4), blocked)
        );
        ingress.recordDelegatedEconomicsConsent(p, grant, a);
        (, T.AssignmentFact memory royaltyFact) = coordinator.reads().currentAssignments(1);
        T.RoyaltyFreeze memory f = T.RoyaltyFreeze(
            royaltyFact.resolver, 1, royaltyFact.revenueClass, royaltyFact.assignmentHash
        );
        a.signature = _delegateSignature(ingress.royaltyFreezeDigest(f, a));
        vm.expectRevert(
            abi.encodeWithSelector(Succ.ForbiddenCapability.selector, artistId, uint32(32), blocked)
        );
        ingress.authorizeDelegatedRoyaltyFreeze(f, grant, a);
        D.Grant memory another = _delegation(0, 4, 1000, 2000, 0);
        another.delegate = address(0xDD);
        T.Authorization memory principal = _authorization(false);
        principal.time = 0;
        principal.signature = _signature(ingress.delegationGrantDigest(another, principal));
        vm.expectRevert(
            abi.encodeWithSelector(Succ.ForbiddenCapability.selector, artistId, uint32(4), blocked)
        );
        ingress.grantArtistDelegation(another, principal);
        require(
            _roots() == roots && ingress.delegationRecord(grant).uses == 0,
            "forbidden checks before consumption"
        );
        bytes32 permit = _directiveRecord(0);
        require(permit != blocked, "newer directive");
        _delegateEconomics(p, grant, 0);
        a.nonce = 1;
        a.signature = _delegateSignature(ingress.royaltyFreezeDigest(f, a));
        ingress.authorizeDelegatedRoyaltyFreeze(f, grant, a);
        ingress.grantArtistDelegation(another, principal);
        require(
            ingress.delegationRecord(grant).uses == 2,
            "no historical forbidden union and old pairing cannot bypass newer prohibition"
        );
    }

    function testEstateDirectiveProvisionalRestrictionAppliesOnlyAfterUncontestedMaturity() public {
        _accept();
        _payout();
        _delegateSetup();
        bytes32 grant = _grant(_delegation(1, 4, 1000, uint64(1000 + 365 days), 0));
        _newRotationSafe(16040);
        bytes32 rotation = _stageRotation(0);
        _executeTimedRotation(rotation);
        _adoptRotatedSafe();
        bytes32 directive = _directiveRecord(4);
        _delegateEconomics(_currentEconomics(address(primary)), grant, 0);
        vm.warp(ingress.rotationRecord(rotation).transition.postWindowEndsAt);
        T.EconomicsConsent memory p = _currentEconomics(address(royalty));
        T.Authorization memory a = T.Authorization(1, uint64(block.timestamp + 1 days), "");
        a.signature = _delegateSignature(ingress.economicsConsentDigest(p, a));
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(
                Succ.ForbiddenCapability.selector, artistId, uint32(4), directive
            )
        );
        ingress.recordDelegatedEconomicsConsent(p, grant, a);
        require(
            _roots() == roots && ingress.delegationRecord(grant).uses == 1,
            "mature mask gates future use without touching old record"
        );
        _directiveRecord(0);
        ingress.recordDelegatedEconomicsConsent(p, grant, a);
        require(
            ingress.delegationRecord(grant).uses == 2,
            "same unused action succeeds under lawful new directive"
        );
    }

    function testSuccessionRevokedPayloadAndFutureSignedAtRejectWithoutConsumingRecord() public {
        Succ.Designation memory p = _successorTerms(address(0xAA), 1);
        T.Authorization memory a = T.Authorization(50, 1000, "");
        bytes32 digest = ingress.successorDesignationDigest(p, a);
        a.signature = _signature(digest);
        StreamArtistAuthorizationTypes.Revocation memory target =
            StreamArtistAuthorizationTypes.Revocation(artistId, digest, 0);
        T.Authorization memory cancel = _authorization(false);
        cancel.signature = _signature(ingress.authorizationRevocationDigest(target, cancel));
        ingress.revokeArtistAuthorization(target, cancel);
        bytes32 key = _identityRevisionReplayKey(
            keccak256("identity_authority.replay.digest_revocation"),
            keccak256(abi.encode(artistId, digest))
        );
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(T.Replay.selector, key));
        ingress.recordSuccessorDesignation(p, a);
        a.nonce = 51;
        a.time = 1001;
        a.signature = _signature(ingress.successorDesignationDigest(p, a));
        vm.expectRevert(abi.encodeWithSelector(T.InvalidTimestamp.selector, uint64(1001)));
        ingress.recordSuccessorDesignation(p, a);
        require(
            _roots() == roots && ingress.operativeSuccessorRecord(artistId) == 0,
            "revocation and future time atomic"
        );
        a.time = 1000;
        a.signature = _signature(ingress.successorDesignationDigest(p, a));
        ingress.recordSuccessorDesignation(p, a);
    }

    function testEstateDirectiveFutureTimeAndStaleDirectTimestampRejectThenSentinelWorks() public {
        (Succ.Directive memory p, Succ.PublicDocument memory doc) = _directiveTerms(0);
        T.Authorization memory a = T.Authorization(0, 1001, "");
        a.signature = _signature(ingress.estateDirectiveDigest(p, a));
        vm.expectRevert(abi.encodeWithSelector(T.InvalidTimestamp.selector, uint64(1001)));
        ingress.recordEstateDirective(p, a, doc);
        a.signature = "";
        a.time = 1000;
        bytes memory queued =
            abi.encodeCall(IStreamArtistSuccessionRecords.recordEstateDirective, (p, a, doc));
        vm.warp(1050);
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeArtistSafe(queued);
        require(_roots() == roots, "stale queued explicit time rejected");
        a.time = 0;
        this.executeArtistSafe(
            abi.encodeCall(IStreamArtistSuccessionRecords.recordEstateDirective, (p, a, doc))
        );
        require(
            ingress.estateDirectiveRecord(ingress.operativeEstateDirective(artistId)).signedAt
                == 1050,
            "sentinel inclusion time"
        );
    }

    function testSuccessionNewOperativeGuardianCanVetoPendingRotation() public {
        _selfGuardian();
        _newRotationSafe(16050);
        bytes32 rotation = _stageRotation(0);
        _delegateSetup();
        address[] memory guardians = new address[](1);
        guardians[0] = address(delegateSafe);
        _guardianRecord(guardians, 1, 0, nextNonce++);
        this.executeDelegate(
            address(ingress),
            abi.encodeCall(
                IStreamArtistRotation.vetoArtistRotation,
                (artistId, rotation, keccak256("new operative guardian"))
            )
        );
        require(
            ingress.rotationRecord(rotation).transition.phase == 3,
            "new operative guardian retains veto standing"
        );
    }

    function testEstateDirectiveActualForeignRecordCannotBePairedAndEOADirectTimeIsObserved()
        public
    {
        address other = vm.addr(0xA247);
        T.BindingProposal memory proposal = _proposal(0);
        proposal.artistAddress = other;
        proposal.identityRecordHash = keccak256("other estate identity");
        (bytes32 otherId,) = ingress.proposeArtistBinding(
            2, proposal, bytes("other estate identity"), "Other estate artist"
        );
        (Succ.Directive memory d, Succ.PublicDocument memory doc) = _directiveTerms(0);
        d.artistId = otherId;
        T.Authorization memory a = T.Authorization(0, 0, "");
        vm.warp(1060);
        vm.prank(other);
        bytes32 foreign = ingress.recordEstateDirective(d, a, doc);
        require(
            ingress.estateDirectiveRecord(foreign).signedAt == 1060, "actual EOA inclusion time"
        );
        Succ.Designation memory p = _successorTerms(address(0xAA), 1);
        p.directiveHash = foreign;
        a = _authorization(true);
        a.signature = _signature(ingress.successorDesignationDigest(p, a));
        avm.expectRevert(Succ.InvalidDirective.selector);
        ingress.recordSuccessorDesignation(p, a);
        p.directiveHash = 0;
        a.signature = _signature(ingress.successorDesignationDigest(p, a));
        ingress.recordSuccessorDesignation(p, a);
    }

    function testSuccessionActualSafeRejectsDirectiveCallbacksAndLinkedConstructorDirectCall()
        public
    {
        (Succ.Directive memory p, Succ.PublicDocument memory doc) = _directiveTerms(0);
        T.Authorization memory a = T.Authorization(0, 0, "");
        T.ActionContext memory c = T.ActionContext(
            37, address(artist), IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2()
        );
        T.SignerApproval memory proof = T.SignerApproval(address(artist), 0, true);
        bytes memory callback = abi.encodeCall(
            IStreamArtistSuccessionOwner.recordEstateDirective, (c, p, a, proof, doc)
        );
        address writer = StreamArtistIdentityAuthority(suite.owners[2]).identityWriterExtension();
        bytes32 roots = _roots();
        uint256 safeNonce = artist.nonce();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(suite.owners[2], callback);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(writer, callback);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(
            address(coordinator),
            abi.encodeCall(
                IStreamArtistSuccessionCoordinator.coordinateRecordEstateDirective,
                (address(artist), p, a, doc)
            )
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(
            address(coordinator),
            abi.encodeCall(
                IStreamArtistSuccessionCoordinator.coordinateRecordSuccessorDesignation,
                (address(artist), _successorTerms(address(0xAA), 1), a)
            )
        );
        bytes memory deploymentCall =
            abi.encodeWithSignature("deployReader(address)", address(coordinator));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(address(StreamArtistRegistryExtensionDeployment), deploymentCall);
        require(
            _roots() == roots && artist.nonce() == safeNonce,
            "actual Safe callback failures have no effects"
        );
        this.executeArtistSafe(
            abi.encodeCall(IStreamArtistSuccessionRecords.recordEstateDirective, (p, a, doc))
        );
    }

    function testEstateDirectiveRejectsOverlappingMasksThenSameNonceDisjointPositive() public {
        Succ.PublicDocument memory document;
        bytes memory overlapping = bytes(
            '{"forbiddenCapabilities":4,"grantedCapabilities":4,"legalInstrumentHash":"0x0000000000000000000000000000000000000000000000000000000000000000","payoutRoutingIntentHash":"0x0000000000000000000000000000000000000000000000000000000000000000","schema":"6529STREAM_ESTATE_DIRECTIVE_V1"}'
        );
        Succ.Directive memory p = Succ.Directive(artistId, 4, 4, keccak256(overlapping));
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.estateDirectiveDigest(p, a));
        bytes32 roots = _roots();
        avm.expectRevert(Succ.InvalidDirective.selector);
        ingress.previewEstateDirectivePayload(4, 4, document);
        avm.expectRevert(Succ.InvalidDirective.selector);
        ingress.recordEstateDirective(p, a, document);
        require(
            _roots() == roots && ingress.operativeEstateDirective(artistId) == 0,
            "overlap rejects before nonce/record"
        );
        p.grantedCapabilities = 0;
        p.directivePayloadHash = keccak256(ingress.previewEstateDirectivePayload(0, 4, document));
        a.signature = _signature(ingress.estateDirectiveDigest(p, a));
        bytes32 record = ingress.recordEstateDirective(p, a, document);
        require(
            ingress.operativeEstateDirective(artistId) == record
                && ingress.estateDirectiveRecord(record).nonce == 0,
            "same-context disjoint nonce0 positive"
        );
    }

    event SuccessionReaderDeploymentProof(
        address indexed helper,
        bytes helperRuntime,
        address indexed registry,
        address indexed reader
    );

    function testSuccessionLinkedReaderDeploymentRetainsCreatorAndMeasuredHelperRuntime() public {
        address helper = address(StreamArtistRegistryExtensionDeployment);
        address reader = ingress.registryReadExtension();
        require(
            helper.code.length != 0 && helper.code.length <= 24576,
            "actual compiler-linked constructor helper fits"
        );
        require(
            reader == avm.computeCreateAddress(address(ingress), 2)
                && ingress.registryWriterExtension()
                    == avm.computeCreateAddress(address(ingress), 1),
            "same creator and child nonces"
        );
        require(
            address(ingress).code.length <= 24576 && suite.owners[2].code.length <= 24576,
            "actual host runtime limits"
        );
        emit SuccessionReaderDeploymentProof(helper, helper.code, address(ingress), reader);
        this.executeArtistSafe(
            abi.encodeCall(IStreamArtistSuccessionReads.operativeSuccessorRecord, (artistId))
        );
    }

    /// @dev First connected estate flow: actual artist/Safe/archival products; Core and governance are unit boundaries.
    function testEstateActivationActualCoverageAndSafePrincipalsZeroCapabilities() public {
        _accept();
        _policy();
        _payout();
        _economics();
        _ratify();
        _attestations();
        ingress.requireMintConsent(1, PHASE, POLICY);
        _delegateSetup();
        Succ.Designation memory designation = _successorTerms(address(delegateSafe), 2);
        designation.grantedCapabilities = 0;
        T.Authorization memory designationAuth = T.Authorization(nextNonce++, 0, "");
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistSuccessionRecords.recordSuccessorDesignation,
                    (designation, designationAuth)
                ),
                0
            ),
            "living Safe designation"
        );
        bytes32 designationHash =
            StreamArtistIdentityAuthority(suite.owners[2]).operativeSuccessorRecord(artistId);
        (bytes32 evidence, bytes32 coverage) = _estateArchiveEvidence(artistId);
        Estate.Request memory request =
            Estate.Request(artistId, address(delegateSafe), evidence, designationHash, coverage);
        T.Authorization memory auth = T.Authorization(0, uint64(block.timestamp + 1 days), "");
        bytes32 independentlyTyped = _successionTyped(
            keccak256(
                abi.encode(
                    keccak256(
                        "StreamArtistEstateActivation(bytes32 artistId,address successor,bytes32 evidenceHash,uint256 nonce,uint64 deadline)"
                    ),
                    artistId,
                    address(delegateSafe),
                    evidence,
                    uint256(0),
                    auth.time
                )
            )
        );
        require(
            ingress.estateActivationDigest(request, auth) == independentlyTyped,
            "exact permanent five-field signed digest"
        );
        uint64 observed = uint64(block.timestamp);
        require(
            executeSafe(
                delegateSafe,
                delegateKeys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistEstateActivation.requestEstateActivation, (request, auth)
                ),
                0
            ),
            "successor Safe request"
        );
        (address pending, uint64 ends, bytes32 record) = ingress.estateActivationState(artistId);
        require(pending == address(delegateSafe) && ends == observed + 180 days, "captured notice");
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ESTATE_ACTIVATION_RECORD_V1"),
                block.chainid,
                address(ingress),
                artistId,
                address(delegateSafe),
                evidence,
                uint256(0),
                observed,
                ends
            )
        );
        require(record == expected, "exact permanent request record");
        require(
            ingress.estateActivationNonceHint(artistId, address(delegateSafe)) == 1,
            "persistent successor replay lane"
        );
        vm.warp(ends);
        Estate.Execution memory execution = Estate.Execution(artistId, record, coverage);
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistEstateActivation.executeEstateActivation, (execution)),
                0
            ),
            "permissionless Safe execution at notice equality"
        );
        Estate.AuthorityCapabilities memory rights = ingress.currentAuthorityCapabilities(artistId);
        require(
            rights.authorityAddress == address(delegateSafe) && rights.authorityClass == 3
                && rights.status == 3 && rights.effectiveCapabilities == 0
                && rights.activationRecordHash == record,
            "truthful zero-cap successor authority"
        );
        require(
            ingress.acceptedArtist(1) == address(delegateSafe),
            "immutable binding resolves current successor"
        );
        require(
            StreamArtistIdentityAuthority(suite.owners[2]).activeIdentity(address(artist)) == 0
                && StreamArtistIdentityAuthority(suite.owners[2])
                        .activeIdentity(address(delegateSafe)) == artistId,
            "one operative identity address"
        );
        (Estate.RequestRecord memory saved, uint8 phase, Estate.ExecutionFacts memory result) =
            ingress.estateActivationRecord(record);
        require(
            saved.recordHash == record && phase == 2 && result.activationRecordHash == record
                && result.coverageRecordHash == coverage && result.effectiveCapabilities == 0
                && result.executedAt == ends && result.governanceActionId == 0
                && result.delegationEpoch == 1,
            "actual executed archival evidence"
        );
        ingress.requireMintConsent(1, PHASE, POLICY);
        T.PolicyConsent memory later = T.PolicyConsent(1, keccak256("fresh estate policy"), POLICY);
        T.Identity memory current =
            StreamArtistIdentityAuthority(suite.owners[2]).identity(artistId);
        T.Authorization memory denied =
            T.Authorization(current.nonceHint, uint64(block.timestamp + 1 days), "");
        vm.prank(address(delegateSafe));
        vm.expectRevert(
            abi.encodeWithSelector(Estate.EstateCapabilityUnavailable.selector, artistId, uint32(2))
        );
        ingress.recordPolicyConsent(later, denied);
        require(
            ingress.currentAuthorityCapabilities(artistId).effectiveCapabilities == 0,
            "failed new policy cannot manufacture rights"
        );
    }

    function _estatePendingFixture(uint32 capabilities)
        private
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
    ) private view {
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

    function _estateLivingRevisionAt(uint256 boundary) private {
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

    function testEstateLivingRevisionCancelsInSameBlockAndStaysOperative() public {
        _estateLivingRevisionAt(0);
    }

    function testEstateLivingRevisionCancelsAtNoticeEquality() public {
        _estateLivingRevisionAt(1);
    }

    function testEstateLivingRevisionCancelsAfterNoticeBeforeExecution() public {
        _estateLivingRevisionAt(2);
    }

    function testEstateDirectSafeCancellationAfterNoticePinsReplayAndEvent() public {
        Estate.Execution memory p = _estatePendingFixture(0);
        (, uint64 end,) = ingress.estateActivationState(artistId);
        vm.warp(uint256(end) + 1);
        vm.recordLogs();
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistEstateActivation.cancelEstateActivation,
                    (artistId, p.expectedActivationRecordHash)
                ),
                0
            ),
            "direct current Safe cancel"
        );
        _assertEstateCancellationEvent(vm.getRecordedLogs(), p.expectedActivationRecordHash, 1);
        (, uint8 phase,) = ingress.estateActivationRecord(p.expectedActivationRecordHash);
        require(
            phase == 3 && ingress.currentAuthorityCapabilities(artistId).authorityClass == 1,
            "cancel preserves living authority"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                Estate.InvalidEstateActivation.selector, p.expectedActivationRecordHash
            )
        );
        ingress.executeEstateActivation(p);
    }

    function _estatePendingContest(bool named) private {
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

    function testEstateNamedPendingRequestGuardianContestTerminatesWithoutSyntheticCancel() public {
        _estatePendingContest(true);
    }

    function testEstateGeneralGuardianContestTerminatesPendingWithoutSyntheticCancel() public {
        _estatePendingContest(false);
    }

    function testEstateLivingCancellationAndRevisionRollbackOnLateArchiveThenExactSafeRetry()
        public
    {
        Estate.Execution memory p = _estatePendingFixture(4095);
        bytes memory document = bytes("atomic living revision and pending cancellation");
        bytes32 previous = ingress.operativeIdentityRecord(artistId);
        StreamArtistIdentityRevisionTypes.Revision memory revision =
            StreamArtistIdentityRevisionTypes.Revision(
                artistId, previous, keccak256(document), "urn:estate-cancellation-rollback"
            );
        T.Authorization memory a = T.Authorization(nextNonce, uint64(block.timestamp), "");
        bytes memory call_ = abi.encodeCall(
            IStreamArtistIdentityRevision.recordIdentityRevision,
            (revision, a, document, "Living retry")
        );
        bytes32 roots = _roots();
        uint256 safeNonce = artist.nonce();
        avm.mockCallRevert(
            address(archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(T.InvalidRecord.selector)
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeArtistSafe(call_);
        (,, bytes32 pending) = ingress.estateActivationState(artistId);
        require(
            _roots() == roots && artist.nonce() == safeNonce
                && pending == p.expectedActivationRecordHash
                && ingress.operativeIdentityRecord(artistId) == previous,
            "late archive reverts revision, same-block living marker, cancellation and Safe nonce"
        );
        avm.clearMockedCalls();
        this.executeArtistSafe(call_);
        (,, pending) = ingress.estateActivationState(artistId);
        require(
            pending == 0 && ingress.operativeIdentityRecord(artistId) == keccak256(document),
            "same calldata and nonce succeeds after archive restoration"
        );
    }

    function testEstateExecutionLateArchiveRollsAuthorityEpochAndWindowBackThenExactRetry() public {
        Estate.Execution memory p = _estatePendingFixture(1024);
        (, uint64 end,) = ingress.estateActivationState(artistId);
        vm.warp(end);
        bytes32 roots = _roots();
        uint256 safeNonce = artist.nonce();
        bytes memory call_ =
            abi.encodeCall(IStreamArtistEstateActivation.executeEstateActivation, (p));
        avm.mockCallRevert(
            address(archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(T.InvalidRecord.selector)
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeArtistSafe(call_);
        (, uint8 phase, Estate.ExecutionFacts memory execution) =
            ingress.estateActivationRecord(p.expectedActivationRecordHash);
        require(
            _roots() == roots && artist.nonce() == safeNonce && phase == 1
                && execution.activationRecordHash == 0
                && ingress.currentAuthorityCapabilities(artistId).authorityClass == 1,
            "late archive reverts authority/epoch/execution window"
        );
        avm.clearMockedCalls();
        this.executeArtistSafe(call_);
        Estate.AuthorityCapabilities memory rights = ingress.currentAuthorityCapabilities(artistId);
        require(
            rights.authorityClass == 3 && rights.effectiveCapabilities == 1024,
            "exact retry activates selected sale capability"
        );
    }

    /// @dev Root-derived mainnet native paths, signed by local fixture observers; not independent quorum or consensus evidence.
    function testEstateNetworkDerivedArweavePathsAndActualCoverageReachExecution() public {
        estateNetworkVector = true;
        vm.warp(1800000000);
        Estate.Execution memory p = _estatePendingFixture(1024);
        (Estate.RequestRecord memory request,,) =
            ingress.estateActivationRecord(p.expectedActivationRecordHash);
        require(
            request.terms.evidenceHash == keccak256(bytes("test")),
            "exact neutral network payload commitment"
        );
        vm.warp(request.noticeEndsAt);
        ingress.executeEstateActivation(p);
        Estate.AuthorityCapabilities memory rights = ingress.currentAuthorityCapabilities(artistId);
        require(
            rights.authorityClass == 3 && rights.status == 3
                && rights.effectiveCapabilities == 1024,
            "verified network-derived bytes reach actual estate execution"
        );
    }

    function testEstateActualSafeReadSurfaceAndCommercialAuthorityAtActivation() public {
        _all();
        Estate.Execution memory p = _estatePendingFixture(1024);
        (Estate.RequestRecord memory item,,) =
            ingress.estateActivationRecord(p.expectedActivationRecordHash);
        bytes[] memory reads = new bytes[](6);
        reads[0] = abi.encodeCall(
            IStreamArtistEstateActivation.estateActivationDigest, (item.terms, item.authorization)
        );
        reads[1] = abi.encodeCall(IStreamArtistEstateActivation.estateActivationState, (artistId));
        reads[2] = abi.encodeCall(
            IStreamArtistEstateActivation.estateActivationRecord, (p.expectedActivationRecordHash)
        );
        reads[3] = abi.encodeCall(
            IStreamArtistEstateActivation.estateActivationNonceHint,
            (artistId, address(delegateSafe))
        );
        reads[4] =
            abi.encodeCall(IStreamArtistEstateActivation.currentAuthorityCapabilities, (artistId));
        reads[5] = abi.encodeCall(IStreamArtistEstateActivation.estateAccelerationContext, (p));
        for (uint256 i; i < reads.length; ++i) {
            require(
                executeSafe(artist, keys, address(ingress), 0, reads[i], 0),
                "actual Safe estate read"
            );
        }
        vm.warp(item.noticeEndsAt);
        ingress.executeEstateActivation(p);
        (
            bytes32 id,
            uint64 generation,
            bytes32 binding,
            address account,
            uint8 class_,
            uint8 status,
            uint32 caps
        ) = ingress.collectionArtistAuthority(1);
        T.Binding memory actual = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        require(
            id == artistId && generation == actual.generation && binding == actual.bindingHash
                && account == address(delegateSafe) && class_ == 3 && status == 3 && caps == 1024,
            "exact seven-word current commercial authority"
        );
        require(
            executeSafe(
                delegateSafe,
                delegateKeys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistCommercialAuthority.collectionArtistAuthority, (uint256(1))
                ),
                0
            ),
            "successor Safe reads exact commercial facts"
        );
        require(
            ingress.supportsInterface(type(IStreamArtistEstateActivation).interfaceId)
                && ingress.supportsInterface(type(IStreamArtistCommercialAuthority).interfaceId),
            "implemented typed estate capabilities advertised"
        );
    }

    function _estateActivateAndAdopt(uint32 caps) private returns (Estate.Execution memory p) {
        p = _estatePendingFixture(caps);
        (Estate.RequestRecord memory item,,) =
            ingress.estateActivationRecord(p.expectedActivationRecordHash);
        vm.warp(item.noticeEndsAt);
        ingress.executeEstateActivation(p);
        artist = delegateSafe;
        keys = delegateKeys;
        nextNonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
    }

    function testEstateSuccessorAcceptsFixedIdentityWithClassThreeAndCannotCreatePolicy() public {
        T.Binding memory prior = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        T.Authorization memory oldProof =
            T.Authorization(100, uint64(block.timestamp + 365 days), "");
        oldProof.signature = _signature(ingress.acceptanceDigest(1, oldProof));
        _estateActivateAndAdopt(0);
        bytes32 roots = _roots();
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.acceptArtistBinding(1, oldProof);
        require(_roots() == roots, "retired principal proof fails before effects");
        uint256 nonce = nextNonce;
        uint64 observed = uint64(block.timestamp);
        vm.recordLogs();
        directArtistCalls = true;
        _accept();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        T.Binding memory current = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        require(
            current.bindingHash == prior.bindingHash && current.artistAddress == prior.artistAddress
                && current.artistId == prior.artistId && current.generation == prior.generation
                && current.accepted,
            "successor acceptance preserves frozen proposal facts"
        );
        bytes32 record =
            IStreamArtistAcceptanceOwner(suite.owners[3]).acceptanceRecord(prior.bindingHash);
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != suite.owners[3]
                    || logs[i].topics[0]
                        != keccak256(
                            "ArtistBindingAccepted(uint16,uint256,bytes32,address,uint64,bytes32,uint8,uint256,uint64,bytes32)"
                        )
            ) continue;
            ++count;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == bytes32(uint256(1))
                    && logs[i].topics[2] == artistId
                    && logs[i].topics[3] == bytes32(uint256(uint160(address(artist))))
                    && keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                prior.generation,
                                prior.bindingHash,
                                uint8(3),
                                nonce,
                                observed,
                                record
                            )
                        ),
                "truthful class-three acceptance event"
            );
        }
        require(
            count == 1 && ingress.acceptedArtist(1) == address(artist), "one acceptance transition"
        );
        T.PolicyConsent memory terms = T.PolicyConsent(1, PHASE, POLICY);
        T.Authorization memory a = T.Authorization(nextNonce, uint64(block.timestamp + 1 days), "");
        roots = _roots();
        vm.prank(address(artist));
        vm.expectRevert(
            abi.encodeWithSelector(Estate.EstateCapabilityUnavailable.selector, artistId, uint32(2))
        );
        ingress.recordPolicyConsent(terms, a);
        require(_roots() == roots, "acceptance creates no new-work capability");
    }

    function testEstateSuccessorRefusesFixedProposalWithExactClassThreeRecord() public {
        L.Termination memory terms = _termination(1);
        T.Binding memory binding = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        _estateActivateAndAdopt(0);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.bindingRefusalDigest(terms, a));
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_BINDING_REFUSAL_RECORD_V1"),
                block.chainid,
                address(ingress),
                suite.core,
                uint256(1),
                terms.generation,
                terms.bindingHash,
                artistId,
                address(artist),
                uint8(3),
                terms.reasonHash,
                a.nonce,
                uint64(block.timestamp)
            )
        );
        require(ingress.refuseArtistBinding(terms, a) == expected, "canonical class-three refusal");
        T.Binding memory after_ = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        require(
            after_.bindingHash == binding.bindingHash
                && after_.artistAddress == binding.artistAddress && !after_.accepted,
            "refusal retains immutable proposal"
        );
        require(
            ingress.currentAuthorityCapabilities(artistId).effectiveCapabilities == 0,
            "refusal grants no unrelated authority"
        );
    }

    function testEstateZeroCapSuccessorRotatesAndRevokesPriorStandingWithoutInventedCaps() public {
        address retired = address(artist);
        Estate.Execution memory p = _estateActivateAndAdopt(0);
        (Estate.RequestRecord memory saved,,) =
            ingress.estateActivationRecord(p.expectedActivationRecordHash);
        R.TransitionState memory estateWindow =
            ingress.artistTransitionState(p.expectedActivationRecordHash);
        vm.warp(uint256(estateWindow.postWindowEndsAt) + saved.standingTailSeconds);
        R.StandingRevocation memory terms = R.StandingRevocation(
            artistId, retired, keccak256("estate standing removal"), p.expectedActivationRecordHash
        );
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.standingRevocationDigest(terms, a));
        ingress.revokePriorAddressStanding(terms, a);
        (bool revoked,) = ingress.priorAddressStandingRevoked(artistId, retired);
        require(revoked, "class-three exact retirement standing revoked");
        _newRotationSafe(17001);
        bytes32 rotation = _stageRotation(p.expectedActivationRecordHash);
        _executeTimedRotation(rotation);
        Estate.AuthorityCapabilities memory rights = ingress.currentAuthorityCapabilities(artistId);
        require(
            rights.authorityAddress == address(rotationSafe) && rights.authorityClass == 3
                && rights.status == 3 && rights.effectiveCapabilities == 0
                && rights.activationRecordHash == p.expectedActivationRecordHash,
            "two-sided successor rotation retains class caps and activation provenance"
        );
    }

    function testEstateExecutionInvalidatesGrantEpochButExactRetiredGrantorCanRevoke() public {
        _accept();
        _payout();
        _delegateSetup();
        bytes32 grant = _grant(_delegation(1, 4, 1000, uint64(400 days), 5));
        Estate.Execution memory p = _estatePendingFixture(4095);
        (Estate.RequestRecord memory item,,) =
            ingress.estateActivationRecord(p.expectedActivationRecordHash);
        vm.warp(item.noticeEndsAt);
        ingress.executeEstateActivation(p);
        (bool active, uint64 recorded, uint64 current) =
            IStreamArtistEstateOwner(suite.owners[2]).delegationEpochState(grant);
        require(!active && recorded == 0 && current == 1, "old grant epoch ceases operation");
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(D.DelegationUnavailable.selector, grant));
        this.relayDelegateEconomics(address(primary), grant, 0);
        require(_roots() == roots, "epoch denial precedes all consent mutations");
        T.Identity memory before_ = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        directArtistCalls = true;
        _revoke(grant);
        T.Identity memory after_ = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        require(
            after_.nonceHint == before_.nonceHint + 1
                && after_.lastAuthorityActionAt == before_.lastAuthorityActionAt
                && after_.authorityAddress == before_.authorityAddress
                && after_.authorityClass == before_.authorityClass
                && after_.status == before_.status
                && IStreamArtistIdentityOwner(suite.owners[2])
                    .nonceUsed(artistId, before_.nonceHint)
                && ingress.delegationRecord(grant).revoked,
            "retired Safe grantor consumes shared nonce without current authority or liveness change"
        );
        D.Grant memory fresh = _delegation(1, 4, 0, 0, 5);
        T.Authorization memory a = T.Authorization(after_.nonceHint, 0, "");
        vm.prank(address(delegateSafe));
        vm.expectRevert(abi.encodeWithSelector(T.InvalidIdentity.selector, artistId));
        ingress.grantArtistDelegation(fresh, a);
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

    function testEstateEarlyAcceleratorRequiresClassOneExactEvidenceAndPerCallContext() public {
        Estate.Execution memory p = _estatePendingFixture(1024);
        (Estate.RequestRecord memory request,,) =
            ingress.estateActivationRecord(p.expectedActivationRecordHash);
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(Estate.EstateNoticeNotElapsed.selector, request.noticeEndsAt)
        );
        ingress.executeEstateActivation(p);
        for (uint8 i; i < 6; ++i) {
            avm.expectRevert(Contest.InvalidContestGovernance.selector);
            this.executeEstateAccelerator(p, i == 0 ? 0 : i == 1 ? 2 : 1, i < 2 ? 0 : i - 1);
            require(_roots() == roots, "failed acceleration preserves identical request and roots");
        }
        vm.recordLogs();
        this.executeEstateAccelerator(p, 1, 0);
        (Estate.RequestRecord memory saved, uint8 phase, Estate.ExecutionFacts memory result) =
            ingress.estateActivationRecord(p.expectedActivationRecordHash);
        require(
            phase == 2 && result.executedAt == request.requestedAt
                && result.governanceActionId == keccak256("unit authority gas raise")
                && result.governanceWitnessHash != 0 && saved.noticeEndsAt == request.noticeEndsAt,
            "exact class-one witness permits early execution without rewriting notice"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != suite.owners[2]
                    || logs[i].topics[0]
                        != keccak256(
                            "ArtistSuccessionActivated(uint16,bytes32,address,uint8,uint32,bytes32,bytes32)"
                        )
            ) continue;
            ++count;
            require(
                logs[i].topics.length == 3 && logs[i].topics[1] == artistId
                    && logs[i].topics[2] == bytes32(uint256(uint160(address(delegateSafe))))
                    && keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                uint8(3),
                                uint32(1024),
                                request.terms.evidenceHash,
                                result.governanceActionId
                            )
                        ),
                "exact activation event"
            );
        }
        require(count == 1, "one actual Identity activation event");
    }

    function testEstateNoticeAndPostWindowCaptureSurviveLaterTimingChanges() public {
        Estate.Execution memory p = _estatePendingFixture(0);
        (Estate.RequestRecord memory saved,,) =
            ingress.estateActivationRecord(p.expectedActivationRecordHash);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        bytes32 parameter = keccak256("ARTIST_ESTATE_ACTIVATION_NOTICE_SECONDS");
        T.Identity memory before_ = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        authority.configureWindow(ingress, parameter, 200 days, 1, 1, false);
        authority.configureWindow(
            ingress, keccak256("ARTIST_ROTATION_CONTEST_SECONDS"), 14 days, 1, 1, false
        );
        (Estate.RequestRecord memory same,,) =
            ingress.estateActivationRecord(p.expectedActivationRecordHash);
        require(
            keccak256(abi.encode(saved)) == keccak256(abi.encode(same)),
            "recorded windows immutable under config change"
        );
        T.Identity memory after_ = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        require(
            before_.lastAuthorityActionAt == after_.lastAuthorityActionAt
                && before_.nonceHint == after_.nonceHint,
            "timing changes are not living actions"
        );
        vm.warp(saved.noticeEndsAt);
        ingress.executeEstateActivation(p);
        R.TransitionState memory transition =
            ingress.artistTransitionState(p.expectedActivationRecordHash);
        require(
            transition.postWindowEndsAt == saved.noticeEndsAt + saved.postContestSeconds,
            "execution uses captured post-window rather than new configuration"
        );
    }

    function testEstateLivingRotationCancelsPendingEstateAndPreservesWindowTruth() public {
        Estate.Execution memory p = _estatePendingFixture(4095);
        (, uint64 notice,) = ingress.estateActivationState(artistId);
        (bytes32 active, uint64 end, bool contested) = ingress.activeAuthorityWindow(artistId);
        require(
            active == p.expectedActivationRecordHash && end == notice && !contested,
            "generic read resolves actual pending estate"
        );
        _newRotationSafe(17002);
        vm.recordLogs();
        bytes32 replacement = _stageRotation(p.expectedActivationRecordHash);
        _assertEstateCancellationEvent(vm.getRecordedLogs(), p.expectedActivationRecordHash, 1);
        (, uint8 phase,) = ingress.estateActivationRecord(p.expectedActivationRecordHash);
        (active, end, contested) = ingress.activeAuthorityWindow(artistId);
        require(
            phase == 3 && active == replacement && !contested
                && end == ingress.rotationRecord(replacement).transition.contestEndsAt,
            "living transition supersedes pending estate atomically"
        );
    }

    function _estatePreparedRequest(uint32 caps) private returns (Estate.Request memory p) {
        _delegateSetup();
        Succ.Designation memory d = _successorTerms(address(delegateSafe), 2);
        d.grantedCapabilities = caps;
        bytes32 designation = _successionRecord(d);
        (bytes32 evidence, bytes32 coverage) = _estateArchiveEvidence(artistId);
        return Estate.Request(artistId, address(delegateSafe), evidence, designation, coverage);
    }

    function testEstateRequestLateArchiveRollsReplayAndPendingBackThenExactSafeRetry() public {
        Estate.Request memory p = _estatePreparedRequest(0);
        T.Authorization memory a = T.Authorization(0, uint64(block.timestamp + 1 days), "");
        bytes memory data =
            abi.encodeCall(IStreamArtistEstateActivation.requestEstateActivation, (p, a));
        bytes32 roots = _roots();
        uint256 safeNonce = delegateSafe.nonce();
        avm.mockCallRevert(
            address(archive),
            abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(T.InvalidRecord.selector)
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeDelegate(address(ingress), data);
        (,, bytes32 pending) = ingress.estateActivationState(artistId);
        require(
            _roots() == roots && pending == 0 && delegateSafe.nonce() == safeNonce
                && ingress.estateActivationNonceHint(artistId, address(delegateSafe)) == 0,
            "late request Archive failure rolls all owner and Safe effects back"
        );
        avm.clearMockedCalls();
        vm.recordLogs();
        require(
            executeSafe(delegateSafe, delegateKeys, address(ingress), 0, data, 0),
            "same exact request retry"
        );
        (, uint64 ends, bytes32 record) = ingress.estateActivationState(artistId);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != suite.owners[2]
                    || logs[i].topics[0]
                        != keccak256(
                            "ArtistEstateActivationRequested(uint16,bytes32,address,uint64,uint64,uint256,bytes32,bytes32)"
                        )
            ) continue;
            ++count;
            require(
                logs[i].topics.length == 3 && logs[i].topics[1] == artistId
                    && logs[i].topics[2] == bytes32(uint256(uint160(address(delegateSafe))))
                    && keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                uint64(block.timestamp),
                                ends,
                                a.nonce,
                                p.evidenceHash,
                                record
                            )
                        ),
                "exact request emitter event and record"
            );
        }
        require(
            count == 1 && ingress.estateActivationNonceHint(artistId, address(delegateSafe)) == 1,
            "one successful request consumes persistent successor nonce"
        );
    }

    function testEstateSuccessorProofDomainAndCancelledRequestNonceCannotReplay() public {
        Estate.Request memory p = _estatePreparedRequest(0);
        T.Authorization memory a = T.Authorization(0, uint64(block.timestamp + 1 days), "");
        bytes32 body = keccak256(
            abi.encode(
                keccak256(
                    "StreamArtistEstateActivation(bytes32 artistId,address successor,bytes32 evidenceHash,uint256 nonce,uint64 deadline)"
                ),
                artistId,
                p.successor,
                p.evidenceHash,
                a.nonce,
                a.time
            )
        );
        bytes32 roots = _roots();
        for (uint256 i; i < 2; ++i) {
            bytes32 domain = keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256("6529StreamArtistRegistry"),
                    keccak256("1"),
                    i == 0 ? block.chainid + 1 : block.chainid,
                    i == 1 ? address(0xBAD) : address(ingress)
                )
            );
            bytes32 wrong = keccak256(abi.encodePacked(hex"1901", domain, body));
            a.signature = safeThresholdSignature(
                delegateKeys, safeMessageDigest(delegateSafe, abi.encode(wrong))
            );
            avm.expectRevert(T.InvalidSignature.selector);
            ingress.requestEstateActivation(p, a);
            require(_roots() == roots, "actual wrong chain or facade domain rejects same body");
        }
        a.signature = _delegateSignature(ingress.estateActivationDigest(p, a));
        bytes32 record = ingress.requestEstateActivation(p, a);
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistEstateActivation.cancelEstateActivation, (artistId, record)
                ),
                0
            ),
            "actual living Safe cancellation"
        );
        bytes32 key = _identityRevisionReplayKey(
            keccak256("identity_authority.replay.nonce_allocator"),
            keccak256(abi.encode("estate_activation", artistId, p.successor, uint256(0)))
        );
        roots = _roots();
        T.ReplayCell memory consumed = IStreamArtistOwner(suite.owners[2]).replayCell(key);
        require(
            consumed.status == 2 && consumed.commitment == ingress.estateActivationDigest(p, a),
            "cancel retains exact consumed successor nonce cell"
        );
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.requestEstateActivation(p, a);
        require(_roots() == roots, "same-block duplicate record rejects before authorization");
        vm.warp(block.timestamp + 1);
        vm.expectRevert(abi.encodeWithSelector(T.Replay.selector, key));
        ingress.requestEstateActivation(p, a);
        require(_roots() == roots, "cancel preserves permanent prior successor nonce");
        a.nonce = 1;
        a.signature = _delegateSignature(ingress.estateActivationDigest(p, a));
        bytes32 later = ingress.requestEstateActivation(p, a);
        require(
            later != record && ingress.estateActivationNonceHint(artistId, p.successor) == 2,
            "fresh nonce can request same retained coverage after living cancellation"
        );
    }

    function testEstateApprovedEmptySuccessorProofIsRelayAndExpiredProofRejectsBeforeRetry()
        public
    {
        Estate.Request memory p = _estatePreparedRequest(0);
        T.Authorization memory a = T.Authorization(0, uint64(block.timestamp - 1), "");
        a.signature = _delegateSignature(ingress.estateActivationDigest(p, a));
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(T.ExpiredAuthorization.selector, a.time));
        ingress.requestEstateActivation(p, a);
        require(_roots() == roots, "expired exact successor signature cannot request");
        a.time = uint64(block.timestamp + 1 days);
        a.signature = "";
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.requestEstateActivation(p, a);
        bytes32 digest = ingress.estateActivationDigest(p, a);
        require(
            executeSafe(
                delegateSafe,
                delegateKeys,
                safeComponents.signMessage,
                0,
                abi.encodeWithSignature("signMessage(bytes)", abi.encode(digest)),
                1
            ),
            "actual successor Safe approved digest"
        );
        bytes32 record = ingress.requestEstateActivation(p, a);
        (Estate.RequestRecord memory saved,,) = ingress.estateActivationRecord(record);
        require(
            saved.authorization.signature.length == 0 && saved.authorization.time == a.time
                && saved.authorization.nonce == 0,
            "approved-empty relay retains exact submitted authorization"
        );
    }

    function testEstatePairedDirectiveIntersectionAndLatestGlobalForbidDoNotAddRights() public {
        _delegateSetup();
        // The paired grant permits only policy+sale. A newer unpaired grant cannot add payout.
        Succ.PublicDocument memory doc =
            Succ.PublicDocument(keccak256("paired legal"), keccak256("paired payout"));
        Succ.Directive memory directive = Succ.Directive(
            artistId, 1026, 0, keccak256(ingress.previewEstateDirectivePayload(1026, 0, doc))
        );
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.estateDirectiveDigest(directive, a));
        bytes32 paired = ingress.recordEstateDirective(directive, a, doc);
        Succ.Designation memory d = _successorTerms(address(delegateSafe), 2);
        d.directiveHash = paired;
        bytes32 designation = _successionRecord(d);
        _directiveRecord(2);
        (bytes32 evidence, bytes32 coverage) = _estateArchiveEvidence(artistId);
        Estate.Request memory p =
            Estate.Request(artistId, address(delegateSafe), evidence, designation, coverage);
        a = T.Authorization(0, uint64(block.timestamp + 1 days), "");
        a.signature = _delegateSignature(ingress.estateActivationDigest(p, a));
        bytes32 record = ingress.requestEstateActivation(p, a);
        (Estate.RequestRecord memory saved,,) = ingress.estateActivationRecord(record);
        require(
            saved.pairedDirectiveRecordHash == paired
                && saved.forbiddenDirectiveRecordHash != paired,
            "exact distinct paired grant and current global-forbid witnesses"
        );
        vm.warp(saved.noticeEndsAt);
        ingress.executeEstateActivation(Estate.Execution(artistId, record, coverage));
        require(
            ingress.currentAuthorityCapabilities(artistId).effectiveCapabilities == 1024,
            "designation intersects paired grant then latest global forbids; unrelated grant adds nothing"
        );
    }

    function testEstateClosedOldRotationDoesNotHideNewPendingEstateWindow() public {
        _newRotationSafe(17003);
        bytes32 old = _stageRotation(bytes32(0));
        _executeTimedRotation(old);
        _adoptRotatedSafe();
        vm.warp(ingress.rotationRecord(old).transition.postWindowEndsAt);
        _dismissalGuardianCause();
        _dismissalExecute(_dismissalRequest(), 1, 0);
        require(
            ingress.identityTransitionClosure(artistId, old).dismissalRecordHash != 0,
            "actual old execution is closed"
        );
        ArtistUnitGovernance(manager.governanceAuthority())
            .configureContestReads(
                address(estateFixityRoles),
                address(this),
                keccak256("archival fixture"),
                "urn:unit:archival"
            );
        Estate.Execution memory p = _estatePendingFixture(0);
        (Estate.RequestRecord memory saved,,) =
            ingress.estateActivationRecord(p.expectedActivationRecordHash);
        (bytes32 active, uint64 end, bool contested) = ingress.activeAuthorityWindow(artistId);
        require(
            active == p.expectedActivationRecordHash && end == saved.noticeEndsAt && !contested,
            "closed old cohort cannot hide actual pending estate"
        );
    }

    // Draft for the next test-only boundary; not part of the immutable225 run.
    function testEstateGuardianSetCapabilityCannotRemoveCapturedLivingGuardians() public {
        _selfGuardian();
        address retained = address(artist);
        _estateActivateAndAdopt(256);
        R.GuardianSet memory terms = R.GuardianSet(artistId, new address[](0), 0, 0);
        T.Authorization memory a = T.Authorization(nextNonce, uint64(block.timestamp), "");
        a.signature = _signature(ingress.guardianSetDigest(terms, a));
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(
                Estate.EstateCapabilityUnavailable.selector, artistId, uint32(2048)
            )
        );
        ingress.setArtistGuardians(terms, a);
        require(_roots() == roots, "guardian cap alone does not remove lifetime guardian");
        terms.guardians = new address[](1);
        terms.guardians[0] = retained;
        terms.approvalThreshold = 1;
        a.signature = _signature(ingress.guardianSetDigest(terms, a));
        bytes32 record = ingress.setArtistGuardians(terms, a);
        require(
            ingress.guardianSetRecord(record).authorityClass == 3,
            "same nonce records truthful retained guardian set"
        );
    }

    function testEstateExplicitGuardianRemovalCapabilityCanRemoveCapturedSet() public {
        _selfGuardian();
        _estateActivateAndAdopt(2304);
        R.GuardianSet memory terms = R.GuardianSet(artistId, new address[](0), 0, 0);
        T.Authorization memory a = T.Authorization(nextNonce, uint64(block.timestamp), "");
        a.signature = _signature(ingress.guardianSetDigest(terms, a));
        bytes32 record = ingress.setArtistGuardians(terms, a);
        R.GuardianRecord memory saved = ingress.guardianSetRecord(record);
        require(
            saved.authorityClass == 3 && saved.terms.guardians.length == 0
                && saved.provisional.transitionRecordHash != 0,
            "explicit removal right still obeys post-estate provisional window"
        );
        vm.warp(saved.provisional.windowEndsAt);
        (address[] memory members,,, bytes32 selected) = ingress.guardianSet(artistId);
        require(
            members.length == 0 && selected == record,
            "uncontested removal matures at captured equality"
        );
    }

    function testEstatePendingOldCollaboratorAccountNeverRedirectsToSuccessor() public {
        ingress.withdrawArtistBinding(_termination(1));
        T.BindingProposal memory terms = _proposal(artistId);
        address listed = address(artist);
        terms.collaborators = new T.CollaboratorRecord[](1);
        terms.collaborators[0] = T.CollaboratorRecord(listed, keccak256("composer"), bytes32(0));
        ingress.proposeArtistBinding(1, terms, bytes("unit identity document"), "Artist Safe");
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        _estateActivateAndAdopt(0);
        _accept();
        C.BindingAcceptance memory row = C.BindingAcceptance(
            1, b.generation, b.bindingHash, listed, keccak256("composer"), bytes32(0)
        );
        T.Authorization memory a = T.Authorization(nextNonce, uint64(block.timestamp + 1 days), "");
        a.signature = _signature(ingress.collaboratorAcceptanceDigest(row, a));
        bytes32 roots = _roots();
        // Exact listed account has no active identity after succession.
        vm.expectRevert(abi.encodeWithSelector(T.InvalidIdentity.selector, bytes32(0)));
        ingress.acceptCollaborator(row, a);
        row.account = address(artist);
        a.signature = _signature(ingress.collaboratorAcceptanceDigest(row, a));
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.acceptCollaborator(row, a);
        require(
            _roots() == roots && !IStreamArtistBindingOwner(suite.owners[0]).binding(1).accepted,
            "pending tuple is exact and cannot inherit authority by substitution"
        );
    }

    function testEstateActualSafeOwnerAndBothChildCallbacksRemainProtocolOnly() public {
        Estate.Execution memory p = _estatePendingFixture(0);
        StreamArtistIdentityAuthority owner = StreamArtistIdentityAuthority(suite.owners[2]);
        address child1 = owner.identityWriterExtension();
        address child2 = owner.identityEstateExtension();
        T.ActionContext memory c =
            T.ActionContext(39, address(artist), owner.ownerStateSnapshotV2());
        bytes memory data = abi.encodeCall(
            IStreamArtistEstateOwner.cancelEstate, (c, artistId, p.expectedActivationRecordHash)
        );
        bytes32 roots = _roots();
        vm.prank(address(artist));
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(artist)));
        IStreamArtistEstateOwner(address(owner))
            .cancelEstate(c, artistId, p.expectedActivationRecordHash);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(address(owner), data);
        vm.prank(address(artist));
        vm.expectRevert(abi.encodeWithSignature("ExtensionWrongHost(address)", child2));
        IStreamArtistEstateOwner(child2).cancelEstate(c, artistId, p.expectedActivationRecordHash);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(child2, data);
        // Existing child1 read guard and new child2 read guard must not return empty owner facts.
        bytes memory read = abi.encodeCall(IStreamArtistOwner.ownerStateSnapshotV2, ());
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(child1, read);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(child2, read);
        require(
            _roots() == roots, "actual Safe CALL cannot impersonate Coordinator or Identity host"
        );
    }

    function _estateSafeRead(address target, bytes memory data) private {
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

    function testEstateArchivalActualSafeInheritedAndCurrentReadSelectors() public {
        (bytes32 evidence, bytes32 hash) = _estateArchiveEvidence(artistId);
        A.CoverageFacts memory f = estateCoverageProvider.coverage(hash);
        address[2] memory targets =
            [address(estateCheckpointVerifier), address(estateCoverageProvider)];
        bytes[] memory common = new bytes[](11);
        common[0] = abi.encodeWithSignature("FAILURE_CLASS_FAIL_CLOSED_PRECHECK()");
        common[1] = abi.encodeWithSignature("FAILURE_CLASS_FORWARDING_CAP()");
        common[2] = abi.encodeWithSignature("FAILURE_CLASS_MIN_GAS_GATE()");
        common[3] = abi.encodeWithSignature("FAILURE_CLASS_NONE()");
        common[4] = abi.encodeWithSignature("GAS_PARAMETER_SCHEMA_VERSION()");
        common[5] = abi.encodeCall(IStreamGasParameterHost.gasParameterIds, ());
        common[6] = abi.encodeCall(IStreamGasParameterHost.governanceAuthority, ());
        common[7] = abi.encodeWithSignature("profileHash()");
        common[8] = abi.encodeWithSignature("supportsInterface(bytes4)", bytes4(0x01ffc9a7));
        bytes32 signatureGas = keccak256("6529STREAM_GGP_ARCHIVAL_ERC1271_VERIFY_GAS");
        common[9] = abi.encodeCall(IStreamGasParameterHost.gasParameter, (signatureGas));
        common[10] = abi.encodeCall(IStreamGasParameterHost.gasParameterInfo, (signatureGas));
        for (uint256 j; j < 2; ++j) {
            for (uint256 i; i < common.length; ++i) {
                _estateSafeRead(targets[j], common[i]);
            }
        }
        _estateSafeRead(
            targets[0], abi.encodeCall(IStreamArchivalCheckpointVerifier.configurationHash, ())
        );
        _estateSafeRead(targets[0], abi.encodeCall(IStreamArchivalCheckpointVerifier.networkId, ()));
        _estateSafeRead(targets[0], abi.encodeCall(IStreamArchivalCheckpointVerifier.quorum, ()));
        _estateSafeRead(targets[1], abi.encodeCall(IStreamArchivalCoverage.core, ()));
        _estateSafeRead(targets[1], abi.encodeCall(IStreamArchivalCoverage.roleRegistry, ()));
        _estateSafeRead(targets[1], abi.encodeCall(IStreamArchivalCoverage.checkpointVerifier, ()));
        _estateSafeRead(targets[1], abi.encodeWithSignature("POSSESSION_PROFILE()"));
        _estateSafeRead(
            targets[1],
            abi.encodeCall(IStreamArchivalCoverage.familyRevision, (f.firstFamilyRecordHash))
        );
        _estateSafeRead(
            targets[1],
            abi.encodeCall(
                IStreamArchivalCoverage.familyStatusContext, (f.firstFamilyRecordHash, uint8(2))
            )
        );
        _estateSafeRead(
            targets[1],
            abi.encodeCall(IStreamArchivalCoverage.latestFixity, (f.secondReceiptRecordHash))
        );
        _estateSafeRead(targets[1], abi.encodeCall(IStreamArchivalCoverage.nonceUsed, (bytes32(0))));
        (A.Family memory family_,) = estateCoverageProvider.family(f.secondFamilyRecordHash);
        family_.familyId = keccak256("estate-safe-registration-context");
        _estateSafeRead(
            targets[1],
            abi.encodeCall(
                IStreamArchivalCoverage.familyRegistrationContext,
                ("estate-safe-registration-context", family_)
            )
        );
        (A.ReceiptTerms memory receipt,,) =
            estateCoverageProvider.receipt(f.secondReceiptRecordHash);
        _estateSafeRead(
            targets[1],
            abi.encodeCall(
                IStreamArchivalCoverage.possessionHash,
                (A.Possession(
                        receipt.envelopeHash,
                        receipt.familyRecordHash,
                        receipt.storageIdentifierHash,
                        receipt.writer,
                        receipt.observedAt
                    ))
            )
        );
        _estateSafeRead(
            targets[1], abi.encodeCall(IStreamArchivalCoverage.receiptDigest, (receipt))
        );
        (A.FixityTerms memory fixity_,) = estateCoverageProvider.fixity(f.secondFixityRecordHash);
        _estateSafeRead(targets[1], abi.encodeCall(IStreamArchivalCoverage.fixityDigest, (fixity_)));
        _estateSafeRead(
            targets[1],
            abi.encodeCall(IStreamArchivalCoverage.requireCoverage, (hash, artistId, evidence))
        );
        for (uint256 i; i < 2; ++i) {
            bytes memory data = abi.encodeCall(
                IStreamGasParameterHost.raiseGasParameter, (signatureGas, uint256(500000))
            );
            vm.prank(address(artist));
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamGasParameterHost.GasParameterNotAuthority.selector, address(artist)
                )
            );
            IStreamGasParameterHost(targets[i]).raiseGasParameter(signatureGas, 500000);
            vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
            this.executeTargetSafe(targets[i], data);
        }
        bytes memory statusCall = abi.encodeCall(
            IStreamArchivalCoverage.setFamilyStatus, (f.firstFamilyRecordHash, uint8(2))
        );
        vm.prank(address(artist));
        vm.expectRevert(abi.encodeWithSelector(A.ArchivalUnauthorized.selector, address(artist)));
        estateCoverageProvider.setFamilyStatus(f.firstFamilyRecordHash, 2);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(targets[1], statusCall);
        require(
            estateCoverageProvider.requireCoverage(hash, artistId, evidence).coverageRecordHash
                == hash,
            "all read and direct-governance-negative rows preserve actual coverage"
        );
    }

    function testEstatePermissionlessSafeEnvelopeFixityAndCoverageHaveExactGoldenCommitments()
        public
    {
        (bytes32 evidence, bytes32 old) = _estateArchiveEvidence(artistId);
        A.CoverageFacts memory f = estateCoverageProvider.coverage(old);
        (A.Envelope memory envelope,) = estateCoverageProvider.envelope(f.envelopeHash);
        bytes memory payload = bytes("another exact public envelope");
        A.Envelope memory other = envelope;
        other.evidenceHash = keccak256(payload);
        other.payloadDigest = sha256(payload);
        other.byteSize = uint64(payload.length);
        bytes32 envelopeHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARCHIVAL_ENVELOPE_V1"),
                block.chainid,
                address(estateCoverageProvider),
                other
            )
        );
        require(
            executeSafe(
                artist,
                keys,
                address(estateCoverageProvider),
                0,
                abi.encodeCall(IStreamArchivalCoverage.recordEnvelope, (other, payload)),
                0
            ),
            "permissionless actual Safe envelope write"
        );
        (A.Envelope memory actual, bytes memory bytes_) =
            estateCoverageProvider.envelope(envelopeHash);
        require(
            keccak256(abi.encode(actual)) == keccak256(abi.encode(other))
                && keccak256(bytes_) == keccak256(payload),
            "exact envelope domain and stored bytes"
        );
        (A.ReceiptTerms memory receipt,,) =
            estateCoverageProvider.receipt(f.secondReceiptRecordHash);
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream Archival Coverage"),
                keccak256("1"),
                block.chainid,
                address(estateCoverageProvider)
            )
        );
        bytes32 receiptBody = keccak256(
            abi.encode(
                keccak256(
                    "StreamArchivalReceipt(bytes32 envelopeHash,bytes32 familyRecordHash,bytes32 storageIdentifierHash,bytes32 evidenceClass,bytes32 proofProfileHash,bytes32 proofRecordHash,address writer,uint64 observedAt,uint256 nonce,uint64 deadline)"
                ),
                receipt.envelopeHash,
                receipt.familyRecordHash,
                receipt.storageIdentifierHash,
                receipt.evidenceClass,
                receipt.proofProfileHash,
                receipt.proofRecordHash,
                receipt.writer,
                receipt.observedAt,
                receipt.nonce,
                receipt.deadline
            )
        );
        require(
            estateCoverageProvider.receiptDigest(receipt)
                == keccak256(abi.encodePacked(hex"1901", domain, receiptBody)),
            "independent receipt field sequence and provider domain"
        );
        (A.FixityTerms memory fixity_,) = estateCoverageProvider.fixity(f.secondFixityRecordHash);
        fixity_.previousFixityHash = f.secondFixityRecordHash;
        fixity_.nonce = 2;
        fixity_.reportHash = keccak256("new healthy fixity report");
        bytes32 body = keccak256(
            abi.encode(
                keccak256(
                    "StreamArchivalFixity(bytes32 receiptRecordHash,bytes32 envelopeHash,bytes32 familyRecordHash,bytes32 expectedDigest,bytes32 observedDigest,uint64 observedSize,uint64 checkedAt,uint8 outcome,bytes32 reportHash,bytes32 previousFixityHash,bytes32 repairReportHash,address verifier,uint256 nonce,uint64 deadline)"
                ),
                fixity_.receiptRecordHash,
                fixity_.envelopeHash,
                fixity_.familyRecordHash,
                fixity_.expectedDigest,
                fixity_.observedDigest,
                fixity_.observedSize,
                fixity_.checkedAt,
                fixity_.outcome,
                fixity_.reportHash,
                fixity_.previousFixityHash,
                fixity_.repairReportHash,
                fixity_.verifier,
                fixity_.nonce,
                fixity_.deadline
            )
        );
        bytes32 digest = keccak256(abi.encodePacked(hex"1901", domain, body));
        require(
            estateCoverageProvider.fixityDigest(fixity_) == digest,
            "independent fixity type and domain"
        );
        (uint8 v, bytes32 r, bytes32 ss) = safeVm.sign(0xE5705, digest);
        bytes memory signature = abi.encodePacked(r, ss, v);
        vm.recordLogs();
        require(
            executeSafe(
                artist,
                keys,
                address(estateCoverageProvider),
                0,
                abi.encodeCall(IStreamArchivalCoverage.recordFixity, (fixity_, signature)),
                0
            ),
            "Safe relays actual independent operator fixity"
        );
        bytes32 fixityHash = estateCoverageProvider.latestFixity(f.secondReceiptRecordHash);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(estateCoverageProvider)
                    || logs[i].topics[0]
                        != keccak256(
                            "ArchivalFixityRecorded(uint16,bytes32,bytes32,(bytes32,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint8,bytes32,bytes32,bytes32,address,uint256,uint64))"
                        )
            ) continue;
            ++count;
            require(
                logs[i].topics.length == 3 && logs[i].topics[1] == fixityHash
                    && logs[i].topics[2] == f.secondReceiptRecordHash
                    && keccak256(logs[i].data) == keccak256(abi.encode(uint16(1), fixity_)),
                "exact independent fixity event"
            );
        }
        require(count == 1, "one full-schema fixity event");
        f.coverageRecordHash = 0;
        f.secondFixityRecordHash = fixityHash;
        bytes32 next = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARCHIVAL_COVERAGE_RECORD_V1"),
                block.chainid,
                address(estateCoverageProvider),
                f
            )
        );
        require(
            executeSafe(
                artist,
                keys,
                address(estateCoverageProvider),
                0,
                abi.encodeCall(
                    IStreamArchivalCoverage.recordCoverage,
                    (f.firstReceiptRecordHash, f.secondReceiptRecordHash)
                ),
                0
            ),
            "permissionless actual Safe selects current independent fixity coverage"
        );
        f.coverageRecordHash = next;
        require(
            keccak256(abi.encode(estateCoverageProvider.requireCoverage(next, artistId, evidence)))
                == keccak256(abi.encode(f)),
            "exact canonical full coverage facts"
        );
        avm.expectRevert(A.InvalidArchivalCoverage.selector);
        estateCoverageProvider.requireCoverage(old, artistId, evidence);
    }

    function _estateCoolCoverageState() private {
        // Foundry cool(address) marks that account and all its slots cold:
        // https://github.com/foundry-rs/foundry/blob/master/crates/cheatcodes/spec/src/vm.rs
        safeVm.cool(address(core));
        safeVm.cool(address(ingress));
        safeVm.cool(address(estateCoverageProvider));
        safeVm.cool(address(estateCheckpointVerifier));
        safeVm.cool(suite.owners[2]);
    }

    function testEstateActualColdCoverageAndParentGasSameContextRetry() public {
        Estate.Execution memory p = _estatePendingFixture(1024);
        (Estate.RequestRecord memory item,,) =
            ingress.estateActivationRecord(p.expectedActivationRecordHash);
        bytes memory call_ = abi.encodeCall(
            IStreamArchivalCoverage.requireCoverage,
            (p.currentCoverageHash, artistId, item.terms.evidenceHash)
        );
        _estateCoolCoverageState();
        uint256 before_ = gasleft();
        (bool ok, bytes memory result) =
            address(estateCoverageProvider).staticcall{ gas: 400000 }(call_);
        uint256 span = before_ - gasleft();
        require(ok && result.length == 384, "actual cold provider fits current outer cap");
        require(
            abi.decode(result, (A.CoverageFacts)).coverageRecordHash == p.currentCoverageHash,
            "actual provider result"
        );
        emit EstateCoverageMeasurement("provider-state-cold", 400000, span);
        call_ = abi.encodeCall(IStreamArtistEstateActivation.estateAccelerationContext, (p));
        _estateCoolCoverageState();
        (ok, result) = address(ingress).staticcall{ gas: 350000 }(call_);
        require(
            !ok
                && keccak256(result)
                    == keccak256(
                        abi.encodeWithSelector(T.ComponentChanged.selector, address(core))
                    ),
            "insufficient parent gas fails exact first bounded dependency"
        );
        _estateCoolCoverageState();
        before_ = gasleft();
        (ok, result) = address(ingress).staticcall{ gas: 1500000 }(call_);
        span = before_ - gasleft();
        require(ok && result.length == 160, "same exact context healthy parent gas retry");
        emit EstateCoverageMeasurement("facade-state-cold-linked-code-warm", 1500000, span);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        bytes32 inner = keccak256("6529STREAM_GGP_ARCHIVAL_DEPENDENCY_READ_GAS");
        bytes32 outer = keccak256("6529STREAM_GGP_ARTIST_ARCHIVAL_COVERAGE_READ_GAS");
        authority.raise(estateCoverageProvider, inner, 300000);
        _estateCoolCoverageState();
        (ok, result) = address(ingress).staticcall{ gas: 1500000 }(call_);
        // Preserve the measured observation without asserting that an unmeasured cap must fail.
        emit EstateCoverageMeasurement(
            ok ? "inner-raised-outer-original-pass" : "inner-raised-outer-original-fail", 400000, 0
        );
        authority.raise(ingress, outer, 800000);
        _estateCoolCoverageState();
        (ok, result) = address(ingress).staticcall{ gas: 2000000 }(call_);
        require(
            ok && result.length == 160,
            "actual nested and outer monotonic raises preserve identical evidence"
        );
        require(
            ingress.estateActivationNonceHint(artistId, address(delegateSafe)) == 1,
            "passive capped reads and governance raises consume no estate authorization"
        );
    }

    function _estateExactOwnerBytes(bytes memory data, bytes memory expected) private {
        (bool ok, bytes memory actual) = suite.owners[2].staticcall(data);
        require(
            ok && keccak256(actual) == keccak256(expected), "exact full encoded owner returndata"
        );
        _estateSafeRead(suite.owners[2], data);
    }

    function testEstateSixEncodedOwnerReadsMatchExplicitTuplesIncludingMaximumSignature() public {
        Estate.RequestRecord memory empty;
        Estate.ExecutionFacts memory noExecution;
        bytes32 absent = keccak256("absent estate record");
        _estateExactOwnerBytes(
            abi.encodeCall(IStreamArtistEstateOwner.estateActivationRecord, (absent)),
            abi.encode(empty, uint8(0), noExecution)
        );
        Succ.DesignationRecord memory emptyDesignation;
        Succ.DirectiveRecord memory emptyDirective;
        _estateExactOwnerBytes(
            abi.encodeCall(IStreamArtistSuccessionReads.successorDesignationRecord, (absent)),
            abi.encode(emptyDesignation)
        );
        _estateExactOwnerBytes(
            abi.encodeCall(IStreamArtistSuccessionReads.estateDirectiveRecord, (absent)),
            abi.encode(emptyDirective)
        );
        bytes32 directive = _directiveRecord(0);
        Estate.Request memory p = _estatePreparedRequest(0);
        A.CoverageFacts memory coverage = estateCoverageProvider.coverage(p.selectedCoverageHash);
        Estate.RequestFacts memory expected = Estate.RequestFacts(
            p.expectedDesignationRecordHash,
            0,
            directive,
            0,
            coverage.envelopeHash,
            180 days,
            1,
            7 days,
            90 days,
            1
        );
        _estateExactOwnerBytes(
            abi.encodeCall(IStreamArtistEstateOwner.estateRequestFacts, (p, coverage.envelopeHash)),
            abi.encode(expected)
        );
        Estate.AuthorityCapabilities memory living =
            Estate.AuthorityCapabilities(address(artist), 1, 1, 4095, 0);
        _estateExactOwnerBytes(
            abi.encodeCall(IStreamArtistEstateOwner.currentAuthorityCapabilities, (artistId)),
            abi.encode(living)
        );
        Succ.Designation memory terms = _successorTerms(address(delegateSafe), 2);
        terms.grantedCapabilities = 0;
        Succ.DesignationRecord memory designation = Succ.DesignationRecord(
            p.expectedDesignationRecordHash,
            terms,
            address(artist),
            1,
            1,
            uint64(block.timestamp),
            R.ProvisionalAssociation(0, 0)
        );
        _estateExactOwnerBytes(
            abi.encodeCall(
                IStreamArtistSuccessionReads.successorDesignationRecord,
                (p.expectedDesignationRecordHash)
            ),
            abi.encode(designation)
        );
        (Succ.Directive memory directiveTerms,) = _directiveTerms(0);
        Succ.DirectiveRecord memory savedDirective = Succ.DirectiveRecord(
            directive,
            directiveTerms,
            address(artist),
            1,
            0,
            uint64(block.timestamp),
            R.ProvisionalAssociation(0, 0)
        );
        _estateExactOwnerBytes(
            abi.encodeCall(IStreamArtistSuccessionReads.estateDirectiveRecord, (directive)),
            abi.encode(savedDirective)
        );
        T.Authorization memory a = T.Authorization(0, uint64(block.timestamp + 1 days), "");
        bytes memory shortSignature = _delegateSignature(ingress.estateActivationDigest(p, a));
        a.signature = new bytes(4096);
        for (uint256 i; i < shortSignature.length; ++i) {
            a.signature[i] = shortSignature[i];
        }
        bytes32 record = ingress.requestEstateActivation(p, a);
        Estate.RequestRecord memory item = Estate.RequestRecord(
            record,
            p,
            a,
            address(artist),
            p.expectedDesignationRecordHash,
            0,
            directive,
            0,
            coverage.envelopeHash,
            uint64(block.timestamp),
            uint64(block.timestamp + 180 days),
            180 days,
            1,
            7 days,
            90 days,
            1,
            0
        );
        _estateExactOwnerBytes(
            abi.encodeCall(IStreamArtistEstateOwner.estateActivationRecord, (record)),
            abi.encode(item, uint8(1), noExecution)
        );
        Estate.Execution memory execution =
            Estate.Execution(artistId, record, p.selectedCoverageHash);
        Estate.AccelerationContext memory x;
        x.scopeHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ESTATE_ACCELERATION_SCOPE_V1"),
                block.chainid,
                address(ingress),
                suite.owners[2],
                artistId,
                record
            )
        );
        x.oldValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ESTATE_ACCELERATION_STATE_V1"),
                x.scopeHash,
                item,
                IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId),
                uint256(0),
                p.expectedDesignationRecordHash,
                directive,
                p.selectedCoverageHash,
                coverage.envelopeHash,
                uint32(0)
            )
        );
        x.newValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ESTATE_ACCELERATION_INTENT_V1"),
                x.scopeHash,
                x.oldValueHash,
                execution,
                uint32(0)
            )
        );
        x.evidenceHash = p.evidenceHash;
        _estateExactOwnerBytes(
            abi.encodeCall(
                IStreamArtistEstateOwner.estateExecutionFacts, (execution, coverage.envelopeHash)
            ),
            abi.encode(uint32(0), x)
        );
        (bool ok, bytes memory raw) = suite.owners[2].staticcall(
            abi.encodeCall(IStreamArtistEstateOwner.currentAuthorityCapabilities, (absent))
        );
        require(
            !ok
                && keccak256(raw)
                    == keccak256(abi.encodeWithSelector(T.InvalidIdentity.selector, absent)),
            "encoded getter preserves exact unknown-identity error"
        );
    }

    function testEstateEarlyContestAndDismissalAbandonThreeCandidatesAndRestoreSuccessorProgress()
        public
    {
        _accept();
        _payout();
        _selfGuardian();
        OfficialSafe retired = artist;
        uint256[] memory retiredKeys = keys;
        bytes32 priorDocument = ingress.operativeIdentityRecord(artistId);
        (address priorPayout, bytes32 priorPayoutRecord) = ingress.artistPayoutAccount(artistId);
        (,,, bytes32 priorGuardian) = ingress.guardianSet(artistId);
        Estate.Execution memory p = _estateActivateAndAdopt(4095);
        R.TransitionState memory transition =
            ingress.artistTransitionState(p.expectedActivationRecordHash);
        bytes32 document = _reviseDocument(bytes("provisional successor document"));
        bytes32 payout = _dismissalPayout(address(0xACCA));
        address[] memory none = new address[](0);
        bytes32 guardian = _guardianRecord(none, 0, 0, nextNonce);
        require(
            ingress.identityRevisionProvisionalAssociation(document).transitionRecordHash
                    == p.expectedActivationRecordHash
                && ingress.payoutDesignationProvisionalAssociation(payout).transitionRecordHash
                    == p.expectedActivationRecordHash
                && ingress.guardianSetRecord(guardian).provisional.transitionRecordHash
                    == p.expectedActivationRecordHash,
            "all three candidates bind actual estate cohort"
        );
        require(
            ingress.operativeIdentityRecord(artistId) == priorDocument,
            "candidate document is not yet operative"
        );
        vm.warp(transition.postWindowEndsAt - 1);
        require(
            executeSafe(
                retired,
                retiredKeys,
                address(ingress),
                0,
                _contestData(p.expectedActivationRecordHash),
                0
            ),
            "actual retired guardian contests executed estate"
        );
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.authorityClass == 3 && cause.facts.priorStatus == 3
                && cause.facts.executedTransitionHash == p.expectedActivationRecordHash,
            "contest captures truthful successor incumbent and estate cohort"
        );
        _dismissalExecute(_dismissalRequest(), 1, 0);
        require(
            ingress.currentAuthorityCapabilities(artistId).authorityClass == 3
                && ingress.currentAuthorityCapabilities(artistId).status == 3,
            "governed dismissal restores actual successor status"
        );
        R.TransitionState memory closed =
            ingress.artistTransitionState(p.expectedActivationRecordHash);
        vm.warp(transition.postWindowEndsAt + 1);
        (address selected, bytes32 selectedRecord) = ingress.artistPayoutAccount(artistId);
        (,,, bytes32 selectedGuardian) = ingress.guardianSet(artistId);
        require(
            ingress.operativeIdentityRecord(artistId) == priorDocument && selected == priorPayout
                && selectedRecord == priorPayoutRecord && selectedGuardian == priorGuardian,
            "dismissal never matures invalid estate candidates after original deadline"
        );
        require(
            keccak256(abi.encode(closed))
                == keccak256(
                    abi.encode(ingress.artistTransitionState(p.expectedActivationRecordHash))
                ),
            "actual closed estate facts remain immutable"
        );
        bytes32 replacement = _reviseDocument(bytes("fresh successor continuation"));
        bytes32 newPayout = _dismissalPayout(address(0xACCB));
        bytes32 newGuardian = _guardianRecord(none, 0, 0, nextNonce);
        require(
            ingress.identityRevisionProvisionalAssociation(replacement).transitionRecordHash == 0
                && ingress.payoutDesignationProvisionalAssociation(newPayout).transitionRecordHash
                    == 0
                && ingress.guardianSetRecord(newGuardian).provisional.transitionRecordHash == 0,
            "fresh revision continuation payout detachment and guardian write are stable"
        );
    }

    function _scopePayload(uint8 scope, uint256 id, bytes32 profile, bool frozen_)
        private
        view
        returns (T.EconomicsConsent memory p, T.FixedEconomicsCandidate memory candidate)
    {
        T.AssignmentFact memory fact =
            primary.previewArtistPrimaryAssignmentForScope(1, scope, id, profile, 0, frozen_);
        p = T.EconomicsConsent(1, address(primary), PRIMARY, scope, id, fact.assignmentHash);
        candidate = T.FixedEconomicsCandidate(profile, 0, 0, frozen_);
    }

    function _scopeRecord(T.EconomicsConsent memory p) private returns (bytes32 record) {
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
        _artistCall(abi.encodeCall(IStreamArtistOnboarding.recordEconomicsConsent, (p, a)));
        T.Binding memory b = coordinator.reads().acceptedBinding(p.collectionId);
        return IStreamArtistEconomicsEvidence(suite.owners[6])
            .economicsRecordForBinding(p, b.artistId, b.generation, b.bindingHash);
    }

    function _clearPrimary(uint8 scope, uint256 id) private {
        T.EconomicsConsent memory p = T.EconomicsConsent(1, address(primary), PRIMARY, scope, id, 0);
        _prospectiveConsent(p, T.FixedEconomicsCandidate(0, 0, 0, false));
        vm.prank(primary.owner());
        primary.clearPrimaryAssignment(PRIMARY, scope, id);
    }

    function testPrimaryTokenConsentActualSafeInstallFreezeAndImmutableAssociation() public {
        directArtistCalls = true;
        _accept();
        _payout();
        core.setTokenCollection(41, 1);
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory collection =
            primary.resolvePrimaryAssignment(1, 0, PRIMARY);
        (T.EconomicsConsent memory p, T.FixedEconomicsCandidate memory candidate) =
            _scopePayload(2, 41, collection.profileId, false);
        address governance = primary.owner();
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("economics"))
        );
        vm.prank(governance);
        primary.setPrimaryProfileAssignment(PRIMARY, 2, 41, collection.profileId, 0);
        _prospectiveConsent(p, candidate);
        vm.prank(primary.owner());
        bytes32 installed =
            primary.setPrimaryProfileAssignment(PRIMARY, 2, 41, collection.profileId, 0);
        require(
            installed == p.assignmentHash
                && primary.resolvePrimaryAssignment(0, 41, PRIMARY).assignmentHash == installed,
            "actual mapped token and Safe consent"
        );
        T.Binding memory b = coordinator.reads().acceptedBinding(1);
        IStreamArtistEconomicsEvidence owner = IStreamArtistEconomicsEvidence(suite.owners[6]);
        bytes32 record = owner.economicsRecordForBinding(p, b.artistId, b.generation, b.bindingHash);
        IStreamArtistEconomicsEvidence.Association memory association =
            owner.economicsRecordAssociation(record);
        require(
            record != 0 && association.originalRecord == record
                && association.payloadHash == keccak256(abi.encode(p)),
            "first immutable association"
        );
        this.executeTargetSafe(
            suite.owners[6],
            abi.encodeCall(
                IStreamArtistEconomicsEvidence.economicsRecordForBinding,
                (p, b.artistId, b.generation, b.bindingHash)
            )
        );
        this.executeTargetSafe(
            suite.owners[6],
            abi.encodeCall(IStreamArtistEconomicsEvidence.economicsRecordAssociation, (record))
        );
        (p, candidate) = _scopePayload(2, 41, collection.profileId, true);
        _prospectiveConsent(p, candidate);
        vm.prank(primary.owner());
        require(
            primary.freezePrimaryAssignment(PRIMARY, 2, 41) == p.assignmentHash,
            "exact token freeze hash"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.PrimaryAssignmentFrozen.selector,
                PRIMARY,
                uint8(2),
                uint256(41)
            )
        );
        primary.previewArtistPrimaryClear(1, 2, 41);
        require(
            primary.resolvePrimaryAssignment(1, 41, PRIMARY).frozen, "frozen token remains selected"
        );
    }

    function testPrimaryTokenClearZeroDoesNotConsentInheritedCollectionAndCanBeReused() public {
        _accept();
        _payout();
        core.setTokenCollection(41, 1);
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory collection =
            primary.resolvePrimaryAssignment(1, 0, PRIMARY);
        (T.EconomicsConsent memory p, T.FixedEconomicsCandidate memory candidate) =
            _scopePayload(2, 41, collection.profileId, false);
        _prospectiveConsent(p, candidate);
        vm.prank(primary.owner());
        primary.setPrimaryProfileAssignment(PRIMARY, 2, 41, collection.profileId, 0);
        _clearPrimary(2, 41);
        require(!primary.primaryEconomicsFacts(1, 2, 41).exists, "clear removes exact key only");
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("economics"))
        );
        primary.resolvePrimaryAssignment(1, 41, PRIMARY);
        _scopeRecord(
            T.EconomicsConsent(1, address(primary), PRIMARY, 1, 1, collection.assignmentHash)
        );
        require(
            primary.resolvePrimaryAssignment(1, 41, PRIMARY).assignmentHash
                == collection.assignmentHash,
            "separate selected ancestor consent"
        );
        vm.prank(primary.owner());
        primary.setPrimaryProfileAssignment(PRIMARY, 2, 41, collection.profileId, 0);
        vm.prank(primary.owner());
        primary.clearPrimaryAssignment(PRIMARY, 2, 41);
        require(
            primary.resolvePrimaryAssignment(1, 41, PRIMARY).scope == 1,
            "same association clear authorization reusable"
        );
    }

    function testPrimaryDefaultConsentRestoresMintAndDoesNotSignOrAuthorizeAnotherCollection()
        public
    {
        _all();
        StreamArtistOnboardingReads reads = coordinator.reads();
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory collection =
            primary.resolvePrimaryAssignment(1, 0, PRIMARY);
        vm.prank(primary.owner());
        primary.setPrimaryProfileAssignment(PRIMARY, 0, 0, collection.profileId, 0);
        _clearPrimary(1, 1);
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("economics"))
        );
        ingress.requireMintConsent(1, PHASE, POLICY);
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory current =
            primary.primaryEconomicsFacts(1, 0, 0);
        T.EconomicsConsent memory p =
            T.EconomicsConsent(1, address(primary), PRIMARY, 0, 0, current.assignmentHash);
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.economicsConsentDigest(p, a);
        a.signature = _signature(digest);
        ingress.recordEconomicsConsent(p, a);
        ingress.requireMintConsent(1, PHASE, POLICY);
        ingress.proposeArtistBinding(
            2, _proposal(artistId), bytes("unit identity document"), "Artist Safe"
        );
        T.Authorization memory acceptance = _authorization(false);
        acceptance.signature = _signature(ingress.acceptanceDigest(2, acceptance));
        ingress.acceptArtistBinding(2, acceptance);
        p.collectionId = 2;
        require(
            ingress.economicsConsentDigest(p, a) == digest,
            "default collection admission is not signed"
        );
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("economics"))
        );
        reads.requireEconomicsConsent(p);
        avm.expectPartialRevert(T.Replay.selector);
        ingress.recordEconomicsConsent(p, a);
        _scopeRecord(p);
        reads.requireEconomicsConsent(p);
    }

    function _economicsReplayKey(bytes32 scope) private view returns (bytes32) {
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
    function _correctEconomicsBinding(address payout) private returns (T.Binding memory b) {
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

    function _mockEconomicsBinding(T.Binding memory b) private {
        avm.mockCall(
            suite.owners[0], abi.encodeCall(IStreamArtistBindingOwner.binding, (1)), abi.encode(b)
        );
        avm.mockCall(
            suite.owners[4],
            abi.encodeCall(IStreamArtistAttributionOwner.attributionState, (1)),
            abi.encode(uint8(2), b.generation)
        );
    }

    function testEconomicsAssociationCorrectedArtistSecondThirdGenerationAndExactReplay() public {
        _accept();
        _payout();
        StreamArtistOnboardingReads reads = coordinator.reads();
        T.EconomicsConsent memory p = _currentEconomics(address(primary));
        T.Binding memory firstBinding = coordinator.reads().acceptedBinding(1);
        bytes32 first = _scopeRecord(p);
        bytes32 firstKey = _economicsReplayKey(keccak256(abi.encode(p)));
        T.ReplayCell memory originalCell = IStreamArtistOwner(suite.owners[6]).replayCell(firstKey);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
        vm.expectRevert(abi.encodeWithSelector(T.Replay.selector, firstKey));
        ingress.recordEconomicsConsent(p, a);
        T.Binding memory b = _correctEconomicsBinding(address(artist));
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("economics"))
        );
        reads.requireEconomicsConsent(p);
        bytes32 second = _scopeRecord(p);
        require(second != first, "new artist fresh canonical record");
        reads.requireEconomicsConsent(p);
        bytes32 secondScope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ECONOMICS_BINDING_CONTINUATION_V1"),
                first,
                p,
                b.artistId,
                b.generation,
                b.bindingHash
            )
        );
        bytes32 secondKey = _economicsReplayKey(secondScope);
        a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
        vm.expectRevert(abi.encodeWithSelector(T.Replay.selector, secondKey));
        ingress.recordEconomicsConsent(p, a);
        IStreamArtistEconomicsEvidence owner = IStreamArtistEconomicsEvidence(suite.owners[6]);
        require(
            owner.economicsRecordForBinding(
                p, firstBinding.artistId, firstBinding.generation, firstBinding.bindingHash
            ) == first,
            "historical first lookup"
        );
        require(
            owner.economicsRecordForBinding(p, b.artistId, b.generation, firstBinding.bindingHash)
                == 0,
            "wrong binding hash absent"
        );
        require(
            owner.economicsRecordForBinding(p, firstBinding.artistId, b.generation, b.bindingHash)
                    == 0
                && owner.economicsRecordForBinding(p, b.artistId, b.generation + 1, b.bindingHash)
                == 0,
            "wrong artist and generation cannot select current consent"
        );
        b.generation = 3;
        b.bindingHash = keccak256("corrected binding generation 3");
        _mockEconomicsBinding(b);
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("economics"))
        );
        reads.requireEconomicsConsent(p);
        bytes32 third = _scopeRecord(p);
        require(
            third != second && owner.economicsRecordAssociation(third).originalRecord == first,
            "third generation anchors first record"
        );
        require(
            IStreamArtistConsentOwner(suite.owners[6]).economicsRecord(p) == first,
            "raw first immutable"
        );
        require(
            keccak256(abi.encode(IStreamArtistOwner(suite.owners[6]).replayCell(firstKey)))
                == keccak256(abi.encode(originalCell)),
            "original consumed cell immutable"
        );
        require(
            IStreamArtistOwner(suite.owners[6]).replayCell(secondKey).commitment == second,
            "second continuation retained"
        );
        reads.requireEconomicsConsent(p);
    }

    function _associationEvent(
        Vm.Log[] memory logs,
        bytes32 record,
        T.EconomicsConsent memory p,
        T.Binding memory b,
        bytes32 original
    ) private view {
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

    function testEconomicsAssociationLateArchiveActualSafeRollbackAndExactEvidenceRetry() public {
        _accept();
        _payout();
        T.EconomicsConsent memory p = _currentEconomics(address(primary));
        T.Binding memory firstBinding = coordinator.reads().acceptedBinding(1);
        vm.recordLogs();
        bytes32 first = _scopeRecord(p);
        _associationEvent(vm.getRecordedLogs(), first, p, firstBinding, first);
        T.Binding memory b = _correctEconomicsBinding(address(artist));
        T.Authorization memory a = _authorization(false);
        a.signature = "";
        bytes memory data = abi.encodeCall(IStreamArtistOnboarding.recordEconomicsConsent, (p, a));
        bytes32 roots = _roots();
        uint256 safeNonce = artist.nonce();
        IStreamArtistEconomicsEvidence owner = IStreamArtistEconomicsEvidence(suite.owners[6]);
        avm.mockCallRevert(
            address(archive),
            abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(T.InvalidRecord.selector)
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(address(ingress), data);
        require(
            _roots() == roots && artist.nonce() == safeNonce
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce)
                && owner.economicsRecordForBinding(p, b.artistId, b.generation, b.bindingHash) == 0
                && IStreamArtistConsentOwner(suite.owners[6]).economicsRecord(p) == first,
            "late rollback includes Safe, both owners, association and immutable raw record"
        );
        avm.clearMockedCalls();
        _mockEconomicsBinding(b);
        vm.recordLogs();
        this.executeTargetSafe(address(ingress), data);
        bytes32 record = owner.economicsRecordForBinding(p, b.artistId, b.generation, b.bindingHash);
        _associationEvent(vm.getRecordedLogs(), record, p, b, first);
        require(record != 0 && artist.nonce() == safeNonce + 1, "same direct Safe action retry");
        bytes32 evidenceId = keccak256(
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
            archive.artistEvidenceBytesV2(evidenceId, 1),
            (uint16, bytes32, uint16, address, bytes32, T.Snapshot[7], T.Snapshot[7], bytes)
        );
        (
            T.Binding memory captured,
            T.EconomicsConsent memory terms,
            T.Payout memory payout,
            T.Authorization memory authorization,
            T.SignerApproval memory proof,
            bytes memory candidate,
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
                && proof.signer == address(artist) && candidate.length == 0
                && association.originalRecord == first && association.bindingHash == b.bindingHash
                && association.payloadHash == keccak256(abi.encode(p)),
            "exact archived association and one owner commit"
        );
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
    ) private view returns (bytes32) {
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

    function testPrimaryAssignmentHashLinkedReadExactLiteralPreimagesAndFailureControl() public {
        core.setTokenCollection(41, 1);
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory current =
            primary.resolvePrimaryAssignment(1, 0, PRIMARY);
        require(
            current.assignmentHash
                == _literalPrimaryHash(1, 1, 1, current.profileId, 0, 0, 0, false),
            "old collection preimage"
        );
        for (uint8 scope; scope < 3; ++scope) {
            uint256 id = scope == 0 ? 0 : scope == 1 ? 1 : 41;
            T.AssignmentFact memory preview = primary.previewArtistPrimaryAssignmentForScope(
                1, scope, id, current.profileId, 0, true
            );
            require(
                preview.assignmentHash
                    == _literalPrimaryHash(scope, id, 1, current.profileId, 0, 0, 0, true),
                "every scoped fixed hash and provider context"
            );
        }
        avm.mockCallRevert(
            address(factory),
            abi.encodeCall(IStreamSplitFactory.profileEntriesHash, (current.profileId)),
            abi.encodeWithSelector(T.InvalidRecord.selector)
        );
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        primary.previewArtistPrimaryAssignmentForScope(1, 2, 41, current.profileId, 0, false);
        avm.clearMockedCalls();
        require(
            primary.previewArtistPrimaryAssignmentForScope(1, 2, 41, current.profileId, 0, false)
            .assignmentHash == _literalPrimaryHash(2, 41, 1, current.profileId, 0, 0, 0, false),
            "same immutable factory read healthy retry"
        );
        _freshTemplateFixture(1);
        current = primary.resolvePrimaryAssignment(1, 0, PRIMARY);
        (bytes32 entries, bytes32 metadataHash,) =
            primary.primaryTemplateEconomicsFacts(current.templateId);
        require(
            current.assignmentHash
                == _literalPrimaryHash(
                    1, 1, 2, 0, current.templateId, entries, metadataHash, false
                ),
            "old template preimage and zero profile branch"
        );
    }

    function testPrimaryClearRequiresExactZeroCandidateAndExistingMutableKey() public {
        _accept();
        _payout();
        core.setTokenCollection(41, 1);
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory installed =
            primary.resolvePrimaryAssignment(1, 0, PRIMARY);
        T.EconomicsConsent memory p = T.EconomicsConsent(1, address(primary), PRIMARY, 1, 1, 0);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
        T.FixedEconomicsCandidate memory candidate =
            T.FixedEconomicsCandidate(installed.profileId, 0, 0, false);
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(T.UnsupportedProfile.selector));
        ingress.recordProspectiveEconomicsConsent(p, candidate, a);
        candidate.profileHash = 0;
        candidate.frozen = true;
        vm.expectRevert(abi.encodeWithSelector(T.UnsupportedProfile.selector));
        ingress.recordProspectiveEconomicsConsent(p, candidate, a);
        candidate.frozen = false;
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        ingress.recordEconomicsConsent(p, a);
        require(
            _roots() == roots
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "zero only prospective and malformed controls do not consume"
        );
        ingress.recordProspectiveEconomicsConsent(p, candidate, a);
        vm.prank(primary.owner());
        primary.clearPrimaryAssignment(PRIMARY, 1, 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.PrimaryAssignmentMissing.selector,
                PRIMARY,
                uint8(1),
                uint256(1)
            )
        );
        primary.previewArtistPrimaryClear(1, 1, 1);
    }

    function testEconomicsAssociationTokenConsumptionSurvivesPayoutRotationAndZeroCapEstate()
        public
    {
        _all();
        core.setTokenCollection(41, 1);
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory collection =
            primary.resolvePrimaryAssignment(1, 0, PRIMARY);
        (T.EconomicsConsent memory p, T.FixedEconomicsCandidate memory candidate) =
            _scopePayload(2, 41, collection.profileId, false);
        _prospectiveConsent(p, candidate);
        vm.prank(primary.owner());
        primary.setPrimaryProfileAssignment(PRIMARY, 2, 41, collection.profileId, 0);
        T.Binding memory b = coordinator.reads().acceptedBinding(1);
        IStreamArtistEconomicsEvidence owner = IStreamArtistEconomicsEvidence(suite.owners[6]);
        bytes32 record = owner.economicsRecordForBinding(p, b.artistId, b.generation, b.bindingHash);
        bytes32 evidence = keccak256(abi.encode(owner.economicsRecordAssociation(record)));
        _newRotationSafe(24481);
        bytes32 rotation = _stageRotation(0);
        _executeTimedRotation(rotation);
        _adoptRotatedSafe();
        coordinator.reads().requireEconomicsConsent(p);
        require(
            primary.resolvePrimaryAssignment(1, 41, PRIMARY).assignmentHash == p.assignmentHash,
            "rotation preserves selected token consent"
        );
        R.TransitionState memory transition = ingress.artistTransitionState(rotation);
        vm.warp(transition.postWindowEndsAt);
        (, bytes32 previous) = ingress.artistPayoutAccount(artistId);
        T.PayoutDesignation memory update = T.PayoutDesignation(artistId, address(0xCAFE), previous);
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.payoutDesignationDigest(update, a));
        ingress.recordPayoutDesignation(update, a);
        coordinator.reads().requireEconomicsConsent(p);
        require(
            primary.resolvePrimaryAssignment(1, 41, PRIMARY).profileId == collection.profileId,
            "fixed old payout profile rights remain immutable"
        );
        _estateActivateAndAdopt(0);
        Estate.AuthorityCapabilities memory rights = ingress.currentAuthorityCapabilities(artistId);
        require(
            rights.authorityClass == 3 && rights.status == 3 && rights.effectiveCapabilities == 0,
            "real zero-cap successor"
        );
        coordinator.reads().requireEconomicsConsent(p);
        require(
            primary.resolvePrimaryAssignment(1, 41, PRIMARY).assignmentHash == p.assignmentHash,
            "consumption of existing token consent needs no new capability"
        );
        ingress.requireMintConsent(1, PHASE, POLICY);
        require(
            owner.economicsRecordForBinding(p, b.artistId, b.generation, b.bindingHash) == record
                && keccak256(abi.encode(owner.economicsRecordAssociation(record))) == evidence
                && keccak256(abi.encode(coordinator.reads().acceptedBinding(1)))
                    == keccak256(abi.encode(b)),
            "binding and immutable evidence survive all three authority/payout changes"
        );
    }

    /// @dev Explicit missing-evidence storage fault, not a live migration/upgrade path.
    ///      Mapping slot16 is pinned by the separate recursive layout proof; old raw slot5/replay stay intact.
    function testEconomicsAssociationMissingLegacyEvidenceFailsClosedThenExactRestoreRetry()
        public
    {
        _accept();
        _payout();
        T.EconomicsConsent memory p = _currentEconomics(address(primary));
        bytes32 first = _scopeRecord(p);
        bytes32 key = _economicsReplayKey(keccak256(abi.encode(p)));
        bytes32 oldCell = keccak256(abi.encode(IStreamArtistOwner(suite.owners[6]).replayCell(key)));
        bytes32 slot = keccak256(abi.encode(first, uint256(16)));
        bytes32[5] memory words;
        for (uint256 i; i < 5; ++i) {
            words[i] = vm.load(suite.owners[6], bytes32(uint256(slot) + i));
            vm.store(suite.owners[6], bytes32(uint256(slot) + i), 0);
        }
        require(
            words[0] == artistId && words[3] == keccak256(abi.encode(p)) && words[4] == first,
            "exact tested association storage roots"
        );
        T.Binding memory b = _correctEconomicsBinding(address(artist));
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        ingress.recordEconomicsConsent(p, a);
        require(
            _roots() == roots
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce)
                && IStreamArtistConsentOwner(suite.owners[6]).economicsRecord(p) == first,
            "unknown old evidence cannot be guessed and does not consume new authorization"
        );
        for (uint256 i; i < 5; ++i) {
            vm.store(suite.owners[6], bytes32(uint256(slot) + i), words[i]);
        }
        bytes32 fresh = ingress.recordEconomicsConsent(p, a);
        require(
            fresh != 0
                && IStreamArtistEconomicsEvidence(suite.owners[6])
                    .economicsRecordForBinding(p, b.artistId, b.generation, b.bindingHash) == fresh
                && keccak256(abi.encode(IStreamArtistOwner(suite.owners[6]).replayCell(key)))
                    == oldCell,
            "same proof healthy retry with original replay bytes preserved"
        );
    }

    function _economicsSafeRead(address target, bytes memory data, bytes memory expected) private {
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

    function testEconomicsPreparationReadsActualSafeParityAndInvalidInputRejection() public {
        _accept();
        _payout();
        StreamArtistOnboardingReads reads = coordinator.reads();
        T.EconomicsConsent memory p = _currentEconomics(address(primary));
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory installed =
            primary.primaryEconomicsFacts(1, 1, 1);
        T.FixedEconomicsCandidate memory candidate =
            T.FixedEconomicsCandidate(installed.profileId, 0, 0, false);
        T.AssignmentFact memory fact =
            T.AssignmentFact(p.resolver, p.revenueClass, p.scope, p.scopeId, p.assignmentHash);
        bytes memory currentCall = abi.encodeCall(
            StreamArtistOnboardingReads.requireCurrentEconomics, (p, address(artist))
        );
        bytes memory prospectiveCall = abi.encodeCall(
            StreamArtistOnboardingReads.requireProspectiveEconomicsWithEvidence,
            (p, candidate, address(artist))
        );
        _economicsSafeRead(address(reads), currentCall, abi.encode(bytes("")));
        _economicsSafeRead(address(reads), prospectiveCall, abi.encode(fact, bytes32(0)));
        require(
            IStreamArtistConsentOwner(suite.owners[6]).economicsRecord(p) == 0,
            "read preparation is not consent authority"
        );
        bytes32 goodHash = p.assignmentHash;
        p.assignmentHash = keccak256("wrong current assignment");
        bytes memory bad = abi.encodeCall(
            StreamArtistOnboardingReads.requireCurrentEconomics, (p, address(artist))
        );
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        reads.requireCurrentEconomics(p, address(artist));
        uint256 safeNonce = artist.nonce();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(address(reads), bad);
        require(artist.nonce() == safeNonce, "invalid current read rolls Safe envelope back");
        p.assignmentHash = goodHash;
        candidate.profileHash = 0;
        bad = abi.encodeCall(
            StreamArtistOnboardingReads.requireProspectiveEconomicsWithEvidence,
            (p, candidate, address(artist))
        );
        vm.expectRevert(abi.encodeWithSelector(T.UnsupportedProfile.selector));
        reads.requireProspectiveEconomicsWithEvidence(p, candidate, address(artist));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(address(reads), bad);
        require(artist.nonce() == safeNonce, "invalid prospective read rolls Safe envelope back");
        _economicsSafeRead(address(reads), currentCall, abi.encode(bytes("")));
        _economicsSafeRead(address(reads), prospectiveCall, abi.encode(fact, bytes32(0)));
    }

    function testPrimaryClearMissingPaidCollaboratorDesignationSameAuthorizationRetry() public {
        _collaboratorIdentity(false);
        C.BindingAcceptance memory row = _collaborativeProposal(true);
        _accept();
        _collaboratorAcceptance(row, false);
        _payout();
        bytes32 installed = primary.primaryEconomicsFacts(1, 1, 1).assignmentHash;
        T.EconomicsConsent memory p = T.EconomicsConsent(1, address(primary), PRIMARY, 1, 1, 0);
        T.FixedEconomicsCandidate memory candidate = T.FixedEconomicsCandidate(0, 0, 0, false);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
        bytes memory call_ = abi.encodeCall(
            IStreamArtistEconomicsAuthority.recordProspectiveEconomicsConsent, (p, candidate, a)
        );
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(
                T.MissingMintPrerequisite.selector, keccak256("collaborator_payout")
            )
        );
        ingress.recordProspectiveEconomicsConsent(p, candidate, a);
        require(
            _roots() == roots
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce)
                && primary.primaryEconomicsFacts(1, 1, 1).assignmentHash == installed,
            "missing collaborator leaves authorization and exact key untouched"
        );
        _collaboratorPayout(address(delegateSafe));
        this.executeTargetSafe(address(ingress), call_);
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce)
                && IStreamArtistConsentOwner(suite.owners[6]).economicsRecord(p) != 0,
            "same artist authorization succeeds after actual collaborator designation"
        );
        vm.prank(primary.owner());
        primary.clearPrimaryAssignment(PRIMARY, 1, 1);
        require(
            !primary.primaryEconomicsFacts(1, 1, 1).exists, "actual independently authorized clear"
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
        _deployEstateArchival(address(core), governance);
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
        coordinator = new StreamArtistOnboardingCoordinator(suite);
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
        p.saleConsentScope = saleScopeFixture;
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

    function _assertDismissalCauseEvent(Vm.Log[] memory logs, Dismissal.Cause memory cause)
        private
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

    function _dismissalRequest() private view returns (Dismissal.Request memory) {
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
        private
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

    function _dismissalPayout(address account) private returns (bytes32 record) {
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

    function _dismissalGuardianCause() private {
        _selfGuardian();
        require(
            executeSafe(artist, keys, address(ingress), 0, _contestData(0), 0),
            "actual Safe files cause"
        );
    }

    function testDismissalExactCauseRecordReplayEventAndSoleIdentityCommit() public {
        vm.recordLogs();
        _dismissalGuardianCause();
        Vm.Log[] memory causeLogs = vm.getRecordedLogs();
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        _assertDismissalCauseEvent(causeLogs, cause);
        require(
            cause.causeHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1"),
                        block.chainid,
                        address(ingress),
                        suite.owners[2],
                        cause.facts
                    )
                ),
            "independent cause commitment"
        );
        require(
            cause.facts.kind == 1
                && cause.facts.referenceHash == ingress.latestIdentityContest(artistId)
                && cause.facts.actor == address(artist) && cause.facts.incumbent == address(artist)
                && cause.facts.priorStatus == 1 && cause.facts.authorityClass == 1,
            "actual filing facts"
        );
        T.Identity memory before_ = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        bytes32 otherRoots = _otherOwnerRoots();
        T.Snapshot memory snapshot_ = IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2();
        Dismissal.Request memory p = _dismissalRequest();
        vm.recordLogs();
        bytes32 record = _dismissalExecute(p, 1, 0);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Dismissal.Record memory item = ingress.identityContestDismissalRecord(record);
        (
            ,
            Contest.GovernanceWitness memory g,
            Dismissal.Cause memory archivedCause,
            Dismissal.Context memory x,
            Dismissal.Record memory archived
        ) = abi.decode(
            _operationPayload(58, manager.governanceAuthority(), record),
            (
                Dismissal.Request,
                Contest.GovernanceWitness,
                Dismissal.Cause,
                Dismissal.Context,
                Dismissal.Record
            )
        );
        require(
            keccak256(abi.encode(archivedCause)) == keccak256(abi.encode(cause))
                && keccak256(abi.encode(archived)) == keccak256(abi.encode(item)),
            "exact archive cause and result"
        );
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_IDENTITY_DISMISSAL_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        suite.owners[2],
                        p,
                        manager.governanceAuthority(),
                        g.proposer,
                        g.actionClass,
                        g.actionId,
                        item.incumbent,
                        item.authorityClass,
                        item.restoredStatus,
                        item.dismissedAt,
                        item.cohortHash,
                        keccak256(abi.encode(g))
                    )
                ),
            "independent primary record"
        );
        require(
            x.scopeHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_IDENTITY_DISMISSAL_SCOPE_V1"),
                        block.chainid,
                        address(ingress),
                        suite.owners[2],
                        artistId
                    )
                ),
            "independent scope"
        );
        uint256 events;
        bytes32 topic = keccak256(
            "ArtistIdentityContestDismissed(uint16,bytes32,bytes32,bytes32,bytes32,address,address,uint8,bytes32,address,uint8,uint8,bytes32,bytes32,bool,bytes32,uint64,bytes32,bytes32,bytes32)"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == suite.owners[2] && logs[i].topics[0] == topic) {
                ++events;
                require(
                    logs[i].topics.length == 4 && logs[i].topics[1] == artistId
                        && logs[i].topics[2] == cause.causeHash && logs[i].topics[3] == record,
                    "Identity emitter and indexed fields"
                );
                require(
                    keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                p.expectedResolutionHash,
                                item.executor,
                                item.proposer,
                                item.actionClass,
                                item.actionId,
                                item.incumbent,
                                item.authorityClass,
                                item.restoredStatus,
                                p.evidenceHash,
                                p.reasonHash,
                                p.removePriorStanding,
                                p.expectedRetirementHash,
                                item.dismissedAt,
                                item.cohortHash,
                                item.governanceWitnessHash,
                                item.revisionContinuationHead
                            )
                        ),
                    "exact event reconstruction"
                );
            }
        }
        require(events == 1, "exactly one dismissal event");
        T.Identity memory after_ = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        require(after_.status == 1, "restored active");
        after_.status = before_.status;
        require(
            keccak256(abi.encode(after_)) == keccak256(abi.encode(before_))
                && _otherOwnerRoots() == otherRoots,
            "no nonce, liveness or other owner mutation"
        );
        T.Snapshot memory afterSnapshot = IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2();
        require(afterSnapshot.revision == snapshot_.revision + 1, "one semantic owner commit");
        bytes32 key = _identityRevisionReplayKey(
            keccak256("identity_authority.replay.contest_resolution"),
            keccak256(abi.encode(artistId, cause.causeHash))
        );
        T.ReplayCell memory cell = IStreamArtistOwner(suite.owners[2]).replayCell(key);
        require(
            cell.commitment == record && cell.status == 2 && cell.kind == 1,
            "exact consumed cause replay"
        );
        vm.expectRevert(abi.encodeWithSelector(Dismissal.InvalidDismissal.selector, artistId));
        ingress.identityContestDismissalContext(p);
    }

    function testDismissalGovernanceFaultsAndBothAllowedClassesHaveSameContextControls() public {
        _dismissalGuardianCause();
        Dismissal.Request memory p = _dismissalRequest();
        bytes32 roots = _roots();
        for (uint8 fault = 1; fault <= 6; ++fault) {
            uint256 point = vm.snapshotState();
            if (fault == 6) {
                vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(artist)));
            } else {
                vm.expectRevert(abi.encodeWithSelector(Contest.InvalidContestGovernance.selector));
            }
            this.executeGovernedDismissal(p, 1, fault);
            require(
                _roots() == roots && ingress.latestIdentityContestDismissal(artistId) == 0,
                "fault atomic"
            );
            require(_dismissalExecute(p, 1, 0) != 0, "same request restored success");
            require(vm.revertToState(point), "restore");
        }
        for (uint8 class_; class_ < 4; class_ += 3) {
            vm.expectRevert(abi.encodeWithSelector(Contest.InvalidContestGovernance.selector));
            this.executeGovernedDismissal(p, class_, 0);
        }
        bytes32 record = _dismissalExecute(p, 2, 0);
        require(
            ingress.identityContestDismissalRecord(record).actionClass == 2,
            "terminal class accepted"
        );
    }

    function testDismissalMalformedGovernanceReadCannotConsumeCause() public {
        _dismissalGuardianCause();
        Dismissal.Request memory p = _dismissalRequest();
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(artist), p.reasonHash, "urn:unit"
        );
        bytes memory valid = abi.encode(authority.governanceAction(0));
        bytes32 roots = _roots();
        for (uint256 mode; mode < 5; ++mode) {
            uint256 point = vm.snapshotState();
            bytes memory bad = bytes.concat(valid);
            if (mode == 0) bad = new bytes(639);
            if (mode == 1) assembly ("memory-safe") { mstore(add(bad, 32), 64) }
            if (mode == 2) assembly ("memory-safe") { mstore(add(bad, 640), not(0)) }
            if (mode == 3) assembly ("memory-safe") { mstore(add(bad, 416), not(0)) }
            if (mode == 4) bad = bytes.concat(bad, bytes32(0));
            avm.mockCall(
                address(authority),
                abi.encodeWithSelector(IStreamGovernanceReads.governanceAction.selector),
                bad
            );
            vm.expectRevert(abi.encodeWithSelector(Contest.InvalidContestGovernance.selector));
            this.executeGovernedDismissal(p, 1, 0);
            require(_roots() == roots, "malformed read atomic");
            avm.clearMockedCalls();
            require(_dismissalExecute(p, 1, 0) != 0, "same context positive");
            require(vm.revertToState(point), "restore");
        }
    }

    function testDismissalActualSafeAllEightSelectorsAndProtocolCallbackBoundaries() public {
        _dismissalGuardianCause();
        Dismissal.Request memory p = _dismissalRequest();
        require(
            ingress.supportsInterface(type(IStreamArtistIdentityDismissal).interfaceId)
                && type(IStreamArtistIdentityDismissal).interfaceId == bytes4(0x6ddc41b6),
            "exact narrow capability"
        );
        this.executeArtistSafe(
            abi.encodeCall(IStreamArtistIdentityDismissal.currentIdentityContestCause, (artistId))
        );
        this.executeArtistSafe(
            abi.encodeCall(
                IStreamArtistIdentityDismissal.identityContestCause, (p.expectedCauseHash)
            )
        );
        this.executeArtistSafe(
            abi.encodeCall(IStreamArtistIdentityDismissal.identityContestDismissalContext, (p))
        );
        bytes memory data =
            abi.encodeCall(IStreamArtistIdentityDismissal.dismissArtistIdentityContest, (p));
        address identityWriter =
            StreamArtistIdentityAuthority(suite.owners[2]).identityWriterExtension();
        address registryWriter = ingress.registryWriterExtension();
        address registryReader = ingress.registryReadExtension();
        bytes32 roots = _roots();
        uint256 safeNonce = artist.nonce();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeArtistSafe(data);
        require(
            _roots() == roots && artist.nonce() == safeNonce, "Safe has no direct Executor role"
        );
        address ownerEOA = vm.addr(keys[0]);
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, ownerEOA));
        vm.prank(ownerEOA);
        ingress.dismissArtistIdentityContest(p);
        T.ActionContext memory c = T.ActionContext(
            58, address(artist), IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2()
        );
        Contest.GovernanceWitness memory g;
        bytes memory callback =
            abi.encodeCall(IStreamArtistIdentityDismissalOwner.dismissIdentityContest, (c, p, g));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(suite.owners[2], callback);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(identityWriter, callback);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(
            address(coordinator),
            abi.encodeCall(
                IStreamArtistIdentityDismissalCoordinator.coordinateDismissArtistIdentityContest,
                (address(artist), p)
            )
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(registryWriter, data);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(
            registryReader,
            abi.encodeCall(IStreamArtistIdentityDismissal.currentIdentityContestCause, (artistId))
        );
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        authority.configureContestReads(
            suite.roleRegistry, address(artist), p.reasonHash, "urn:unit"
        );
        Dismissal.Context memory x = ingress.identityContestDismissalContext(p);
        require(
            executeSafe(
                artist,
                keys,
                address(authority),
                0,
                abi.encodeCall(
                    ArtistUnitGovernance.executeModuleContext,
                    (address(ingress), data, uint8(1), x.scopeHash, x.oldValueHash, x.newValueHash)
                ),
                0
            ),
            "actual Safe calls qualified governance host"
        );
        bytes32 record = ingress.latestIdentityContestDismissal(artistId);
        this.executeArtistSafe(
            abi.encodeCall(
                IStreamArtistIdentityDismissal.latestIdentityContestDismissal, (artistId)
            )
        );
        this.executeArtistSafe(
            abi.encodeCall(IStreamArtistIdentityDismissal.identityContestDismissalRecord, (record))
        );
        this.executeArtistSafe(
            abi.encodeCall(
                IStreamArtistIdentityDismissal.identityTransitionClosure, (artistId, bytes32(0))
            )
        );
        this.executeArtistSafe(
            abi.encodeCall(
                IStreamArtistIdentityDismissal.identityRevisionContinuation, (bytes32(0))
            )
        );
    }

    function _dismissalReadParity(bytes memory data, bytes memory expected) private view {
        (bool hostOk, bytes memory hostData) = suite.owners[2].staticcall(data);
        (bool facadeOk, bytes memory facadeData) = address(ingress).staticcall(data);
        require(
            hostOk && facadeOk && keccak256(hostData) == keccak256(expected)
                && keccak256(facadeData) == keccak256(expected),
            "canonical exact returndata without bytes wrapper"
        );
    }

    function testDismissalStoredReadExtractionMatchesInlineEmptyAndMaximumDynamicBytes() public {
        ArtistIdentityInlineReadOracle inline_ = new ArtistIdentityInlineReadOracle();
        ArtistIdentityEncodedReadOracle encoded = new ArtistIdentityEncodedReadOracle();
        bytes4[4] memory selectors = [
            ArtistIdentityInlineReadOracle.identity.selector,
            ArtistIdentityInlineReadOracle.guardianSetRecord.selector,
            ArtistIdentityInlineReadOracle.rotationRecord.selector,
            ArtistIdentityInlineReadOracle.delegationRecord.selector
        ];
        for (uint256 populated; populated < 2; ++populated) {
            if (populated != 0) {
                T.Identity memory principal = T.Identity(
                    address(artist),
                    1,
                    1,
                    1000,
                    1100,
                    keccak256("independent document"),
                    string(new bytes(2048)),
                    string(new bytes(256)),
                    type(uint256).max
                );
                R.GuardianRecord memory guardian;
                guardian.recordHash = keccak256("guardian");
                guardian.terms = R.GuardianSet(artistId, new address[](32), 31, type(uint64).max);
                for (uint256 j; j < 32; ++j) {
                    guardian.terms.guardians[j] = address(uint160(j + 1));
                }
                guardian.nonce = type(uint256).max;
                R.RotationRecord memory rotation_;
                rotation_.recordHash = keccak256("rotation");
                rotation_.terms = R.Rotation(
                    artistId,
                    address(artist),
                    address(0x1234),
                    keccak256("reason"),
                    keccak256("prior")
                );
                rotation_.transition =
                    R.TransitionState(artistId, rotation_.recordHash, 1, 2, 3, 4, 5, 2);
                inline_.install(artistId, principal, guardian, rotation_);
                encoded.install(artistId, principal, guardian, rotation_);
            }
            for (uint256 i; i < 4; ++i) {
                bytes memory data = abi.encodeWithSelector(selectors[i], artistId);
                (bool okA, bytes memory a) = address(inline_).staticcall(data);
                (bool okB, bytes memory b) = address(encoded).staticcall(data);
                require(
                    okA && okB && a.length == b.length && keccak256(a) == keccak256(b),
                    "old inline and linked full returndata exact"
                );
            }
        }
    }

    event DismissalIdentityDeploymentProof(
        address indexed helper,
        bytes helperRuntime,
        address indexed identity,
        address indexed writer
    );

    function testDismissalIdentityDeploymentHelperRetainsCreatorAndDirectCallGuard() public {
        address helper = address(StreamArtistIdentityExtensionDeployment);
        address identity = suite.owners[2];
        address writer = StreamArtistIdentityAuthority(identity).identityWriterExtension();
        require(
            helper.code.length != 0 && helper.code.length <= 24576 && identity.code.length <= 24576
                && writer.code.length <= 24576,
            "actual deployed product limits"
        );
        require(
            writer == avm.computeCreateAddress(identity, 1),
            "Identity remains exact child creator nonce1"
        );
        emit DismissalIdentityDeploymentProof(helper, helper.code, identity, writer);
        bytes memory direct = abi.encodeWithSignature(
            "deployWriter(address,address,address,address,address)",
            address(ingress),
            address(coordinator),
            address(archive),
            address(core),
            address(manager)
        );
        uint256 beforeNonce = artist.nonce();
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(helper, direct);
        require(
            artist.nonce() == beforeNonce && _roots() == roots,
            "actual Safe direct library call cannot create another authority"
        );
    }

    function testDismissalLinkedReadsEmptyAndPopulatedExactStaticReturndataAndErrors() public {
        Dismissal.Cause memory emptyCause;
        Dismissal.Record memory emptyRecord;
        Dismissal.Closure memory emptyClosure;
        Dismissal.RevisionContinuation memory emptyContinuation;
        _dismissalReadParity(
            abi.encodeCall(IStreamArtistIdentityDismissal.currentIdentityContestCause, (artistId)),
            abi.encode(emptyCause)
        );
        _dismissalReadParity(
            abi.encodeCall(IStreamArtistIdentityDismissal.identityContestCause, (bytes32(0))),
            abi.encode(emptyCause)
        );
        _dismissalReadParity(
            abi.encodeCall(
                IStreamArtistIdentityDismissal.identityContestDismissalRecord, (bytes32(0))
            ),
            abi.encode(emptyRecord)
        );
        _dismissalReadParity(
            abi.encodeCall(
                IStreamArtistIdentityDismissal.latestIdentityContestDismissal, (artistId)
            ),
            abi.encode(bytes32(0))
        );
        _dismissalReadParity(
            abi.encodeCall(
                IStreamArtistIdentityDismissal.identityTransitionClosure, (artistId, bytes32(0))
            ),
            abi.encode(emptyClosure)
        );
        _dismissalReadParity(
            abi.encodeCall(
                IStreamArtistIdentityDismissal.identityRevisionContinuation, (bytes32(0))
            ),
            abi.encode(emptyContinuation)
        );
        DismissalCohortFixture memory f = _dismissalCohort(0);
        Dismissal.Request memory p = _dismissalRequest();
        Dismissal.Context memory context_ = ingress.identityContestDismissalContext(p);
        _dismissalReadParity(
            abi.encodeCall(IStreamArtistIdentityDismissal.identityContestDismissalContext, (p)),
            abi.encode(context_)
        );
        bytes32 record = _dismissalExecute(p, 1, 0);
        (
            ,,
            Dismissal.Cause memory cause,,
            Dismissal.Record memory item,
            Dismissal.RevisionContinuation memory continuation,,
            Dismissal.Closure memory closure_
        ) = abi.decode(
            _operationPayload(58, manager.governanceAuthority(), record),
            (
                Dismissal.Request,
                Contest.GovernanceWitness,
                Dismissal.Cause,
                Dismissal.Context,
                Dismissal.Record,
                Dismissal.RevisionContinuation,
                Dismissal.Closure,
                Dismissal.Closure
            )
        );
        _dismissalReadParity(
            abi.encodeCall(IStreamArtistIdentityDismissal.currentIdentityContestCause, (artistId)),
            abi.encode(cause)
        );
        _dismissalReadParity(
            abi.encodeCall(IStreamArtistIdentityDismissal.identityContestCause, (cause.causeHash)),
            abi.encode(cause)
        );
        _dismissalReadParity(
            abi.encodeCall(IStreamArtistIdentityDismissal.identityContestDismissalRecord, (record)),
            abi.encode(item)
        );
        _dismissalReadParity(
            abi.encodeCall(
                IStreamArtistIdentityDismissal.latestIdentityContestDismissal, (artistId)
            ),
            abi.encode(record)
        );
        _dismissalReadParity(
            abi.encodeCall(
                IStreamArtistIdentityDismissal.identityTransitionClosure, (artistId, f.rotation)
            ),
            abi.encode(closure_)
        );
        _dismissalReadParity(
            abi.encodeCall(
                IStreamArtistIdentityDismissal.identityRevisionContinuation,
                (continuation.continuationHash)
            ),
            abi.encode(continuation)
        );
        bytes memory invalid = abi.encodeCall(
            IStreamArtistIdentityDismissal.identityTransitionClosure,
            (keccak256("foreign identity"), f.rotation)
        );
        (bool ok, bytes memory reason) = suite.owners[2].staticcall(invalid);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(Dismissal.InvalidClosure.selector, f.rotation)
                    ),
            "exact linked error"
        );
        (ok, reason) = address(ingress).staticcall(invalid);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(Dismissal.InvalidClosure.selector, f.rotation)
                    ),
            "exact facade error"
        );
        invalid =
            abi.encodeCall(IStreamArtistIdentityDismissal.identityContestDismissalContext, (p));
        (ok, reason) = suite.owners[2].staticcall(invalid);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(Dismissal.InvalidDismissal.selector, artistId)
                    ),
            "stale context exact error"
        );
    }

    function testDismissalRejectsAbsentWrongCauseHeadAndRetirementTerms() public {
        Dismissal.Request memory p = _dismissalRequest();
        vm.expectRevert(abi.encodeWithSelector(Dismissal.InvalidDismissal.selector, artistId));
        ingress.identityContestDismissalContext(p);
        _dismissalGuardianCause();
        p = _dismissalRequest();
        for (uint256 fault; fault < 6; ++fault) {
            Dismissal.Request memory bad = Dismissal.Request(
                p.artistId,
                p.expectedCauseHash,
                p.expectedResolutionHash,
                p.evidenceHash,
                p.reasonHash,
                p.removePriorStanding,
                p.expectedRetirementHash
            );
            if (fault == 0) bad.expectedCauseHash = keccak256("wrong cause");
            if (fault == 1) bad.expectedResolutionHash = keccak256("wrong head");
            if (fault == 2) bad.evidenceHash = 0;
            if (fault == 3) bad.reasonHash = 0;
            if (fault == 4) bad.expectedRetirementHash = keccak256("forbidden false target");
            if (fault == 5) bad.removePriorStanding = true;
            vm.expectRevert(abi.encodeWithSelector(Dismissal.InvalidDismissal.selector, artistId));
            ingress.identityContestDismissalContext(bad);
        }
        require(_dismissalExecute(p, 1, 0) != 0, "valid exact cause succeeds");
    }

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

    function _dismissalCohort(uint8 boundary) private returns (DismissalCohortFixture memory f) {
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

    function _dismissalAssertSelection(DismissalCohortFixture memory f, bool mature) private view {
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

    function testDismissalEarlyClosureAbandonsFiveFamiliesAndAllowsFreshProgress() public {
        DismissalCohortFixture memory f = _dismissalCohort(0);
        bytes32 transitionBytes = keccak256(abi.encode(ingress.rotationRecord(f.rotation)));
        bytes32 oldRevisionKey = _identityRevisionReplayKey(
            keccak256("identity_authority.replay.identity_revision_chain"),
            keccak256(abi.encode(artistId, f.stableRevision, f.stableDocument))
        );
        T.ReplayCell memory oldReplay =
            IStreamArtistOwner(suite.owners[2]).replayCell(oldRevisionKey);
        bytes32 record = _dismissalExecute(_dismissalRequest(), 1, 0);
        Dismissal.Closure memory closure_ = ingress.identityTransitionClosure(artistId, f.rotation);
        require(
            closure_.abandoned && closure_.dismissalRecordHash == record
                && closure_.windowEndsAt == f.end && block.timestamp < f.end,
            "terminal early closure"
        );
        require(
            keccak256(abi.encode(ingress.rotationRecord(f.rotation))) == transitionBytes,
            "captured transition immutable"
        );
        (bytes32 activeWindow,,) = ingress.activeAuthorityWindow(artistId);
        require(activeWindow == 0, "closed window no longer blocks");
        _dismissalAssertSelection(f, false);
        uint256 beforeExpiry = vm.snapshotState();
        vm.warp(uint256(f.end) + 100);
        _dismissalAssertSelection(f, false);
        require(vm.revertToState(beforeExpiry), "restore original pre-expiry time");
        require(
            ingress.identityRevisionRecord(f.childRevision).recordHash == f.childRevision
                && ingress.successorDesignationRecord(f.childSuccessor).recordHash
                    == f.childSuccessor
                && ingress.estateDirectiveRecord(f.childDirective).recordHash == f.childDirective,
            "rejected history remains"
        );
        Dismissal.Record memory item = ingress.identityContestDismissalRecord(record);
        Dismissal.RevisionContinuation memory cont =
            ingress.identityRevisionContinuation(item.revisionContinuationHead);
        require(
            cont.continuationHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_IDENTITY_REVISION_CONTINUATION_V1"),
                        block.chainid,
                        address(ingress),
                        suite.owners[2],
                        artistId,
                        record,
                        bytes32(0),
                        f.stableRevision,
                        f.stableDocument,
                        f.childRevision
                    )
                ),
            "independent continuation preimage"
        );
        bytes32 newRevision = _reviseDocument(bytes("stable continuation document"));
        bytes32 continuationKey = _identityRevisionReplayKey(
            keccak256("identity_authority.replay.identity_revision_continuation"),
            keccak256(
                abi.encode(artistId, f.stableRevision, f.stableDocument, cont.continuationHash)
            )
        );
        require(
            IStreamArtistOwner(suite.owners[2]).replayCell(continuationKey).commitment
                    == newRevision
                && keccak256(
                    abi.encode(IStreamArtistOwner(suite.owners[2]).replayCell(oldRevisionKey))
                ) == keccak256(abi.encode(oldReplay)),
            "new lane consumed and old replay unchanged"
        );
        StreamArtistIdentityRevisionTypes.Revision memory fork =
            StreamArtistIdentityRevisionTypes.Revision(
                artistId, f.stableDocument, keccak256("fork document"), "urn:fork"
            );
        T.Authorization memory forkA = T.Authorization(nextNonce, uint64(block.timestamp), "");
        forkA.signature = _signature(ingress.identityRevisionDigest(fork, forkA));
        bytes32 forkRoots = _roots();
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        ingress.recordIdentityRevision(fork, forkA, bytes("fork document"), "Fork");
        require(_roots() == forkRoots, "occupied predecessor cannot fork the continuation");
        bytes32 newPayout = _dismissalPayout(address(0x1003));
        require(
            StreamArtistPayoutLifecycle(suite.owners[5]).payoutAbandonment(f.childPayout) == record
                && newPayout != f.childPayout,
            "lazy exact payout child detachment"
        );
        _selfGuardian();
        _successionRecord(_successorTerms(address(0xCC), 1));
        _directiveRecord(0);
        _newRotationSafe(18009);
        bytes32 next = _stageRotation(f.rotation);
        require(next != 0, "new rotation after closure");
    }

    function testDismissalPayoutLegacyContextRejectsAndLazyDetachRollsBackWithArchive() public {
        DismissalCohortFixture memory f = _dismissalCohort(0);
        bytes32 dismissal = _dismissalExecute(_dismissalRequest(), 1, 0);
        T.PayoutDesignation memory p =
            T.PayoutDesignation(artistId, address(0x1007), f.stablePayout);
        T.ActionContext memory c = T.ActionContext(
            18, address(artist), IStreamArtistOwner(suite.owners[5]).ownerStateSnapshotV2()
        );
        R.TransitionState memory transition = ingress.rotationRecord(f.rotation).transition;
        vm.expectRevert(abi.encodeWithSelector(R.ProvisionalChainOccupied.selector, f.childPayout));
        vm.prank(address(coordinator));
        StreamArtistPayoutLifecycle(suite.owners[5])
            .recordDesignationWithTransition(
                c, p, address(artist), nextNonce, uint64(block.timestamp), transition, transition
            );
        bytes32 roots = _roots();
        avm.mockCallRevert(
            address(archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(T.InvalidRecord.selector)
        );
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        this.executeDismissalPayout(address(0x1007));
        require(
            _roots() == roots
                && StreamArtistPayoutLifecycle(suite.owners[5]).payoutAbandonment(f.childPayout)
                    == 0,
            "late archive restores pending child and detachment proof"
        );
        avm.clearMockedCalls();
        this.executeDismissalPayout(address(0x1007));
        require(
            StreamArtistPayoutLifecycle(suite.owners[5]).payoutAbandonment(f.childPayout)
                == dismissal,
            "actual typed closure authorizes exact stored child detachment"
        );
    }

    function testDismissalRepeatedAbandonmentCreatesNewContinuationWithoutResettingOldLane()
        public
    {
        DismissalCohortFixture memory f = _dismissalCohort(0);
        bytes32 first = _dismissalExecute(_dismissalRequest(), 1, 0);
        bytes32 head1 = ingress.identityContestDismissalRecord(first).revisionContinuationHead;
        OfficialSafe prior = artist;
        uint256[] memory priorKeys = keys;
        _newRotationSafe(18040);
        bytes32 rotation = _stageRotation(f.rotation);
        _executeTimedRotation(rotation);
        _adoptRotatedSafe();
        bytes32 child = _reviseDocument(bytes("second provisional continuation child"));
        bytes32 key1 = _identityRevisionReplayKey(
            keccak256("identity_authority.replay.identity_revision_continuation"),
            keccak256(abi.encode(artistId, f.stableRevision, f.stableDocument, head1))
        );
        require(
            IStreamArtistOwner(suite.owners[2]).replayCell(key1).commitment == child,
            "first continuation consumed"
        );
        require(
            executeSafe(prior, priorKeys, address(ingress), 0, _contestData(rotation), 0),
            "new actual retired contest"
        );
        bytes32 second = _dismissalExecute(_dismissalRequest(), 1, 0);
        bytes32 head2 = ingress.identityContestDismissalRecord(second).revisionContinuationHead;
        Dismissal.RevisionContinuation memory cont = ingress.identityRevisionContinuation(head2);
        require(
            head2 != head1 && cont.previousContinuationHash == head1
                && cont.abandonedRevisionRecordHash == child,
            "versioned continuation retains predecessor history"
        );
        bytes32 replacement = _reviseDocument(bytes("second stable continuation"));
        bytes32 key2 = _identityRevisionReplayKey(
            keccak256("identity_authority.replay.identity_revision_continuation"),
            keccak256(abi.encode(artistId, f.stableRevision, f.stableDocument, head2))
        );
        require(
            IStreamArtistOwner(suite.owners[2]).replayCell(key1).commitment == child
                && IStreamArtistOwner(suite.owners[2]).replayCell(key2).commitment == replacement,
            "neither prior replay lane reset"
        );
    }

    function _dismissalMatureCase(uint8 boundary) private {
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

    function testDismissalAtExactExpiryKeepsAllFiveMatureHeads() public {
        _dismissalMatureCase(1);
    }

    function testDismissalAfterExpiryKeepsAllFiveMatureHeads() public {
        _dismissalMatureCase(2);
    }

    function testDismissalVetoCauseKeepsNoPrimaryRecordAndLaterContestCannotMutateClosure() public {
        _selfGuardian();
        _newRotationSafe(18100);
        bytes32 first = _stageRotation(0);
        _executeTimedRotation(first);
        _adoptRotatedSafe();
        vm.warp(ingress.rotationRecord(first).transition.postWindowEndsAt);
        _selfGuardian();
        _newRotationSafe(18101);
        bytes32 pending = _stageRotation(first);
        bytes32 previousContest = ingress.latestIdentityContest(artistId);
        T.Snapshot memory beforeVeto = IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2();
        vm.recordLogs();
        this.executeArtistSafe(
            abi.encodeCall(
                IStreamArtistRotation.vetoArtistRotation,
                (artistId, pending, keccak256("veto reason"))
            )
        );
        Vm.Log[] memory causeLogs = vm.getRecordedLogs();
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        _assertDismissalCauseEvent(causeLogs, cause);
        require(
            IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2().recordChainTip
                == beforeVeto.recordChainTip,
            "operation31 still has no normative primary record"
        );
        require(
            cause.facts.kind == 2 && cause.facts.referenceHash == pending
                && cause.facts.actor == address(artist)
                && cause.facts.pendingTransitionHash == pending
                && cause.facts.executedTransitionHash == first && cause.facts.evidenceHash == 0
                && ingress.latestIdentityContest(artistId) == previousContest,
            "actual veto cause, no fabricated33"
        );
        _dismissalExecute(_dismissalRequest(), 1, 0);
        bytes32 firstBytes = keccak256(abi.encode(ingress.rotationRecord(first)));
        bytes32 closureBytes =
            keccak256(abi.encode(ingress.identityTransitionClosure(artistId, first)));
        _newRotationSafe(18102);
        bytes32 fresh = _stageRotation(pending);
        this.executeArtistSafe(_contestData(first));
        require(ingress.rotationRecord(fresh).transition.phase == 3, "new pending is cancelled");
        require(
            keccak256(abi.encode(ingress.rotationRecord(first))) == firstBytes
                && keccak256(abi.encode(ingress.identityTransitionClosure(artistId, first)))
                    == closureBytes,
            "closed mature transition and closure immutable"
        );
        Dismissal.Cause memory later = ingress.currentIdentityContestCause(artistId);
        require(
            later.causeHash != cause.causeHash && later.facts.pendingTransitionHash == fresh,
            "new exact cause"
        );
        _dismissalExecute(_dismissalRequest(), 2, 0);
        require(
            keccak256(abi.encode(ingress.identityTransitionClosure(artistId, first)))
                == closureBytes,
            "second dismissal cannot overwrite closure"
        );
    }

    function testDismissalLateArchiveRollbackRetainsCauseStatusClosuresAndContinuation() public {
        DismissalCohortFixture memory f = _dismissalCohort(0);
        Dismissal.Request memory p = _dismissalRequest();
        bytes32 roots = _roots();
        bytes32 causeHash = p.expectedCauseHash;
        avm.mockCallRevert(
            address(archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(T.InvalidRecord.selector)
        );
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        this.executeGovernedDismissal(p, 1, 0);
        require(
            _roots() == roots && ingress.latestIdentityContestDismissal(artistId) == 0
                && ingress.currentIdentityContestCause(artistId).causeHash == causeHash
                && ingress.identityTransitionClosure(artistId, f.rotation).dismissalRecordHash == 0
                && IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).status == 4,
            "late all-owner resolution rollback"
        );
        avm.clearMockedCalls();
        require(_dismissalExecute(p, 1, 0) != 0, "exact request succeeds after restored archive");
    }

    function testDismissalRemovedPriorStandingBlocks31And33ButGuardianStandingSurvives() public {
        OfficialSafe retired = artist;
        uint256[] memory retiredKeys = keys;
        _newRotationSafe(18200);
        bytes32 first = _stageRotation(0);
        _executeTimedRotation(first);
        _adoptRotatedSafe();
        require(
            executeSafe(retired, retiredKeys, address(ingress), 0, _contestData(first), 0),
            "actual retired cause actor"
        );
        Dismissal.Request memory p = _dismissalRequest();
        p.removePriorStanding = true;
        p.expectedRetirementHash = first;
        bytes32 record = _dismissalExecute(p, 1, 0);
        (bool revoked, bytes32 judgment) =
            ingress.priorAddressStandingRevoked(artistId, address(retired));
        require(revoked && judgment == record, "composed retirement-specific judgment");
        _newRotationSafe(18201);
        bytes32 pending = _stageRotation(first);
        bytes memory veto = abi.encodeCall(
            IStreamArtistRotation.vetoArtistRotation, (artistId, pending, keccak256("retired veto"))
        );
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(retired)));
        vm.prank(address(retired));
        ingress.vetoArtistRotation(artistId, pending, keccak256("retired veto"));
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(retired)));
        vm.prank(address(retired));
        ingress.contestArtistIdentity(
            artistId, 0, keccak256("new evidence"), keccak256("new reason")
        );
        address[] memory guardians = new address[](1);
        guardians[0] = address(retired);
        _guardianRecord(guardians, 1, 0, nextNonce);
        require(
            executeSafe(retired, retiredKeys, address(ingress), 0, veto, 0),
            "independent operative guardian remains actual Safe"
        );
    }

    function testDismissalRemovedPriorStandingCannotBeRevokedAgainBy51() public {
        OfficialSafe retired = artist;
        uint256[] memory retiredKeys = keys;
        _newRotationSafe(18210);
        bytes32 first = _stageRotation(0);
        _executeTimedRotation(first);
        _adoptRotatedSafe();
        require(
            executeSafe(retired, retiredKeys, address(ingress), 0, _contestData(first), 0),
            "retired cause"
        );
        Dismissal.Request memory p = _dismissalRequest();
        p.removePriorStanding = true;
        p.expectedRetirementHash = first;
        _dismissalExecute(p, 1, 0);
        R.StandingRevocation memory terms =
            R.StandingRevocation(artistId, address(retired), keccak256("again"), first);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.standingRevocationDigest(terms, a));
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(R.InvalidPriorStanding.selector, address(retired)));
        ingress.revokePriorAddressStanding(terms, a);
        require(_roots() == roots, "no duplicate standing record");
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
            ingress.operativeIdentityRecord(artistId),
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
