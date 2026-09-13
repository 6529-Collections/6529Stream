// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamOwnerRecords.sol";
import "./StreamOwnerRecoveryNoticeTypes.sol";
import "../finality/IStreamFinalityRecoveryOwnerEvidence.sol";

/// @notice Owner-authorized responses and permissionless, action-bound TOKEN notice publication.
/// @dev Opening does not prove offchain delivery. Responses never grant veto authority.
interface IStreamOwnerRecoveryNotices {
    error InvalidOwnerRecoveryNotice();
    error OwnerRecoveryNoticeExists(bytes32 actionId);
    error OwnerRecoveryNoticeUnknown(bytes32 actionId);
    error OwnerRecoveryResponseUnknown(bytes32 recordHash);

    event OwnerRecoveryNoticeOpened(
        bytes32 indexed actionId,
        uint256 indexed tokenId,
        address indexed openingOwner,
        address publisher,
        bytes32 stewardRecordHash,
        bytes32 publicationHash,
        uint64 openedAt,
        uint64 noticeEndsAt,
        bytes32 evidenceHash,
        uint16 schemaVersion
    );
    event OwnerRecoveryResponseRecorded(
        bytes32 indexed actionId,
        address indexed author,
        bytes32 indexed recordHash,
        uint256 tokenId,
        bool queued,
        bool afterMinimumWindow,
        uint16 schemaVersion
    );
    event OwnerRecoveryResponseProcessed(
        bytes32 indexed actionId,
        address indexed author,
        bytes32 indexed recordHash,
        bytes32 predecessor,
        uint64 revision,
        uint32 acknowledgements,
        uint32 objections,
        bytes32 evidenceHash,
        uint16 schemaVersion
    );

    function openRecoveryNotice(
        bytes32 actionId,
        GovernanceCall[] calldata completePublishedCalls,
        StreamFinalityRecoveryRequest calldata request,
        StreamOwnerNoticeTypes.Designation calldata steward,
        StreamOwnerRecoveryNoticeTypes.Publication calldata publication
    ) external;

    function recordRecoveryResponse(
        uint256 tokenId,
        IStreamOwnerRecords.OwnerRecord calldata record,
        StreamOwnerNoticeTypes.Response calldata response
    ) external;

    function recordRecoveryResponseFor(
        uint256 tokenId,
        IStreamOwnerRecords.OwnerRecord calldata record,
        address owner,
        uint256 nonce,
        uint64 deadline,
        bytes calldata signature,
        StreamOwnerNoticeTypes.Response calldata response
    ) external;

    /// @notice Processes exactly the next original response while the action is SCHEDULED.
    function processRecoveryResponse(bytes32 actionId) external returns (bool processed);
    function recoveryNotice(bytes32 actionId)
        external
        view
        returns (StreamOwnerRecoveryNoticeTypes.Snapshot memory);
    /// @notice Exact retained ABI bytes: index0=(runbook,publicNotice), indices1..deliveryCount=Delivery.
    function recoveryNoticeClaim(bytes32 actionId, uint256 index)
        external
        view
        returns (address pointer, bytes memory originalBytes);
    function recoveryResponse(bytes32 recordHash)
        external
        view
        returns (StreamOwnerRecoveryNoticeTypes.Response memory);
    function recoveryResponseAt(bytes32 actionId, uint256 index) external view returns (bytes32);
    function latestCountedRecoveryResponse(bytes32 actionId, address author)
        external
        view
        returns (bytes32);
}
