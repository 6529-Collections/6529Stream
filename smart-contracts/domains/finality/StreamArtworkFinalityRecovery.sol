// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamFinalityRecoveryRoutes.sol";
import "./StreamFinalityRecoveryExecution.sol";
import "../modules/StreamModuleBase.sol";
import "../parameters/StreamGasParameterHost.sol";
import "../../interfaces/stream/finality/IStreamArtworkFinalityRecovery.sol";
import "../../interfaces/stream/finality/IStreamFinalityRecoveryIntentStorage.sol";
import "../../interfaces/stream/finality/IStreamFinalityRecoveryGovernanceBinding.sol";
import "../../interfaces/stream/finality/StreamFinalityRecoveryDeploymentTypes.sol";

/// @notice Canonical Executor-only appended recovery and bounded permissionless refresh.
/// @dev First profile uses artist-sanctioned original records. New inherited RELEASE/SEASON/VIEW
///      and adjudicated artist supersession remain unsupported. Immutable raw execution records
///      are separate from current route health, authority and evidence readiness.
contract StreamArtworkFinalityRecovery is
    StreamModuleBase,
    StreamGasParameterHost,
    IStreamArtworkFinalityRecovery,
    IStreamFinalityRecoveryIntentStorage,
    IStreamFinalityRecoveryEvents
{
    error FinalityRecoveryCallerNotExecutor(address caller);
    error FinalityRecoveryCalldataTooLarge(uint256 actual, uint256 maximum);
    error FinalityRecoveryModuleConfigurationInvalid();
    error FinalityRecoveryRefreshReentrancy();

    bytes32 public constant GGP_RECOVERY_DEPENDENCY_READ_GAS =
        keccak256("6529STREAM_GGP_RECOVERY_DEPENDENCY_READ_GAS");
    bytes32 public constant GGP_RECOVERY_ARTIST_READ_GAS =
        keccak256("6529STREAM_GGP_RECOVERY_ARTIST_READ_GAS");
    bytes32 public constant GGP_RECOVERY_OWNER_READ_GAS =
        keccak256("6529STREAM_GGP_RECOVERY_OWNER_READ_GAS");
    address public immutable core;
    address public immutable originalFinalityRegistry;
    address public immutable artistEvidence;
    address public immutable ownerEvidence;
    bytes32 public immutable configurationHash;
    StreamFinalityRecoveryBindings.Bound private _bindings;
    StreamFinalityRecoveryIntentState.State private _intents;
    StreamFinalityRecoveryState.State private _state;
    bool private _entered;

    constructor(
        StreamFinalityRecoveryTargets memory targets,
        GasParameterConfig[3] memory caps,
        StreamFinalityRecoveryDeploymentConfiguration memory deployment
    )
        StreamGasParameterHost(targets.executor)
        StreamModuleBase(
            keccak256("6529stream.artwork-finality-recovery.schema.v1"),
            address(0),
            deployment.deploymentManifestHash,
            deployment.manifestURI,
            deployment.manifestHash
        )
    {
        if (
            deployment.deploymentManifestHash == 0 || deployment.manifestHash == 0
                || bytes(deployment.manifestURI).length > 2048
        ) revert FinalityRecoveryModuleConfigurationInvalid();
        bytes32[3] memory names = [
            keccak256("RECOVERY_DEPENDENCY_READ_GAS"),
            keccak256("RECOVERY_ARTIST_READ_GAS"),
            keccak256("RECOVERY_OWNER_READ_GAS")
        ];
        for (uint256 i; i < 3; ++i) {
            if (
                keccak256(bytes(caps[i].name)) != names[i] || caps[i].floor < 50000
                    || caps[i].failureClass != 2 || caps[i].genesisValue > type(uint256).max / 64
            ) revert FinalityRecoveryModuleConfigurationInvalid();
            _registerGasParameter(caps[i]);
        }
        core = targets.core;
        originalFinalityRegistry = targets.originalFinality;
        artistEvidence = targets.artist;
        ownerEvidence = targets.ownerEvidence;
        _bindings = StreamFinalityRecoveryBindings.admit(
            StreamFinalityRecoveryBindings.Inputs(
                targets.core,
                targets.executor,
                targets.originalFinality,
                targets.artist,
                targets.ownerEvidence,
                caps[0].genesisValue
            )
        );
        configurationHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_RECOVERY_CONFIGURATION_V1"),
                block.chainid,
                address(this),
                _bindings,
                caps,
                deployment
            )
        );
    }
    modifier mutation() {
        if (_entered) revert FinalityRecoveryRefreshReentrancy();
        if (msg.data.length > 24575) revert FinalityRecoveryCalldataTooLarge(msg.data.length, 24575);
        _entered = true;
        _;
        _entered = false;
    }

    function streamModuleType() public pure override returns (bytes32) {
        return keccak256("STREAM_ARTWORK_FINALITY_RECOVERY");
    }

    function streamModuleVersion() public pure override returns (bytes32) {
        return keccak256("6529stream.artwork-finality-recovery.v1");
    }

    function streamModuleInterfaceId() public pure override returns (bytes4) {
        return type(IStreamArtworkFinalityRecovery).interfaceId;
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamArtworkFinalityRecovery).interfaceId
            || id == type(IStreamFinalityRecoveryIntentStorage).interfaceId
            || id == type(IStreamArtistRecoveryIntent).interfaceId
            || id == type(IStreamFinalityRecoveryGovernanceBinding).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId || super.supportsInterface(id);
    }

    function stageFinalityRecoveryManifest(bytes calldata data)
        external
        override
        mutation
        returns (bytes32)
    {
        return StreamFinalityRecoveryIntentState.stage(_intents, data);
    }

    function finalityRecoveryManifestStored(bytes32 hash) external view override returns (bool) {
        if (_intents.manifests[hash].pointer == address(0)) return false;
        StreamFinalityRecoveryIntentState.manifestBytes(_intents, hash);
        return true;
    }

    function finalityRecoveryManifestBytes(bytes32 hash)
        external
        view
        override
        returns (bytes memory)
    {
        return StreamFinalityRecoveryIntentState.manifestBytes(_intents, hash);
    }

    function finalityRecoveryIntentBytes(StreamFinalityRecoveryRequest calldata request)
        external
        view
        override
        returns (bytes memory)
    {
        return StreamFinalityRecoveryHashes.intentBytes(_environment(), request);
    }

    function registerFinalityRecoveryIntent(StreamFinalityRecoveryRequest calldata request)
        external
        override
        mutation
        returns (bytes32)
    {
        return StreamFinalityRecoveryIntentState.register(_intents, _environment(), request);
    }

    function finalityRecoveryIntentRequest(bytes32 hash)
        external
        view
        override
        returns (StreamFinalityRecoveryRequest memory)
    {
        return StreamFinalityRecoveryIntentState.requestFor(_intents, hash);
    }

    function requireArtistRecoveryIntent(
        StreamFinalityScope calldata scope,
        bytes32 originalHash,
        bytes32 manifestHash
    ) external view returns (IStreamArtistRecoveryIntent.Facts memory facts) {
        StreamFinalityRecoveryRequest memory request =
            StreamFinalityRecoveryIntentState.requestFor(_intents, manifestHash);
        if (
            request.expectedOriginalFinalityRecordHash != originalHash
                || keccak256(abi.encode(request.scope)) != keccak256(abi.encode(scope))
        ) revert StreamFinalityRecoveryIntentState.FinalityRecoveryManifestInvalid();
        (facts,) = _prepare(request);
    }

    function executeFinalityRecovery(StreamFinalityRecoveryRequest calldata request)
        external
        override
        mutation
    {
        if (msg.sender != governanceAuthority) {
            revert FinalityRecoveryCallerNotExecutor(msg.sender);
        }
        (
            IStreamArtistRecoveryIntent.Facts memory facts,
            StreamFinalityRecoveryRoutes.Selection memory selection
        ) = _prepare(request);
        StreamFinalityRecoveryBindings.Bound memory b = _bound();
        bytes32 id = StreamFinalityRecoveryExecution.context(b, facts);
        if (_state.records[id].executed) {
            revert StreamFinalityRecoveryState.FinalityRecoveryActionConsumed(id);
        }
        StreamFinalityRecoveryEvidenceSnapshot memory evidence =
            StreamFinalityRecoveryExecution.evidence(
                b,
                request,
                id,
                selection.artistId,
                gasParameter(GGP_RECOVERY_ARTIST_READ_GAS),
                gasParameter(GGP_RECOVERY_OWNER_READ_GAS)
            );
        // Evidence may call back into the view preparation path. Repeat exact current facts before
        // append; every external observation is static and mutation remains under this host lock.
        {
            (
                IStreamArtistRecoveryIntent.Facts memory again,
                StreamFinalityRecoveryRoutes.Selection memory selectedAgain
            ) = _prepare(request);
            if (
                keccak256(abi.encode(facts, selection))
                        != keccak256(abi.encode(again, selectedAgain))
                    || StreamFinalityRecoveryExecution.context(b, again) != id
            ) revert StreamFinalityRecoveryExecution.FinalityRecoveryTransitionContextMismatch();
        }
        _append(request, evidence, selection.originalScope, id, b.inputs.readGas);
    }

    function _append(
        StreamFinalityRecoveryRequest calldata request,
        StreamFinalityRecoveryEvidenceSnapshot memory evidence,
        StreamFinalityScope memory originalScope,
        bytes32 id,
        uint256 cap
    ) private {
        bytes memory high = StreamFinalityRecoveryBindings.fixedRead(
            core, abi.encodeCall(IStreamFinalityRecoveryCore.lastAllocatedTokenId, ()), 32, cap
        );
        uint256 highWater = abi.decode(high, (uint256));
        StreamFinalityRecoveryState.append(
            _state,
            request,
            evidence,
            StreamFinalityRecoveryState.Admission(
                id, originalScope, request.expectedOldRouteHash, highWater
            )
        );
    }

    function _prepare(StreamFinalityRecoveryRequest memory request)
        private
        view
        returns (
            IStreamArtistRecoveryIntent.Facts memory facts,
            StreamFinalityRecoveryRoutes.Selection memory selected
        )
    {
        StreamFinalityRecoveryBindings.Bound memory b = _bound();
        StreamFinalityRecoveryBindings.current(b, address(this));
        StreamFinalityRecoveryIntentState.validate(_intents, _environment(), request);
        selected = StreamFinalityRecoveryRoutes.resolve(
            _state, b, request.replacementRoute.componentType, request.scope
        );
        if (selected.originalFinalityRecordHash == 0) {
            revert StreamFinalityRecoveryRoutes.FinalityRecoveryOriginalRecordMissing(StreamFinalityRecoveryHashes.scopeKey(
                    request.scope
                ));
        }
        if (!selected.pinned) {
            revert StreamFinalityRecoveryRoutes.FinalityRecoveryRouteMissing(request.replacementRoute
                .componentType);
        }
        if (selected.originalFinalityRecordHash != request.expectedOriginalFinalityRecordHash) {
            revert StreamFinalityRecoveryState.FinalityRecoveryOriginalRecordMismatch(
                request.expectedOriginalFinalityRecordHash, selected.originalFinalityRecordHash
            );
        }
        // A first inherited selection was checked by resolve. Historical exact heads deliberately
        // skip that dependency, so new preparation must recheck the admitted inherited relation.
        if (selected.exactHead != 0) {
            StreamFinalityRecoveryRoutes.requireInheritedFamily(
                b, selected.originalScope, request.scope
            );
        }
        if (selected.exactHead != request.expectedPredecessorRecoveryId) {
            revert StreamFinalityRecoveryState.FinalityRecoveryPredecessorMismatch(
                request.expectedPredecessorRecoveryId, selected.exactHead
            );
        }
        bytes32 oldHash = StreamFinalityRecoveryHashes.componentRouteHash(selected.route);
        if (oldHash != request.expectedOldRouteHash) {
            revert StreamFinalityRecoveryState.FinalityRecoveryOldRouteMismatch(
                request.expectedOldRouteHash, oldHash
            );
        }
        if (selected.exactGeneration == type(uint64).max) {
            revert StreamFinalityRecoveryState.FinalityRecoveryGenerationOverflow(StreamFinalityRecoveryHashes.scopeKey(
                    request.scope
                ));
        }
        StreamFinalityRecoveryRoutes.requireReplacement(
            request.replacementRoute, request.scope, selected.route.componentType, b.inputs.readGas
        );
        facts = IStreamArtistRecoveryIntent.Facts(
            StreamFinalityRecoveryHashes.scopeHash(_environment(), request.scope),
            StreamFinalityRecoveryHashes.oldValueHash(
                request.scope,
                selected.originalFinalityRecordHash,
                selected.exactHead,
                selected.exactGeneration,
                oldHash
            ),
            StreamFinalityRecoveryHashes.newValueHash(
                _environment(), selected.exactGeneration + 1, request
            ),
            keccak256(abi.encode(request))
        );
    }

    function finalityRecoveryRecord(bytes32 id)
        external
        view
        override
        returns (StreamFinalityRecoveryRecord memory)
    {
        return _state.records[id];
    }

    function activeFinalityRecovery(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (bytes32 id, bytes32 routeHash, uint64 generation)
    {
        StreamFinalityRecoveryState.Head storage h =
            _state.heads[StreamFinalityRecoveryHashes.scopeKey(scope)];
        return (h.recoveryId, _state.records[h.recoveryId].recoveryRouteHash, h.generation);
    }

    function resolvedFinalityRoute(bytes32 kind, StreamFinalityScope calldata scope)
        external
        view
        override
        returns (bool, address, bytes32, bytes32, bytes32)
    {
        StreamFinalityRecoveryRoutes.Selection memory s =
            StreamFinalityRecoveryRoutes.resolve(_state, _bound(), kind, scope);
        return (
            s.pinned,
            s.route.component,
            s.pinned ? StreamFinalityRecoveryHashes.componentRouteHash(s.route) : bytes32(0),
            s.originalFinalityRecordHash,
            s.recoveryId
        );
    }

    function finalityRecoveryRouteStatus(bytes32 kind, StreamFinalityScope calldata scope)
        external
        view
        override
        returns (bool, bool, bytes32, bytes32)
    {
        StreamFinalityRecoveryBindings.Bound memory b = _bound();
        StreamFinalityRecoveryRoutes.Selection memory s =
            StreamFinalityRecoveryRoutes.resolve(_state, b, kind, scope);
        return (
            s.pinned,
            s.pinned
                && StreamFinalityRecoveryRoutes.matches(s.route, s.routeScope, b.inputs.readGas),
            s.pinned ? StreamFinalityRecoveryHashes.componentRouteHash(s.route) : bytes32(0),
            s.recoveryId
        );
    }

    function finalityRecoveryRefreshPlan(bytes32 id)
        external
        view
        override
        returns (StreamFinalityRecoveryRefreshPlan memory)
    {
        return _state.plans[id];
    }

    function continueFinalityRecoveryRefresh(StreamFinalityScope calldata scope, bytes32 id)
        external
        override
        mutation
    {
        StreamFinalityRecoveryBindings.Bound memory b = _bound();
        if (block.chainid != b.chainId) {
            revert StreamFinalityRecoveryBindings.FinalityRecoveryBindingInvalid(address(0));
        }
        StreamFinalityRecoveryBindings.selected(
            core,
            keccak256("ARTWORK_FINALITY_RECOVERY"),
            address(this),
            streamModuleType(),
            streamModuleInterfaceId(),
            b.inputs.readGas
        );
        StreamFinalityRecoveryState.continuePlan(_state, scope, id, core, b.codeHashes[0]);
    }

    function incompleteFinalityRecoveryRefreshPlanCount() external view override returns (uint256) {
        return _state.incompleteCount;
    }

    function assertNoIncompleteFinalityRecoveryRefreshPlans() external view override {
        StreamFinalityRecoveryState.assertComplete(_state);
    }

    function finalityRecoveryScopeHash(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (bytes32)
    {
        StreamFinalityRecoveryIntentState.shape(scope);
        return StreamFinalityRecoveryHashes.scopeHash(_environment(), scope);
    }

    function finalityRecoveryOldValueHash(StreamFinalityRecoveryRequest calldata request)
        external
        view
        override
        returns (bytes32)
    {
        (IStreamArtistRecoveryIntent.Facts memory facts,) = _prepare(request);
        return facts.oldValueHash;
    }

    function finalityRecoveryNewValueHash(StreamFinalityRecoveryRequest calldata request)
        external
        view
        override
        returns (bytes32)
    {
        (IStreamArtistRecoveryIntent.Facts memory facts,) = _prepare(request);
        return facts.newValueHash;
    }

    function _environment() private view returns (StreamFinalityRecoveryHashes.Environment memory) {
        return StreamFinalityRecoveryHashes.Environment(block.chainid, address(this));
    }

    function _bound() private view returns (StreamFinalityRecoveryBindings.Bound memory b) {
        b = _bindings;
        b.inputs.readGas = gasParameter(GGP_RECOVERY_DEPENDENCY_READ_GAS);
    }
}
