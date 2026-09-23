// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamScopedRenderCriticalTypes as Scoped
} from "../../interfaces/stream/preservation/StreamScopedRenderCriticalTypes.sol";
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
    StreamScopedRenderCriticalTokenReads as Tokens
} from "./StreamScopedRenderCriticalTokenReads.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import {
    StreamPreservationDocumentReads as Documents
} from "./StreamPreservationDocumentReads.sol";

/// @notice Additive current citation evidence, independently of original retained renderer goldens.
/// @dev This closed profile covers 680d current-base-citation, not a later terminal-output profile.
/// The full original renderer roster remains a separate mandatory inventory stage.
library StreamScopedRenderCriticalCitationReads {
    bytes32 private constant PROFILE = keccak256("6529STREAM_CURRENT_BASE_CITATION_V1");

    function item(S.Dependencies memory d, Scoped.Context memory c, uint64 ordinal, uint64 index)
        public
        view
        returns (T.Item memory row, uint64 count)
    {
        (uint256 token, Tokens.Original memory source) = Tokens.sourceAt(d, c, ordinal);
        Router.Selection memory selected = source.selection.selection;
        IO.pin(selected.registry, selected.registryCodeHash);
        IO.pin(selected.renderer, selected.rendererCodeHash);
        bytes memory raw = IO.fixedRead(
            selected.renderer,
            abi.encodeCall(IERC165.supportsInterface, (type(Renderer).interfaceId)),
            32,
            d.readGas
        );
        bool supported = abi.decode(raw, (bool));
        IO.canonical(selected.renderer, raw, abi.encode(supported));
        if (!supported) {
            if (index != 0) revert T.InvalidInventoryItem();
            return (
                Items.absent(
                    keccak256("CURRENT_BASE_CITATION_ADMISSION"),
                    selected.registry,
                    selected.versionKey,
                    token
                ),
                1
            );
        }
        count = 5;
        if (index >= count) revert T.InvalidInventoryItem();
        raw = IO.fixedRead(
            selected.registry,
            abi.encodeCall(Registry.requireCurrentCitation, (selected.versionKey)),
            128,
            d.sourceGas
        );
        (address renderer, bytes32 runtime, bytes32 profile, bytes4 selector) =
            abi.decode(raw, (address, bytes32, bytes32, bytes4));
        IO.canonical(selected.registry, raw, abi.encode(renderer, runtime, profile, selector));
        if (
            renderer != selected.renderer || runtime != selected.rendererCodeHash
                || profile != PROFILE || selector != Renderer.renderCurrent.selector
        ) {
            revert T.InventorySourceChanged();
        }
        raw = IO.fixedRead(
            selected.registry,
            abi.encodeCall(Registry.currentCitationRecord, (selected.versionKey)),
            384,
            d.readGas
        );
        Registry.CurrentRecord memory record = abi.decode(raw, (Registry.CurrentRecord));
        IO.canonical(selected.registry, raw, abi.encode(record));
        Registry.CurrentRegistration memory r = record.registration;
        if (
            r.versionKey != selected.versionKey || r.profile != PROFILE || r.selector != selector
                || record.actionId == 0 || record.analysisHash == 0 || record.goldenHash == 0
        ) revert T.InventorySourceChanged();
        IO.pin(r.encoding, r.encodingRuntimeHash);
        bytes memory binding =
            IO.fixedRead(renderer, abi.encodeCall(Renderer.encodingBinding, ()), 64, d.readGas);
        IO.canonical(renderer, binding, abi.encode(r.encoding, r.encodingRuntimeHash));
        bytes memory declared = IO.read(
            selected.registry,
            abi.encodeCall(Registry.currentCitationReads, (selected.versionKey)),
            16448,
            d.readGas
        );
        V.Read[] memory reads = abi.decode(declared, (V.Read[]));
        IO.canonical(selected.registry, declared, abi.encode(reads));
        _reads(d, selected, record, reads);
        if (index == 0) {
            return (
                Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("CURRENT_BASE_CITATION_ADMISSION"),
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
                    keccak256("CURRENT_BASE_CITATION_READS"),
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
                keccak256("CURRENT_BASE_CITATION_ENCODING"),
                r.encoding,
                record.registrationHash,
                token
            ),
            count
        );
    }

    function _reads(
        S.Dependencies memory d,
        Router.Selection memory selected,
        Registry.CurrentRecord memory record,
        V.Read[] memory reads
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
                            keccak256("6529STREAM_CURRENT_CITATION_REGISTRATION_V1"),
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
