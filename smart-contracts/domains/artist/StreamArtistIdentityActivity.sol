// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistEstateState.sol";
import "./StreamArtistUnavailabilityState.sol";

/// @notice Bounded activity composition over the fixed Identity's actual storage references.
/// @dev Keeps estate cancellation and unavailability cancellation separate, in that order.
library StreamArtistIdentityActivity {
    function note(
        StreamArtistEstateState.State storage estate,
        StreamArtistIdentityState.State storage identity,
        StreamArtistUnavailabilityState.State storage findings,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes32 artistId,
        address signer,
        uint16 operation
    ) public returns (bytes32 estateState, bytes32 estateReplay, bytes32 findingState) {
        (estateState, estateReplay) =
            StreamArtistEstateState.livingAction(estate, identity, replay, o, artistId, signer);
        findingState = StreamArtistUnavailabilityState.notePrincipalActivity(
            findings, identity.identities[artistId], artistId, signer, operation
        );
    }
}
