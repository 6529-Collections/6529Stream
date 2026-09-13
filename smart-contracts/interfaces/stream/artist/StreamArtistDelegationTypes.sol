// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Typed scoped delegation records; only economics and royalty-freeze capabilities are supported.
library StreamArtistDelegationTypes {
    uint32 internal constant ECONOMICS = 4;
    uint32 internal constant ROYALTY_FREEZE = 32;

    struct Grant {
        bytes32 artistId;
        address delegate;
        uint256 collectionId;
        uint32 capabilities;
        uint64 notBefore;
        uint64 expiresAt;
        uint64 maxUses;
        bytes32 constraintsHash;
    }

    struct Revocation {
        bytes32 artistId;
        address delegate;
        bytes32 delegationRecordHash;
        bytes32 reasonHash;
    }

    struct Record {
        Grant grant;
        address grantor;
        uint256 nonce;
        uint256 uses;
        bool revoked;
        bytes32 revocationRecordHash;
    }

    /// @dev Immutable configuration passed by the guarded Coordinator to its stateless linked helper.
    struct CoordinatorContext {
        T.SuiteConfiguration suite;
        address reads;
        bytes32 configurationHash;
    }

    error InvalidDelegation(bytes32 recordHash);
    error ConflictingDelegation(bytes32 recordHash);
    error DelegationUnavailable(bytes32 recordHash);
    error DelegationScope(bytes32 recordHash);
    error DelegationCapability(bytes32 recordHash, uint32 requiredCapability);
}
