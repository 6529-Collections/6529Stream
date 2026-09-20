// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicySnapshotPublicationKernel
} from "./StreamPreservationPolicySnapshotPublicationKernel.sol";
import {
    StreamPreservationPolicySnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamPreservationPolicySnapshotTypesV1.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Producers
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";

/// @notice Fixed two-producer V2 family snapshot writer; constructor and public tuple ABIs are unchanged.
contract StreamPreservationPolicySnapshotPublicationV2 is
    StreamPreservationPolicySnapshotPublicationKernel
{
    constructor(S.Dependencies memory d, address executor, GasParameterConfig[3] memory configs)
        StreamPreservationPolicySnapshotPublicationKernel(
            d, executor, configs, Producers.FAMILY_PROFILE
        )
    { }

    function preservationPolicySnapshotProfile() external pure override returns (bytes32) {
        return keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_V2");
    }
}
