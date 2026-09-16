// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamOwnerPreparedNoticeTypes.sol";
import "./StreamOwnerRecoveryNoticeTypes.sol";

/// @notice Incremental immutable publication followed by atomic action-bound notice opening.
/// @dev Preparation creates neither a notice clock nor valid owner recovery evidence.
interface IStreamOwnerPreparedRecoveryNotices {
    error InvalidOwnerNoticePreparation();
    error OwnerNoticePreparationUnknown(bytes32 preparationId);
    error OwnerNoticePreparationPublisherRequired(address caller);

    event OwnerRecoveryNoticePreparing(
        bytes32 indexed preparationId,
        bytes32 indexed actionId,
        address indexed publisher,
        uint256 tokenId,
        address openingOwner,
        bytes32 stewardRecordHash,
        uint64 deliveryCount,
        uint16 schemaVersion
    );
    event OwnerRecoveryNoticeDeliveryPrepared(
        bytes32 indexed preparationId,
        uint64 indexed deliveryIndex,
        bytes32 claimHash,
        address claimPointer,
        bool complete,
        uint16 schemaVersion
    );
    event OwnerRecoveryNoticePreparedOpening(
        bytes32 indexed preparationId,
        bytes32 indexed actionId,
        address indexed publisher,
        address finalizer,
        uint16 schemaVersion
    );

    function prepareRecoveryNotice(StreamOwnerPreparedNoticeTypes.Input calldata input)
        external
        returns (bytes32 preparationId);
    function prepareRecoveryNoticeDelivery(
        bytes32 preparationId,
        StreamOwnerRecoveryNoticeTypes.Delivery calldata delivery
    ) external;
    function openPreparedRecoveryNotice(
        bytes32 preparationId,
        GovernanceCall[] calldata completePublishedCalls,
        StreamFinalityRecoveryRequest calldata request
    ) external;
    function recoveryNoticePreparation(bytes32 preparationId)
        external
        view
        returns (StreamOwnerPreparedNoticeTypes.Snapshot memory);
    function recoveryNoticePreparedClaim(bytes32 preparationId, uint256 index)
        external
        view
        returns (address pointer, bytes memory originalBytes);
    function recoveryNoticePreparationFor(bytes32 actionId) external view returns (bytes32);
}
