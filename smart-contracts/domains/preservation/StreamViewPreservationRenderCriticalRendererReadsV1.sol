// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamViewPreservationRenderCriticalTypesV1 as Scoped
} from "../../interfaces/stream/preservation/StreamViewPreservationRenderCriticalTypesV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    IStreamRendererRegistry as V
} from "../../interfaces/stream/metadata/IStreamRendererRegistry.sol";
import { IStreamRenderer as R } from "../../interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamStaticMetadataRouter as Router
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    StreamViewPreservationRenderCriticalSourceReadsV1 as Sources
} from "./StreamViewPreservationRenderCriticalSourceReadsV1.sol";
import {
    StreamViewPreservationReferenceTypesV1 as Reference
} from "../../interfaces/stream/preservation/StreamViewPreservationReferenceTypesV1.sol";
import { StreamViewPolicyTypesV2 as Policy } from "../metadata/StreamViewPolicyTypesV2.sol";
import {
    IStreamViewRendererV2 as ViewRenderer
} from "../../interfaces/stream/metadata/IStreamViewRendererV2.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import {
    StreamPreservationDocumentReads as Documents
} from "./StreamPreservationDocumentReads.sol";

import {
    StreamViewPreservationRenderCriticalRetainedReadsV1 as Retained
} from "./StreamViewPreservationRenderCriticalRetainedReadsV1.sol";

