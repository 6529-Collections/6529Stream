// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyReferencePublicationBase
} from "./StreamPreservationPolicyReferencePublicationBase.sol";
import {
    StreamPreservationPolicyReferenceTypesV1 as T
} from "../../interfaces/stream/preservation/StreamPreservationPolicyReferenceTypesV1.sol";
import {
    StreamPreservationPolicyReferenceDefinitionsV1 as D
} from "../records/StreamPreservationPolicyReferenceDefinitionsV1.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Profiles
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";

/// @notice Fixed V1 reference profile; no mutable family or caller-selected interpretation.
contract StreamPreservationPolicyReferencePublicationV1 is
    StreamPreservationPolicyReferencePublicationBase
{
    constructor(T.Dependencies memory d, address executor, GasParameterConfig[4] memory configs)
        StreamPreservationPolicyReferencePublicationBase(
            d, executor, configs, Profiles.ORIGINAL_PROFILE
        )
    { }

    function preservationPolicyReferenceProfile() external pure override returns (bytes32) {
        return keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_V1");
    }

    function streamModuleVersion() public pure override returns (bytes32) {
        return keccak256("STREAM_PRESERVATION_POLICY_REFERENCE_RENDER_IMPLEMENTATION_V1");
    }

    function streamModuleSchemaHash() external pure override returns (bytes32) {
        return D.SCHEMA_HASH;
    }

    function streamModuleManifest() external pure override returns (string memory, bytes32) {
        return ("", D.PROFILE_HASH);
    }
}
