// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationTokenProducerProfilesV1 as Family
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as C
} from "../../interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamStaticSelectionCheckpoint as S
} from "../../interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    IStreamStaticMetadataRouter as M
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import { IStreamRenderer as R } from "../../interfaces/stream/metadata/IStreamRenderer.sol";

import {
    IStreamFinalityEntropyPolicySourceSet as E
} from "../../interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    IStreamTerminalEntropyReadiness as T
} from "../../interfaces/stream/finality/IStreamTerminalEntropyReadiness.sol";
import {
    StreamScopeMembershipFacts
} from "../../interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    IStreamStaticEntropySource as Native
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
import { StreamPolicyContentBytesV2 as TerminalBytes } from "./StreamPolicyContentBytesV2.sol";
import { StreamOnchainContentBytes as Image } from "./StreamOnchainContentBytes.sol";

import {
    StreamPreservationPolicyOutputTypesV1 as P
} from "../../interfaces/stream/finality/StreamPreservationPolicyOutputTypesV1.sol";
import {
    StreamPreservationPolicyOutputBindingV1 as Binding
} from "./StreamPreservationPolicyOutputBindingV1.sol";
import {
    IStreamPreservationRegistryV1 as Registry
} from "../../interfaces/stream/metadata/IStreamPreservationRegistryV1.sol";
import {
    StreamScopedPreservationPolicySourceBindingV1 as Scoped
} from "./StreamScopedPreservationPolicySourceBindingV1.sol";

