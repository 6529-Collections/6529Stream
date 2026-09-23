// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPolicyContentObservationV2 as Observation
} from "./StreamPolicyContentObservationV2.sol";
import {
    IStreamPolicyContentCheckpointV2 as C
} from "../../interfaces/stream/finality/IStreamPolicyContentCheckpointV2.sol";
import {
    IStreamStaticSelectionCheckpoint as S
} from "../../interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";

import {
    IStreamFinalityEntropyPolicySourceSet as E
} from "../../interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";

import {
    StreamScopeMembershipFacts
} from "../../interfaces/stream/finality/StreamScopeMembershipTypes.sol";

import { StreamTokenContentTree as Tree } from "../metadata/StreamTokenContentTree.sol";
import { StreamRendererCalls as Calls } from "../metadata/StreamRendererCalls.sol";
import { StreamGasParameterHost } from "../parameters/StreamGasParameterHost.sol";
import {
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import {
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import { StreamStaticContentBytes as Bytes } from "./StreamStaticContentBytes.sol";
import { StreamPolicyContentBytesV2 as TerminalBytes } from "./StreamPolicyContentBytesV2.sol";
import { StreamOnchainContentBytes as Image } from "./StreamOnchainContentBytes.sol";

/// @notice Permissionless complete collection V2 output checkpoint for terminal and finalized policy rows.
/// @dev Live diagnostics and lifecycle are included literally. Every current read re-renders all
/// completed rows; pins alone cannot establish current output. Historical hashes remain readable.
/// Exact output bytes still require a separate preserved artifact and authoritative publication.
contract StreamPolicyContentCheckpointV2 is C, StreamGasParameterHost, IERC165 {
    address public immutable override core;
    address public immutable override metadataRouter;
    address public immutable override selectionCheckpoint;
    address public immutable override entropySourceSet;
    address public immutable override terminalReadiness;
    bytes32 public immutable entropySourceSetCodeHash;
    bytes32 public immutable terminalReadinessCodeHash;
    bytes32 public immutable coreCodeHash;
    bytes32 public immutable routerCodeHash;
    bytes32 public immutable selectionCodeHash;
    uint256 public immutable deploymentChainId;
    bytes32 public constant PROFILE = keccak256("6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2");
    bytes32 public constant LEAF_CHAIN = keccak256("6529STREAM_POLICY_CONTENT_LEAVES_V2");
    bytes32 public constant OUTPUT_CHAIN = keccak256("6529STREAM_POLICY_FULL_OUTPUTS_V2");
    bytes32 public constant READ_GAS = keccak256("6529STREAM_GGP_STATIC_CONTENT_READ_GAS");
    bytes32 public constant RENDER_GAS = keccak256("6529STREAM_GGP_STATIC_CONTENT_RENDER_GAS");
    uint256 public constant MAX_BYTES = 16777216;
    uint256 public constant MAX_APPEND = 4;
    mapping(bytes32 => Plan) private _plans;
    mapping(bytes32 => mapping(uint256 => Output)) private _outputs;
    mapping(bytes32 => mapping(uint256 => bytes32)) private _frontier;

    constructor(
        address selection,
        address policySourceSet,
        address readiness,
        address executor,
        GasParameterConfig memory readGas,
        GasParameterConfig memory renderGas
    ) StreamGasParameterHost(executor) {
        if (
            selection.code.length == 0 || _registerGasParameter(readGas) != READ_GAS
                || _registerGasParameter(renderGas) != RENDER_GAS || readGas.failureClass != 2
                || renderGas.failureClass != 2
        ) {
            revert InvalidStaticContentConfiguration();
        }
        selectionCheckpoint = selection;
        selectionCodeHash = selection.codehash;
        core = abi.decode(_read(selection, abi.encodeCall(S.core, ()), 32, true, false), (address));
        metadataRouter = abi.decode(
            _read(selection, abi.encodeCall(S.metadataRouter, ()), 32, true, false), (address)
        );
        if (core.code.length == 0 || metadataRouter.code.length == 0) {
            revert InvalidStaticContentConfiguration();
        }
        coreCodeHash = core.codehash;
        routerCodeHash = metadataRouter.codehash;
        deploymentChainId = block.chainid;
        entropySourceSet = policySourceSet;
        terminalReadiness = readiness;
        entropySourceSetCodeHash = policySourceSet.codehash;
        terminalReadinessCodeHash = readiness.codehash;
        if (
            policySourceSet.code.length == 0 || readiness.code.length == 0
                || abi.decode(
                        _read(policySourceSet, abi.encodeWithSignature("core()"), 32, true, false),
                        (address)
                    ) != core
                || abi.decode(
                        _read(
                            policySourceSet,
                            abi.encodeCall(IERC165.supportsInterface, (type(E).interfaceId)),
                            32,
                            true,
                            false
                        ),
                        (bool)
                    ) != true
                || abi.decode(
                        _read(
                            policySourceSet,
                            abi.encodeWithSignature("SOURCE_SET_PROFILE()"),
                            32,
                            true,
                            false
                        ),
                        (bytes32)
                    ) != keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2")
                || abi.decode(
                        _read(readiness, abi.encodeWithSignature("core()"), 32, true, false),
                        (address)
                    ) != core
                || abi.decode(
                        _read(
                            readiness, abi.encodeWithSignature("metadataRouter()"), 32, true, false
                        ),
                        (address)
                    ) != metadataRouter
                || abi.decode(
                        _read(
                            readiness,
                            abi.encodeWithSignature("entropySourceSet()"),
                            32,
                            true,
                            false
                        ),
                        (address)
                    ) != policySourceSet
        ) revert InvalidStaticContentConfiguration();
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(C).interfaceId || id == type(IERC165).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId;
    }

    function begin(bytes32 selectionId, bytes32 salt) external returns (bytes32 id) {
        S.Plan memory selected = _selection(selectionId);
        bytes32 selectionHash = keccak256(abi.encode(selected));
        bytes32 inventoryHash = _sourceWord(E.originalInventoryHash.selector);
        bytes32 policyChainHash = _sourceWord(E.originalPolicyChainHash.selector);
        id = keccak256(
            abi.encode(
                PROFILE,
                deploymentChainId,
                address(this),
                selectionCheckpoint,
                selectionId,
                selectionHash,
                entropySourceSet,
                entropySourceSetCodeHash,
                terminalReadiness,
                terminalReadinessCodeHash,
                inventoryHash,
                policyChainHash,
                salt
            )
        );
        if (_plans[id].tokenCount == 0) {
            _plans[id] = Plan(
                selectionId,
                selectionHash,
                inventoryHash,
                policyChainHash,
                selected.scope,
                selected.tokenCount,
                0,
                0,
                0,
                0
            );
            emit StaticContentStarted(2, id, salt, _plans[id]);
        }
    }

    function append(bytes32 id, Payload[] calldata payloads) external {
        Plan storage p = _plans[id];
        _current(id, p);
        if (
            payloads.length == 0 || payloads.length > MAX_APPEND
                || payloads.length > p.tokenCount - p.nextIndex
        ) {
            revert StaticContentBatch(payloads.length);
        }
        for (uint256 j; j < payloads.length; ++j) {
            uint256 index = p.nextIndex;
            S.TokenSelection memory row = _row(p.selectionId, index);
            if (
                payloads[j].tokenId != row.tokenId || payloads[j].animation.length == 0
                    || payloads[j].animation.length > MAX_BYTES || payloads[j].image.length > 2048
            ) {
                revert StaticContentPayload(row.tokenId);
            }
            (
                Output memory value,
                bytes memory json,
                bytes memory html,
                bytes memory data,
                string memory imageURI
            ) = _observe(p, row);
            if (
                keccak256(payloads[j].animation) != keccak256(html)
                    || !(value.entropy.terminal
                            ? TerminalBytes.matches(json, html, data)
                            : Bytes.matches(json, html, data))
                    || !Image.matchesImage(json, imageURI, payloads[j].image)
            ) {
                revert StaticContentPayload(row.tokenId);
            }
            value.leaf.imageHash =
                payloads[j].image.length == 0 ? bytes32(0) : keccak256(payloads[j].image);
            if (index != 0 && row.tokenId <= _outputs[id][index - 1].leaf.tokenId) {
                revert StaticContentPayload(row.tokenId);
            }
            _outputs[id][index] = value;
            bytes32 leafHash = Tree.leafHash(deploymentChainId, core, value.leaf);
            _append(id, index, leafHash);
            p.leafChainHash = keccak256(abi.encode(LEAF_CHAIN, p.leafChainHash, index, leafHash));
            p.outputRoot = keccak256(abi.encode(OUTPUT_CHAIN, p.outputRoot, index, value));
            ++p.nextIndex;
            emit StaticContentAppended(2, id, uint64(index), value, leafHash);
        }
        // Only STATICCALLs intervene; repeat the original complete selection join before completion.
        if (keccak256(abi.encode(_selection(p.selectionId))) != p.selectionHash) {
            revert StaticContentChanged(id);
        }
        if (p.nextIndex == p.tokenCount) {
            p.contentRoot = _root(id, p.tokenCount);
            emit StaticContentCompleted(2, id, p.contentRoot, p.outputRoot, p.tokenCount);
        }
    }

    function checkpoint(bytes32 id) external view returns (Plan memory) {
        return _plans[id];
    }

    function outputAt(bytes32 id, uint256 index) external view returns (Output memory) {
        if (index >= _plans[id].nextIndex) revert StaticContentIndex(index);
        return _outputs[id][index];
    }

    function requireCurrentCheckpoint(bytes32 id) external view returns (Plan memory) {
        Plan storage p = _plans[id];
        _current(id, p);
        if (p.nextIndex != p.tokenCount || p.contentRoot == 0 || p.outputRoot == 0) {
            revert StaticContentIncomplete(id);
        }
        return p;
    }

    function _current(bytes32 id, Plan storage p) private view {
        if (
            p.tokenCount == 0 || keccak256(abi.encode(_selection(p.selectionId))) != p.selectionHash
                || p.inventoryHash != _sourceWord(E.originalInventoryHash.selector)
                || p.policyChainHash != _sourceWord(E.originalPolicyChainHash.selector)
        ) revert StaticContentChanged(id);
        // Complete finite read, not a constant-cost promise. Insufficient parent/read budgets fail closed.
        for (uint256 i; i < p.nextIndex; ++i) {
            Output memory saved = _outputs[id][i];
            (Output memory now_,,,,) = _observe(p, _row(p.selectionId, i));
            // Image bytes were already proven at append. Exact same full JSON/source URI commits them.
            now_.leaf.imageHash = saved.leaf.imageHash;
            if (keccak256(abi.encode(saved)) != keccak256(abi.encode(now_))) {
                revert StaticContentChanged(id);
            }
        }
    }

    function _selection(bytes32 id) private view returns (S.Plan memory p) {
        if (block.chainid != deploymentChainId) {
            revert InvalidStaticContentConfiguration();
        }
        if (
            selectionCheckpoint.codehash != selectionCodeHash || core.codehash != coreCodeHash
                || metadataRouter.codehash != routerCodeHash
                || entropySourceSet.codehash != entropySourceSetCodeHash
                || terminalReadiness.codehash != terminalReadinessCodeHash
        ) {
            revert InvalidStaticContentConfiguration();
        }
        p = abi.decode(
            _read(
                selectionCheckpoint,
                abi.encodeCall(S.requireCurrentCheckpoint, (id)),
                288,
                true,
                false
            ),
            (S.Plan)
        );
        if (
            p.tokenCount == 0 || p.nextIndex != p.tokenCount || p.selectionRoot == 0
                || p.scope.scopeType != StreamFinalityScopeType.COLLECTION
        ) {
            revert InvalidStaticContentConfiguration();
        }
        _read(entropySourceSet, abi.encodeCall(E.requireCurrentSourceSet, ()), 0, true, false);
        bytes memory scope =
            _read(entropySourceSet, abi.encodeCall(E.sourceScope, ()), 128, true, false);
        StreamScopeMembershipFacts memory membership = abi.decode(
            _read(entropySourceSet, abi.encodeCall(E.scopeMembershipFacts, ()), 256, true, false),
            (StreamScopeMembershipFacts)
        );
        if (
            keccak256(scope) != keccak256(abi.encode(p.scope))
                || membership.membershipHash != p.membershipHash
                || membership.tokenCount != p.tokenCount
                || _sourceWord(E.originalInventoryHash.selector) == 0
                || _sourceWord(E.originalPolicyChainHash.selector) == 0
        ) revert InvalidStaticContentConfiguration();
    }

    function _sourceWord(bytes4 selector) private view returns (bytes32) {
        return abi.decode(
            _read(entropySourceSet, abi.encodeWithSelector(selector), 32, true, false), (bytes32)
        );
    }

    function _row(bytes32 id, uint256 index) private view returns (S.TokenSelection memory) {
        return abi.decode(
            _read(
                selectionCheckpoint, abi.encodeCall(S.selectionAt, (id, index)), 896, true, false
            ),
            (S.TokenSelection)
        );
    }

    function _observe(Plan storage p, S.TokenSelection memory row)
        private
        view
        returns (
            Output memory value,
            bytes memory json,
            bytes memory html,
            bytes memory data,
            string memory imageURI
        )
    {
        return Observation.observe(
            _gasParameters,
            Observation.Context(
                core,
                metadataRouter,
                entropySourceSet,
                terminalReadiness,
                entropySourceSetCodeHash,
                terminalReadinessCodeHash,
                deploymentChainId,
                PROFILE
            ),
            p,
            row
        );
    }

    function _append(bytes32 id, uint256 index, bytes32 value) private {
        uint256 level;
        while (index & 1 != 0) {
            value = Tree.nodeHash(_frontier[id][level], value);
            delete _frontier[id][level];
            index >>= 1;
            ++level;
        }
        _frontier[id][level] = value;
    }

    function _root(bytes32 id, uint256 count) private view returns (bytes32 value) {
        uint256 level;
        while (count != 0) {
            if (count & 1 != 0) {
                bytes32 left = _frontier[id][level];
                value = value == 0 ? left : Tree.nodeHash(left, value);
            }
            count >>= 1;
            ++level;
        }
    }

    function _read(address target, bytes memory input, uint256 maximum, bool exact, bool render)
        private
        view
        returns (bytes memory output)
    {
        uint256 cap = _gasParameterValue(render ? RENDER_GAS : READ_GAS);
        if (target.code.length == 0) revert Calls.RendererReadFailed(target, bytes4(input));
        if (cap > type(uint256).max / 2) {
            revert StaticContentParentGas(gasleft(), type(uint256).max);
        }
        // Admission must not turn caller starvation into a successful unavailable display.
        // Prepare input and warm the target before the preflight; leave room for EIP-150,
        // STATICCALL overhead and local work. Never clamp the configured dependency budget.
        uint256 required = cap + cap / 63 + 100000;
        uint256 available = gasleft();
        if (available <= required) revert StaticContentParentGas(available, required);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), 0, 0)
            size := returndatasize()
        }
        if (!ok || size > maximum || (exact && size != maximum)) {
            revert Calls.RendererReadFailed(target, bytes4(input));
        }
        output = new bytes(size);
        assembly ("memory-safe") { returndatacopy(add(output, 32), 0, size) }
    }
}
