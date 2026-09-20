// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamScopedPolicyRenderCriticalTypesV2 as Scoped
} from "../../interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    IStreamRendererRegistry as V
} from "../../interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamCurrentCitationRegistry as Registry
} from "../../interfaces/stream/metadata/IStreamCurrentCitationRegistry.sol";
import {
    IStreamCurrentCitationRenderer as Renderer
} from "../../interfaces/stream/metadata/IStreamCurrentCitationRenderer.sol";
import {
    IStreamStaticMetadataRouter as Router
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import {
    StreamScopedPolicyRenderCriticalTokenReadsV2 as Tokens
} from "./StreamScopedPolicyRenderCriticalTokenReadsV2.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import {
    StreamPreservationDocumentReads as Documents
} from "./StreamPreservationDocumentReads.sol";

/// @notice Exact current citation or terminal profile, separately from original renderer evidence.
/// @dev Terminal outputs require their own admission; they never inherit citation or old goldens.
import {
    IStreamTerminalEntropyRegistry as TerminalRegistry
} from "../../interfaces/stream/metadata/IStreamTerminalEntropyRegistry.sol";
import {
    IStreamTerminalEntropyRenderer as TerminalRenderer
} from "../../interfaces/stream/metadata/IStreamTerminalEntropyRenderer.sol";

