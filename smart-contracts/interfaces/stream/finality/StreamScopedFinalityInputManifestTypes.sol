// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtworkFinalityTypes.sol";
import "./StreamFinalityEvidenceTypes.sol";

/// @notice Exact TOKEN/RELEASE/SEASON finality manifest with full original scoped identities.
/// @dev The provider derives every value from its fixed live graph. Supplying this tuple is
/// not authority or readiness. The original sanction and this document's own hash are excluded.
library StreamScopedFinalityInputManifestTypes {
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
        // This native artist-bound scoped profile admits only each named policy.
        uint8 entropyPolicy; // 1 = every member terminal; no deferred entropy exception.
        uint8 postFreezePolicy; // 1 = no artwork-byte mutation exception.
        uint8 sanctionPolicy; // 1 = actual artist sanction and archive checked separately.
    }
}
