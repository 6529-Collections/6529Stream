// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamOperatorDistribution.sol";

/// @notice Additive publication commitment for Merkle recipient distributions.
/// @dev The original distribution interface and Program tuple remain unchanged.
interface IStreamOperatorDistributionMerkle {
    error DistributionMerkleDefinitionInvalid(bytes32 counterConfigHash);

    /// @notice Derives the phase commitment after registering the recipient definition.
    /// @dev The definition must include the published full allowlist's nonzero content hash.
    /// This getter can be called before configuring the phase; admission uses its current counter.
    function merkleProgramHash(
        uint256 collectionId,
        bytes32 phaseId,
        IStreamOperatorDistribution.Program calldata program,
        bytes32 recipientCounterConfigHash
    ) external view returns (bytes32);
}
