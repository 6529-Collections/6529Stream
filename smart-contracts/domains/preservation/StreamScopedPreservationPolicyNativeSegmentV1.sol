// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyOutputSchemasV2 as OutputV2
} from "../finality/StreamPreservationPolicyOutputSchemasV2.sol";
import {
    StreamScopedPreservationPolicySnapshotDefinitionsV2 as DefinitionsV2
} from "../records/StreamScopedPreservationPolicySnapshotDefinitionsV2.sol";
import {
    StreamPreservationPolicyInventoryFamilyV2 as FamilyRead
} from "./StreamPreservationPolicyInventoryFamilyV2.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Family
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalTypesV1 as Scoped
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamScopedPreservationPolicyReferenceTypesV1 as R
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyReferenceTypesV1.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as Snapshot
} from "../../interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1 as Snap
} from "../../interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalStateV1 as State
} from "./StreamScopedPreservationPolicyRenderCriticalStateV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalSourceReadsV1 as Sources
} from "./StreamScopedPreservationPolicyRenderCriticalSourceReadsV1.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import {
    StreamScopedPreservationPolicySnapshotDefinitionsV1 as Definitions
} from "../records/StreamScopedPreservationPolicySnapshotDefinitionsV1.sol";
import {
    IStreamFinalityScopedEntropyPolicySourceFactoryV2 as Factory
} from "../../interfaces/stream/finality/IStreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as Policies
} from "../finality/StreamFinalityCoordinatorPolicyReadsV2.sol";
import {
    StreamPreservationPolicyOutputSchemasV1 as OutputSchemas
} from "../finality/StreamPreservationPolicyOutputSchemasV1.sol";

import {
    StreamScopedPreservationPolicyNativeSourceV1 as NativeSource
} from "./StreamScopedPreservationPolicyNativeSourceV1.sol";
import {
    StreamScopedPreservationPolicyNativeReceiptRowsV1 as ReceiptRows
} from "./StreamScopedPreservationPolicyNativeReceiptRowsV1.sol";
import {
    StreamScopedPreservationPolicyNativeFactRowsV1 as FactRows
} from "./StreamScopedPreservationPolicyNativeFactRowsV1.sol";
import {
    StreamScopedPreservationPolicyNativePlanRowsV1 as PlanRows
} from "./StreamScopedPreservationPolicyNativePlanRowsV1.sol";
import {
    StreamScopedPreservationPolicyNativeRuntimeRowsV1 as RuntimeRows
} from "./StreamScopedPreservationPolicyNativeRuntimeRowsV1.sol";

/// @notice Fixed complete native segment construction after the original source checks.
/// @dev Full Context and SourceFacts authentication precedes every consumed projection and row.
library StreamScopedPreservationPolicyNativeSegmentV1 {
    function items(
        S.Dependencies memory d,
        Scoped.Context memory c,
        uint64 start,
        uint64 maximum,
        bytes32 family
    ) public view returns (T.Item[] memory rows, uint64 total) {
        if (maximum == 0 || maximum > 64) revert T.InvalidInventorySegment();
        Snapshot.Dependencies memory sd = Sources.snapshotBindings(d, family);
        NativeSource.Facts memory f = NativeSource.read(d, c, family);
        // Preserve the actual factory tuple and all four constructor targets, in addition
        // to the original inventory/snapshot/Artist roster and complete policy occurrences.
        Policies.Dependencies memory factory = _factory(d, f);
        uint256 count = 44 + f.snapshotSource.entropy.policies.length * 2;
        if (
            count > type(uint64).max || start >= count || !f.snapshotSource.entropy.allFrozen
                || f.snapshotSource.entropy.policyCount != f.snapshotSource.entropy.policies.length
        ) revert T.InventorySourceChanged();
        total = uint64(count);
        uint256 length = count - start;
        if (length > maximum) length = maximum;
        rows = new T.Item[](length);
        bytes32 original = c.snapshot.recordHash;
        for (uint256 i; i < length; ++i) {
            uint256 at = start + i;
            if (at == 0) {
                rows[i] = ReceiptRows.record(d.targets[5], c.snapshot, c.scope, d.sourceGas);
            } else if (at == 1) {
                rows[i] = ReceiptRows.payload(d.targets[5], c.snapshot, d.sourceGas, family);
            } else if (at == 2) {
                rows[i] = FactRows.source(d.targets[5], original, f.snapshotSource);
            } else if (at == 3) {
                rows[i] = FactRows.root(
                    d.targets[4], c.rootRecordHash, f.contentRoot, f.contentRootBinding
                );
            } else if (at == 4) {
                rows[i] =
                    PlanRows.selection(sd.targets[6], c.selectionId, f.snapshotSource.selection);
            } else if (at == 5) {
                rows[i] =
                    PlanRows.content(sd.targets[7], c.checkpointHash, f.snapshotSource.content);
            } else if (at == 6) {
                rows[i] = PlanRows.outputs(
                    sd.targets[8], c.outputManifestRecord, f.snapshotSource.outputs
                );
            } else if (at == 7) {
                rows[i] = PlanRows.outputRows(
                    sd.targets[8], c.outputManifestRecord, f.snapshotSource.outputs, family
                );
            } else if (at == 8) {
                rows[i] = PlanRows.entropy(sd.targets[10], original, f.snapshotSource.entropy);
            } else {
                rows[i] = RuntimeRows.item(
                    d,
                    sd,
                    f.snapshotSource.sourceFactory,
                    factory,
                    f.snapshotSource.entropy.policies,
                    original,
                    at
                );
            }
        }
    }

    function _factory(S.Dependencies memory d, NativeSource.Facts memory f)
        private
        view
        returns (Policies.Dependencies memory saved)
    {
        address factory = f.snapshotSource.sourceFactory;
        IO.pin(factory, f.snapshotSource.sourceFactoryCodeHash);
        bytes memory raw =
            IO.fixedRead(factory, abi.encodeCall(Factory.dependencies, ()), 352, d.readGas);
        saved = abi.decode(raw, (Policies.Dependencies));
        IO.canonical(factory, raw, abi.encode(saved));
        if (keccak256(raw) != f.snapshotSource.factoryDependenciesHash) {
            revert T.InventorySourceChanged();
        }
        Policies.validateDependencies(saved);
    }
}
