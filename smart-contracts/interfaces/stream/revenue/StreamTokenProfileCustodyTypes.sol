// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Appended rights approval for an already acquired token; always ALLOW_CURRENT.
library StreamTokenProfileCustodyTypes {
    struct Authorization {
        bytes32 auctionId;
        bytes32 baseConfigHash;
        bytes32 originHash;
        uint256 tokenId;
        bytes32 assignmentHash;
        bytes32 primaryPolicyHash;
        uint8 primaryPolicyMode;
        address artist;
        bytes32 nonce;
        uint64 deadline;
    }

    struct Activation {
        Authorization authorization;
        bytes32 authorizationDigest;
        bytes32 effectiveConfigHash;
    }
}
