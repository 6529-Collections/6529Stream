// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamViewRetrievalWitnessV1 as Witness
} from "../../interfaces/stream/preservation/IStreamViewRetrievalWitnessV1.sol";
import {
    IStreamViewPreservationRenderCriticalInventoryV1 as Inventory
} from "../../interfaces/stream/preservation/IStreamViewPreservationRenderCriticalInventoryV1.sol";
import {
    StreamViewRetrievalWitnessTypesV1 as W
} from "../../interfaces/stream/preservation/StreamViewRetrievalWitnessTypesV1.sol";
import {
    StreamViewPreservationRenderCriticalTypesV1 as V
} from "../../interfaces/stream/preservation/StreamViewPreservationRenderCriticalTypesV1.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamBundleArchiveTypes as B
} from "../../interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamFinalityScope
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamViewRetrievalBindingV1 as Binding } from "./StreamViewRetrievalBindingV1.sol";
import {
    StreamViewRetrievalObligationV1 as Obligation
} from "./StreamViewRetrievalObligationV1.sol";
import { StreamViewRetrievalCodecV1 as Codec } from "./StreamViewRetrievalCodecV1.sol";
import {
    StreamViewPreservationMediaCorrespondenceV1 as Media
} from "./StreamViewPreservationMediaCorrespondenceV1.sol";
import { StreamBundleArchiveReads as Original } from "./StreamBundleArchiveReads.sol";

/// @notice One exact correspondence path for VIEW cover, refresh, full-current and media review.
library StreamViewRetrievalConsumerV1 {
    function _binding(B.Dependencies memory d)
        private
        view
        returns (address witness, bytes32 codeHash, W.Configuration memory c)
    {
        if (d.chainId != block.chainid) revert W.InvalidViewRetrieval();
        IO.pin(d.targets[2], d.codeHashes[2]);
        bytes memory raw =
            IO.fixedRead(d.targets[2], abi.encodeCall(Inventory.dependencies, ()), 1344, d.readGas);
        S.Dependencies memory source = abi.decode(raw, (S.Dependencies));
        IO.canonical(d.targets[2], raw, abi.encode(source));
        if (
            source.chainId != d.chainId || source.targets[0] != d.targets[0]
                || source.codeHashes[0] != d.codeHashes[0] || source.targets[1] != d.targets[1]
                || source.codeHashes[1] != d.codeHashes[1] || source.targets[10] != d.targets[3]
                || source.codeHashes[10] != d.codeHashes[3] || source.targets[11] != d.targets[4]
                || source.codeHashes[11] != d.codeHashes[4]
                || source.artistTargets[4] != d.targets[5]
                || source.artistCodeHashes[4] != d.codeHashes[5]
                || IO.word(d.targets[2], abi.encodeCall(Inventory.dependencyHash, ()), d.readGas)
                    != keccak256(raw)
        ) revert W.InvalidViewRetrieval();
        return Binding.requireInventory(d.targets[2], source, d.readGas);
    }

    function environment(
        B.Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 originalEnvironment
    ) public view returns (bytes32) {
        (address witness, bytes32 codeHash,) = _binding(d);
        bytes memory raw =
            IO.fixedRead(witness, abi.encodeCall(Witness.revocationEpoch, (scope)), 32, d.readGas);
        uint64 epoch = abi.decode(raw, (uint64));
        IO.canonical(witness, raw, abi.encode(epoch));
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_RETRIEVAL_ARCHIVE_ENVIRONMENT_V1"),
                originalEnvironment,
                witness,
                codeHash,
                scope,
                epoch
            )
        );
    }

    function context(B.Dependencies memory d, bytes32 plan, V.Evidence memory e)
        public
        view
        returns (V.Context memory c)
    {
        IO.pin(d.targets[2], d.codeHashes[2]);
        bytes memory raw =
            IO.read(d.targets[2], abi.encodeCall(Inventory.sourceContext, (plan)), 16384, d.readGas);
        c = abi.decode(raw, (V.Context));
        IO.canonical(d.targets[2], raw, abi.encode(c));
        bytes32 dependency =
            IO.word(d.targets[2], abi.encodeCall(Inventory.dependencyHash, ()), d.readGas);
        if (
            plan == 0 || e.inventory.planId != plan || e.inventory.artistId != c.artistId
                || e.inventory.sourceContextHash != keccak256(raw)
                || keccak256(abi.encode(e.scope)) != keccak256(abi.encode(c.scope))
                || keccak256(
                        abi.encode(
                            keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_PLAN_V1"),
                            d.chainId,
                            d.targets[2],
                            dependency,
                            c
                        )
                    ) != plan
        ) revert W.InvalidViewRetrieval();
    }

    function admit(
        B.Dependencies memory d,
        V.Context memory c,
        T.Item memory item,
        bytes32 recordHash
    ) public view returns (B.Admission memory a, bytes32 observation) {
        if (recordHash == 0 || (item.role != W.ROLE && item.role != Media.LOCATOR_ROLE)) revert W.InvalidViewRetrieval();
        (address witness, bytes32 codeHash, W.Configuration memory config) = _binding(d);
        bytes memory raw = IO.read(
            witness,
            abi.encodeCall(Witness.requireCorrespondence, (recordHash)),
            16384,
            d.archiveGas
        );
        (W.Source memory source, W.Receipt memory receipt, B.Admission memory actual) =
            abi.decode(raw, (W.Source, W.Receipt, B.Admission));
        IO.canonical(witness, raw, abi.encode(source, receipt, actual));
        if (
            receipt.recordHash != recordHash || receipt.sourceKey != Codec.sourceKey(source)
                || receipt.objectHash != actual.proof.objectHash
                || receipt.coverageHash != actual.proof.coverageHash || receipt.payloadHash == 0
                || actual.proof.backend != 1 || source.core != d.targets[0]
                || source.router != config.router || source.adoptionRecord != c.adoptionRecord
                || source.payloadHash != c.payloadHash
                || source.checkpointContextHash != c.sourceContextHash
                || c.artistId != source.artistId || c.artistId != actual.externalOriginal.artistId
                || keccak256(abi.encode(source.scope)) != keccak256(abi.encode(c.scope))
                || keccak256(abi.encode(item)) != keccak256(abi.encode(Obligation.item(source)))
        ) revert W.InvalidViewRetrieval();
        T.Item memory materialized = abi.decode(abi.encode(item), (T.Item));
        materialized.algorithm = 1;
        materialized.digest = abi.encodePacked(actual.externalOriginal.contentHash);
        materialized.byteSize = actual.externalOriginal.byteSize;
        bytes32 pairObservation = Original.current(d, c.artistId, materialized, actual);
        a = actual;
        a.originalBundleHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_RETRIEVAL_ADMITTED_BUNDLE_V1"),
                actual.originalBundleHash,
                witness,
                codeHash,
                keccak256(abi.encode(W.PROFILE, config)),
                recordHash,
                receipt.payloadHash
            )
        );
        observation = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_RETRIEVAL_CURRENT_OBSERVATION_V1"),
                source,
                receipt,
                pairObservation
            )
        );
    }

    function current(
        B.Dependencies memory d,
        V.Context memory c,
        T.Item memory item,
        B.Admission memory saved,
        bytes32 witnessHash
    ) public view returns (bytes32 observation) {
        B.Admission memory actual;
        (actual, observation) = admit(d, c, item, witnessHash);
        if (keccak256(abi.encode(actual)) != keccak256(abi.encode(saved))) {
            revert T.InventorySourceChanged();
        }
    }
}
