// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredTimingTypes as TM
} from "../../interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";
import {
    StreamArtistRecoveredExternalGuards as External
} from "./StreamArtistRecoveredExternalGuards.sol";
import {
    StreamArtistRecoveredHydrationEvidence as Evidence
} from "./StreamArtistRecoveredHydrationEvidence.sol";

/// @notice Original recovered-operation commitment and Archive byte encodings.
/// @dev The caller supplies its original chain and Coordinator context explicitly. This fixed
/// pure worker does not collect source state, move replay state, or write Archive evidence.
library StreamArtistRecoveredHydrationCommitEncoding {
    struct Inputs {
        address prior;
        address sourceCoordinator;
        AH.Query[] artists;
        AH.Query[] collections;
        AH.Query query;
        AH.OwnerData[7] data;
        TM.Checkpoint timing;
        External.Snapshot externalGuards;
        T.Snapshot[7] before_;
    }

    function prepare(
        uint256 chainId,
        address registry,
        address coordinator,
        bytes32 configurationHash,
        address actor,
        RH.Request calldata request,
        Inputs calldata prepared
    )
        public
        pure
        returns (
            bytes32 value,
            bytes memory profileBytes,
            Evidence.Descriptor memory descriptor,
            bytes memory carrier,
            bytes memory probe
        )
    {
        value = keccak256(
            abi.encode(
                RH.PROFILE,
                RH.VERSION,
                chainId,
                registry,
                coordinator,
                prepared.prior,
                prepared.sourceCoordinator,
                request,
                prepared.artists,
                prepared.collections,
                prepared.query,
                prepared.data,
                prepared.timing,
                prepared.externalGuards,
                prepared.before_
            )
        );
        profileBytes = abi.encode(
            RH.PROFILE,
            RH.VERSION,
            prepared.prior,
            prepared.sourceCoordinator,
            request,
            prepared.artists,
            prepared.collections,
            prepared.query,
            prepared.data,
            prepared.timing,
            prepared.externalGuards
        );
        descriptor = Evidence.describe(profileBytes);
        carrier = abi.encode(RH.PROFILE, descriptor);
        probe = abi.encode(
            uint16(1),
            configurationHash,
            uint16(60),
            actor,
            value,
            prepared.before_,
            prepared.before_,
            carrier
        );
    }

    function evidence(
        uint256 chainId,
        address registry,
        address coordinator,
        bytes32 configurationHash,
        address actor,
        bytes32 value,
        T.Snapshot[7] calldata before_,
        T.Snapshot[7] calldata after_,
        bytes calldata carrier
    ) public pure returns (bytes32 id, bytes memory encoded) {
        id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                chainId,
                registry,
                coordinator,
                uint16(60),
                actor,
                value
            )
        );
        encoded = abi.encode(
            uint16(1), configurationHash, uint16(60), actor, value, before_, after_, carrier
        );
    }
}
