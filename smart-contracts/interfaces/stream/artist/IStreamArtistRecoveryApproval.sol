// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamArtistRecoveryApprovalOwner.sol";

/// @notice Recovery approval ingress and permanent saved-evidence verification.
/// @dev Initial authority profile is a current principal or activated successor with CAP_SANCTION,
///      without collaborators/delegation/stewardship or corrective-association adoption.
interface IStreamArtistRecoveryApproval {
    function recordRecoveryApproval(
        Approval.Request calldata request,
        T.Authorization calldata authorization
    ) external returns (bytes32 recordHash);
    function recoveryApprovalDigest(
        Recovery.ApprovalTerms calldata terms,
        T.Authorization calldata authorization
    ) external view returns (bytes32);
    function recoveryApprovalRecord(bytes32 recordHash)
        external
        view
        returns (Recovery.ApprovalRecord memory, Approval.Admission memory);
    function verifyRecoveryApproval(
        uint256 collectionId,
        bytes32 finalityRecordHash,
        bytes32 recoveryManifestHash
    )
        external
        view
        returns (bool valid, bytes32 approvalRecordHash, address signer, uint8 authorityClass);
}

interface IStreamArtistRecoveryApprovalCoordinator {
    function coordinateRecordRecoveryApproval(
        address actor,
        Approval.Request calldata request,
        T.Authorization calldata authorization
    ) external returns (bytes32 recordHash);
    function verifyRecoveryApproval(
        uint256 collectionId,
        bytes32 finalityRecordHash,
        bytes32 recoveryManifestHash
    )
        external
        view
        returns (bool valid, bytes32 approvalRecordHash, address signer, uint8 authorityClass);
}
