// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol";

/// @notice Real artist owners, both economics providers, split profiles and official Safe signatures.
/// @dev Core, metadata and governance boundaries are explicit unit doubles;
///      a separate current-stack test owns integration and eligible token mint proof.
/// @dev Test-only simulation of the future operation33 state seam. No public compromise filing is claimed.
contract ArtistRotationContestHarness is StreamArtistIdentityAuthority {
    constructor(
        address registry_,
        address coordinator_,
        address archive_,
        address core_,
        address manager_,
        address extensionFactory_,
        address[3] memory extensions_
    ) StreamArtistIdentityAuthority(registry_, coordinator_, archive_, core_, manager_, extensionFactory_, extensions_) { }

    function simulateExecutedTransitionContest(bytes32 record) external {
        R.TransitionState storage transition = _rotations.rotations[record].transition;
        require(
            transition.phase == 2 && transition.contestedAt == 0, "qualified transition fixture"
        );
        transition.contestedAt = _now();
        _identity.identities[transition.artistId].status = 4;
        ++_revision;
        _stateRoot = keccak256(
            abi.encode(keccak256("TEST_ONLY_COMPROMISE_STATE_SEAM"), _stateRoot, transition)
        );
    }
}
