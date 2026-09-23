// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamFinalityScope } from "./StreamArtworkFinalityTypes.sol";

/// @notice Scope-keyed full-policy snapshot selection for the original Router's new preservation root path.
/// @dev This is a separate capability; original scoped V1 and COLLECTION sources keep their selectors.
interface IStreamScopedPreservationPolicyContentRootEvidenceBindingV1 {
    function scopedPreservationPolicySnapshotHost(StreamFinalityScope calldata scope)
        external
        view
        returns (address);
    function scopedPreservationPolicySnapshotCodeHash(StreamFinalityScope calldata scope)
        external
        view
        returns (bytes32);
    function scopedPreservationPolicySnapshotValidationGas(StreamFinalityScope calldata scope)
        external
        view
        returns (uint256);
    function scopedPreservationPolicySnapshotProfile() external view returns (bytes32);
}
