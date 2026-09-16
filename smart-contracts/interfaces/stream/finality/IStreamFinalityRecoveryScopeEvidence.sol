// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamFinalityScope } from "./StreamArtworkFinalityTypes.sol";

/// @notice Authoritative family-qualified membership for a new inherited recovery scope.
/// @dev The fixed provider derives the subject and manifest from its actual registered scope
///      inventory, with exact family/collection/scope and provenance validation. The caller must
///      recompute the subject locally. COLLECTION/TOKEN return a zero manifest; RELEASE/SEASON/
///      VIEW require a nonzero family-qualified manifest. Unsupported scopes revert. This caller
///      subset is not evidence that the legacy scopeManifest(collectionId,scopeId) satisfies it.
interface IStreamFinalityRecoveryScopeEvidence {
    function requireRecoveryScope(StreamFinalityScope calldata scope)
        external
        view
        returns (bytes32 scopeSubject, bytes32 scopeManifestHash);
}
