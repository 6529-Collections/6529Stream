// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamScopedPreservationPolicySnapshotPublicationKernel
} from "./StreamScopedPreservationPolicySnapshotPublicationKernel.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Producers
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";

/// @notice Fixed original V1 snapshot writer; constructor and public tuple ABIs are unchanged.
contract StreamScopedPreservationPolicySnapshotPublicationV1 is
    StreamScopedPreservationPolicySnapshotPublicationKernel
{
    constructor(S.Dependencies memory d, address executor, GasParameterConfig[3] memory configs)
        StreamScopedPreservationPolicySnapshotPublicationKernel(
            d, executor, configs, Producers.ORIGINAL_PROFILE
        )
    { }
}
