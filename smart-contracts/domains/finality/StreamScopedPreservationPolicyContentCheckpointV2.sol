// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyContentCheckpointBaseV1 as Base
} from "./StreamPreservationPolicyContentCheckpointBaseV1.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Family
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";

/// @notice Complete TOKEN/RELEASE/SEASON preservation output with exact per-row governed producer admission.
/// @dev This wrapper fixes the closed two-token family; historical V1 meanings remain unchanged.
contract StreamScopedPreservationPolicyContentCheckpointV2 is Base {
    bytes32 public constant PRESERVATION_PROFILE = Family.FAMILY_PROFILE;

    constructor(
        address selection,
        address policySourceSet,
        address readiness,
        address executor,
        GasParameterConfig memory readGas,
        GasParameterConfig memory renderGas
    ) Base(selection, policySourceSet, readiness, true, true, executor, readGas, renderGas) { }

    function _preservationProfile() internal pure override returns (bytes32) {
        return PRESERVATION_PROFILE;
    }
}