/// @notice Shared engine for separately identified, governed preservation-output consumers.
/// @dev Each concrete consumer must authenticate its per-row preservation admission. All other
/// artwork, identity, entropy, citation and C2PA facts remain current. Every read re-renders all
/// completed rows; pins alone cannot establish current output. Historical hashes remain readable.
/// Exact output bytes still require a separate preserved artifact and authoritative publication.
abstract contract StreamPreservationPolicyContentCheckpointBaseV1 is
    C,
    StreamGasParameterHost,
    IERC165
{
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
    bytes32 public immutable PROFILE;
    bool public immutable scoped;
    address public immutable override sourceFactory;
    bytes32 public immutable sourceFactoryCodeHash;
    bytes32 public immutable override factoryDependenciesHash;
    bytes32 public constant LEAF_CHAIN =
        keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_LEAVES_V1");
    bytes32 public constant OUTPUT_CHAIN = keccak256("6529STREAM_PRESERVATION_POLICY_OUTPUTS_V1");
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
        bool scoped_,
        bool familyV2_,
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
        scoped = scoped_;
        PROFILE = familyV2_
            ? (scoped_ ? Family.SCOPED_CHECKPOINT_PROFILE : Family.COLLECTION_CHECKPOINT_PROFILE)
            : (scoped_
                    ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_V1")
                    : keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1"));
        Scoped.Binding memory factoryBinding;
        if (scoped_) {
            factoryBinding = Scoped.bind(core, selection, policySourceSet, readGas.genesisValue);
        }
        sourceFactory = factoryBinding.factory;
        sourceFactoryCodeHash = factoryBinding.factoryCodeHash;
        factoryDependenciesHash = factoryBinding.dependenciesHash;
    }

    function preservationPolicyProfile() external view returns (bytes32) {
        return PROFILE;
    }

    function preservationOutputProfile() external pure returns (bytes32) {
        return _preservationProfile();
    }

    /// @dev Fixed by the concrete wrapper; no caller-supplied family selection.
    function _preservationProfile() internal pure virtual returns (bytes32);

    /// @dev The original selected Registry owns the immutable class-1 admission. A producer's
    /// capability claim or a caller's supplied evidence cannot replace this exact current read.
    function _admission(S.TokenSelection memory row, P.Binding memory expected)
        private
        view
        returns (P.Admission memory a)
    {
        bytes memory raw = _read(
            row.selection.registry,
            abi.encodeCall(
                Registry.requirePreservation,
                (row.selection.versionKey, expected.producer, expected.profile)
            ),
            512,
            true,
            false
        );
        P.Binding memory b;
        (b, a) = abi.decode(raw, (P.Binding, P.Admission));
        if (
            keccak256(raw) != keccak256(abi.encode(b, a))
                || Binding.hash(b) != Binding.hash(expected)
        ) {
            revert StaticContentPayload(row.tokenId);
        }
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
                _preservationProfile(),
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
                0,
                _preservationProfile()
            );
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
            ) = _observe(p, row, payloads[j].producer);
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
            p.tokenCount == 0 || p.preservationProfile != _preservationProfile()
                || keccak256(abi.encode(_selection(p.selectionId))) != p.selectionHash
                || p.inventoryHash != _sourceWord(E.originalInventoryHash.selector)
                || p.policyChainHash != _sourceWord(E.originalPolicyChainHash.selector)
        ) revert StaticContentChanged(id);
        // Complete finite read, not a constant-cost promise. Insufficient parent/read budgets fail closed.
        for (uint256 i; i < p.nextIndex; ++i) {
            Output memory saved = _outputs[id][i];
            (Output memory now_,,,,) =
                _observe(p, _row(p.selectionId, i), saved.preservation.producer);
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
                || (!scoped && p.scope.scopeType != StreamFinalityScopeType.COLLECTION)
        ) {
            revert InvalidStaticContentConfiguration();
        }
        if (scoped) {
            Scoped.requireCurrent(
                Scoped.Binding(sourceFactory, sourceFactoryCodeHash, factoryDependenciesHash),
                entropySourceSet,
                entropySourceSetCodeHash,
                p.scope,
                _gasParameterValue(READ_GAS)
            );
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

    function _observe(Plan storage p, S.TokenSelection memory row, address producer)
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
        bytes32 producerProfile = _preservationProfile();
        if (producerProfile == Family.FAMILY_PROFILE) {
            producerProfile = abi.decode(
                _read(producer, abi.encodeWithSignature("preservationProfile()"), 32, true, false),
                (bytes32)
            );
            if (!Family.isSupported(producerProfile)) revert P.InvalidPreservationBinding();
        } else if (producerProfile != Family.ORIGINAL_PROFILE) {
            revert P.InvalidPreservationBinding();
        }
        value.preservation = Binding.current(
            producer, producerProfile, core, metadataRouter, _gasParameterValue(READ_GAS)
        );
        Binding.requireCurrent(value.preservation, row, _gasParameterValue(READ_GAS));
        value.preservationAdmission = _admission(row, value.preservation);
        P.Admission memory admission = value.preservationAdmission;
        if (
            admission.registry != row.selection.registry
                || admission.registryCodeHash != row.selection.registryCodeHash
                || admission.versionKey != row.selection.versionKey
                || admission.registrationHash == 0 || admission.readSetHash == 0
                || admission.analysisHash == 0 || admission.goldenHash == 0
        ) {
            revert StaticContentPayload(row.tokenId);
        }
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
            entropySourceSet,
            abi.encodeCall(E.tokenEntropyReadiness, (row.tokenId)),
            320,
            true,
            false
        );
        value.entropy = abi.decode(facts, (E.TokenReadiness));
        E.TokenReadiness memory e = value.entropy;
        if (
            keccak256(facts) != keccak256(abi.encode(e)) || e.coordinator != entropy
                || e.coordinatorCodeHash != row.sourceCodeHashes[3] || e.policyHash == 0
        ) revert StaticContentPayload(row.tokenId);
        if (e.terminal) {
            if (
                e.finalized || e.seed != 0 || e.renderRequirement != 1
                    || !((e.status == 1 && e.mode == 0) || (e.status == 2 && e.mode == 2))
            ) revert StaticContentPayload(row.tokenId);
            bytes memory admitted = _read(
                terminalReadiness,
                abi.encodeCall(T.requireTerminalRenderReady, (row.tokenId)),
                608,
                true,
                false
            );
            T.Evidence memory a = abi.decode(admitted, (T.Evidence));
            if (
                keccak256(admitted) != keccak256(abi.encode(a))
                    || keccak256(abi.encode(a.entropy)) != keccak256(facts)
                    || a.configRecordHash != row.configRecordHash
                    || a.versionKey != row.selection.versionKey
                    || a.renderer != row.selection.renderer
                    || a.rendererCodeHash != row.selection.rendererCodeHash
                    || a.registry != row.selection.registry
                    || a.registryCodeHash != row.selection.registryCodeHash
                    || a.policyChainHash != p.policyChainHash || a.admissionHash == 0
                    || a.evidenceHash == 0
            ) revert StaticContentPayload(row.tokenId);
            value.terminalAdmissionHash = keccak256(admitted);
        } else {
            if (!e.finalized || e.status != 5 || e.mode != 2 || e.renderRequirement != 0) {
                revert StaticContentPayload(row.tokenId);
            }
            bytes memory nativeFacts = _read(
                entropy,
                abi.encodeCall(Native.staticTokenRenderFacts, (row.tokenId)),
                96,
                true,
                false
            );
            (uint8 status, bytes32 seed, address provider) =
                abi.decode(nativeFacts, (uint8, bytes32, address));
            if (
                keccak256(nativeFacts) != keccak256(abi.encode(status, seed, provider))
                    || status != 5 || seed != e.seed
            ) revert StaticContentPayload(row.tokenId);
        }
        raw = _read(core, abi.encodeCall(D.tokenData, (row.tokenId)), 16448, false, false);
        data = abi.decode(raw, (bytes));
        if (data.length > 16384 || keccak256(raw) != keccak256(abi.encode(data))) {
            revert StaticContentPayload(row.tokenId);
        }
        json = bytes(
            Calls.stringResult(
                _read(
                    value.preservation.producer,
                    abi.encodeWithSignature("preservationTokenJSON(uint256)", row.tokenId),
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
                    value.preservation.producer,
                    abi.encodeWithSignature("preservationTokenHTML(uint256)", row.tokenId),
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
        value.sourceFactsHash = keccak256(
            abi.encode(
                PROFILE,
                p.preservationProfile,
                value.preservation,
                admission,
                row.configHash,
                row.rawSourceHash,
                entropy,
                facts,
                entropySourceSet,
                entropySourceSetCodeHash,
                p.inventoryHash,
                p.policyChainHash,
                terminalReadiness,
                terminalReadinessCodeHash,
                value.terminalAdmissionHash
            )
        );
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
