// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamRenderer as R } from "../../interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamRendererRegistry as V
} from "../../interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamStaticMetadataRouter as S
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import { IStreamCoreIdentity as CI } from "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import {
    IStreamCoreCollectionView as CV
} from "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import {
    IStreamStaticEntropySource as StaticEntropy
} from "../../interfaces/stream/metadata/IStreamStaticEntropySource.sol";
import { StreamRendererV1 } from "./StreamRendererV1.sol";
import { StreamMetadataStaticState as State } from "./StreamMetadataStaticState.sol";
import { StreamRendererCalls as Calls } from "./StreamRendererCalls.sol";
import { StreamMetadataDisplayParameters as Gas } from "./StreamMetadataDisplayParameters.sol";
import { StreamCurrentCitationRouting } from "./StreamCurrentCitationRouting.sol";
import {
    IStreamTerminalEntropyRegistry as TerminalRegistry
} from "../../interfaces/stream/metadata/IStreamTerminalEntropyRegistry.sol";
import {
    IStreamTerminalEntropyRenderer as TerminalRenderer
} from "../../interfaces/stream/metadata/IStreamTerminalEntropyRenderer.sol";

/// @notice Internal-only Router route: every external call in this implementation is bounded STATICCALL.
/// @dev Source finality adapters must bind this exact config record and source snapshot. This
/// route never substitutes a legacy linked renderer for an activated version or a failed read.
library StreamMetadataStaticRouting {
    error InvalidToken(uint256 tokenId);
    error TokenEntropyNotFinalized(uint256 tokenId);

    function serve(address core, uint256 token, bool allowBurned, uint8 mode)
        internal
        view
        returns (string memory)
    {
        (bool exists, uint256 id, uint256 serial, bool burned) = abi.decode(
            _read(core, abi.encodeCall(CI.tokenCollectionIdentity, (token)), 128),
            (bool, uint256, uint256, bool)
        );
        if (!exists || (burned && !allowBurned)) revert InvalidToken(token);
        uint8 lifecycle =
            abi.decode(_read(core, abi.encodeCall(CI.tokenLifecycle, (token)), 32), (uint8));
        if (lifecycle != (burned ? 3 : 2)) revert InvalidToken(token);
        S.ConfigRecord memory c = State.resolved(id, token);
        S.Selection memory selected = c.selection;
        _pin(selected.renderer, selected.rendererCodeHash);
        _pin(selected.registry, selected.registryCodeHash);
        (address retained, bytes32 hash) = abi.decode(
            _read(selected.registry, abi.encodeCall(V.requireRetained, (selected.versionKey)), 64),
            (address, bytes32)
        );
        if (retained != selected.renderer || hash != selected.rendererCodeHash) {
            revert S.InvalidStaticMetadataConfig();
        }
        // The concrete STATIC profile fixes these source targets at renderer deployment.
        // A different API/class needs a separately versioned Router profile, never selector fallback.
        (StreamRendererV1.Sources memory sources, bytes32[6] memory pins) = abi.decode(
            _read(selected.renderer, abi.encodeCall(StreamRendererV1.sourceBindings, ()), 384),
            (StreamRendererV1.Sources, bytes32[6])
        );
        if (
            sources.core != core || sources.router != address(this) || pins[0] != core.codehash
                || pins[1] != address(this).codehash
        ) revert S.InvalidStaticMetadataConfig();
        address entropy =
            abi.decode(_read(core, abi.encodeCall(CI.coordinatorAtMint, (token)), 32), (address));
        if (entropy != sources.entropy) revert S.InvalidStaticMetadataConfig();
        _pin(entropy, pins[3]);
        (uint8 entropyStatus, bytes32 seed,) = abi.decode(
            _read(entropy, abi.encodeCall(StaticEntropy.staticTokenRenderFacts, (token)), 96),
            (uint8, bytes32, address)
        );
        if (entropyStatus > 7) revert S.InvalidStaticMetadataConfig();
        bool finalized = entropyStatus == 5;
        bool historical = (allowBurned && mode == 0) || mode == 4;
        bool terminal = !historical && (entropyStatus == 1 || entropyStatus == 2);
        if ((allowBurned || mode >= 2) && !finalized && !terminal) {
            revert TokenEntropyNotFinalized(token);
        }
        bool frozen = c.config.frozen
            || abi.decode(_read(core, abi.encodeCall(CV.collectionFreezeStatus, (id)), 32), (bool));
        R.TokenRenderState status = burned
            ? R.TokenRenderState.BURNED
            : !finalized && !terminal
                ? R.TokenRenderState.PENDING_RANDOMNESS
                : frozen ? R.TokenRenderState.FROZEN : R.TokenRenderState.ACTIVE;
        R.RenderRequest memory request = R.RenderRequest(
            core,
            token,
            id,
            serial,
            finalized ? seed : bytes32(0),
            status,
            c.config.mode,
            abi.decode(_read(core, abi.encodeCall(CV.collectionSupplyMode, (id)), 32), (uint8)),
            abi.decode(_read(core, abi.encodeCall(CV.collectionStatus, (id)), 32), (uint8)),
            0,
            0,
            c.recordHash
        );
        uint256 maximum = mode == 1 ? 24576 : mode == 0 ? 18000 : 16777216;
        uint256 cap = Gas.value(mode >= 2 ? Gas.FULL_VIEW_GAS : Gas.BUNDLE_RENDER_GAS);
        // Explicit historical checkpoint entries retain the original renderer profile. Current
        // tokenJSON (mode 2, also burn-readable) is distinct from historicalFull... (mode 4).
        bytes memory input = terminal
            ? _terminalInput(selected, request, mode)
            : historical
                ? abi.encodeCall(StreamRendererV1.renderView, (request, mode == 4 ? 2 : mode))
                : StreamCurrentCitationRouting.input(
                    selected, request, mode, Gas.value(Gas.BUNDLE_READ_GAS)
                );
        bytes memory raw =
            Calls.read(selected.renderer, input, 64 + ((maximum + 31) / 32) * 32, false, cap);
        return Calls.stringResult(raw, maximum);
    }

    function _terminalInput(S.Selection memory selected, R.RenderRequest memory request, uint8 mode)
        private
        view
        returns (bytes memory)
    {
        (address renderer, bytes32 runtime, bytes32 profile, bytes4 selector) = abi.decode(
            _read(
                selected.registry,
                abi.encodeCall(TerminalRegistry.requireTerminalEntropy, (selected.versionKey)),
                128
            ),
            (address, bytes32, bytes32, bytes4)
        );
        if (
            renderer != selected.renderer || runtime != selected.rendererCodeHash
                || profile != keccak256("6529STREAM_TERMINAL_ENTROPY_RENDER_V1")
                || selector != TerminalRenderer.renderTerminal.selector
        ) revert S.InvalidStaticMetadataConfig();
        return abi.encodeCall(TerminalRenderer.renderTerminal, (request, mode));
    }

    function _read(address a, bytes memory input, uint256 size)
        private
        view
        returns (bytes memory)
    {
        return Calls.read(a, input, size, true, Gas.value(Gas.BUNDLE_READ_GAS));
    }

    function _pin(address a, bytes32 hash) private view {
        if (a.code.length == 0 || a.codehash != hash) revert S.StaticMetadataSourceChanged(a);
    }
}
