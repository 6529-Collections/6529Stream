// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamRenderCriticalInventory } from "./IStreamRenderCriticalInventory.sol";
import { StreamRenderCriticalSourceTypes as S } from "./StreamRenderCriticalSourceTypes.sol";

/// @notice Distinct source profile using the original role-qualified Item/Segment vocabulary.
interface IStreamPreservationPolicyRenderCriticalInventoryV1 is IStreamRenderCriticalInventory {
    function preservationPolicyInventoryProfile() external pure returns (bytes32);
    function appendTokenPreservation(bytes32 id) external;
    function dependencyHash() external view returns (bytes32);
    function dependencies() external view returns (S.Dependencies memory);
}
