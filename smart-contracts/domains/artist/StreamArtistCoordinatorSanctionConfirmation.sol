// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    StreamArtistCurrentAuthorityTypes as CurrentAuthority
} from "../../interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";
import { StreamArtistCurrentFinalityRoute } from "./StreamArtistCurrentFinalityRoute.sol";
import {
    StreamArtistCoordinatorFinalityReads as FinalityReads
} from "./StreamArtistCoordinatorFinalityReads.sol";
import {
    StreamArtistSanctionConfirmationOperations
} from "./StreamArtistSanctionConfirmationOperations.sol";
import { StreamArtistSanctionConfirmationReads } from "./StreamArtistSanctionConfirmationReads.sol";

/// @notice Original confirmation branch and calls after the Coordinator's unchanged operation admission.
library StreamArtistCoordinatorSanctionConfirmation {
    function confirm(
        T.SuiteConfiguration storage _suite,
        bytes32[16] storage _runtimeHashes,
        address reads,
        bytes32 configurationHash,
        uint256 deploymentChainId,
        address finalityRegistry,
        bytes32 finalityRegistryCodeHash,
        address actor,
        uint256 collectionId
    ) public {
        uint256 cap = FinalityReads.finalityReadGas(_suite);
        if (StreamArtistCurrentFinalityRoute.isAnchoredCapability(
                _suite.metadata, collectionId, cap
            )) {
            CurrentAuthority.Route memory route =
                FinalityReads.currentFinalityRoute(_suite, deploymentChainId, collectionId);
            StreamArtistSanctionConfirmationOperations.confirmCurrentAuthority(
                D.CoordinatorContext(_suite, reads, configurationHash),
                StreamArtistSanctionConfirmationReads.Pins(
                    route.finalityRegistry,
                    route.finalityCodeHash,
                    _runtimeHashes[9],
                    _runtimeHashes[7],
                    cap
                ),
                actor,
                collectionId
            );
            return;
        }
        StreamArtistSanctionConfirmationOperations.confirm(
            D.CoordinatorContext(_suite, reads, configurationHash),
            StreamArtistSanctionConfirmationReads.Pins(
                finalityRegistry,
                finalityRegistryCodeHash,
                _runtimeHashes[9],
                _runtimeHashes[7],
                cap
            ),
            actor,
            collectionId
        );
    }
}
