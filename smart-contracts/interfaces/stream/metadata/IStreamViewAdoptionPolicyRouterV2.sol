// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamViewAdoptionTypes as V } from "./StreamViewAdoptionTypes.sol";

/// @notice Closed additive policy VIEW methods on the original admitted Router.
/// @dev Existing adopted-VIEW head/carrier/aggregate APIs remain authoritative for both profiles.
interface IStreamViewAdoptionPolicyRouterV2 {
    function previewPolicyViewAdoption(V.Input calldata input, address actor)
        external
        view
        returns (bytes32 familyState, bytes32 sourceHash);
    function adoptPolicyView(V.Input calldata input) external returns (bytes32 recordHash);
    /// @notice Unknown records revert; zero identifies an existing original V1 record only.
    function viewAdoptionProfile(bytes32 recordHash) external view returns (bytes32);
}
