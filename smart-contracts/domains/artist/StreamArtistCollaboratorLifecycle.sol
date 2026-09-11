// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistOwner.sol";

/// @notice Real immutable empty collaborator domain for the primary-only onboarding profile.
/// @dev No collaborator operation is advertised. Nonempty profiles fail at binding admission.
contract StreamArtistCollaboratorLifecycle is StreamArtistOwner {
    constructor(
        address registry_,
        address coordinator_,
        address archive_,
        address core_,
        address manager_
    )
        StreamArtistOwner(
            registry_,
            coordinator_,
            archive_,
            keccak256("domain:collaborator_lifecycle"),
            core_,
            manager_
        )
    { }

    function collaboratorSetHash() external pure returns (bytes32) {
        return StreamArtistHashes.emptyCollaborators();
    }

    function collaboratorCount() external pure returns (uint256) {
        return 0;
    }
}
