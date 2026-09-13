// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamOwnerNoticeTypes.sol";

/// @notice Preparation is attributed publication work, not an opened recovery notice.
library StreamOwnerPreparedNoticeTypes {
    struct Input {
        uint256 tokenId;
        bytes32 actionId;
        uint256 nonce;
        StreamOwnerNoticeTypes.Designation steward;
        StreamOwnerNoticeTypes.Reference runbook;
        StreamOwnerNoticeTypes.Reference publicNotice;
    }

    struct Snapshot {
        uint256 tokenId;
        bytes32 actionId;
        address publisher;
        address openingOwner;
        bytes32 stewardRecordHash;
        bytes32 stewardPayloadHash;
        bytes32 expectedEndpointHash;
        bytes32 endpointHash;
        bytes32 publicationHash;
        uint64 deliveryCount;
        uint64 preparedCount;
        uint64 preparedAt;
        bool complete;
        bool consumed;
    }
}
