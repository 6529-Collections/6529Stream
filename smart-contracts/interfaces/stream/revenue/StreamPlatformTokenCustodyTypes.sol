// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Append-only, declaration-bound authorization; families 12/13 always ALLOW_CURRENT.
library StreamPlatformTokenCustodyTypes {
    struct Authorization {
        bytes32 auctionId;
        bytes32 baseConfigHash;
        bytes32 originHash;
        uint256 tokenId;
        bytes32 declarationHash;
        uint8 rightsMode;
        bytes32 assignmentHash;
        bytes32 primaryPolicyHash;
        uint8 primaryPolicyMode;
        bytes32 nonce;
        uint64 deadline;
    }

    struct Activation {
        Authorization authorization;
        bytes32 authorizationDigest;
        bytes32 effectiveConfigHash;
    }
}
