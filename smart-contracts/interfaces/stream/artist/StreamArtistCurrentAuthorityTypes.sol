// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistArchiveOriginTypes as O
} from "../preservation/StreamArtistArchiveOriginTypes.sol";

/// @notice Separate current authority for an original, capability-aware Finality deployment.
/// @dev These facts never replace historical Artist, Finality or signing domains.
library StreamArtistCurrentAuthorityTypes {
    bytes32 internal constant PROFILE = keccak256("6529STREAM_ARTIST_CURRENT_AUTHORITY_V1");

    struct Anchors {
        // Original Core, generic Metadata, Router, Artist registry and evidence provider.
        address[5] targets;
        bytes32[5] codeHashes;
        // Predicted original Finality; its actual code must be selected for operative reads.
        address finalityRegistry;
        uint256 chainId;
        uint256 readGas;
    }

    /// @dev 26 static words. Selection is reauthenticated for every operative use.
    struct Selection {
        O.Origin origin;
        bytes32 completion;
        bytes32 selectionHash;
    }

    /// @dev Ten static words. Both endpoints must derive exactly the same route.
    struct Route {
        address finalityRegistry;
        bytes32 finalityCodeHash;
        address provider;
        bytes32 providerCodeHash;
        address registry;
        bytes32 registryCodeHash;
        address coordinator;
        bytes32 coordinatorCodeHash;
        bytes32 selectionHash;
        bytes32 presentationHash;
    }

    error InvalidCurrentAuthority();
    error CurrentAuthorityChanged();

    function hashSelection(Anchors memory anchors, O.Origin memory origin, bytes32 completion)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(PROFILE, anchors, origin, completion));
    }
}