library StreamScopedPolicyRenderCriticalCitationReadsV2 {
    bytes32 private constant PROFILE = keccak256("6529STREAM_CURRENT_BASE_CITATION_V1");
    bytes32 private constant TERMINAL = keccak256("6529STREAM_TERMINAL_ENTROPY_RENDER_V1");

    function item(S.Dependencies memory d, Scoped.Context memory c, uint64 ordinal, uint64 index)
        public
        view
        returns (T.Item memory row, uint64 count)
    {
        (uint256 token, Tokens.Original memory source) = Tokens.sourceAt(d, c, ordinal);
        Router.Selection memory selected = source.selection.selection;
        bool terminal = source.output.entropy.terminal;
        bytes32 expectedProfile = terminal ? TERMINAL : PROFILE;
        bytes4 expectedSelector =
            terminal ? TerminalRenderer.renderTerminal.selector : Renderer.renderCurrent.selector;
        IO.pin(selected.registry, selected.registryCodeHash);
        IO.pin(selected.renderer, selected.rendererCodeHash);
        bytes memory raw = IO.fixedRead(
            selected.renderer,
            abi.encodeCall(
                IERC165.supportsInterface,
                (terminal ? type(TerminalRenderer).interfaceId : type(Renderer).interfaceId)
            ),
            32,
            d.readGas
        );
        bool supported = abi.decode(raw, (bool));
        IO.canonical(selected.renderer, raw, abi.encode(supported));
        if (!supported) {
            if (terminal) revert T.InventorySourceChanged();
            if (index != 0) revert T.InvalidInventoryItem();
            return (
                Items.absent(
                    terminal
                        ? keccak256("TERMINAL_ENTROPY_ADMISSION")
                        : keccak256("CURRENT_BASE_CITATION_ADMISSION"),
                    selected.registry,
                    selected.versionKey,
                    token
                ),
                1
            );
        }
        count = terminal ? 8 : 5;
        if (index >= count) revert T.InvalidInventoryItem();
        raw = IO.fixedRead(
            selected.registry,
            terminal
                ? abi.encodeCall(TerminalRegistry.requireTerminalEntropy, (selected.versionKey))
                : abi.encodeCall(Registry.requireCurrentCitation, (selected.versionKey)),
            128,
            d.sourceGas
        );
        (address renderer, bytes32 runtime, bytes32 profile, bytes4 selector) =
            abi.decode(raw, (address, bytes32, bytes32, bytes4));
        IO.canonical(selected.registry, raw, abi.encode(renderer, runtime, profile, selector));
        if (
            renderer != selected.renderer || runtime != selected.rendererCodeHash
                || profile != expectedProfile || selector != expectedSelector
        ) {
            revert T.InventorySourceChanged();
        }
        raw = IO.fixedRead(
            selected.registry,
            terminal
                ? abi.encodeCall(TerminalRegistry.terminalEntropyRecord, (selected.versionKey))
                : abi.encodeCall(Registry.currentCitationRecord, (selected.versionKey)),
            384,
            d.readGas
        );
        Registry.CurrentRecord memory record = abi.decode(raw, (Registry.CurrentRecord));
        IO.canonical(selected.registry, raw, abi.encode(record));
        Registry.CurrentRegistration memory r = record.registration;
        if (
            r.versionKey != selected.versionKey || r.profile != expectedProfile
                || r.selector != selector || record.actionId == 0 || record.analysisHash == 0
                || record.goldenHash == 0
        ) revert T.InventorySourceChanged();
        IO.pin(r.encoding, r.encodingRuntimeHash);
        bytes memory binding = IO.fixedRead(
            renderer,
            terminal
                ? abi.encodeCall(TerminalRenderer.terminalEncodingBinding, ())
                : abi.encodeCall(Renderer.encodingBinding, ()),
            64,
            d.readGas
        );
        IO.canonical(renderer, binding, abi.encode(r.encoding, r.encodingRuntimeHash));
        bytes memory declared = IO.read(
            selected.registry,
            terminal
                ? abi.encodeCall(TerminalRegistry.terminalEntropyReads, (selected.versionKey))
                : abi.encodeCall(Registry.currentCitationReads, (selected.versionKey)),
            16448,
            d.readGas
        );
        V.Read[] memory reads = abi.decode(declared, (V.Read[]));
        IO.canonical(selected.registry, declared, abi.encode(reads));
        _reads(d, selected, record, reads, terminal);
        if (terminal) {
            T.Item memory extra = _terminal(d, source, record, token, index);
            if (index >= 5) return (extra, count);
        }
        if (index == 0) {
            return (
                Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    terminal
                        ? keccak256("TERMINAL_ENTROPY_ADMISSION")
                        : keccak256("CURRENT_BASE_CITATION_ADMISSION"),
                    selected.registry,
                    selected.versionKey,
                    token,
                    raw
                ),
                count
            );
        }
        if (index == 1) {
            return (
                Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    terminal
                        ? keccak256("TERMINAL_ENTROPY_READS")
                        : keccak256("CURRENT_BASE_CITATION_READS"),
                    selected.registry,
                    selected.versionKey,
                    token,
                    declared
                ),
                count
            );
        }
        if (index == 2) return (Documents.item(d, r.analysisDocument, record.analysisHash), count);
        if (index == 3) return (Documents.item(d, r.goldenDocument, record.goldenHash), count);
        return (
            Items.runtime(
                terminal
                    ? keccak256("TERMINAL_ENTROPY_ENCODING")
                    : keccak256("CURRENT_BASE_CITATION_ENCODING"),
                r.encoding,
                record.registrationHash,
                token
            ),
            count
        );
    }

    function _terminal(
        S.Dependencies memory d,
        Tokens.Original memory source,
        Registry.CurrentRecord memory record,
        uint256 token,
        uint64 index
    ) private view returns (T.Item memory row) {
        address renderer = source.selection.selection.renderer;
        bytes memory validation = IO.fixedRead(
            renderer, abi.encodeCall(TerminalRenderer.terminalValidationBinding, ()), 64, d.readGas
        );
        (address validator, bytes32 runtime) = abi.decode(validation, (address, bytes32));
        IO.canonical(renderer, validation, abi.encode(validator, runtime));
        IO.pin(validator, runtime);
        bytes memory policy = IO.fixedRead(
            renderer, abi.encodeCall(TerminalRenderer.terminalPolicyBinding, ()), 96, d.readGas
        );
        (address core, address coordinator, bytes32 coordinatorHash) =
            abi.decode(policy, (address, address, bytes32));
        IO.canonical(renderer, policy, abi.encode(core, coordinator, coordinatorHash));
        if (
            core != d.targets[0] || coordinator != source.selection.sources[3]
                || coordinatorHash != source.selection.sourceCodeHashes[3]
        ) revert T.InventorySourceChanged();
        IO.pin(coordinator, coordinatorHash);
        if (index == 5) {
            return Items.bytesItem(
                T.Kind.NATIVE_BYTES,
                keccak256("TERMINAL_VALIDATION_BINDING"),
                renderer,
                record.registrationHash,
                token,
                validation
            );
        }
        if (index == 6) {
            return Items.runtime(
                keccak256("TERMINAL_VALIDATION_RUNTIME"), validator, record.registrationHash, token
            );
        }
        if (index == 7) {
            return Items.bytesItem(
                T.Kind.NATIVE_BYTES,
                keccak256("TERMINAL_POLICY_BINDING"),
                renderer,
                record.registrationHash,
                token,
                policy
            );
        }
    }

    function _reads(
        S.Dependencies memory d,
        Router.Selection memory selected,
        Registry.CurrentRecord memory record,
        V.Read[] memory reads,
        bool terminal
    ) private view {
        address registry = selected.registry;
        if (
            IO.addressWord(registry, abi.encodeWithSignature("schemaRegistry()"), d.readGas)
                    != d.targets[2]
                || IO.word(registry, abi.encodeWithSignature("schemaRegistryCodeHash()"), d.readGas)
                    != d.codeHashes[2]
                || uint256(
                        IO.word(registry, abi.encodeWithSignature("deploymentChainId()"), d.readGas)
                    ) != d.chainId
        ) {
            revert T.InventorySourceChanged();
        }
        bytes32 targetsHash =
            IO.word(registry, abi.encodeWithSignature("targetSetHash()"), d.readGas);
        if (
            keccak256(abi.encode(keccak256("6529STREAM_RENDERER_READ_SET_V1"), targetsHash, reads))
                    != record.readSetHash
                || keccak256(
                        abi.encode(
                            terminal
                                ? keccak256("6529STREAM_TERMINAL_ENTROPY_REGISTRATION_V1")
                                : keccak256("6529STREAM_CURRENT_CITATION_REGISTRATION_V1"),
                            d.chainId,
                            registry,
                            d.targets[2],
                            d.codeHashes[2],
                            targetsHash,
                            selected.registrationHash,
                            record.registration,
                            reads
                        )
                    ) != record.registrationHash
        ) {
            revert T.InventorySourceChanged();
        }
        bytes memory raw =
            IO.read(registry, abi.encodeCall(V.reads, (selected.versionKey)), 16448, d.readGas);
        V.Read[] memory original = abi.decode(raw, (V.Read[]));
        IO.canonical(registry, raw, abi.encode(original));
        if (reads.length > 128 || original.length > reads.length) revert T.InvalidInventoryItem();
        uint256 n = uint256(IO.word(registry, abi.encodeCall(V.targetCount, ()), d.readGas));
        if (n == 0 || n > 64) revert T.InvalidInventoryItem();
        uint256 previous;
        uint256 cursor;
        for (uint256 i; i < reads.length; ++i) {
            V.Read memory r = reads[i];
            uint256 order = (uint256(r.targetIndex) << 32) | uint32(r.selector);
            if (
                r.targetIndex >= n || r.selector == 0 || (i != 0 && order <= previous)
                    || r.maxReturnBytes == 0 || r.maxReturnBytes > 16777216
                    || (r.exact && r.maxReturnBytes % 32 != 0)
            ) {
                revert T.InvalidInventoryItem();
            }
            previous = order;
            if (
                cursor < original.length
                    && keccak256(abi.encode(r)) == keccak256(abi.encode(original[cursor]))
            ) ++cursor;
        }
        if (cursor != original.length) revert T.InventorySourceChanged();
    }
}