/// @notice Actual admitted full-policy VIEW renderer, full original read roster and five documents.
/// @dev This worker does not claim transitive opcode conformance. A separately admitted current
/// output profile also requires its own declaration/analysis/goldens/read-set inventory.
library StreamViewPreservationRenderCriticalRendererReadsV1 {
    struct Original {
        Router.Selection selected;
        V.Version version;
        V.Registration registration;
        V.Read[] reads;
        V.Target[] targets;
        bytes bindings;
        address encoding;
        bytes32 encodingHash;
        address[4] sources;
        bytes32[4] sourcePins;
        Policy.Binding policy;
    }

    function item(S.Dependencies memory d, Scoped.Context memory c, uint64 index)
        public
        view
        returns (T.Item memory row, uint64 count)
    {
        Reference.SourceFacts memory facts = Retained.sourceFacts(d, c);
        Original memory o = _load(
            d,
            facts.snapshotSource.adoption.adoption.source.renderer,
            facts.snapshotSource.adoption.policy
        );
        uint256 token = 0; // Shared immutable VIEW renderer; per-token identities have their own stage.
        count = uint64(18 + o.targets.length);
        if (index >= count) revert T.InvalidInventoryItem();
        address registry = o.selected.registry;
        bytes32 key = o.selected.versionKey;
        if (index == 0) {
            return (
                _bytes("RENDERER_RETAINED_VERSION", registry, key, token, abi.encode(o.version)),
                count
            );
        }
        if (index == 1) {
            return (
                _bytes("RENDERER_REGISTRATION", registry, key, token, abi.encode(o.registration)),
                count
            );
        }
        if (index == 2) {
            return
                (
                    _bytes("RENDERER_DECLARED_READS", registry, key, token, abi.encode(o.reads)),
                    count
                );
        }
        if (index == 3) {
            return (
                _bytes("RENDERER_COMPLETE_TARGETS", registry, key, token, abi.encode(o.targets)),
                count
            );
        }
        if (index == 4) {
            return
                (Items.runtime(keccak256("RENDERER_REGISTRY_RUNTIME"), registry, key, token), count);
        }
        if (index == 5) {
            return (
                Items.runtime(
                    keccak256("SELECTED_RENDERER_RUNTIME"), o.selected.renderer, key, token
                ),
                count
            );
        }
        if (index == 6) {
            return (
                _bytes("RENDERER_SOURCE_BINDINGS", o.selected.renderer, key, token, o.bindings),
                count
            );
        }
        if (index == 7) {
            return (
                Items.runtime(keccak256("RENDERER_ENCODING_RUNTIME"), o.encoding, key, token), count
            );
        }
        if (index == 8) {
            return (
                _bytes(
                    "VIEW_RENDERER_FULL_POLICY_BINDING",
                    o.selected.renderer,
                    c.adoptionRecord,
                    0,
                    abi.encode(o.policy)
                ),
                count
            );
        }
        if (index < 14) {
            bytes32[5] memory ids = [
                o.registration.schemaDocument,
                o.registration.contextDocument,
                o.registration.manifestDocument,
                o.registration.analysisDocument,
                o.registration.goldenDocument
            ];
            bytes32[5] memory hashes = [
                o.registration.manifest.schemaHash,
                bytes32(0),
                o.registration.manifest.manifestHash,
                o.version.analysisHash,
                o.version.goldenHash
            ];
            row = Documents.item(d, ids[index - 9], hashes[index - 9]);
            return (row, count);
        }
        if (index < 18) {
            row = Items.runtime(
                keccak256("VIEW_RENDERER_SOURCE_RUNTIME"),
                o.sources[index - 14],
                c.adoptionRecord,
                index - 14
            );
            row.provenanceHash =
                keccak256(abi.encode(o.sources[index - 14], o.sourcePins[index - 14]));
            return (row, count);
        }
        V.Target memory target = o.targets[index - 18];
        row = Items.runtime(target.role, target.target, key, index - 18);
        row.provenanceHash = keccak256(abi.encode(registry, key, target));
    }

    function _load(
        S.Dependencies memory d,
        Router.Selection memory selected,
        Policy.Binding memory expectedPolicy
    ) private view returns (Original memory o) {
        o.selected = selected;
        address registry = selected.registry;
        IO.pin(registry, selected.registryCodeHash);
        IO.pin(selected.renderer, selected.rendererCodeHash);
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
        bytes memory raw = IO.fixedRead(
            registry, abi.encodeCall(V.version, (selected.versionKey)), 288, d.readGas
        );
        o.version = abi.decode(raw, (V.Version));
        IO.canonical(registry, raw, abi.encode(o.version));
        if (
            !o.version.exists || o.version.renderer != selected.renderer
                || o.version.runtimeHash != selected.rendererCodeHash
                || o.version.registrationHash != selected.registrationHash
                || o.version.readSetHash != selected.readSetHash
        ) {
            revert T.InventorySourceChanged();
        }
        // Deprecated immutable versions remain retained; ordinary new-assignment policy is separate.
        raw = IO.fixedRead(
            registry, abi.encodeCall(V.requireRetained, (selected.versionKey)), 64, d.sourceGas
        );
        (address retained, bytes32 retainedHash) = abi.decode(raw, (address, bytes32));
        IO.canonical(registry, raw, abi.encode(retained, retainedHash));
        if (retained != selected.renderer || retainedHash != selected.rendererCodeHash) {
            revert T.InventorySourceChanged();
        }
        raw = IO.read(
            registry, abi.encodeCall(V.registration, (selected.versionKey)), 8192, d.readGas
        );
        o.registration = abi.decode(raw, (V.Registration));
        IO.canonical(registry, raw, abi.encode(o.registration));
        R.RendererManifest memory m = o.registration.manifest;
        if (
            o.registration.renderer != selected.renderer || m.rendererId != selected.rendererId
                || m.rendererVersion != selected.rendererVersion
                || m.contextVersion != selected.contextVersion
                || m.schemaHash != selected.schemaHash || m.rendererClass != keccak256("STATIC")
                || selected.versionKey
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_RENDERER_VERSION_V1"),
                            m.rendererId,
                            m.rendererVersion
                        )
                    )
        ) {
            revert T.InventorySourceChanged();
        }
        raw = IO.read(selected.renderer, abi.encodeCall(R.rendererManifest, ()), 8192, d.readGas);
        IO.canonical(selected.renderer, raw, abi.encode(m));
        raw = IO.read(registry, abi.encodeCall(V.reads, (selected.versionKey)), 16448, d.readGas);
        o.reads = abi.decode(raw, (V.Read[]));
        IO.canonical(registry, raw, abi.encode(o.reads));
        uint256 n = uint256(IO.word(registry, abi.encodeCall(V.targetCount, ()), d.readGas));
        if (n == 0 || n > 64 || o.reads.length > 128) revert T.InvalidInventoryItem();
        o.targets = new V.Target[](n);
        for (uint256 i; i < n; ++i) {
            raw = IO.fixedRead(registry, abi.encodeCall(V.targetAt, (i)), 96, d.readGas);
            o.targets[i] = abi.decode(raw, (V.Target));
            IO.canonical(registry, raw, abi.encode(o.targets[i]));
            if (i != 0 && o.targets[i].target <= o.targets[i - 1].target) {
                revert T.InvalidInventoryItem();
            }
            IO.pin(o.targets[i].target, o.targets[i].codeHash);
        }
        bytes32 targetsHash = keccak256(abi.encode(o.targets));
        if (
            targetsHash != IO.word(registry, abi.encodeWithSignature("targetSetHash()"), d.readGas)
                || keccak256(
                        abi.encode(
                            keccak256("6529STREAM_RENDERER_READ_SET_V1"), targetsHash, o.reads
                        )
                    ) != selected.readSetHash
                || keccak256(
                        abi.encode(
                            keccak256("6529STREAM_RENDERER_REGISTRATION_V1"),
                            d.chainId,
                            registry,
                            d.targets[2],
                            d.codeHashes[2],
                            targetsHash,
                            o.registration,
                            o.reads
                        )
                    ) != selected.registrationHash
        ) {
            revert T.InventorySourceChanged();
        }
        uint256 previous;
        for (uint256 i; i < o.reads.length; ++i) {
            V.Read memory declared = o.reads[i];
            uint256 order = (uint256(declared.targetIndex) << 32) | uint32(declared.selector);
            if (
                declared.targetIndex >= n || declared.selector == 0 || (i != 0 && order <= previous)
                    || declared.maxReturnBytes == 0 || declared.maxReturnBytes > 16777216
                    || (declared.exact && declared.maxReturnBytes % 32 != 0)
            ) revert T.InvalidInventoryItem();
            previous = order;
        }
        o.bindings = IO.fixedRead(
            selected.renderer, abi.encodeCall(ViewRenderer.sourceBindings, ()), 256, d.readGas
        );
        (o.sources, o.sourcePins) = abi.decode(o.bindings, (address[4], bytes32[4]));
        IO.canonical(selected.renderer, o.bindings, abi.encode(o.sources, o.sourcePins));
        if (
            o.sources[0] != d.targets[0] || o.sourcePins[0] != d.codeHashes[0]
                || o.sources[1] != d.targets[4] || o.sourcePins[1] != d.codeHashes[4]
                || o.sources[2] != expectedPolicy.sourceSet
                || o.sourcePins[2] != expectedPolicy.sourceSetCodeHash
        ) revert T.InventorySourceChanged();
        for (uint256 i; i < 4; ++i) {
            IO.pin(o.sources[i], o.sourcePins[i]);
        }
        raw = IO.fixedRead(
            selected.renderer, abi.encodeCall(ViewRenderer.policyViewBinding, ()), 736, d.readGas
        );
        o.policy = abi.decode(raw, (Policy.Binding));
        IO.canonical(selected.renderer, raw, abi.encode(o.policy));
        if (keccak256(raw) != keccak256(abi.encode(expectedPolicy))) {
            revert T.InventorySourceChanged();
        }
        raw = IO.fixedRead(
            selected.renderer, abi.encodeWithSignature("encodingBinding()"), 64, d.readGas
        );
        (o.encoding, o.encodingHash) = abi.decode(raw, (address, bytes32));
        IO.canonical(selected.renderer, raw, abi.encode(o.encoding, o.encodingHash));
        IO.pin(o.encoding, o.encodingHash);
    }

    function _bytes(
        string memory role,
        address host,
        bytes32 record,
        uint256 token,
        bytes memory value
    ) private pure returns (T.Item memory) {
        return Items.bytesItem(
            T.Kind.NATIVE_BYTES, keccak256(bytes(role)), host, record, token, value
        );
    }
}
