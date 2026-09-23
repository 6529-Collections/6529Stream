// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamPreservationPolicyOutputTypesV1 as P
} from "../../interfaces/stream/finality/StreamPreservationPolicyOutputTypesV1.sol";
import {
    IStreamStaticSelectionCheckpoint as S
} from "../../interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as C
} from "../../interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamPreservationRegistryV1 as Registry
} from "../../interfaces/stream/metadata/IStreamPreservationRegistryV1.sol";
import {
    IStreamGasParameterHost as Gas
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import { StreamGasParameterHost } from "../parameters/StreamGasParameterHost.sol";
import { StreamRendererCalls as Calls } from "../metadata/StreamRendererCalls.sol";
import {
    StreamPreservationPolicyOutputBindingV1 as Binding
} from "./StreamPreservationPolicyOutputBindingV1.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Family
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";

import {
    IStreamStaticMetadataRouter as M
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import { IStreamRenderer as R } from "../../interfaces/stream/metadata/IStreamRenderer.sol";

/// @notice Complete original producer identity and governed per-version admission join.
/// @dev Fixed delegatecall worker: dependency calls retain the checkpoint as caller.
/// Rendering, full output reobservation and record writes remain in the checkpoint.
library StreamPreservationContentAdmissionV1 {
    bytes32 private constant READ_GAS = keccak256("6529STREAM_GGP_STATIC_CONTENT_READ_GAS");
    bytes32 private constant RENDER_GAS = keccak256("6529STREAM_GGP_STATIC_CONTENT_RENDER_GAS");

    struct Context {
        address core;
        address metadataRouter;
        bytes32 profile;
    }

    function observe(
        mapping(bytes32 => StreamGasParameterHost.GasParameterData) storage parameters,
        Context memory context,
        S.TokenSelection memory row,
        address producer
    ) public view returns (P.Binding memory preservation, P.Admission memory admission) {
        bytes32 producerProfile = context.profile;
        if (producerProfile == Family.FAMILY_PROFILE) {
            producerProfile = abi.decode(
                _read(
                    parameters,
                    producer,
                    abi.encodeWithSignature("preservationProfile()"),
                    32,
                    true,
                    false
                ),
                (bytes32)
            );
            if (!Family.isSupported(producerProfile)) revert P.InvalidPreservationBinding();
        } else if (producerProfile != Family.ORIGINAL_PROFILE) {
            revert P.InvalidPreservationBinding();
        }
        preservation = Binding.current(
            producer,
            producerProfile,
            context.core,
            context.metadataRouter,
            _cap(parameters, READ_GAS)
        );
        Binding.requireCurrent(preservation, row, _cap(parameters, READ_GAS));
        admission = _admission(parameters, row, preservation);
        if (
            admission.registry != row.selection.registry
                || admission.registryCodeHash != row.selection.registryCodeHash
                || admission.versionKey != row.selection.versionKey
                || admission.registrationHash == 0 || admission.readSetHash == 0
                || admission.analysisHash == 0 || admission.goldenHash == 0
        ) {
            revert C.StaticContentPayload(row.tokenId);
        }
    }

    /// @dev The original selected Registry owns the immutable class-1 admission. A producer's
    /// capability claim or a caller's supplied evidence cannot replace this exact current read.
    function _admission(
        mapping(bytes32 => StreamGasParameterHost.GasParameterData) storage parameters,
        S.TokenSelection memory row,
        P.Binding memory expected
    ) private view returns (P.Admission memory a) {
        bytes memory raw = _read(
            parameters,
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
            revert C.StaticContentPayload(row.tokenId);
        }
    }

    /// @notice Authenticate the full selected configuration and raw source before returning its image URI.
    /// @dev Retains the original read order, bounds, complete canonical hashes and live cap reads.
    function sourceImage(
        mapping(bytes32 => StreamGasParameterHost.GasParameterData) storage parameters,
        C.Plan storage p,
        S.TokenSelection memory row,
        address metadataRouter
    ) public view returns (string memory imageURI) {
        bytes memory raw = _read(
            parameters,
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
        ) revert C.StaticContentPayload(row.tokenId);
        raw = _read(
            parameters,
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
        ) revert C.StaticContentPayload(row.tokenId);
        imageURI = source.imageURI;
    }

    // Read the live registered cap at each original call site; do not hoist lookups.
    function _cap(
        mapping(bytes32 => StreamGasParameterHost.GasParameterData) storage parameters,
        bytes32 id
    ) private view returns (uint256) {
        StreamGasParameterHost.GasParameterData storage parameter = parameters[id];
        if (parameter.revision == 0) revert Gas.GasParameterUnknown(id);
        return parameter.value;
    }

    function _read(
        mapping(bytes32 => StreamGasParameterHost.GasParameterData) storage parameters,
        address target,
        bytes memory input,
        uint256 maximum,
        bool exact,
        bool render
    ) private view returns (bytes memory output) {
        uint256 cap = _cap(parameters, render ? RENDER_GAS : READ_GAS);
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
}
