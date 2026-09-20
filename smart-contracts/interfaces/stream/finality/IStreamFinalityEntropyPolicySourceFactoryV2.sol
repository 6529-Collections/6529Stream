// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamFinalityEntropySourceFactory.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2
} from "../../../domains/finality/StreamFinalityCoordinatorPolicyReadsV2.sol";

/// @notice Distinct fixed factory for the matched COLLECTION V2 provider configuration.
/// @dev Original factory/route selectors remain recognizable; this capability identifies the
/// complete V2 policy semantics. Interface claims alone are never runtime/source admission.
interface IStreamFinalityEntropyPolicySourceFactoryV2 is IStreamFinalityEntropySourceFactory {
    function policyFactoryProfile() external pure returns (bytes32);
    function dependencies()
        external
        view
        returns (StreamFinalityCoordinatorPolicyReadsV2.Dependencies memory);
}
