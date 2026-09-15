// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistIdentityRecoveryTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryTypes.sol";

/// @notice The two permanent operation35 semantic hashes. This library grants no authority.
library StreamArtistIdentityRecoveryHashes {
    error InvalidSupersessionList();

    /// @dev All nine fields are static; the nested tuple retains the exact twelve-word preimage.
    ///      Operative callers supply their constructor-captured environment and admitted facts.
    function record(
        uint256 deploymentChainId,
        address registry,
        Recovery.RecordFields memory fields
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                bytes32(0x459749364fd07c3a8f1998b82d893d33ef0942c30d94666b42dac1e37ba5feff),
                deploymentChainId,
                registry,
                fields
            )
        );
    }

    /// @dev Empty content is legitimate and intentionally has the same semantic hash for every
    ///      artist. Distinct recoveries require distinct owner receipt occurrences.
    function supersession(bytes32[] memory sortedRecords) public pure returns (bytes32) {
        bytes32 previous;
        for (uint256 i; i < sortedRecords.length; ++i) {
            if (sortedRecords[i] <= previous) revert InvalidSupersessionList();
            previous = sortedRecords[i];
        }
        return keccak256(
            abi.encode(
                bytes32(0x0c8573762967a1af597f2a7afc4b655a87b3e22d2b11fbab6cf13c6f7b1396ae),
                sortedRecords
            )
        );
    }
}
