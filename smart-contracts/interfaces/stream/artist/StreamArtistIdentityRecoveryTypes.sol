// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Permanent operation35 record fields, separate from admission and receipt coordinates.
library StreamArtistIdentityRecoveryTypes {
    struct RecordFields {
        bytes32 artistId;
        address oldAddress;
        address newAddress;
        uint8 vestedAuthorityClass;
        bytes32 evidenceHash;
        bytes32 reasonHash;
        bytes32 supersededRecordsHash;
        bytes32 governanceActionId;
        uint64 recoveredAt;
    }
}
