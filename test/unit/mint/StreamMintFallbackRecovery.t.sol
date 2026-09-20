// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../core/StreamCorePermanentTarget.t.sol";
import "../../helpers/GovernedParameterTestMocks.sol";
import "../../../script/current/StreamCurrentStackPlan.sol";
import "../../../smart-contracts/domains/mint/StreamMintManagerFallback.sol";
import "../../../smart-contracts/domains/mint/StreamMintLedger.sol";

/// @dev Explicit governance context seam; calls reach targets from the bound contract authority.
contract FallbackRecoveryAuthority is MockGovernedParameterAuthority {
    constructor() MockGovernedParameterAuthority(true) { }

    function execute(address target, bytes calldata input) external returns (bytes memory output) {
        bool ok;
        (ok, output) = target.call(input);
        if (!ok) assembly ("memory-safe") { revert(add(output, 32), mload(output)) }
    }
}

/// @dev Deliberately nonconforming predecessor: persists a preparation through the real Core hook.
/// Its actual Ledger writes establish a genuine nonempty snapshot; no impersonation/storage writes.
contract FallbackIncidentPredecessor {
    IStreamCore public immutable core;
    StreamMintLedger public immutable mintLedger;
    bytes32 public constant CLAIM = keccak256("actual incident entitlement");
    bytes32 public constant AUTH = keccak256("actual incident authorization");
    bytes32 public constant ROOT = keccak256("actual incident operation root");

    constructor(IStreamCore core_, StreamMintLedger ledger_) {
        core = core_;
        mintLedger = ledger_;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamMintManager).interfaceId || id == type(IERC165).interfaceId;
    }

    function strand(bytes32 operation) external returns (uint256 tokenId) {
        bytes32 phase = keccak256("incident fixture phase");
        bytes32 policy = keccak256("incident fixture policy");
        mintLedger.registerPhasePolicy(
            address(this),
            1,
            phase,
            policy,
            new bytes32[](0),
            new IStreamMintLedger.LedgerCounterPolicy[](0),
            0
        );
        bytes32[] memory nullifiers = new bytes32[](1);
        nullifiers[0] = CLAIM;
        mintLedger.consume(
            1, phase, new IStreamMintLedger.CounterConsumption[](0), AUTH, nullifiers, policy, ROOT
        );
        bytes memory data = bytes("stranded original bytes");
        (tokenId,) = core.prepareMintFromManager(1, data, keccak256(data), operation);
    }

    function abort(uint256 tokenId, bytes32 operation) external {
        core.abortPreparedMintFromManager(tokenId, operation);
    }

    function mintBaseline(address recipient) external returns (uint256 tokenId) {
        bytes memory data = bytes("historic artwork");
        (tokenId,) =
            core.mintFromManager(1, recipient, data, keccak256(data), keccak256("historic mint"));
    }
}

/// @dev Typed Artist seam used only for ordinary post-recovery mint/reentry tests.
contract FallbackRecoveryArtist {
    address public immutable core;
    address public immutable mintManager;

    constructor(address core_, address manager_) {
        core = core_;
        mintManager = manager_;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamArtistMintConsent).interfaceId || id == type(IERC165).interfaceId;
    }

    function consentMode(uint256) external pure returns (uint8) {
        return 1;
    }

    function isPolicyConsented(uint256, bytes32, bytes32) external pure returns (bool, bytes32) {
        return (true, keccak256("explicit fixture consent"));
    }
    function requireMintConsent(uint256, bytes32, bytes32) external pure { }
}

/// @dev During an actual mint callback, the authority attempts recovery through the real facade.
contract FallbackRecoveryReceiver is IERC721Receiver {
    FallbackRecoveryAuthority private immutable authority;
    StreamMintManagerFallback private immutable manager;
    bytes32 private immutable operation;
    bool public rejectDelivery;
    bytes4 public observedError;

    constructor(
        FallbackRecoveryAuthority authority_,
        StreamMintManagerFallback manager_,
        bytes32 operation_
    ) {
        authority = authority_;
        manager = manager_;
        operation = operation_;
    }

    function setReject(bool value) external {
        rejectDelivery = value;
    }

    function onERC721Received(address, address, uint256 token, bytes calldata)
        external
        returns (bytes4)
    {
        (bool ok, bytes memory output) = address(authority)
            .call(
                abi.encodeCall(
                    authority.execute,
                    (
                        address(manager),
                        abi.encodeCall(manager.recoverPreparedMint, (token, operation))
                    )
                )
            );
        require(!ok && output.length == 4, "reentry rejected before recovery reads");
        bytes4 selector;
        assembly ("memory-safe") { selector := mload(add(output, 32)) }
        require(
            selector == ReentrancyGuard.ReentrancyGuardReentrantCall.selector, "inherited guard"
        );
        observedError = selector;
        require(!rejectDelivery, "late receiver rejection");
        return this.onERC721Received.selector;
    }
}

