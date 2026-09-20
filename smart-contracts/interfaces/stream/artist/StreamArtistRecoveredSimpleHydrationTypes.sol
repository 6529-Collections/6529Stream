// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import { StreamArtistCollaboratorTypes as C } from "./StreamArtistCollaboratorTypes.sol";
import { StreamArtistBindingLifecycleTypes as L } from "./StreamArtistBindingLifecycleTypes.sol";

/// @notice Explicit singleton PRIMARY_ONLY transport for recovered-profile owners0,1,3.
/// @dev Other collaborator or collection histories require a separate complete implementation.
library StreamArtistRecoveredSimpleHydrationTypes {
    bytes32 internal constant BINDING = keccak256("6529STREAM_ARTIST_RECOVERED_BINDING_STATE_V1");
    bytes32 internal constant COLLABORATOR =
        keccak256("6529STREAM_ARTIST_RECOVERED_EMPTY_COLLABORATOR_STATE_V1");
    bytes32 internal constant ACCEPTANCE =
        keccak256("6529STREAM_ARTIST_RECOVERED_ACCEPTANCE_STATE_V1");

    struct Scope {
        bytes32 artistId;
        uint256 collectionId;
        bytes32 bindingHash;
    }

    struct Binding {
        Scope scope;
        bytes32 provenanceCommitment;
        T.Binding item;
        T.Binding history;
        C.BindingTerms terms;
        L.Terminal terminal;
    }

    struct EmptyCollaborator {
        Scope scope;
        bytes32 provenanceCommitment;
    }

    struct Acceptance {
        Scope scope;
        bytes32 provenanceCommitment;
        bytes32 record;
        uint64 acceptedAt;
    }
}
