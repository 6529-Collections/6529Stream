// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamFinalityScope } from "./StreamArtworkFinalityTypes.sol";

/// @notice Scope-keyed full-policy snapshot selection for the original Router's V2 root path.
/// @dev This is a separate capability; original scoped V1 and COLLECTION sources keep their selectors.
interface IStreamScopedPolicyContentRootEvidenceBindingV2 {
    function scopedPolicySnapshotHost(StreamFinalityScope calldata scope)
        external
        view
        returns (address);
    function scopedPolicySnapshotCodeHash(StreamFinalityScope calldata scope)
        external
        view
        returns (bytes32);
    function scopedPolicySnapshotValidationGas(StreamFinalityScope calldata scope)
        external
        view
        returns (uint256);
    function scopedPolicySnapshotProfile() external view returns (bytes32);
}
