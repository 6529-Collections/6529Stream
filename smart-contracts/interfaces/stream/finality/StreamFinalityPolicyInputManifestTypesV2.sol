// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtworkFinalityTypes.sol";
import "./StreamFinalityEvidenceTypes.sol";

/// @notice Exact independent finality manifest; detailed original evidence resolves by hash.
/// @dev The provider derives every value from its fixed live graph. Supplying this tuple is
/// not authority or readiness. The original sanction and this document's own hash are excluded.
library StreamFinalityPolicyInputManifestTypesV2 {
    struct Entropy {
        address sourceSet;
        bytes32 sourceSetCodeHash;
        bytes32 sourceSetProfile;
        bytes32 inventoryPlan;
        bytes32 inventoryHash;
        bytes32 policyChainHash;
        uint256 policyCount;
        bytes32 snapshotProfileHash;
        bytes32 referenceProfileHash;
    }

    struct Statement {
        StreamFinalityScope scope;
        bytes32 coreFactsHash;
        bytes32 contentRoot;
        uint64 leafCount;
        bytes32 contentRootSchemaId;
        bytes32 snapshotManifestHash;
        bytes32 referenceRenderManifestHash;
        StreamFinalityScopeInputs inputs;
        StreamFinalityComponentExpectation[] nonSanctionComponents;
        // Full H values resolve through the exact complete V2 source-set and snapshot commitments.
        // Explicit terminal statuses are not finalized seed evidence.
        Entropy entropy;
        uint8 postFreezePolicy; // 1 = no artwork-byte mutation exception.
        uint8 sanctionPolicy; // 1 = actual artist sanction and archive checked separately.
    }
}
