// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamOwnerNoticeTypes.sol";
import "../../../domains/records/StreamOwnerRecoveryActionReads.sol";

/// @notice Permanent TOKEN notice evidence; delivery references are attributed claims.
library StreamOwnerRecoveryNoticeTypes {
    struct Delivery {
        StreamOwnerNoticeTypes.Contact endpoint;
        StreamOwnerNoticeTypes.Reference evidence;
    }

    struct Publication {
        StreamOwnerNoticeTypes.Reference runbook;
        StreamOwnerNoticeTypes.Reference publicNotice;
        Delivery[] deliveries;
    }

    struct Snapshot {
        StreamOwnerRecoveryActionReads.Binding binding;
        StreamFinalityScope scope;
        address publisher;
        address openingOwner;
        bytes32 stewardRecordHash;
        bytes32 stewardPayloadHash;
        bytes32 publicationHash;
        uint64 openedAt;
        uint64 noticeEndsAt;
        uint64 firstResponseIndex;
        uint64 deliveryCount;
        bytes32 evidenceHash;
        uint64 revision;
        uint64 responseTail;
        uint64 processed;
        uint32 acknowledgements;
        uint32 objections;
    }

    /// @dev All canonical originals are retained, including ones with no admitted notice.
    struct Response {
        uint256 tokenId;
        address author;
        bytes32 actionId;
        bytes32 manifestHash;
        uint64 recordedAt;
        uint64 recordIndex;
        StreamOwnerNoticeTypes.ResponseClass response;
        bool queued;
        bool processed;
        bool afterMinimumWindow;
    }
}
