// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as Snapshot
} from "../../interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as Policies
} from "../finality/StreamFinalityCoordinatorPolicyReadsV2.sol";

import {
    StreamFinalityCoordinatorPolicyV2,
    StreamFinalityCoordinatorPolicyEvidenceV2
} from "../../interfaces/stream/finality/StreamFinalityCoordinatorPolicyTypesV2.sol";

/// @notice Original runtime pins and ordered policy-pair rows after source validation.
library StreamScopedPreservationPolicyNativeRuntimeRowsV1 {
    function item(
        S.Dependencies memory d,
        Snapshot.Dependencies memory sd,
        address sourceFactory,
        Policies.Dependencies memory factory,
        StreamFinalityCoordinatorPolicyV2[] memory policies,
        bytes32 original,
        uint256 at
    ) public view returns (T.Item memory row) {
        if (at < 21) {
            row = Items.runtime(
                keccak256("SCOPED_INVENTORY_DEPENDENCY_RUNTIME"),
                d.targets[at - 9],
                original,
                at - 9
            );
        } else if (at < 32) {
            IO.pin(sd.targets[at - 21], sd.codeHashes[at - 21]);
            row = Items.runtime(
                keccak256("SCOPED_SNAPSHOT_DEPENDENCY_RUNTIME"),
                sd.targets[at - 21],
                original,
                at - 21
            );
        } else if (at < 37) {
            row = Items.runtime(
                keccak256("ORIGINAL_ARTIST_DEPENDENCY_RUNTIME"),
                d.artistTargets[at - 32],
                original,
                at - 32
            );
        } else if (at == 37) {
            row = Items.runtime(
                keccak256("ORIGINAL_ARTIST_CONTENT_OWNER_RUNTIME"),
                d.artistContentOwner,
                original,
                0
            );
        } else if (at == 38) {
            row = Items.runtime(
                keccak256("SCOPED_POLICY_SOURCE_FACTORY_RUNTIME_V2"), sourceFactory, original, 0
            );
        } else if (at == 39) {
            row = Items.bytesItem(
                T.Kind.NATIVE_BYTES,
                keccak256("SCOPED_POLICY_SOURCE_FACTORY_DEPENDENCIES_V2"),
                sourceFactory,
                original,
                0,
                abi.encode(factory)
            );
        } else if (at < 44) {
            row = Items.runtime(
                keccak256("SCOPED_POLICY_FACTORY_DEPENDENCY_RUNTIME_V2"),
                factory.targets[at - 40],
                original,
                at - 40
            );
        } else {
            uint256 index = (at - 44) / 2;
            address coordinator = policies[index].coordinator;
            IO.pin(coordinator, policies[index].indexedCodeHash);
            if ((at - 44) % 2 == 0) {
                row = Items.runtime(
                    keccak256("ORIGINAL_COORDINATOR_RUNTIME"), coordinator, original, index
                );
            } else {
                row = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("ORIGINAL_COORDINATOR_POLICY_V2"),
                    coordinator,
                    original,
                    index,
                    abi.encode(policies[index])
                );
            }
        }
    }
}
