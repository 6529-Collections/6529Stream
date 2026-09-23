// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamFinalityEntropySourceFactory.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2
} from "../../../domains/finality/StreamFinalityCoordinatorPolicyReadsV2.sol";

/// @notice Distinct non-COLLECTION full-policy source-factory capability.
/// @dev A runtime-pinned consumer also checks the exact profile and dependency tuple. Inherited
/// generic factory/route selectors alone do not distinguish this profile from COLLECTION V2.
interface IStreamFinalityScopedEntropyPolicySourceFactoryV2 is IStreamFinalityEntropySourceFactory {
    function scopedPolicyFactoryProfile() external pure returns (bytes32);
    function dependencies()
        external
        view
        returns (StreamFinalityCoordinatorPolicyReadsV2.Dependencies memory);
}
