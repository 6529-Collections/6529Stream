// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Immutable collection entropy policy, separate from individual request completion.
/// @dev The current coordinator implements one provider at epoch 1 with no fresh-randomness
///      recovery. The manifest commits that explicit profile and its frozen declarations.
///      Live governed timing, funding, provider availability and requester grants are operational.
interface IStreamEntropyFinalityPolicy is IERC165 {
    /// @notice A configured but unlocked policy may have a hash while frozen is false.
    /// @dev Missing provider/reveal declarations return the all-zero unavailable result.
    ///      A true result does not assert that any token or scope seed has finalized.
    function entropyPolicyFrozen(uint256 collectionId)
        external
        view
        returns (
            bool frozen,
            bytes32 policyManifestHash,
            address provider,
            uint32 providerEpoch,
            bytes32 collectionSaltCommitment
        );
}
