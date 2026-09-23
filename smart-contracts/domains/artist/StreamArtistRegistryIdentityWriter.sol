// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistIdentityRevisionTypes as Revision,
    IStreamArtistIdentityRevisionCoordinator
} from "../../interfaces/stream/artist/IStreamArtistIdentityRevision.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistOnboardingCoordinator
} from "../../interfaces/stream/artist/IStreamArtistOnboardingCoordinator.sol";

/// @notice Fixed typed encodings for the facade's identity proposal and revision writers.
/// @dev The original extension checks its immutable host before entering this worker.
library StreamArtistRegistryIdentityWriter {
    function proposeBinding(address coordinator, address actor, bytes calldata arguments)
        public
        returns (bytes32, bytes32)
    {
        (
            uint256 collectionId,
            T.BindingProposal memory proposal,
            bytes memory document,
            string memory displayName
        ) = abi.decode(arguments, (uint256, T.BindingProposal, bytes, string));
        return IStreamArtistOnboardingCoordinator(coordinator)
            .coordinateProposeArtistBinding(actor, collectionId, proposal, document, displayName);
    }

    function recordRevision(address coordinator, address actor, bytes calldata arguments)
        public
        returns (bytes32)
    {
        (
            Revision.Revision memory revision,
            T.Authorization memory authorization,
            bytes memory document,
            string memory displayName
        ) = abi.decode(arguments, (Revision.Revision, T.Authorization, bytes, string));
        return IStreamArtistIdentityRevisionCoordinator(coordinator)
            .coordinateRecordIdentityRevision(actor, revision, authorization, document, displayName);
    }
}
