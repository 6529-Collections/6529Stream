// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamPolicyContentCheckpointV2 as C
} from "../../interfaces/stream/finality/IStreamPolicyContentCheckpointV2.sol";
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
    IStreamFinalityEntropyPolicySourceSet as E
} from "../../interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    IStreamTerminalEntropyReadiness as T
} from "../../interfaces/stream/finality/IStreamTerminalEntropyReadiness.sol";

import {
    IStreamStaticEntropySource as Native
} from "../../interfaces/stream/metadata/IStreamStaticEntropySource.sol";
import { IStreamCoreIdentity as I } from "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import { IStreamCoreMint as D } from "../../interfaces/stream/core/IStreamCoreMint.sol";
import {
    StreamTokenContentLeaf
} from "../../interfaces/stream/metadata/StreamTokenContentTypes.sol";

import { StreamRendererCalls as Calls } from "../metadata/StreamRendererCalls.sol";
import { StreamGasParameterHost } from "../parameters/StreamGasParameterHost.sol";
import {
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";

/// @notice Fixed linked operations retain the original host storage and domains.
library StreamPolicyContentObservationV2 {
    bytes32 private constant READ_GAS = keccak256("6529STREAM_GGP_STATIC_CONTENT_READ_GAS");
    bytes32 private constant RENDER_GAS = keccak256("6529STREAM_GGP_STATIC_CONTENT_RENDER_GAS");
    uint256 private constant MAX_BYTES = 16777216;

    struct Context {
        address core;
        address metadataRouter;
        address entropySourceSet;
        address terminalReadiness;
        bytes32 entropySourceSetCodeHash;
        bytes32 terminalReadinessCodeHash;
        uint256 deploymentChainId;
        bytes32 PROFILE;
    }

    function observe(
        mapping(bytes32 => StreamGasParameterHost.GasParameterData) storage _gasParameters,
        Context memory context,
        C.Plan storage p,
        S.TokenSelection memory row
    )
        public
        view
        returns (
            C.Output memory value,
            bytes memory json,
            bytes memory html,
            bytes memory data,
            string memory imageURI
        )
    {
        bytes memory raw = _read(
            _gasParameters,
            context.metadataRouter,
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
        ) revert C.StaticContentPayload(row.tokenId);
        raw = _read(
            _gasParameters,
            context.metadataRouter,
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
        ) revert C.StaticContentPayload(row.tokenId);
        imageURI = source.imageURI;
        address entropy = abi.decode(
            _read(
                _gasParameters,
                context.core,
                abi.encodeCall(I.coordinatorAtMint, (row.tokenId)),
                32,
                true,
                false
            ),
            (address)
        );
        if (entropy != row.sources[3] || entropy.codehash != row.sourceCodeHashes[3]) {
            revert C.StaticContentPayload(row.tokenId);
        }
        bytes memory facts = _read(
            _gasParameters,
            context.entropySourceSet,
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
        ) revert C.StaticContentPayload(row.tokenId);
        if (e.terminal) {
            if (
                e.finalized || e.seed != 0 || e.renderRequirement != 1
                    || !((e.status == 1 && e.mode == 0) || (e.status == 2 && e.mode == 2))
            ) revert C.StaticContentPayload(row.tokenId);
            bytes memory admitted = _read(
                _gasParameters,
                context.terminalReadiness,
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
            ) revert C.StaticContentPayload(row.tokenId);
            value.terminalAdmissionHash = keccak256(admitted);
        } else {
            if (!e.finalized || e.status != 5 || e.mode != 2 || e.renderRequirement != 0) {
                revert C.StaticContentPayload(row.tokenId);
            }
            bytes memory nativeFacts = _read(
                _gasParameters,
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
            ) revert C.StaticContentPayload(row.tokenId);
        }
        raw = _read(
            _gasParameters,
            context.core,
            abi.encodeCall(D.tokenData, (row.tokenId)),
            16448,
            false,
            false
        );
        data = abi.decode(raw, (bytes));
        if (data.length > 16384 || keccak256(raw) != keccak256(abi.encode(data))) {
            revert C.StaticContentPayload(row.tokenId);
        }
        json = bytes(
            Calls.stringResult(
                _read(
                    _gasParameters,
                    context.metadataRouter,
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
                    _gasParameters,
                    context.metadataRouter,
                    abi.encodeCall(F.tokenHTML, (row.tokenId)),
                    MAX_BYTES + 64,
                    false,
                    true
                ),
                MAX_BYTES
            )
        );
        if (html.length == 0 || json.length == 0) revert C.StaticContentPayload(row.tokenId);
        value.leaf = StreamTokenContentLeaf(
            row.tokenId, keccak256(json), 0, keccak256(html), 0, keccak256(data)
        );
        value.selectionRowHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_STATIC_SELECTION_ROW_V1"),
                context.deploymentChainId,
                context.core,
                context.metadataRouter,
                row
            )
        );
        value.sourceFactsHash = keccak256(
            abi.encode(
                context.PROFILE,
                row.configHash,
                row.rawSourceHash,
                entropy,
                facts,
                context.entropySourceSet,
                context.entropySourceSetCodeHash,
                p.inventoryHash,
                p.policyChainHash,
                context.terminalReadiness,
                context.terminalReadinessCodeHash,
                value.terminalAdmissionHash
            )
        );
        value.htmlHash = keccak256(html);
    }

    function _read(
        mapping(bytes32 => StreamGasParameterHost.GasParameterData) storage _gasParameters,
        address target,
        bytes memory input,
        uint256 maximum,
        bool exact,
        bool render
    ) private view returns (bytes memory output) {
        uint256 cap = _cap(_gasParameters, render ? RENDER_GAS : READ_GAS);
        if (target.code.length == 0) revert Calls.RendererReadFailed(target, bytes4(input));
        if (cap > type(uint256).max / 2) {
            revert C.StaticContentParentGas(gasleft(), type(uint256).max);
        }
        // Admission must not turn caller starvation into a successful unavailable display.
        // Prepare input and warm the target before the preflight; leave room for EIP-150,
        // STATICCALL overhead and local work. Never clamp the configured dependency budget.
        uint256 required = cap + cap / 63 + 100000;
        uint256 available = gasleft();
        if (available <= required) revert C.StaticContentParentGas(available, required);
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

    function _cap(
        mapping(bytes32 => StreamGasParameterHost.GasParameterData) storage _gasParameters,
        bytes32 id
    ) private view returns (uint256) {
        StreamGasParameterHost.GasParameterData storage parameter = _gasParameters[id];
        if (parameter.revision == 0) revert IStreamGasParameterHost.GasParameterUnknown(id);
        return parameter.value;
    }
}
