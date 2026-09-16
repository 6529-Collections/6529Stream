// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistGuardianHistoryTypes as H } from "./StreamArtistGuardianHistoryTypes.sol";

/// @notice Original guardian prefix at an actual Identity-owned authority vesting.
library StreamArtistGuardianVestingTypes {
    struct Input {
        bytes32 artistId;
        bytes32 transitionRecordHash;
        bytes32 previousTransitionRecordHash;
        uint64 ownerRevision;
        uint16 operationId;
    }

    struct Snapshot {
        bytes32 artistId;
        bytes32 transitionRecordHash;
        uint16 operationId;
        uint64 ownerRevision;
        uint64 executedAt;
        address oldAddress;
        address newAddress;
        uint8 authorityClass;
        H.Head guardians;
        bytes32 previousTransitionRecordHash;
        bytes32 previousCommitment;
        bytes32 commitment;
    }
    error InvalidGuardianVesting(bytes32 transitionRecordHash);
    error IncompleteGuardianVestingHistory(bytes32 artistId, bytes32 previousTransitionRecordHash);
}
