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

/// @notice Fixed original V1 snapshot writer; constructor and public tuple ABIs are unchanged.
contract StreamPreservationPolicySnapshotPublicationV1 is
    StreamPreservationPolicySnapshotPublicationKernel
{
    constructor(S.Dependencies memory d, address executor, GasParameterConfig[3] memory configs)
        StreamPreservationPolicySnapshotPublicationKernel(
            d, executor, configs, Producers.ORIGINAL_PROFILE
        )
    { }
}
