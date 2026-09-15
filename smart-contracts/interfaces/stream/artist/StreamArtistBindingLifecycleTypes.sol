// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact pending-generation termination payloads and immutable historical outcomes.
library StreamArtistBindingLifecycleTypes {
    struct Termination {
        uint256 collectionId;
        uint64 generation;
        bytes32 bindingHash;
        bytes32 reasonHash;
        string reasonURI;
    }

    /// @dev kind0 pending/not terminated;1 artist refusal;2 proposer withdrawal. Withdrawal creates no record.
    struct Terminal {
        uint8 kind;
        bytes32 reasonHash;
        bytes32 recordHash;
    }
}
