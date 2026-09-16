// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Collection provider revisions and immutable request-time seed inputs.
/// @dev This additive read capability does not authorize provider migration after mint,
///      fallback requests or a new random draw for a completed subject.
interface IStreamEntropyEpochs is IERC165 {
    struct RequestPolicySnapshot {
        address provider;
        bytes32 providerCodeHash;
        uint32 providerEpoch;
        bytes32 providerConfigHash;
        bytes32 collectionSalt;
        bytes32 inputsHash;
        uint16 requestAttempt;
    }

    error ProviderEpochOverflow(uint256 collectionId);

    event CollectionEntropyEpochConfigured(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        address indexed provider,
        uint32 providerEpoch,
        bytes32 providerConfigHash
    );

    /// @notice Zero before configuration, then increases for each provider/config change.
    /// @dev Operational retuning and identical configuration do not increment the epoch.
    function collectionProviderEpoch(uint256 collectionId) external view returns (uint32);

    /// @notice Returns the policy captured before submitting a request to its provider.
    /// @dev Unknown or reverted requests return an all-zero record. First attempts are 1.
    function requestPolicySnapshot(bytes32 requestKey)
        external
        view
        returns (RequestPolicySnapshot memory);
}