/// @notice Actual Core/Ledger/derived Manager recovery; governance, registry, Artist and entropy
/// are explicit typed boundaries. Successful abort cases require the monotone Core abort repair.
contract StreamMintFallbackRecoveryTest is CharacterizationTestBase {
    bytes32 private constant MANAGER = keccak256("MINT_MANAGER");
    bytes32 private constant MANIFEST = keccak256("recovery fixture manifest");
    bytes32 private constant DEPLOYMENT = keccak256("recovery fixture deployment");
    bytes32 private constant OPERATION = keccak256("stranded operation");
    bytes32 private constant ACTION = keccak256("exact recovery action");
    bytes32 private constant PHASE = keccak256("fresh fallback phase");
    address private constant LIVE_OWNER = address(0xB001);
    address private constant BURN_OWNER = address(0xB002);
    StreamCore private core;
    StreamMintLedger private ledger;
    StreamMintManagerFallback private fallbackManager;
    FallbackIncidentPredecessor private predecessor;
    FallbackRecoveryAuthority private authority;
    PermanentTargetModuleRegistry private registry;
    PermanentTargetEntropyCoordinator private entropy;
    uint256 private token;

    function setUp() public {
        vm.warp(1000);
        vm.roll(20);
        authority = new FallbackRecoveryAuthority();
        registry = new PermanentTargetModuleRegistry();
        registry.setGovernanceExecutor(address(authority));
        core = new StreamCore(
            "Incident Core",
            "INC",
            address(authority),
            StreamCore.GenesisModuleRegistryConfig(
                address(registry), address(registry).codehash, MANIFEST, DEPLOYMENT
            ),
            StreamCurrentStackPlan.gasParameters()
        );
        ledger = new StreamMintLedger();
        fallbackManager = new StreamMintManagerFallback(core, ledger, IERC165(address(registry)));
        predecessor = new FallbackIncidentPredecessor(core, ledger);
        ledger.setLedgerWriter(address(predecessor), true);
        ledger.setLedgerWriter(address(fallbackManager), true);
        fallbackManager.transferOwnership(address(authority));
        ledger.transferOwnership(address(authority));
        _install(
            address(registry), keccak256("MODULE_REGISTRY"), type(IStreamModuleRegistry).interfaceId
        );
        _install(address(ledger), keccak256("MINT_LEDGER"), type(IStreamMintLedger).interfaceId);
        _install(address(predecessor), MANAGER, type(IStreamMintManager).interfaceId);
        entropy = new PermanentTargetEntropyCoordinator();
        _install(
            address(entropy),
            keccak256("ENTROPY_COORDINATOR"),
            type(IStreamEntropyCoordinator).interfaceId
        );
        FallbackRecoveryArtist artist =
            new FallbackRecoveryArtist(address(core), address(fallbackManager));
        _install(
            address(artist),
            keccak256("ARTIST_REGISTRY"),
            type(IStreamArtistMintConsent).interfaceId
        );
        (GovernanceCall memory call_, bytes memory data) =
            StreamCurrentStackPlan.createCollectionCall(core, 1, 10);
        _context(1, call_);
        authority.execute(address(core), data);
        require(predecessor.mintBaseline(LIVE_OWNER) == 1, "actual completed baseline");
        require(predecessor.mintBaseline(BURN_OWNER) == 2, "actual burn baseline");
        vm.prank(BURN_OWNER);
        core.burn(2);
        token = predecessor.strand(OPERATION);
        require(token == 3 && core.pendingPreparedMintTokenId() == 3, "actual stranded incident");
        _importActualClaim();
        registry.setRecord(
            address(fallbackManager),
            MANAGER,
            type(IStreamMintManager).interfaceId,
            MANIFEST,
            DEPLOYMENT
        );
    }

    function _install(address target, bytes32 kind, bytes4 interfaceId) private {
        registry.setRecord(target, kind, interfaceId, MANIFEST, DEPLOYMENT);
        if (kind != keccak256("MODULE_REGISTRY")) _select(target, kind);
    }

    function _select(address target, bytes32 kind) private {
        StreamCorePointerState memory old = StreamCurrentStackPlan.readPointer(core, kind);
        StreamModuleRecord memory r = registry.moduleRecord(target);
        StreamCorePointerState memory next = StreamCorePointerState(
            target,
            target.codehash,
            false,
            r.moduleType,
            r.interfaceId,
            address(registry),
            uint8(r.status),
            r.moduleManifestHash,
            r.deploymentManifestHash,
            old.revision + 1
        );
        (bytes32 scope, bytes32 before_, bytes32 after_) =
            StreamCurrentStackPlan.pointerTransitionHashes(core, kind, old, next);
        authority.setCurrentAction(true, ACTION, 3, scope, before_, after_);
        authority.execute(
            address(core), abi.encodeCall(core.updateSatellitePointer, (kind, target))
        );
    }

    function _importActualClaim() private {
        authority.execute(
            address(ledger), abi.encodeCall(ledger.retireLedgerWriter, (address(predecessor)))
        );
        uint64 snapshot = uint64(block.number);
        bytes32 claim = keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_NULLIFIER_IMPORT_LEAF_V1"),
                        block.chainid,
                        address(ledger),
                        address(predecessor),
                        predecessor.CLAIM()
                    )
                )
            )
        );
        bytes32 descriptor = keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_IMPORT_MANIFEST_LEAF_V1"),
                        block.chainid,
                        address(ledger),
                        address(ledger),
                        address(predecessor),
                        address(fallbackManager),
                        snapshot,
                        MANIFEST,
                        uint64(0),
                        uint64(1)
                    )
                )
            )
        );
        bytes32 root = claim < descriptor
            ? keccak256(abi.encode(claim, descriptor))
            : keccak256(abi.encode(descriptor, claim));
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_IMPORT_SCOPE_V1"),
                block.chainid,
                address(ledger),
                address(fallbackManager)
            )
        );
        bytes32 value = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_IMPORT_COMMITMENT_V1"),
                scope,
                address(ledger),
                address(predecessor),
                address(fallbackManager),
                snapshot,
                root,
                MANIFEST
            )
        );
        authority.setCurrentAction(true, ACTION, 1, scope, 0, value);
        authority.execute(
            address(ledger),
            abi.encodeCall(
                ledger.commitCounterImportRoot,
                (
                    address(ledger),
                    address(predecessor),
                    address(fallbackManager),
                    snapshot,
                    root,
                    MANIFEST
                )
            )
        );
        IStreamMintManagerImport.ImportBatch memory batch;
        batch.importRoot = root;
        batch.counters = new IStreamMintLedgerImport.CounterImportLeaf[](0);
        batch.counterProofs = new bytes32[][](0);
        batch.nullifiers = new bytes32[](1);
        batch.nullifiers[0] = predecessor.CLAIM();
        batch.nullifierProofs = new bytes32[][](1);
        batch.nullifierProofs[0] = new bytes32[](1);
        batch.nullifierProofs[0][0] = descriptor;
        authority.execute(
            address(fallbackManager),
            abi.encodeCall(fallbackManager.importMintState, (abi.encode(batch)))
        );
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = claim;
        ledger.completeCounterImport(root, 0, 1, proof);
        require(
            ledger.isMintSuccessorReady(
                address(ledger), address(predecessor), address(fallbackManager)
            ),
            "real import ready"
        );
    }

    function _context(uint8 cls, GovernanceCall memory call_) private {
        authority.setCurrentAction(
            true, ACTION, cls, call_.scopeHash, call_.oldValueHash, call_.newValueHash
        );
    }

    function _hashes() private view returns (bytes32 scope, bytes32 oldHash, bytes32 newHash) {
        (, uint256 collection, uint256 serial,) = core.tokenCollectionIdentity(token);
        scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_FALLBACK_RECOVERY_SCOPE_V1"),
                block.chainid,
                address(core),
                address(fallbackManager),
                token,
                OPERATION
            )
        );
        bytes32 retained = keccak256(
            abi.encode(
                collection,
                serial,
                core.lastAllocatedTokenId(),
                core.collectionNextSerial(collection),
                core.collectionMintedEver(collection),
                core.totalSupply()
            )
        );
        bytes32 domain = keccak256("6529STREAM_MINT_FALLBACK_RECOVERY_STATE_V1");
        oldHash = keccak256(
            abi.encode(
                domain,
                scope,
                true,
                retained,
                keccak256(core.tokenData(token)),
                core.coordinatorAtMint(token)
            )
        );
        newHash =
            keccak256(abi.encode(domain, scope, false, retained, keccak256(bytes("")), address(0)));
    }

    function _ready() private {
        _select(address(fallbackManager), MANAGER);
        _setRecoveryContext();
    }

    function _setRecoveryContext() private {
        (bytes32 scope, bytes32 before_, bytes32 after_) = _hashes();
        authority.setCurrentAction(true, ACTION, 3, scope, before_, after_);
    }

    function _recover(uint256 id, bytes32 operation) private {
        authority.execute(
            address(fallbackManager),
            abi.encodeCall(fallbackManager.recoverPreparedMint, (id, operation))
        );
    }

    function _state() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                core.preparedMint(token),
                core.pendingPreparedMintTokenId(),
                core.tokenData(token),
                core.coordinatorAtMint(token),
                core.lastAllocatedTokenId(),
                core.collectionNextSerial(1),
                core.collectionMintedEver(1),
                core.totalSupply(),
                _history(),
                fallbackManager.nextOperationNonce(),
                ledger.isManagerNullifierUsed(address(fallbackManager), predecessor.CLAIM())
            )
        );
    }

    function _history() private view returns (bytes32) {
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            core.tokenCollectionIdentity(2);
        return keccak256(
            abi.encode(
                core.ownerOf(1),
                core.tokenData(1),
                core.tokenData(2),
                core.coordinatorAtMint(1),
                core.coordinatorAtMint(2),
                exists,
                collection,
                serial,
                burned
            )
        );
    }

    function _reject(uint256 id, bytes32 operation) private {
        bytes32 before_ = _state();
        vm.expectRevert();
        _recover(id, operation);
        require(_state() == before_, "failed recovery preserves all state");
    }

    function testIndependentTransitionCommitsExactIncidentAndAllocationFrontiers() public view {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = _hashes();
        (bytes32 actualScope, bytes32 actualOld, bytes32 actualNew) =
            StreamMintFallbackRecovery.transition(address(fallbackManager), token, OPERATION);
        require(
            scope == actualScope && oldHash == actualOld && newHash == actualNew,
            "independent recovery commitments"
        );
        require(oldHash != newHash && scope != 0, "real transition");
    }

    function testExactClassThreeAbortPreservesFrontiersLedgerAndEmitsOnce() public {
        bytes32 history = _history();
        _ready();
        vm.recordLogs();
        _recover(token, OPERATION);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 recovered;
        bytes32 topic =
            keccak256("MintFallbackPreparedRecovered(uint16,bytes32,uint256,bytes32,uint256)");
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(fallbackManager) && logs[i].topics[0] == topic) {
                require(
                    logs[i].topics.length == 4 && logs[i].topics[1] == ACTION
                        && logs[i].topics[2] == bytes32(token) && logs[i].topics[3] == OPERATION,
                    "recovery event identity"
                );
                (uint16 schema, uint256 collection) = abi.decode(logs[i].data, (uint16, uint256));
                require(schema == 1 && collection == 1, "recovery event body");
                ++recovered;
            }
        }
        require(recovered == 1, "one recovery event");
        require(
            core.pendingPreparedMintTokenId() == 0 && !core.preparedMint(token).exists
                && core.tokenData(token).length == 0 && core.coordinatorAtMint(token) == address(0),
            "incident cleared"
        );
        (bool exists,,,) = core.tokenCollectionIdentity(token);
        require(!exists, "abandoned identity removed");
        require(
            core.lastAllocatedTokenId() == token && core.collectionNextSerial(1) == 4
                && core.collectionMintedEver(1) == 2 && core.totalSupply() == 1
                && core.totalSupplyOfCollection(1) == 1 && _history() == history,
            "allocation gaps retained"
        );
        require(
            ledger.isManagerNullifierUsed(address(predecessor), predecessor.CLAIM())
                && ledger.isManagerNullifierUsed(address(fallbackManager), predecessor.CLAIM())
                && ledger.isManagerAuthorizationUsed(address(predecessor), predecessor.AUTH())
                && ledger.isManagerOperationRootUsed(address(predecessor), predecessor.ROOT()),
            "original and imported evidence retained"
        );
        _reject(token, OPERATION);
    }

    function testWrongCallerCannotUseOtherwiseExactContext() public {
        _ready();
        bytes32 before_ = _state();
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintFallbackRecovery.InvalidFallbackRecoveryBinding.selector
            )
        );
        fallbackManager.recoverPreparedMint(token, OPERATION);
        require(_state() == before_, "caller failure unchanged");
    }

    function testWrongClassNonexecutingAndZeroActionAreRejected() public {
        _ready();
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = _hashes();
        for (uint8 cls; cls < 5; ++cls) {
            if (cls == 3) continue;
            authority.setCurrentAction(true, ACTION, cls, scope, oldHash, newHash);
            _reject(token, OPERATION);
        }
        authority.setCurrentAction(false, ACTION, 3, scope, oldHash, newHash);
        _reject(token, OPERATION);
        authority.setCurrentAction(true, 0, 3, scope, oldHash, newHash);
        _reject(token, OPERATION);
        _setRecoveryContext();
        _recover(token, OPERATION);
    }

    function testWrongScopeOldAndNewCommitmentsDoNotConsumeIncident() public {
        _ready();
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = _hashes();
        authority.setCurrentAction(true, ACTION, 3, scope ^ bytes32(uint256(1)), oldHash, newHash);
        _reject(token, OPERATION);
        authority.setCurrentAction(true, ACTION, 3, scope, oldHash ^ bytes32(uint256(1)), newHash);
        _reject(token, OPERATION);
        authority.setCurrentAction(true, ACTION, 3, scope, oldHash, newHash ^ bytes32(uint256(1)));
        _reject(token, OPERATION);
        _setRecoveryContext();
        _recover(token, OPERATION);
    }

    function testWrongOrZeroTokenAndOperationRejectWithoutStateChange() public {
        _ready();
        _reject(0, OPERATION);
        _reject(token + 1, OPERATION);
        _reject(token, 0);
        _reject(token, keccak256("different operation"));
        _recover(token, OPERATION);
    }

    function testMalformedBoundedGovernanceRepliesFailClosed() public {
        _ready();
        for (
            uint8 mode = 1;
            mode <= uint8(MockGovernedParameterAuthority.ResponseMode.GasHeavy);
            ++mode
        ) {
            authority.setResponseMode(MockGovernedParameterAuthority.ResponseMode(mode));
            _reject(token, OPERATION);
        }
        authority.setResponseMode(MockGovernedParameterAuthority.ResponseMode.Canonical);
        _recover(token, OPERATION);
    }

    function testPreparerAndNoncurrentFallbackCannotAbort() public {
        _setRecoveryContext();
        _reject(token, OPERATION);
        vm.expectRevert(abi.encodeWithSelector(StreamCore.PreparedMintAbortNotReplacement.selector));
        predecessor.abort(token, OPERATION);
        _ready();
        vm.expectRevert();
        predecessor.abort(token, OPERATION);
        _recover(token, OPERATION);
    }

    function testChangedOwnerAndRegistryAuthorityFailClosed() public {
        _ready();
        registry.setGovernanceExecutor(address(this));
        _reject(token, OPERATION);
        registry.setGovernanceExecutor(address(authority));
        authority.execute(
            address(fallbackManager),
            abi.encodeCall(fallbackManager.transferOwnership, (address(this)))
        );
        _reject(token, OPERATION);
        fallbackManager.transferOwnership(address(authority));
        _recover(token, OPERATION);
    }

    function testManagerAndRegistryRuntimePinsRejectDriftAndAllowRestoredRetry() public {
        _ready();
        bytes memory saved = address(fallbackManager).code;
        vm.etch(address(fallbackManager), bytes.concat(saved, hex"00"));
        _reject(token, OPERATION);
        vm.etch(address(fallbackManager), saved);
        saved = address(registry).code;
        vm.etch(address(registry), bytes.concat(saved, hex"00"));
        _reject(token, OPERATION);
        vm.etch(address(registry), saved);
        _recover(token, OPERATION);
    }

    function testRecoveryFacadeDoesNotForwardPrepareOrComplete() public {
        _ready();
        bytes32 before_ = _state();
        vm.expectRevert();
        authority.execute(
            address(fallbackManager),
            abi.encodeCall(
                core.prepareMintFromManager,
                (1, bytes("unsupported"), keccak256("unsupported"), OPERATION)
            )
        );
        vm.expectRevert();
        authority.execute(
            address(fallbackManager),
            abi.encodeCall(
                core.completePreparedMintFromManager,
                (token, address(this), OPERATION, keccak256("unsupported"))
            )
        );
        require(_state() == before_, "no extra lifecycle forwarder");
    }

    function _configureFreshPhase() private {
        IStreamMintManager.MintPhaseConfig memory config = IStreamMintManager.MintPhaseConfig(
            false, 0, 0, 1, keccak256("fresh terms"), keccak256("fresh metadata")
        );
        IStreamMintManager.MintGateConfig memory gate;
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = keccak256("fresh cap");
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            2,
            1,
            keccak256("fresh counter terms")
        );
        authority.execute(
            address(fallbackManager),
            abi.encodeCall(fallbackManager.configurePhase, (1, PHASE, config, gate, ids, counters))
        );
        authority.execute(
            address(fallbackManager),
            abi.encodeCall(fallbackManager.setPhaseExecutor, (1, PHASE, address(this), true))
        );
    }

    function _batch(address recipient)
        private
        view
        returns (IStreamMintManager.MintBatch memory b)
    {
        b.collectionId = 1;
        b.phaseId = PHASE;
        b.payer = address(this);
        b.authorizer = address(0); // Ungated phases have no external authorizer.
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = recipient;
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = recipient;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = bytes("fresh artwork");
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = keccak256("fresh mint");
        b.expectedPolicyHash = fallbackManager.phasePolicyHash(1, PHASE);
        b.contextHash = keccak256("fresh context");
        b.authorizationId = keccak256("fresh authorization");
    }

    function testActiveMintRejectsRecoveryReentryAndNeverReusesAbandonedIdentity() public {
        _ready();
        _recover(token, OPERATION);
        _configureFreshPhase();
        FallbackRecoveryReceiver receiver =
            new FallbackRecoveryReceiver(authority, fallbackManager, OPERATION);
        (uint256[] memory ids,,) =
            fallbackManager.executeSingleStepMint(_batch(address(receiver)), "");
        require(
            ids[0] == token + 1 && core.ownerOf(ids[0]) == address(receiver),
            "next token never reuses incident ID"
        );
        (, uint256 collection, uint256 serial,) = core.tokenCollectionIdentity(ids[0]);
        require(
            collection == 1 && serial == 4
                && receiver.observedError()
                    == ReentrancyGuard.ReentrancyGuardReentrantCall.selector,
            "next serial and real inherited reentry guard"
        );
    }

    function testLateReceiverFailureRollsBackMintAndIdenticalRetrySucceeds() public {
        _ready();
        _recover(token, OPERATION);
        _configureFreshPhase();
        FallbackRecoveryReceiver receiver =
            new FallbackRecoveryReceiver(authority, fallbackManager, OPERATION);
        IStreamMintManager.MintBatch memory batch = _batch(address(receiver));
        bytes32 counter = keccak256("fresh cap");
        bytes32 subject = fallbackManager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.CONSTANT,
            1,
            PHASE,
            counter,
            batch.payer,
            address(receiver),
            address(this),
            address(0),
            batch.contextHash
        );
        bytes32 counterKey = fallbackManager.previewCounterValueKey(1, PHASE, counter, subject);
        (bytes32 root,) = fallbackManager.previewSingleStepMintOperation(batch, "");
        bytes32 before_ = _state();
        receiver.setReject(true);
        vm.expectRevert();
        fallbackManager.executeSingleStepMint(batch, "");
        require(
            _state() == before_
                && !ledger.isManagerOperationRootUsed(address(fallbackManager), root)
                && !ledger.isManagerAuthorizationUsed(
                    address(fallbackManager), batch.authorizationId
                ) && entropy.callCount() == 2 && receiver.observedError() == bytes4(0)
                && ledger.counterValue(counterKey) == 0,
            "full late-failure rollback"
        );
        receiver.setReject(false);
        (uint256[] memory ids, bytes32 accepted,) = fallbackManager.executeSingleStepMint(batch, "");
        require(
            ids[0] == token + 1 && accepted == root && fallbackManager.nextOperationNonce() == 1
                && ledger.counterValue(counterKey) == 1,
            "identical valid request retries at preserved frontier"
        );
    }
}
