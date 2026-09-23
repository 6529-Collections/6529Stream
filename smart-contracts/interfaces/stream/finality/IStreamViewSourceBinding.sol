// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamViewAdoptionTypes as V } from "../metadata/StreamViewAdoptionTypes.sol";

/// @notice Immutable source roster on the actual selected finality provider, not an authority grant.
/// @dev Getter has no statement/inventory/component recursion. Caller must pin the provider and
/// revalidate actual Core/Metadata/Router and module reciprocities before interpreting a document.
interface IStreamViewSourceBinding {
    function viewSourceBinding() external view returns (V.Binding memory);
}
