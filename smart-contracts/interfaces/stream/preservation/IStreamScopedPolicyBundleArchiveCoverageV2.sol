// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC165 } from "../../../vendor/openzeppelin/IERC165.sol";
import {
    StreamScopedPolicyBundleArchiveTypesV2 as PolicyBundle
} from "./StreamScopedPolicyBundleArchiveTypesV2.sol";
import { StreamFinalityScope } from "../finality/StreamArtworkFinalityTypes.sol";

/// @notice Complete archival admission for a distinct scoped full-policy inventory.
interface IStreamScopedPolicyBundleArchiveCoverageV2 is IERC165 {
    function scopedPolicyBundleArchiveProfile() external pure returns (bytes32);
    function core() external view returns (address);
    function metadataHost() external view returns (address);
    function renderCriticalInventory() external view returns (address);
    function artifactCoverage() external view returns (address);
    function externalCoverage() external view returns (address);
    function deploymentChainId() external view returns (uint256);
    function coreCodeHash() external view returns (bytes32);
    function metadataCodeHash() external view returns (bytes32);
    function inventoryCodeHash() external view returns (bytes32);
    function bundleEvidence(bytes32 inventoryPlan)
        external
        view
        returns (PolicyBundle.BundleEvidence memory);

    /// @notice Exact completed inventory's archive liveness, independently of source currentness.
    /// @dev First authenticate this capability/profile. Compose with the new typed scoped-policy
    /// inventory.requireCurrent(scope) and compare its exact plan/hash, so the inventory's actual
    /// factory, membership, snapshot, reference and full-policy checks remain authoritative.
    function requireCoverage(
        StreamFinalityScope calldata scope,
        bytes32 inventoryPlan,
        bytes32 expectedRenderCriticalEvidenceHash
    ) external view returns (PolicyBundle.BundleEvidence memory);
}
