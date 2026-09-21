// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityViewPreservationConfigurationV1 as Configuration
} from "./StreamFinalityViewPreservationConfigurationV1.sol";
import {
    StreamFinalityNativeProviderReads as Native
} from "./StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityViewPreservationInputTypesV1 as Statement
} from "../../interfaces/stream/finality/StreamFinalityViewPreservationInputTypesV1.sol";
import {
    StreamViewPreservationRenderCriticalTypesV1 as V
} from "../../interfaces/stream/preservation/StreamViewPreservationRenderCriticalTypesV1.sol";
import {
    IStreamViewPreservationRenderCriticalInventoryV1 as Inventory
} from "../../interfaces/stream/preservation/IStreamViewPreservationRenderCriticalInventoryV1.sol";
import {
    StreamViewPreservationRenderCriticalArtworkReadsV1 as Artwork
} from "../preservation/StreamViewPreservationRenderCriticalArtworkReadsV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamBundleArchiveTypes as B
} from "../../interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamViewPreservationArchiveReadsV1 as Archive
} from "../preservation/StreamViewPreservationArchiveReadsV1.sol";
import {
    StreamPreservationInventoryChains as Chains
} from "../preservation/StreamPreservationInventoryChains.sol";
import {
    StreamPreservationInventoryIO as IO
} from "../preservation/StreamPreservationInventoryIO.sol";
import {
    StreamViewPreservationBundleArchiveCoverageV1 as Bundle
} from "../preservation/StreamViewPreservationBundleArchiveCoverageV1.sol";
import {
    IStreamViewPreservationBundleArchiveCoverageV1 as Coverage
} from "../../interfaces/stream/preservation/IStreamViewPreservationBundleArchiveCoverageV1.sol";

/// @notice Exact media content from the already complete current VIEW artwork and archive.
/// @dev No arbitrary item position is accepted. Find the original stage8 witness in the exact
/// completed segment list and independently rebuild all seven artwork rows before its archive join.
library StreamFinalityViewMediaReviewV1 {
    error InvalidViewMediaReview();

    function hashes(Native.Config memory original, Statement.Statement memory statement)
        public
        view
        returns (bytes32[] memory values)
    {
        Configuration.Context memory x = Configuration.resolve(original);
        Native.Config memory c = x.effective;
        bytes memory raw = IO.fixedRead(
            c.targets[18],
            abi.encodeCall(Inventory.requireCurrent, (statement.scope)),
            736,
            c.sourceGas
        );
        V.Evidence memory e = abi.decode(raw, (V.Evidence));
        IO.canonical(c.targets[18], raw, abi.encode(e));
        if (
            e.inventory.renderCriticalEvidenceHash != statement.inputs.renderCriticalEvidenceHash
                || keccak256(abi.encode(e.scope)) != keccak256(abi.encode(statement.scope))
        ) revert InvalidViewMediaReview();
        raw = IO.fixedRead(
            c.targets[19],
            abi.encodeCall(
                Coverage.requireCoverage,
                (statement.scope, e.inventory.planId, e.inventory.renderCriticalEvidenceHash)
            ),
            288,
            c.sourceGas
        );
        V.BundleEvidence memory coverage = abi.decode(raw, (V.BundleEvidence));
        IO.canonical(c.targets[19], raw, abi.encode(coverage));
        if (
            coverage.coverage.bundleCoverageHash != statement.inputs.bundleCoverageHash
                || coverage.coverage.inventoryPlan != e.inventory.planId
                || coverage.coverage.itemCount != e.inventory.itemCount
                || coverage.coverage.renderCriticalEvidenceHash
                    != e.inventory.renderCriticalEvidenceHash
                || keccak256(abi.encode(coverage.scope)) != keccak256(abi.encode(statement.scope))
        ) revert InvalidViewMediaReview();
        raw = IO.read(
            c.targets[18],
            abi.encodeCall(Inventory.sourceContext, (e.inventory.planId)),
            16384,
            c.readGas
        );
        V.Context memory context = abi.decode(raw, (V.Context));
        IO.canonical(c.targets[18], raw, abi.encode(context));
        if (
            keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_PLAN_V1"),
                        c.chainId,
                        c.targets[18],
                        c.inventoryDependencyHash,
                        context
                    )
                ) != e.inventory.planId
        ) {
            revert InvalidViewMediaReview();
        }
        T.Item[] memory rows = Artwork.items(x.inventory, context);
        if (rows.length != 7) revert InvalidViewMediaReview();
        bytes32 witness = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_OUTPUT_INVENTORY_SOURCE_V1"),
                context.adoptionRecord,
                context.checkpointHash,
                context.sourceContextHash,
                uint16(8),
                uint64(0),
                uint64(7)
            )
        );
        uint64 offset;
        bool found;
        for (uint64 i; i < e.inventory.segmentCount; ++i) {
            raw = IO.fixedRead(
                c.targets[18],
                abi.encodeCall(Inventory.inventorySegment, (e.inventory.planId, i)),
                128,
                c.readGas
            );
            T.Segment memory segment = abi.decode(raw, (T.Segment));
            IO.canonical(c.targets[18], raw, abi.encode(segment));
            if (segment.sourceWitnessHash == witness) {
                bytes32 key = keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_SEGMENT_V1"),
                        e.inventory.planId,
                        i
                    )
                );
                if (
                    keccak256(raw)
                        != keccak256(abi.encode(Chains.segmentInMemory(key, witness, rows)))
                ) revert InvalidViewMediaReview();
                found = true;
                break;
            }
            offset += segment.itemCount;
        }
        if (!found || uint256(offset) + 7 > e.inventory.itemCount) revert InvalidViewMediaReview();
        if (rows[5].kind == T.Kind.ABSENT) return new bytes32[](0);
        raw = IO.read(
            c.targets[19],
            abi.encodeCall(Bundle.admittedItem, (e.inventory.planId, offset + 5)),
            16384,
            c.sourceGas
        );
        (T.Item memory item, B.Admission memory saved) = abi.decode(raw, (T.Item, B.Admission));
        IO.canonical(c.targets[19], raw, abi.encode(item, saved));
        if (keccak256(abi.encode(item)) != keccak256(abi.encode(rows[5]))) {
            revert InvalidViewMediaReview();
        }
        raw = IO.fixedRead(c.targets[19], abi.encodeWithSignature("dependencies()"), 480, c.readGas);
        B.Dependencies memory d = abi.decode(raw, (B.Dependencies));
        IO.canonical(c.targets[19], raw, abi.encode(d));
        // Re-run original full object correspondence, not only the cheap immutable pair projection.
        (B.Admission memory current,) = Archive.admit(d, e.inventory.artistId, item, saved.proof);
        if (keccak256(abi.encode(current)) != keccak256(abi.encode(saved))) {
            revert InvalidViewMediaReview();
        }
        bytes32 hash;
        if (saved.proof.backend == 1) hash = saved.externalOriginal.contentHash;
        else if (saved.proof.backend == 2) hash = saved.onchainOriginal.contentHash;
        if (hash == 0) revert InvalidViewMediaReview();
        values = new bytes32[](1);
        values[0] = hash;
    }
}
