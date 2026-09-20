// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamFinalityScope } from "./StreamArtworkFinalityTypes.sol";
import {
    StreamRenderCriticalSourceTypes as Inventory
} from "../preservation/StreamRenderCriticalSourceTypes.sol";
import { IStreamGasParameterHost as Gas } from "../parameters/IStreamGasParameterHost.sol";

/// @notice Constructor-fixed deployment recipe; no caller-selected evidence hosts.
library StreamPreservationPolicyPublicationGraphTypesV1 {
    bytes32 internal constant PROFILE =
        keccak256("6529STREAM_PRESERVATION_POLICY_PUBLICATION_FACTORY_V1");

    struct Recipe {
        // Original twelve-role roster. Slots 5 and 6 and their hashes MUST be zero;
        // the factory fills them with its genuine snapshot and reference children.
        Inventory.Dependencies inventory;
        // Membership, STATIC selection, COLLECTION policy source factory, Governance executor.
        address[4] targets;
        bytes32[4] codeHashes;
        uint32 readinessReadGas;
        uint32 readinessSourceGas;
        uint256 factorySourceGas;
        uint256 bundleReadGas;
        uint256 bundleArchiveGas;
        Gas.GasParameterConfig[2] checkpointGas;
        Gas.GasParameterConfig outputGas;
        Gas.GasParameterConfig[3] snapshotGas;
        Gas.GasParameterConfig[4] referenceGas;
    }

    struct Graph {
        StreamFinalityScope scope;
        bytes32 inventoryPlan;
        address sourceSet;
        bytes32 sourceSetCodeHash;
        bytes32 graphId;
        // Readiness, checkpoint, output, snapshot, reference, inventory, bundle.
        address[7] children;
        bytes32[7] codeHashes;
        uint8 preparedChildren;
    }
    error PublicationRecipeInvalid();
    error PublicationGraphDependency(address target);
    error PublicationGraphIncomplete(bytes32 graphId);
    error PublicationGraphChanged(bytes32 graphId);
}
