// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamViewPreservationRenderCriticalTypesV1 as View
} from "../../interfaces/stream/preservation/StreamViewPreservationRenderCriticalTypesV1.sol";
import {
    StreamViewPreservationReferenceTypesV1 as Reference
} from "../../interfaces/stream/preservation/StreamViewPreservationReferenceTypesV1.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as C
} from "../../interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    IStreamPreservationRegistryV1 as P
} from "../../interfaces/stream/metadata/IStreamPreservationRegistryV1.sol";
import {
    IStreamRendererRegistry as V
} from "../../interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamViewPreservationRendererV1 as Producer
} from "../../interfaces/stream/metadata/IStreamViewPreservationRendererV1.sol";
import {
    StreamViewPreservationRenderCriticalSourceReadsV1 as Sources
} from "./StreamViewPreservationRenderCriticalSourceReadsV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import {
    StreamPreservationDocumentReads as Documents
} from "./StreamPreservationDocumentReads.sol";

import {
    StreamViewPreservationRenderCriticalRetainedReadsV1 as Retained
} from "./StreamViewPreservationRenderCriticalRetainedReadsV1.sol";

/// @notice Separate governed preservation admission, complete read roster and actual fixed producer workers.
/// @dev Explicit old VIEW preservation profile only; current-Artist successors require their own admission branch.
library StreamViewPreservationRenderCriticalAdmissionReadsV1 {
    struct Original {
        address registry;
        bytes32 key;
        P.PreservationRecord record;
        V.Read[] reads;
        V.Target[] targets;
        Producer.Configuration configuration;
        address worker;
        bytes32 workerHash;
        address encoder;
        bytes32 encoderHash;
        Producer.Binding binding;
    }

    function item(S.Dependencies memory d, View.Context memory c, uint64 index)
        public
        view
        returns (T.Item memory row, uint64 count)
    {
        Original memory o = _load(d, c);
        count = uint64(14 + o.targets.length);
        if (index >= count) revert T.InvalidInventoryItem();
        P.ProducerBinding memory b = o.record.registration.binding;
        if (index == 0) {
            return (
                _bytes("VIEW_PRESERVATION_REGISTRATION", o.registry, o.key, abi.encode(o.record)),
                count
            );
        }
        if (index == 1) {
            return (
                _bytes("VIEW_PRESERVATION_DECLARED_READS", o.registry, o.key, abi.encode(o.reads)),
                count
            );
        }
        if (index == 2) {
            return (
                _bytes(
                    "VIEW_PRESERVATION_COMPLETE_TARGETS", o.registry, o.key, abi.encode(o.targets)
                ),
                count
            );
        }
        if (index == 3) {
            return (
                _bytes(
                    "VIEW_PRESERVATION_CONFIGURATION",
                    b.producer,
                    o.key,
                    abi.encode(o.configuration)
                ),
                count
            );
        }
        if (index == 4) {
            return (
                _bytes(
                    "VIEW_PRESERVATION_ACTUAL_ADOPTION_BINDING",
                    b.producer,
                    c.adoptionRecord,
                    abi.encode(o.binding)
                ),
                count
            );
        }
        if (index == 5) {
            return (
                Items.runtime(
                    keccak256("VIEW_PRESERVATION_PRODUCER_RUNTIME"), b.producer, o.key, 0
                ),
                count
            );
        }
        if (index == 6) {
            return (
                Items.runtime(
                    keccak256("VIEW_PRESERVATION_ATTRIBUTION_RUNTIME"), b.attribution, o.key, 0
                ),
                count
            );
        }
        if (index == 7) {
            return (
                Items.runtime(
                    keccak256("VIEW_PRESERVATION_FIXED_WORKER_RUNTIME"), o.worker, o.key, 0
                ),
                count
            );
        }
        if (index == 8) {
            return (
                Items.runtime(keccak256("VIEW_PRESERVATION_ENCODING_RUNTIME"), o.encoder, o.key, 0),
                count
            );
        }
        if (index == 9) {
            return (
                _bytes(
                    "VIEW_PRESERVATION_WORKER_BINDING",
                    b.producer,
                    o.key,
                    abi.encode(o.worker, o.workerHash)
                ),
                count
            );
        }
        if (index == 10) {
            return (
                _bytes(
                    "VIEW_PRESERVATION_ENCODING_BINDING",
                    b.producer,
                    o.key,
                    abi.encode(o.encoder, o.encoderHash)
                ),
                count
            );
        }
        if (index < 14) {
            bytes32[3] memory ids = [
                o.record.registration.schemaDocument,
                o.record.registration.analysisDocument,
                o.record.registration.goldenDocument
            ];
            bytes32[3] memory hashes = [bytes32(0), o.record.analysisHash, o.record.goldenHash];
            return (Documents.item(d, ids[index - 11], hashes[index - 11]), count);
        }
        V.Target memory target = o.targets[index - 14];
        row = Items.runtime(target.role, target.target, o.key, index - 14);
        row.provenanceHash = keccak256(abi.encode(o.registry, o.key, target));
    }

    function _load(S.Dependencies memory d, View.Context memory c)
        private
        view
        returns (Original memory o)
    {
        Reference.SourceFacts memory facts = Retained.sourceFacts(d, c);
        C.Source memory source = facts.snapshotSource.adoption;
        o.registry = source.admission.registry;
        IO.pin(o.registry, source.admission.registryCodeHash);
        address producer = facts.contentBinding.preservationRenderer;
        if (
            producer == address(0)
                || source.admission.versionKey != source.adoption.source.renderer.versionKey
                || source.admission.registry != source.adoption.source.renderer.registry
                || source.admission.registryCodeHash
                    != source.adoption.source.renderer.registryCodeHash
        ) revert T.InventorySourceChanged();
        o.key = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRESERVATION_KEY_V1"),
                source.admission.versionKey,
                producer,
                C.OUTPUT_PROFILE
            )
        );
        bytes memory raw =
            IO.fixedRead(o.registry, abi.encodeCall(P.preservationRecord, (o.key)), 576, d.readGas);
        o.record = abi.decode(raw, (P.PreservationRecord));
        IO.canonical(o.registry, raw, abi.encode(o.record));
        P.ProducerBinding memory b = o.record.registration.binding;
        if (
            b.producer != producer || b.profile != C.OUTPUT_PROFILE || b.core != d.targets[0]
                || b.router != d.targets[4] || b.liveRenderer != source.preservation.liveRenderer
                || b.liveRendererCodeHash != source.preservation.liveRendererRuntimeHash
                || b.attribution != source.preservation.preservationAttribution
                || b.attributionCodeHash != source.preservation.preservationAttributionRuntimeHash
                || o.record.registration.versionKey != source.admission.versionKey
                || o.record.actionId == 0
                || o.record.registrationHash != source.admission.registrationHash
                || o.record.readSetHash != source.admission.readSetHash
                || o.record.analysisHash != source.admission.analysisHash
                || o.record.goldenHash != source.admission.goldenHash
        ) revert T.InventorySourceChanged();
        IO.pin(producer, b.producerCodeHash);
        IO.pin(b.liveRenderer, b.liveRendererCodeHash);
        IO.pin(b.attribution, b.attributionCodeHash);
        raw = IO.fixedRead(
            o.registry,
            abi.encodeCall(
                P.requirePreservation, (source.admission.versionKey, producer, C.OUTPUT_PROFILE)
            ),
            512,
            d.sourceGas
        );
        IO.canonical(o.registry, raw, abi.encode(b, source.admission));
        if (
            IO.addressWord(o.registry, abi.encodeWithSignature("schemaRegistry()"), d.readGas)
                    != d.targets[2]
                || IO.word(
                        o.registry, abi.encodeWithSignature("schemaRegistryCodeHash()"), d.readGas
                    ) != d.codeHashes[2]
                || uint256(
                        IO.word(
                            o.registry, abi.encodeWithSignature("deploymentChainId()"), d.readGas
                        )
                    ) != d.chainId
        ) revert T.InventorySourceChanged();
        raw = IO.read(o.registry, abi.encodeCall(P.preservationReads, (o.key)), 16448, d.readGas);
        o.reads = abi.decode(raw, (V.Read[]));
        IO.canonical(o.registry, raw, abi.encode(o.reads));
        uint256 n = uint256(IO.word(o.registry, abi.encodeCall(V.targetCount, ()), d.readGas));
        if (n == 0 || n > 64 || o.reads.length > 128) revert T.InvalidInventoryItem();
        o.targets = new V.Target[](n);
        for (uint256 i; i < n; ++i) {
            raw = IO.fixedRead(o.registry, abi.encodeCall(V.targetAt, (i)), 96, d.readGas);
            o.targets[i] = abi.decode(raw, (V.Target));
            IO.canonical(o.registry, raw, abi.encode(o.targets[i]));
            if (i != 0 && o.targets[i].target <= o.targets[i - 1].target) {
                revert T.InvalidInventoryItem();
            }
            IO.pin(o.targets[i].target, o.targets[i].codeHash);
        }
        bytes32 targetHash = keccak256(abi.encode(o.targets));
        if (
            targetHash != IO.word(o.registry, abi.encodeWithSignature("targetSetHash()"), d.readGas)
                || keccak256(
                        abi.encode(
                            keccak256("6529STREAM_RENDERER_READ_SET_V1"), targetHash, o.reads
                        )
                    ) != o.record.readSetHash
                || keccak256(
                        abi.encode(
                            keccak256("6529STREAM_PRESERVATION_REGISTRATION_V1"),
                            d.chainId,
                            o.registry,
                            d.targets[2],
                            d.codeHashes[2],
                            targetHash,
                            source.adoption.source.renderer.registrationHash,
                            o.record.registration,
                            o.reads
                        )
                    ) != o.record.registrationHash
        ) revert T.InventorySourceChanged();
        uint256 previous;
        for (uint256 i; i < o.reads.length; ++i) {
            V.Read memory r = o.reads[i];
            uint256 order = (uint256(r.targetIndex) << 32) | uint32(r.selector);
            if (
                r.targetIndex >= n || r.selector == 0 || (i != 0 && order <= previous)
                    || r.maxReturnBytes == 0 || r.maxReturnBytes > 16777216
                    || (r.exact && r.maxReturnBytes % 32 != 0)
            ) revert T.InvalidInventoryItem();
            previous = order;
        }
        raw = IO.fixedRead(producer, abi.encodeCall(Producer.configuration, ()), 288, d.readGas);
        o.configuration = abi.decode(raw, (Producer.Configuration));
        IO.canonical(producer, raw, abi.encode(o.configuration));
        if (
            o.configuration.core != d.targets[0] || o.configuration.coreCodeHash != d.codeHashes[0]
                || o.configuration.router != d.targets[4]
                || o.configuration.routerCodeHash != d.codeHashes[4]
                || o.configuration.preservationAttribution != b.attribution
                || o.configuration.preservationAttributionCodeHash != b.attributionCodeHash
                || o.configuration.chainId != d.chainId
        ) revert T.InventorySourceChanged();
        raw = IO.fixedRead(producer, abi.encodeCall(Producer.workerBinding, ()), 64, d.readGas);
        (o.worker, o.workerHash) = abi.decode(raw, (address, bytes32));
        IO.canonical(producer, raw, abi.encode(o.worker, o.workerHash));
        IO.pin(o.worker, o.workerHash);
        raw = IO.fixedRead(producer, abi.encodeCall(Producer.encodingBinding, ()), 64, d.readGas);
        (o.encoder, o.encoderHash) = abi.decode(raw, (address, bytes32));
        IO.canonical(producer, raw, abi.encode(o.encoder, o.encoderHash));
        IO.pin(o.encoder, o.encoderHash);
        if (
            IO.word(producer, abi.encodeCall(Producer.configurationHash, ()), d.readGas)
                != keccak256(
                    abi.encode(
                        C.OUTPUT_PROFILE,
                        d.chainId,
                        producer,
                        o.configuration,
                        o.worker,
                        o.workerHash,
                        o.encoder,
                        o.encoderHash
                    )
                )
        ) revert T.InventorySourceChanged();
        raw = IO.fixedRead(
            producer,
            abi.encodeCall(Producer.preservationViewBinding, (c.adoptionRecord)),
            192,
            d.sourceGas
        );
        o.binding = abi.decode(raw, (Producer.Binding));
        IO.canonical(producer, raw, abi.encode(o.binding));
        if (keccak256(raw) != keccak256(abi.encode(source.preservation))) {
            revert T.InventorySourceChanged();
        }
    }

    function _bytes(string memory role, address host, bytes32 record, bytes memory raw)
        private
        pure
        returns (T.Item memory)
    {
        return Items.bytesItem(T.Kind.NATIVE_BYTES, keccak256(bytes(role)), host, record, 0, raw);
    }
}
