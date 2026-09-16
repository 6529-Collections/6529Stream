// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamStaticContentCheckpoint as C
} from "../../interfaces/stream/finality/IStreamStaticContentCheckpoint.sol";
import {
    IStreamStaticSelectionCheckpoint as S
} from "../../interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    IStreamStaticMetadataRouter as M
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import { IStreamRenderer as R } from "../../interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamMetadataFullViews as F
} from "../../interfaces/stream/metadata/IStreamMetadataFullViews.sol";
import {
    IStreamStaticEntropySource as E
} from "../../interfaces/stream/metadata/IStreamStaticEntropySource.sol";
import { IStreamCoreIdentity as I } from "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import { IStreamCoreMint as D } from "../../interfaces/stream/core/IStreamCoreMint.sol";
import {
    StreamTokenContentLeaf
} from "../../interfaces/stream/metadata/StreamTokenContentTypes.sol";
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
import { StreamOnchainContentBytes as Image } from "./StreamOnchainContentBytes.sol";

/// @notice Permissionless, ordered complete-scope STATIC-v1 content and full-output checkpoint.
/// @dev Live diagnostics and lifecycle are included literally. Every current read re-renders all
/// completed rows; pins alone cannot establish current output. Historical hashes remain readable.
/// Exact output bytes still require a separate preserved artifact and authoritative publication.
contract StreamStaticContentCheckpoint is C, StreamGasParameterHost, IERC165 {
    address public immutable override core;
    address public immutable override metadataRouter;
    address public immutable override selectionCheckpoint;
    bytes32 public immutable coreCodeHash;
    bytes32 public immutable routerCodeHash;
    bytes32 public immutable selectionCodeHash;
    uint256 public immutable deploymentChainId;
    bytes32 public constant PROFILE = keccak256("6529STREAM_STATIC_CURRENT_FULL_CONTENT_V1");
    bytes32 public constant LEAF_CHAIN = keccak256("6529STREAM_STATIC_CONTENT_LEAVES_V1");
    bytes32 public constant OUTPUT_CHAIN = keccak256("6529STREAM_STATIC_FULL_OUTPUTS_V1");
    bytes32 public constant READ_GAS = keccak256("6529STREAM_GGP_STATIC_CONTENT_READ_GAS");
    bytes32 public constant RENDER_GAS = keccak256("6529STREAM_GGP_STATIC_CONTENT_RENDER_GAS");
    uint256 public constant MAX_BYTES = 16777216;
    uint256 public constant MAX_APPEND = 4;
    mapping(bytes32 => Plan) private _plans;
    mapping(bytes32 => mapping(uint256 => Output)) private _outputs;
    mapping(bytes32 => mapping(uint256 => bytes32)) private _frontier;

    constructor(
        address selection,
        address executor,
        GasParameterConfig memory readGas,
        GasParameterConfig memory renderGas
    ) StreamGasParameterHost(executor) {
        if (
            selection.code.length == 0 || _registerGasParameter(readGas) != READ_GAS
                || _registerGasParameter(renderGas) != RENDER_GAS || readGas.failureClass != 1
                || renderGas.failureClass != 1
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
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(C).interfaceId || id == type(IERC165).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId;
    }

    function begin(bytes32 selectionId, bytes32 salt) external returns (bytes32 id) {
        S.Plan memory selected = _selection(selectionId);
        bytes32 selectionHash = keccak256(abi.encode(selected));
        id = keccak256(
            abi.encode(
                PROFILE,
                deploymentChainId,
                address(this),
                selectionCheckpoint,
                selectionId,
                selectionHash,
                salt
            )
        );
        if (_plans[id].tokenCount == 0) {
            _plans[id] =
                Plan(selectionId, selectionHash, selected.scope, selected.tokenCount, 0, 0, 0, 0);
            emit StaticContentStarted(1, id, salt, _plans[id]);
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
                    || !Bytes.matches(json, html, data)
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
            emit StaticContentAppended(1, id, uint64(index), value, leafHash);
        }
        // Only STATICCALLs intervene; repeat the original complete selection join before completion.
        if (keccak256(abi.encode(_selection(p.selectionId))) != p.selectionHash) {
            revert StaticContentChanged(id);
        }
        if (p.nextIndex == p.tokenCount) {
            p.contentRoot = _root(id, p.tokenCount);
            emit StaticContentCompleted(1, id, p.contentRoot, p.outputRoot, p.tokenCount);
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
                || p.scope.scopeType == StreamFinalityScopeType.VIEW
        ) {
            revert InvalidStaticContentConfiguration();
        }
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
        bytes memory raw = _read(
            metadataRouter,
            abi.encodeCall(M.resolvedMetadataConfig, (row.tokenId)),
            8192,
            false,
            false
        );
        M.ConfigRecord memory config = abi.decode(raw, (M.ConfigRecord));
        if (
            keccak256(raw) != keccak256(abi.encode(config)) || keccak256(raw) != row.configHash
                || config.recordHash != row.configRecordHash
                || config.config.mode != R.MetadataMode.ONCHAIN || !config.config.frozen
                || config.selection.rendererId != keccak256("6529STREAM_RENDERER_V1")
                || config.selection.rendererVersion != keccak256("6529STREAM_STATIC_RENDERER_V1")
        ) revert StaticContentPayload(row.tokenId);
        raw = _read(
            metadataRouter,
            abi.encodeCall(
                M.staticRenderSourceForConfig, (p.scope.collectionId, row.configRecordHash)
            ),
            24000,
            false,
            false
        );
        (M.RawSource memory source, R.MetadataConfig memory selected) =
            abi.decode(raw, (M.RawSource, R.MetadataConfig));
        if (
            keccak256(raw) != keccak256(abi.encode(source, selected))
                || keccak256(abi.encode(source)) != row.rawSourceHash
                || keccak256(abi.encode(selected)) != keccak256(abi.encode(config.config))
        ) revert StaticContentPayload(row.tokenId);
        imageURI = source.imageURI;
        address entropy = abi.decode(
            _read(core, abi.encodeCall(I.coordinatorAtMint, (row.tokenId)), 32, true, false),
            (address)
        );
        if (entropy != row.sources[3] || entropy.codehash != row.sourceCodeHashes[3]) {
            revert StaticContentPayload(row.tokenId);
        }
        bytes memory facts = _read(
            entropy, abi.encodeCall(E.staticTokenRenderFacts, (row.tokenId)), 96, true, false
        );
        (uint8 status,,) = abi.decode(facts, (uint8, bytes32, address));
        if (status != 5) revert StaticContentPayload(row.tokenId);
        raw = _read(core, abi.encodeCall(D.tokenData, (row.tokenId)), 16448, false, false);
        data = abi.decode(raw, (bytes));
        if (data.length > 16384 || keccak256(raw) != keccak256(abi.encode(data))) {
            revert StaticContentPayload(row.tokenId);
        }
        json = bytes(
            Calls.stringResult(
                _read(
                    metadataRouter,
                    abi.encodeCall(F.tokenJSON, (row.tokenId)),
                    MAX_BYTES + 64,
                    false,
                    true
                ),
                MAX_BYTES
            )
        );
        html = bytes(
            Calls.stringResult(
                _read(
                    metadataRouter,
                    abi.encodeCall(F.tokenHTML, (row.tokenId)),
                    MAX_BYTES + 64,
                    false,
                    true
                ),
                MAX_BYTES
            )
        );
        if (html.length == 0 || json.length == 0) revert StaticContentPayload(row.tokenId);
        value.leaf = StreamTokenContentLeaf(
            row.tokenId, keccak256(json), 0, keccak256(html), 0, keccak256(data)
        );
        value.selectionRowHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_STATIC_SELECTION_ROW_V1"),
                deploymentChainId,
                core,
                metadataRouter,
                row
            )
        );
        value.sourceFactsHash =
            keccak256(abi.encode(PROFILE, row.configHash, row.rawSourceHash, entropy, facts));
        value.htmlHash = keccak256(html);
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
        returns (bytes memory)
    {
        return Calls.read(
            target, input, maximum, exact, _gasParameterValue(render ? RENDER_GAS : READ_GAS)
        );
    }
}
