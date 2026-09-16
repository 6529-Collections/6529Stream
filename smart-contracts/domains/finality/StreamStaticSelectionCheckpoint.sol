// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamStaticSelectionCheckpoint as C
} from "../../interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    IStreamStaticMetadataRouter as S
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    IStreamRendererRegistry as V
} from "../../interfaces/stream/metadata/IStreamRendererRegistry.sol";
import { IStreamRenderer as R } from "../../interfaces/stream/metadata/IStreamRenderer.sol";
import { IStreamMetadataRouter } from "../../interfaces/stream/metadata/IStreamMetadataRouter.sol";
import { IStreamCoreIdentity } from "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import { IStreamCorePointers } from "../../interfaces/stream/core/IStreamCorePointers.sol";
import { StreamCorePointerState } from "../../core/StreamCoreExternalReads.sol";
import {
    IStreamFinalityScopeMembership as M
} from "../../interfaces/stream/finality/IStreamFinalityScopeMembership.sol";
import {
    StreamScopeMembershipFacts
} from "../../interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    StreamFinalityScope
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import { StreamGasParameterHost } from "../parameters/StreamGasParameterHost.sol";
import {
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

/// @notice Permissionless bounded enumeration of every actual resolved STATIC selection in a scope.
/// @dev All token identifiers come from the fixed authoritative membership host. Every appended
/// config is frozen and retains its original Router source snapshot. A coarse collection-input
/// commitment deliberately invalidates an in-progress/current candidate after ANY collection
/// config/source change; historical rows are retained and are not reinterpreted as current.
/// No readiness, renderer opcode conformance, media-byte fixity or artwork-finality authority is added.
contract StreamStaticSelectionCheckpoint is C, StreamGasParameterHost, IERC165 {
    address public immutable override core;
    address public immutable override metadataRouter;
    address public immutable override scopeMembership;
    address public immutable metadataHost;
    bytes32 public immutable coreCodeHash;
    bytes32 public immutable routerCodeHash;
    bytes32 public immutable membershipCodeHash;
    bytes32 public immutable metadataCodeHash;
    uint256 public immutable deploymentChainId;
    bytes32 public constant READ_GAS = keccak256("6529STREAM_GGP_STATIC_CHECKPOINT_READ_GAS");
    bytes32 public constant PROFILE = keccak256("6529STREAM_STATIC_SELECTION_CHECKPOINT_V1");
    bytes32 public constant ROW_DOMAIN = keccak256("6529STREAM_STATIC_SELECTION_ROW_V1");
    bytes32 public constant CHAIN_DOMAIN = keccak256("6529STREAM_STATIC_SELECTION_CHAIN_V1");
    uint256 public constant MAX_APPEND = 16;
    mapping(bytes32 => Plan) private _plans;
    mapping(bytes32 => mapping(uint256 => TokenSelection)) private _selections;
    mapping(bytes32 => address[]) private _dependencies;
    mapping(bytes32 => mapping(address => bytes32)) private _dependencyPins;

    constructor(
        address core_,
        address router_,
        address membership_,
        address executor,
        GasParameterConfig memory gasConfig
    ) StreamGasParameterHost(executor) {
        if (
            core_.code.length == 0 || router_.code.length == 0 || membership_.code.length == 0
                || _registerGasParameter(gasConfig) != READ_GAS || gasConfig.failureClass != 1
        ) revert StaticCheckpointConfiguration();
        core = core_;
        metadataRouter = router_;
        scopeMembership = membership_;
        coreCodeHash = core_.codehash;
        routerCodeHash = router_.codehash;
        membershipCodeHash = membership_.codehash;
        deploymentChainId = block.chainid;
        if (
            _address(router_, abi.encodeWithSignature("core()")) != core_
                || _address(membership_, abi.encodeCall(M.core, ())) != core_
        ) revert StaticCheckpointConfiguration();
        metadataHost = _address(membership_, abi.encodeCall(M.metadataHost, ()));
        if (
            metadataHost.code.length == 0
                || _address(metadataHost, abi.encodeWithSignature("core()")) != core_
        ) revert StaticCheckpointConfiguration();
        metadataCodeHash = metadataHost.codehash;
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId || id == type(C).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId;
    }

    function begin(StreamFinalityScope calldata scope) external override returns (bytes32 id) {
        _pins();
        StreamScopeMembershipFacts memory f = _membership(scope);
        if (f.tokenCount == 0 || f.tokenCount > type(uint64).max) {
            revert StaticCheckpointConfiguration();
        }
        bytes32 input = _collectionState(scope.collectionId);
        id = keccak256(
            abi.encode(
                PROFILE,
                deploymentChainId,
                address(this),
                core,
                metadataRouter,
                scopeMembership,
                scope,
                f.membershipHash,
                input
            )
        );
        if (_plans[id].tokenCount == 0) {
            _plans[id] = Plan(scope, f.membershipHash, input, uint64(f.tokenCount), 0, 0);
            emit StaticSelectionStarted(1, id, _plans[id]);
        }
    }

    function append(bytes32 id, uint256 maximumTokens) external override {
        Plan storage p = _plans[id];
        _current(id, p);
        if (maximumTokens == 0 || maximumTokens > MAX_APPEND || p.nextIndex == p.tokenCount) {
            revert StaticCheckpointBatch(maximumTokens);
        }
        uint256 end = uint256(p.nextIndex) + maximumTokens;
        if (end > p.tokenCount) end = p.tokenCount;
        for (uint256 i = p.nextIndex; i < end; ++i) {
            uint256 token = abi.decode(
                _read(scopeMembership, abi.encodeCall(M.scopeTokenAt, (p.scope, i)), 32, true),
                (uint256)
            );
            TokenSelection memory selected = _selection(p.scope.collectionId, token);
            bytes32 row = keccak256(
                abi.encode(ROW_DOMAIN, deploymentChainId, core, metadataRouter, selected)
            );
            _selections[id][i] = selected;
            _noteDependency(id, selected.selection.registry, selected.selection.registryCodeHash);
            _noteDependency(id, selected.selection.renderer, selected.selection.rendererCodeHash);
            for (uint256 j; j < 6; ++j) {
                if (selected.sources[j] != address(0)) {
                    _noteDependency(id, selected.sources[j], selected.sourceCodeHashes[j]);
                }
            }
            p.selectionRoot = keccak256(abi.encode(CHAIN_DOMAIN, p.selectionRoot, i, row));
            ++p.nextIndex;
            emit StaticSelectionAppended(1, id, uint64(i), selected, row);
        }
        // Static calls cannot mutate the sources; a second exact join also makes the candidate boundary explicit.
        _current(id, p);
        if (p.nextIndex == p.tokenCount) {
            emit StaticSelectionCompleted(1, id, p.selectionRoot, p.tokenCount);
        }
    }

    function checkpoint(bytes32 id) external view override returns (Plan memory) {
        return _plans[id];
    }

    function selectionAt(bytes32 id, uint256 index)
        external
        view
        override
        returns (TokenSelection memory)
    {
        if (index >= _plans[id].nextIndex) revert StaticCheckpointIndex(index);
        return _selections[id][index];
    }

    function requireCurrentCheckpoint(bytes32 id) external view override returns (Plan memory) {
        Plan storage p = _plans[id];
        _current(id, p);
        if (p.nextIndex != p.tokenCount || p.selectionRoot == 0) {
            revert StaticCheckpointIncomplete(id);
        }
        return p;
    }

    function _current(bytes32 id, Plan storage p) private view {
        if (p.tokenCount == 0) revert StaticCheckpointUnknown(id);
        _pins();
        // Recheck every distinct recorded runtime, including renderers used only by token overrides.
        // This is a finite complete read, not a promise that arbitrary dependency counts fit one cap.
        for (uint256 i; i < _dependencies[id].length; ++i) {
            address target = _dependencies[id][i];
            _pin(target, _dependencyPins[id][target]);
        }
        StreamScopeMembershipFacts memory f = _membership(p.scope);
        if (
            f.membershipHash != p.membershipHash || f.tokenCount != p.tokenCount
                || _collectionState(p.scope.collectionId) != p.collectionStateHash
        ) revert StaticCheckpointInputChanged(id);
    }

    function _noteDependency(bytes32 id, address target, bytes32 hash) private {
        bytes32 old = _dependencyPins[id][target];
        if (old == 0) {
            _dependencyPins[id][target] = hash;
            _dependencies[id].push(target);
        } else if (old != hash) {
            revert StaticCheckpointDependency(target);
        }
    }

    function _membership(StreamFinalityScope memory scope)
        private
        view
        returns (StreamScopeMembershipFacts memory f)
    {
        bytes memory raw = _read(
            scopeMembership, abi.encodeCall(M.requireScopeMembership, (scope)), 256, true
        );
        f = abi.decode(raw, (StreamScopeMembershipFacts));
        if (
            f.scopeSubject != StreamMetadataSubjects.scopeSubject(deploymentChainId, core, scope)
                || f.membershipHash == 0
        ) revert StaticCheckpointConfiguration();
    }

    function _collectionState(uint256 id) private view returns (bytes32) {
        bytes memory activation =
            _read(metadataRouter, abi.encodeCall(S.staticMetadataActivation, (id)), 96, true);
        (bytes32 originalDefault, uint64 revision,) =
            abi.decode(activation, (bytes32, uint64, bytes32));
        if (originalDefault == 0 || revision == 0) revert StaticCheckpointConfiguration();
        bytes memory raw =
            _read(metadataRouter, abi.encodeCall(S.collectionMetadataConfig, (id)), 8192, false);
        S.ConfigRecord memory config = abi.decode(raw, (S.ConfigRecord));
        if (
            keccak256(raw) != keccak256(abi.encode(config)) || config.recordHash == 0
                || config.collectionId != id
        ) revert StaticCheckpointConfiguration();
        raw = _read(metadataRouter, abi.encodeCall(S.staticRenderSource, (id)), 16000, false);
        S.RawSource memory source = abi.decode(raw, (S.RawSource));
        if (
            keccak256(raw) != keccak256(abi.encode(source)) || source.chainId != deploymentChainId
                || !source.configured
        ) revert StaticCheckpointConfiguration();
        return keccak256(abi.encode(PROFILE, activation, config, source));
    }

    function _selection(uint256 collectionId, uint256 token)
        private
        view
        returns (TokenSelection memory row)
    {
        (bool exists, uint256 id, uint256 serial,) = abi.decode(
            _read(
                core,
                abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (token)),
                128,
                true
            ),
            (bool, uint256, uint256, bool)
        );
        if (!exists || token == 0 || id != collectionId || serial == 0) {
            revert StaticCheckpointToken(token);
        }
        bytes memory raw =
            _read(metadataRouter, abi.encodeCall(S.resolvedMetadataConfig, (token)), 8192, false);
        S.ConfigRecord memory config = abi.decode(raw, (S.ConfigRecord));
        if (
            keccak256(raw) != keccak256(abi.encode(config)) || config.collectionId != id
                || !config.config.frozen || config.sourceSnapshotHash == 0 || config.recordHash == 0
                || config.level == 0 || (config.tokenId != 0 && config.tokenId != token)
                || config.config.renderer != config.selection.renderer
        ) revert StaticCheckpointToken(token);
        row.tokenId = token;
        row.configRecordHash = config.recordHash;
        row.configHash = keccak256(raw);
        row.sourceSnapshotHash = config.sourceSnapshotHash;
        row.selection = config.selection;
        config.recordHash = 0;
        if (
            keccak256(
                    abi.encode(
                        keccak256("6529STREAM_STATIC_METADATA_CONFIG_RECORD_V1"),
                        core,
                        metadataRouter,
                        config
                    )
                ) != row.configRecordHash
        ) revert StaticCheckpointToken(token);
        raw = _read(
            metadataRouter,
            abi.encodeCall(S.staticRenderSourceForConfig, (id, row.configRecordHash)),
            24000,
            false
        );
        (S.RawSource memory source, R.MetadataConfig memory selectedConfig) =
            abi.decode(raw, (S.RawSource, R.MetadataConfig));
        if (
            keccak256(raw) != keccak256(abi.encode(source, selectedConfig))
                || keccak256(abi.encode(selectedConfig)) != keccak256(abi.encode(config.config))
                || !source.configured || source.chainId != deploymentChainId
                || keccak256(abi.encode(keccak256("6529STREAM_STATIC_SOURCE_SNAPSHOT_V1"), source))
                    != row.sourceSnapshotHash
        ) revert StaticCheckpointToken(token);
        row.rawSourceHash = keccak256(abi.encode(source));
        _pin(row.selection.registry, row.selection.registryCodeHash);
        _pin(row.selection.renderer, row.selection.rendererCodeHash);
        (address retained, bytes32 codeHash) = abi.decode(
            _read(
                row.selection.registry,
                abi.encodeCall(V.requireRetained, (row.selection.versionKey)),
                64,
                true
            ),
            (address, bytes32)
        );
        V.Version memory version = abi.decode(
            _read(
                row.selection.registry,
                abi.encodeCall(V.version, (row.selection.versionKey)),
                288,
                true
            ),
            (V.Version)
        );
        if (
            !version.exists || retained != row.selection.renderer
                || codeHash != row.selection.rendererCodeHash || version.renderer != retained
                || version.runtimeHash != codeHash
                || version.readSetHash != row.selection.readSetHash
                || version.registrationHash != row.selection.registrationHash
        ) revert StaticCheckpointToken(token);
        (row.sources, row.sourceCodeHashes) = abi.decode(
            _read(retained, abi.encodeWithSignature("sourceBindings()"), 384, true),
            (address[6], bytes32[6])
        );
        if (
            row.sources[0] != core || row.sources[1] != metadataRouter
                || row.sources[2] != metadataHost
                || row.sources[3]
                    != _address(
                        core, abi.encodeCall(IStreamCoreIdentity.coordinatorAtMint, (token))
                    )
        ) revert StaticCheckpointToken(token);
        for (uint256 i; i < 6; ++i) {
            if (i >= 4 && row.sources[i] == address(0) && row.sourceCodeHashes[i] == 0) continue;
            _pin(row.sources[i], row.sourceCodeHashes[i]);
        }
    }

    function _pins() private view {
        if (block.chainid != deploymentChainId) revert StaticCheckpointConfiguration();
        _pin(core, coreCodeHash);
        _pin(metadataRouter, routerCodeHash);
        _pin(scopeMembership, membershipCodeHash);
        _pin(metadataHost, metadataCodeHash);
        StreamCorePointerState memory p = abi.decode(
            _read(
                core,
                abi.encodeCall(
                    IStreamCorePointers.getSatellitePointer, (keccak256("METADATA_ROUTER"))
                ),
                320,
                true
            ),
            (StreamCorePointerState)
        );
        if (
            p.target != metadataRouter || p.codeHash != routerCodeHash
                || p.moduleType != keccak256("METADATA_ROUTER")
                || p.interfaceId != type(IStreamMetadataRouter).interfaceId
                || p.registry == address(0) || p.registryStatus != 1 || p.moduleManifestHash == 0
                || p.deploymentManifestHash == 0 || p.revision == 0
        ) revert StaticCheckpointDependency(metadataRouter);
    }

    function _pin(address target, bytes32 hash) private view {
        if (target.code.length == 0 || target.codehash != hash) {
            revert StaticCheckpointDependency(target);
        }
    }

    function _address(address target, bytes memory input) private view returns (address) {
        return abi.decode(_read(target, input, 32, true), (address));
    }

    function _read(address target, bytes memory input, uint256 maximum, bool exact)
        private
        view
        returns (bytes memory out)
    {
        uint256 cap = _gasParameterValue(READ_GAS);
        if (cap == 0 || cap > type(uint256).max / 64 || gasleft() <= cap + cap / 63 + 100000) {
            revert StaticCheckpointRead(target, bytes4(input));
        }
        out = new bytes(maximum);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(out, 32), maximum)
            size := returndatasize()
        }
        if (!ok || size > maximum || (exact && size != maximum)) {
            revert StaticCheckpointRead(target, bytes4(input));
        }
        assembly ("memory-safe") { mstore(out, size) }
    }
}
